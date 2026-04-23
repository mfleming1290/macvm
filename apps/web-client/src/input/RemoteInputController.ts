import {
  ControlMessage,
  InputResetMessage,
  KeyboardKeyMessage,
  MouseButton,
  MouseButtonMessage,
  MouseMoveMessage,
  MouseWheelMessage,
  PROTOCOL_VERSION,
} from "@macvm/protocol";
import { normalizedVideoPoint } from "./videoCoordinates";

type SendControlMessage = (message: ControlMessage) => void;

export class RemoteInputController {
  private readonly pressedButtons = new Set<MouseButton>();
  private readonly pressedKeys = new Set<string>();
  private readonly send: SendControlMessage;
  private readonly surface: HTMLElement;
  private readonly video: HTMLVideoElement;
  private isActive = false;
  private sequence = 0;

  constructor(surface: HTMLElement, video: HTMLVideoElement, send: SendControlMessage) {
    this.surface = surface;
    this.video = video;
    this.send = send;
  }

  attach(): void {
    this.surface.tabIndex = 0;
    this.surface.addEventListener("contextmenu", this.preventDefault);
    this.surface.addEventListener("pointerdown", this.handlePointerDown);
    this.surface.addEventListener("pointermove", this.handlePointerMove);
    this.surface.addEventListener("pointerup", this.handlePointerUp);
    this.surface.addEventListener("pointercancel", this.handlePointerCancel);
    this.surface.addEventListener("wheel", this.handleWheel, { passive: false });
    window.addEventListener("keydown", this.handleKeyDown, { capture: true });
    window.addEventListener("keyup", this.handleKeyUp, { capture: true });
    window.addEventListener("blur", this.handleBlur);
    document.addEventListener("visibilitychange", this.handleVisibilityChange);
  }

  detach(reason: InputResetMessage["reason"] = "disconnect"): void {
    this.reset(reason);
    this.surface.removeEventListener("contextmenu", this.preventDefault);
    this.surface.removeEventListener("pointerdown", this.handlePointerDown);
    this.surface.removeEventListener("pointermove", this.handlePointerMove);
    this.surface.removeEventListener("pointerup", this.handlePointerUp);
    this.surface.removeEventListener("pointercancel", this.handlePointerCancel);
    this.surface.removeEventListener("wheel", this.handleWheel);
    window.removeEventListener("keydown", this.handleKeyDown, { capture: true });
    window.removeEventListener("keyup", this.handleKeyUp, { capture: true });
    window.removeEventListener("blur", this.handleBlur);
    document.removeEventListener("visibilitychange", this.handleVisibilityChange);
  }

  reset(reason: InputResetMessage["reason"]): void {
    this.pressedButtons.clear();
    this.pressedKeys.clear();
    this.send(this.baseMessage("input.reset", { reason }));
  }

  private readonly handlePointerDown = (event: PointerEvent) => {
    const button = mouseButtonFromEvent(event);
    if (!button) {
      return;
    }

    const point = normalizedVideoPoint(this.video, event.clientX, event.clientY);
    if (!point) {
      return;
    }

    event.preventDefault();
    this.isActive = true;
    this.surface.focus();
    this.surface.setPointerCapture(event.pointerId);
    this.pressedButtons.add(button);
    this.send(
      this.baseMessage("input.mouse.button", {
        action: "down",
        button,
        buttons: Array.from(this.pressedButtons),
        x: point.x,
        y: point.y,
      } satisfies Omit<MouseButtonMessage, "version" | "type" | "sequence" | "timestampMs">),
    );
  };

  private readonly handlePointerMove = (event: PointerEvent) => {
    const point = normalizedVideoPoint(this.video, event.clientX, event.clientY);
    if (!point) {
      return;
    }

    event.preventDefault();
    this.send(
      this.baseMessage("input.mouse.move", {
        buttons: Array.from(this.pressedButtons),
        x: point.x,
        y: point.y,
      } satisfies Omit<MouseMoveMessage, "version" | "type" | "sequence" | "timestampMs">),
    );
  };

