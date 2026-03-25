import fs from "node:fs";
import path from "node:path";

function fail(message: string): never {
  throw new Error(message);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    fail(message);
  }
}

export function runIr2HandoffDocsTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const planPath = path.join(repoRoot, "docs", "0065-2026-03-24-ir2-execution-plan.md");
  assert(fs.existsSync(planPath), `missing canonical IR2 handoff doc: ${planPath}`);

  const plan = fs.readFileSync(planPath, "utf8");
  for (const required of [
    "0060-2026-03-24-cfg-contract-and-block-boundary-rules.md",
    "0061-2026-03-24-local-ssa-policy.md",
    "## Next Slice Order",
    "## Minimum Validation Per Slice",
  ]) {
    assert(plan.includes(required), `IR2 handoff doc is missing required text: ${required}`);
  }

  const irReadme = fs.readFileSync(path.join(repoRoot, "src", "ir", "README.md"), "utf8");
  assert(
    irReadme.includes("0065-2026-03-24-ir2-execution-plan.md"),
    "src/ir/README.md must link to the canonical IR2 handoff doc",
  );

  const agentTodo = fs.readFileSync(path.join(repoRoot, "agent-todo.md"), "utf8");
  assert(!agentTodo.includes("IR2 - 300"), "agent-todo.md still references completed slice IR2-300");
  assert(!agentTodo.includes("IR2 - 310"), "agent-todo.md still references completed slice IR2-310");
  assert(!agentTodo.includes("IR2 - 320"), "agent-todo.md still references completed slice IR2-320");
  assert(
    agentTodo.includes("No active backlog slices"),
    "agent-todo.md must explicitly show the empty active backlog state",
  );
}

if (import.meta.main) {
  runIr2HandoffDocsTest();
}
