export type IntegerWidth = number;
export type IntegerExpression =
  | { kind: "var"; name: string; width: IntegerWidth }
  | { kind: "const"; value: bigint; width: IntegerWidth }
  | { kind: "add" | "sub" | "mul" | "and" | "or" | "xor" | "shl" | "shr_u" | "div_s" | "div_u" | "rem_s" | "rem_u"; width: IntegerWidth; left: IntegerExpression; right: IntegerExpression };
export type RewriteContract = { id: string; variables: Array<{ name: string; width: IntegerWidth }>; before: IntegerExpression; after: IntegerExpression; precondition?: (values: Record<string, bigint>) => boolean };
export type IntegerEvaluation = { defined: true; value: bigint } | { defined: false; trapClass: string };

const mask = (width: number) => (1n << BigInt(width)) - 1n;
const unsigned = (value: bigint, width: number) => value & mask(width);
const signed = (value: bigint, width: number) => BigInt.asIntN(width, value);

export function evaluateIntegerExpression(expression: IntegerExpression, variables: Record<string, bigint>): IntegerEvaluation {
  if (expression.kind === "var") return { defined: true, value: unsigned(variables[expression.name] ?? 0n, expression.width) };
  if (expression.kind === "const") return { defined: true, value: unsigned(expression.value, expression.width) };
  const left = evaluateIntegerExpression(expression.left, variables);
  if (!left.defined) return left;
  const right = evaluateIntegerExpression(expression.right, variables);
  if (!right.defined) return right;
  const width = expression.width;
  const l = unsigned(left.value, width);
  const r = unsigned(right.value, width);
  switch (expression.kind) {
    case "add": return { defined: true, value: unsigned(l + r, width) };
    case "sub": return { defined: true, value: unsigned(l - r, width) };
    case "mul": return { defined: true, value: unsigned(l * r, width) };
    case "and": return { defined: true, value: l & r };
    case "or": return { defined: true, value: l | r };
    case "xor": return { defined: true, value: l ^ r };
    case "shl": return { defined: true, value: unsigned(l << (r % BigInt(width)), width) };
    case "shr_u": return { defined: true, value: l >> (r % BigInt(width)) };
    case "div_u":
    case "rem_u":
      if (r === 0n) return { defined: false, trapClass: "integer-divide-by-zero" };
      return { defined: true, value: expression.kind === "div_u" ? l / r : l % r };
    case "div_s":
    case "rem_s": { const ls = signed(l, width); const rs = signed(r, width); if (rs === 0n) return { defined: false, trapClass: "integer-divide-by-zero" }; if (expression.kind === "div_s" && ls === -(1n << BigInt(width - 1)) && rs === -1n) return { defined: false, trapClass: "signed-integer-division-overflow" }; return { defined: true, value: unsigned(expression.kind === "div_s" ? ls / rs : ls % rs, width) }; }
  }
}

function evaluationsDiffer(left: IntegerEvaluation, right: IntegerEvaluation): boolean {
  if (left.defined !== right.defined) return true;
  if (!left.defined && !right.defined) return left.trapClass !== right.trapClass;
  return left.defined && right.defined && left.value !== right.value;
}

export function exhaustiveValidateRewrite(contract: RewriteContract) {
  const totalBits = contract.variables.reduce((sum, variable) => sum + variable.width, 0);
  if (totalBits > 20) return { status: "blocked" as const, detail: "reduced-width exhaustive space too large" };
  const limit = 1n << BigInt(totalBits);
  for (let packed = 0n; packed < limit; packed += 1n) {
    let cursor = packed;
    const values: Record<string, bigint> = {};
    for (const variable of contract.variables) { values[variable.name] = cursor & mask(variable.width); cursor >>= BigInt(variable.width); }
    if (contract.precondition && !contract.precondition(values)) continue;
    const before = evaluateIntegerExpression(contract.before, values);
    const after = evaluateIntegerExpression(contract.after, values);
    if (evaluationsDiffer(before, after)) return { status: "counterexample" as const, values, before, after };
  }
  return { status: "proved" as const };
}

