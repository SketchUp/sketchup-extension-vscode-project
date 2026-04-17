# MCP server for the SketchUp eval bridge.
# Registered with: claude mcp add sketchup-bridge -- python tools/sketchup-bridge/mcp_server.py

import json
import os
import socket

from mcp.server.fastmcp import FastMCP

PORT = int(os.environ.get('SKETCHUP_BRIDGE_PORT', 7200))

mcp = FastMCP('sketchup-bridge')


def send_to_bridge(code):
    try:
        sock = socket.create_connection(('127.0.0.1', PORT), timeout=30)
    except ConnectionRefusedError:
        return {
            'success': False,
            'error': 'Cannot connect to SketchUp bridge. Is SketchUp running with the bridge loaded?',
        }

    sock.sendall(code.encode())
    sock.shutdown(socket.SHUT_WR)

    chunks = []
    while True:
        data = sock.recv(4096)
        if not data:
            break
        chunks.append(data)
    sock.close()

    try:
        return json.loads(b''.join(chunks).decode())
    except json.JSONDecodeError:
        return {'success': False, 'error': 'Invalid response from bridge'}


@mcp.tool()
def evaluate_ruby(code: str) -> str:
    """Evaluate Ruby code in the running SketchUp instance.

    The code runs on SketchUp's main thread with full API access.
    Returns the result of the last expression (via .inspect) and
    any stdout output from puts/print calls.

    Examples:
        evaluate_ruby("Sketchup.active_model.title")
        evaluate_ruby("Sketchup.active_model.entities.length")
    """
    result = send_to_bridge(code)
    parts = []
    if result.get('stdout'):
        parts.append(result['stdout'])
    if result.get('success'):
        parts.append(result['result'])
    else:
        parts.append(f"Error: {result['error']}")
        for line in result.get('backtrace') or []:
            parts.append(f'  {line}')
    return '\n'.join(parts)


if __name__ == '__main__':
    mcp.run()
