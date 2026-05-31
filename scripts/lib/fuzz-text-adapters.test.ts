import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  classifyFakeTextAdapters,
  runOptionalWabtTextAdapter,
  runOptionalWasmToolsTextAdapter,
} from "./fuzz-text-adapters";

function makeExecutable(file: string, source: string): string {
  fs.writeFileSync(file, source, { mode: 0o755 });
  fs.chmodSync(file, 0o755);
  return file;
}

describe("fuzz text adapters", () => {
  test("run optional WABT text command and classify accepted parse", () => {
    const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-wabt-text-adapter-"));
    const fakeWat2Wasm = makeExecutable(
      path.join(tmpdir, "wat2wasm"),
      `#!/usr/bin/env node
const fs = require("node:fs");
const args = process.argv.slice(2);
const out = args[args.indexOf("-o") + 1];
fs.writeFileSync(out, "wasm");
`,
    );

    const result = runOptionalWabtTextAdapter("(module)", fakeWat2Wasm);

    expect(result).toEqual({ adapter: "wabt", classification: "accepted", diagnostic: undefined });
  });

  test("run optional WABT text command and classify unavailable command", () => {
    const result = runOptionalWabtTextAdapter("(module)", "/definitely/missing/wat2wasm");

    expect(result.classification).toBe("adapter-unavailable");
    expect(result.diagnostic).toContain("/definitely/missing/wat2wasm");
  });

  test("run optional wasm-tools text command and classify unsupported syntax", () => {
    const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-wasm-tools-text-adapter-"));
    const fakeWasmTools = makeExecutable(
      path.join(tmpdir, "wasm-tools"),
      `#!/usr/bin/env node
process.stderr.write("unsupported text syntax: module linking");
process.exit(1);
`,
    );

    const result = runOptionalWasmToolsTextAdapter("(module)", fakeWasmTools);

    expect(result).toEqual({
      adapter: "wasm-tools",
      classification: "unsupported-syntax",
      diagnostic: "unsupported text syntax: module linking",
    });
  });

  test("run optional wasm-tools text command and classify accepted parse", () => {
    const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-wasm-tools-text-adapter-"));
    const fakeWasmTools = makeExecutable(
      path.join(tmpdir, "wasm-tools"),
      `#!/usr/bin/env node
const fs = require("node:fs");
const args = process.argv.slice(2);
const out = args[args.indexOf("-o") + 1];
fs.writeFileSync(out, "wasm");
`,
    );

    const result = runOptionalWasmToolsTextAdapter("(module)", fakeWasmTools);

    expect(result).toEqual({ adapter: "wasm-tools", classification: "accepted", diagnostic: undefined });
  });

  test("classify n-way fake text adapter results", () => {
    const results = classifyFakeTextAdapters("(module)", [
      { adapter: "local", ok: true, text: "(module)" },
      { adapter: "wabt", ok: false, diagnostic: "parse failed" },
      { adapter: "wasm-tools", ok: true, text: "(module)" },
    ]);

    expect(results.inputHash).toMatch(/^[0-9a-f]{64}$/);
    expect(results.adapters).toEqual([
      { adapter: "local", classification: "accepted", diagnostic: undefined },
      { adapter: "wabt", classification: "parse-error", diagnostic: "parse failed" },
      { adapter: "wasm-tools", classification: "accepted", diagnostic: undefined },
    ]);
    expect(results.summary).toEqual({ accepted: 2, "parse-error": 1 });
  });
});
