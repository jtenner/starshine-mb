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
    ["WIT_BINDGEN_VERSION: \"0.60.0\"", "pinned wit-bindgen version"],
    ["JCO_VERSION: \"1.28.1\"", "pinned Jco version"],
    ["cargo install wit-bindgen-cli --locked --version \"$WIT_BINDGEN_VERSION\"", "pinned wit-bindgen installation"],
    ["bun component check --wit-bindgen \"$HOME/.cargo/bin/wit-bindgen\"", "component generation and validation lane"],
    ["bunx \"@bytecodealliance/jco@$JCO_VERSION\" transpile", "component JavaScript binding generation"],
    ["node scripts/test/component-consumer-smoke.mjs", "component JavaScript consumer smoke"],
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
    ["--require-binaryen-version 131", "fail-closed Binaryen release guard"],
    ["--no-reduce-mismatches", "bounded mismatch handling"],
  ];
  for (const [fragment, label] of requiredFragments) {
    requireText(workflow, fragment, label);
  }
  const moonUpdateCount = workflow.split("moon update").length - 1;
  if (moonUpdateCount < 3) {
    fail(`required CI workflow must resolve MoonBit registry dependencies in every job; found ${moonUpdateCount} moon update step(s)`);
  }

  const fuzzWorkflow = fs.readFileSync(path.join(workflowDir, "fuzz.yml"), "utf8");
  for (const [fragment, label] of [
    ['WASM_TOOLS_VERSION: "1.251.0"', "pinned semantic wasm-tools"],
    ['BINARYEN_VERSION: "131"', "pinned semantic Binaryen"],
    ['Z3_VERSION: "4.13.3"', "pinned semantic Z3"],
    ['semantic-optimizer-smoke:', "semantic optimizer CI job"],
    ['--gen-valid-profile semantic-optimizer-all', "semantic GenValid aggregate"],
    ['--require-binaryen-version 131', "semantic Binaryen release guard"],
    ['--require-feature semantic_effects:1', "semantic effects floor"],
    ['--semantic-oracle node-v2', "observation-v2 CI smoke"],
    ['--property semantic-idempotence', "semantic idempotence CI smoke"],
    ['--commutator-left vacuum', "commutator CI smoke"],
    ['--emit-metamorphic-pairs', "paired metamorphic CI smoke"],
    ['--no-reduce-mismatches', "bounded semantic CI without structural reduction"],
  ] as Array<[string, string]>) {
    requireText(fuzzWorkflow, fragment, label);
  }

  const nodeWorkflow = fs.readFileSync(path.join(workflowDir, "node-wasm-tests.yml"), "utf8");
  requireText(
    nodeWorkflow,
    "bun scripts/test/node-package-static-contract.ts",
    "clean-checkout Node package static contract",
  );

  const staleMainTriggers: string[] = [];
  const missingMoonUpdates: string[] = [];
  const staleNodePrefixes: string[] = [];
  for (const entry of fs.readdirSync(workflowDir)) {
    if (!entry.endsWith(".yml") && !entry.endsWith(".yaml")) continue;
    const contents = fs.readFileSync(path.join(workflowDir, entry), "utf8");
    if (/^\s*- main\s*$/m.test(contents)) staleMainTriggers.push(entry);
    if (contents.includes("cli.moonbitlang.com") && !contents.includes("moon update")) {
      missingMoonUpdates.push(entry);
    }
    if (contents.includes("npm --prefix tests/node")) staleNodePrefixes.push(entry);
  }
  if (staleMainTriggers.length > 0) {
    fail(`workflow push triggers still name main instead of master: ${staleMainTriggers.join(", ")}`);
  }
  if (missingMoonUpdates.length > 0) {
    fail(`workflows install MoonBit without resolving registry dependencies: ${missingMoonUpdates.join(", ")}`);
  }
  if (staleNodePrefixes.length > 0) {
    fail(`workflows reference the removed tests/node package: ${staleNodePrefixes.join(", ")}`);
  }
}

if (import.meta.main) {
  runCiWorkflowContractTest();
  process.stdout.write("required CI workflow contract: ok\n");
}
