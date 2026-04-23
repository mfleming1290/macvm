import {
  AddIceCandidateRequest,
  CreateSessionRequest,
  CreateSessionResponse,
  IceCandidatesResponse,
  PROTOCOL_VERSION,
} from "@macvm/protocol";

export type ConnectionState =
  | "idle"
  | "connecting"
  | "connected"
  | "disconnected"
  | "failed";

export interface AgentConnectionEvents {
  onRemoteStream: (stream: MediaStream) => void;
  onStateChange: (state: ConnectionState) => void;
  onError: (message: string) => void;
}

export class AgentConnection {
  private readonly agentBaseUrl: string;
  private readonly events: AgentConnectionEvents;
  private icePollTimer: number | undefined;
  private iceCursor = 0;
  private peer: RTCPeerConnection | undefined;
  private sessionId: string | undefined;

  constructor(agentBaseUrl: string, events: AgentConnectionEvents) {
    this.agentBaseUrl = agentBaseUrl.replace(/\/$/, "");
    this.events = events;
  }

  async connect(): Promise<void> {
    this.events.onStateChange("connecting");

    const peer = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    });
    this.peer = peer;

    peer.addTransceiver("video", { direction: "recvonly" });

    peer.ontrack = (event) => {
      const [stream] = event.streams;
      if (stream) {
        this.events.onRemoteStream(stream);
      }
    };

    peer.onconnectionstatechange = () => {
      if (peer.connectionState === "connected") {
        this.events.onStateChange("connected");
      }
      if (peer.connectionState === "disconnected") {
        this.events.onStateChange("disconnected");
      }
      if (peer.connectionState === "failed" || peer.connectionState === "closed") {
        this.events.onStateChange("failed");
      }
    };

    peer.onicecandidate = (event) => {
      if (event.candidate && this.sessionId) {
        void this.sendIceCandidate(event.candidate);
      }
    };

    const offer = await peer.createOffer();
    await peer.setLocalDescription(offer);

    const response = await this.postJson<CreateSessionResponse>("/api/sessions", {
      version: PROTOCOL_VERSION,
      offer: {
        type: "offer",
        sdp: offer.sdp ?? "",
      },
    } satisfies CreateSessionRequest);

    this.sessionId = response.sessionId;
    await peer.setRemoteDescription(response.answer);
    this.startIcePolling();
  }

  async disconnect(): Promise<void> {
    window.clearInterval(this.icePollTimer);
    this.icePollTimer = undefined;

    if (this.sessionId) {
      try {
        await fetch(`${this.agentBaseUrl}/api/sessions/${this.sessionId}`, {
          method: "DELETE",
        });
      } catch {
        // Closing locally is still safe if the agent is already gone.
      }
    }

    this.peer?.close();
    this.peer = undefined;
    this.sessionId = undefined;
    this.iceCursor = 0;
    this.events.onStateChange("disconnected");
  }

  private startIcePolling(): void {
    this.icePollTimer = window.setInterval(() => {
      void this.pollAgentIce();
    }, 500);
    void this.pollAgentIce();
  }

  private async pollAgentIce(): Promise<void> {
    if (!this.sessionId || !this.peer) {
      return;
    }

    try {
      const response = await this.getJson<IceCandidatesResponse>(
        `/api/sessions/${this.sessionId}/ice?since=${this.iceCursor}`,
      );
      this.iceCursor = response.nextCursor;

      for (const candidate of response.candidates) {
        await this.peer.addIceCandidate(candidate);
      }
    } catch (error) {
      this.events.onError(error instanceof Error ? error.message : String(error));
    }
  }

  private async sendIceCandidate(candidate: RTCIceCandidate): Promise<void> {
    if (!this.sessionId) {
      return;
    }

    await this.postJson(`/api/sessions/${this.sessionId}/ice`, {
      version: PROTOCOL_VERSION,
      candidate: {
        candidate: candidate.candidate,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      },
    } satisfies AddIceCandidateRequest);
  }

  private async getJson<T>(path: string): Promise<T> {
    const response = await fetch(`${this.agentBaseUrl}${path}`);
    if (!response.ok) {
      throw new Error(`Agent request failed: ${response.status}`);
    }
    return response.json() as Promise<T>;
  }

  private async postJson<T = unknown>(path: string, body: unknown): Promise<T> {
    const response = await fetch(`${this.agentBaseUrl}${path}`, {
      body: JSON.stringify(body),
      headers: { "Content-Type": "application/json" },
      method: "POST",
    });
    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || `Agent request failed: ${response.status}`);
    }
    return response.json() as Promise<T>;
  }
}
