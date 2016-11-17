import zerror

type
  BitStream* = object
    bitPointer*: int
    data: string
    dataBitLen: int

# BitStream for deflate constructor
proc initBitStream*(): BitStream =
  result.bitPointer = 0
  result.dataBitLen = -1
  result.data = ""
  
# BitStream for inflate constructor
proc initBitStream*(input: string): BitStream =
  shallowCopy(result.data, input)
  result.dataBitLen = input.len * 8
  result.bitPointer = 0
    
proc readBit*(s: BitStream): int {.inline.} =
  assert(s.dataBitLen != -1)
  result = (ord(s.data[s.bitPointer shr 3]) shr (s.bitPointer and 0x07)) and 0x01

proc readBitFromStream*(s: var BitStream): int {.inline.} =
  assert(s.dataBitLen != -1)
  result = s.readBit
  inc s.bitPointer

proc readBitsFromStream*(s: var BitStream, nbits: int): int =
  assert(s.dataBitLen != -1)
  for i in 0..nbits-1:
    inc(result, s.readBit shl i)
    inc s.bitPointer

proc readBitsSafe*(s: var BitStream, nbits: int): int =
  assert(s.dataBitLen != -1)
  if s.bitPointer + nbits > s.dataBitLen:
    nzerror(ERR_BIT_POINTER_JUMP_PAST_MEMORY)

  for i in 0..nbits-1:
    inc(result, s.readBit shl i)
    inc s.bitPointer

proc readInt16*(s: var BitStream): int =
  assert(s.dataBitLen != -1)
  #go to first boundary of byte
  while (s.bitPointer and 0x7) != 0: inc s.bitPointer
  var p = s.bitPointer div 8 #byte position
  if p + 2 >= s.data.len: nzerror(ERR_BIT_POINTER_JUMP_PAST_MEMORY)
  result = ord(s.data[p]) + 256 * ord(s.data[p + 1])
  inc(s.bitPointer, 16)

proc getBytePosition*(s: var BitStream): int =
  result = s.bitPointer div 8 #byte position

proc readByte*(s: var BitStream): int =
  assert(s.dataBitLen != -1)
  while (s.bitPointer and 0x7) != 0: inc s.bitPointer
  var p = s.bitPointer div 8 #byte position
  if p + 1 >= s.data.len: nzerror(ERR_BIT_POINTER_JUMP_PAST_MEMORY)
  result = ord(s.data[p])
  inc(s.bitPointer, 8)

proc `|=`(a: var char, b: char) {.inline.} =
  a = chr(ord(a) or ord(b))

proc addBitToStream*(s: var BitStream, bit: int) =
  assert(s.dataBitLen == -1)
  #add a new byte at the end
  if (s.bitPointer and 0x07) == 0: s.data.add chr(0)
  #earlier bit of huffman code is in a lesser significant bit of an earlier byte
  s.data[s.data.len - 1] |= chr(bit shl (s.bitPointer and 0x07))
  inc s.bitPointer

proc addBitsToStream*(s: var BitStream, value: int, nbits: int) =
  assert(s.dataBitLen == -1)
  for i in 0..nbits-1:
    s.addBitToStream((value shr i) and 1)

proc addBitsToStreamReversed*(s: var BitStream, value: int, nbits: int) =
  assert(s.dataBitLen == -1)
  for i in 0..nbits-1:
    s.addBitToStream((value shr (nbits - 1 - i)) and 1)