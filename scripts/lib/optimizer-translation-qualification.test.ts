import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { evaluateIntegerExpression, exhaustiveValidateRewrite, formatRewriteSmtLib, INTEGER_MODEL_VERSION, parseSolverModel, proveRewriteWithSolver, type RewriteContract } from "./optimizer-translation-validation";

const x = { kind: "var" as const, name: "x", width: 4 };
const contract: RewriteContract = { id: "identity", variables: [{ name: "x", width: 4 }], before: x, after: x };

test("exhaustive qualification reports its admitted domain and blocks vacuous premises", () => {
  expect(exhaustiveValidateRewrite(contract)).toMatchObject({ status: "proved", checkedAssignments: 16, modelDomain: "reduced-bitvector" });
  expect(exhaustiveValidateRewrite({ ...contract, precondition: () => false })).toMatchObject({ status: "blocked", reason: "empty-domain", checkedAssignments: 0 });
});

test("representative rewrite obligations pin their model and implemented rule bodies", () => {
  const fixture = JSON.parse(fs.readFileSync("tests/optimizer/scalar-rewrite-contracts.json", "utf8"));
  expect(fixture.modelVersion).toBe(INTEGER_MODEL_VERSION);
  expect(fixture.contracts.length).toBe(12);
  for (const source of fixture.sources) {
    const body = fs.readFileSync(source.path, "utf8");
    const start = body.indexOf(`fn ${source.function}(`);
    expect(start).toBeGreaterThanOrEqual(0);
    const end = body.indexOf("\n///|", start);
    expect(createHash("sha256").update(body.slice(start, end)).digest("hex")).toBe(source.sha256);
  }
});

test("malformed proof contracts cannot qualify", () => {
  const invalid: RewriteContract[] = [
    { ...contract, variables: [] },
    { ...contract, variables: [{ name: "x", width: 4 }, { name: "x", width: 4 }] },
    { ...contract, after: { ...x, width: 8 } },
    { ...contract, variables: [{ name: "x", width: 0 }] },
    { ...contract, variables: [{ name: "x", width: 65 }] },
    { ...contract, before: { kind: "add", width: 4, left: x, right: { kind: "const", width: 8, value: 0n } } },
    { ...contract, variables: [{ name: "x) (assert false", width: 4 }] },
    { ...contract, before: { kind: "unsupported", width: 4 } as any },
  ];
  for (const candidate of invalid) {
    expect(exhaustiveValidateRewrite(candidate)).toMatchObject({ status: "blocked", reason: "invalid-contract" });
    expect(() => formatRewriteSmtLib(candidate)).toThrow();
  }
});

test("missing live inputs do not silently become zero", () => {
  expect(() => evaluateIntegerExpression(x, {})).toThrow("missing variable");
  expect(() => evaluateIntegerExpression(x, { x: 0 as any })).toThrow("bigint");
});

test("functional preconditions remain deliberately unsupported by the SMT path", async () => {
  const conditional = { ...contract, precondition: (values: Record<string, bigint>) => values.x !== 0n };
  expect(() => formatRewriteSmtLib(conditional)).toThrow("precondition");
  let calls = 0;
  const result = await proveRewriteWithSolver(conditional, { solver: async () => { calls++; return { status: "unsat", stdout: "", version: "fake" }; } });
  expect(result).toMatchObject({ status: "blocked", reason: "unsupported-precondition" });
  expect(calls).toBe(0);
});

test("premises cannot mutate the exhaustive assignment and thrown premises do not qualify", () => {
  const invalidIdentity = { ...contract, after: { kind: "const" as const, width: 4, value: 0n }, precondition: (values: Record<string, bigint>) => { values.x = 0n; return true; } };
  expect(exhaustiveValidateRewrite(invalidIdentity)).toMatchObject({ status: "blocked", reason: "precondition-error" });
  expect(exhaustiveValidateRewrite({ ...contract, precondition: () => { throw new Error("bad premise"); } })).toMatchObject({ status: "blocked", reason: "precondition-error" });
  const mutable: RewriteContract = { ...contract, after: { kind: "const", width: 4, value: 0n }, precondition: () => true };
  mutable.precondition = () => { mutable.before = mutable.after; return true; };
  expect(exhaustiveValidateRewrite(mutable)).toMatchObject({ status: "counterexample" });
});

test("solver errors and timeout remain distinct from unknown and verification", async () => {
  for (const status of ["unknown", "unavailable", "timeout", "error"] as const) {
    const result = await proveRewriteWithSolver(contract, { solver: async () => ({ status, stdout: "", version: "fake" }) });
    expect(result).toMatchObject({ status: "blocked", reason: `solver-${status}` });
  }
  expect(await proveRewriteWithSolver(contract, { solver: async () => { throw new Error("solver broke"); } })).toMatchObject({ status: "blocked", reason: "solver-error" });
  expect(await proveRewriteWithSolver(contract, { timeoutMs: 5, solver: () => new Promise(() => {}) })).toMatchObject({ status: "blocked", reason: "solver-timeout" });
});

