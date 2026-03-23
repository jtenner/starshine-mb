import process from "node:process";

import { assertTarget, fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export type FuzzOptions = {
  profile: string;
  suite: string;
  seed: string | null;
  target: string;
  moonBin: string;
};

// Parse CLI arguments into validated command settings; defaults are kept conservative
// and missing-value tokens fail immediately.
export function parseFuzzRunArgs(argv: string[]): FuzzOptions {
  const options: FuzzOptions = {
    profile: "ci",
    suite: "all",
    seed: null,
    target: "wasm-gc",
    moonBin: resolveMoonBin(),
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--profile":
        options.profile = argv[i + 1] ?? fail("missing value for --profile");
        i += 2;
        break;
      case "--suite":
        options.suite = argv[i + 1] ?? fail("missing value for --suite");
        i += 2;
        break;
      case "--seed":
        options.seed = argv[i + 1] ?? fail("missing value for --seed");
        i += 2;
        break;
      case "--target":
        options.target = argv[i + 1] ?? fail("missing value for --target");
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

  assertTarget(options.target);
  return options;
}

// Build `moon run src/fuzz` command from parsed options and run in the repo root.
export function runFuzz(options: FuzzOptions, repoRoot = resolveWorkspaceRoot()): void {
  const args = ["run", "--target", options.target, "src/fuzz", "--", options.suite, options.profile];
  if (options.seed !== null) {
    args.push("--seed", options.seed);
  }
  runOrThrow(options.moonBin, args, { cwd: repoRoot });
}

// `bun fuzz run` entrypoint with a strict single subcommand and no fallback parser.
export function main(argv: string[]): void {
  const [subcommand, ...rest] = argv;
  if (subcommand !== "run") {
    fail("usage: bun fuzz run [--profile <name>] [--suite <name>] [--seed <hex>] [--target <target>] [--moon <path>]");
  }
  runFuzz(parseFuzzRunArgs(rest));
}

if (import.meta.main) {
  main(process.argv.slice(2));
}
