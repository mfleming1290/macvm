# macOS Permissions

The first MVP requires Screen Recording permission because the Mac agent captures the display with ScreenCaptureKit.

The app checks permission at launch using `CGPreflightScreenCaptureAccess()` and can trigger the system prompt with `CGRequestScreenCaptureAccess()`.

If capture fails:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Screen Recording.
4. Enable permission for the app or the terminal host used to launch it during development.
5. Restart the Mac agent.

Accessibility permission is not required yet because keyboard and mouse input are intentionally out of scope for this version.
