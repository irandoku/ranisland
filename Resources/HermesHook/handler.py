"""Fail-open Hermes hook for the local Open Island observer bridge."""

from __future__ import annotations

import json
import os
import socket
from pathlib import Path
from typing import Any


def _socket_path() -> str:
    return (
        os.environ.get("OPEN_ISLAND_SOCKET_PATH")
        or os.environ.get("VIBE_ISLAND_SOCKET_PATH")
        or str(Path.home() / "Library/Application Support/OpenIsland/bridge.sock")
    )


def _value(context: dict[str, Any], key: str, limit: int = 500) -> str | None:
    value = context.get(key)
    if value is None:
        return None
    return str(value)[:limit]


def handle(event_type: str, context: dict[str, Any]) -> None:
    payload = {
        "eventName": event_type,
        "sessionID": _value(context, "session_id"),
        "sessionKey": _value(context, "session_key"),
        "platform": _value(context, "platform", 64),
        "userID": _value(context, "user_id", 256),
        "chatID": _value(context, "chat_id", 256),
        "threadID": _value(context, "thread_id", 256),
        "message": _value(context, "message"),
        "response": _value(context, "response"),
    }
    envelope = {
        "type": "command",
        "command": {
            "type": "processHermesHook",
            "hermesHook": payload,
        },
    }

    # Hermes hooks must never delay or break the gateway when Open Island is
    # closed, rebuilding, or unavailable.
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(2.0)
            client.connect(_socket_path())
            client.sendall((json.dumps(envelope, separators=(",", ":")) + "\n").encode())
            client.recv(4096)
    except (OSError, TimeoutError):
        return
