# Signaling Protocol

The first MVP uses minimal HTTP signaling hosted by the Mac agent.

This protocol is intended for local-network MVP development and currently carries media signaling only. Input/control signaling is not implemented yet.

Base URL:

```text
http://<agent-host>:8080
```

## `GET /api/health`

Returns agent status.

## `POST /api/sessions`

Creates a single active viewer session from a browser WebRTC offer.

Request:

```json
{
  "version": 1,
  "offer": {
    "type": "offer",
    "sdp": "..."
  }
}
```

Response:

```json
{
  "version": 1,
  "sessionId": "...",
  "answer": {
    "type": "answer",
    "sdp": "..."
  }
}
```

## `POST /api/sessions/{sessionId}/ice`

Adds a browser ICE candidate to the active Mac agent peer.

Request:

```json
{
  "version": 1,
  "candidate": {
    "candidate": "...",
    "sdpMid": "0",
    "sdpMLineIndex": 0
  }
}
```

## `GET /api/sessions/{sessionId}/ice?since=0`

Returns agent ICE candidates gathered after the provided zero-based cursor.

Response:

```json
{
  "version": 1,
  "candidates": [],
  "nextCursor": 0
}
```

## `DELETE /api/sessions/{sessionId}`

Closes the active session.

Input/control messages are not defined yet. The first version only negotiates media.
