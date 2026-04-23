export const PROTOCOL_VERSION = 1;

export type AgentHealthStatus =
  | "ok"
  | "permissionMissing"
  | "captureFailed"
  | "negotiationFailed"
  | "serverFailed";

export type AgentErrorCode =
  | "capture_failed"
  | "invalid_ice_candidate"
  | "invalid_json"
  | "invalid_offer"
  | "negotiation_failed"
  | "not_found"
  | "permission_missing"
  | "session_not_found"
  | "unsupported_protocol_version";

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
  status: AgentHealthStatus;
  activeSession: boolean;
  screenRecordingAllowed: boolean;
  sessionStatus: string;
  serverStatus: string;
  lastError: string | null;
}

export interface ErrorResponse {
  version: typeof PROTOCOL_VERSION;
  error: {
    code: AgentErrorCode;
    message: string;
  };
}

export function isHealthResponse(value: unknown): value is HealthResponse {
  if (!isRecord(value)) {
    return false;
  }

  return (
    value.version === PROTOCOL_VERSION &&
    typeof value.status === "string" &&
    typeof value.activeSession === "boolean" &&
    typeof value.screenRecordingAllowed === "boolean" &&
    typeof value.sessionStatus === "string" &&
    typeof value.serverStatus === "string" &&
    (typeof value.lastError === "string" || value.lastError === null)
  );
}

export function isCreateSessionResponse(value: unknown): value is CreateSessionResponse {
  if (!isRecord(value) || !isRecord(value.answer)) {
    return false;
  }

  return (
    value.version === PROTOCOL_VERSION &&
    typeof value.sessionId === "string" &&
    value.answer.type === "answer" &&
    typeof value.answer.sdp === "string"
  );
}

export function isIceCandidatesResponse(value: unknown): value is IceCandidatesResponse {
  if (!isRecord(value) || !Array.isArray(value.candidates)) {
    return false;
  }

  return (
    value.version === PROTOCOL_VERSION &&
    typeof value.nextCursor === "number" &&
    value.candidates.every(isIceCandidate)
  );
}

export function isErrorResponse(value: unknown): value is ErrorResponse {
  return (
    isRecord(value) &&
    value.version === PROTOCOL_VERSION &&
    isRecord(value.error) &&
    typeof value.error.code === "string" &&
    typeof value.error.message === "string"
  );
}

function isIceCandidate(value: unknown): value is IceCandidateMessage {
  return (
    isRecord(value) &&
    typeof value.candidate === "string" &&
    (typeof value.sdpMid === "string" || value.sdpMid === null) &&
    (typeof value.sdpMLineIndex === "number" || value.sdpMLineIndex === null)
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
