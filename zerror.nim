type
  NZError = ref object of Exception
  ErrorType* = enum
    ERR_BIT_POINTER_JUMP_PAST_MEMORY,
    ERR_OVERSUBSCRIBED

const error_msg = [
  "bit pointer jumps past memory",
  "oversubscribed"
  ]

proc newNZError(msg: string): NZError =
  new(result)
  result.msg = msg

proc nzerror*(e: ErrorType) =
  raise newNZError(error_msg[e.ord])