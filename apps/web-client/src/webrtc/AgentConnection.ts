import {
  AddIceCandidateRequest,
  AgentErrorCode,
  ControlMessage,
  CreateSessionRequest,
  CreateSessionResponse,
  HealthResponse,
  IceCandidatesResponse,
  PROTOCOL_VERSION,
  StreamQualitySettings,
  isCreateSessionResponse,
  isErrorResponse,
  isHealthResponse,
  isIceCandidatesResponse,
} from "@macvm/protocol";

export type ConnectionState =
  | "idle"
  | "connecting"
  | "connected"
  | "disconnected"
  | "failed";

export type ControlChannelState = "none" | "connecting" | "open" | "closing" | "closed";

export interface AgentConnectionEvents {
  onDiagnostics: (diagnostics: ConnectionDiagnostics) => void;
  onRemoteStream: (stream: MediaStream) => void;
  onStateChange: (state: ConnectionState) => void;
  onError: (message: string) => void;
}

export interface ConnectionDiagnostics {
  controlChannelState: ControlChannelState;
  connectionState: RTCPeerConnectionState | "none";
  iceConnectionState: RTCIceConnectionState | "none";
  signalingState: RTCSignalingState | "none";
  remoteTrackCount: number;
  remoteVideoTrackState: string;
  inboundFramesDecoded: number | null;
  inboundFrameWidth: number | null;
  inboundFrameHeight: number | null;
  selectedBitrateBps: number | null;
  selectedResolutionPreset: string | null;
}

export class AgentConnection {
  private readonly agentBaseUrl: string;
  private readonly events: AgentConnectionEvents;
  private diagnosticsTimer: number | undefined;
  private icePollTimer: number | undefined;
  private iceCursor = 0;
  private isDisconnecting = false;
  private pendingLocalCandidates: RTCIceCandidate[] = [];
  private peer: RTCPeerConnection | undefined;
  private streamSettings: StreamQualitySettings;
  private sessionId: string | undefined;
  private controlChannel: RTCDataChannel | undefined;

  constructor(agentBaseUrl: string, events: AgentConnectionEvents, streamSettings: StreamQualitySettings) {
    this.agentBaseUrl = agentBaseUrl.replace(/\/$/, "");
    this.events = events;
    this.streamSettings = streamSettings;
  }

