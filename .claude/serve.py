import os
import functools
from http.server import HTTPServer, SimpleHTTPRequestHandler

ROOT = "/tmp/portfolio-preview"
os.chdir(ROOT)
Handler = functools.partial(SimpleHTTPRequestHandler, directory=ROOT)
HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
