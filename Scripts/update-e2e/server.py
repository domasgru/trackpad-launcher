# The local stand-in for the two hosts an update touches, for Scripts/update-e2e.sh.
#
#   server.py <serve-dir> <request-log> <control-file> <port>
#
# <serve-dir>/feed.xml is served at the feed's path as raw.githubusercontent.com serves it. An archive under
# <serve-dir>/assets/<name> is asked for at /domasgru/trackpad-launcher/releases/download/v<version>/<name>, which
# answers 302 to a second path, as github.com answers, and that path serves the bytes. Both offer a year-long cookie,
# so a later request carrying it shows the updater's session keeps cookies.
#
# Every request is appended to the log as one record: a line "--- <epoch ms> <METHOD> <target>", then the request's
# headers exactly as received, one per line, then an empty line.
#
# The control file is read on every request, so a row changes behaviour without a restart. It holds words of the form
# key=value; a missing key or file means ok:
#   feed=ok|503|503once|404|reset|hold   the feed; 503once answers 503 to one request, then the word is removed
#   asset=ok|503|404|reset           the release path, before its redirect
#   payload=ok|503|404|reset|hold    the redirect's target, which carries the bytes; hold sends half the body, then waits,
#                                    and resets the connection once the word becomes reset
import hashlib
import http.server
import os
import re
import select
import socket
import socketserver
import struct
import sys
import threading
import time
import urllib.parse

root, log_path, control_path, port = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

FEED_PATH = "/domasgru/trackpad-launcher/main/appcast.xml"
RELEASE = re.compile(r"^/domasgru/trackpad-launcher/releases/download/v[^/]+/([^/]+)$")
PAYLOAD = re.compile(r"^/assets/([^/]+)$")
COOKIE = "probe=abc123; Max-Age=31536000; Path=/"
log_lock = threading.Lock()


def consume(key, value):
    """Removes one word from the control file, so a fault set to happen once happens once."""
    with log_lock:
        try:
            with open(control_path) as handle:
                words = handle.read().split()
        except OSError:
            return
        kept = [word for word in words if word != f"{key}={value}"]
        with open(control_path + ".new", "w") as handle:
            handle.write(" ".join(kept) + "\n")
        os.replace(control_path + ".new", control_path)


def control():
    settings = {}
    try:
        with open(control_path) as handle:
            for word in handle.read().split():
                key, _, value = word.partition("=")
                settings[key] = value
    except OSError:
        pass
    return settings


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def finish(self):
        try:
            super().finish()
        except OSError:
            pass

    def do_GET(self):
        self.serve(with_body=True)

    def do_HEAD(self):
        self.serve(with_body=False)

    def record(self):
        lines = [f"--- {int(time.time() * 1000)} {self.command} {self.path}"]
        lines += [f"{name}: {value}" for name, value in self.headers.items()]
        with log_lock, open(log_path, "a") as out:
            out.write("\n".join(lines) + "\n\n")

    def reply(self, status, body=b"", headers=(), with_body=True):
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if with_body and body:
            self.wfile.write(body)

    def reset_connection(self):
        self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        self.connection.close()
        self.close_connection = True

    def fault(self, mode, with_body):
        if mode in ("503", "404"):
            self.reply(int(mode), with_body=with_body)
            return True
        if mode == "reset":
            self.reset_connection()
            return True
        return False

    def serve(self, with_body):
        self.record()
        settings = control()
        path = urllib.parse.urlsplit(self.path).path
        if path == FEED_PATH:
            self.serve_feed(settings.get("feed", "ok"), with_body)
        elif RELEASE.match(path):
            self.serve_release(path, settings.get("asset", "ok"), with_body)
        elif PAYLOAD.match(path):
            self.serve_payload(path, settings.get("payload", "ok"), with_body)
        else:
            self.reply(404, with_body=with_body)

    def serve_feed(self, mode, with_body):
        if mode == "503once":
            consume("feed", "503once")
            self.reply(503, with_body=with_body)
            return
        if self.fault(mode, with_body):
            return
        try:
            with open(os.path.join(root, "feed.xml"), "rb") as handle:
                body = handle.read()
        except OSError:
            self.reply(404, with_body=with_body)
            return
        tag = '"' + hashlib.md5(body).hexdigest() + '"'
        headers = [
            ("Content-Type", "text/plain; charset=utf-8"),
            ("ETag", tag),
            ("Cache-Control", "max-age=300"),
        ]
        if self.headers.get("If-None-Match") == tag:
            self.reply(304, headers=headers[1:], with_body=False)
            return
        if mode == "hold":
            self.hold(body, headers, "feed")
            return
        self.reply(200, body, headers, with_body)

    def serve_release(self, path, mode, with_body):
        if self.fault(mode, with_body):
            return
        name = RELEASE.match(path).group(1)
        self.reply(
            302,
            headers=[("Location", f"/assets/{urllib.parse.quote(name)}?token=abc123"), ("Set-Cookie", COOKIE)],
            with_body=with_body,
        )

    def serve_payload(self, path, mode, with_body):
        if self.fault(mode, with_body):
            return
        name = urllib.parse.unquote(PAYLOAD.match(path).group(1))
        try:
            with open(os.path.join(root, "assets", name), "rb") as handle:
                body = handle.read()
        except OSError:
            self.reply(404, with_body=with_body)
            return
        headers = [("Content-Type", "application/octet-stream"), ("Set-Cookie", COOKIE)]
        if mode == "hold":
            self.hold(body, headers, "payload")
            return
        self.reply(200, body, headers, with_body)

    def hold(self, body, headers, key):
        self.send_response(200)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body[: max(1, len(body) // 2)])
        self.wfile.flush()
        self.close_connection = True
        deadline = time.time() + 900
        while time.time() < deadline:
            if control().get(key) == "reset":
                self.reset_connection()
                return
            readable, _, _ = select.select([self.connection], [], [], 1.0)
            if readable:
                try:
                    if not self.connection.recv(1, socket.MSG_PEEK):
                        return
                except OSError:
                    return


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def server_bind(self):
        # HTTPServer's own bind looks up the host's name, which can stall for a long time on a Mac with no resolver.
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = "127.0.0.1", self.server_address[1]

    def handle_error(self, request, client_address):
        pass


Server(("127.0.0.1", port), Handler).serve_forever()
