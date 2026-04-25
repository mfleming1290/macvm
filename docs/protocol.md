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
    "clipboardReads": 0,
    "clipboardWrites": 0,
    "lastClipboardTextLength": null,
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
- `requestedFramesPerSecond`: browser-selected FPS target
- `effectiveFramesPerSecond`: current agent submission FPS after load adaptation
- `sourceFrames`: frames handed into the custom WebRTC capturer
- `capturerFrames`: frames actually delivered into the WebRTC video source
- `clientDecodedFrames`, `clientEstimatedFramesPerSecond`, `clientRoundTripTimeMs`, `clientBitrateBps`: browser receive-side feedback reported over `stream.stats.report`

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

## WebRTC DataChannel Messages

The browser and agent reuse the `macvm-control` WebRTC DataChannel for input, stream settings, and clipboard.

`stream.quality.update` now carries:

- `maxBitrateBps`: 1 Mbps to 100 Mbps
- `framesPerSecond`: `30`, `45`, or `60`
- `resolutionPreset`: `native`, `1440p`, `1080p`, or `720p`

Bitrate and FPS updates apply at runtime. Resolution changes are still reconnect-based in the current MVP.

### `stream.stats.report`

Browser periodically reports live receive-side stats back to the agent over the same DataChannel.

```json
{
  "version": 1,
  "type": "stream.stats.report",
  "sequence": 301,
  "timestampMs": 1713926401000,
  "stats": {
    "decodedFrames": 840,
    "droppedFrames": 12,
    "estimatedFramesPerSecond": 29.4,
    "frameWidth": 1280,
    "frameHeight": 720,
    "jitterMs": 8.5,
    "roundTripTimeMs": 42.0,
    "bitrateBps": 14500000
  }
}
```

Clipboard messages are explicit and text-only:

### `clipboard.set`

Browser sends plain text to the Mac clipboard.

```json
{
  "version": 1,
  "type": "clipboard.set",
  "sequence": 101,
  "timestampMs": 1713926400000,
  "source": "browser",
  "text": "hello from the browser"
}
```

### `clipboard.get`

Browser requests the current Mac clipboard text.

```json
{
  "version": 1,
  "type": "clipboard.get",
  "sequence": 102,
  "timestampMs": 1713926400500,
  "source": "browser"
}
```

### `clipboard.value`

Agent replies with plain text from the Mac clipboard.

```json
{
  "version": 1,
  "type": "clipboard.value",
  "sequence": 501,
  "timestampMs": 1713926400600,
  "source": "agent",
  "replyToSequence": 102,
  "text": "hello from the mac"
}
```

### `clipboard.error`

Agent replies when the Mac clipboard is empty, non-text, or could not be read/written.

```json
{
  "version": 1,
  "type": "clipboard.error",
  "sequence": 502,
  "timestampMs": 1713926400650,
  "source": "agent",
  "replyToSequence": 102,
  "code": "non_text",
  "message": "The Mac clipboard does not currently contain plain text."
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
