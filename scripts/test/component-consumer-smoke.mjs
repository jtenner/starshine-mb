import assert from "node:assert/strict";
import path from "node:path";
import { pathToFileURL } from "node:url";

const generatedModule = process.argv[2] ?? ".tmp/component-jco-smoke/starshine.component.js";
const { coreIr, metadata, modules } = await import(
  pathToFileURL(path.resolve(generatedModule)).href,
);

assert.equal(metadata.version(), "0.1.1");
assert.equal(metadata.implementationTarget(), "portable-component-linear-wasm");
assert.deepEqual(
  metadata.capabilities().map(({ name }) => name),
  ["binary", "text", "validate", "passes", "generate", "core-ir"],
);

const passCatalog = modules.availablePasses();
assert(passCatalog.some(({ name, kind }) => name === "vacuum" && kind === "function-pass"));
assert(passCatalog.some(({ name, kind }) => name === "local-cse" && kind === "module-pass"));
assert(passCatalog.some(({ name, kind }) => name === "optimize" && kind === "preset"));
assert(!passCatalog.some(({ name }) => name === "const-hoisting"));

const generatorProfiles = modules.availableGeneratorProfiles();
assert(generatorProfiles.includes("natural-small"));
const generationOptions = { seed: 0x5eedn, profile: "natural-small" };
const generated = modules.generateValidWasm(generationOptions);
const generatedAgain = modules.generateValidWasm(generationOptions);
assert.equal(generated.profile, "natural-small");
assert(generated.attempts > 0);
assert.deepEqual(generated.wasm, generatedAgain.wasm);
modules.validateWasm(generated.wasm);

let generationDiagnostic;
try {
  modules.generateValidWasm({ seed: 1n, profile: "not-a-generator-profile" });
} catch (error) {
  generationDiagnostic = error?.payload;
}
assert.equal(generationDiagnostic?.stage, "generate");

const i32Type = coreIr.ValType.i32();
const functionType = coreIr.CompType.funcValue([], [i32Type]);
const typeMetadata = coreIr.TypeMetadata.create(undefined, undefined, false);
const subtype = coreIr.SubType.compType(functionType, typeMetadata);
const recType = coreIr.RecType.create(subtype);
const typeSection = coreIr.TypeSec.create([recType]);
const typeIndex = coreIr.TypeIdx.create(0);
const functionSection = coreIr.FuncSec.create([typeIndex]);
const discardedConstant = coreIr.I32.create(6);
discardedConstant[Symbol.dispose]();
const constant = coreIr.I32.create(7);
const instruction = coreIr.Instruction.i32Const(constant);
const expression = coreIr.Expr.create([instruction]);
const func = coreIr.FuncIr.create(coreIr.Locals.empty(), expression);
const codeSection = coreIr.CodeSec.create([func]);
let constructedModule = coreIr.emptyModule();
constructedModule = coreIr.Module.withTypeSec(constructedModule, typeSection);
constructedModule = coreIr.Module.withFuncSec(constructedModule, functionSection);
constructedModule = coreIr.Module.withCodeSec(constructedModule, codeSection);
coreIr.validateModule(constructedModule);
const constructedWasm = coreIr.encodeModule(constructedModule);
modules.validateWasm(constructedWasm);
assert(constructedWasm.length > 8);

const input = modules.watToWasm('(module (func (export "run") (result i32) i32.const 7))');
modules.validateWasm(input);
assert.deepEqual(modules.roundtripWasm(input), input);

const optimized = modules.optimizeWasm(input, {
  preset: "optimize",
  additionalPasses: [],
  closedWorld: false,
  trapsNeverHappen: false,
  ignoreImplicitTraps: false,
  zeroFilledMemory: false,
  optimizeLevel: 2,
  shrinkLevel: 0,
});
modules.validateWasm(optimized);

let diagnostic;
try {
  modules.watToWasm("(module (func");
} catch (error) {
  diagnostic = error?.payload;
}
assert.equal(diagnostic?.stage, "parse");
assert.match(diagnostic?.message ?? "", /expected '\)'/);
assert.doesNotMatch(diagnostic?.message ?? "", /\0/);

process.stdout.write("component JavaScript consumer smoke: ok\n");
