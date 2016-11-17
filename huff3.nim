import heapqueue

type
  Node = ref object
    data: int
    freq: int
    left: Node
    right: Node

  Pair = tuple[data, freq: int]

proc newNode(data: int, freq: int): Node =
  new(result)
  result.left = nil
  result.right = nil
  result.data = data
  result.freq = freq

proc `<`*(a, b: Node): bool =
  result = a.freq < b.freq

proc printCodes(root: Node, str: string) =
  if root == nil: return
  
  if root.data != -1:
    echo root.data, ": ", str

  printCodes(root.left, str & "0")
  printCodes(root.right, str & "1")

proc HuffmanCodes(nodes: openArray[Pair]): Node =
  var left, right, top: Node

  var minHeap = newHeapQueue[Node]()
  for n in nodes:
    minHeap.push newNode(n.data, n.freq)

  while minHeap.len != 1:
    # Extract the two minimum freq items from min heap
    left = minHeap.pop()
    right = minHeap.pop()

    # Create a new internal node with frequency equal to the
    # sum of the two nodes frequencies. Make the two extracted
    # node as left and right children of this new node. Add
    # this node to the min heap
    # '-1' is a special value for internal nodes, not used
    top = newNode(-1, left.freq + right.freq)
    top.left = left
    top.right = right
    minHeap.push(top)

  result = minHeap.pop()

const a = [
  (1, 5),
  (2, 9),
  (3, 12),
  (4, 13),
  (5, 16),
  (6, 45)
  ]

let x = HuffmanCodes(a)
printCodes(x, "")