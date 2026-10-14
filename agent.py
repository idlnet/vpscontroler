import os
import json
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

SECRET_TOKEN = os.getenv("AGENT_SECRET", "")
PORT = int(os.getenv("AGENT_PORT", 5050))

class SimpleHandler(BaseHTTPRequestHandler):
    def _send_response(self, code, data):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def do_GET(self):
        if self.path == '/ping':
            self._send_response(200, {"status": "online"})
        else:
            self._send_response(404, {"error": "Not Found"})

    def do_POST(self):
        if self.path != '/api/account/create':
            self._send_response(404, {"error": "Endpoint tidak wujud"})
            return

        token = self.headers.get('x-agent-token')
        if not SECRET_TOKEN or token != SECRET_TOKEN:
            self._send_response(401, {"error": "Token salah"})
            return

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        try:
            body = json.loads(post_data.decode('utf-8'))
        except Exception:
            self._send_response(400, {"error": "JSON tidak sah"})
            return

        protocol = body.get('protocol', '').lower()
        username = body.get('username', '')
        days = body.get('duration_days', 30)
        password = body.get('password', '123456')

        commands = {
            "ssh": f"/usr/bin/add-ssh {username} {password} {days}",
            "vmess": f"/usr/bin/add-ws {username} {days}",
            "vless": f"/usr/bin/add-vless {username} {days}",
            "trojan": f"/usr/bin/add-tr {username} {days}"
        }

        cmd = commands.get(protocol)
        if not cmd:
            self._send_response(400, {"error": "Protokol tidak disokong"})
            return

        try:
            proc = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30)
            output = proc.stdout if proc.stdout else proc.stderr
            self._send_response(200, {
                "status": "success",
                "protocol": protocol,
                "username": username,
                "raw_output": output
            })
        except Exception as e:
            self._send_response(500, {"error": str(e)})

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), SimpleHandler)
    server.serve_forever()
