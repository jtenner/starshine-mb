export type ValidationDisposition = "valid" | "invalid" | "malformed" | "unsupported" | "host-failure" | "timeout";
export function classifyValidationRun(tool: string, encoding: ValidationObservation["encoding"], result: { exit: number | null; errorCode: string | null; error: string | null; stderr: string }): ValidationDisposition {
  if (result.errorCode === "ETIMEDOUT") return "timeout";
  if (result.error || result.exit === null) return "host-failure";
  if (encoding === "malformed") {
    const decodePrefix = tool === "starshine" ? /^error: decode failed for .*: Decode\(InvalidMagicHeader\)/m : tool === "wasm-tools" ? /^error: unexpected end-of-file \(at offset /m : tool === "binaryen-133" ? /\[parse exception: unexpected end of input \(at / : /$a/;
    return result.exit !== 0 && decodePrefix.test(result.stderr) ? "malformed" : "host-failure";
  }
  if (encoding !== "well-formed") return "host-failure";
  if (result.exit === 0) return "valid";
  if (/not enabled|feature.*disabled|unsupported feature|function references required for non-nullable types/i.test(result.stderr)) return "unsupported";
  const typingPrefix = tool === "starshine" ? /^error: validate pass:/m : tool === "wasm-tools" ? /^error: func \d+ failed to validate/m : tool === "binaryen-133" ? /\[wasm-validator error in function|\[parse exception: (?:popping from empty stack|select type does not match expected type)/ : /$a/;
  return typingPrefix.test(result.stderr) ? "invalid" : "host-failure";
}
export type ValidationObservation = { tool: string; encoding: "well-formed" | "malformed" | "unknown"; disposition: ValidationDisposition; diagnostic: string };
export type ValidationPremise = { id: string; pair: string; family: string; features: string[]; expected: "valid" | "invalid"; rejectionPatterns: Record<string, string>; sourceTest: { path: string; name: string }; wat: string; specSection: string; knownReferenceDisagreements: string[] };
export type PremiseCatalog = { schema: string; specification: { revision: string; files: Array<{ path: string; sha256: string }> }; featurePolicy: { guestExecution: string }; cases: ValidationPremise[] };
export const VALIDATION_SPEC_REVISION = "7e9fb78c63d65018cc111422f657947b3df80d7b";
const specificationFiles = new Map([
  ["document/core/valid/instructions.rst", "4305c124553c290cab9633c5b477b0f426fd3726f294b3becce37e716a79b57a"],
  ["document/core/appendix/algorithm.rst", "a1d622e2e1ccc99ce3ab49365417a6ffcb8b3c0b2b8943d835a3dbe4516e0e41"],
]);

export function validatePremiseCatalog(catalog: PremiseCatalog): string[] {
  const errors: string[] = [];
  if (catalog.schema !== "starshine.validator-premise-catalog.v1") errors.push("unknown premise schema");
  if (!/^[a-f0-9]{40}$/.test(catalog.specification.revision)) errors.push("specification revision must be immutable");
  if (catalog.specification.revision !== VALIDATION_SPEC_REVISION) errors.push("unreviewed specification revision");
  if (catalog.specification.files.length < 2 || catalog.specification.files.some((file) => !/^[a-f0-9]{64}$/.test(file.sha256))) errors.push("missing specification source identity");
  for (const [path, sha256] of specificationFiles) if (!catalog.specification.files.some((file) => file.path === path && file.sha256 === sha256)) errors.push("unreviewed specification source identity");
  if (catalog.featurePolicy.guestExecution !== "forbidden; validation and decode only") errors.push("guest execution is outside the premise matrix");
  if (catalog.cases.length === 0 || catalog.cases.length > 32) errors.push("empty or over-budget premise matrix");
  const ids = new Set<string>(), pairs = new Map<string, Set<string>>();
  for (const row of catalog.cases) {
    if (!row.id || ids.has(row.id)) errors.push("missing or duplicate premise id");
    ids.add(row.id);
    const roles = pairs.get(row.pair) ?? new Set<string>(); roles.add(row.expected); pairs.set(row.pair, roles);
    if (!row.features.length || !row.sourceTest.path || !row.sourceTest.name || !row.specSection || !row.wat.startsWith("(module")) errors.push(`${row.id}: incomplete premise mapping`);
    if (row.expected === "invalid") for (const tool of ["starshine", "wasm-tools", "binaryen-133"]) {
      const pattern = row.rejectionPatterns[tool];
      if (!pattern) errors.push(`${row.id}: missing rejection premise for ${tool}`);
      try { if (pattern) new RegExp(pattern, "i"); } catch { errors.push(`${row.id}: invalid rejection pattern`); }
    }
    if (row.knownReferenceDisagreements.some((tool) => tool !== "binaryen-133")) errors.push(`${row.id}: unreviewed reference exception`);
  }
  for (const [pair, roles] of pairs) if (!roles.has("valid") || !roles.has("invalid")) errors.push(`${pair}: missing valid/invalid pair`);
  return errors;
}

export function qualifyValidationPremise(premise: ValidationPremise, observations: ValidationObservation[]) {
  const byTool = new Map<string, ValidationObservation>();
  for (const observation of observations) {
    if (byTool.has(observation.tool)) return { status: "blocked" as const, reason: "duplicate-tool-observation", disagreements: [] };
    byTool.set(observation.tool, observation);
  }
  const primary = byTool.get("starshine"), strict = byTool.get("wasm-tools"), secondary = byTool.get("binaryen-133");
  if (!primary || !strict || !secondary) return { status: "blocked" as const, reason: "missing-reference", disagreements: [] };
  const disagreements: string[] = [];
  for (const observation of [primary, strict, secondary]) {
    if (observation.encoding !== "well-formed" || !["valid", "invalid"].includes(observation.disposition)) return { status: "blocked" as const, reason: `unqualified-phase:${observation.tool}:${observation.disposition}`, disagreements };
    if (observation.disposition !== premise.expected) {
      if (observation.tool === "starshine") return { status: "failed" as const, reason: "primary-premise-not-enforced", disagreements };
      if (!premise.knownReferenceDisagreements.includes(observation.tool)) return { status: "failed" as const, reason: "unexpected-reference-disagreement", disagreements: [...disagreements, observation.tool] };
      disagreements.push(observation.tool);
    } else if (premise.expected === "invalid" && !new RegExp(premise.rejectionPatterns[observation.tool]!, "i").test(observation.diagnostic)) return { status: "failed" as const, reason: "wrong-rejection-premise", disagreements };
  }
  return { status: disagreements.length ? "qualified-with-reference-disagreement" as const : "qualified" as const, disagreements };
}
