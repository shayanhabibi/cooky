import cooky/utils/thinstring
import cooky/cooky

import std/uri
import std/parseutils
import std/times
import std/strformat
import std/tables {.all.}
export tables.len
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

type
  CookyJar* = TableRef[string, TableRef[string, seq[Cooky]]]
    ## Holds the cookies relating to a particular domain
    ## separated by paths

proc newCookyJar*(): CookyJar =
  result = newTable[string, TableRef[string, seq[Cooky]]]()

proc cRawGetDeepImpl[X, A](t: X, key: A, hc: var Hash): int {.inline.} =
  ## Same as one in tableimpl but without the hash gen
  var h: Hash = hc and maxHash(t)
  while isFilled(t.data[h].hcode):
    h = nextTry(h, maxHash(t))
  result = h
  
proc incl*(cj: CookyJar, c: Cooky) =
  ## Includes the cooky into the cooky jar or replaces it if it found one
  ## with the same value
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

template cDelImpl(t: untyped, i: untyped) =
  let msk = maxHash(t)
  if i >= 0:
    dec(t.counter)
    block outer:
      while true:         # KnuthV3 Algo6.4R adapted for i=i+1 instead of i=i-1
        var j = i         # The correctness of this depends on (h+1) in nextTry
        var r = j         # though may be adaptable to other simple sequences.
        t.data[i].hcode = 0                     # mark current EMPTY
        t.data[i].key = default(typeof(t.data[i].key))
        t.data[i].val = default(typeof(t.data[i].val))
        while true:
          i = (i + 1) and msk            # increment mod table size
          if isEmpty(t.data[i].hcode):               # end of collision cluster; So all done
            break outer
          r = t.data[i].hcode and msk        # initial probe index for key@slot i
          if not ((i >= r and r > j) or (r > j and j > i) or (j > i and i >= r)):
            break
        when defined(js):
          t.data[j] = t.data[i]
        else:
          t.data[j] = move(t.data[i]) # data[j] will be marked EMPTY next loop

proc excl*(cj: CookyJar, c: Cooky) =
  var hc, hcPath: Hash
  var idxDomain, idxPath: int

  idxDomain = rawGet(cj[], c.domain, hc)
  if idxDomain < 0:
    return

  var tb = cj[].data[idxDomain].val
  
  idxPath = rawGet(tb[], c.path, hcPath)
  if idxPath < 0:
    return

  template sq: untyped = tb[].data[idxPath].val

  var delSeq: seq[int]
  for i,v in sq:
    if v == c:
      delSeq.add i
  for i in delSeq:
    sq.del(i)
  if sq.len == 0:
    cDelImpl(tb[], idxPath)
    if tb.len == 0:
      cDelImpl(cj[], idxDomain)

proc getCookys*(cj: CookyJar, uri: Uri, clearExpired: bool = true): seq[Cooky] =
  ## Gathers all the relevant cookys from a cookyjar for the given uri.
  ## Any expired cookies are deleted.
  
  # get currTime to compare to expiries of cookys
  let currTime = getTime().toUnix()

  var
    inp: string
    highIdx, pos: int

  inp = uri.hostname
  highIdx = high(inp)

  # create a list to put all matched domains in the cooky jar to the hostname
  # of the given uri
  var domainTbs: seq[(int, TableRef[string, seq[Cooky]])]

  while pos < highIdx:
    var hc: Hash
    let idxDomain = rawGet(cj[], inp[pos .. highIdx], hc)
    if idxDomain >= 0:
      # Found matched table; add to list
      domainTbs.add (idxDomain, cj[].data[idxDomain].val)

    # Skip until the next domain delimiter, and then skip that delimiter
    pos += skipUntil(inp[pos .. highIdx], '.', 0) + 1

  if domainTbs.len == 0:
    # no matches were found for the domain
    return

  inp = uri.path
  highIdx = high(inp)
  pos = 0

  # prepare a list of tables for domains that are to be deleted because they
  # only contained expired cookys and are now dead/empty
  var delTbs: seq[int]
  
  while pos < highIdx:
    # iterate over the path one step at a time and determine if the domain
    # contains any cookys for that path and beyond
    inc pos
    # Generate the hash for the path
    var hc: Hash = genHash(inp[0 ..< pos])

    if clearExpired and len(delTbs) > 0:
      # If we have some domain tables to delete then we do it here
      for i in delTbs:
        domainTbs.del i
      reset delTbs
      
    for tbIdx, (idxDomain, tb) in domainTbs:
      # For each domain table, we now use the predetermined hash to find matches
      var idxPath = rawGetKnownHC(tb[], inp[0 ..< pos], hc)
      if idxPath >= 0:
        # Match found for path
        block:
          if clearExpired:
            var delIdxs: seq[int]

            for i,cky in tb[].data[idxPath].val:
              # Iterate over all the cookys in the path sequence to see if any
              # have expired (-1 have no expiry)
              if cky.maxAge >= 0 and currTime > cky.maxAge:
                # Cooky is expired; time to die bitch
                delIdxs.add i
            # Delete all the cookies that were expired
            for i in delIdxs:
              tb[].data[idxPath].val.del i
            # Check if we now have to delete the path from the domain table
            if tb[].data[idxPath].val.len == 0:
              # all the cookys timed out so we better clear this thang out
              cDelImpl(tb[], idxPath)
              if tb.len == 0:
                # there are no more paths in the domain table, so we better
                # clear it out
                var idxDelDomain = idxDomain
                cDelImpl(cj[], idxDelDomain)
                # add to the list of domain tables to delete
                delTbs.add tbIdx
              # The key/value is invalid so we will break the block to prevent
              # adding undefined memory
              break
          result.add tb[].data[idxPath].val

    pos += skipUntil(inp, '/', pos)

proc getCookys*(cj: CookyJar; uri: string, clearExpired: bool = true): seq[Cooky] =
  getCookys(cj, parseUri(uri), clearExpired)

proc `$`*(ckys: seq[Cooky]): string =
  if ckys.len == 0:
    return ""
  result = $ckys[0]
  if ckys.len > 1:
    for cky in ckys[1..^1]:
      result &= "; " & $cky
  
proc getCookyHeader*(ckys: seq[Cooky]): string = $ckys