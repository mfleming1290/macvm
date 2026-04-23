import { FormEvent, useRef, useState } from "react";
import { AgentConnection, ConnectionDiagnostics, ConnectionState } from "./webrtc/AgentConnection";

const defaultAgentUrl = "http://localhost:8080";

interface VideoDiagnostics {
  readyState: number;
  paused: boolean;
  ended: boolean;
  videoWidth: number;
  videoHeight: number;
  playbackError: string | null;
}

const emptyConnectionDiagnostics: ConnectionDiagnostics = {
  connectionState: "none",
  iceConnectionState: "none",
  signalingState: "none",
  remoteTrackCount: 0,
  remoteVideoTrackState: "none",
  inboundFramesDecoded: null,
  inboundFrameWidth: null,
  inboundFrameHeight: null,
};

const emptyVideoDiagnostics: VideoDiagnostics = {
  readyState: 0,
  paused: true,
  ended: false,
  videoWidth: 0,
  videoHeight: 0,
  playbackError: null,
};

export default function App() {
  const [agentUrl, setAgentUrl] = useState(defaultAgentUrl);
  const [connectionState, setConnectionState] = useState<ConnectionState>("idle");
  const [connectionDiagnostics, setConnectionDiagnostics] = useState<ConnectionDiagnostics>(
    emptyConnectionDiagnostics,
  );
  const [error, setError] = useState<string | null>(null);
  const [videoDiagnostics, setVideoDiagnostics] = useState<VideoDiagnostics>(emptyVideoDiagnostics);
  const connectionRef = useRef<AgentConnection | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  async function connect(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    await connectionRef.current?.disconnect();

    const connection = new AgentConnection(agentUrl, {
      onDiagnostics: setConnectionDiagnostics,
      onError: setError,
      onRemoteStream: async (stream) => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          updateVideoDiagnostics();
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
    });

    connectionRef.current = connection;

    try {
      await connection.connect();
    } catch (nextError) {
      setConnectionState("failed");
      setError(nextError instanceof Error ? nextError.message : String(nextError));
    }
  }

  async function disconnect() {
    await connectionRef.current?.disconnect();
    connectionRef.current = null;
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
    setConnectionDiagnostics(emptyConnectionDiagnostics);
    setVideoDiagnostics(emptyVideoDiagnostics);
  }

  function updateVideoDiagnostics() {
    const video = videoRef.current;
    if (!video) {
      return;
    }

    setVideoDiagnostics((current) => ({
      readyState: video.readyState,
      paused: video.paused,
      ended: video.ended,
      videoWidth: video.videoWidth,
      videoHeight: video.videoHeight,
      playbackError: current.playbackError,
    }));
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
        {error ? <p className="error">{error}</p> : null}
      </section>

      <section className="remote-stage" aria-label="Remote display">
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted
          onCanPlay={updateVideoDiagnostics}
          onLoadedMetadata={updateVideoDiagnostics}
          onPause={updateVideoDiagnostics}
          onPlaying={updateVideoDiagnostics}
          onResize={updateVideoDiagnostics}
          onStalled={updateVideoDiagnostics}
          onWaiting={updateVideoDiagnostics}
        />
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
          <span>Remote track</span>
          <strong>
            {connectionDiagnostics.remoteVideoTrackState} ({connectionDiagnostics.remoteTrackCount} tracks)
          </strong>
          <span>Inbound decoded</span>
          <strong>
            {connectionDiagnostics.inboundFramesDecoded ?? "n/a"} frames at{" "}
            {connectionDiagnostics.inboundFrameWidth ?? 0}x{connectionDiagnostics.inboundFrameHeight ?? 0}
          </strong>
          <span>Video element</span>
          <strong>
            readyState {videoDiagnostics.readyState}, {videoDiagnostics.videoWidth}x
            {videoDiagnostics.videoHeight}, {videoDiagnostics.paused ? "paused" : "playing"}
          </strong>
          <span>Playback</span>
          <strong>{videoDiagnostics.playbackError ?? "ok"}</strong>
        </div>
      </section>
    </main>
  );
}
