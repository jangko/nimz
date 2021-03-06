import sequtils, bitstream, zerror, packagemerge, strutils

type
  HuffmanTree = object
    tree2d, tree1d: seq[int]
    lengths: seq[int] #the lengths of the codes of the 1d-tree
    maxBitLen: int    #maximum number of bits a single code can get
    numCodes: int     #number of symbols in the alphabet = number of codes

# Second step for the ...makeFromLengths and ...makeFromFrequencies functions.
# numCodes, lengths and maxBitLen must already be filled in correctly.
# the tree representation used by the decoder.
proc make2D(tree: var HuffmanTree) =
  var nodeFilled = 0 #up to which node it is filled
  var treePos = 0    #position in the tree (1 of the numCodes columns)

  #32767 here means the tree2d isn't filled there yet
  tree.tree2d = newSeqWith(tree.numCodes * 2, 0x7FFF)

  #convert tree1d[] to tree2d[][]. In the 2D array, a value of 32767 means
  #uninited, a value >= numCodes is an address to another bit, a value < numCodes
  #is a code. The 2 rows are the 2 possible bit values (0 or 1), there are as
  #many columns as codes - 1.
  #A good huffmann tree has N * 2 - 1 nodes, of which N - 1 are internal nodes.
  #Here, the internal nodes are stored (what their 0 and 1 option point to).
  #There is only memory for such good tree currently, if there are more nodes
  #(due to too long length codes), error 55 will happen

  for n in 0.. <tree.numCodes: #the codes
    let len = tree.lengths[n]
    for i in 0.. <len: #the bits for this code
      let bit = (tree.tree1d[n] shr (len - i - 1)) and 1
      let branch = 2 * treePos + bit
      #oversubscribed, see comment in lodepng_error_text
      if treePos > 0x7FFFFFFF or treePos + 2 > tree.numCodes:
        nzerror(ERR_OVERSUBSCRIBED)

      if tree.tree2d[branch] != 0x7FFF: #not yet filled in
        treePos = tree.tree2d[branch] - tree.numCodes
        continue

      if i + 1 < len:
        #put address of the next step in here, first that address has to be found of course
        #(it's just nodeFilled + 1)...
        inc(nodeFilled)
        #addresses encoded with numCodes added to it
        tree.tree2d[branch] = nodeFilled + tree.numCodes
        treePos = nodeFilled
        continue

      #last bit
      tree.tree2d[branch] = n #put the current code in it
      treePos = 0 #start from root again

  tree.tree2d.applyIt(if it == 0x7FFF: 0 else: it) #remove possible remaining 32767's

proc make1D(tree: var HuffmanTree) =
  tree.tree1d = newSeq[int](tree.numCodes)
  var blCount = newSeq[int](tree.maxBitLen + 1)
  var nextCode = newSeq[int](tree.maxBitLen + 1)

  #step 1: count number of instances of each code length
  for len in tree.lengths: inc blCount[len]

  #step 2: generate the nextCode values
  for bits in 1..tree.maxBitLen:
    nextCode[bits] = (nextCode[bits - 1] + blCount[bits - 1]) shl 1

  #step 3: generate all the codes
  for n in 0..tree.numCodes-1:
    let len = tree.lengths[n]
    if len != 0:
      tree.tree1d[n] = nextCode[len]
      inc nextCode[len]

# given the code lengths (as stored in the compressed data),
# generate the tree as defined by Deflate.
# maxBitLen is the maximum bits that a code in the tree can have.
proc makeFromLengths*(input: openArray[int], maxBitLen: int): HuffmanTree =
  result.lengths   = @input
  result.numCodes  = input.len #number of symbols
  result.maxBitLen = maxBitLen
  result.make1D
  result.make2D

type
  HDC = object
    symbol: int
    len: int

  HDTree = object
    tree: seq[HDC]
    maxCodes: int
    maxBit: int
    
proc makeMask(maskLen: int): int =
  let len = sizeof(int) * 8
  let maskDist = len - maskLen
  result = ((not 0) shl maskDist) shr maskDist

const MASUKU_LENU = 9

