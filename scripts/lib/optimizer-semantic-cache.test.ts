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
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "semantic-cache-legacy-"));
    // Frozen key from the pre-intrinsic execution contract. An equal report
    // computed by the old generic import stub must not suppress fresh execution.
    const oldKey = "sha256:c0e56d9a0def5ad9d1b72205b6c913c4cfd7b03429866fe3c4db65ca03a257d6";
    storeSemanticCacheEntry(root, oldKey, { classification: "semantic-match" });
    expect(loadSemanticCacheEntry(root, first)).toBeNull();
    expect(first).toBe(buildSemanticCacheKey(base));
    const nodeKey = buildSemanticCacheKey({ ...base, runtimeIdentity: "node:v26.3.0" });
    const bunKey = buildSemanticCacheKey({ ...base, runtimeIdentity: "bun:1.4.1:javascriptcore" });
    storeSemanticCacheEntry(root, nodeKey, { classification: "semantic-match" });
    expect(nodeKey).not.toBe(bunKey);
    expect(loadSemanticCacheEntry(root, bunKey)).toBeNull();
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
