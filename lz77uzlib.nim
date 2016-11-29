import lz77util

const
  HASH_BITS = 12
  HASH_SIZE = 1 shl HASH_BITS

  # Minimum and maximum length of matches to look for, inclusive
  MIN_MATCH = 3
  MAX_MATCH = 258

  # Max offset of the match to look for, inclusive
  MAX_OFFSET = 32768

# This is hash function from liblzf
proc HASH(p: cstring): int {.inline.} =
  let v = (p[0].ord shl 16) or (p[1].ord shl 8) or p[2].ord
  result = ((v shr (3*8 - HASH_BITS)) - v) and (HASH_SIZE - 1)

proc compare(a, b: cstring, len: int): bool =
  result = true
  for i in 0.. <len:
    if a[i] != b[i]: return false

proc LZ77Encode*(data: cstring, slen: int): seq[int16] =
  var hashTable: array[HASH_SIZE, int]
  var topIdx = slen - MIN_MATCH
  var srcIdx = 0
  var src = data
  result = @[]

  while srcIdx < topIdx:
    let h = HASH(src[srcIdx].addr)
    let bucket = h and (HASH_SIZE - 1)
    var subIdx = hashTable[bucket]
    hashTable[bucket] = srcIdx

    if subIdx > 0 and srcIdx > subIdx and (srcIdx - subIdx) <= MAX_OFFSET and
       compare(src[srcIdx].addr, src[subIdx].addr, MIN_MATCH):
         inc(srcIdx, MIN_MATCH)
         var matchIdx = subIdx + MIN_MATCH
         var len = MIN_MATCH
         while src[srcIdx] == src[matchIdx] and len < MAX_MATCH:
           inc srcIdx
           inc matchIdx
           inc len

         let distance = srcIdx - len - subIdx
         result.addLengthDistance(len, distance)
         #echo len, ": ", distance
    else:
      #echo "lit: ", src[srcIdx]
      result.add int16(src[srcIdx])
      inc srcIdx

  # Process buffer tail, which is less than MIN_MATCH
  # (and so it doesn't make sense to look for matches there)
  inc(topIdx, MIN_MATCH)
  while srcIdx < topIdx:
    #echo "lit: ", src[srcIdx]
    result.add int16(src[srcIdx])
    inc srcIdx
