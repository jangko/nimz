import lz77util

const
  HASH_BITS = 12
  HASH_SIZE = 1 shl HASH_BITS

# This is hash function from liblzf
proc HASH(p: cstring): int {.inline.} =
  let v = (p[0].ord shl 16) or (p[1].ord shl 8) or p[2].ord
  result = ((v shr (3*8 - HASH_BITS)) - v) and (HASH_SIZE - 1)

proc compare(a, b: cstring, len: int): bool =
  result = true
  for i in 0.. <len:
    if a[i] != b[i]: return false

proc LZ77Encode*(opts: LZOpts, data: cstring, inSize: int): seq[int16] =
  let minMatch = opts.minMatch
  let windowSize = opts.windowSize
  var hashTable: array[HASH_SIZE, int]
  var topIdx = inSize - minMatch
  var srcIdx = 0
  var src = data
  result = @[]

  while srcIdx < topIdx:
    let h = HASH(src[srcIdx].addr)
    let bucket = h and (HASH_SIZE - 1)
    var subIdx = hashTable[bucket]
    hashTable[bucket] = srcIdx

    if subIdx > 0 and srcIdx > subIdx and (srcIdx - subIdx) <= windowSize and
       compare(src[srcIdx].addr, src[subIdx].addr, minMatch):
         inc(srcIdx, minMatch)
         var matchIdx = subIdx + minMatch
         var len = minMatch
         while src[srcIdx] == src[matchIdx] and len < MAX_MATCH:
           inc srcIdx
           inc matchIdx
           inc len

         let distance = srcIdx - len - subIdx
         result.addLengthDistance(len, distance)
    else:
      result.add int16(src[srcIdx])
      inc srcIdx

  # Process buffer tail, which is less than minMatch
  # (and so it doesn't make sense to look for matches there)
  inc(topIdx, minMatch)
  while srcIdx < topIdx:
    result.add int16(src[srcIdx])
    inc srcIdx
