#!/usr/bin/env python3
"""Simple HTTP and HTTPS CONNECT proxy for adb reverse internet sharing."""
import socket
import select
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request

class ProxyHandler(BaseHTTPRequestHandler):
    def do_CONNECT(self):
        # Handle HTTPS tunneling
        host, port = self.path.split(":")
        port = int(port)
        try:
            remote = socket.create_connection((host, port), timeout=10)
        except Exception as e:
            self.send_error(502, f"Bad Gateway: {e}")
            return

        self.send_response(200, "Connection Established")
        self.end_headers()

        conns = [self.connection, remote]
        while True:
            r, _, _ = select.select(conns, [], conns, 30)
            if not r:
                break
            for s in r:
                other = remote if s is self.connection else self.connection
                try:
                    data = s.recv(16384)
                    if not data:
                        return
                    other.sendall(data)
                except Exception:
                    return

    def do_GET(self):
        self._proxy_request("GET")

    def do_POST(self):
        self._proxy_request("POST")

    def do_HEAD(self):
        self._proxy_request("HEAD")

    def _proxy_request(self, method):
        url = self.path
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ("host", "proxy-connection")}
        data = None
        if "Content-Length" in self.headers:
            length = int(self.headers["Content-Length"])
            data = self.rfile.read(length)

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                self.send_response(resp.status, resp.reason)
                for k, v in resp.getheaders():
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code, e.reason)
            self.end_headers()
        except Exception as e:
            self.send_error(502, f"Proxy Error: {e}")

if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 8080), ProxyHandler)
    print("[*] HTTP/HTTPS Proxy listening on 127.0.0.1:8080")
    sys.stdout.flush()
    server.serve_forever()
