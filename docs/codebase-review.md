# Codebase Review

This pass reviewed the current `macvm` MVP as a cleanup pass, not a feature pass. The WebRTC signaling/media path, browser rendering model, DataChannel shape, and input pipeline were preserved.

## Reviewed Areas

- macOS agent session lifecycle, signaling server, ScreenCaptureKit capture, WebRTC transport, DataChannel handling, input injection, clipboard service, permissions UI, and dev app signing script.
- Web client connection lifecycle, ICE polling, diagnostics, contained-frame viewport mapping, input normalization, stream controls, and clipboard sync UI.
- Shared TypeScript protocol definitions, Swift protocol mirrors, README, AGENTS.md, and docs for protocol, development, and permissions.

## Safe Fixes Made

- Tightened Swift stream-quality validation so `resolutionPreset` must match the documented/shared TypeScript protocol values: `native`, `1440p`, `1080p`, or `720p`.
- Rejected unsupported initial session stream presets at HTTP signaling time instead of silently falling through to the 1080p behavior.
- Made the minimal HTTP request parser tolerate duplicate query keys and duplicate headers without trapping the agent process; duplicate values now use the last value observed.
- Removed a dead private capture helper and an unused React ref.
- Added regression coverage for unsupported stream presets and duplicate HTTP keys.

## Remaining Concerns

- The protocol contract is mirrored manually between `packages/protocol/src/index.ts` and Swift structs/validators. This is workable for the MVP, but it remains a drift risk; this pass found one such gap in stream preset validation.
- `docs/protocol.md` is mostly accurate, but the `POST /api/sessions` response section is separated from the request by the DataChannel message section, which makes the document harder to scan.
- Clipboard auto-sync has simple snapshot checks to avoid obvious loops, but it still needs manual browser testing across secure/insecure origins and user-gesture requirements.
- The dev app build on this machine used ad-hoc signing. That matches the documented fallback, but Screen Recording and Accessibility persistence still need testing with a stable Apple Development identity.
- Live video, remote input, clipboard exchange, reconnect behavior, and permission prompts require manual testing on a Mac with the built app launched and permissions configured.

## Recommended Next Task

Add protocol parity tests or a tiny shared-schema validation check that exercises stream settings, clipboard messages, control messages, diagnostics, and error responses across the TypeScript and Swift protocol mirrors. Keep it test-only first; avoid codegen unless drift continues.

## Verification Run

- `npm run typecheck`
- `cd apps/mac-agent && swift test`
- `npm run build`
- `npm run build:agent-app`

The final `npm run build:agent-app` completed with `Identifier=com.matt.macvm.agent`, `Signature=adhoc`, and `TeamIdentifier=not set`.

## Manual Testing Still Needed

- Launch `apps/mac-agent/build/macvm Agent.app`, confirm permission status, and check `/api/health`.
- Connect from the web client and verify live video, contained-frame resize behavior, mouse/keyboard input, disconnect/reconnect cleanup, runtime bitrate/FPS changes, and text clipboard send/fetch/copy/auto-sync.
