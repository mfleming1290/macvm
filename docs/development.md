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
- `Transport/` owns LiveKitWebRTC peer connection setup and the outgoing video track.
- `Signaling/` owns the local HTTP endpoints.
- `Permissions/` owns Screen Recording permission checks.
- `Session/` owns one-viewer session state.

## Verification

Run these before considering the MVP healthy:

```sh
npm run build
cd apps/mac-agent && swift test
npm run build:agent-app
```

Manual verification requires a Mac with Screen Recording permission granted:

1. First launch: run `npm run build:agent-app`, open `apps/mac-agent/build/macvm Agent.app`, and confirm the SwiftUI window shows signaling status.
2. Permission grant: click the permission button if needed, grant Screen Recording to **macvm Agent** in System Settings, then restart the app.
3. Health check: run `curl http://127.0.0.1:8080/api/health` and confirm JSON includes `status: "ok"` and `screenRecordingAllowed: true`.
4. Successful stream: start the web client with `npm run dev:web`, open it from another machine or browser profile, connect to `http://<mac-lan-ip>:8080`, and confirm live video appears.
5. Disconnect/reconnect: click Disconnect, then Connect again, and confirm the browser receives a fresh stream without restarting the agent.
6. Agent unreachable failure: stop the agent, click Connect, and confirm the browser reports that the Mac agent cannot be reached.
7. Permission failure: revoke Screen Recording for **macvm Agent**, restart the app, click Connect, and confirm the browser reports that Screen Recording permission is missing.
8. CORS/preflight: from the web dev-server origin, confirm browser requests to `http://<mac-lan-ip>:8080/api/*` are not blocked by CORS.
