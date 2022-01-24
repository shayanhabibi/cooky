# Check what format set-cookies come back in

import pkg/puppy

const
  url = "https://my.api.net.au/customer/account/login/"

block:
  let request = newRequest(url)
  let resp = fetch request
  let headers = resp.headers
  echo headers