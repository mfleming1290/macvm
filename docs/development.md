# Development

## Prerequisites

- macOS 14 or newer recommended
- Xcode command line tools
- Node.js 20 or newer
- npm 10 or newer

## Web Client

```sh
npm install
npm run dev:web
```

The web app is intentionally small: one connection form, connection status, one remote video surface, and compact diagnostics. Browser input capture is limited to the remote surface and sends normalized control messages over the existing WebRTC connection.

## Mac Agent

```sh
cd apps/mac-agent
swift build
```

`MacAgent` is a SwiftUI macOS app implemented as a SwiftPM executable and launched for development through a generated `.app` bundle. Use the app bundle path for day-to-day runs so macOS Screen Recording permission attaches to the stable bundle identifier `com.matt.macvm.agent`.

From the repo root:

```sh
npm run build:agent-app
open "apps/mac-agent/build/macvm Agent.app"
```

`swift run MacAgent` is still useful for quick compiler/runtime experiments, but it is not the primary runtime path because macOS privacy prompts may attach permission to Terminal or another transient host instead of the app.

The code is split by responsibility:

- `Capture/` owns ScreenCaptureKit setup and frame delivery.
- `Input/` owns Accessibility checks, DataChannel control decoding, coordinate mapping, input state, and CoreGraphics injection.
- `Transport/` owns LiveKitWebRTC peer connection setup and the outgoing video track.
- `Signaling/` owns the local HTTP endpoints.
- `Permissions/` owns Screen Recording permission checks.
- `Session/` owns one-viewer session state.

## Media Pipeline Diagnostics

The Phase 1 stream has diagnostics on both sides so black-video failures can be localized instead of guessed.

Agent-side `/api/health` includes:

- `captureFrames`: ScreenCaptureKit sample buffers received.
- `completeFrames`: ScreenCaptureKit frames with complete frame status.
- `droppedFrames`: incomplete or invalid ScreenCaptureKit frames filtered out.
- `capturerFrames`: frames handed to the custom LiveKitWebRTC capturer.
- `sourceFrames`: frames handed through the WebRTC video source path.
- `senderAttached`: whether the WebRTC sender/transceiver has the screen track.
- `senderTrackReadyState`: expected to be `live` while streaming.
- `lastFrameWidth`, `lastFrameHeight`, `lastPixelFormat`: latest captured frame shape.

Browser-side diagnostics show:

- peer connection and ICE state
- remote video track state
- inbound decoded frame count and dimensions when browser stats expose them
- video element `readyState`, dimensions, and playback state
- DataChannel state for the input control path

For the current LiveKitWebRTC answerer path, the Mac agent starts ScreenCaptureKit first, configures a screencast `RTCVideoSource`, binds the video track to the browser offer's negotiated video transceiver as `sendOnly`, then creates the answer. Avoid moving the video sender setup back to a separate pre-offer `addTrack` path unless you re-verify Safari/Chrome negotiation and decoded frame dimensions.

## Control Path Diagnostics

The browser creates a `macvm-control` WebRTC DataChannel before creating the SDP offer. Pointer and keyboard events are normalized in `apps/web-client/src/input/` and sent through `AgentConnection.sendControlMessage`.

The Mac agent receives that DataChannel in `WebRTCSession`, delegates messages to `Input/ControlChannelHandler.swift`, validates the JSON control protocol, maps normalized coordinates with `DisplayCoordinateMapper`, and injects events with CoreGraphics through `InputInjector`.

Agent-side `/api/health` includes:

- `accessibilityAllowed`: whether macOS currently allows input injection.
- `control.channelState`: DataChannel state.
- `control.receivedMessages`: decoded control messages received.
- `control.injectedEvents`: CoreGraphics events posted successfully.
- `control.resetCount`: explicit input cleanup/reset events.
- `control.lastError`: permission, mapping, decode, or injection error details.

## Verification

Run these before considering the MVP healthy:

```sh
npm run build
cd apps/mac-agent && swift test
npm run build:agent-app
```

Manual verification requires a Mac with Screen Recording permission granted:

1. First launch: run `npm run build:agent-app`, open `apps/mac-agent/build/macvm Agent.app`, and confirm the SwiftUI window shows signaling status.
2. Permission grant: click the permission buttons if needed, grant Screen Recording and Accessibility to **macvm Agent** in System Settings, then restart the app or refresh status.
3. Health check: run `curl http://127.0.0.1:8080/api/health` and confirm JSON includes `status: "ok"`, `screenRecordingAllowed: true`, and `accessibilityAllowed: true`.
4. Successful stream: start the web client with `npm run dev:web`, open it from another machine or browser profile, connect to `http://<mac-lan-ip>:8080`, and confirm live video appears.
5. Frame-flow proof: while connected, confirm `/api/health` has increasing `captureFrames`, `completeFrames`, `capturerFrames`, and `sourceFrames`, with `senderAttached: true` and `senderTrackReadyState: "live"`.
6. Browser decode proof: confirm the Media Diagnostics panel reports a live remote track and non-zero video element dimensions.
7. Disconnect/reconnect: click Disconnect, then Connect again, and confirm the browser receives a fresh stream without restarting the agent.
8. Input channel: confirm the browser diagnostics report control channel `open` after connection.
9. Mouse input: move over the remote video, left click, right click, and scroll; confirm the Mac responds and `/api/health` shows increasing `control.receivedMessages` and `control.injectedEvents`.
10. Keyboard input: focus a simple text field on the Mac through the remote session, type basic letters/numbers, press Enter/Escape/arrow keys, and verify a basic modifier shortcut such as Command+A.
11. Stuck-state cleanup: hold a key or mouse button, blur/close/disconnect the browser, and confirm the Mac does not remain stuck in a pressed state.
12. One-viewer behavior: if another tab or machine connects, older tabs may lose the signaling session; they should stop ICE polling instead of spamming repeated `session_not_found` errors.
13. Agent unreachable failure: stop the agent, click Connect, and confirm the browser reports that the Mac agent cannot be reached.
14. Permission failure: revoke Screen Recording for **macvm Agent**, restart the app, click Connect, and confirm the browser reports that Screen Recording permission is missing. Revoke Accessibility and confirm video still works while control diagnostics show an actionable permission error.
15. CORS/preflight: from the web dev-server origin, confirm browser requests to `http://<mac-lan-ip>:8080/api/*` are not blocked by CORS.
