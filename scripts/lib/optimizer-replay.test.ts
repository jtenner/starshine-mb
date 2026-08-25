import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { replayOptimizerFailure } from "./optimizer-replay";

function wasmFromWat(dir: string, name: string, wat: string): string {
  const watPath = path.join(dir, `${name}.wat`);
  const wasmPath = path.join(dir, `${name}.wasm`);
  fs.writeFileSync(watPath, wat);
  const result = spawnSync("wasm-tools", ["parse", watPath, "-o", wasmPath], { encoding: "utf8" });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || "wasm-tools parse failed");
  return wasmPath;
}

function fakeStarshine(dir: string, outputWasm: string): string {
  const executable = path.join(dir, "fake-starshine.ts");
  fs.writeFileSync(
    executable,
    `#!/usr/bin/env bun\nimport fs from "node:fs";\nconst args = process.argv.slice(2);\nconst out = args[args.indexOf("--out") + 1];\nfs.copyFileSync(${JSON.stringify(outputWasm)}, out);\n`,
  );
  fs.chmodSync(executable, 0o755);
  return executable;
}

function semanticFailureFixture(afterWat: string): { failureDir: string; starshineBin: string } {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-optimizer-replay-"));
  const failureDir = path.join(root, "failure");
  fs.mkdirSync(failureDir);
  const before = wasmFromWat(
    failureDir,
    "input",
    `(module (func (export "run") (param i32) (result i32) local.get 0 i32.const 1 i32.add))`,
  );
  const after = wasmFromWat(root, "after", afterWat);
  fs.copyFileSync(before, path.join(failureDir, "input.wasm"));
  fs.writeFileSync(
    path.join(failureDir, "failure-metadata.json"),
    JSON.stringify({
      status: "property-failure",
      propertyFailureClass: "semantic-self",
      replay: { input: "input.wasm", passFlags: ["--vacuum"] },
      propertyEvidence: { semanticPolicy: "strict", serialPasses: false },
      genValidManifestEntry: { seed: "0x5eed" },
    }, null, 2) + "\n",
  );
  return { failureDir, starshineBin: fakeStarshine(root, after) };
}

describe("optimizer failure replay", () => {
  test("reconstructs and reproduces a semantic-self failure", async () => {
    const fixture = semanticFailureFixture(`(module (func (export "run") (param i32) (result i32) local.get 0))`);

    const result = await replayOptimizerFailure({
      source: fixture.failureDir,
      starshineBin: fixture.starshineBin,
    });

    expect(result.reproduced).toBe(true);
    expect(result.failureClass).toBe("semantic-self");
    expect(result.detail).toContain("semantic-mismatch");
  });

  test("reports when the original semantic failure no longer reproduces", async () => {
    const fixture = semanticFailureFixture(
      `(module (func (export "run") (param i32) (result i32) local.get 0 i32.const 1 i32.add))`,
    );

    const result = await replayOptimizerFailure({
      source: fixture.failureDir,
      starshineBin: fixture.starshineBin,
    });

    expect(result.reproduced).toBe(false);
    expect(result.failureClass).toBeNull();
  });
});
