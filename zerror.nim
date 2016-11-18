type
  NZError = ref object of Exception
  ErrorType* = enum
    ERR_BIT_POINTER_JUMP_PAST_MEMORY,
    ERR_OVERSUBSCRIBED,
    ERR_WRONG_JUMP_OUTSIDE_OF_TREE,
    ERR_NO_END_CODE,
    ERR_INTERNAL

const error_msg = [
  "bit pointer jumps past memory",
  "oversubscribed",
  "wrong jump outside of tree",
  "no end code",
  "internal error"
  ]

proc newNZError(msg: string): NZError =
  new(result)
  result.msg = msg

proc nzerror*(e: ErrorType) =
  raise newNZError(error_msg[e.ord])