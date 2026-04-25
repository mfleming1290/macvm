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
  stream?: StreamQualitySettings;
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
  submittedFrames: number;
  droppedFrames: number;
  droppedIncompleteFrames: number;
  droppedPacingFrames: number;
  droppedBackpressureFrames: number;
  targetFramesPerSecond: number;
  requestedFramesPerSecond: number;
  effectiveFramesPerSecond: number;
  capturerFrames: number;
  sourceFrames: number;
  lastFrameWidth: number | null;
  lastFrameHeight: number | null;
  lastPixelFormat: string | null;
  lastTimestampNs: number | null;
  sourceDisplayWidth: number | null;
  sourceDisplayHeight: number | null;
  selectedStreamMaxLongEdge: number | null;
  selectedBitrateBps: number | null;
  senderAttached: boolean;
  senderTrackEnabled: boolean;
  senderTrackReadyState: string;
  localCandidates: number;
  signalingState: string;
  iceConnectionState: string;
  clientDecodedFrames: number | null;
  clientDroppedFrames: number | null;
  clientEstimatedFramesPerSecond: number | null;
  clientFrameWidth: number | null;
  clientFrameHeight: number | null;
  clientJitterMs: number | null;
  clientRoundTripTimeMs: number | null;
  clientBitrateBps: number | null;
}

