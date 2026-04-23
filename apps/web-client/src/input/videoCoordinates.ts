export interface NormalizedPoint {
  x: number;
  y: number;
}

export function normalizedVideoPoint(
  video: HTMLVideoElement,
  clientX: number,
  clientY: number,
): NormalizedPoint | null {
  const bounds = video.getBoundingClientRect();
  const content = videoContentRect(video);

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

function videoContentRect(video: HTMLVideoElement) {
  const bounds = video.getBoundingClientRect();
  const videoWidth = video.videoWidth || bounds.width;
  const videoHeight = video.videoHeight || bounds.height;
  const elementRatio = bounds.width / bounds.height;
  const videoRatio = videoWidth / videoHeight;

  if (elementRatio > videoRatio) {
    const width = bounds.height * videoRatio;
    return {
      x: (bounds.width - width) / 2,
      y: 0,
      width,
      height: bounds.height,
    };
  }

  const height = bounds.width / videoRatio;
  return {
    x: 0,
    y: (bounds.height - height) / 2,
    width: bounds.width,
    height,
  };
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}
