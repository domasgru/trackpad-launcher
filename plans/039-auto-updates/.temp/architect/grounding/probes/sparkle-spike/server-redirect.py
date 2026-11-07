# As server.py, but the archive's path answers 302 to a second path, as github.com does,
# so the log shows which headers survive a redirect. Sets no cookie.
import http.server
import sys
import time

root, log_path, port = sys.argv[1], sys.argv[2], int(sys.argv[3])


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=root, **kwargs)

    def do_GET(self):
        with open(log_path, "a") as out:
            out.write(f"--- {time.strftime('%H:%M:%S')} {self.command} {self.path}\n")
            for name, value in self.headers.items():
                out.write(f"{name}: {value}\n")
        if self.path == "/SpikeHost-2.aar":
            self.send_response(302)
            self.send_header("Location", "/assets/SpikeHost-2.aar?token=abc")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if self.path.startswith("/assets/"):
            self.path = "/SpikeHost-2.aar"
        super().do_GET()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
