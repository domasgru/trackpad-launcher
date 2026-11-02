# Local test server for urlsession-probe.swift. Binds 127.0.0.1 only.
#   /echo   -> prints every request header it received (to stdout) and answers 200 "ok"
#   /file   -> 200 with 64 KiB body
#   /stall  -> 200 headers + 10 bytes of a declared 1 MiB body, then stalls 10 s
#   /slow   -> 200 headers, then 1 byte per second for 6 s (declared length 6)
#   /redirect -> 302 to /echo
import sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a):
        pass
    def do_GET(self):
        if self.path.startswith("/echo"):
            print("REQUEST", self.command, self.path, flush=True)
            for k, v in self.headers.items():
                print("  HEADER", k + ":", v, flush=True)
            body = b"ok"
            self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        elif self.path == "/redirect":
            self.send_response(302); self.send_header("Location", "/echo?after-redirect"); self.send_header("Content-Length", "0"); self.end_headers()
        elif self.path == "/file":
            body = b"x" * 65536
            self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        elif self.path == "/stall":
            self.send_response(200); self.send_header("Content-Length", str(1 << 20)); self.end_headers()
            self.wfile.write(b"y" * 10); self.wfile.flush(); time.sleep(10)
        elif self.path == "/slow":
            self.send_response(200); self.send_header("Content-Length", "6"); self.end_headers()
            for _ in range(6):
                self.wfile.write(b"z"); self.wfile.flush(); time.sleep(1)
        else:
            self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers()

from socketserver import ThreadingMixIn
class S(ThreadingMixIn, HTTPServer):
    daemon_threads = True

S(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
