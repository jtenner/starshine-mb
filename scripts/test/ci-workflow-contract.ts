import fs from "node:fs";
import path from "node:path";

function fail(message: string): never {
  throw new Error(message);
}

function requireText(text: string, expected: string, label: string): void {
  if (!text.includes(expected)) {
    fail(`required CI workflow is missing ${label}: ${JSON.stringify(expected)}`);
  }
}

export function runCiWorkflowContractTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const workflowDir = path.join(repoRoot, ".github", "workflows");
  const workflowPath = path.join(workflowDir, "ci.yml");
  if (!fs.existsSync(workflowPath)) {
    fail("required CI workflow is missing: .github/workflows/ci.yml");
  }

  const workflow = fs.readFileSync(workflowPath, "utf8");
  const requiredFragments: Array<[string, string]> = [
    ["name: \"Required CI\"", "workflow name"],
    ["pull_request:", "pull-request trigger"],
    ["      - master", "master push trigger"],
    ["permissions:\n  contents: read", "read-only default permissions"],
    ["concurrency:", "concurrency cancellation"],
    ["  format-and-tests:", "format and full-test job"],
    ["    timeout-minutes: 30", "bounded format/test timeout"],
    ["moon info", "MoonBit interface refresh"],
    ["moon fmt", "MoonBit formatting"],
    ["git diff --exit-code", "format/interface cleanliness enforcement"],
    ["moon test", "full MoonBit test suite"],
    ["bun scripts/test/ci-workflow-contract.ts", "workflow self-contract"],
    ["  release-artifacts:", "release artifact job"],
    ["moon build --target native --release src/cmd", "native release build"],
    ["moon build --target wasm-gc --release src/cmd", "wasm-gc release build"],
    ["wasm-tools validate --features all", "external wasm validation"],
    ["roundtrip-1.wasm", "first Starshine binary roundtrip"],
    ["roundtrip-2.wasm", "second Starshine binary roundtrip"],
    ["cmp .tmp/ci-roundtrip/roundtrip-1.wasm .tmp/ci-roundtrip/roundtrip-2.wasm", "stable encoded-byte roundtrip"],
    ["--suite binary-roundtrip --profile smoke --seed 0x5eed", "deterministic bounded binary roundtrip fuzz smoke"],
    ["  dae-differential:", "DAE differential job"],
    ["*retained dropped-result graph*", "retained-versus-fresh focused tests"],
    ["*complete dead-suffix call removal reports topology change*", "topology-changing DAE boundary test"],
    ["--count 10000", "full GenValid signoff case count"],
    ["--seed 0x5eed", "deterministic GenValid seed"],
    ["--pass dead-argument-elimination", "direct DAE pass oracle"],
    ["--normalize drop-consts", "dropped-constant normalization"],
    ["--normalize unreachable-control-debris", "unreachable-debris normalization"],
    ["--starshine-bin _build/native/release/build/cmd/cmd.exe", "fresh native Starshine binary"],
    ["--wasm-opt-bin \"$BINARYEN_DIR/bin/wasm-opt\"", "pinned Binaryen oracle"],
    ["--no-reduce-mismatches", "bounded mismatch handling"],
  ];
  for (const [fragment, label] of requiredFragments) {
    requireText(workflow, fragment, label);
  }

  const staleMainTriggers: string[] = [];
  for (const entry of fs.readdirSync(workflowDir)) {
    if (!entry.endsWith(".yml") && !entry.endsWith(".yaml")) continue;
    const contents = fs.readFileSync(path.join(workflowDir, entry), "utf8");
    if (/^\s*- main\s*$/m.test(contents)) staleMainTriggers.push(entry);
  }
  if (staleMainTriggers.length > 0) {
    fail(`workflow push triggers still name main instead of master: ${staleMainTriggers.join(", ")}`);
  }
}

if (import.meta.main) {
  runCiWorkflowContractTest();
  process.stdout.write("required CI workflow contract: ok\n");
}
