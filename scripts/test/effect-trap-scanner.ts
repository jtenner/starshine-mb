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
}

if (import.meta.main) {
  runEffectTrapScannerTest();
}
