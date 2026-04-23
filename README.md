# macvm

`macvm` is a first-pass browser-based remote desktop MVP for macOS.

It includes:

- a Swift macOS agent that captures the primary display with ScreenCaptureKit
- a local HTTP signaling endpoint hosted by the agent
- a LiveKitWebRTC peer in the agent that publishes the captured screen as video
- a Vite React web client that connects with browser-native WebRTC and renders the stream in a `<video>` element
- a WebRTC DataChannel control path for mouse, wheel, and keyboard input

## Project Structure

```text
apps/
  mac-agent/      SwiftUI macOS app, ScreenCaptureKit capture, signaling, WebRTC transport, input injection
  web-client/     Vite React browser client and normalized input capture
packages/
  protocol/       Shared TypeScript protocol contracts for signaling and control messages
docs/
  development.md
  permissions.md
  protocol.md
```

## Setup

Install web dependencies:

```sh
npm install
```

Resolve/build the Mac agent:

```sh
npm run build:agent-app
```

The Mac agent depends on LiveKit's WebRTC XCFramework distributed through Swift Package Manager. The first resolve may take a while. The build command creates `apps/mac-agent/build/macvm Agent.app` with the stable bundle identifier `com.matt.macvm.agent`.

## Run

Start the macOS agent:

```sh
open "apps/mac-agent/build/macvm Agent.app"
```

The agent opens a SwiftUI status window and starts the signaling server on `http://0.0.0.0:8080`.

Grant Screen Recording permission when prompted. If macOS does not show a prompt, open System Settings and enable Screen Recording for **macvm Agent**, then restart the app.

Grant Accessibility permission before using remote input. In System Settings, enable Accessibility for **macvm Agent**, then restart or refresh the agent status window.

Start the web client:

```sh
npm run dev:web
```

Open the Vite URL from another machine on the same network. Enter the Mac agent base URL, for example:

```text
http://<mac-lan-ip>:8080
```

Click **Connect**. The browser creates a WebRTC offer, opens a `macvm-control` DataChannel, sends the offer to the agent, receives an answer, exchanges ICE candidates through the agent's minimal HTTP endpoints, and renders the Mac screen in the video element. Once the control channel reports `open`, pointer, wheel, and keyboard events over the remote video surface are sent as normalized protocol messages and injected by the Mac agent.

This MVP is local-network development infrastructure. Do not expose it to the public internet.

## Verify

```sh
npm run build
cd apps/mac-agent && swift test
npm run build:agent-app
```

With the agent app running:

```sh
curl http://127.0.0.1:8080/api/health
```

The response should be JSON with `status: "ok"` when Screen Recording is granted.

For an active stream, `media` should show stable paced frame flow all the way through the sender:

```json
{
  "captureFrames": 244,
  "completeFrames": 244,
  "submittedFrames": 122,
  "droppedPacingFrames": 122,
  "droppedBackpressureFrames": 0,
  "targetFramesPerSecond": 30,
  "capturerFrames": 122,
  "sourceFrames": 122,
  "senderAttached": true,
  "senderTrackReadyState": "live",
  "lastFrameWidth": 1920,
  "lastFrameHeight": 1080
}
```

`captureFrames` counts raw ScreenCaptureKit sample buffers, `submittedFrames` counts frames admitted after the 30 fps pacing gate, and `droppedBackpressureFrames` counts stale frames discarded inside the custom WebRTC capturer when the sender is still busy. During fast motion, a healthy low-latency session may show pacing or backpressure drops, but it should not build an ever-growing backlog of old frames.

The browser also shows a small Media Diagnostics panel. A healthy stream shows a live remote track, decoded frames, and non-zero video dimensions. The web client constrains the remote video inside the viewport with `object-fit: contain`, so the full desktop should be visible without page scrolling.

For input, `/api/health` should include `accessibilityAllowed: true` and a `control` object. During an active controlled session, `control.channelState` should become `open`, `receivedMessages` should increase as input is captured, and `injectedEvents` should increase when Accessibility permission allows injection.

## Minimal Flow

1. Mac agent launches and checks Screen Recording permission.
2. Browser clicks connect and creates a WebRTC offer.
3. Browser sends the offer to `POST /api/sessions`.
4. Agent starts ScreenCaptureKit capture, attaches the screen track to the negotiated video transceiver, and returns an answer.
5. Browser and agent exchange ICE candidates over HTTP.
6. Browser receives the remote video track and renders the Mac display.
7. Browser sends normalized input messages over the WebRTC DataChannel.
8. Agent maps normalized coordinates to the captured display and injects input through CoreGraphics.

## Viewport and Quality Notes

The browser shell is fixed to `100vw` by `100vh` with page-level overflow hidden. Inside the center stage, the browser computes an explicit floating frame from the stage size and intrinsic stream size, then renders the video into that frame. That frame preserves aspect ratio, scales to the largest contained size, and is reused for pointer mapping diagnostics.

The agent caps oversized capture output to a 1920-pixel long edge while preserving display aspect ratio, then sets the WebRTC sender to a higher-bitrate screen-stream profile. Capture is paced at 30 fps, ScreenCaptureKit queue depth is kept low, and the custom WebRTC bridge keeps only the newest pending frame under load so latency does not grow behind old desktop frames. The browser bitrate slider now supports up to 50 Mbps, but changes are committed on release instead of being applied continuously during drag so interaction stays responsive.
