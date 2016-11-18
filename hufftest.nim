import huff4, packagemerge, bitstream, strutils

#const sampleString = "metihello tobulinum Lorem Ipsum Dolor Sit amtculae probkulc\n\r\t\b opqiscis man\x15\x18uhutelatzxma abcs234211/[]ASQWECMPPQWW@M~>?" & '\x00'
#let sampleString = readFile(".gitignore") & '\x00'
let sampleString = readFile("sample.txt") & '\x00'

var freq: array[256, int]
for c in sampleString:
  inc freq[c.ord]
  
let tree = makeFromFrequencies(freq, freq.len, 15, PM_BOUNDARY)
var bits = initBitStream()
    
#let numCodes = tree.getNumCodes()
#for i in 0.. <numCodes:
#  if tree.getLength(i) != 0:
#    echo toBin(tree.getCode(i), tree.getLength(i)),", ",i.chr, ", ", i
    
#echo "OUTPUT:"
for c in sampleString:
  bits.addBitsToStreamReversed(tree.getCode(c.ord), tree.getLength(c.ord))
#  stdout.write(toBin(tree.getCode(c.ord), tree.getLength(c.ord)))
#  stdout.write(" ")
#
#echo "GENL: "
let bitLen = bits.getBitLen()  
var input = initBitStream(bits.getData)
let codeTree = makeFromLengths2(tree.getLengths(), 15)

#assert(codeTree.getNumCodes == tree.getNumCodes)
#assert(codeTree.getLengths == tree.getLengths)

#echo ""
var output = ""
while true:
  let code = decodeSymbol(input, codeTree, bitLen)
  #stdout.write code.chr
  output.add chr(code)
  if code == '\x00'.ord: break

#echo output
assert(output == sampleString)
#echo output.len
#echo sampleString.len
#for i in 0.. <sampleString.len:
#  if output[i] != sampleString[i]:
#    echo "ERROR ", i, output[i], " ", sampleString[i]
#    break
echo "OK"

