export const PROTOCOL_VERSION = 1;

export type SessionDescriptionType = "offer" | "answer";

export interface SessionDescriptionMessage {
  type: SessionDescriptionType;
  sdp: string;
}

export interface IceCandidateMessage {
  candidate: string;
  sdpMid: string | null;
  sdpMLineIndex: number | null;
}

export interface CreateSessionRequest {
  version: typeof PROTOCOL_VERSION;
  offer: SessionDescriptionMessage;
}

export interface CreateSessionResponse {
  version: typeof PROTOCOL_VERSION;
  sessionId: string;
  answer: SessionDescriptionMessage;
}

export interface AddIceCandidateRequest {
  version: typeof PROTOCOL_VERSION;
  candidate: IceCandidateMessage;
}

export interface IceCandidatesResponse {
  version: typeof PROTOCOL_VERSION;
  candidates: IceCandidateMessage[];
  nextCursor: number;
}

export interface HealthResponse {
  version: typeof PROTOCOL_VERSION;
  status: "ok";
  activeSession: boolean;
  screenRecordingAllowed: boolean;
}