test("proof reports carry reproducible contract and semantic model identities", async () => {
  const solver = async () => ({ status: "unsat" as const, stdout: "unsat", version: "fake" });
  const a = await proveRewriteWithSolver(contract, { solver });
  const b = await proveRewriteWithSolver({ ...contract, after: { kind: "const", width: 4, value: 1n } }, { solver });
  expect(a).toMatchObject({ modelVersion: "wasm-integer-bitvectors-v2", modelDomain: "reduced-bitvector" });
  expect(a.contractHash).toMatch(/^[a-f0-9]{64}$/);
  expect(a.contractHash).not.toBe(b.contractHash);
});

test("solver witnesses retain binary, decimal and prototype-named declared bindings only", () => {
  const variables = [{ name: "x", width: 3 }, { name: "__proto__", width: 4 }];
  const model = "sat\n((define-fun x () (_ BitVec 3) #b111) (define-fun __proto__ () (_ BitVec 4) (_ bv15 4)) (define-fun value_after () (_ BitVec 3) #b000))";
  const values = parseSolverModel(model, variables);
  expect(Object.getPrototypeOf(values)).toBeNull();
  expect(Object.keys(values)).toEqual(["x", "__proto__"]);
  expect(values.x).toBe("0b111");
  expect(values.__proto__).toBe("15");
  expect(() => parseSolverModel("sat\n((error \"bad\"))", variables)).toThrow();
  expect(() => parseSolverModel("sat\n()", variables)).toThrow("missing");
});

test("SMT preserves distinct integer trap outcomes and left-to-right trap precedence", () => {
  const c = (value: bigint) => ({ kind: "const" as const, width: 32, value });
  const overflow = { kind: "div_s" as const, width: 32, left: c(0x80000000n), right: c(0xffffffffn) };
  const zero = { kind: "div_s" as const, width: 32, left: c(1n), right: c(0n) };
  expect(exhaustiveValidateRewrite({ id: "wrong-trap", variables: [], before: overflow, after: zero })).toMatchObject({ status: "counterexample" });
  const smt = formatRewriteSmtLib({ id: "wrong-trap", variables: [], before: { kind: "add", width: 32, left: overflow, right: zero }, after: zero });
  expect(smt).toContain("(define-fun trap_before () Int");
  expect(smt).toContain("(not (= trap_before trap_after))");
});

test("proof CLI fails after persisting blocked or counterexample reports and rejects solver process errors", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "rewrite-gate-"));
  try {
    const input = path.join(dir, "contracts.json");
    fs.writeFileSync(input, JSON.stringify([{ ...contract, before: { kind: "var", name: "x", width: 4 }, after: { kind: "const", width: 4, value: "0" } }]));
    const solver = path.join(dir, "fake-solver");
    let index = 0;
    for (const [status, exitCode] of [["unsat", 7], ["sat\n((define-fun x () (_ BitVec 4) #x1))", 0], ["unknown", 0], ["unsat\n(error \"bad\")", 0], ["unsat\nsat", 0], ["satisfiable\n()", 0]] as const) {
      fs.writeFileSync(solver, `#!/usr/bin/env node\nif(process.argv.includes('--version'))console.log('test-solver');else{const input=require('node:fs').readFileSync(0,'utf8');const output=${JSON.stringify(status)};console.log(output.startsWith('sat\\n')&&!input.includes('get-model')?'sat':output);process.exitCode=${exitCode};}\n`, { mode: 0o755 });
      const out = path.join(dir, `out-${index++}`);
      const result = spawnSync(process.execPath, ["scripts/fuzz.ts", "prove-rewrites", input, "--solver", solver, "--out-dir", out], { encoding: "utf8" });
      expect(result.status).toBe(1);
      const report = JSON.parse(fs.readFileSync(path.join(out, "identity.json"), "utf8"));
      expect(report.proof.status).toBe(status.startsWith("sat\n") ? "counterexample" : "blocked");
      if (exitCode) expect(report.proof.reason).toBe("solver-error");
    }
    for (const entries of [[], [{ ...contract, id: "a/b" }, { ...contract, id: "a_b" }]]) {
      fs.writeFileSync(input, JSON.stringify(entries));
      const result = spawnSync(process.execPath, ["scripts/fuzz.ts", "prove-rewrites", input, "--solver", solver, "--out-dir", path.join(dir, "invalid")], { encoding: "utf8" });
      expect(result.status).toBe(1);
      expect(result.stderr).toMatch(/at least one contract|colliding proof output/);
    }
    fs.writeFileSync(input, JSON.stringify([{ id: "unsafe-json-number", variables: [], before: { kind: "const", width: 64, value: Number.MAX_SAFE_INTEGER + 1 }, after: { kind: "const", width: 64, value: "0" } }]));
    const unsafe = spawnSync(process.execPath, ["scripts/fuzz.ts", "prove-rewrites", input, "--solver", solver, "--out-dir", path.join(dir, "unsafe")], { encoding: "utf8" });
    expect(unsafe.status).toBe(1);
    expect(unsafe.stderr).toContain("safe integer");
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
