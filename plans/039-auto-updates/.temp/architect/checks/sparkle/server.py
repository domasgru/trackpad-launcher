# Serves the spike's feed and archive, and logs every request's exact headers.
# Every response sets a year-long cookie, as github.com's latest-release redirect does,
# so a later request carrying it shows whether Sparkle's session keeps cookies.
import http.server
import os
import sys
import time

root, log_path, port = sys.argv[1], sys.argv[2], int(sys.argv[3])


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=root, **kwargs)

    def guess_type(self, path):
        # What raw.githubusercontent.com sends for a committed file.
        if path.endswith(".xml"):
            return "text/plain; charset=utf-8"
        return super().guess_type(path)

    def end_headers(self):
        self.send_header("Cache-Control", "max-age=300")
        self.send_header("ETag", '"probe-etag"')
        super().end_headers()

    def do_GET(self):
        with open(log_path, "a") as out:
            out.write(f"--- {time.strftime('%H:%M:%S')} {self.command} {self.path}\n")
            for name, value in self.headers.items():
                out.write(f"{name}: {value}\n")
        super().do_GET()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
