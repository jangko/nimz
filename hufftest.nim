import huff_basic, packagemerge, bitstream, strutils

#const sampleString = "metihello tobulinum Lorem Ipsum Dolor Sit amtculae probkulc\n\r\t\b opqiscis man\x15\x18uhutelatzxma abcs234211/[]ASQWECMPPQWW@M~>?" & '\x00'
#let sampleString = readFile(".gitignore") & '\x00'
let sampleString = readFile("sample.txt") & '\x00'
#let sampleString = readFile("out.txt") & '\x00'

var freq: array[256, int]
for c in sampleString:
  inc freq[c.ord]
  
let tree = makeFromFrequencies(freq, freq.len, 15, PM_BOUNDARY)
var bits = initBitStream()
    
for c in sampleString:
  bits.addBitsToStreamReversed(getCode(tree, c.ord), getLength(tree,c.ord))
  
let bitLen = bits.getBitLen()  
var input = initBitStream(bits.getData)
let codeTree = makeFromLengths(getLengths(tree), 15)
 
#assert(codeTree.getNumCodes == tree.getNumCodes)
#assert(codeTree.getLengths == tree.getLengths)

var output = ""
while true:
  let code = decodeSymbol(input, codeTree, bitLen)
  output.add chr(code)
  if code == '\x00'.ord: break

assert(output == sampleString)
echo "OK"

