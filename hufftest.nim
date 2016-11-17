import huff4, packagemerge, bitstream, strutils

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
let codeTree = makeFromLengths2(tree.getLengths(), 15)

#assert(codeTree.getNumCodes == tree.getNumCodes)
#assert(codeTree.getLengths == tree.getLengths)

proc reverse(s: string): string =
  result = newStringOfCap(s.len)
  for i in countdown(s.len-1, 0):
    result.add s[i]
    
let numCodes = tree.getNumCodes()
for i in 0.. <numCodes:
  if tree.getLength(i) != 0:
    echo reverse(toBin(tree.getCode(i), tree.getLength(i))), ", ", i.chr
    
var output = ""
var bp = input.bitPointer
while true:
  let code = decodeSymbol(input, codeTree, bitLen)
  echo code.chr
  echo (input.bitPointer - bp)
  bp = input.bitPointer
  if code == '$'.ord: break
  output.add chr(code)
  
echo output
echo sampleString
  

