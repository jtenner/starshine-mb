import { expect, test } from "bun:test";
import { applyCompareNormalizersForTest } from "../pass-fuzz-compare-task.ts";

test("drop-consts keeps division and remainder with a computed zero divisor", () => {
  const empty = `(module
 (func $run (export "run")
 )
)
`;
  for (const width of [32, 64]) {
    for (const opcode of ["div_s", "div_u", "rem_s", "rem_u"]) {
      const original = `(module
 (func $run (export "run")
  (drop (i${width}.${opcode} (i${width}.const 7)
    (i${width}.sub (i${width}.const 2) (i${width}.const 2))))
 )
)
`;
      expect(applyCompareNormalizersForTest(original, ["drop-consts"]))
        .not.toBe(applyCompareNormalizersForTest(empty, ["drop-consts"]));
    }
  }
});
