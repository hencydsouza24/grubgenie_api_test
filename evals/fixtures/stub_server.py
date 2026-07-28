#!/usr/bin/env python3
"""Minimal HTTP stub for offline contract testing (no real GrubGenie API required).

Route convention: the path itself encodes the desired response, so no fixture files are
needed for the basic status/contract assertions:
  /status/200            -> 200 {"result": {"cartId": "abc123"}}
  /status/401            -> 401 {"message": "unauthorized"}
  /status/500            -> 500 {"message": "boom"}
  /status/409            -> 409 {"message": "already running"}
  /contract/missing      -> 200 {"message": "ok"}                (no .result.cartId — contract violation)
  anything else          -> 404 {"message": "not found"}

Every request increments a counter file at $GG_STUB_COUNTER_FILE (if set), keyed by path — used
by the double-POST regression check once pos.sh exists (Phase 4).
"""
import http.server
import json
import os
import sys


def _bump_counter(path):
    counter_file = os.environ.get("GG_STUB_COUNTER_FILE")
    if not counter_file:
        return
    counts = {}
    if os.path.exists(counter_file):
        try:
            with open(counter_file) as f:
                counts = json.load(f)
        except (ValueError, OSError):
            counts = {}
    counts[path] = counts.get(path, 0) + 1
    with open(counter_file, "w") as f:
        json.dump(counts, f)


class Handler(http.server.BaseHTTPRequestHandler):
    def _reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _route(self):
        _bump_counter(self.path)
        if self.path.startswith("/status/"):
            code = int(self.path.split("/")[2].split("?")[0])
            body = {200: {"result": {"cartId": "abc123"}}}.get(code, {"message": f"status {code}"})
            self._reply(code, body)
        elif self.path.startswith("/contract/missing"):
            self._reply(200, {"message": "ok"})
        else:
            self._reply(404, {"message": "not found"})

    def do_GET(self):
        self._route()

    def do_POST(self):
        self._route()

    def do_PUT(self):
        self._route()

    def do_PATCH(self):
        self._route()

    def do_DELETE(self):
        self._route()

    def log_message(self, *_args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    print(server.server_address[1], flush=True)  # so the caller can read the bound port
    server.serve_forever()
