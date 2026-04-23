import { ContainedFrame } from "../view/containedFrame";

export interface NormalizedPoint {
  x: number;
  y: number;
}

export interface VideoContentRect {
  element: DOMRect;
  content: ContainedFrame;
}

export function normalizedFramePoint(
  surface: HTMLElement,
  frame: ContainedFrame,
  clientX: number,
  clientY: number,
): NormalizedPoint | null {
  const { element: bounds, content } = displayedFrameRect(surface, frame);

  if (content.width <= 0 || content.height <= 0) {
    return null;
  }

  const x = clientX - bounds.left - content.x;
  const y = clientY - bounds.top - content.y;

  if (x < 0 || y < 0 || x > content.width || y > content.height) {
    return null;
  }

  return {
    x: clamp01(x / content.width),
    y: clamp01(y / content.height),
  };
}

export function displayedFrameRect(surface: HTMLElement, frame: ContainedFrame): VideoContentRect {
  return {
    element: surface.getBoundingClientRect(),
    content: frame,
  };
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}
