import sequtils, heapqueue

type
  NZError = ref object of Exception

  #A coin, this is the terminology used for the package-merge algorithm and the
  #coin collector's problem. This is used to generate the huffman tree.
  #A coin can be multiple coins (when they're merged)
  Coin = ref object
    symbols: seq[int]
    weight: float #the sum of all weights in this coin

  Coins = HeapQueue[Coin]

proc `<`*(a, b: Coin): bool =
  result = a.weight < b.weight

proc package(a, b: Coin): Coin =
  a.symbols.add b.symbols
  a.weight += b.weight
  result = a

proc appendSymbolCoins(coins: var Coins, freq: openArray[int], sum: int) =
  for i in 0.. <freq.len:
    if freq[i] == 0: continue  #only include symbols that are present
    coins.push Coin(weight: freq[i]/sum, symbols: @[i])

proc merge(coins: var Coins, numSymbols: int): Coins =
  result = HeapQueue[Coin](newSeqOfCap[Coin](coins.len div 2 + numSymbols))
  # fill in the packaged coins of the previous row
  for i in countup(0, coins.len-2, 2):
    # package two coin with smallest weight into new coin
    result.push package(coins.pop(), coins.pop())

proc extractBitLen(coins: Coins, lengths: var seq[int]) =
  for coin in seq[Coin](coins).items:
    for sym in coin.symbols:
      inc lengths[sym]

proc codeLengths*(freq: openArray[int], maxBitLen: int): seq[int] =
  let numCodes = freq.len

  if numCodes == 0:
    raise NZError()

  var numSymbols = 0
  var freqSum = 0
  for f in freq:
    if f == 0: continue
    inc numSymbols
    inc(freqSum, f)

  #ensure at least two present symbols. There should be at least one symbol
  #according to RFC 1951 section 3.2.7. To decoders incorrectly require two. To
  #make these work as well ensure there are at least two symbols. The
  #Package-Merge code below also doesn't work correctly if there's only one
  #symbol, it'd give it the theoritical 0 bits but in practice zlib wants 1 bit

  var lengths = newSeqWith(numCodes, 0)
  if numSymbols == 0:
    lengths[0] = 1
    lengths[1] = 1 #note that for RFC 1951 section 3.2.7, only lengths[0] = 1 is needed
  elif numSymbols == 1:
    for i in 0.. <numCodes:
      if freq[i] != 0:
        lengths[i] = 1
        lengths[if i == 0: 1 else: 0] = 1
        break
  else:
    # Package-Merge algorithm represented by coin collector's problem
    # For every symbol, maxBitLen coins will be created
    var coins = HeapQueue[Coin](newSeqOfCap[Coin](numSymbols))

    # first row, lowest denominator
    coins.appendSymbolCoins(freq, freqSum)

    for j in 1..maxBitLen: #each of the remaining rows
      coins = coins.merge(numSymbols)
      # fill in all the original symbols again
      if j < maxBitLen: coins.appendSymbolCoins(freq, freqSum)

    # calculate the lengths of each symbol,
    # as the amount of times a coin of each symbol is used
    extractBitLen(coins, lengths)

  result = lengths