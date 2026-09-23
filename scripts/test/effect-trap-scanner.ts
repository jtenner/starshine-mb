import { scanEffectTrapFactsFromWasmBytes } from "../lib/effect-trap-scanner";

function fail(message: string): never {
  throw new Error(message);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    fail(message);
  }
}

function moduleWithCodeBytes(codeBytes: number[]): Uint8Array {
  const body = [0x00, ...codeBytes, 0x0b]; // local decl count, body, end
  return Uint8Array.from([
    0x00, 0x61, 0x73, 0x6d,
    0x01, 0x00, 0x00, 0x00,
    0x0a, body.length + 2,
    0x01,
    body.length,
    ...body,
  ]);
}

function validModuleWithSharedMemoryAndCode(codeBytes: number[]): Uint8Array {
  const body = [0x00, ...codeBytes, 0x0b]; // local decl count, body, end
  return Uint8Array.from([
    0x00, 0x61, 0x73, 0x6d,
    0x01, 0x00, 0x00, 0x00,
    0x01, 0x04, 0x01, 0x60, 0x00, 0x00, // one [] -> [] function type
    0x03, 0x02, 0x01, 0x00, // one defined function of type 0
    0x05, 0x04, 0x01, 0x03, 0x01, 0x01, // shared memory, min=max=1
    0x0a, body.length + 2,
    0x01,
    body.length,
    ...body,
  ]);
}

function validModuleWithSingleBody(body: number[]): Uint8Array {
  return Uint8Array.from([
    0x00, 0x61, 0x73, 0x6d,
    0x01, 0x00, 0x00, 0x00,
    0x01, 0x04, 0x01, 0x60, 0x00, 0x00, // one [] -> [] function type
    0x03, 0x02, 0x01, 0x00, // one defined function of type 0
    0x0a, body.length + 2,
    0x01,
    body.length,
    ...body,
  ]);
}

