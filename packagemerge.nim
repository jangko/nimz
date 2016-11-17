import bpm, ccpm, ccpmheap

type
  PM_ALGO* = enum
    PM_CCPM
    PM_CCPMHEAP
    PM_BOUNDARY
    
proc codeLengths*(freq: openArray[int], maxBitLen: int, algo: PM_ALGO): seq[int] =
  case algo
  of PM_CCPM: result = ccpm.codeLengths(freq, maxBitLen)
  of PM_CCPMHEAP: result = ccpmheap.codeLengths(freq, maxBitLen)
  of PM_BOUNDARY: result = bpm.codeLengths(freq, maxBitLen)