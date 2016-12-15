type
  NZError = ref object of Exception
  ErrorType* = enum
    ERR_BIT_POINTER_JUMP_PAST_MEMORY,
    ERR_OVERSUBSCRIBED,
    ERR_WRONG_JUMP_OUTSIDE_OF_TREE,
    ERR_NO_END_CODE,
    ERR_INTERNAL,
    ERR_BAD_CODE_OR_WRONG_TABLE,
    ERR_WINDOW_SIZE_NOT_ALLOWED,
    ERR_WINDOW_SIZE_MUST_BE_POWER_OF_TWO,
    ERR_LAZY_MATCHING_IMPOSSIBLE,
    ERR_OVERFLOWN_OFFSET

const error_msg = [
  "bit pointer jumps past memory",
  "oversubscribed",
  "wrong jump outside of tree",
  "no end code",
  "internal error",
  "bad input code or wrong table construction",
  "window size smaller/larger than allowed",
  "window size must be power of two",
  "lazy matching at pos 0 is impossible",
  "too big (or overflown negative) offset"
  ]

proc newNZError(msg: string): NZError =
  new(result)
  result.msg = msg

proc nzerror*(e: ErrorType) =
  raise newNZError(error_msg[e.ord])