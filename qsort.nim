proc placePivot[T](a: var openArray[T], lo, hi: int): int =
  var pivot = lo #set pivot
  var switch_i = lo + 1
  let x = lo+1

  for i in x..hi: #run on array
    if cmpx(a[i], a[pivot]) <= 0:        #compare pivot and i
      swap(a[i], a[switch_i])      #swap i and i to switch
      swap(a[pivot], a[switch_i])  #swap pivot and i to switch
      inc pivot    #set current location of pivot
      inc switch_i #set location for i to switch with pivot
  result = pivot #return pivot location

proc quickSort[T](a: var openArray[T], lo, hi: int) =
  if lo >= hi: return #stop condition
  #set pivot location
  var pivot = placePivot(a, lo, hi)
  quickSort(a, lo, pivot-1) #sort bottom half
  quickSort(a, pivot+1, hi) #sort top half

proc quickSort[T](a: var openArray[T], length = -1) =
  var lo = 0
  var hi = if length < 0: a.high else: length-1
  quickSort(a, lo, hi)