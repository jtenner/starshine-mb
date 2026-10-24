import { expect, test } from "bun:test";
import { evaluateIntegerExpression, type IntegerExpression } from "./optimizer-translation-validation";

// Independent binary fixture: two parameters followed by one actual Wasm opcode.
// It intentionally does not translate the expression model into bytecode.
const opcodes = { add: 0x6a, sub: 0x6b, mul: 0x6c, div_s: 0x6d, div_u: 0x6e, rem_s: 0x6f, rem_u: 0x70, and: 0x71, or: 0x72, xor: 0x73, shl: 0x74, shr_u: 0x76 };
function section(id: number, bytes: number[]) { return [id, bytes.length, ...bytes]; }
function operator(width: number, opcode: number): (...args: any[]) => number | bigint {
  const type = width === 32 ? 0x7f : 0x7e;
  const bytes = new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0,
    ...section(1, [1, 0x60, 2, type, type, 1, type]),
    ...section(3, [1, 0]), ...section(7, [1, 1, 102, 0, 0]),
    ...section(10, [1, 7, 0, 0x20, 0, 0x20, 1, opcode + (width === 64 ? 0x12 : 0), 0x0b])]);
  expect(WebAssembly.validate(bytes)).toBe(true);
  return new WebAssembly.Instance(new WebAssembly.Module(bytes)).exports.f as (...args: any[]) => number | bigint;
}

test("integer model agrees with actual i32/i64 execution at wrap, signed and masked-shift boundaries", () => {
  for (const width of [32, 64]) {
    const values = [0n, 1n, 2n, -1n, -2n, 1n << BigInt(width - 1), (1n << BigInt(width - 1)) - 1n, BigInt(width - 1), BigInt(width), BigInt(width + 1)];
    for (const [kind, opcode] of Object.entries(opcodes)) {
      const run = operator(width, opcode);
      const expression = { kind, width, left: { kind: "var", width, name: "x" }, right: { kind: "var", width, name: "y" } } as IntegerExpression;
      for (const x of values) for (const y of values) {
        const expected = evaluateIntegerExpression(expression, { x, y });
        let observed;
        try {
          const result = run(...[x, y].map((value) => width === 64 ? BigInt.asIntN(64, value) : Number(BigInt.asIntN(32, value))));
          observed = { defined: true, value: BigInt.asUintN(width, BigInt(result)) };
        } catch (error) {
          expect(error).toBeInstanceOf(WebAssembly.RuntimeError);
          const message = String(error);
          observed = { defined: false, trapClass: /divide by zero|division by zero/i.test(message) ? "integer-divide-by-zero" : /overflow|unrepresentable/i.test(message) ? "signed-integer-division-overflow" : message };
        }
        expect(observed).toEqual(expected);
      }
    }
  }
});
