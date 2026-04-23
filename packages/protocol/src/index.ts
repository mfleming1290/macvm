export const PROTOCOL_VERSION = 1;

export type AgentHealthStatus =
  | "ok"
  | "permissionMissing"
  | "accessibilityMissing"
  | "captureFailed"
  | "negotiationFailed"
  | "serverFailed";

export type AgentErrorCode =
  | "capture_failed"
  | "invalid_ice_candidate"
  | "invalid_input"
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
  accessibilityAllowed: boolean;
  sessionStatus: string;
  serverStatus: string;
  lastError: string | null;
  media: MediaDiagnostics;
  control: ControlDiagnostics;
}

export interface MediaDiagnostics {
  captureFrames: number;
  completeFrames: number;
  droppedFrames: number;
  capturerFrames: number;
  sourceFrames: number;
  lastFrameWidth: number | null;
  lastFrameHeight: number | null;
  lastPixelFormat: string | null;
  lastTimestampNs: number | null;
  senderAttached: boolean;
  senderTrackEnabled: boolean;
  senderTrackReadyState: string;
  localCandidates: number;
  signalingState: string;
  iceConnectionState: string;
}

export interface ControlDiagnostics {
  channelState: "none" | "connecting" | "open" | "closing" | "closed";
  accessibilityAllowed: boolean;
  receivedMessages: number;
  injectedEvents: number;
  resetCount: number;
  pressedKeys: number;
  pressedButtons: number;
  lastMessageType: ControlMessageType | null;
  lastMappedX: number | null;
  lastMappedY: number | null;
  lastError: string | null;
}

export type ControlMessageType =
  | "input.mouse.move"
  | "input.mouse.button"
  | "input.mouse.wheel"
  | "input.keyboard.key"
  | "input.reset";

export type MouseButton = "left" | "right";
export type InputAction = "down" | "up";

export interface ModifierState {
  shift: boolean;
  control: boolean;
  alt: boolean;
  meta: boolean;
}

export interface ControlMessageBase {
  version: typeof PROTOCOL_VERSION;
  type: ControlMessageType;
  sequence: number;
  timestampMs: number;
}

export interface MouseMoveMessage extends ControlMessageBase {
  type: "input.mouse.move";
  x: number;
  y: number;
  buttons: MouseButton[];
}

export interface MouseButtonMessage extends ControlMessageBase {
  type: "input.mouse.button";
  button: MouseButton;
  action: InputAction;
  x: number;
  y: number;
  buttons: MouseButton[];
}

export interface MouseWheelMessage extends ControlMessageBase {
  type: "input.mouse.wheel";
  deltaX: number;
  deltaY: number;
  x: number;
  y: number;
}

export interface KeyboardKeyMessage extends ControlMessageBase {
  type: "input.keyboard.key";
  action: InputAction;
  code: string;
  key: string;
  modifiers: ModifierState;
  repeat: boolean;
}

export interface InputResetMessage extends ControlMessageBase {
  type: "input.reset";
  reason: "blur" | "disconnect" | "reconnect" | "visibilitychange" | "manual";
}

export type ControlMessage =
  | MouseMoveMessage
  | MouseButtonMessage
  | MouseWheelMessage
  | KeyboardKeyMessage
  | InputResetMessage;

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
    typeof value.accessibilityAllowed === "boolean" &&
    typeof value.sessionStatus === "string" &&
    typeof value.serverStatus === "string" &&
    (typeof value.lastError === "string" || value.lastError === null) &&
    isMediaDiagnostics(value.media) &&
    isControlDiagnostics(value.control)
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