proc makeFromLengths2*(input: openArray[int], maxBitLen: int): HDTree =
  var tree: HuffmanTree
  tree.lengths   = @input
  tree.numCodes  = input.len #number of symbols
  tree.maxBitLen = maxBitLen
  tree.make1D

  let maskLen = MASUKU_LENU
  let mask = makeMask(maskLen)
  var lut = newSeqWith(mask+1, HDC(symbol: -1, len: -1))

  let numCodes = tree.numCodes
  var maxBit = 0
  var maxCodes = 0
  var codes = newSeq[int](numCodes)
  for i in 0.. <numCodes:
    var code = tree.tree1d[i]
    var inv = 0
    let len = tree.lengths[i]
    if len > maxBit: maxBit = len
    if len != 0 and i > maxCodes:
      maxCodes = i
    for x in 0.. <len:
      inv = inv or ((code shr (len - 1 - x)) and 1) shl x
    codes[i] = inv

  inc maxCodes
  
  for i in 0.. <numCodes:
    let code = codes[i]
    let len = tree.lengths[i]
    if len != 0:
      let index = code and mask
      if (len - maskLen) <= 0:
        if lut[index].symbol != -1:
          echo "err: ", reverse(toBin(code, len)), " : ", lut[index].symbol, ", ", toBin(index, maskLen)
          break
        lut[index].symbol = i
        lut[index].len = len
        
        let nlen = makeMask(maskLen - len) + 1            
        for z in 0.. <nlen:
          let newIndex = index or (z shl (len))
          #if i == 'r'.ord:
            #echo toBin(newIndex, maskLen), ", ", z, ", ", toBin(z, maskLen)
          if lut[newIndex].symbol == -1:
            lut[newIndex].symbol = i
            lut[newIndex].len = len 
          
      else:        
        var e = lut[index].addr
        if e.symbol < maxCodes:
          let oldLen = lut.len
          let newLen = oldLen + makeMask(maxBit - maskLen) + 1
          e.symbol = maxCodes + len - maskLen
          e.len = oldLen
          #if i == 'Y'.ord: 
          #  echo "AA len: ", len
          #  echo "index: ", index
          #  echo "index: ", toBin(index, maskLen)
          #  echo "symbol: ", e.symbol

          lut.setLen(newLen)
          for j in oldLen.. <newLen:
            lut[j].symbol = -1
            lut[j].len = -1

        #if e.symbol == 124:
        #  echo "i: ", i
        #  echo "i.chr: ", i.chr
        
        if len == maxBit:
          let newIndex = e.len + (code shr maskLen)
          lut[newIndex].symbol = i
          lut[newIndex].len = len - maskLen
        else:
          let zlen = len - maskLen        
          let nlen = makeMask(maxBit - maskLen - zlen) + 1
          let zIndex = e.len + (code shr maskLen)
          #if i == 'Y'.ord:
          #  echo "code: ", toBin(code, len)
          #  echo "zlen: ", zlen
          #  echo "nlen: ", nlen
          #  echo "e.len: ", e.len, ", ", toBin(e.len, maxBit)
          #  echo "zIndex: ", zIndex, ", ", toBin(zIndex, maxBit)
          #  echo "lut.len: ", lut.len
          for z in 0.. <nlen:
            let newIndex = zIndex or (z shl (zlen))
            #if i == 'Y'.ord:
              #echo "newIndex: ", newIndex, ", ", toBin(newIndex, maxBit)
                
        #echo newIndex, ", ", lut.len
        #if i == 'Y'.ord: 
        #  echo "index: ", index
        #  echo "e.len: ", e.len
        #  echo "newIndex: ", newIndex
        #  echo "code: ", toBin(code shr maskLen, len - maskLen)
        #  echo "s.symbol: ", e.symbol
        #  echo "ss: ", maxCodes + len - maskLen
        #  echo "maxCodes: ", maxCodes
        #  echo "tree.len: ", tree.lengths[i]
        #  echo "len: ", len - maskLen
            if lut[newIndex].symbol == -1:
              lut[newIndex].symbol = i
              lut[newIndex].len = len - maskLen
  
  #for i in 0.. <numCodes:
  #  let code = codes[i]
  #  let len = tree.lengths[i]
  #  if len != 0 and len < maskLen:
  #    var index = code and mask
                   
                    
  result.tree = lut
  result.maxCodes = maxCodes
  result.maxBit = maxBit
  #for i in 0.. <lut.len:
  # if lut[i].symbol >= maxCodes:
  #   echo i, ", ", reverse(toBin(i, maskLen)), ", ", lut[i].symbol
  # elif lut[i].symbol == -1:
  #   echo i, ", ", reverse(toBin(i, maskLen)), ", ", lut[i].symbol
  # else:
  #   echo i, ", ", reverse(toBin(i, maskLen)), ", ", lut[i].symbol.chr

