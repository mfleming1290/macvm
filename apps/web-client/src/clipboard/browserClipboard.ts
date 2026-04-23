export async function readBrowserClipboardText(): Promise<string> {
  const clipboard = navigator.clipboard;
  if (!clipboard?.readText) {
    throw new Error("Browser clipboard reading is not available in this browser or origin.");
  }

  return clipboard.readText();
}

export async function writeBrowserClipboardText(text: string): Promise<void> {
  const clipboard = navigator.clipboard;
  if (!clipboard?.writeText) {
    throw new Error("Browser clipboard writing is not available in this browser or origin.");
  }

  await clipboard.writeText(text);
}
