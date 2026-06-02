import { expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import process from "node:process";
import { runWasmStart } from "./moonbit-wasi-runner.mjs";

// Reduced from tests/node/dist/starshine-debug-wasi.wasm; see
// docs/wiki/raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md.
const startupMapRepro = "tests/repros/o4z-debug-startup-map-init-repro.wasm";

// Narrower structural guard for the current reduction: the malloc path must pass
// the TLSF root/control pointer to removeBlock, not a literal zero left on the
// operand stack. This catches stale debug-WASI artifacts before the runtime
// startup assertion below.
test("reduced O4z debug startup map fixture keeps malloc removeBlock rooted", () => {
  const wat = execFileSync("wasm-tools", ["print", startupMapRepro], {
    encoding: "utf8",
    maxBuffer: 2 * 1024 * 1024,
  });

  const hasBrokenMallocUnlinkRoot = wat.includes(`
    i32.const 0
    global.get 0
    local.tee 5
`);
  expect(hasBrokenMallocUnlinkRoot).toBe(false);
});

test("reduced O4z debug startup map fixture completes runtime init", async () => {
  const code = await runWasmStart({
    wasmPath: startupMapRepro,
    args: ["--help"],
    cwd: process.cwd(),
    preopens: { ".": process.cwd() },
  });

  expect(code).toBe(0);
}, 30_000);
