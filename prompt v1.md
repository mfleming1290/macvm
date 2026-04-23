TASK:

Build the first working version of a browser-based remote desktop system for macOS.

The system must:

stream the Mac screen to a browser in real-time
establish a connection between a macOS agent and a browser client
prepare the foundation for future keyboard/mouse control (do NOT implement input yet)
CONTEXT:

Architecture:

macOS agent (runs on target Mac)
browser client (runs on another machine)
real-time connection between them

Tech Stack:

macOS Agent:
Swift
ScreenCaptureKit (for screen capture)
WebRTC (for video streaming)
Web Client:
TypeScript
React (Vite or Next.js acceptable, prefer Vite for simplicity)
WebRTC (browser-native)

System Model:

Mac captures screen → encodes → streams via WebRTC
Browser connects → receives stream → renders video
A signaling mechanism is required (can be simple HTTP or WebSocket)

Project Structure:

apps/
  mac-agent/
  web-client/
packages/
  protocol/
CONSTRAINTS:
General
MUST follow separation of:
capture plane (Mac)
media transport (WebRTC)
signaling/session setup
DO NOT implement mouse/keyboard input yet
DO NOT use high-latency streaming methods (no HLS, no MJPEG)
MUST use WebRTC for video transport
macOS Agent
MUST use ScreenCaptureKit for capture
MUST be a proper macOS app (not just CLI)
MUST include permission handling for:
screen recording
MUST expose a signaling endpoint (HTTP or WebSocket)
MUST act as WebRTC peer
Web Client
MUST render video using <video> element
MUST connect using WebRTC
MUST implement minimal UI:
connect button / input
connection status
MUST NOT include complex UI or dashboards
Signaling
MUST support:
offer
answer
ICE candidates
can be:
simple HTTP endpoints
or WebSocket
MUST be minimal and self-contained
Code Quality
clear separation of concerns
no duplicated protocol definitions
modular structure (capture, signaling, transport separated)
avoid unnecessary dependencies
OUTPUT:

Provide:

Full project structure
Mac agent implementation
ScreenCaptureKit capture setup
WebRTC peer setup
signaling endpoints
Web client implementation
React app
WebRTC connection logic
video rendering
Protocol definitions (if needed)
Setup instructions
how to run mac agent
how to run web client
Minimal working connection flow
open browser → connect → see Mac screen