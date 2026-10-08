// A process deadline keeps this test bounded when the current code blocks.
import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, spawnSync } from "node:child_process";

for (const entry of ["export", "start"] as const) {
  test(`runtime matrix bounds a nonterminating ${entry}`, async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-mass-matrix-"));
    const wat = path.join(dir, "input.wat");
    const wasm = path.join(dir, "input.wasm");
    fs.writeFileSync(wat, entry === "export"
      ? `(module (func (export "run") (loop br 0)))`
      : `(module (func $start (loop br 0)) (start $start) (func (export "run")))`);
    const parsed = spawnSync("wasm-tools", ["parse", wat, "-o", wasm], { encoding: "utf8", timeout: 5000 });
    if (parsed.error || parsed.status !== 0) {
      fs.rmSync(dir, { recursive: true, force: true });
      throw parsed.error ?? new Error(parsed.stderr);
    }
    let output = "";
    let killed = false;
    try {
      await new Promise<void>((resolve, reject) => {
        const child = spawn(process.execPath, [fileURLToPath(new URL("./matrix-deadline-child.ts", import.meta.url)), wasm], { stdio: ["ignore", "pipe", "pipe"] });
        child.stdout.setEncoding("utf8");
        child.stdout.on("data", (chunk) => { output += chunk; });
        const timer = setTimeout(() => { killed = true; child.kill("SIGKILL"); }, 4000);
        child.on("error", (error) => { clearTimeout(timer); reject(error); });
        child.on("close", () => { clearTimeout(timer); resolve(); });
      });
      expect(killed).toBe(false);
      expect(JSON.parse(output).some((report: { classification: string }) => report.classification === "unsupported-runtime")).toBe(true);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }, 10000);
}
