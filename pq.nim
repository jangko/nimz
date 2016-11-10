type
  PriorityQueue[T] = ref object
    elements: seq[T]

proc newPriorityQueue[T](): PriorityQueue[T] =
  new(result)
  result.elements = @[]

proc len[T](p: PriorityQueue[T]): int =
  result = p.elements.len
  
proc exchange[T](p: PriorityQueue[T], source, target: int) =
  swap(p.elements[source], p.elements[target])
    
proc bubbleUp[T](p: PriorityQueue[T], index: int) =
  let parentIndex = index div 2

  # return if we reach the root element
  if index <= 1: return

  # or if the parent is already greater than the child
  if p.elements[parentIndex] >= p.elements[index]: return

  # otherwise we exchange the child with the parent
  p.exchange(index, parentIndex)

  # and keep bubbling up
  p.bubbleUp(parentIndex)


proc add[T](p: PriorityQueue[T], element: T) =
  p.elements.add element
  # bubble up the element that we just added
  p.bubbleUp(p.elements.len - 1)


proc bubbleDown[T](p: PriorityQueue[T], index: int) =
  var childIndex = index * 2

  # stop if we reach the bottom of the tree
  if childIndex > p.elements.len - 1: return

  # make sure we get the largest child
  let notTheLastElement = childIndex < p.elements.len - 1
  if notTheLastElement:
    let leftElement = p.elements[childIndex]
    let rightElement = p.elements[childIndex + 1]  
    if (rightElement > leftElement):
      inc childIndex

  # there is no need to continue if the parent element is already bigger
  # then its children
  if p.elements[index] >= p.elements[childIndex]: return

  p.exchange(index, childIndex)

  # repeat the process until we reach a point where the parent
  # is larger than its children
  p.bubbleDown(childIndex)


proc pop[T](p: PriorityQueue[T]): T =
  if p.elements.len == 1:
    return p.elements.pop
    
  # exchange the root with the last element
  p.exchange(1, p.elements.len - 1)

  # remove the last element of the list
  result = p.elements.pop

  # and make sure the tree is ordered again
  p.bubbleDown(1)
  
var pq = newPriorityQueue[int]()
pq.add 11
pq.add 7
pq.add 13
pq.add 19
pq.add 45

while pq.len > 0:
  echo pq.pop