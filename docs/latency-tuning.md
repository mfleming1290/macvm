# Latency Tuning Notes

This note records the current low-latency capture experiment without changing the media architecture.

## Capture Path

- ScreenCaptureKit captures the selected display.
- The agent requests video-range NV12 (`420v`) by default.
- `MACVM_CAPTURE_PIXEL_FORMAT=bgra` restores BGRA capture for rollback comparisons.
- ScreenCaptureKit queue depth defaults to `2`.
- `MACVM_SCK_QUEUE_DEPTH=1` or `3` changes queue depth for local experiments.
- Unsupported environment values fall back to the defaults.
- `minimumFrameInterval` is set to `1 / requestedFramesPerSecond` when capture starts.
- Runtime FPS updates recompute the effective FPS and call `SCStream.updateConfiguration`.

The capture service drops incomplete frames, applies the current pacing gate, and hands only admitted frames to the WebRTC session. The custom LiveKitWebRTC capturer keeps at most one pending sample buffer while it is delivering a frame; if another frame arrives while one is pending, the older pending frame is discarded.

## Diagnostics

`/api/health` reports the fields needed for latency experiments:

- `configuredPixelFormat`
- `configuredQueueDepth`
- `requestedFramesPerSecond`
- `effectiveFramesPerSecond`
- `submittedFrames`
- `droppedPacingFrames`
- `droppedBackpressureFrames`
- `sourceFrames`
- `capturerFrames`
- `clientEstimatedFramesPerSecond`
- `clientDroppedFrames`
- `clientRoundTripTimeMs`
- `clientJitterMs`

For the default low-latency NV12 path, `configuredPixelFormat` and `lastPixelFormat` should both report `420v` after frames arrive.

## Encoder API Findings

The current LiveKitWebRTC Objective-C headers expose:

- `RTCDefaultVideoEncoderFactory.preferredCodec`
- `RTCDefaultVideoEncoderFactory.supportedCodecs`
- `RTCRtpTransceiver.codecPreferences`
- sender encoding parameters such as `maxBitrateBps`, `minBitrateBps`, `maxFramerate`, `bitratePriority`, `networkPriority`, and `scaleResolutionDownBy`
- `RTCVideoSource.adaptOutputFormatToWidth:height:fps:`

The public headers do not expose a direct VideoToolbox low-latency flag such as `kVTVideoEncoderSpecification_EnableLowLatencyRateControl`, B-frame/lookahead controls, or a sender keyframe request API. This pass therefore avoids speculative encoder changes and keeps the existing LiveKitWebRTC encoder factory. Codec preference experiments should be done separately because they affect negotiation behavior.

## Manual Comparison

Compare the default path against fallback settings under the same resolution, FPS, and bitrate:

```sh
MACVM_CAPTURE_PIXEL_FORMAT=bgra MACVM_SCK_QUEUE_DEPTH=3 \
  "apps/mac-agent/build/macvm Agent.app/Contents/MacOS/MacAgent"
```

Then connect the browser and compare `/api/health` plus perceived pointer-to-video latency.
