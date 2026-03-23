import process from "node:process";

import { assertTarget, fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export type FuzzOptions = {
  profile: string;
  suite: string;
  seed: string | null;
  output: "text" | "jsonl";
  target: string;
  moonBin: string;
  listSuites: boolean;
  listProfiles: boolean;
  help: boolean;
};

// Parse CLI arguments into validated command settings; defaults are kept conservative
// and missing-value tokens fail immediately.
export function parseFuzzRunArgs(argv: string[]): FuzzOptions {
  const options: FuzzOptions = {
    profile: "smoke",
    suite: "all",
    seed: null,
    output: "text",
    target: "wasm-gc",
    moonBin: resolveMoonBin(),
    listSuites: false,
    listProfiles: false,
    help: false,
  };

  const positional: string[] = [];
  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    if (token.startsWith("--seed=")) {
      options.seed = token.substring("--seed=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--profile=")) {
      options.profile = token.substring("--profile=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--output=")) {
      switch (token.substring("--output=".length)) {
        case "text":
          options.output = "text";
          break;
        case "jsonl":
          options.output = "jsonl";
          break;
        default:
          fail("unknown output mode: " + (token.substring("--output=".length) ?? "<missing>"));
      }
      i += 1;
      continue;
    }
    if (token.startsWith("--target=")) {
      options.target = token.substring("--target=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--moon=")) {
      options.moonBin = token.substring("--moon=".length);
      i += 1;
      continue;
    }
    if (token.startsWith("--suite=")) {
      options.suite = token.substring("--suite=".length);
      i += 1;
      continue;
    }
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
      case "--output":
        switch (argv[i + 1]) {
          case "text":
            options.output = "text";
            break;
          case "jsonl":
            options.output = "jsonl";
            break;
          default:
            fail("unknown output mode: " + (argv[i + 1] ?? "<missing>"));
        }
        i += 2;
        break;
      case "--jsonl":
        options.output = "jsonl";
        i += 1;
        break;
      case "--list-suites":
        options.listSuites = true;
        i += 1;
        break;
      case "--list-profiles":
        options.listProfiles = true;
        i += 1;
        break;
      case "--help":
      case "-h":
        options.help = true;
        i += 1;
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
        if (token.startsWith("--")) {
          fail(`unknown option: ${token}`);
        }
        positional.push(token);
        i += 1;
        break;
    }
  }

  if (positional.length() > 3) {
    fail("too many positional arguments; expected [suite] [profile] [seed]");
  }
  if (positional.length() >= 1) {
    options.suite = positional[0];
  }
  if (positional.length() >= 2) {
    options.profile = positional[1];
  }
  if (positional.length() === 3) {
    if (options.seed !== null) {
      fail("seed provided both as positional argument and --seed flag");
    }
    options.seed = positional[2];
  }

  assertTarget(options.target);
  if (options.listSuites && options.listProfiles) {
    fail("--list-suites and --list-profiles cannot be used together");
  }
  if (
    (options.listSuites || options.listProfiles || options.help) &&
    (options.seed !== null || positional.length() > 0)
  ) {
    fail(
      "--list-suites, --list-profiles, and --help cannot be combined with suite/profile/seed arguments",
    );
  }
  return options;
}

// Build `moon run src/fuzz` command from parsed options and run in the repo root.
export function runFuzz(options: FuzzOptions, repoRoot = resolveWorkspaceRoot()): void {
  if (options.help) {
    runOrThrow(
      options.moonBin,
      ["run", "--target", options.target, "src/fuzz", "--", "--help"],
      { cwd: repoRoot },
    );
    return;
  }
  if (options.listSuites) {
    runOrThrow(
      options.moonBin,
      ["run", "--target", options.target, "src/fuzz", "--", "--list-suites"],
      { cwd: repoRoot },
    );
    return;
  }
  if (options.listProfiles) {
    runOrThrow(
      options.moonBin,
      ["run", "--target", options.target, "src/fuzz", "--", "--list-profiles"],
      { cwd: repoRoot },
    );
    return;
  }

  const args = ["run", "--target", options.target, "src/fuzz", "--", options.suite, options.profile];
  if (options.output === "jsonl") {
    args.push("--output", "jsonl");
  }
  if (options.seed !== null) {
    args.push("--seed", options.seed);
  }
  runOrThrow(options.moonBin, args, { cwd: repoRoot });
}

// `bun fuzz run` entrypoint with a strict single subcommand and no fallback parser.
export function main(argv: string[]): void {
  const [subcommand, ...rest] = argv;
  if (subcommand !== "run") {
    fail(
      "usage: bun fuzz run [--profile <name>|--profile=<name>] [--suite <name>|--suite=<name>] [--seed <hex>|--seed=<hex>] [--output text|jsonl|--jsonl|--output=<text|jsonl>] [--target <target>|--target=<target>] [--moon <path>|--moon=<path>] [--list-suites|--list-profiles|--help]",
    );
  }
  runFuzz(parseFuzzRunArgs(rest));
}

if (import.meta.main) {
  main(process.argv.slice(2));
}
