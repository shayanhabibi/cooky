import cooky/spec
import cooky/utils/thinstring

export thinstring

import std/strutils
import std/parseutils
import std/times
import std/tables {.all.}

type
  CookyJar = TableRef[string, TableRef[string, seq[Cooky]]]
    ## Holds the cookies relating to a particular domain
    ## separated by paths

  CookyHeader* = concept x
    x.key is string
    x.value is string

  Cooky* = ref object
    name*: tstring # 8 bytes
    value*: tstring  # 8 bytes
    maxAge*: int64  # 8 bytes
    path*: tstring # 8 bytes
    domain*: tstring # 8 bytes
    # 1 byte:
    httpOnly* {.bitsize: 1.}: bool
    secure* {.bitsize: 1.}: bool
    sameSite* {.bitsize: 2.}: SameSite
    # Overflow available: 7 bytes - can perhaps generate an aligned
    # pointer to a table which can contain extra attributes that are found
    padding: array[7, char]

  Cookys* = distinct string

converter toString(x: Cookys): string = x.string
converter toCookys(x: string): Cookys = x.Cookys

proc newCooky(): Cooky =
  Cooky(maxAge: -1)
proc initCooky(): Cooky {.deprecated: "Use newCooky() instead".} =
  newCooky()

proc isCookySetter*(x: CookyHeader): bool {.inline.} =
  x.key.toLowerAscii() == "set-cookie"

proc parseCookyDate*(x: string): int64 =
  const tformatRFC1123 = initTimeFormat("ddd, dd-MMM-yyyy hh:mm:ss 'GMT'")
  const tformatRFC1123_spaces = initTimeFormat("ddd, dd MMM yyyy hh:mm:ss 'GMT'")

  var dt: DateTime

  template tryWith(tf: TimeFormat, body: untyped): untyped {.dirty.} =
    try:
      dt = x.parse(tf)
    except TimeParseError:
      body
    except:
      raise
  
  tryWith(tformatRFC1123):
    tryWith(tformatRFC1123_spaces):
      discard
  
  result = dt.toTime().toUnix()

template parseName(result: var Cooky, inp: string, pos, pos2: var int): bool =
  mixin skipUntil
  pos2 = skipUntil(inp, '=', pos)
  result.name.asign inp[pos ..< pos2]
  pos = pos2 + 1
  true

template parseValue(result: var Cooky, inp: string, pos, pos2: var int): bool =
  mixin skipUntil
  pos2 += skipUntil(inp, ';', pos)
  result.value.asign inp[pos .. pos2]
  pos = pos2 + 1
  true

template parseIdentifier(inp: string, pos, pos2: var int): string =
  mixin skipUntil
  pos2 += skipUntil(inp, {'=', ';'}, pos)
  let val = inp[pos .. pos2].toLowerAscii()
  pos = pos2 + 1
  val

template parseValue(inp: string, pos, pos2: var int): string =
  mixin skipUntil
  pos2 += skipUntil(inp, ';', pos)
  let val = inp[pos + 1 .. pos2]
  pos = pos2 + 1
  val

template parseValue(inp: string, pos, pos2: var int, default: string): string =
  mixin skipUntil
  pos2 += skipUntil(inp, ';', pos)
  if pos == pos2 + 1:
    default
  else:
    let val = inp[pos + 1 .. pos2]
    pos = pos2 + 1
    val

proc parseCooky*(x: CookyHeader): Cooky =
  assert x.value isnot "", "Set-Cookie had no value"

  result = initCooky()

  let inp = x.value
  var pos: int
  var pos2: int

  discard result.parseName(inp, pos, pos2) # boolean will be used
  # in future to control flow from progressing if no valid name
  discard result.parseValue(inp, pos, pos2) # or value is parsed

  while pos < inp.len:
    pos2 += skipWhile(inp, {';', ' '}, pos)
    pos = pos2 + 1

    if pos >= inp.len: break

    let ident = parseIdentifier(inp, pos, pos2)
    case ident
    of "expires":
      let val = parseValue(inp, pos, pos2)
      result.maxAge = parseCookyDate(val)
    of "max-age":
      let val = parseValue(inp, pos, pos2)
      result.maxAge = parseCookyDate(val)
    of "domain":
      let val = parseValue(inp, pos, pos2)
      result.domain.asign val
    of "path":
      let val = parseValue(inp, pos, pos2, "/")
      result.path.asign val
    of "secure":
      result.secure = true
    of "httponly":
      result.httpOnly = true
    of "samesite":
      let val = parseValue(inp, pos, pos2)
      result.sameSite = parseEnum[SameSite](val)
    else:
      discard parseValue(inp, pos, pos2)
      echo "Found unexpected attribute in Set-Cookie header: ", ident

#[
  CookyJar requires lower level implementation hacks to make it as efficient
  as possible
]#

import std/hashes
import std/math
import std/algorithm
import std/importutils

privateAccess(Table)
template maxHash(t): untyped = high(t.data)
template dataLen(t): untyped = len(t.data)

include std/tableimpl

proc newCookyJar*(): CookyJar =
  result = newTable[string, TableRef[string, seq[Cooky]]]()

proc cRawGetDeepImpl[X, A](t: X, key: A, hc: var Hash): int {.inline.} =
  ## Same as one in tableimpl but without the hash gen
  var h: Hash = hc and maxHash(t)
  while isFilled(t.data[h].hcode):
    h = nextTry(h, maxHash(t))
  result = h
  
proc incl*(cj: CookyJar, c: Cooky) =
  var hc: Hash
  var hcPath: Hash
  var idxDomain = rawGet(cj[], c.domain, hc)
  if idxDomain < 0:
    if mustRehash(cj[]):
      enlarge(cj[])
    idxDomain = cRawGetDeepImpl(cj[], c.domain, hc)
    let nt = newTable[string, seq[Cooky]]()
    rawInsert(cj[], cj[].data, $c.domain, nt, hc, idxDomain)
    inc(cj[].counter)

  var tb = cj[].data[idxDomain].val

  var idxPath = rawGet(tb[], c.path, hcPath)
  if idxPath < 0:
    if mustRehash(tb[]):
      enlarge(tb[])
    idxPath = cRawGetDeepImpl(tb[], c.path, hcPath)
    rawInsert(tb[], tb[].data, $c.path, newSeq[Cooky](), hcPath, idxPath)
    inc(tb[].counter)
  
  template sq: untyped = tb[].data[idxPath].val
  let idx = sq.find(c)
  if idx >= 0:
    sq[idx] = c
  else:
    sq.add c