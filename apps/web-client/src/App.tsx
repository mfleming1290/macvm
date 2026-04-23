import { FormEvent, useRef, useState } from "react";
import { AgentConnection, ConnectionState } from "./webrtc/AgentConnection";

const defaultAgentUrl = "http://localhost:8080";

export default function App() {
  const [agentUrl, setAgentUrl] = useState(defaultAgentUrl);
  const [connectionState, setConnectionState] = useState<ConnectionState>("idle");
  const [error, setError] = useState<string | null>(null);
  const connectionRef = useRef<AgentConnection | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  async function connect(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    await connectionRef.current?.disconnect();

    const connection = new AgentConnection(agentUrl, {
      onError: setError,
      onRemoteStream: (stream) => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
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
        <video ref={videoRef} autoPlay playsInline muted />
      </section>
    </main>
  );
}
