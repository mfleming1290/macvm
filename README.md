# macvm

`macvm` is a first-pass browser-based remote desktop MVP for macOS.

It includes:

- a Swift macOS agent that captures the primary display with ScreenCaptureKit
- a local HTTP signaling endpoint hosted by the agent
- a LiveKitWebRTC peer in the agent that publishes the captured screen as video
- a Vite React web client that connects with browser-native WebRTC and renders the stream in a `<video>` element

Keyboard and mouse control are intentionally not implemented yet.

## Project Structure

```text
apps/
  mac-agent/      SwiftUI macOS app, ScreenCaptureKit capture, signaling, WebRTC transport
  web-client/     Vite React browser client
packages/
  protocol/       Shared TypeScript protocol contracts for signaling
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
cd apps/mac-agent
swift build
```

The Mac agent depends on LiveKit's WebRTC XCFramework distributed through Swift Package Manager. The first resolve may take a while.

## Run

Start the macOS agent:

```sh
cd apps/mac-agent
swift run MacAgent
```

The agent opens a SwiftUI status window and starts the signaling server on `http://0.0.0.0:8080`.

Grant Screen Recording permission when prompted. If macOS does not show a prompt, open System Settings and enable Screen Recording for the built app or terminal host used to launch it.

Start the web client:

```sh
npm run dev:web
```

Open the Vite URL from another machine on the same network. Enter the Mac agent base URL, for example:

```text
http://<mac-lan-ip>:8080
```

Click **Connect**. The browser creates a WebRTC offer, sends it to the agent, receives an answer, exchanges ICE candidates through the agent's minimal HTTP endpoints, and renders the Mac screen in the video element.

This MVP is local-network development infrastructure with no input control. Do not expose it to the public internet.

## Minimal Flow

1. Mac agent launches and checks Screen Recording permission.
2. Browser clicks connect and creates a WebRTC offer.
3. Browser sends the offer to `POST /api/sessions`.
4. Agent creates a WebRTC peer, starts ScreenCaptureKit capture, and returns an answer.
5. Browser and agent exchange ICE candidates over HTTP.
6. Browser receives the remote video track and renders the Mac display.
