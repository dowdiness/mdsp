"""Loopback-only measurement collector; never used by the product server."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import os
OUTPUT = Path('artifacts/audio-profile')
OUTPUT.mkdir(parents=True, exist_ok=True)
class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        if not re.fullmatch(r'/capture/[a-z0-9-]+\.(json|pcm|rows)', self.path):
            self.send_error(400); return
        size = int(self.headers.get('Content-Length', '0'))
        if size < 1 or size > 4_000_000:
            self.send_error(413); return
        (OUTPUT / self.path.split('/')[-1]).write_bytes(self.rfile.read(size))
        self.send_response(204); self.end_headers()
ThreadingHTTPServer(('127.0.0.1', int(os.environ.get('COMPOSITION_PORT', '8770'))), Handler).serve_forever()
