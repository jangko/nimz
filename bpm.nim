import algorithm, sequtils

type
  NZError = ref object of Exception
  Node = object
    weight: int
    index: int
    
  PNode = ref object
    weight: int
    index: int
    tail: PNode
    
  TChains = array[2, seq[PNode]]

proc toLeaves(freq: openArray[int]): seq[Node] =
  result = @[]
  for i in 0.. <freq.len:
    if freq[i] > 0: result.add(Node(weight: freq[i], index: i))

proc initLengths(numCodes: int): seq[int] =
  result = newSeqWith(numCodes, 0)

proc cmp(a, b: Node): int =
  if a.weight < b.weight: return -1
  if a.weight > b.weight: return 1
  result = if a.index < b.index : 1 else: -1

proc createNode(weight, index: int, tail: PNode = nil): PNode =
  result = PNode(weight: weight, index: index, tail: tail)

proc initChains(leaves: seq[Node], maxBitLen: int): TChains =
  var node0 = createNode(leaves[0].weight, 1)
  var node1 = createNode(leaves[1].weight, 2)
  result[0] = newSeqWith(maxBitLen, node0)
  result[1] = newSeqWith(maxBitLen, node1)

proc boundaryPM(chains: var TChains, leaves: seq[Node], numSymbols, c: int, final: bool) =
  let oldChain = chains[1][c]
  let lastIndex = oldChain.index

  if c == 0:
    if lastIndex >= numSymbols: return
    chains[0][c] = oldChain
    chains[1][c] = createNode(leaves[lastIndex].weight, lastIndex + 1)
  else:
    # sum of the weights of the head nodes of the previous lookahead chains.
    let sum = chains[0][c - 1].weight + chains[1][c - 1].weight
    chains[0][c] = oldChain
    if (lastIndex < numSymbols) and (sum > leaves[lastIndex].weight):
      chains[1][c] = createNode(leaves[lastIndex].weight, lastIndex + 1, oldChain.tail)
      return
    chains[1][c] = createNode(sum, lastIndex, chains[1][c - 1])
    # in the end we are only interested in the chain of the last list, so no
    # need to recurse if we're at the last one (this gives measurable speedup)
    if not final:
      boundaryPM(chains, leaves, numSymbols, c - 1, final)
      boundaryPM(chains, leaves, numSymbols, c - 1, final)

proc extractBitLen(node: PNode, leaves: seq[Node], lengths: var seq[int]) =
  var n = node
  while n != nil:
    for i in 0.. <n.index:
      inc lengths[leaves[i].index]
    n = n.tail

proc codeLengths*(freq: openArray[int], maxBitLen: int): seq[int] =
  let numCodes = freq.len

  if numCodes == 0: raise NZError()
  if (1 shl maxBitLen) < numCodes: raise NZError()

  var leaves = freq.toLeaves
  let numSymbols = leaves.len
  var lengths = initLengths(numCodes)

  if numSymbols == 0:
    lengths[0] = 1
    lengths[1] = 1
  elif numSymbols == 1:
    lengths[leaves[0].index] = 1
    lengths[if leaves[0].index == 0: 1 else: 0] = 1
  else:
    leaves.sort(cmp)
    var chains = initChains(leaves, maxBitLen)

    let bpmRun = 2 * numSymbols - 2
    for i in 2.. <bpmRun:
      let final = i == bpmRun - 1
      boundaryPM(chains, leaves, numSymbols, maxBitLen - 1, final)

    extractBitLen(chains[1][maxBitLen-1], leaves, lengths)

  result = lengths