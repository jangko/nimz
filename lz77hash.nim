import lz77util, zerror, hashz

proc getMaxChainLen(windowSize: int): int =
  result = if windowsize >= 8192: windowsize else: windowsize div 8

proc getMaxLazyMatch(windowSize: int): int =
  result = if windowsize >= 8192: MAX_MATCH else: 64
  
proc LZ77Encode*(opts: LZOpts, data: cstring, inSize: int): seq[int16] =
  #for large window lengths, assume the user wants no compression loss.
  #Otherwise, max hash chain length speedup.
  result = @[]

  let windowSize = opts.windowSize
  var maxChainLength = getMaxChainLen(windowSize)
  var maxLazyMatch = getMaxLazyMatch(windowSize)

  #not sure if setting it to false for windowsize < 8192 is better or worse
  var
    useZeros = true
    numZeros = 0
    lazy = 0
    lazyLength = 0
    lazyOffset = 0
    hashVal: int
    offset, length: int
    hashpos: int
    lastPtr, forePtr, backPtr: int
    prevOffset: int
    currentOffset, currentLength: int
    hash: NZHash

  if (windowSize == 0) or (windowSize > 32768):
    nzerror(ERR_WINDOW_SIZE_NOT_ALLOWED)
  if (windowSize and (windowSize - 1)) != 0:
    nzerror(ERR_WINDOW_SIZE_MUST_BE_POWER_OF_TWO)

  hash.hashInit(windowSize)
  var niceMatch = min(opts.niceMatch, MAX_MATCH)
  var pos = 0

  while pos < inSize:
    var wpos = pos and (windowSize - 1) #position for in 'circular' hash buffers
    var chainlength = 0
    hashVal = getHash(data, inSize, pos)

    if useZeros and hashVal == 0:
      if numZeros == 0: numZeros = countZeros(data, inSize, pos)
      elif (pos + numZeros > inSize) or (data[pos + numZeros - 1] != chr(0)): dec numZeros
    else: numZeros = 0

    updateHashChain(hash, wpos, hashVal, numZeros)

    #the length and offset found for the current position
    length = 0
    offset = 0
    hashpos = hash.chain[wpos]
    lastPtr = min(inSize, pos + MAX_MATCH)

    #search for the longest string
    prevOffset = 0
    while true:
      if chainlength >= maxChainLength: break
      inc chainlength
      currentOffset = if hashpos <= wpos: wpos - hashpos else: wpos - hashpos + windowSize

      #stop when went completely around the circular buffer
      if currentOffset < prevOffset: break
      prevOffset = currentOffset
      if currentOffset > 0:
        #test the next characters
        forePtr = pos
        backPtr = pos - currentOffset

        #common case in PNGs is lots of zeros. Quickly skip over them as a speedup
        if numZeros >= 3:
          let skip = min(numZeros, hash.zeros[hashpos])
          inc(backPtr, skip)
          inc(forePtr, skip)

        #maximum supported length by deflate is max length
        while forePtr < lastPtr:
          if data[backPtr] != data[forePtr]: break
          inc backPtr
          inc forePtr

        currentLength = forePtr - pos

        if currentLength > length:
          length = currentLength #the longest length
          offset = currentOffset #the offset that is related to this longest length
          #jump out once a length of max length is found (speed gain). This also jumps
          #out if length is MAX_MATCH
          if currentLength >= niceMatch: break

      if hashpos == hash.chain[hashpos]: break

      if (numZeros >= 3) and (length > numZeros):
        hashpos = hash.chainz[hashpos]
        if hash.zeros[hashpos] != numZeros: break
      else:
        hashpos = hash.chain[hashpos]
        #outdated hash value, happens if particular
        #value was not encountered in whole last window
        if hash.val[hashpos] != hashVal: break

    if opts.lazyMatching:
      if (lazy==0) and (length >= 3) and (length <= maxLazyMatch) and (length < MAX_MATCH):
        lazy = 1
        lazyLength = length
        lazyOffset = offset
        inc pos
        continue #try the next byte

      if lazy != 0:
        lazy = 0
        if pos == 0: nzerror(ERR_LAZY_MATCHING_IMPOSSIBLE)
        if length > lazyLength + 1:
          #push the previous character as literal
          result.add ord(data[pos - 1])
        else:
          length = lazyLength
          offset = lazyOffset
          hash.head[hashVal] = -1 #the same hashchain update will be done, this ensures no wrong alteration*
          hash.headz[numZeros] = -1 #idem
          dec pos

    if(length >= 3) and (offset > windowSize):
      nzerror(ERR_OVERFLOWN_OFFSET)

    #encode it as length/distance pair or literal value
    if length < 3: #only lengths of 3 or higher are supported as length/distance pair
      result.add ord(data[pos])
    elif(length < opts.minMatch) or ((length == 3) and (offset > 4096)):
      #compensate for the fact that longer offsets have more extra bits, a
      #length of only 3 may be not worth it then
      result.add ord(data[pos])
    else:
      result.addLengthDistance(length, offset)
      for i in 1..length-1:
        inc pos
        wpos = pos and (windowSize - 1)
        hashVal = getHash(data, inSize, pos)
        if useZeros and (hashVal == 0):
          if numZeros == 0: numZeros = countZeros(data, inSize, pos)
          elif (pos + numZeros > inSize) or (data[pos + numZeros - 1] != chr(0)): dec numZeros
        else: numZeros = 0
        updateHashChain(hash, wpos, hashVal, numZeros)
    inc pos

