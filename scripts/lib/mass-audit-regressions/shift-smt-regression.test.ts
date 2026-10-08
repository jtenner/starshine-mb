// This small interpreter uses SMT bitvector shift rules, which differ from Wasm.
import { expect, test } from "bun:test";
import { evaluateIntegerExpression, formatRewriteSmtLib, type IntegerExpression } from "../optimizer-translation-validation.ts";

type Term = string | Term[];
function mass_audit_pipeline_parse(tokens: string[]): Term {
  const head = tokens.shift();
  if (head !== "(") return head!;
  const result: Term[] = [];
  while (tokens[0] !== ")") result.push(mass_audit_pipeline_parse(tokens));
  tokens.shift();
  return result;
}
function mass_audit_pipeline_smt_value(term: Term, width: number): bigint {
  if (typeof term === "string") throw new Error(`unexpected variable ${term}`);
  if (term[0] === "_") return BigInt((term[1] as string).slice(2));
  const left = mass_audit_pipeline_smt_value(term[1], width);
  const right = mass_audit_pipeline_smt_value(term[2], width);
  const mask = (1n << BigInt(width)) - 1n;
  switch (term[0]) {
    case "bvshl": return right >= BigInt(width) ? 0n : (left << right) & mask;
    case "bvlshr": return right >= BigInt(width) ? 0n : left >> right;
    case "bvand": return left & right;
    case "bvurem": return right === 0n ? left : left % right;
    default: throw new Error(`unsupported SMT operation ${term[0]}`);
  }
}
test("SMT shifts use the Wasm shift count for 32 and 64 bit values", () => {
  for (const width of [32, 64]) {
    for (const kind of ["shl", "shr_u"] as const) {
      for (const count of [width, width + 1]) {
        const before: IntegerExpression = { kind, width,
          left: { kind: "const", width, value: 7n },
          right: { kind: "const", width, value: BigInt(count) } };
        const smt = formatRewriteSmtLib({ id: "mass-shift", variables: [], before,
          after: { kind: "const", width, value: 0n } });
        const line = smt.split("\n").find((item) => item.startsWith("(define-fun value_before"))!;
        const form = mass_audit_pipeline_parse(line.match(/\(|\)|[^\s()]+/g)!) as Term[];
        const expected = evaluateIntegerExpression(before, {});
        expect(expected.defined).toBe(true);
        if (expected.defined) expect(mass_audit_pipeline_smt_value(form[4], width)).toBe(expected.value);
      }
    }
  }
});
