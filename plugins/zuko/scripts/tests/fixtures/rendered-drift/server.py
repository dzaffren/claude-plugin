"""Test servers for test-e2e-rendered-drift.sh.

    server.py http404 <host> <portfile>           answers every path with HTTP 404 and a page
                                                  that uses only tokens, as an app's not-found
                                                  page does
    server.py listen <host> <portfile> <logfile>  accepts TCP connections and logs each one,
                                                  to prove that nothing reached a far host

Each binds port 0 and writes the port it got to <portfile>. http404 serves each
connection in its own thread, so an idle connection from Chrome cannot block it.
"""
import http.server
import socket
import sys

mode, host, portfile = sys.argv[1], sys.argv[2], sys.argv[3]

TOKENS = b":root{--ink:#1a1a1a;--surface:#ffffff;--text-base:16px;--font-sans:system-ui,sans-serif}"
PAGE = (b'<!doctype html><html><head><link rel="stylesheet" href="/tokens.css"><style>'
        b"body{margin:0;background:var(--surface);color:var(--ink);font-family:var(--font-sans);"
        b"font-size:var(--text-base)}</style></head><body><p>Page not found</p></body></html>")


class NotFound(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/tokens.css":
            self.send_response(200)
            self.send_header("Content-Type", "text/css")
            self.end_headers()
            self.wfile.write(TOKENS)
            return
        self.send_response(404)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, *args):
        pass


if mode == "http404":
    server = http.server.ThreadingHTTPServer((host, 0), NotFound)
    open(portfile, "w").write(str(server.server_address[1]))
    server.serve_forever()
elif mode == "listen":
    logfile = sys.argv[4]
    s = socket.socket()
    s.bind((host, 0))
    s.listen(8)
    open(portfile, "w").write(str(s.getsockname()[1]))
    while True:
        conn, _ = s.accept()
        with open(logfile, "a") as log:
            log.write("connection\n")
        conn.close()