export interface ControlDiagnostics {
  channelState: "none" | "connecting" | "open" | "closing" | "closed";
  accessibilityAllowed: boolean;
  receivedMessages: number;
  injectedEvents: number;
  resetCount: number;
  clipboardReads: number;
  clipboardWrites: number;
  lastClipboardTextLength: number | null;
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
  | "input.reset"
  | "stream.quality.update"
  | "clipboard.set"
  | "clipboard.get"
  | "clipboard.value"
  | "clipboard.error"
  | "stream.stats.report";

export type StreamResolutionPreset = "native" | "1440p" | "1080p" | "720p";

export interface StreamQualitySettings {
  maxBitrateBps: number;
  framesPerSecond: 30 | 45 | 60;
  resolutionPreset: StreamResolutionPreset;
}

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

export interface StreamQualityUpdateMessage extends ControlMessageBase {
  type: "stream.quality.update";
  settings: StreamQualitySettings;
}

export type ClipboardSource = "browser" | "agent";
export type ClipboardErrorCode = "empty" | "non_text" | "read_failed" | "write_failed";

export interface ClipboardSetMessage extends ControlMessageBase {
  type: "clipboard.set";
  source: ClipboardSource;
  text: string;
}

export interface ClipboardGetMessage extends ControlMessageBase {
  type: "clipboard.get";
  source: ClipboardSource;
}

export interface ClipboardValueMessage extends ControlMessageBase {
  type: "clipboard.value";
  source: ClipboardSource;
  replyToSequence: number | null;
  text: string;
}

export interface ClipboardErrorMessage extends ControlMessageBase {
  type: "clipboard.error";
  source: ClipboardSource;
  replyToSequence: number | null;
  code: ClipboardErrorCode;
  message: string;
}

export interface StreamStatsReportMessage extends ControlMessageBase {
  type: "stream.stats.report";
  stats: StreamClientStats;
}

export interface StreamClientStats {
  decodedFrames: number | null;
  droppedFrames: number | null;
  estimatedFramesPerSecond: number | null;
  frameWidth: number | null;
  frameHeight: number | null;
  jitterMs: number | null;
  roundTripTimeMs: number | null;
  bitrateBps: number | null;
}

export type ControlMessage =
  | MouseMoveMessage
  | MouseButtonMessage
  | MouseWheelMessage
  | KeyboardKeyMessage
  | InputResetMessage
  | StreamQualityUpdateMessage
  | ClipboardSetMessage
  | ClipboardGetMessage
  | ClipboardValueMessage
  | ClipboardErrorMessage
  | StreamStatsReportMessage;

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
    isAgentHealthStatus(value.status) &&
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
    isAgentErrorCode(value.error.code) &&
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
    case "stream.quality.update":
      return isStreamQualitySettings(value.settings);
    case "clipboard.set":
      return isClipboardSource(value.source) && typeof value.text === "string";
    case "clipboard.get":
      return isClipboardSource(value.source);
    case "clipboard.value":
      return (
        isClipboardSource(value.source) &&
        (typeof value.replyToSequence === "number" || value.replyToSequence === null) &&
        typeof value.text === "string"
      );
    case "clipboard.error":
      return (
        isClipboardSource(value.source) &&
        (typeof value.replyToSequence === "number" || value.replyToSequence === null) &&
        isClipboardErrorCode(value.code) &&
        typeof value.message === "string"
      );
    case "stream.stats.report":
      return isStreamClientStats(value.stats);
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
    typeof value.submittedFrames === "number" &&
    typeof value.droppedFrames === "number" &&
    typeof value.droppedIncompleteFrames === "number" &&
    typeof value.droppedPacingFrames === "number" &&
    typeof value.droppedBackpressureFrames === "number" &&
    typeof value.targetFramesPerSecond === "number" &&
    typeof value.requestedFramesPerSecond === "number" &&
    typeof value.effectiveFramesPerSecond === "number" &&
    typeof value.capturerFrames === "number" &&
    typeof value.sourceFrames === "number" &&
    (typeof value.lastFrameWidth === "number" || value.lastFrameWidth === null) &&
    (typeof value.lastFrameHeight === "number" || value.lastFrameHeight === null) &&
    (typeof value.lastPixelFormat === "string" || value.lastPixelFormat === null) &&
    (typeof value.lastTimestampNs === "number" || value.lastTimestampNs === null) &&
    (typeof value.sourceDisplayWidth === "number" || value.sourceDisplayWidth === null) &&
    (typeof value.sourceDisplayHeight === "number" || value.sourceDisplayHeight === null) &&
    (typeof value.selectedStreamMaxLongEdge === "number" || value.selectedStreamMaxLongEdge === null) &&
    (typeof value.selectedBitrateBps === "number" || value.selectedBitrateBps === null) &&
    typeof value.senderAttached === "boolean" &&
    typeof value.senderTrackEnabled === "boolean" &&
    typeof value.senderTrackReadyState === "string" &&
    typeof value.localCandidates === "number" &&
    typeof value.signalingState === "string" &&
    typeof value.iceConnectionState === "string" &&
    (typeof value.clientDecodedFrames === "number" || value.clientDecodedFrames === null) &&
    (typeof value.clientDroppedFrames === "number" || value.clientDroppedFrames === null) &&
    (typeof value.clientEstimatedFramesPerSecond === "number" || value.clientEstimatedFramesPerSecond === null) &&
    (typeof value.clientFrameWidth === "number" || value.clientFrameWidth === null) &&
    (typeof value.clientFrameHeight === "number" || value.clientFrameHeight === null) &&
    (typeof value.clientJitterMs === "number" || value.clientJitterMs === null) &&
    (typeof value.clientRoundTripTimeMs === "number" || value.clientRoundTripTimeMs === null) &&
    (typeof value.clientBitrateBps === "number" || value.clientBitrateBps === null)
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
    typeof value.clipboardReads === "number" &&
    typeof value.clipboardWrites === "number" &&
    (typeof value.lastClipboardTextLength === "number" || value.lastClipboardTextLength === null) &&
    typeof value.pressedKeys === "number" &&
    typeof value.pressedButtons === "number" &&
    (isControlMessageType(value.lastMessageType) || value.lastMessageType === null) &&
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

function isStreamQualitySettings(value: unknown): value is StreamQualitySettings {
  return (
    isRecord(value) &&
    typeof value.maxBitrateBps === "number" &&
    value.maxBitrateBps >= 1_000_000 &&
    value.maxBitrateBps <= 100_000_000 &&
    (value.framesPerSecond === 30 || value.framesPerSecond === 45 || value.framesPerSecond === 60) &&
    (value.resolutionPreset === "native" ||
      value.resolutionPreset === "1440p" ||
      value.resolutionPreset === "1080p" ||
      value.resolutionPreset === "720p")
  );
}

function isStreamClientStats(value: unknown): value is StreamClientStats {
  return (
    isRecord(value) &&
    (typeof value.decodedFrames === "number" || value.decodedFrames === null) &&
    (typeof value.droppedFrames === "number" || value.droppedFrames === null) &&
    (typeof value.estimatedFramesPerSecond === "number" || value.estimatedFramesPerSecond === null) &&
    (typeof value.frameWidth === "number" || value.frameWidth === null) &&
    (typeof value.frameHeight === "number" || value.frameHeight === null) &&
    (typeof value.jitterMs === "number" || value.jitterMs === null) &&
    (typeof value.roundTripTimeMs === "number" || value.roundTripTimeMs === null) &&
    (typeof value.bitrateBps === "number" || value.bitrateBps === null)
  );
}

function isClipboardSource(value: unknown): value is ClipboardSource {
  return value === "browser" || value === "agent";
}

function isClipboardErrorCode(value: unknown): value is ClipboardErrorCode {
  return (
    value === "empty" ||
    value === "non_text" ||
    value === "read_failed" ||
    value === "write_failed"
  );
}

function isAgentErrorCode(value: unknown): value is AgentErrorCode {
  return (
    value === "capture_failed" ||
    value === "invalid_ice_candidate" ||
    value === "invalid_input" ||
    value === "invalid_json" ||
    value === "invalid_offer" ||
    value === "negotiation_failed" ||
    value === "not_found" ||
    value === "permission_missing" ||
    value === "session_not_found" ||
    value === "unsupported_protocol_version"
  );
}

function isAgentHealthStatus(value: unknown): value is AgentHealthStatus {
  return (
    value === "ok" ||
    value === "permissionMissing" ||
    value === "accessibilityMissing" ||
    value === "captureFailed" ||
    value === "negotiationFailed" ||
    value === "serverFailed"
  );
}

function isControlMessageType(value: unknown): value is ControlMessageType {
  return (
    value === "input.mouse.move" ||
    value === "input.mouse.button" ||
    value === "input.mouse.wheel" ||
    value === "input.keyboard.key" ||
    value === "input.reset" ||
    value === "stream.quality.update" ||
    value === "clipboard.set" ||
    value === "clipboard.get" ||
    value === "clipboard.value" ||
    value === "clipboard.error" ||
    value === "stream.stats.report"
  );
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
