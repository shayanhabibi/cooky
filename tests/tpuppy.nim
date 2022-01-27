# Check what format set-cookies come back in

import pkg/puppy
import pkg/cooky

const
  url = "https://my.api.net.au/customer/account/login/"
  url2 = "https://www.google.com"

block:
  let request = newRequest(url)
  request.jar = newCookyJar()
  let resp = fetch request
  let headers = resp.headers
  echo headers
  echo request.jar.len