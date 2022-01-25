# Cooky

User cookie handling for CLIENTS.

Designed primarily to work in concert with the Parthian fork of Puppy.

It is also built to be extremely memory efficient. They are designed to span
less than a single cache line to make them suitable for use in multi threading
paradigms.

The cookie jar is made to be as fast to access and modify as possible to ensure
concurrent use is not bottlenecked by its use.

# Usage

`isCookySetter()` can be used on key/value tuples to determine if the key is
a set-cookie header.

`parseCooky` can then be used on the key/value tuple, or on any string that is a
known value for a set-cookie header.

The parsed cooky can be `incl` into any `CookyJar` which is generated using
`newCookyJar()`. Any cooky in the jar that has the same `name` value will be
replaced.

You can also `excl` any cooky from the `CookyJar`; this looks for any `Cooky`
along the given domain and path with the same name and removes it.

Whenever you have a url/uri that you want to get all the relevant `Cooky`s for,
you can pass it as a `string` or as a `from std/uri import Uri` object to
`getCookys(cj: CookyJar, uri: string | Uri): seq[Cooky]` to get a sequence of
`Cooky`s which match the uri. You can convert these into a properly formatted
'cookie' value  using `getCookyHeader(ckys: seq[Cooky]): string` or just `$`.

`getCookys` will automatically remove any expired cookys from the jar unless you
pass an optional boolean `getCookys(cj: CookyJar, uri: string | Uri, clearExpired: bool = true): seq[Cooky]`.

## Thin Strings

Strings are excessively large for cookies which are primarily static for the
duration of their life time (which is usually non-negligible). We use cstrings
instead which are known by the allocator by creating our own equivalent type
called tstrings. However, tstrings must be asigned to using their specific
`asign` operator

```nim
type
  MyObj = object
    str: tstring

let validObj = MyObj()
validObj.str.asign "value"
```

## Time Parser

In the interest of time I have avoided implementing the full
parser as per RFC6265 and have just opted for the `std/times`
parser with preset `TimeFormat`s. This will be changed in time.