export interface Size {
  width: number;
  height: number;
}

export interface ContainedFrame {
  x: number;
  y: number;
  width: number;
  height: number;
  scale: number;
}

export function computeContainedFrame(stage: Size, content: Size): ContainedFrame {
  if (stage.width <= 0 || stage.height <= 0 || content.width <= 0 || content.height <= 0) {
    return {
      x: 0,
      y: 0,
      width: 0,
      height: 0,
      scale: 0,
    };
  }

  const scale = Math.min(stage.width / content.width, stage.height / content.height);
  const width = Math.round(content.width * scale);
  const height = Math.round(content.height * scale);

  return {
    x: Math.round((stage.width - width) / 2),
    y: Math.round((stage.height - height) / 2),
    width,
    height,
    scale,
  };
}
