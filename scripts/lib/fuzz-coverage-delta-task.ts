import fs from "node:fs";

import { fail } from "./task-runtime";

type JsonObject = Record<string, unknown>;

type Counter = {
  path: string;
  value: number;
  required: boolean;
  alwaysVisible: boolean;
};

type CoverageDeltaOptions = {
  beforePath: string;
  afterPath: string;
  includeOptional: boolean;
};

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseArgs(argv: string[]): CoverageDeltaOptions {
  let includeOptional = false;
  const positional: string[] = [];
  for (const token of argv) {
    if (token === "--optional" || token === "--include-optional") {
      includeOptional = true;
      continue;
    }
    if (token === "--help" || token === "-h") {
      fail("usage: bun fuzz coverage-delta [--optional] <before-report.json> <after-report.json>");
    }
    if (token.startsWith("-")) {
      fail(`unknown option: ${token}`);
    }
    positional.push(token);
  }
  if (positional.length !== 2) {
    fail("usage: bun fuzz coverage-delta [--optional] <before-report.json> <after-report.json>");
  }
  return { beforePath: positional[0], afterPath: positional[1], includeOptional };
}

function readJson(path: string): unknown {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (err) {
    fail(`failed to read JSON report ${path}: ${err instanceof Error ? err.message : String(err)}`);
  }
}

function counterIsRequired(path: string): boolean {
  return path.split(".").some((part) => part.startsWith("required"));
}

function counterIsAlwaysVisible(path: string): boolean {
  return path.startsWith("artifact_counts.") ||
    path.startsWith("failure_classes.") ||
    path.startsWith("pass_statuses.") ||
    path.startsWith("artifacts.") ||
    path.startsWith("failures.") ||
    path.startsWith("statuses.") ||
    path.startsWith("timings.");
}

function collectCounters(value: unknown, prefix: string, out: Map<string, Counter>): void {
  if (!isObject(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const childPath = prefix.length === 0 ? key : `${prefix}.${key}`;
    if (typeof child === "number" && Number.isFinite(child)) {
      out.set(childPath, {
        path: childPath,
        value: child,
        required: counterIsRequired(childPath),
        alwaysVisible: counterIsAlwaysVisible(childPath),
      });
      continue;
    }
    if (isObject(child)) {
      collectCounters(child, childPath, out);
    }
  }
}

function reportCounters(report: unknown): Map<string, Counter> {
  const counters = new Map<string, Counter>();
  if (isObject(report) && isObject(report.summary)) {
    collectCounters(report.summary, "", counters);
  } else {
    collectCounters(report, "", counters);
  }
  return counters;
}

function displayName(path: string): string {
  const parts = path.split(".");
  return parts[parts.length - 1];
}

export function runFuzzCoverageDelta(argv: string[]): void {
  const options = parseArgs(argv);
  const before = reportCounters(readJson(options.beforePath));
  const after = reportCounters(readJson(options.afterPath));
  const keys = Array.from(new Set([...before.keys(), ...after.keys()])).sort();
  const requiredDrops: string[] = [];
  const visibleDiffs: string[] = [];

  for (const key of keys) {
    const beforeCounter = before.get(key);
    const afterCounter = after.get(key);
    const beforeValue = beforeCounter?.value ?? 0;
    const afterValue = afterCounter?.value ?? 0;
    if (beforeValue === afterValue) {
      continue;
    }
    const required = beforeCounter?.required ?? afterCounter?.required ?? counterIsRequired(key);
    const alwaysVisible = beforeCounter?.alwaysVisible ?? afterCounter?.alwaysVisible ?? counterIsAlwaysVisible(key);
    const delta = afterValue - beforeValue;
    const line = `${displayName(key)}: ${beforeValue} -> ${afterValue} (${delta >= 0 ? "+" : ""}${delta})`;
    if (required && delta < 0) {
      requiredDrops.push(line);
    }
    if (required || alwaysVisible || options.includeOptional) {
      visibleDiffs.push(line);
    }
  }

  if (visibleDiffs.length === 0) {
    console.log("Coverage delta: no visible counter changes");
  } else {
    console.log("Coverage delta:");
    for (const line of visibleDiffs) {
      console.log(`- ${line}`);
    }
  }

  if (requiredDrops.length > 0) {
    console.log("Required coverage drops:");
    for (const line of requiredDrops) {
      console.log(`- ${line}`);
    }
    process.exitCode = 1;
  }
}
