import { createHash } from "node:crypto";

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
export const INTEGER_MODEL_VERSION = "wasm-integer-bitvectors-v2";
const binaryKinds = new Set(["add", "sub", "mul", "and", "or", "xor", "shl", "shr_u", "div_s", "div_u", "rem_s", "rem_u"]);
const validWidth = (width: number) => Number.isInteger(width) && width >= 1 && width <= 64;

function contractError(contract: RewriteContract): string | null {
  if (!contract || typeof contract.id !== "string" || !contract.id || !Array.isArray(contract.variables)) return "missing contract id or variables";
  const bindings = new Map<string, number>();
  const reserved = new Set(["true", "false", "let", "forall", "exists", "_", "defined_before", "defined_after", "value_before", "value_after", "trap_before", "trap_after"]);
  for (const variable of contract.variables) {
    if (!variable || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(variable.name) || variable.name.startsWith("__starshine_") || reserved.has(variable.name) || !validWidth(variable.width)) return "invalid variable name or width";
    if (bindings.has(variable.name)) return "duplicate variable declaration";
    bindings.set(variable.name, variable.width);
  }
  const active = new Set<IntegerExpression>();
  let nodes = 0;
  function visit(expression: IntegerExpression, depth: number): string | null {
    if (!expression || depth > 128 || ++nodes > 2048 || active.has(expression)) return "cyclic or over-budget expression";
    if (!validWidth(expression.width)) return "invalid expression width";
    if (expression.kind === "var") return bindings.get(expression.name) === expression.width ? null : "missing variable or wrong variable width";
    if (expression.kind === "const") return typeof expression.value === "bigint" ? null : "constant must be bigint";
    if (!binaryKinds.has(expression.kind)) return "unsupported expression kind";
    if (expression.left?.width !== expression.width || expression.right?.width !== expression.width) return "operand width mismatch";
    active.add(expression);
    const error = visit(expression.left, depth + 1) ?? visit(expression.right, depth + 1);
    active.delete(expression);
    return error;
  }
  const error = visit(contract.before, 0) ?? visit(contract.after, 0);
  if (error) return error;
  if (contract.before.width !== contract.after.width) return "result width mismatch";
  if (contract.precondition !== undefined && typeof contract.precondition !== "function") return "invalid precondition";
  return null;
}

function modelDomain(contract: RewriteContract) {
  return [contract.before.width, ...contract.variables.map((v) => v.width)].every((width) => width === 32 || width === 64) ? "wasm-integer" as const : "reduced-bitvector" as const;
}

export function evaluateIntegerExpression(expression: IntegerExpression, variables: Record<string, bigint>): IntegerEvaluation {
  if (!validWidth(expression.width)) throw new Error("invalid expression width");
  if (expression.kind === "var") {
    if (!Object.hasOwn(variables, expression.name)) throw new Error(`missing variable ${expression.name}`);
    if (typeof variables[expression.name] !== "bigint") throw new Error("variable must be bigint");
    return { defined: true, value: unsigned(variables[expression.name], expression.width) };
  }
  if (expression.kind === "const") {
    if (typeof expression.value !== "bigint") throw new Error("constant must be bigint");
    return { defined: true, value: unsigned(expression.value, expression.width) };
  }
  if (!binaryKinds.has(expression.kind)) throw new Error("unsupported expression kind");
  if (expression.left?.width !== expression.width || expression.right?.width !== expression.width) throw new Error("operand width mismatch");
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
  const error = contractError(contract);
  if (error) return { status: "blocked" as const, reason: "invalid-contract", detail: error, checkedAssignments: 0 };
  // A developer-side premise may close over the caller's contract. Evaluate an
  // owned expression snapshot so it cannot change the obligation mid-enumeration.
  contract = { id: contract.id, variables: contract.variables.map((variable) => ({ ...variable })), before: structuredClone(contract.before), after: structuredClone(contract.after), precondition: contract.precondition };
  const domain = modelDomain(contract);
  const totalBits = contract.variables.reduce((sum, variable) => sum + variable.width, 0);
  if (totalBits > 20) return { status: "blocked" as const, reason: "space-limit", detail: "reduced-width exhaustive space too large", checkedAssignments: 0, modelDomain: domain };
  const limit = 1n << BigInt(totalBits);
  let checkedAssignments = 0;
  for (let packed = 0n; packed < limit; packed += 1n) {
    let cursor = packed;
    const values: Record<string, bigint> = Object.create(null);
    for (const variable of contract.variables) { values[variable.name] = cursor & mask(variable.width); cursor >>= BigInt(variable.width); }
    Object.freeze(values);
    if (contract.precondition) {
      try {
        const admitted = contract.precondition(values);
        if (typeof admitted !== "boolean") throw new Error("precondition must return boolean");
        if (!admitted) continue;
      } catch (error) { return { status: "blocked" as const, reason: "precondition-error", detail: String(error), checkedAssignments, modelDomain: domain }; }
    }
    checkedAssignments++;
    const before = evaluateIntegerExpression(contract.before, values);
    const after = evaluateIntegerExpression(contract.after, values);
    if (evaluationsDiffer(before, after)) return { status: "counterexample" as const, values, before, after, checkedAssignments, modelDomain: domain };
  }
  if (checkedAssignments === 0) return { status: "blocked" as const, reason: "empty-domain", checkedAssignments, modelDomain: domain };
  return { status: "proved" as const, checkedAssignments, modelDomain: domain, modelVersion: INTEGER_MODEL_VERSION };
}

