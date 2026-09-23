import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import path from "node:path";

describe("CI optimizer correctness lanes", () => {
  test("keeps the external wasm-smith lane separate and manually gated", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const workflow = fs.readFileSync(path.join(repoRoot, ".github", "workflows", "fuzz.yml"), "utf8");
    const externalJob = workflow.split("  external-generator-smoke:\n")[1]?.split(/\n  [a-z][a-z-]*:\n/)[0];
    expect(externalJob).toBeDefined();
    expect(externalJob).toContain("if: github.event_name == 'workflow_dispatch'");
    expect(externalJob).toContain("--wasm-smith");
    expect(externalJob).toContain("--require-binaryen-version 132");
    expect(externalJob).toContain("--require-independent-validator");
    expect(externalJob).not.toContain("--report-only");
  });

  test("require independent validation, deterministic output, and stable codec bytes", () => {
    const repoRoot = path.resolve(import.meta.dir, "..", "..");
    const workflows = ["ci.yml", "fuzz.yml"];
    let commands = 0;
    for (const workflow of workflows) {
      const lines = fs.readFileSync(path.join(repoRoot, ".github", "workflows", workflow), "utf8").split("\n");
      for (let index = 0; index < lines.length; index += 1) {
        if (!lines[index].includes("bun fuzz compare-pass \\")) continue;
        const command: string[] = [];
        while (index < lines.length) {
          const line = lines[index].trim();
          command.push(line);
          if (!line.endsWith("\\")) break;
          index += 1;
        }
        commands += 1;
        expect(command.join(" "), workflow).toContain("--determinism");
        expect(command.join(" "), workflow).toContain("--codec-idempotence");
        expect(command.join(" "), workflow).toContain("--require-independent-validator");
      }
    }
    expect(commands).toBeGreaterThanOrEqual(2);
  });
});
