# Client for the SketchUp eval bridge.
# Usage:
#   python tools/sketchup-bridge/client.py "expression"
#   echo expression | python tools/sketchup-bridge/client.py
#   python tools/sketchup-bridge/client.py < script.rb

import json
import os
import socket
import sys

PORT = int(os.environ.get('SKETCHUP_BRIDGE_PORT', 7200))

code = ' '.join(sys.argv[1:]) if len(sys.argv) > 1 else sys.stdin.read()

try:
    sock = socket.create_connection(('127.0.0.1', PORT), timeout=5)
except ConnectionRefusedError:
    print('Cannot connect to SketchUp bridge. Is SketchUp running with the bridge loaded?', file=sys.stderr)
    sys.exit(1)

sock.sendall(code.encode())
sock.shutdown(socket.SHUT_WR)

chunks = []
while True:
    data = sock.recv(4096)
    if not data:
        break
    chunks.append(data)
sock.close()

response = b''.join(chunks).decode()

try:
    result = json.loads(response)
except json.JSONDecodeError:
    print(f'Invalid response from bridge: {response[:200]}', file=sys.stderr)
    sys.exit(1)

if result.get('stdout'):
    print(result['stdout'], end='')

if result.get('success'):
    print(result['result'])
else:
    print(f"Error: {result['error']}", file=sys.stderr)
    for line in (result.get('backtrace') or []):
        print(f'  {line}', file=sys.stderr)
    sys.exit(1)
