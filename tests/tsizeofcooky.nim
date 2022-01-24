# compare size of cooky to alts
import cooky

echo sizeof CookyObj # 48

import cookiejar

echo sizeof Cookie # 104

import cookies
import strtabs

echo sizeof StringTableObj # 40

# cookies uses a StrTable which by default is 40 bytes in size by default.