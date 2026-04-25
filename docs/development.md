# Development

## Repo Tooling Note

`macvm` does not currently have an app-side LLM runtime or model-selection setting. If local repo tooling or Codex-facing guidance needs an explicit coding model choice, use GPT-5.5 as the current default baseline.

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

If the default Vite port is busy, override it with:

```sh
WEB_CLIENT_PORT=3000 npm run dev:web
```

You can also set it in [apps/web-client/.env](/Users/matt/Documents/macvm/apps/web-client/.env):

```sh
WEB_CLIENT_PORT=3000
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

### Stable Development Signing

The development app already has a stable bundle identifier and app path. For Screen Recording and Accessibility permission persistence, the remaining variable is the code signature used across rebuilds.

Preferred build:

```sh
MACVM_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" npm run build:agent-app
```

The build script also supports a direct flag:

```sh
apps/mac-agent/scripts/build-dev-app.sh --signing-identity "Apple Development: Your Name (TEAMID)"
```

If no identity is configured, the script tries to auto-detect the first available `Apple Development` certificate from the local keychain. If none is available, it falls back to ad-hoc signing and prints that mode explicitly. Ad-hoc fallback keeps local development unblocked, but permission persistence across rebuilds is not expected to be reliable in that mode.

The build script now updates the existing `apps/mac-agent/build/macvm Agent.app` in place, signs `LiveKitWebRTC.framework`, signs the app bundle, and verifies the result.

To inspect the current built app identity:

```sh
codesign -dv --verbose=4 "apps/mac-agent/build/macvm Agent.app" 2>&1 | egrep 'Identifier=|Authority=|TeamIdentifier=|Signature='
```

For stable development permissions, expect:

- `Identifier=com.matt.macvm.agent`
- `Authority=Apple Development: ...`
- a non-empty `TeamIdentifier`

If the output shows `Signature=adhoc`, the build is using the explicit fallback path.

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
- `submittedFrames`: complete frames admitted by the explicit FPS pacing gate.
- `droppedFrames`: total dropped frames across incomplete, pacing, and backpressure paths.
- `droppedIncompleteFrames`: invalid or incomplete ScreenCaptureKit frames filtered out.
- `droppedPacingFrames`: complete frames dropped because they arrived sooner than the current target cadence.
- `droppedBackpressureFrames`: stale frames discarded because the custom WebRTC capturer was still delivering a newer frame.
- `targetFramesPerSecond`: current pacing target for the live pipeline.
- `sourceFrames`: sample buffers handed from capture into the custom LiveKitWebRTC capturer.
- `capturerFrames`: frames actually delivered into the WebRTC video source.
- `senderAttached`: whether the WebRTC sender/transceiver has the screen track.
- `senderTrackReadyState`: expected to be `live` while streaming.
- `lastFrameWidth`, `lastFrameHeight`, `lastPixelFormat`: latest captured frame shape.

Browser-side diagnostics show:

- peer connection and ICE state
- remote video track state
- inbound decoded frame count and dimensions when browser stats expose them
- video element `readyState`, dimensions, and playback state
- computed remote stage size and contained display rect used for rendering and pointer mapping
- DataChannel state for the input control path

For the current LiveKitWebRTC answerer path, the Mac agent starts ScreenCaptureKit first, configures a screencast `RTCVideoSource`, binds the video track to the browser offer's negotiated video transceiver as `sendOnly`, then creates the answer. Capture uses a higher ceiling internally, the submission gate enforces the current effective FPS target, ScreenCaptureKit queue depth stays low, and the custom capturer keeps only the newest pending frame when overloaded. Avoid moving the video sender setup back to a separate pre-offer `addTrack` path unless you re-verify Safari/Chrome negotiation and decoded frame dimensions.

## Browser Viewport Layout

The web client root, body, and app shell are fixed to `100vw` by `100vh` with `overflow: hidden`. The connection panel, remote stage, and diagnostics are laid out inside that single viewport so the page itself never scrolls during a session.

The browser uses an explicit contained-frame helper instead of relying on passive `<video>` layout side effects. Given the measured stage size and intrinsic stream size, it computes one floating frame with `scale = min(stageWidth / videoWidth, stageHeight / videoHeight)`, centers that frame in the stage, and renders the `<video>` to fill it exactly. Browser-side pointer mapping uses that same computed frame, so rendering, diagnostics, and absolute input coordinates stay aligned.

## Video Quality Tuning

The Mac agent keeps the same WebRTC sender path, but capture output is capped to a 1920-pixel long edge when the display is larger. The sender applies the current runtime bitrate/FPS settings, uses high network priority, and keeps a screen-stream-friendly degradation preference.

The intent is to reduce encoder pressure from very large Retina frames while giving motion more bitrate headroom. This should reduce smearing during fast desktop changes without introducing an alternate transport or buffering strategy. Browser bitrate changes are committed on release/blur instead of on every slider movement so the active session does not churn sender parameters continuously.

The stream controls now support:

- bitrate up to 100 Mbps, with a 20 Mbps default
- 30 / 45 / 60 FPS runtime targets
- reconnect-required resolution changes

The agent captures with a higher internal ceiling, but the pacing gate is the authoritative submission control. Under load, the agent may lower the effective submitted FPS below the requested FPS when browser decode/network stats or local stale-frame drops show that the client cannot keep up. This keeps latency bounded instead of allowing old frames to accumulate.

## Control Path Diagnostics

The browser creates a `macvm-control` WebRTC DataChannel before creating the SDP offer. Pointer and keyboard events are normalized in `apps/web-client/src/input/` and sent through `AgentConnection.sendControlMessage`.

The Mac agent receives that DataChannel in `WebRTCSession`, delegates messages to `Input/ControlChannelHandler.swift`, validates the JSON control protocol, maps normalized coordinates with `DisplayCoordinateMapper`, and injects events with CoreGraphics through `InputInjector`.

Agent-side `/api/health` includes:

- `accessibilityAllowed`: whether macOS currently allows input injection.
- `control.channelState`: DataChannel state.
- `control.receivedMessages`: decoded control messages received.
- `control.injectedEvents`: CoreGraphics events posted successfully.
- `control.resetCount`: explicit input cleanup/reset events.
- `control.clipboardReads`: successful plain-text clipboard reads from `NSPasteboard`.
- `control.clipboardWrites`: successful plain-text clipboard writes to `NSPasteboard`.
- `control.lastClipboardTextLength`: latest clipboard text length processed by the agent.
- `control.lastError`: permission, mapping, decode, or injection error details.

Browser-side diagnostics now also report:

- estimated inbound FPS
- inbound dropped frames when exposed by the browser
- estimated inbound bitrate
- RTT and jitter when available from WebRTC stats

The browser periodically reports these stats back to the agent over the existing `macvm-control` DataChannel using `stream.stats.report`. The agent uses that feedback, together with local stale-frame drops, to reduce effective submission FPS before latency grows into visible lag.

This tuning path is still iterative. The current target is stable responsiveness, not maximum throughput, so the agent may intentionally lower effective submitted FPS before old frames are allowed to pile up.

## Clipboard

Clipboard is explicit and text-only in this MVP. The browser uses the existing `macvm-control` WebRTC DataChannel for:

- `clipboard.set`: browser sends text to the Mac clipboard
- `clipboard.get`: browser asks the Mac for its current plain-text clipboard value
- `clipboard.value`: agent returns plain-text clipboard contents
- `clipboard.error`: agent returns empty/non-text/read/write failures

The Mac side uses `NSPasteboard.general` and only reads/writes plain text. Empty clipboard and non-text clipboard contents return explicit clipboard errors instead of pretending a string is available.

The browser UI exposes manual send/fetch actions plus an opt-in auto-sync toggle. Auto-sync is disabled by default and remains best-effort because browser clipboard permissions vary by browser, page focus, and secure-context rules.

## Verification

Run these before considering the MVP healthy:

```sh
npm test
npm run build
cd apps/mac-agent && swift test
npm run build:agent-app
```

`npm test` runs the TypeScript protocol parity tests against the shared JSON fixtures in `protocol-fixtures/`. The Swift test suite also reads those fixtures so protocol drift between `packages/protocol` and the mac-agent mirror fails early.

Manual verification requires a Mac with Screen Recording permission granted:

1. First launch: run `npm run build:agent-app`, open `apps/mac-agent/build/macvm Agent.app`, and confirm the SwiftUI window shows signaling status.
2. Signing check: confirm the build output reports an Apple Development identity, or explicitly says it is using the ad-hoc fallback mode.
3. Permission grant: click the permission buttons if needed, grant Screen Recording and Accessibility to **macvm Agent** in System Settings, then restart the app or refresh status.
4. Rebuild persistence: rebuild with the same Apple Development identity, relaunch the app, and confirm both permissions are still granted without removing and re-adding them.
5. Health check: run `curl http://127.0.0.1:8080/api/health` and confirm JSON includes `status: "ok"`, `screenRecordingAllowed: true`, and `accessibilityAllowed: true`.
6. Successful stream: start the web client with `npm run dev:web`, open it from another machine or browser profile, connect to `http://<mac-lan-ip>:8080`, and confirm live video appears.
7. Frame-flow proof: while connected, confirm `/api/health` has increasing `captureFrames`, `completeFrames`, `submittedFrames`, `sourceFrames`, and `capturerFrames`, with `targetFramesPerSecond: 30`, `senderAttached: true`, and `senderTrackReadyState: "live"`.
8. Pacing proof: during normal motion, `submittedFrames` should grow more slowly than `captureFrames`, and some `droppedPacingFrames` are expected. During overload, `droppedBackpressureFrames` may increase, but it should not explode alongside growing end-to-end lag.
9. Feedback proof: while connected, confirm `/api/health` includes client stats such as `clientEstimatedFramesPerSecond`, `clientRoundTripTimeMs`, and `clientBitrateBps` once the browser has been receiving frames for a moment.
10. Runtime tuning: change bitrate and FPS in the browser, confirm the values commit cleanly instead of churning during slider drag, and confirm `/api/health` reflects the requested/effective FPS fields.
11. Browser decode proof: confirm the Media Diagnostics panel reports a live remote track and non-zero video element dimensions.
12. Viewport fit: confirm the full remote desktop is visible without page scrolling.
13. Resize behavior: resize the browser and confirm the video remains centered, aspect-correct, and fully visible.
14. Motion responsiveness: at 720p or 1080p, move windows quickly and confirm the session feels smoother and less laggy than before, without visible backlog buildup.
15. Disconnect/reconnect: click Disconnect, then Connect again, and confirm the browser receives a fresh stream without restarting the agent.
16. Input channel: confirm the browser diagnostics report control channel `open` after connection.
17. Mouse input: move over the remote video, left click, right click, and scroll; confirm the Mac responds and `/api/health` shows increasing `control.receivedMessages` and `control.injectedEvents`.
18. Mapping accuracy: click near all four corners and the center of the visible remote desktop, including after resizing the browser, and confirm the Mac pointer lands accurately.
19. Keyboard input: focus a simple text field on the Mac through the remote session, type basic letters/numbers, press Enter/Escape/arrow keys, and verify a basic modifier shortcut such as Command+A.
20. Clipboard send: type text into the browser clipboard panel, click **Send To Mac**, then paste on the Mac and confirm the text matches.
21. Clipboard fetch: copy plain text on the Mac, click **Fetch Mac Clipboard**, and confirm the fetched text appears in the browser panel.
22. Clipboard copy-back: click **Copy To Browser** and confirm the browser clipboard now contains the fetched Mac text when browser permissions allow it.
23. Empty/non-text clipboard: clear the Mac clipboard or copy non-text content, fetch again, and confirm the browser shows a clear clipboard error instead of stale text.
24. Stuck-state cleanup: hold a key or mouse button, blur/close/disconnect the browser, and confirm the Mac does not remain stuck in a pressed state.
25. One-viewer behavior: if another tab or machine connects, older tabs may lose the signaling session; they should stop ICE polling instead of spamming repeated `session_not_found` errors.
26. Agent unreachable failure: stop the agent, click Connect, and confirm the browser reports that the Mac agent cannot be reached.
27. Permission failure: revoke Screen Recording for **macvm Agent**, restart the app, click Connect, and confirm the browser reports that Screen Recording permission is missing. Revoke Accessibility and confirm video still works while control diagnostics show an actionable permission error.
28. CORS/preflight: from the web dev-server origin, confirm browser requests to `http://<mac-lan-ip>:8080/api/*` are not blocked by CORS.
