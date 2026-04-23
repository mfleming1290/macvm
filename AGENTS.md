# Project Instructions

This file defines the architecture, structure, protocol contract, implementation rules, and operating assumptions for `macvm`.

All code and documentation must follow these guidelines. If the codebase changes materially, update this file and the relevant docs in the same change.

## Documentation Maintenance Rule

`AGENTS.md` is a living source of truth.

Whenever architecture, transport choices, signaling behavior, protocol contracts, permissions flow, encoding approach, or client interaction rules change materially, update all of these in the same change:

- `AGENTS.md`
- `README.md`
- any protocol or API reference docs
- any developer setup doc
- any deployment or signing notes

Do not leave obsolete architecture guidance in place after implementation changes.

## Product Goal

The product is a personal, local-first remote desktop tool for a Mac, with a browser-based viewer as the first client.

The current direction is:

- one macOS agent running on the target Mac
- one browser client running on another device
- low-latency screen streaming from the Mac to the browser
- future low-latency mouse and keyboard return path from the browser back to the Mac agent
- future local input injection on the Mac through approved macOS APIs
- a simple session model suitable for a single-user software-KVM workflow

This is not a marketplace plugin system, a team collaboration product, or a cloud-first remote access SaaS.

## Current MVP Scope

The first working version proves the media stack only:

- screen capture on macOS
- WebRTC-compatible real-time video delivery to a browser
- browser rendering with a `<video>` element
- minimal HTTP signaling for offer, answer, and ICE candidates
- one active viewer session
- explicit Screen Recording permission handling

Mouse, keyboard, coordinate mapping, Accessibility permission, data-channel control, and stuck-input cleanup are intentionally deferred until the input/control milestone.

Out of scope for the current MVP:

- mouse and keyboard control
- remote audio
- multi-user collaboration
- file transfer
- mobile clients
- enterprise auth
- cloud relay infrastructure beyond minimal signaling if needed later
- polished installers and production signing automation
- clipboard sync
- multi-monitor orchestration

## Platform Architecture

The live architecture is:

```text
apps/
  mac-agent/
    Resources/
    Sources/
    Tests/
    scripts/
  web-client/
    src/
    public/
packages/
  protocol/
docs/
  protocol.md
  permissions.md
  development.md
```

Logical boundaries:

- `apps/mac-agent/` owns capture, media encoding/frame delivery, WebRTC peer setup, local HTTP signaling, session lifecycle, permission checks, and diagnostics.
- `apps/web-client/` owns session join UI, browser-side WebRTC setup, remote video rendering, connection state, and diagnostics.
- `packages/protocol/` owns browser-facing protocol definitions. Do not duplicate message contracts ad hoc.

## Core System Model

The stack currently has three active planes:

- Capture plane: ScreenCaptureKit captures the Mac display.
- Media transport plane: WebRTC transports live video to the browser.
- Session/signaling plane: the Mac agent hosts minimal HTTP endpoints for offer, answer, ICE, health, and teardown.

The control plane is future work. When added, it must use normalized protocol messages, session-bound authorization, centralized coordinate mapping, and macOS-native input injection through approved APIs.

## Technology Direction

### Mac Agent

- Swift
- SwiftUI app lifecycle and status UI
- generated development `.app` bundle with bundle identifier `com.matt.macvm.agent`
- ScreenCaptureKit for screen capture
- LiveKitWebRTC for native WebRTC media
- Network.framework for the minimal local HTTP signaling server
- centralized Screen Recording permission checks

### Web Client

- TypeScript
- React with Vite
- browser-native WebRTC
- a single remote-view page with minimal chrome

### Shared

- TypeScript definitions for HTTP signaling messages
- versioned protocol constants
- future canonical input event schemas only when input control is implemented

Do not introduce heavy backend frameworks, databases, brokers, or cloud services without a clear reason.

## Signaling Contract

The Mac agent exposes:

