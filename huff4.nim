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

proc getCode*(tree: HuffmanTree, index: int): int =
  result = tree.tree1d[index]

proc getLength*(tree: HuffmanTree, index: int): int =
  result = tree.lengths[index]

proc getNumCodes*(tree: HuffmanTree): int = tree.numCodes

proc getLengths*(tree: HuffmanTree): seq[int] = tree.lengths