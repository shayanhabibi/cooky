# Cooky

User cookie handling for CLIENTS.

Designed primarily to work in concert with the Parthian fork of Puppy.

It is also built to be extremely memory efficient. They are designed to span
less than a single cache line to make them suitable for use in multi threading
paradigms.

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