function exprSmt(expression: IntegerExpression): string {
  if (expression.kind === "var") return expression.name;
  if (expression.kind === "const") return `(_ bv${unsigned(expression.value, expression.width)} ${expression.width})`;
  const left = exprSmt(expression.left); const right = exprSmt(expression.right);
  const op: Record<string, string> = { add: "bvadd", sub: "bvsub", mul: "bvmul", and: "bvand", or: "bvor", xor: "bvxor", shl: "bvshl", shr_u: "bvlshr", div_s: "bvsdiv", div_u: "bvudiv", rem_s: "bvsrem", rem_u: "bvurem" };
  if (expression.kind === "shl" || expression.kind === "shr_u") {
    const width = expression.width;
    const count = (width & (width - 1)) === 0
      ? `(bvand ${right} (_ bv${width - 1} ${width}))`
      : `(bvurem ${right} (_ bv${width} ${width}))`;
    return `(${op[expression.kind]} ${left} ${count})`;
  }
  return `(${op[expression.kind]} ${left} ${right})`;
}

// 0 = success, 1 = divide-by-zero, 2 = signed division overflow. Wasm
// evaluates operands in order; a child's first trap precedes the parent operation.
function trapSmt(expression: IntegerExpression): string {
  if (expression.kind === "var" || expression.kind === "const") return "0";
  const left = trapSmt(expression.left); const right = trapSmt(expression.right);
  let own = "0";
  if (["div_s", "div_u", "rem_s", "rem_u"].includes(expression.kind)) {
    let nonzero = "0";
    if (expression.kind === "div_s") nonzero = `(ite (and (= ${exprSmt(expression.left)} (_ bv${1n << BigInt(expression.width - 1)} ${expression.width})) (= ${exprSmt(expression.right)} (_ bv${mask(expression.width)} ${expression.width}))) 2 0)`;
    own = `(ite (= ${exprSmt(expression.right)} (_ bv0 ${expression.width})) 1 ${nonzero})`;
  }
  return `(let ((__starshine_left_trap ${left}) (__starshine_right_trap ${right})) (ite (not (= __starshine_left_trap 0)) __starshine_left_trap (ite (not (= __starshine_right_trap 0)) __starshine_right_trap ${own})))`;
}

export function formatRewriteSmtLib(contract: RewriteContract): string {
  const error = contractError(contract);
  if (error) throw new Error(`invalid contract: ${error}`);
  if (contract.precondition) throw new Error("unsupported non-declarative precondition in SMT");
  const declarations = contract.variables.map((variable) => `(declare-fun ${variable.name} () (_ BitVec ${variable.width}))`).join("\n");
  return `${declarations}\n(define-fun trap_before () Int ${trapSmt(contract.before)})\n(define-fun trap_after () Int ${trapSmt(contract.after)})\n(define-fun defined_before () Bool (= trap_before 0))\n(define-fun defined_after () Bool (= trap_after 0))\n(define-fun value_before () (_ BitVec ${contract.before.width}) ${exprSmt(contract.before)})\n(define-fun value_after () (_ BitVec ${contract.after.width}) ${exprSmt(contract.after)})\n(assert (or (not (= trap_before trap_after)) (and defined_before defined_after (not (= value_before value_after)))))\n(check-sat)\n`;
}

