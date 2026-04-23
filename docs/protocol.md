# Signaling Protocol

The MVP uses minimal HTTP signaling hosted by the Mac agent for session setup. Input control uses a WebRTC DataChannel on the same peer connection.

This protocol is intended for local-network MVP development. It is not hardened for public internet exposure.

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
  "accessibilityAllowed": true,
  "sessionStatus": "Waiting for viewer",
  "serverStatus": "Listening on :8080",
  "lastError": null,
  "media": {},
  "control": {
    "channelState": "none",
    "accessibilityAllowed": true,
    "receivedMessages": 0,
    "injectedEvents": 0,
    "resetCount": 0,
    "pressedKeys": 0,
    "pressedButtons": 0,
    "lastMessageType": null,
    "lastMappedX": null,
    "lastMappedY": null,
    "lastError": null
  }
}
```

The `media` object reports live capture and sender diagnostics. The most useful pacing fields are:

- `captureFrames`: raw ScreenCaptureKit sample buffers received
- `completeFrames`: complete frames after ScreenCaptureKit status filtering
- `submittedFrames`: frames admitted by the explicit 30 fps pacing gate
- `droppedIncompleteFrames`: invalid or incomplete capture frames
- `droppedPacingFrames`: complete frames dropped to hold the target cadence
- `droppedBackpressureFrames`: stale frames discarded when the WebRTC capturer is still busy
- `targetFramesPerSecond`: current pacing target
- `sourceFrames`: frames handed into the custom WebRTC capturer
- `capturerFrames`: frames actually delivered into the WebRTC video source

`status` may be:

- `ok`
- `permissionMissing`
- `accessibilityMissing`
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

The Mac agent also resets any pressed input state when a session closes.

## WebRTC DataChannel: `macvm-control`

The browser creates an ordered DataChannel named `macvm-control` before creating the SDP offer. The Mac agent accepts that channel through the negotiated WebRTC session. Control messages are UTF-8 JSON and include the shared protocol version, a stable message type, sequence, and browser timestamp.

### `input.mouse.move`

```json
{
  "version": 1,
  "type": "input.mouse.move",
  "sequence": 1,
  "timestampMs": 1710000000000,
  "x": 0.5,
  "y": 0.5,
  "buttons": []
}
```

`x` and `y` are normalized to the actual visible video content rectangle, after browser-side letterbox/pillarbox handling.

### `input.mouse.button`

```json
{
  "version": 1,
  "type": "input.mouse.button",
  "sequence": 2,
  "timestampMs": 1710000000001,
  "button": "left",
  "action": "down",
  "x": 0.5,
  "y": 0.5,
  "buttons": ["left"]
}
```

`button` is `left` or `right`; `action` is `down` or `up`.

### `input.mouse.wheel`

```json
{
  "version": 1,
  "type": "input.mouse.wheel",
  "sequence": 3,
  "timestampMs": 1710000000002,
  "deltaX": 0,
  "deltaY": 120,
  "x": 0.5,
  "y": 0.5
}
```

Wheel deltas are normalized to pixel units on the browser side before sending.

### `input.keyboard.key`

```json
{
  "version": 1,
  "type": "input.keyboard.key",
  "sequence": 4,
  "timestampMs": 1710000000003,
  "action": "down",
  "code": "KeyA",
  "key": "a",
  "modifiers": {
    "shift": false,
    "control": false,
    "alt": false,
    "meta": false
  },
  "repeat": false
}
```

The first keyboard implementation prioritizes common physical `KeyboardEvent.code` values, control keys, arrows, and modifiers. It does not claim full IME or keyboard-layout coverage.

### `input.reset`

```json
{
  "version": 1,
  "type": "input.reset",
  "sequence": 5,
  "timestampMs": 1710000000004,
  "reason": "disconnect"
}
```

The browser sends reset on blur, visibility changes, reconnect, and disconnect. The Mac agent also clears pressed state when the session ends.

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
- `invalid_input`
- `invalid_json`
- `invalid_offer`
- `negotiation_failed`
- `not_found`
- `permission_missing`
- `session_not_found`
- `unsupported_protocol_version`