  private readonly handlePointerUp = (event: PointerEvent) => {
    const button = mouseButtonFromEvent(event);
    if (!button) {
      return;
    }

    const point = normalizedVideoPoint(this.video, event.clientX, event.clientY);
    if (!point) {
      this.pressedButtons.delete(button);
      return;
    }

    event.preventDefault();
    this.pressedButtons.delete(button);
    this.send(
      this.baseMessage("input.mouse.button", {
        action: "up",
        button,
        buttons: Array.from(this.pressedButtons),
        x: point.x,
        y: point.y,
      } satisfies Omit<MouseButtonMessage, "version" | "type" | "sequence" | "timestampMs">),
    );
  };

  private readonly handlePointerCancel = () => {
    this.reset("blur");
  };

  private readonly handleWheel = (event: WheelEvent) => {
    const point = normalizedVideoPoint(this.video, event.clientX, event.clientY);
    if (!point) {
      return;
    }

    event.preventDefault();
    this.send(
      this.baseMessage("input.mouse.wheel", {
        deltaX: normalizedWheelDelta(event.deltaX, event.deltaMode),
        deltaY: normalizedWheelDelta(event.deltaY, event.deltaMode),
        x: point.x,
        y: point.y,
      } satisfies Omit<MouseWheelMessage, "version" | "type" | "sequence" | "timestampMs">),
    );
  };

  private readonly handleKeyDown = (event: KeyboardEvent) => {
    if (!this.shouldHandleKeyboardEvent(event)) {
      return;
    }

    event.preventDefault();
    this.pressedKeys.add(event.code);
    this.sendKeyboard(event, "down");
  };

  private readonly handleKeyUp = (event: KeyboardEvent) => {
    if (!this.shouldHandleKeyboardEvent(event)) {
      return;
    }

    event.preventDefault();
    this.pressedKeys.delete(event.code);
    this.sendKeyboard(event, "up");
  };

  private readonly handleBlur = () => {
    this.isActive = false;
    this.reset("blur");
  };

  private readonly handleVisibilityChange = () => {
    if (document.hidden) {
      this.isActive = false;
      this.reset("visibilitychange");
    }
  };

  private readonly preventDefault = (event: Event) => {
    event.preventDefault();
  };

  private shouldHandleKeyboardEvent(event: KeyboardEvent): boolean {
    if (!this.isActive) {
      return false;
    }

    const target = event.target;
    if (
      target instanceof HTMLInputElement ||
      target instanceof HTMLTextAreaElement ||
      target instanceof HTMLSelectElement ||
      (target instanceof HTMLElement && target.isContentEditable)
    ) {
      return false;
    }

    return true;
  }

  private sendKeyboard(event: KeyboardEvent, action: KeyboardKeyMessage["action"]): void {
    this.send(
      this.baseMessage("input.keyboard.key", {
        action,
        code: event.code,
        key: event.key,
        modifiers: {
          alt: event.altKey,
          control: event.ctrlKey,
          meta: event.metaKey,
          shift: event.shiftKey,
        },
        repeat: event.repeat,
      } satisfies Omit<KeyboardKeyMessage, "version" | "type" | "sequence" | "timestampMs">),
    );
  }

  private baseMessage<TType extends ControlMessage["type"], TPayload extends object>(
    type: TType,
    payload: TPayload,
  ): Extract<ControlMessage, { type: TType }> {
    return {
      version: PROTOCOL_VERSION,
      type,
      sequence: ++this.sequence,
      timestampMs: Date.now(),
      ...payload,
    } as unknown as Extract<ControlMessage, { type: TType }>;
  }
}

function mouseButtonFromEvent(event: PointerEvent): MouseButton | null {
  if (event.button === 0) {
    return "left";
  }

  if (event.button === 2) {
    return "right";
  }

  return null;
}

function normalizedWheelDelta(delta: number, deltaMode: number): number {
  if (deltaMode === WheelEvent.DOM_DELTA_LINE) {
    return delta * 16;
  }

  if (deltaMode === WheelEvent.DOM_DELTA_PAGE) {
    return delta * window.innerHeight;
  }

  return delta;
}
