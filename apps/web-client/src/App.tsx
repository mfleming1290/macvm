import { FormEvent, useEffect, useRef, useState } from "react";
import { StreamQualitySettings, StreamResolutionPreset } from "@macvm/protocol";
import { RemoteInputController } from "./input/RemoteInputController";
import { displayedFrameRect } from "./input/videoCoordinates";
import { computeContainedFrame, type ContainedFrame } from "./view/containedFrame";
import { AgentConnection, ConnectionDiagnostics, ConnectionState } from "./webrtc/AgentConnection";

const defaultAgentUrl = "http://localhost:8080";

interface VideoDiagnostics {
  intrinsicHeight: number;
  intrinsicWidth: number;
  stageHeight: number;
  stageWidth: number;
  displayedHeight: number;
  displayedWidth: number;
  readyState: number;
  paused: boolean;
  ended: boolean;
  videoWidth: number;
  videoHeight: number;
  playbackError: string | null;
}

const emptyConnectionDiagnostics: ConnectionDiagnostics = {
  controlChannelState: "none",
  connectionState: "none",
  iceConnectionState: "none",
  signalingState: "none",
  remoteTrackCount: 0,
  remoteVideoTrackState: "none",
  inboundFramesDecoded: null,
  inboundFrameWidth: null,
  inboundFrameHeight: null,
  selectedBitrateBps: null,
  selectedResolutionPreset: null,
};

const emptyVideoDiagnostics: VideoDiagnostics = {
  intrinsicHeight: 0,
  intrinsicWidth: 0,
  stageHeight: 0,
  stageWidth: 0,
  displayedHeight: 0,
  displayedWidth: 0,
  readyState: 0,
  paused: true,
  ended: false,
  videoWidth: 0,
  videoHeight: 0,
  playbackError: null,
};

const defaultStreamSettings: StreamQualitySettings = {
  maxBitrateBps: 8_000_000,
  resolutionPreset: "1080p",
};

const bitrateStepMbps = 1;

