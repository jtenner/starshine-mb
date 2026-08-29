import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  buildSemanticCacheKey,
  loadSemanticCacheEntry,
  storeSemanticCacheEntry,
} from "./optimizer-semantic-cache";

describe("optimizer semantic observation cache", () => {
  test("keys raw Wasm bytes and every observation setting", () => {
    const base = {
      original: new Uint8Array([0, 1]),
      starshine: new Uint8Array([2, 3]),
      binaryen: new Uint8Array([4, 5]),
      seed: 9n,
      policy: "trap-aware",
      mode: "stateful",
      timeoutMs: 1000,
      memoryCapBytes: 65536,
      tableEntryCap: 32,
      runtimeVersion: "node-v2",
    } as const;
    const first = buildSemanticCacheKey(base);
    expect(first).toBe(buildSemanticCacheKey(base));
    expect(first).not.toBe(buildSemanticCacheKey({ ...base, policy: "strict" }));
    expect(first).not.toBe(buildSemanticCacheKey({ ...base, starshine: new Uint8Array([2, 4]) }));
  });

  test("stores versioned entries and rejects malformed cache contents", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "semantic-cache-test-"));
    const key = "sha256:abc";
    const report = { schema: "starshine.optimizer-three-way-runtime-report.v1", value: 1 };
    storeSemanticCacheEntry(root, key, report);
    expect(loadSemanticCacheEntry(root, key)).toEqual(report);
    const entryPath = path.join(root, "semantic-v2", "abc", "entry.json");
    fs.writeFileSync(entryPath, "{}\n");
    expect(loadSemanticCacheEntry(root, key)).toBeNull();
  });
});
