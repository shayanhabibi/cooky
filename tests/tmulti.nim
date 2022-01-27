let setcookies = @["frontend=uet5p7d0peeg1cv88tktdummo1; expires=Thu, 27-Jan-2022 12:55:24 GMT; path=/; domain=.my.api.net.au",
                  "frontend=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/; domain=.my.api.net.au",
                  "frontend=hmtg46sjtf1rpbdae5s61djq40; expires=Thu, 27-Jan-2022 12:55:25 GMT; path=/; domain=.my.api.net.au; secure"]

import cooky

let jar = newCookyJar()

for setcky in setcookies:
  jar.incl parseCooky(setcky)

echo jar.getCookys("https://my.api.net.au/customer")