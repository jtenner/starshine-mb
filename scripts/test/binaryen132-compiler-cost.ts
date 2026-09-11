import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";

// Dedicated Linux resource lane, deliberately outside default Moon tests.
// Supply a fixed compiler Wasm input and an explicit prebuilt native CLI.
const [binaryArg, inputArg, budgetArg = "1024", pass = "dae2", ...extraFlags] = process.argv.slice(2);
assert(binaryArg && inputArg, "usage: <native-cli> <compiler.wasm> [max-RSS-MiB] [pass] [flags...]");
const binary = path.resolve(binaryArg);
const input = path.resolve(inputArg);
const budget = Number(budgetArg);
assert(Number.isFinite(budget) && budget > 0, "RSS budget must be positive");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-v132-cost-"));
const output = path.join(dir, "optimized.wasm");
const hash = (file: string) => createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const start = performance.now();
const command = [binary, input, "--" + pass, ...extraFlags, "-o", output];
const child = Bun.spawnSync(command, {
  timeout: 300000, stdout: "pipe", stderr: "pipe",
});
assert.equal(child.exitCode, 0, child.stderr.toString());
const usage = child.resourceUsage;
assert(usage, "subprocess resource statistics are required");
const peakRssKiB = usage.maxRSS / 1024;
const userSeconds = Number(usage.cpuTime.user) / 1e6;
const systemSeconds = Number(usage.cpuTime.system) / 1e6;
const wallSeconds = (performance.now() - start) / 1000;
execFileSync("wasm-tools", ["validate", "--features", "all", output], { timeout: 30000, stdio: "pipe" });
const result = {
  pass, command, binarySha256: hash(binary), inputSha256: hash(input), outputSha256: hash(output),
  outputBytes: fs.statSync(output).size, peakRssKiB, userSeconds, systemSeconds, wallSeconds,
  maxRssMiB: budget, artifacts: dir,
};
fs.writeFileSync(path.join(dir, "result.json"), JSON.stringify(result, null, 2) + "\n");
console.log(JSON.stringify(result));
assert(peakRssKiB <= budget * 1024, `RSS ${peakRssKiB} KiB exceeds ${budget} MiB; artifacts: ${dir}`);
