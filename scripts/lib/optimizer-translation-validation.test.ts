import { describe, expect, test } from "bun:test";
import { evaluateIntegerExpression, exhaustiveValidateRewrite, formatRewriteSmtLib, parseSolverModel, proveRewriteWithSolver } from "./optimizer-translation-validation";

const x = { kind: "var" as const, name: "x", width: 32 as const };

describe("integer rewrite semantics", () => {
  test("distinguishes values from traps", () => {
    expect(evaluateIntegerExpression({ kind: "div_s", width: 32, left: x, right: { kind: "const", width: 32, value: 0n } }, { x: 7n })).toEqual({ defined: false, trapClass: "integer-divide-by-zero" });
    expect(evaluateIntegerExpression({ kind: "add", width: 32, left: x, right: { kind: "const", width: 32, value: 1n } }, { x: 0xffffffffn })).toEqual({ defined: true, value: 0n });
  });

  test("validates encodings with exhaustive reduced-width evaluation", () => {
    const result = exhaustiveValidateRewrite({ id: "add-zero", variables: [{ name: "x", width: 4 }], before: { kind: "add", width: 4, left: { kind: "var", name: "x", width: 4 }, right: { kind: "const", width: 4, value: 0n } }, after: { kind: "var", name: "x", width: 4 } });
    expect(result.status).toBe("proved");
  });

  test("emits SMT-LIB for definedness and value differences", () => {
    const smt = formatRewriteSmtLib({ id: "add-zero", variables: [{ name: "x", width: 32 }], before: { kind: "add", width: 32, left: x, right: { kind: "const", width: 32, value: 0n } }, after: x });
    expect(smt).toContain("defined_before");
    expect(smt).toContain("value_before");
    expect(smt).toContain("check-sat");
  });

  test("supports deterministic fake solvers and absent solver blocking", async () => {
    const contract = { id: "bad", variables: [{ name: "x", width: 32 }], before: x, after: { kind: "const" as const, width: 32 as const, value: 0n } };
    const fake = await proveRewriteWithSolver(contract, { solver: async () => ({ status: "sat", stdout: "(model (define-fun x () (_ BitVec 32) #x00000001))", version: "fake-z3" }) });
    expect(fake.status).toBe("counterexample");
    expect(parseSolverModel(fake.modelText ?? "").x).toBe("0x00000001");
    const blocked = await proveRewriteWithSolver(contract, { solver: async () => ({ status: "unavailable", stdout: "", version: null }) });
    expect(blocked.status).toBe("blocked");
  });
});
