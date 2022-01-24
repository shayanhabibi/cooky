const headers = @[(key: "Cache-Control", value: "no-store, no-cache, must-revalidate, post-check=0, pre-check=0"),
  (key: "Connection", value: "keep-alive"), (key: "Date", value: "Mon, 24 Jan 2022 01:47:25 GMT"),
  (key: "Pragma", value: "no-cache"), (key: "Transfer-Encoding", value: "chunked"),
  (key: "Content-Type", value: "text/html; charset=UTF-8"), (key: "Content-Encoding", value: "gzip"),
  (key: "Expires", value: "Thu, 19 Nov 1981 08:52:00 GMT"), (key: "Server", value: "nginx"),
  (key: "Set-Cookie", value: "frontend=3arnqjvriav3lkhd8ddoni12b4; expires=Mon, 24-Jan-2022 13:47:25 GMT; path=/; domain=.my.api.net.au; secure"),
  (key: "Set-Cookie", value: "visid_incap_1938254=myNfoNyWR0CEzpgQFSFGui0F7mEAAAAAQUIPAAAAAACj76wvR3hO4ED3qpMJz+MI; expires=Mon, 23 Jan 2023 17:12:27 GMT; HttpOnly; path=/; Domain=.api.net.au; Secure; SameSite=None"),
  (key: "Set-Cookie", value: "nlbi_1938254=r5mKPfGPOTpgj/BvH+dSNgAAAADfHSmywelwrwG6ryj7XFai; path=/; Domain=.api.net.au; Secure; SameSite=None"),
  (key: "Set-Cookie", value: "incap_ses_958_1938254=Rpc/UnQu23mEYLG5eoBLDS0F7mEAAAAAJ2JN8TDs9yJFJxPtbeaSVw==; path=/; Domain=.api.net.au; Secure; SameSite=None"),
  (key: "Login-Required", value: "true"), (key: "X-Frame-Options", value: "SAMEORIGIN"), (key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains"),
  (key: "X-CDN", value: "Imperva"), (key: "X-Iinfo", value: "7-51420702-51420739 NNYY CT(92 93 0) RT(1642988844871 134) q(0 0 0 -1) r(4 5) U5")]

import cooky

var jar = newCookyJar()
var cookies = newSeq[Cooky]()
for x in headers:
  if x.isCookySetter():
    let cky = x.parseCooky()
    cookies.add cky
    jar.incl cky


for cky in cookies:
  echo len jar
  jar.excl cky

echo len jar