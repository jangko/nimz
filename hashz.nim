import sequtils, lz77util

type
  NZHash* = object
    head*: seq[int]   #hash value to head circular pos
                     #can be outdated if went around window
    chain*: seq[int]  #circular pos to prev circular pos
    val*: seq[int]    #circular pos to hash value

    #TODO: do this not only for zeros but for any repeated byte. However for PNG
    #it's always going to be the zeros that dominate, so not important for PNG

    headz*: seq[int]  #similar to head, but for chainz
    chainz*: seq[int] #those with same amount of zeros
    zeros*: seq[int]  #length of zeros streak, used as a second hash chain

const
  # 3 bytes of data get encoded into two bytes. The hash cannot use more than 3
  # bytes as input because 3 is the minimum match length for deflate
  HASH_NUM_VALUES* = 65536
  HASH_BIT_MASK* = HASH_NUM_VALUES - 1
 
  
proc hashInit*(hash: var NZHash, windowSize: int) =
  hash.head   = newSeqWith(HASH_NUM_VALUES, -1)
  hash.val    = newSeqWith(windowSize, -1)
  hash.chain  = newSeq[int](windowSize)
  hash.zeros  = newSeq[int](windowSize)
  hash.headz  = newSeqWith(MAX_MATCH + 1, -1)
  hash.chainz = newSeq[int](windowSize)
  for i in 0.. <windowSize:
    hash.chain[i] = i
    hash.chainz[i] = i
    
# wPos = pos & (windowSize - 1)
proc updateHashChain*(hash: var NZHash, wPos, hashVal, numZeros: int) =
  hash.val[wPos] = hashVal
  if hash.head[hashVal] != -1: hash.chain[wPos] = hash.head[hashVal]
  hash.head[hashVal] = wPos

  hash.zeros[wPos] = numZeros
  if hash.headz[numZeros] != -1: hash.chainz[wPos] = hash.headz[numZeros]
  hash.headz[numZeros] = wPos

proc `^=`(a: var int, b: int) =
  a = a xor b

proc getHash*(data: cstring, size, pos: int): int =
  if pos + 2 < size:
    #simple shift and xor hash is used. Since the data of PNGs is dominated
    #by zeroes due to the filters, a better hash does not have a significant
    #effect on speed in traversing the chain, and causes more time spend on
    #calculating the hash.
    result ^= (ord(data[pos + 0]) shl 0)
    result ^= (ord(data[pos + 1]) shl 4)
    result ^= (ord(data[pos + 2]) shl 8)
  else:
    if pos >= size: return 0
    let amount = size - pos
    for i in 0..amount-1: result ^= (ord(data[pos + i]) shl (i * 8))

  result = result and HASH_BIT_MASK

proc countZeros*(data: cstring, size, pos: int): int =
  var dataPos = pos
  var dataEnd = min(dataPos + MAX_MATCH, size)
  while dataPos < dataEnd and data[dataPos] == chr(0): inc dataPos
  #subtracting two addresses returned as 32-bit number (max value is MAX_SUPPORTED_DEFLATE_LENGTH)
  result = dataPos - pos