proc trimFreq(freq: openArray[int], minCodes: int): seq[int] =
  var numCodes = freq.len
  while(freq[numCodes - 1] == 0) and (numCodes > minCodes):
    dec numCodes #trim zeroes

  result = newSeq[int](numCodes)
  for i in 0.. <numCodes: result[i] = freq[i]

#Create the Huffman tree given the symbol frequencies
proc makeFromFrequencies*(input: openArray[int], minCodes, maxBitLen: int, algo: PM_ALGO): HuffmanTree =
  let freq = trimFreq(input, minCodes)
  let numCodes = freq.len
  result.maxBitLen = maxBitLen
  result.numCodes  = numCodes #number of symbols
  result.lengths   = codeLengths(freq, maxBitLen, algo)
  result.make1D

#returns the code, or (unsigned)(-1) if error happened
#inbitLength is the length of the complete buffer, in bits (so its byte length times 8)
proc decodeSymbol*(s: var BitStream, tree: HuffmanTree, inbitLength: int): int =
  var treePos = 0

  while true:
    if s.bitPointer >= inbitLength:
      nzerror(ERR_NO_END_CODE) #end of input memory reached without endcode

    #decode the symbol from the tree. The "readBitFromStream" code is inlined in
    #the expression below because this is the biggest bottleneck while decoding
    let ct = tree.tree2d[(treePos shl 1) + s.readBit]
    inc s.bitPointer
    if ct < tree.numCodes: return ct #the symbol is decoded, return it
    else: treePos = ct - tree.numCodes #symbol not yet decoded, instead move tree position

    if treePos >= tree.numCodes: #it appeared outside the codetree
      nzerror(ERR_WRONG_JUMP_OUTSIDE_OF_TREE)

proc decodeSymbol*(s: var BitStream, tree: HDTree, inbitLength: int): int =
  let maskLen = MASUKU_LENU

  if s.bitPointer >= inbitLength:
    #echo s.bitPointer
    #echo inbitLength
    nzerror(ERR_NO_END_CODE) #end of input memory reached without endcode

  var index = s.readBitsFromStream(maskLen)
  
  var code = tree.tree[index].symbol
  var len = tree.tree[index].len

  if code >= 0 and code < tree.maxCodes:
    #if code == 'a'.ord:
      #echo "BB: ", reverse(toBin(index, maskLen))
      
    #echo "a: ", len
    #stdout.write(reverse(toBin(index, len)))
    #stdout.write(" ")
  
    dec(s.bitPointer, maskLen - len)
    return code

  #let nlen = code - tree.maxCodes
  let newIndex = s.readBitsFromStream(tree.maxBit - maskLen)
  
  #if index == 0x7F:
  #  echo "\ncode: ", code
  #  echo "len: ", len
  #  echo "nlen: ", nlen
  #  echo "newIndex: ", nlen
  #echo "b"
  #stdout.write(reverse(toBin(index, maskLen)))
  #stdout.write(reverse(toBin(newIndex, tree.maxBit - maskLen)))
  #stdout.write(" ")
  
  code = tree.tree[newIndex + len].symbol
  dec(s.bitPointer, (tree.maxBit - maskLen) - tree.tree[newIndex + len].len)
  
  #if code == 'a'.ord:
    #echo reverse(toBin(index, maskLen)), ", ", index, ", ", newIndex, ", ", len
  return code

proc getCode*(tree: HuffmanTree, index: int): int =
  result = tree.tree1d[index]

proc getLength*(tree: HuffmanTree, index: int): int =
  result = tree.lengths[index]

proc getNumCodes*(tree: HuffmanTree): int = tree.numCodes

proc getLengths*(tree: HuffmanTree): seq[int] = tree.lengths