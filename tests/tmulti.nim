let setcookies = @["frontend=sessionid0000000000000000; expires=Thu, 27-Jan-2022 12:55:24 GMT; path=/; domain=.my.example.com",
                  "frontend=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/; domain=.my.example.com",
                  "frontend=sessionid0000000000000000; expires=Thu, 27-Jan-2022 12:55:25 GMT; path=/; domain=.my.example.com; secure"]

import cooky

let jar = newCookyJar()

for setcky in setcookies:
  jar.incl parseCooky(setcky)

echo jar.getCookys("https://my.example.com/customer")