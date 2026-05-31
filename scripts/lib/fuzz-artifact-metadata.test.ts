import { describe, expect, test } from "bun:test";

import { buildFuzzArtifactMetadata } from "./fuzz-artifact-metadata";

describe("fuzz artifact metadata", () => {
  test("records raw bytes/text and normalized canonical hashes", () => {
    const metadata = buildFuzzArtifactMetadata({
      rawBytes: Buffer.from([0, 97, 115, 109]),
      rawText: "(module)",
      normalizedCanonicalBytes: Buffer.from([1, 2, 3]),
      normalizedCanonicalText: "(module ;; normalized)",
    });

    expect(metadata.schema).toBe("starshine.fuzz.artifact-metadata.v1");
    expect(metadata.rawBytesSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(metadata.rawTextSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(metadata.normalizedCanonicalBytesSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(metadata.normalizedCanonicalTextSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(metadata.rawByteLength).toBe(4);
    expect(metadata.rawTextLength).toBe(8);
  });
});
