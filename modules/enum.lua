local mime = {
  html = "text/html; charset=utf-8",
  htm  = "text/html; charset=utf-8",
  css  = "text/css",
  js   = "application/javascript",
  json = "application/json",
  png  = "image/png",
  jpg  = "image/jpeg",
  jpeg = "image/jpeg",
  gif  = "image/gif",
  svg  = "image/svg+xml",
  txt  = "text/plain; charset=utf-8",
  -- map  = "application/json",
  ico  = "image/x-icon",
  wasm = "application/wasm",
  pdf  = "application/pdf",
}


local enum = {}


enum.contentType = mime


return enum