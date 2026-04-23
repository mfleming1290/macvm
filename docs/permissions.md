# macOS Permissions

The MVP requires Screen Recording permission for capture and Accessibility permission for remote input.

The app checks permission at launch using `CGPreflightScreenCaptureAccess()` and can trigger the system prompt with `CGRequestScreenCaptureAccess()`.

Use the generated development app bundle for permission testing:

```sh
npm run build:agent-app
open "apps/mac-agent/build/macvm Agent.app"
```

The bundle identifier is stable:

```text
com.matt.macvm.agent
```

This matters because macOS privacy grants are tied to app identity. Avoid using `swift run MacAgent` as the primary runtime path for permission testing, because permission may attach to Terminal or another transient development host.

For rebuild-to-rebuild permission persistence during development, also keep the code signature stable:

```sh
MACVM_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" npm run build:agent-app
```

If `MACVM_CODESIGN_IDENTITY` is not set, the build script tries to auto-detect the first available Apple Development certificate. If none is available, it falls back to ad-hoc signing and prints that mode explicitly. In ad-hoc mode, Screen Recording and Accessibility permissions may need to be removed and re-added after rebuilds.

To inspect the current signature:

```sh
codesign -dv --verbose=4 "apps/mac-agent/build/macvm Agent.app" 2>&1 | egrep 'Identifier=|Authority=|TeamIdentifier|Signature='
```

For persistent permissions, expect the same bundle identifier plus `Authority=Apple Development: ...` rather than `Signature=adhoc`.

If capture fails:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Screen Recording.
4. Enable permission for **macvm Agent**.
5. Restart the Mac agent.

Remote mouse and keyboard control require Accessibility permission because the agent injects local CoreGraphics events.

If input does not work:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable permission for **macvm Agent**.
5. Restart the Mac agent or click **Refresh Status** in the agent window.

The app exposes this state as `accessibilityAllowed` in `/api/health` and in the SwiftUI status window. Video streaming can still work without Accessibility permission, but input messages are ignored with a diagnostic error until the permission is granted.
