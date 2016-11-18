type
  HDE = object
    symbol: int
    len: int

  HDTree = object
    tree: seq[HDE]
    maxCodes: int
    maxBit: int
    
  HETree = object
    tree1d: seq[int]
    lengths: seq[int] #the lengths of the codes of the 1d-tree
    maxBitLen: int    #maximum number of bits a single code can get
    numCodes: int     #number of symbols in the alphabet = number of codes
    
proc makeMask(maskLen: int): int =
  let len = sizeof(int) * 8
  let maskDist = len - maskLen
  result = ((not 0) shl maskDist) shr maskDist

const MAGIC_MASK_LEN = 9

proc makeFromLengths2*(input: openArray[int], maxBitLen: int): HDTree =
  var tree: HuffmanTree
  tree.lengths   = @input
  tree.numCodes  = input.len #number of symbols
  tree.maxBitLen = maxBitLen
  tree.make1D

  let maskLen = MAGIC_MASK_LEN
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
          nzerror(ERR_INTERNAL)
          break
        lut[index].symbol = i
        lut[index].len = len
        
        let nlen = makeMask(maskLen - len) + 1            
        for z in 0.. <nlen:
          let newIndex = index or (z shl (len))          
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
          lut.setLen(newLen)
          for j in oldLen.. <newLen:
            lut[j].symbol = -1
            lut[j].len = -1
        
        if len == maxBit:
          let newIndex = e.len + (code shr maskLen)
          lut[newIndex].symbol = i
          lut[newIndex].len = len - maskLen
        else:
          let zlen = len - maskLen        
          let nlen = makeMask(maxBit - maskLen - zlen) + 1
          let zIndex = e.len + (code shr maskLen)
          for z in 0.. <nlen:
            let newIndex = zIndex or (z shl (zlen))
            if lut[newIndex].symbol == -1:
              lut[newIndex].symbol = i
              lut[newIndex].len = len - maskLen

  result.tree = lut
  result.maxCodes = maxCodes
  result.maxBit = maxBit
  
proc decodeSymbol*(s: var BitStream, tree: HDTree, inbitLength: int): int =
  let maskLen = MAGIC_MASK_LEN

  if s.bitPointer >= inbitLength:
    nzerror(ERR_NO_END_CODE) #end of input memory reached without endcode

  var index = s.readBitsFromStream(maskLen)
  var code = tree.tree[index].symbol
  var len = tree.tree[index].len

  if code >= 0 and code < tree.maxCodes:
    dec(s.bitPointer, maskLen - len)
    return code

  let nlen = tree.maxBit - maskLen
  let newIndex = s.readBitsFromStream(nlen) + len
  code = tree.tree[newIndex].symbol
  if code < 0:
    nzerror(ERR_BAD_CODE_OR_WRONG_TABLE)
    
  dec(s.bitPointer, nlen - tree.tree[newIndex].len)
  return code