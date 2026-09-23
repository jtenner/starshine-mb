import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import path from "node:path";

describe("CI optimizer correctness lanes", () => {
  test("require deterministic output and stable codec bytes", () => {
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
      }
    }
    expect(commands).toBeGreaterThanOrEqual(2);
  });
});