export function parseSolverModel(text: string, variables?: RewriteContract["variables"]): Record<string, string> {
  type Term = string | Term[];
  const tokens = text.trim().replace(/^sat\s+/, "").match(/\(|\)|[^()\s]+/g) ?? [];
  let index = 0;
  function read(depth: number): Term {
    if (depth > 512 || index >= tokens.length) throw new Error("malformed solver model");
    const token = tokens[index++];
    if (token === ")") throw new Error("malformed solver model");
    if (token !== "(") return token;
    const result: Term[] = [];
    while (tokens[index] !== ")") result.push(read(depth + 1));
    index++;
    return result;
  }
  const model = read(0);
  if (!Array.isArray(model) || index !== tokens.length) throw new Error("malformed solver model");
  if (model[0] === "model") model.shift();
  const bindings = variables && new Map(variables.map((variable) => [variable.name, variable.width]));
  const helpers = new Set(["defined_before", "defined_after", "trap_before", "trap_after", "value_before", "value_after"]);
  const seen = new Set<string>();
  const values: Record<string, string> = Object.create(null);
  for (const definition of model) {
    if (!Array.isArray(definition) || definition.length !== 5 || definition[0] !== "define-fun" || typeof definition[1] !== "string" || !Array.isArray(definition[2]) || definition[2].length !== 0 || seen.has(definition[1])) throw new Error("malformed solver model definition");
    const name = definition[1]; seen.add(name);
    if (bindings && !bindings.has(name)) {
      if (!helpers.has(name)) throw new Error("undeclared solver model variable");
      continue;
    }
    const type = definition[3], value = definition[4];
    if (!Array.isArray(type) || type.length !== 3 || type[0] !== "_" || type[1] !== "BitVec" || typeof type[2] !== "string") {
      if (!bindings && helpers.has(name)) continue;
      throw new Error("malformed solver bitvector type");
    }
    const width = Number(type[2]);
    if (!validWidth(width) || (bindings && bindings.get(name) !== width)) throw new Error("solver model width mismatch");
    if (typeof value === "string" && /^#x[0-9a-f]+$/i.test(value)) values[name] = `0x${value.slice(2).toLowerCase()}`;
    else if (typeof value === "string" && /^#b[01]+$/.test(value)) values[name] = `0b${value.slice(2)}`;
    else if (Array.isArray(value) && value.length === 3 && value[0] === "_" && typeof value[1] === "string" && /^bv\d+$/.test(value[1]) && value[2] === String(width)) values[name] = value[1].slice(2);
    else if (!bindings && helpers.has(name)) continue;
    else throw new Error("unsupported solver model value");
    if (BigInt(values[name]) > mask(width)) throw new Error("solver model value exceeds width");
  }
  if (bindings && [...bindings.keys()].some((name) => !Object.hasOwn(values, name))) throw new Error("missing solver model variable");
  return values;
}

export async function proveRewriteWithSolver(contract: RewriteContract, options: { timeoutMs?: number; solver(smt: string): Promise<{ status: "sat" | "unsat" | "unknown" | "unavailable" | "timeout" | "error"; stdout: string; version: string | null }> }) {
  const base = { schema: "starshine.optimizer-rewrite-proof.v2" as const, ruleId: contract?.id, modelVersion: INTEGER_MODEL_VERSION };
  const error = contractError(contract);
  if (error) return { ...base, status: "blocked" as const, reason: "invalid-contract", detail: error, smtLib: "", solverVersion: null };
  if (contract.precondition) return { ...base, status: "blocked" as const, reason: "unsupported-precondition", smtLib: "", solverVersion: null };
  const smtLib = formatRewriteSmtLib(contract);
  const identity = { ...base, smtLib, modelDomain: modelDomain(contract), contractHash: createHash("sha256").update(INTEGER_MODEL_VERSION + "\n" + smtLib).digest("hex") };
  const timeoutMs = options.timeoutMs ?? 10000;
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) return { ...identity, status: "blocked" as const, reason: "invalid-timeout", solverVersion: null };
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const result = await Promise.race([options.solver(smtLib), new Promise<{ status: "timeout"; stdout: string; version: null }>((resolve) => { timer = setTimeout(() => resolve({ status: "timeout", stdout: "solver deadline exceeded", version: null }), timeoutMs); })]);
    if (result.status === "unsat") return { ...identity, status: "contract-proved" as const, solverVersion: result.version };
    if (result.status === "sat") return { ...identity, status: "counterexample" as const, solverVersion: result.version, modelText: result.stdout, counterexample: parseSolverModel(result.stdout, contract.variables) };
    return { ...identity, status: "blocked" as const, reason: `solver-${result.status}`, solverVersion: result.version, detail: result.stdout };
  } catch (error) { return { ...identity, status: "blocked" as const, reason: "solver-error", solverVersion: null, detail: String(error) }; }
  finally { if (timer !== undefined) clearTimeout(timer); }
}
