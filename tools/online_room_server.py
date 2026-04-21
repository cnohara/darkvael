#!/usr/bin/env python3
from __future__ import annotations

import json
import random
import string
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


ROOMS: dict[str, dict] = {}
ROOM_LOCK = threading.Lock()
CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def now_ts() -> float:
    return time.time()


def json_response(handler: BaseHTTPRequestHandler, status: int, payload: dict) -> None:
    data = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def parse_json(handler: BaseHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length", "0"))
    raw = handler.rfile.read(length) if length > 0 else b"{}"
    try:
        return json.loads(raw.decode("utf-8") or "{}")
    except json.JSONDecodeError:
        return {}


def make_code() -> str:
    while True:
        code = "".join(random.choice(CODE_ALPHABET) for _ in range(6))
        if code not in ROOMS:
            return code


def make_token() -> str:
    return "".join(random.choice(string.ascii_letters + string.digits) for _ in range(24))


def require_room(code: str) -> dict | None:
    room = ROOMS.get(code)
    if room is not None:
        room["last_seen"] = now_ts()
    return room


def prune_rooms() -> None:
    cutoff = now_ts() - 60 * 60 * 6
    stale = [code for code, room in ROOMS.items() if room.get("last_seen", 0) < cutoff]
    for code in stale:
        ROOMS.pop(code, None)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        if parsed.path == "/api/rooms/state":
            return self.handle_state(query)
        if parsed.path == "/api/rooms/commands":
            return self.handle_commands(query)
        return json_response(self, HTTPStatus.NOT_FOUND, {"error": "Not found."})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        body = parse_json(self)
        if parsed.path == "/api/rooms/host":
            return self.handle_host()
        if parsed.path == "/api/rooms/join":
            return self.handle_join(body)
        if parsed.path == "/api/rooms/start":
            return self.handle_start(body)
        if parsed.path == "/api/rooms/snapshot":
            return self.handle_snapshot(body)
        if parsed.path == "/api/rooms/command":
            return self.handle_command(body)
        return json_response(self, HTTPStatus.NOT_FOUND, {"error": "Not found."})

    def handle_host(self) -> None:
        with ROOM_LOCK:
            prune_rooms()
            code = make_code()
            token = make_token()
            ROOMS[code] = {
                "code": code,
                "host_token": token,
                "guest_token": "",
                "started": False,
                "guest_joined": False,
                "snapshot": {},
                "revision": 0,
                "commands": [],
                "next_command_id": 1,
                "last_seen": now_ts(),
            }
        json_response(self, HTTPStatus.OK, {
            "room_code": code,
            "token": token,
            "seat_index": 0,
        })

    def handle_join(self, body: dict) -> None:
        code = str(body.get("room_code", "")).strip().upper()
        with ROOM_LOCK:
            room = require_room(code)
            if room is None:
                return json_response(self, HTTPStatus.NOT_FOUND, {"error": "Room code not found."})
            if room["guest_joined"]:
                return json_response(self, HTTPStatus.CONFLICT, {"error": "Room already has a guest."})
            token = make_token()
            room["guest_token"] = token
            room["guest_joined"] = True
        json_response(self, HTTPStatus.OK, {
            "room_code": code,
            "token": token,
            "seat_index": 1,
        })

    def handle_start(self, body: dict) -> None:
        code = str(body.get("room_code", "")).strip().upper()
        token = str(body.get("token", ""))
        with ROOM_LOCK:
            room = require_room(code)
            if room is None or room["host_token"] != token:
                return json_response(self, HTTPStatus.FORBIDDEN, {"error": "Invalid host token."})
            if not room["guest_joined"]:
                return json_response(self, HTTPStatus.CONFLICT, {"error": "A guest has not joined yet."})
            room["started"] = True
        json_response(self, HTTPStatus.OK, {"started": True})

    def handle_snapshot(self, body: dict) -> None:
        code = str(body.get("room_code", "")).strip().upper()
        token = str(body.get("token", ""))
        snapshot = body.get("snapshot", {})
        with ROOM_LOCK:
            room = require_room(code)
            if room is None or room["host_token"] != token:
                return json_response(self, HTTPStatus.FORBIDDEN, {"error": "Invalid host token."})
            room["snapshot"] = snapshot
            room["revision"] += 1
        json_response(self, HTTPStatus.OK, {"revision": room["revision"]})

    def handle_command(self, body: dict) -> None:
        code = str(body.get("room_code", "")).strip().upper()
        token = str(body.get("token", ""))
        payload = body.get("command", {})
        with ROOM_LOCK:
            room = require_room(code)
            if room is None or room["guest_token"] != token:
                return json_response(self, HTTPStatus.FORBIDDEN, {"error": "Invalid guest token."})
            cmd = {
                "id": room["next_command_id"],
                "payload": payload,
                "created_at": now_ts(),
            }
            room["next_command_id"] += 1
            room["commands"].append(cmd)
        json_response(self, HTTPStatus.OK, {"queued": True, "id": cmd["id"]})

    def handle_state(self, query: dict) -> None:
        code = str(query.get("room_code", [""])[0]).strip().upper()
        token = str(query.get("token", [""])[0])
        with ROOM_LOCK:
            room = require_room(code)
            if room is None:
                return json_response(self, HTTPStatus.NOT_FOUND, {"error": "Room code not found."})
            if token not in {room["host_token"], room["guest_token"]}:
                return json_response(self, HTTPStatus.FORBIDDEN, {"error": "Invalid session token."})
            payload = {
                "room_code": code,
                "guest_joined": room["guest_joined"],
                "started": room["started"],
                "revision": room["revision"],
                "snapshot": room["snapshot"],
            }
        json_response(self, HTTPStatus.OK, payload)

    def handle_commands(self, query: dict) -> None:
        code = str(query.get("room_code", [""])[0]).strip().upper()
        token = str(query.get("token", [""])[0])
        after = int(query.get("after", ["0"])[0])
        with ROOM_LOCK:
            room = require_room(code)
            if room is None or room["host_token"] != token:
                return json_response(self, HTTPStatus.FORBIDDEN, {"error": "Invalid host token."})
            commands = [cmd for cmd in room["commands"] if cmd["id"] > after]
        json_response(self, HTTPStatus.OK, {"commands": commands})


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", 8787), Handler)
    print("Online room server listening on http://0.0.0.0:8787")
    server.serve_forever()


if __name__ == "__main__":
    main()
