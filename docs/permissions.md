# macOS Permissions

The first MVP requires Screen Recording permission because the Mac agent captures the display with ScreenCaptureKit.

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

If capture fails:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Screen Recording.
4. Enable permission for **macvm Agent**.
5. Restart the Mac agent.

Accessibility permission is not required yet because keyboard and mouse input are intentionally out of scope for this version.
