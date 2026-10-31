#!/usr/bin/env python3
"""High-performance streaming HTTP and HTTPS proxy for package downloads."""
import socket
import select
import sys
import shutil
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
import urllib.request

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class StreamingProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        # Concise logging
        sys.stderr.write(f"[{self.command}] {args[0]} -> {args[1]}\n")

    def do_CONNECT(self):
        # Direct TCP tunnel for HTTPS
        try:
            host, port = self.path.split(":")
            port = int(port)
            remote = socket.create_connection((host, port), timeout=15)
        except Exception as e:
            self.send_error(502, f"CONNECT failed: {e}")
            return

        self.send_response(200, "Connection Established")
        self.end_headers()

        conns = [self.connection, remote]
        while True:
            r, _, x = select.select(conns, [], conns, 30)
            if not r or x:
                break
            for s in r:
                other = remote if s is self.connection else self.connection
                try:
                    data = s.recv(32768)
                    if not data:
                        return
                    other.sendall(data)
                except Exception:
                    return

    def do_GET(self):
        self._stream_request("GET")

    def do_POST(self):
        self._stream_request("POST")

    def do_HEAD(self):
        self._stream_request("HEAD")

    def _stream_request(self, method):
        url = self.path
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ("host", "proxy-connection")}
        data = None
        if "Content-Length" in self.headers:
            length = int(self.headers["Content-Length"])
            data = self.rfile.read(length)

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status, resp.reason)
                for k, v in resp.getheaders():
                    if k.lower() != "transfer-encoding":
                        self.send_header(k, v)
                self.end_headers()
                shutil.copyfileobj(resp, self.wfile, length=65536)
        except urllib.error.HTTPError as e:
            self.send_response(e.code, e.reason)
            self.end_headers()
        except Exception as e:
            self.send_error(502, f"Proxy Error: {e}")

if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8080), StreamingProxyHandler)
    print("[*] Streaming HTTP/HTTPS Proxy listening on 0.0.0.0:8080", flush=True)
    server.serve_forever()
