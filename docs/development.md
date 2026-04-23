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

The web app is intentionally small: one connection form, connection status, and one remote video surface.

## Mac Agent

```sh
cd apps/mac-agent
swift build
swift run MacAgent
```

`MacAgent` is a SwiftUI macOS app target launched through SwiftPM for development. Its code is split by responsibility:

- `Capture/` owns ScreenCaptureKit setup and frame delivery.
- `Transport/` owns LiveKitWebRTC peer connection setup and the outgoing video track.
- `Signaling/` owns the local HTTP endpoints.
- `Permissions/` owns Screen Recording permission checks.
- `Session/` owns one-viewer session state.

## Verification

Run these before considering the MVP healthy:

```sh
npm run build
cd apps/mac-agent && swift build
```

Manual verification requires a Mac with Screen Recording permission granted:

1. Start the agent.
2. Start the web client.
3. Open the browser from another machine or browser profile.
4. Connect to `http://<mac-lan-ip>:8080`.
5. Confirm the browser shows a live Mac display stream.
