import sequtils, strutils, bitstream, zerror, packagemerge

type
  HuffmanNode = ref object
    code: int # -1 for non-leaf nodes
    zero: HuffmanNode
    one : HuffmanNode

  HuffmanRange = object
    endPoint: int
    bitLength: int
 
  TreeNode = object
    len: int
    code: int

  HuffmanTree = object    
    root: HuffmanNode
    tree: seq[TreeNode]
    
proc getBitLengthCount(maxBitLength: int, ranges: seq[HuffmanRange]): seq[int] =
  result = newSeqWith(maxBitLength + 1, 0)
  for n in 0.. <ranges.len:
    let k = ranges[ n ].endPoint - (if n > 0: ranges[ n - 1 ].endPoint else: -1)
    inc(result[ ranges[ n ].bitLength ], k)

proc getNextCode(maxBitLength: int, blCount: seq[int]): seq[int] =
  result = newSeqWith(maxBitLength + 1, 0)
  var code = 0
  for bits in 1..maxBitLength:
    code = ( code + blCount[ bits - 1 ] ) shl 1
    if blCount[ bits ] != 0:
      result[ bits ] = code
    
proc getTree(ranges: seq[HuffmanRange], nextCode: var seq[int]): seq[TreeNode] =
  let lastPoint = ranges[ ranges.len - 1 ].endPoint
  result = newSeqWith(lastPoint + 1, TreeNode(len: 0, code: 0))
  var activeRange = 0
  for n in 0..lastPoint:
    if n > ranges[ activeRange ].endPoint:
      inc activeRange
    if ranges[ activeRange ].bitLength != 0:
      result[ n ].len = ranges[ activeRange ].bitLength
      if result[ n ].len != 0:
        result[ n ].code = nextCode[ result[ n ].len ]
        inc nextCode[ result[ n ].len ]
    
proc make2D(ranges: seq[HuffmanRange], tree: seq[TreeNode]): HuffmanNode =
  var root = HuffmanNode(code: -1, zero: nil, one: nil)
  let lastPoint = ranges[ ranges.len - 1 ].endPoint
  
  for n in 0..lastPoint:
    var node = root
    if tree[ n ].len == 0: continue
    
    #echo n, ": ", toBin(tree[n].code, tree[n].len)
    
    for bits in countdown(tree[ n ].len, 1):
      if (tree[ n ].code and (1 shl (bits - 1))) != 0:
        if node.one == nil:
          node.one = HuffmanNode(code: -1, zero: nil, one: nil)          
        node = node.one
      else:
        if node.zero == nil:
          node.zero = HuffmanNode(code: -1, zero: nil, one: nil)          
        node = node.zero
    assert( node.code == -1 )
    node.code = n
    
  result = root
  
proc make1D(ranges: seq[HuffmanRange], maxBitLen: int): seq[TreeNode] =  
  let blCount  = getBitLengthCount(maxBitLen, ranges)
  var nextCode = getNextCode(maxBitLen, blCount)
  result       = getTree(ranges, nextCode)
  
proc trimFreq(freq: openArray[int], minCodes: int): seq[int] =
  var numCodes = freq.len
  while(freq[numCodes - 1] == 0) and (numCodes > minCodes):
    dec numCodes #trim zeroes

  result = newSeq[int](numCodes)
  for i in 0.. <numCodes: result[i] = freq[i]
  
proc buildRanges(lengths: openArray[int]): seq[HuffmanRange] =
  result = @[]
  let numCodes = lengths.len
  var prevLen = lengths[0]
  for i in 0.. <numCodes:
    if lengths[i] != prevLen:
      result.add HuffmanRange(endPoint: i-1, bitLength: prevLen)
      prevLen = lengths[i]
      
  if lengths[numCodes-1] != result[result.len-1].bitLength:
    result.add HuffmanRange(endPoint: numCodes-1, bitLength: lengths[numCodes-1])
    
proc makeFromFrequencies*(input: openArray[int], minCodes, maxBitLen: int, algo: PM_ALGO): HuffmanTree =
  let freq    = trimFreq(input, minCodes)  
  let lengths = codeLengths(freq, maxBitLen, algo)
  let ranges  = buildRanges(lengths)
  result.tree = make1D(ranges, maxBitLen)
  
proc makeFromLengths*(lengths: openArray[int], maxBitLen: int): HuffmanTree =
  let ranges  = buildRanges(lengths)
  result.tree = make1D(ranges, maxBitLen)
  result.root = make2D(ranges, result.tree)
    
  #echo lengths
  #for c in input:
  #  stdout.write c
  #  stdout.write ", "
  #stdout.write "\n"
  #echo ranges
  
  #result.maxBitLen = maxBitLen
  #result.numCodes  = numCodes #number of symbols
  #result.lengths   = codeLengths(freq, maxBitLen, algo)
  #result.make1D
  
proc decodeSymbol*(s: var BitStream, tree: HuffmanTree, inbitLength: int): int =
  var node = tree.root
  
  while true:
    if s.bitPointer >= inbitLength:
      nzerror(ERR_NO_END_CODE) #end of input memory reached without endcode
      
    if s.readBit != 0:
      node = node.one
    else:
      node = node.zero
    
    inc s.bitPointer
    if node.isNil:
      nzerror(ERR_BAD_CODE_OR_WRONG_TABLE)
      
    if node.code != -1:
      return node.code
      
proc getCode*(tree: HuffmanTree, index: int): int =
  result = tree.tree[index].code

proc getLength*(tree: HuffmanTree, index: int): int =
  result = tree.tree[index].len
  
proc getLengths*(tree: HuffmanTree): seq[int] = 
  result = newSeq[int](tree.tree.len)
  for i in 0.. <tree.tree.len:
    result[i] = tree.tree[i].len