function exprSmt(expression: IntegerExpression): string {
  if (expression.kind === "var") return expression.name;
  if (expression.kind === "const") return `(_ bv${unsigned(expression.value, expression.width)} ${expression.width})`;
  const left = exprSmt(expression.left); const right = exprSmt(expression.right);
  const op: Record<string, string> = { add: "bvadd", sub: "bvsub", mul: "bvmul", and: "bvand", or: "bvor", xor: "bvxor", shl: "bvshl", shr_u: "bvlshr", div_s: "bvsdiv", div_u: "bvudiv", rem_s: "bvsrem", rem_u: "bvurem" };
  return `(${op[expression.kind]} ${left} ${right})`;
}

function definedSmt(expression: IntegerExpression): string {
  if (expression.kind === "var" || expression.kind === "const") return "true";
  const children = `(and ${definedSmt(expression.left)} ${definedSmt(expression.right)})`;
  if (["div_s", "div_u", "rem_s", "rem_u"].includes(expression.kind)) {
    const nonzero = `(not (= ${exprSmt(expression.right)} (_ bv0 ${expression.width})))`;
    if (expression.kind === "div_s") {
      const min = 1n << BigInt(expression.width - 1); const minusOne = mask(expression.width);
      return `(and ${children} ${nonzero} (not (and (= ${exprSmt(expression.left)} (_ bv${min} ${expression.width})) (= ${exprSmt(expression.right)} (_ bv${minusOne} ${expression.width})))))`;
    }
    return `(and ${children} ${nonzero})`;
  }
  return children;
}

export function formatRewriteSmtLib(contract: RewriteContract): string {
  const declarations = contract.variables.map((variable) => `(declare-fun ${variable.name} () (_ BitVec ${variable.width}))`).join("\n");
  return `${declarations}\n(define-fun defined_before () Bool ${definedSmt(contract.before)})\n(define-fun defined_after () Bool ${definedSmt(contract.after)})\n(define-fun value_before () (_ BitVec ${(contract.before as { width: number }).width}) ${exprSmt(contract.before)})\n(define-fun value_after () (_ BitVec ${(contract.after as { width: number }).width}) ${exprSmt(contract.after)})\n(assert (or (not (= defined_before defined_after)) (and defined_before defined_after (not (= value_before value_after)))))\n(check-sat)\n(get-model)\n`;
}

export function parseSolverModel(text: string): Record<string, string> {
  const values: Record<string, string> = {};
  for (const match of text.matchAll(/define-fun\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\(_ BitVec \d+\)\s*#x([0-9a-fA-F]+)/g)) values[match[1]] = `0x${match[2].toLowerCase()}`;
  return values;
}

export async function proveRewriteWithSolver(contract: RewriteContract, options: { solver(smt: string): Promise<{ status: "sat" | "unsat" | "unknown" | "unavailable"; stdout: string; version: string | null }> }) {
  const smtLib = formatRewriteSmtLib(contract);
  const result = await options.solver(smtLib);
  if (result.status === "unavailable") return { schema: "starshine.optimizer-rewrite-proof.v1" as const, status: "blocked" as const, ruleId: contract.id, solverVersion: null, smtLib };
  if (result.status === "unsat") return { schema: "starshine.optimizer-rewrite-proof.v1" as const, status: "contract-proved" as const, ruleId: contract.id, solverVersion: result.version, smtLib };
  if (result.status === "sat") return { schema: "starshine.optimizer-rewrite-proof.v1" as const, status: "counterexample" as const, ruleId: contract.id, solverVersion: result.version, smtLib, modelText: result.stdout, counterexample: parseSolverModel(result.stdout) };
  return { schema: "starshine.optimizer-rewrite-proof.v1" as const, status: "blocked" as const, ruleId: contract.id, solverVersion: result.version, smtLib, detail: "solver returned unknown" };
}
