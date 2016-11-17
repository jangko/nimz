import huff4, packagemerge, bitstream

const sampleString = "this is an example for huffman encoding$"

var freq: array[256, int]
for c in sampleString:
  inc freq[c.ord]
  
let tree = makeFromFrequencies(freq, freq.len, 15, PM_BOUNDARY)
var bits = initBitStream()

for c in sampleString:
  bits.addBitsToStreamReversed(tree.getCode(c.ord), tree.getLength(c.ord))

let bitLen = bits.getBitLen()  
var input = initBitStream(bits.getData)
let codeTree = makeFromLengths(tree.getLengths(), 15)

assert(codeTree.getNumCodes == tree.getNumCodes)
assert(codeTree.getLengths == tree.getLengths)

var output = ""
while true:
  let code = decodeSymbol(input, codeTree, bitLen)
  if code == '$'.ord: break
  output.add chr(code)
  
echo output
echo sampleString
  