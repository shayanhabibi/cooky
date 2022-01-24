type
  SameSite* {.size: 1.} = enum
    None, Lax, Strict

template `+%`*(x: pointer, y: int): ptr char =
  cast[ptr char](
    cast[int](x) + y
  )
template `-%`*(x: pointer, y: int): ptr char =
  cast[ptr char](
    cast[int](x) - y
  )