export function runEffectTrapScannerTest(): void {
  const pure = scanEffectTrapFactsFromWasmBytes(moduleWithCodeBytes([0x41, 0x00, 0x1a]));
  assert(!pure.hasCall, "pure const/drop body should not report calls");
  assert(!pure.mutatesMemory, "pure const/drop body should not report memory mutation");
  assert(!pure.mayTrap, "pure const/drop body should not report traps");

  const effects = scanEffectTrapFactsFromWasmBytes(moduleWithCodeBytes([
    0x10, 0x00, // call 0
    0x24, 0x00, // global.set 0
    0x36, 0x02, 0x00, // i32.store align=2 offset=0
    0x26, 0x00, // table.set 0
    0x00, // unreachable
  ]));
  assert(effects.hasCall, "call opcode should set hasCall");
  assert(effects.mutatesGlobal, "global.set should set mutatesGlobal");
  assert(effects.mutatesMemory, "store opcode should set mutatesMemory");
  assert(effects.mutatesTable, "table.set should set mutatesTable");
  assert(effects.hasUnreachable, "unreachable opcode should set hasUnreachable");
  assert(effects.mayTrap, "store/table.set/unreachable should set mayTrap");
  assert(effects.hazards.some((hazard) => hazard.kind === "import-or-local-call"), "call location should be recorded");
  assert(effects.hazards.some((hazard) => hazard.kind === "memory-write"), "memory write location should be recorded");
  assert(effects.hazards.some((hazard) => hazard.kind === "table-write"), "table write location should be recorded");
  assert(effects.hazards.some((hazard) => hazard.kind === "explicit-unreachable"), "unreachable location should be recorded");
  assert(effects.possibleTrapCategories.includes("explicit-unreachable"), "trap categories should include explicit unreachable");

  const prefixed = scanEffectTrapFactsFromWasmBytes(moduleWithCodeBytes([
    0xfc, 0x0a, 0x00, 0x00, // memory.copy
    0xfe, 0x1e, 0x02, 0x00, // i32.atomic.rmw.add align/offset
    0x08, 0x00, // throw tag 0
  ]));
  assert(prefixed.mutatesMemory, "memory.copy or atomic RMW should set mutatesMemory");
  assert(prefixed.hasAtomics, "0xfe atomic prefix should set hasAtomics");
  assert(prefixed.hasException, "throw opcode should set hasException");
  assert(!prefixed.hasUnreachable, "throw tag immediates should not be scanned as unreachable opcodes");
  assert(prefixed.mayTrap, "prefixed mutating/throwing ops should set mayTrap");

  const hazardLikeSimdImmediate = [
    0xfd, 0x0c, // v128.const
    0x10, 0xfe, 0x36, 0x24, 0x26, 0x00, 0x08, 0x6d,
    0x11, 0x13, 0x28, 0x3e, 0x18, 0x19, 0x7f, 0x82,
    0x1a, // drop
  ];
  const simdOnly = validModuleWithSharedMemoryAndCode(hazardLikeSimdImmediate);
  assert(WebAssembly.validate(simdOnly), "SIMD immediate regression module should validate");
  const simdFacts = scanEffectTrapFactsFromWasmBytes(simdOnly);
  assert(!simdFacts.hasCall, "SIMD immediate bytes should not report calls");
  assert(!simdFacts.mutatesMemory, "SIMD immediate bytes should not report memory mutation");
  assert(!simdFacts.mutatesTable, "SIMD immediate bytes should not report table mutation");
  assert(!simdFacts.mutatesGlobal, "SIMD immediate bytes should not report global mutation");
  assert(!simdFacts.hasException, "SIMD immediate bytes should not report exceptions");
  assert(!simdFacts.hasAtomics, "SIMD immediate bytes should not report atomics");
  assert(!simdFacts.hasUnreachable, "SIMD immediate bytes should not report unreachable");
  assert(!simdFacts.mayTrap, "v128.const and drop should not report traps");
  assert(simdFacts.hazards.length === 0, "SIMD immediate bytes should not report hazard offsets");

  const trueOpcodes = validModuleWithSharedMemoryAndCode([
    ...hazardLikeSimdImmediate,
    0x10, 0x00, // call function 0
    0x41, 0x00, 0x41, 0x01, 0x36, 0x02, 0x00, // i32.store align=2 offset=0
    0x41, 0x00, 0x41, 0x01,
    0xfe, 0x1e, 0x02, 0x00, // i32.atomic.rmw.add align=2 offset=0
    0x1a, // drop the atomic result
  ]);
  assert(WebAssembly.validate(trueOpcodes), "true opcode control module should validate");
  const trueFacts = scanEffectTrapFactsFromWasmBytes(trueOpcodes);
  assert(trueFacts.hasCall, "real call after a SIMD immediate should be reported");
  assert(trueFacts.hasAtomics, "real atomic after a SIMD immediate should be reported");
  assert(trueFacts.mutatesMemory, "real store and atomic should report memory mutation");
  assert(trueFacts.mayTrap, "real store and atomic should report possible traps");
  assert(trueFacts.hazards.some((hazard) => hazard.kind === "import-or-local-call"), "real call hazard should be recorded");
  assert(trueFacts.hazards.some((hazard) => hazard.kind === "memory-write"), "real store hazard should be recorded");
  assert(trueFacts.hazards.some((hazard) => hazard.kind === "atomic"), "real atomic hazard should be recorded");

  const simdStore = validModuleWithSharedMemoryAndCode([
    0x41, 0x00, // store address
    0xfd, 0x0c, // v128.const
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xfd, 0x0b, 0x04, 0x00, // v128.store align=4 offset=0
  ]);
  assert(WebAssembly.validate(simdStore), "SIMD store control module should validate");
  const simdStoreFacts = scanEffectTrapFactsFromWasmBytes(simdStore);
  assert(simdStoreFacts.mutatesMemory, "real SIMD store should report memory mutation");
  assert(simdStoreFacts.mayTrap, "real SIMD store should report possible traps");
  assert(simdStoreFacts.hazards.some((hazard) => hazard.kind === "memory-write"), "real SIMD store hazard should be recorded");

  const noFunctions = Uint8Array.from([
    0x00, 0x61, 0x73, 0x6d,
    0x01, 0x00, 0x00, 0x00,
    0x05, 0x03, 0x01, 0x00, 0x01, // one memory with minimum one page
    0x0b, 0x0e, 0x01, 0x00, 0x41, 0x00, 0x0b, 0x08,
    0x00, 0x24, 0x26, 0x36, 0xfe, 0x10, 0x6d, 0x08, // inert data payload
  ]);
  assert(WebAssembly.validate(noFunctions), "no-function memory/data regression module should validate");
  const noFunctionFacts = scanEffectTrapFactsFromWasmBytes(noFunctions);
  assert(!noFunctionFacts.hasCall, "data bytes should not report calls when the module has no code section");
  assert(!noFunctionFacts.mutatesMemory, "data bytes should not report memory mutation when the module has no code section");
  assert(!noFunctionFacts.mutatesTable, "data bytes should not report table mutation when the module has no code section");
  assert(!noFunctionFacts.mutatesGlobal, "data bytes should not report global mutation when the module has no code section");
  assert(!noFunctionFacts.hasException, "data bytes should not report exceptions when the module has no code section");
  assert(!noFunctionFacts.hasAtomics, "data bytes should not report atomics when the module has no code section");
  assert(!noFunctionFacts.hasUnreachable, "data bytes should not report unreachable when the module has no code section");
  assert(!noFunctionFacts.mayTrap, "data bytes should not report traps when the module has no code section");
  assert(noFunctionFacts.hazards.length === 0, "data bytes should not report hazard offsets when the module has no code section");

  const typedReferenceLocal = validModuleWithSingleBody([
    0x01, 0x01, 0x63, 0x00, // one local with type (ref null 0)
    0x01, // nop
    0x0b,
  ]);
  assert(WebAssembly.validate(typedReferenceLocal), "typed-reference local regression module should validate");
  const typedLocalFacts = scanEffectTrapFactsFromWasmBytes(typedReferenceLocal);
  assert(!typedLocalFacts.hasUnreachable, "typed-reference local heap index should not report unreachable");
  assert(!typedLocalFacts.mayTrap, "typed-reference local declaration should not report traps");
  assert(typedLocalFacts.hazards.length === 0, "typed-reference local declaration should not report hazard offsets");

  for (const [opcode, name] of [[0x14, "call_ref"], [0x15, "return_call_ref"]] as const) {
    const referenceCall = validModuleWithSingleBody([
      0x00, // no locals
      0xd0, 0x00, // ref.null type 0
      opcode, 0x00, // reference call of type 0
      0x0b,
    ]);
    assert(WebAssembly.validate(referenceCall), `${name} regression module should validate`);
    const referenceCallFacts = scanEffectTrapFactsFromWasmBytes(referenceCall);
    assert(referenceCallFacts.hasCall, `${name} should report a call`);
    assert(referenceCallFacts.mayTrap, `${name} with a nullable reference should report a possible trap`);
    assert(!referenceCallFacts.hasUnreachable, `${name} type index should not report unreachable`);
    assert(referenceCallFacts.hazards.some((hazard) => hazard.kind === "import-or-local-call"), `${name} call hazard should be recorded`);
  }
}

if (import.meta.main) {
  runEffectTrapScannerTest();
}