export default function App() {
  const [agentUrl, setAgentUrl] = useState(defaultAgentUrl);
  const [connectionState, setConnectionState] = useState<ConnectionState>("idle");
  const [connectionDiagnostics, setConnectionDiagnostics] = useState<ConnectionDiagnostics>(
    emptyConnectionDiagnostics,
  );
  const [error, setError] = useState<string | null>(null);
  const [streamSettings, setStreamSettings] = useState<StreamQualitySettings>(defaultStreamSettings);
  const [pendingBitrateMbps, setPendingBitrateMbps] = useState(defaultStreamSettings.maxBitrateBps / 1_000_000);
  const [videoDiagnostics, setVideoDiagnostics] = useState<VideoDiagnostics>(emptyVideoDiagnostics);
  const connectionRef = useRef<AgentConnection | null>(null);
  const frameRef = useRef<HTMLDivElement | null>(null);
  const frameStateRef = useRef<ContainedFrame>({ x: 0, y: 0, width: 0, height: 0, scale: 0 });
  const inputControllerRef = useRef<RemoteInputController | null>(null);
  const stageRef = useRef<HTMLElement | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const lastSentStreamSettingsRef = useRef("");
  const warnedControlNotReadyRef = useRef(false);
  const [frame, setFrame] = useState<ContainedFrame>({ x: 0, y: 0, width: 0, height: 0, scale: 0 });

  useEffect(() => {
    const stage = stageRef.current;
    const video = videoRef.current;
    if (!stage || !video) {
      return;
    }

    const updateMeasurements = () => {
      const stageRect = stage.getBoundingClientRect();
      const nextFrame = computeContainedFrame(
        { width: stageRect.width, height: stageRect.height },
        { width: video.videoWidth, height: video.videoHeight },
      );
      frameStateRef.current = nextFrame;
      setFrame(nextFrame);
      const displayed = displayedFrameRect(stage, nextFrame);
      setVideoDiagnostics((current) => ({
        intrinsicHeight: video.videoHeight,
        intrinsicWidth: video.videoWidth,
        stageHeight: Math.round(stageRect.height),
        stageWidth: Math.round(stageRect.width),
        displayedHeight: Math.round(displayed.content.height),
        displayedWidth: Math.round(displayed.content.width),
        readyState: video.readyState,
        paused: video.paused,
        ended: video.ended,
        videoWidth: video.videoWidth,
        videoHeight: video.videoHeight,
        playbackError: current.playbackError,
      }));
    };

    const observer = new ResizeObserver(() => updateMeasurements());
    observer.observe(stage);
    window.addEventListener("resize", updateMeasurements);
    const timer = window.setInterval(updateMeasurements, 500);
    updateMeasurements();
    return () => {
      observer.disconnect();
      window.removeEventListener("resize", updateMeasurements);
      window.clearInterval(timer);
    };
  }, []);

  useEffect(() => {
    setPendingBitrateMbps(streamSettings.maxBitrateBps / 1_000_000);
  }, [streamSettings.maxBitrateBps]);

  async function connect(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    lastSentStreamSettingsRef.current = "";
    warnedControlNotReadyRef.current = false;

    inputControllerRef.current?.detach("reconnect");
    inputControllerRef.current = null;
    await connectionRef.current?.disconnect();

    const connection = new AgentConnection(
      agentUrl,
      {
        onDiagnostics: (diagnostics) => {
        if (diagnostics.controlChannelState === "open") {
          warnedControlNotReadyRef.current = false;
          sendStreamQuality(connection, streamSettings);
        }
        setConnectionDiagnostics(diagnostics);
      },
      onError: setError,
      onRemoteStream: async (stream) => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          try {
            await videoRef.current.play();
          } catch (playError) {
            setVideoDiagnostics((current) => ({
              ...current,
              playbackError: playError instanceof Error ? playError.message : String(playError),
            }));
          }
        }
      },
        onStateChange: setConnectionState,
      },
      streamSettings,
    );

    connectionRef.current = connection;

    try {
      await connection.connect();
      if (stageRef.current && videoRef.current) {
        const inputController = new RemoteInputController(
          stageRef.current,
          () => frameStateRef.current,
          (message) => {
            if (!connection.sendControlMessage(message)) {
              if (!warnedControlNotReadyRef.current) {
                warnedControlNotReadyRef.current = true;
                setError("Input is not ready yet. Wait for the control channel to open, then try again.");
              }
            }
          },
        );
        inputController.attach();
        inputControllerRef.current = inputController;
      }
    } catch (nextError) {
      inputControllerRef.current?.detach("disconnect");
      inputControllerRef.current = null;
      setConnectionState("failed");
      setError(nextError instanceof Error ? nextError.message : String(nextError));
    }
  }

  async function disconnect() {
    inputControllerRef.current?.detach("disconnect");
    inputControllerRef.current = null;
    await connectionRef.current?.disconnect();
    connectionRef.current = null;
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
    setConnectionDiagnostics(emptyConnectionDiagnostics);
    setVideoDiagnostics(emptyVideoDiagnostics);
  }

  function commitBitrate(nextBitrateMbps: number) {
    const nextSettings = {
      ...streamSettings,
      maxBitrateBps: nextBitrateMbps * 1_000_000,
    };
    setStreamSettings(nextSettings);
    sendStreamQuality(connectionRef.current, nextSettings);
  }

  function handleBitrateDrag(nextBitrateMbps: number) {
    setPendingBitrateMbps(nextBitrateMbps);
  }

  function commitPendingBitrate() {
    if (pendingBitrateMbps === streamSettings.maxBitrateBps / 1_000_000) {
      return;
    }

    commitBitrate(pendingBitrateMbps);
  }

  function updateResolutionPreset(nextPreset: StreamResolutionPreset) {
    const nextSettings = {
      ...streamSettings,
      resolutionPreset: nextPreset,
    };
    setStreamSettings(nextSettings);
    if (connectionState === "connected") {
      setError("Resolution changes apply on the next reconnect. Bitrate changes apply immediately.");
    }
  }

  function sendStreamQuality(connection: AgentConnection | null, settings: StreamQualitySettings) {
    const settingsKey = `${settings.resolutionPreset}:${settings.maxBitrateBps}`;
    if (settingsKey === lastSentStreamSettingsRef.current) {
      return;
    }

    if (connection?.updateStreamQuality(settings)) {
      lastSentStreamSettingsRef.current = settingsKey;
    }
  }

  return (
    <main className="app-shell">
      <section className="connection-panel" aria-label="Connection">
        <div>
          <p className="eyebrow">macvm</p>
          <h1>Remote Mac View</h1>
        </div>

        <form className="connect-form" onSubmit={connect}>
          <label htmlFor="agent-url">Mac agent URL</label>
          <div className="form-row">
            <input
              id="agent-url"
              type="url"
              value={agentUrl}
              onChange={(event) => setAgentUrl(event.target.value)}
              placeholder="http://192.168.1.20:8080"
              required
            />
            <button type="submit" disabled={connectionState === "connecting"}>
              {connectionState === "connecting" ? "Connecting" : "Connect"}
            </button>
            <button className="secondary" type="button" onClick={disconnect}>
              Disconnect
            </button>
          </div>
        </form>

        <div className={`status status-${connectionState}`}>
          Status: <strong>{connectionState}</strong>
        </div>
        <div className="stream-controls" aria-label="Stream quality controls">
          <label htmlFor="bitrate">
            Bitrate <strong>{pendingBitrateMbps} Mbps</strong>
          </label>
          <input
            id="bitrate"
            type="range"
            min="2"
            max="50"
            step={bitrateStepMbps}
            value={pendingBitrateMbps}
            onChange={(event) => handleBitrateDrag(Number(event.target.value))}
            onMouseUp={commitPendingBitrate}
            onTouchEnd={commitPendingBitrate}
            onKeyUp={commitPendingBitrate}
            onBlur={commitPendingBitrate}
          />
          <label htmlFor="resolution-preset">Resolution</label>
          <select
            id="resolution-preset"
            value={streamSettings.resolutionPreset}
            onChange={(event) => updateResolutionPreset(event.target.value as StreamResolutionPreset)}
          >
            <option value="native">Native</option>
            <option value="1440p">1440p</option>
            <option value="1080p">1080p</option>
            <option value="720p">720p</option>
          </select>
        </div>
        {error ? <p className="error">{error}</p> : null}
      </section>

      <section className="remote-stage" aria-label="Remote display" ref={stageRef}>
        <div
          className="remote-frame"
          ref={frameRef}
          style={{
            left: 0,
            top: 0,
            width: `${frame.width}px`,
            height: `${frame.height}px`,
            transform: `translate(${frame.x}px, ${frame.y}px)`,
          }}
        >
          <video
            ref={videoRef}
            autoPlay
            playsInline
            muted
          />
        </div>
      </section>

      <section className="debug-panel" aria-label="Media diagnostics">
        <h2>Media Diagnostics</h2>
        <div className="debug-grid">
          <span>Peer</span>
          <strong>
            {connectionDiagnostics.connectionState} / ICE {connectionDiagnostics.iceConnectionState}
          </strong>
          <span>Signaling</span>
          <strong>{connectionDiagnostics.signalingState}</strong>
          <span>Control channel</span>
          <strong>{connectionDiagnostics.controlChannelState}</strong>
          <span>Remote track</span>
          <strong>
            {connectionDiagnostics.remoteVideoTrackState} ({connectionDiagnostics.remoteTrackCount} tracks)
          </strong>
          <span>Inbound decoded</span>
          <strong>
            {connectionDiagnostics.inboundFramesDecoded ?? "n/a"} frames at{" "}
            {connectionDiagnostics.inboundFrameWidth ?? 0}x{connectionDiagnostics.inboundFrameHeight ?? 0}
          </strong>
          <span>Intrinsic video</span>
          <strong>
            readyState {videoDiagnostics.readyState}, {videoDiagnostics.intrinsicWidth}x
            {videoDiagnostics.intrinsicHeight}, {videoDiagnostics.paused ? "paused" : "playing"}
          </strong>
          <span>Video element</span>
          <strong>
            {videoDiagnostics.videoWidth}x
            {videoDiagnostics.videoHeight}, {videoDiagnostics.paused ? "paused" : "playing"}
          </strong>
          <span>Displayed rect</span>
          <strong>
            {videoDiagnostics.displayedWidth}x{videoDiagnostics.displayedHeight}
          </strong>
          <span>Stage</span>
          <strong>
            {videoDiagnostics.stageWidth}x{videoDiagnostics.stageHeight}
          </strong>
          <span>Stream settings</span>
          <strong>
            {connectionDiagnostics.selectedResolutionPreset ?? streamSettings.resolutionPreset},{" "}
            {(connectionDiagnostics.selectedBitrateBps ?? streamSettings.maxBitrateBps) / 1_000_000} Mbps
          </strong>
          <span>Playback</span>
          <strong>{videoDiagnostics.playbackError ?? "ok"}</strong>
        </div>
      </section>
    </main>
  );
}