export function isControlMessage(value: unknown): value is ControlMessage {
  if (!isControlMessageBase(value)) {
    return false;
  }

  switch (value.type) {
    case "input.mouse.move":
      return isNormalizedCoordinate(value.x) && isNormalizedCoordinate(value.y) && isMouseButtonArray(value.buttons);
    case "input.mouse.button":
      return (
        isMouseButton(value.button) &&
        isInputAction(value.action) &&
        isNormalizedCoordinate(value.x) &&
        isNormalizedCoordinate(value.y) &&
        isMouseButtonArray(value.buttons)
      );
    case "input.mouse.wheel":
      return (
        typeof value.deltaX === "number" &&
        typeof value.deltaY === "number" &&
        isNormalizedCoordinate(value.x) &&
        isNormalizedCoordinate(value.y)
      );
    case "input.keyboard.key":
      return (
        isInputAction(value.action) &&
        typeof value.code === "string" &&
        typeof value.key === "string" &&
        isModifierState(value.modifiers) &&
        typeof value.repeat === "boolean"
      );
    case "input.reset":
      return (
        value.reason === "blur" ||
        value.reason === "disconnect" ||
        value.reason === "reconnect" ||
        value.reason === "visibilitychange" ||
        value.reason === "manual"
      );
  }
}

function isIceCandidate(value: unknown): value is IceCandidateMessage {
  return (
    isRecord(value) &&
    typeof value.candidate === "string" &&
    (typeof value.sdpMid === "string" || value.sdpMid === null) &&
    (typeof value.sdpMLineIndex === "number" || value.sdpMLineIndex === null)
  );
}

function isMediaDiagnostics(value: unknown): value is MediaDiagnostics {
  return (
    isRecord(value) &&
    typeof value.captureFrames === "number" &&
    typeof value.completeFrames === "number" &&
    typeof value.droppedFrames === "number" &&
    typeof value.capturerFrames === "number" &&
    typeof value.sourceFrames === "number" &&
    (typeof value.lastFrameWidth === "number" || value.lastFrameWidth === null) &&
    (typeof value.lastFrameHeight === "number" || value.lastFrameHeight === null) &&
    (typeof value.lastPixelFormat === "string" || value.lastPixelFormat === null) &&
    (typeof value.lastTimestampNs === "number" || value.lastTimestampNs === null) &&
    typeof value.senderAttached === "boolean" &&
    typeof value.senderTrackEnabled === "boolean" &&
    typeof value.senderTrackReadyState === "string" &&
    typeof value.localCandidates === "number" &&
    typeof value.signalingState === "string" &&
    typeof value.iceConnectionState === "string"
  );
}

function isControlDiagnostics(value: unknown): value is ControlDiagnostics {
  return (
    isRecord(value) &&
    (value.channelState === "none" ||
      value.channelState === "connecting" ||
      value.channelState === "open" ||
      value.channelState === "closing" ||
      value.channelState === "closed") &&
    typeof value.accessibilityAllowed === "boolean" &&
    typeof value.receivedMessages === "number" &&
    typeof value.injectedEvents === "number" &&
    typeof value.resetCount === "number" &&
    typeof value.pressedKeys === "number" &&
    typeof value.pressedButtons === "number" &&
    (typeof value.lastMessageType === "string" || value.lastMessageType === null) &&
    (typeof value.lastMappedX === "number" || value.lastMappedX === null) &&
    (typeof value.lastMappedY === "number" || value.lastMappedY === null) &&
    (typeof value.lastError === "string" || value.lastError === null)
  );
}

function isControlMessageBase(value: unknown): value is ControlMessage {
  return (
    isRecord(value) &&
    value.version === PROTOCOL_VERSION &&
    typeof value.type === "string" &&
    typeof value.sequence === "number" &&
    typeof value.timestampMs === "number"
  );
}

function isModifierState(value: unknown): value is ModifierState {
  return (
    isRecord(value) &&
    typeof value.shift === "boolean" &&
    typeof value.control === "boolean" &&
    typeof value.alt === "boolean" &&
    typeof value.meta === "boolean"
  );
}

function isMouseButton(value: unknown): value is MouseButton {
  return value === "left" || value === "right";
}

function isInputAction(value: unknown): value is InputAction {
  return value === "down" || value === "up";
}

function isMouseButtonArray(value: unknown): value is MouseButton[] {
  return Array.isArray(value) && value.every(isMouseButton);
}

function isNormalizedCoordinate(value: unknown): value is number {
  return typeof value === "number" && value >= 0 && value <= 1;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
