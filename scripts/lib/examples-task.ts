import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { fail, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export type SmokeOptions = {
  smokeRoot: string | null;
  moonBin: string;
};

export type WorkflowOptions = {
  workflowPath: string;
};

type SmokeCase = {
  name: string;
  expected: string[];
  args: string[];
};

const SMOKE_CASES: SmokeCase[] = [
  {
    name: "optimize-memory64",
    expected: ["memory64_data.wasm"],
    args: ["--optimize", "examples/modules/memory64_data.wat"],
  },
  {
    name: "release-config",
    expected: ["feature_mix.wasm", "memory64_data.wasm", "simple.wasm"],
    args: ["--config", "examples/config/optimize-release.json"],
  },
  {
    name: "advanced-features",
    expected: ["table_dispatch.wasm", "simd_lane_mix.wasm"],
    args: [
      "--global-effects",
      "--flatten",
      "--vacuum",
      "examples/modules/table_dispatch.wat",
      "examples/modules/simd_lane_mix.wat",
    ],
  },
];

// Keep this list in sync with CI examples workflow cache wiring so the local
// "workflow-contract" check can detect drift in cache/install prerequisites.
const WORKFLOW_PATTERNS = [
  ["WASM_TOOLS_VERSION:", "WASM_TOOLS_VERSION env declaration"],
  ["name: Cache wasm-tools cargo install artifacts", "wasm-tools cache step name"],
  ["uses: actions/cache@v4", "actions/cache usage"],
  ["~/.cargo/bin/wasm-tools", "cached wasm-tools binary path"],
  ['key: ${{ runner.os }}-cargo-wasm-tools-${{ env.WASM_TOOLS_VERSION }}', "cache key tied to WASM_TOOLS_VERSION"],
  ['if [ ! -x "$HOME/.cargo/bin/wasm-tools" ]; then', "guarded install check"],
  ['cargo install wasm-tools --locked --version "$WASM_TOOLS_VERSION"', "versioned wasm-tools install command"],
  ['echo "$HOME/.cargo/bin" >> "$GITHUB_PATH"', "cargo bin path export"],
] as const;

// Parse smoke-test options; defaults keep CI-style native binary and a repo
// relative output directory even when no flags are passed.
export function parseExamplesSmokeArgs(argv: string[]): SmokeOptions {
  const options: SmokeOptions = {
    smokeRoot: null,
    moonBin: resolveMoonBin(),
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--root":
        options.smokeRoot = argv[i + 1] ?? fail("missing value for --root");
        i += 2;
        break;
      case "--moon":
        options.moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  return options;
}

export function parseExamplesWorkflowArgs(argv: string[]): WorkflowOptions {
  // The workflow file can be overridden, but all unknown flags are hard
  // failures to avoid masking an accidental path mistake.
  let workflowPath = ".github/workflows/examples-cli-native.yml";
  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--workflow":
        workflowPath = argv[i + 1] ?? fail("missing value for --workflow");
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }
  return { workflowPath };
}

export function runExamplesSmoke(options: SmokeOptions): void {
  // Each case runs in its own output directory so artifacts and checks do not
  // interfere across cases.
  const repoRoot = resolveWorkspaceRoot();
  const smokeRoot = options.smokeRoot === null
    ? path.join(repoRoot, "_build", "examples-smoke")
    : resolveRepoPath(repoRoot, options.smokeRoot);
  fs.mkdirSync(smokeRoot, { recursive: true });

  for (const testCase of SMOKE_CASES) {
    const outDir = path.join(smokeRoot, testCase.name);
    fs.rmSync(outDir, { recursive: true, force: true });
    fs.mkdirSync(outDir, { recursive: true });

    runOrThrow(
      options.moonBin,
      ["run", "src/cmd", "--target", "native", "--", ...testCase.args, "--out-dir", outDir],
      { cwd: repoRoot },
    );

    for (const expectedFile of testCase.expected) {
      const expectedPath = path.join(outDir, expectedFile);
      if (!fs.existsSync(expectedPath) || fs.statSync(expectedPath).size === 0) {
        fail(`expected non-empty output file missing: ${expectedPath}`);
      }
    }

    process.stdout.write(`OK: ${testCase.name}\n`);
  }

  process.stdout.write("Example CLI smoke checks passed.\n");
}

export function checkExamplesWorkflowContract(options: WorkflowOptions): void {
  // The contract checks for explicit snippets that must exist in the CI workflow
  // because these examples smoke inputs depend on them.
  const repoRoot = resolveWorkspaceRoot();
  const workflowPath = resolveRepoPath(repoRoot, options.workflowPath);
  if (!fs.existsSync(workflowPath)) {
    fail(`Missing workflow file: ${workflowPath}`);
  }
  const workflowText = fs.readFileSync(workflowPath, "utf8");
  for (const [pattern, description] of WORKFLOW_PATTERNS) {
    if (!workflowText.includes(pattern)) {
      fail(`Workflow contract violation: missing ${description}\nRequired pattern: ${pattern}`);
    }
  }
  process.stdout.write("Workflow contract check passed: wasm-tools cache + guarded install wiring is present.\n");
}

export function main(argv: string[]): void {
  const [subcommand, ...rest] = argv;
  switch (subcommand) {
    case "smoke":
      runExamplesSmoke(parseExamplesSmokeArgs(rest));
      return;
    case "workflow-contract":
      checkExamplesWorkflowContract(parseExamplesWorkflowArgs(rest));
      return;
    default:
      fail("usage: bun examples <smoke|workflow-contract> [...]");
  }
}
