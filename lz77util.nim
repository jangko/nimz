const
  FIRST_LENGTH_CODE_INDEX* = 257
  LAST_LENGTH_CODE_INDEX* = 285

  #256 literals, the end code, some length codes, and 2 unused codes
  NUM_DEFLATE_CODE_SYMBOLS* = 288

  #the distance codes have their own symbols, 30 used, 2 unused
  NUM_DISTANCE_SYMBOLS* = 32
  #the code length codes.
  #0-15: code lengths,
  #16: copy previous 3-6 times,
  #17: 3-10 zeros,
  #18: 11-138 zeros

  NUM_CODE_LENGTH_CODES* = 19

  #the base lengths represented by codes 257-285
  LENGTHBASE* = [3, 4, 5, 6, 7, 8, 9, 10,
    11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51,
    59, 67, 83, 99, 115, 131, 163, 195, 227, 258]

  #the extra bits used by codes 257-285 (added to base length)
  LENGTHEXTRA* = [0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
    4, 4, 4, 4, 5, 5, 5, 5, 0]

  #the base backwards distances
  #(the bits of distance codes appear after
  #length codes and use their own huffman tree)
  DISTANCEBASE* = [1, 2, 3, 4, 5, 7, 9,
    13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513,
    769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]

  #the extra bits of backwards distances (added to base)
  DISTANCEEXTRA* = [0, 0, 0, 0, 1, 1, 2,
    2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8,
    8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

# search the index in the array, that has the largest value smaller than or equal to the given value,
# given array must be sorted (if no value is smaller, it returns the size of the given array)
proc searchCodeIndex(input: openArray[int], value: int): int =
  # linear search implementation
  # for i in 1..high(input):
  #   if input[i] > value: return i - 1
  # return input.len - 1

  # binary search implementation (not that much faster) (precondition: array_size > 0)
  var left  = 1
  var right = input.len - 1
  while left <= right:
    let mid = (left + right) div 2
    if input[mid] <= value: left = mid + 1 # the value to find is more to the right
    elif input[mid - 1] > value: right = mid - 1 # the value to find is more to the left
    else: return mid - 1
  result = input.len - 1

proc addLengthDistance*(values: var seq[int16], length, distance: int) =
  # values in encoded vector are those used by deflate:
  # 0-255: literal bytes
  # 256: end
  # 257-285: length/distance pair
  #  (length code, followed by extra length bits, distance code, extra distance bits)
  # 286-287: invalid

  let lengthCode    = searchCodeIndex(LENGTHBASE, length)
  let extraLength   = length - LENGTHBASE[lengthCode]
  let distanceCode  = searchCodeIndex(DISTANCEBASE, distance)
  let extraDistance = distance - DISTANCEBASE[distanceCode]

  values.add int16(lengthCode + FIRST_LENGTH_CODE_INDEX)
  values.add extraLength.int16
  values.add distanceCode.int16
  values.add extraDistance.int16