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
  const planPath = path.join(repoRoot, "docs", "wiki", "ir2", "execution-plan.md");
  assert(fs.existsSync(planPath), `missing canonical living IR2 execution plan: ${planPath}`);

  const plan = fs.readFileSync(planPath, "utf8");
  for (const required of [
    "./architecture-rules.md",
    "./local-ssa-policy.md",
    "## Future Slice Order",
    "## Practical Rule",
  ]) {
    assert(plan.includes(required), `living IR2 execution plan is missing required text: ${required}`);
  }

  const irReadme = fs.readFileSync(path.join(repoRoot, "src", "ir", "README.md"), "utf8");
  assert(
    irReadme.includes("docs/wiki/ir2/execution-plan.md"),
    "src/ir/README.md must link to the canonical living IR2 execution plan",
  );

  const agentTodo = fs.readFileSync(path.join(repoRoot, "agent-todo.md"), "utf8");
  assert(!agentTodo.includes("IR2 - 300"), "agent-todo.md still references completed slice IR2-300");
  assert(!agentTodo.includes("IR2 - 310"), "agent-todo.md still references completed slice IR2-310");
  assert(!agentTodo.includes("IR2 - 320"), "agent-todo.md still references completed slice IR2-320");
  assert(
    agentTodo.includes("## v0.2.0 Binaryen 132 Upgrade") &&
      agentTodo.includes("[IR2-V132]") &&
      agentTodo.includes("docs/wiki/binaryen/version-132-upgrade.md"),
    "agent-todo.md must expose the active Binaryen 132 slice and its durable upgrade contracts",
  );
}

if (import.meta.main) {
  runIr2HandoffDocsTest();
}
