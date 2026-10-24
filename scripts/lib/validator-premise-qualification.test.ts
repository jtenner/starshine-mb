import { expect, test } from "bun:test";
import fs from "node:fs";
import { classifyValidationRun, qualifyValidationPremise, validatePremiseCatalog, type ValidationObservation } from "./validator-premise-qualification";

const catalog = JSON.parse(fs.readFileSync("tests/validator-premises/catalog.json", "utf8"));
const invalid = catalog.cases.find((row: any) => row.id === "local-frame-reset-invalid");
const observation = (tool: string, disposition: ValidationObservation["disposition"], diagnostic = ""): ValidationObservation => ({ tool, encoding: "well-formed", disposition, diagnostic });

test("pinned premise catalog maps paired cases to existing tests and specific diagnostics", () => {
  expect(validatePremiseCatalog(catalog)).toEqual([]);
  expect(catalog.cases.length).toBe(22);
  for (const row of catalog.cases) expect(fs.readFileSync(row.sourceTest.path, "utf8")).toContain(row.sourceTest.name);
  expect(validatePremiseCatalog({ ...catalog, specification: { ...catalog.specification, revision: "main" } })).not.toEqual([]);
});

test("a weakened local premise is rejected even when the known loose reference agrees", () => {
  expect(qualifyValidationPremise(invalid, [observation("starshine", "valid"), observation("wasm-tools", "invalid", "uninitialized local"), observation("binaryen-133", "valid")])).toMatchObject({ status: "failed", reason: "primary-premise-not-enforced" });
});

test("supported-feature reference disagreement remains visible while the primary and strict reference match", () => {
  expect(qualifyValidationPremise(invalid, [observation("starshine", "invalid", "uninitialized local: 1"), observation("wasm-tools", "invalid", "uninitialized local 1"), observation("binaryen-133", "valid")])).toMatchObject({ status: "qualified-with-reference-disagreement", disagreements: ["binaryen-133"] });
});

test("malformed bytes, unsupported features, unknown failures and wrong diagnostics cannot qualify invalid typing", () => {
  for (const disposition of ["malformed", "unsupported", "host-failure", "timeout"] as const) {
    const primary = { ...observation("starshine", disposition), encoding: disposition === "malformed" ? "malformed" as const : "well-formed" as const };
    expect(qualifyValidationPremise(invalid, [primary, observation("wasm-tools", "invalid", "uninitialized local"), observation("binaryen-133", "valid")])).toMatchObject({ status: "blocked" });
  }
  expect(qualifyValidationPremise(invalid, [observation("starshine", "invalid", "unknown opcode"), observation("wasm-tools", "invalid", "uninitialized local"), observation("binaryen-133", "valid")])).toMatchObject({ status: "failed", reason: "wrong-rejection-premise" });
});

test("missing or duplicate references and an unexpected disagreement cannot qualify", () => {
  const primary = observation("starshine", "invalid", "uninitialized local");
  expect(qualifyValidationPremise(invalid, [primary])).toMatchObject({ status: "blocked" });
  expect(qualifyValidationPremise(invalid, [primary, primary, observation("wasm-tools", "invalid", "uninitialized local"), observation("binaryen-133", "valid")])).toMatchObject({ status: "blocked" });
  expect(qualifyValidationPremise({ ...invalid, knownReferenceDisagreements: [] }, [primary, observation("wasm-tools", "invalid", "uninitialized local"), observation("binaryen-133", "valid")])).toMatchObject({ status: "failed", reason: "unexpected-reference-disagreement" });
});

test("host wording cannot masquerade as a typing rejection", () => {
  for (const tool of ["starshine", "wasm-tools", "binaryen-133"]) {
    expect(classifyValidationRun(tool, "well-formed", { exit: 1, error: null, errorCode: null, stderr: "failed to select output file: empty stack in host validator" })).toBe("host-failure");
    expect(classifyValidationRun(tool, "well-formed", { exit: 1, error: null, errorCode: null, stderr: "function references feature is not enabled" })).toBe("unsupported");
    expect(classifyValidationRun(tool, "malformed", { exit: 1, error: null, errorCode: null, stderr: "failed to select output file" })).toBe("host-failure");
    expect(classifyValidationRun(tool, "unknown", { exit: 1, error: null, errorCode: null, stderr: "type mismatch" })).toBe("host-failure");
  }
});

test("malformed header requires causal decode diagnostics", () => {
  for (const [tool, stderr] of [["starshine", "error: decode failed for input.wasm: Decode(InvalidMagicHeader)"], ["wasm-tools", "error: unexpected end-of-file (at offset 0x4)"], ["binaryen-133", "[parse exception: unexpected end of input (at 0:7)]"]]) expect(classifyValidationRun(tool!, "malformed", { exit: 1, error: null, errorCode: null, stderr: stderr! })).toBe("malformed");
});
