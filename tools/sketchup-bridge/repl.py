# Interactive REPL for the SketchUp eval bridge.
# Keeps a long-running process so there's no startup overhead per command.
#
# Usage: python tools/sketchup-bridge/repl.py
#
# Type Ruby expressions, press Enter to evaluate. Multi-line input:
# end a line with \ to continue on the next line.
# Type "exit" or Ctrl+C to quit.

import json
import os
import socket
import sys

PORT = int(os.environ.get('SKETCHUP_BRIDGE_PORT', 7200))

def send_code(code):
    try:
        sock = socket.create_connection(('127.0.0.1', PORT), timeout=10)
    except ConnectionRefusedError:
        print('Cannot connect to SketchUp bridge. Is SketchUp running?', file=sys.stderr)
        return None

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
        return json.loads(response)
    except json.JSONDecodeError:
        print(f'Invalid response: {response[:200]}', file=sys.stderr)
        return None

def main():
    print(f'SketchUp Bridge REPL (port {PORT})')
    print('Type Ruby code and press Enter. End a line with \\ to continue.')
    print('Type "exit" or press Ctrl+C to quit.')
    print()

    while True:
        try:
            line = input('su> ')
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if line.strip() == 'exit':
            break

        # Multi-line: accumulate lines ending with backslash.
        while line.endswith('\\'):
            line = line[:-1] + '\n'
            try:
                line += input('..> ')
            except (EOFError, KeyboardInterrupt):
                print()
                break

        if not line.strip():
            continue

        result = send_code(line)
        if result is None:
            continue

        if result.get('stdout'):
            print(result['stdout'], end='')

        if result.get('success'):
            print(f'=> {result["result"]}')
        else:
            print(f'Error: {result["error"]}', file=sys.stderr)
            for bt in (result.get('backtrace') or []):
                print(f'  {bt}', file=sys.stderr)

if __name__ == '__main__':
    main()
