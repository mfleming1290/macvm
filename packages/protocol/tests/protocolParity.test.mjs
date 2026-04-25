import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  PROTOCOL_VERSION,
  isControlMessage,
  isCreateSessionResponse,
  isErrorResponse,
  isHealthResponse,
  isIceCandidatesResponse,
} from "../dist/index.js";

const testDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(testDir, "../../..");
const fixturesDir = resolve(repoRoot, "protocol-fixtures");

async function fixture(name) {
  return JSON.parse(await readFile(resolve(fixturesDir, name), "utf8"));
}

function streamQualityMessage(settings) {
  return {
    version: PROTOCOL_VERSION,
    type: "stream.quality.update",
    sequence: 1,
    timestampMs: 1713926400000,
    settings,
  };
}

test("accepts all documented stream quality presets, FPS values, and bitrate bounds", () => {
  for (const resolutionPreset of ["native", "1440p", "1080p", "720p"]) {
    for (const framesPerSecond of [30, 45, 60]) {
      for (const maxBitrateBps of [1_000_000, 20_000_000, 100_000_000]) {
        assert.equal(
          isControlMessage(streamQualityMessage({ maxBitrateBps, framesPerSecond, resolutionPreset })),
          true,
          `${resolutionPreset} ${framesPerSecond}fps ${maxBitrateBps}bps should be accepted`,
        );
      }
    }
  }
});

test("rejects stream quality values outside the documented bounds", () => {
  const invalidSettings = [
    { maxBitrateBps: 999_999, framesPerSecond: 30, resolutionPreset: "1080p" },
    { maxBitrateBps: 100_000_001, framesPerSecond: 30, resolutionPreset: "1080p" },
    { maxBitrateBps: 20_000_000, framesPerSecond: 24, resolutionPreset: "1080p" },
    { maxBitrateBps: 20_000_000, framesPerSecond: 30, resolutionPreset: "4k" },
  ];

  for (const settings of invalidSettings) {
    assert.equal(isControlMessage(streamQualityMessage(settings)), false, JSON.stringify(settings));
  }
});

test("shared stream setting fixtures match protocol expectations", async () => {
  assert.equal(isControlMessage(streamQualityMessage(await fixture("valid-stream-settings.json"))), true);
  assert.equal(isControlMessage(streamQualityMessage(await fixture("invalid-stream-settings.json"))), false);
});

test("shared valid control message fixtures are accepted", async () => {
  const messages = await fixture("valid-control-messages.json");

  for (const message of messages) {
    assert.equal(isControlMessage(message), true, `${message.type} should be accepted`);
  }
});

test("shared invalid control message fixtures are rejected", async () => {
  const cases = await fixture("invalid-control-messages.json");

  for (const { label, message } of cases) {
    assert.equal(isControlMessage(message), false, label);
  }
});

test("session and ICE fixtures match protocol expectations", async () => {
  const sessionRequest = await fixture("valid-create-session-request.json");
  assert.equal(sessionRequest.version, PROTOCOL_VERSION);
  assert.equal(sessionRequest.offer.type, "offer");
  assert.equal(typeof sessionRequest.offer.sdp, "string");
  assert.equal(isControlMessage(streamQualityMessage(sessionRequest.stream)), true);

  const invalidSessionRequest = await fixture("invalid-create-session-request.json");
  assert.notEqual(invalidSessionRequest.version, PROTOCOL_VERSION);
  assert.equal(isControlMessage(streamQualityMessage(invalidSessionRequest.stream)), false);

  const iceResponse = await fixture("valid-ice-candidates-response.json");
  assert.equal(isIceCandidatesResponse(iceResponse), true);

  assert.equal(
    isCreateSessionResponse({
      version: PROTOCOL_VERSION,
      sessionId: "session-1",
      answer: { type: "answer", sdp: "v=0" },
    }),
    true,
  );
});

test("health diagnostics fixture matches protocol expectations", async () => {
  assert.equal(isHealthResponse(await fixture("valid-health-response.json")), true);
  assert.equal(
    isHealthResponse({
      ...(await fixture("valid-health-response.json")),
      status: "halfReady",
    }),
    false,
  );
  assert.equal(
    isHealthResponse({
      ...(await fixture("valid-health-response.json")),
      control: {
        ...(await fixture("valid-health-response.json")).control,
        lastMessageType: "clipboard.sync",
      },
    }),
    false,
  );
});

test("all documented error response codes are accepted and unknown codes are rejected", async () => {
  const responses = await fixture("valid-error-responses.json");
  for (const response of responses) {
    assert.equal(isErrorResponse(response), true, `${response.error.code} should be accepted`);
  }

  assert.equal(isErrorResponse(await fixture("invalid-error-response.json")), false);
});
