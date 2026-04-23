# Signaling Protocol

The first MVP uses minimal HTTP signaling hosted by the Mac agent.

This protocol is intended for local-network MVP development and currently carries media signaling only. Input/control signaling is not implemented yet.

All responses include CORS headers for Vite/dev-server origins:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

Base URL:

```text
http://<agent-host>:8080
```

## `GET /api/health`

Returns agent status.

Response:

```json
{
  "version": 1,
  "status": "ok",
  "activeSession": false,
  "screenRecordingAllowed": true,
  "sessionStatus": "Waiting for viewer",
  "serverStatus": "Listening on :8080",
  "lastError": null
}
```

`status` may be:

- `ok`
- `permissionMissing`
- `captureFailed`
- `negotiationFailed`
- `serverFailed`

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

## Error Responses

Errors are JSON when produced by known validation/session failures:

```json
{
  "version": 1,
  "error": {
    "code": "permission_missing",
    "message": "Screen Recording permission is required before starting a stream."
  }
}
```

Known error codes include:

- `capture_failed`
- `invalid_ice_candidate`
- `invalid_json`
- `invalid_offer`
- `negotiation_failed`
- `not_found`
- `permission_missing`
- `session_not_found`
- `unsupported_protocol_version`
