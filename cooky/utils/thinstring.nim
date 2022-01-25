import hashes

type
  tstring* = object
    pntr: pointer
    ## basically cstring but captured by GC

proc `=destroy`*(t: var tstring) =
  if not t.pntr.isNil:
    deallocShared(t.pntr)

proc asign*(t: var tstring, str: string) =
  let strlen = str.len
  if t.pntr.isNil:
    t.pntr = allocShared(strlen + 1)
  else:
    t.pntr = t.pntr.reallocShared(strlen + 1)
  copyMem(t.pntr, unsafeAddr str[0], strlen)
  let terminator = cast[ptr char](
    cast[uint](t.pntr) + cast[uint](strlen)
  )
  terminator[] = '\x00'

converter toCString*(t: tstring): cstring = cast[cstring](t.pntr)

proc hash*(t: tstring): Hash =
  toCString(t).hash()

proc `$`*(t: tstring): string = $t.toCString