  async connect(): Promise<void> {
    this.events.onStateChange("connecting");
    this.isDisconnecting = false;
    await this.assertAgentReady();

    const peer = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    });
    this.peer = peer;

    peer.addTransceiver("video", { direction: "recvonly" });
    this.controlChannel = this.createControlChannel(peer);

    peer.ontrack = (event) => {
      const [stream] = event.streams;
      this.emitDiagnostics();
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
      if (peer.connectionState === "failed") {
        this.events.onStateChange("failed");
      }
      if (peer.connectionState === "closed" && !this.isDisconnecting) {
        this.events.onStateChange("failed");
      }
      this.emitDiagnostics();
    };

    peer.oniceconnectionstatechange = () => {
      this.emitDiagnostics();
    };

    peer.onsignalingstatechange = () => {
      this.emitDiagnostics();
    };

    peer.onicecandidate = (event) => {
      if (!event.candidate) {
        return;
      }

      if (this.sessionId) {
        void this.sendIceCandidate(event.candidate);
      } else {
        this.pendingLocalCandidates.push(event.candidate);
      }
    };

    try {
      const offer = await peer.createOffer();
      await peer.setLocalDescription(offer);

      const response = await this.postJson<CreateSessionResponse>(
        "/api/sessions",
        {
          version: PROTOCOL_VERSION,
          offer: {
            type: "offer",
            sdp: offer.sdp ?? "",
          },
          stream: this.streamSettings,
        } satisfies CreateSessionRequest,
        isCreateSessionResponse,
      );

      this.sessionId = response.sessionId;
      await peer.setRemoteDescription(response.answer);
      await this.flushPendingLocalCandidates();
      this.startStatsPolling();
      this.emitDiagnostics();
    } catch (error) {
      await this.disconnect();
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.isDisconnecting = true;
    this.stopIcePolling();
    window.clearInterval(this.diagnosticsTimer);
    this.diagnosticsTimer = undefined;

    this.sendReset("disconnect");

    if (this.sessionId) {
      try {
        await fetch(`${this.agentBaseUrl}/api/sessions/${this.sessionId}`, {
          method: "DELETE",
        });
      } catch {
        // Closing locally is still safe if the agent is already gone.
      }
    }

    this.controlChannel?.close();
    this.controlChannel = undefined;
    this.peer?.close();
    this.peer = undefined;
    this.sessionId = undefined;
    this.iceCursor = 0;
    this.pendingLocalCandidates = [];
    this.events.onStateChange("disconnected");
    this.emitDiagnostics();
    this.isDisconnecting = false;
  }

  sendControlMessage(message: ControlMessage): boolean {
    if (!this.controlChannel || this.controlChannel.readyState !== "open") {
      return false;
    }

    this.controlChannel.send(JSON.stringify(message));
    return true;
  }

  updateStreamQuality(settings: StreamQualitySettings): boolean {
    this.streamSettings = settings;
    return this.sendControlMessage({
      version: PROTOCOL_VERSION,
      type: "stream.quality.update",
      sequence: 0,
      timestampMs: Date.now(),
      settings,
    });
  }

  private createControlChannel(peer: RTCPeerConnection): RTCDataChannel {
    const channel = peer.createDataChannel("macvm-control", { ordered: true });
    channel.onopen = () => this.emitDiagnostics();
    channel.onclose = () => this.emitDiagnostics();
    channel.onerror = () => {
      this.events.onError("The input control channel reported an error.");
      this.emitDiagnostics();
    };
    return channel;
  }

  private sendReset(reason: "disconnect" | "reconnect" | "manual"): void {
    this.sendControlMessage({
      version: PROTOCOL_VERSION,
      type: "input.reset",
      sequence: 0,
      timestampMs: Date.now(),
      reason,
    });
  }

  private startIcePolling(): void {
    this.stopIcePolling();
    this.icePollTimer = window.setInterval(() => {
      void this.pollAgentIce();
    }, 500);
    void this.pollAgentIce();
  }

  private startStatsPolling(): void {
    this.startIcePolling();
    window.clearInterval(this.diagnosticsTimer);
    this.diagnosticsTimer = window.setInterval(() => {
      void this.emitDiagnostics();
    }, 500);
    void this.emitDiagnostics();
  }

  private stopIcePolling(): void {
    window.clearInterval(this.icePollTimer);
    this.icePollTimer = undefined;
  }

  private async pollAgentIce(): Promise<void> {
    if (!this.sessionId || !this.peer) {
      return;
    }

    try {
      const response = await this.getJson<IceCandidatesResponse>(
        `/api/sessions/${this.sessionId}/ice?since=${this.iceCursor}`,
        isIceCandidatesResponse,
      );
      this.iceCursor = response.nextCursor;

      for (const candidate of response.candidates) {
        await this.peer.addIceCandidate(candidate);
      }
    } catch (error) {
      if (error instanceof AgentRequestError && error.code === "session_not_found") {
        this.sessionId = undefined;
        this.stopIcePolling();

        if (this.peer.connectionState !== "connected") {
          this.events.onStateChange("failed");
          this.events.onError(error.message);
        }
        return;
      }

      this.events.onError(error instanceof Error ? error.message : String(error));
    }
  }

  private async emitDiagnostics(): Promise<void> {
    const peer = this.peer;
    if (!peer) {
      this.events.onDiagnostics({
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
      });
      return;
    }

    const receivers = peer.getReceivers();
    const videoReceiver = receivers.find((receiver) => receiver.track?.kind === "video");
    const diagnostics: ConnectionDiagnostics = {
      controlChannelState: this.controlChannel?.readyState ?? "none",
      connectionState: peer.connectionState,
      iceConnectionState: peer.iceConnectionState,
      signalingState: peer.signalingState,
      remoteTrackCount: receivers.filter((receiver) => receiver.track).length,
      remoteVideoTrackState: videoReceiver?.track.readyState ?? "none",
      inboundFramesDecoded: null,
      inboundFrameWidth: null,
      inboundFrameHeight: null,
      selectedBitrateBps: this.streamSettings.maxBitrateBps,
      selectedResolutionPreset: this.streamSettings.resolutionPreset,
    };

    if (videoReceiver) {
      const stats = await videoReceiver.getStats();
      for (const report of stats.values()) {
        if (report.type !== "inbound-rtp" || report.kind !== "video") {
          continue;
        }

        diagnostics.inboundFramesDecoded = typeof report.framesDecoded === "number" ? report.framesDecoded : null;
        diagnostics.inboundFrameWidth = typeof report.frameWidth === "number" ? report.frameWidth : null;
        diagnostics.inboundFrameHeight = typeof report.frameHeight === "number" ? report.frameHeight : null;
      }
    }

    this.events.onDiagnostics(diagnostics);
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

  private async flushPendingLocalCandidates(): Promise<void> {
    const candidates = this.pendingLocalCandidates;
    this.pendingLocalCandidates = [];

    for (const candidate of candidates) {
      await this.sendIceCandidate(candidate);
    }
  }

  private async assertAgentReady(): Promise<void> {
    const health = await this.getJson<HealthResponse>("/api/health", isHealthResponse);

    if (!health.screenRecordingAllowed || health.status === "permissionMissing") {
      throw new Error(
        "The Mac agent is reachable, but Screen Recording permission is not granted. Grant it in System Settings, restart the agent app, then reconnect.",
      );
    }

    if (health.status !== "ok") {
      throw new Error(
        `The Mac agent is not ready (${health.status}): ${health.lastError ?? health.sessionStatus}`,
      );
    }
  }

  private async getJson<T>(path: string, isExpected: (value: unknown) => value is T): Promise<T> {
    const response = await this.fetchAgent(path);
    return this.readJson(response, isExpected);
  }

  private async postJson<T = unknown>(
    path: string,
    body: unknown,
    isExpected?: (value: unknown) => value is T,
  ): Promise<T> {
    const response = await this.fetchAgent(path, {
      body: JSON.stringify(body),
      headers: { "Content-Type": "application/json" },
      method: "POST",
    });

    if (!isExpected) {
      return undefined as T;
    }

    return this.readJson(response, isExpected);
  }

  private async fetchAgent(path: string, init?: RequestInit): Promise<Response> {
    try {
      const response = await fetch(`${this.agentBaseUrl}${path}`, init);
      if (!response.ok) {
        await this.throwAgentError(response);
      }
      return response;
    } catch (error) {
      if (error instanceof TypeError) {
        throw new Error(
          `Could not reach the Mac agent at ${this.agentBaseUrl}. Check that the app is running, the URL is correct, and both devices are on the same network.`,
        );
      }
      throw error;
    }
  }

  private async readJson<T>(
    response: Response,
    isExpected: (value: unknown) => value is T,
  ): Promise<T> {
    const contentType = response.headers.get("Content-Type") ?? "";
    if (!contentType.includes("application/json")) {
      throw new Error(
        `The Mac agent returned an unsupported response (${response.status}, ${contentType || "no content type"}).`,
      );
    }

    const value: unknown = await response.json();
    if (!isExpected(value)) {
      throw new Error("The Mac agent returned a response that does not match the shared protocol.");
    }

    return value;
  }

  private async throwAgentError(response: Response): Promise<never> {
    const contentType = response.headers.get("Content-Type") ?? "";
    if (contentType.includes("application/json")) {
      const value: unknown = await response.json();
      if (isErrorResponse(value)) {
        throw new AgentRequestError(response.status, value.error.code, value.error.message);
      }
      throw new Error(`The Mac agent returned an unsupported error response (${response.status}).`);
    }

    const message = await response.text();
    throw new Error(message || `Agent request failed: ${response.status}`);
  }
}

class AgentRequestError extends Error {
  readonly code: AgentErrorCode;
  readonly status: number;

  constructor(status: number, code: AgentErrorCode, message: string) {
    super(message);
    this.name = "AgentRequestError";
    this.status = status;
    this.code = code;
  }
}