- `GET /api/health`
- `POST /api/sessions`
- `POST /api/sessions/{sessionId}/ice`
- `GET /api/sessions/{sessionId}/ice?since={cursor}`
- `DELETE /api/sessions/{sessionId}`

All JSON messages must include the shared protocol version where defined. Keep `docs/protocol.md` and `packages/protocol/src/index.ts` synchronized.

Known failures should use versioned JSON error responses instead of plain text where practical.

## Security Rules

The current MVP signaling endpoint is local-network development infrastructure for one viewer and no input control. Do not describe it as hardened internet-safe remote access.

Before input control is added:

- add a real pairing token, session token, or explicit approval flow
- bind media and control to the same authenticated session
- enforce origin/session checks on control messages
- ensure stale sessions expire cleanly

Never add an unauthenticated control endpoint.

## Permissions Rules

The Mac agent must treat macOS permissions as first-class product behavior.

Current permission:

- Screen Recording / screen capture

Future input-control permission:

- Accessibility / input control

Rules:

- never assume permissions are already granted
- use `apps/mac-agent/build/macvm Agent.app` as the primary development runtime path
- keep the bundle identifier stable unless permission migration is explicitly planned
- expose permission state clearly in the app UI and logs
- fail with actionable guidance when permissions are missing
- keep permission logic centralized and testable

## Remote View Rules

The browser remote-view surface is the core product surface.

The current implementation must support:

- connection setup
- live video rendering in a `<video>` element
- connection state display
- obvious disconnect/reconnect affordance

Do not add browser mouse, keyboard, or wheel capture until input control is explicitly in scope.

## Video and Performance Rules

Optimize for responsiveness over visual perfection.

Rules:

- use WebRTC for real-time media
- do not use HLS, DASH, MJPEG, or generic HTTP video playback for the live stream
- keep pipeline copies low where practical
- surface useful diagnostics for permission, session, and negotiation failures
- avoid over-engineered adaptive bitrate before the base stream is reliable

## Testing and Verification

First priorities:

- protocol serialization/deserialization
- CORS/preflight compatibility from the web dev-server origin
- session state transitions
- capture/signaling/WebRTC negotiation behavior
- frontend build correctness
- agent build and launch correctness

Add coordinate mapping, keyboard normalization, and stuck-key cleanup tests when input control is implemented.

Manual MVP verification:

- the Mac agent launches cleanly
- the generated app bundle launches cleanly
- Screen Recording permission state is shown accurately
- the browser can connect to the Mac agent
- the browser receives a live view of the Mac display
- disconnecting closes the media session
- reconnecting restores a clean media session

## First Implementation Milestones

Build in this order unless there is a strong reason not to:

1. Mac agent skeleton with permissions UI/state
2. ScreenCaptureKit capture
3. Browser client skeleton with session join UI
4. Signaling/session setup between browser and Mac agent
5. Live video stream from Mac to browser
6. Disconnect/reconnect cleanup for media sessions
7. Diagnostics and polish
8. Pairing/session hardening before control
9. Data channel or equivalent control channel
10. Mouse movement and click injection
11. Keyboard injection
12. Coordinate mapping hardening

Do not skip to input control before the media stream and session lifecycle are reliable.

## Code Quality Rules

Prefer small, explicit modules with clear ownership.

Rules:

- do not duplicate protocol contracts
- do not mix capture logic with signaling or transport plumbing unnecessarily
- do not hide session state inside unstructured globals
- keep permission logic centralized
- when input exists, keep browser event normalization separate from transport plumbing
- when input exists, keep Mac input injection separate from session transport logic

If a file grows too large, split it by responsibility, not by arbitrary naming.

## Definition Of Done For Current MVP

The current MVP is complete when a user can:

- run the Mac agent
- grant required Screen Recording permission
- open a browser on another machine
- connect to the Mac
- see the Mac display live
- disconnect and reconnect without corrupted media session state

If any of those fail, the current media stack is not yet proven.
