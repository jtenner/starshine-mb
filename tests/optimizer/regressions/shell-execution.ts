import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// Explicit alternate interpreter for continuation cases unsupported by the
// Node test runner. Never turn a failed Node observation into a passing one.
export function assertWasmException(bytes: Uint8Array, exportName: string): void {
  const shell = resolve(process.env.BINARYEN_SHELL ?? ".tmp/binaryen-version_132/bin/wasm-shell");
  const version = execFileSync(shell, ["--version"], { encoding: "utf8", timeout: 10_000 });
  if (!/version 132\b/.test(version)) throw new Error(`Expected Binaryen 132: ${version}`);
  const dir = mkdtempSync(join(tmpdir(), "starshine-shell-execution-"));
  try {
    const wasm = join(dir, "input.wasm");
    const wast = join(dir, "check.wast");
    writeFileSync(wasm, bytes);
    execFileSync("wasm-tools", ["validate", "--features", "all", wasm], { timeout: 10_000 });
    const escapeBytes = (value: Uint8Array) => Array.from(value, byte => `\\${byte.toString(16).padStart(2, "0")}`).join("");
    // Binary embedding preserves every input byte and avoids WAT roundtrips.
    writeFileSync(wast, `(module binary "${escapeBytes(bytes)}")\n(assert_exception (invoke "${escapeBytes(new TextEncoder().encode(exportName))}"))\n`);
    const result = spawnSync(shell, [wast], { encoding: "utf8", timeout: 10_000 });
    if (result.error) throw result.error;
    if (result.status !== 0) {
      throw new Error(`Binaryen 132 exception assertion failed (${result.signal ?? result.status}): ${result.stdout}${result.stderr}`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
