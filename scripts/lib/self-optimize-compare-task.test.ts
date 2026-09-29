import { expect, test } from "bun:test";

import { normalizeBinaryenPassFlags } from "./self-optimize-compare-task";

test("maps Starshine direct-pass names to Binaryen v133 flags", () => {
  expect(normalizeBinaryenPassFlags([
    "--global-effects",
    "--global-struct-inference-desc-cast",
    "--global-type-optimization",
    "--simplify-locals-no-nesting",
    "--simplify-locals-no-tee",
  ])).toEqual([
    "--generate-global-effects",
    "--gsi-desc-cast",
    "--gto",
    "--simplify-locals-nonesting",
    "--simplify-locals-notee",
  ]);
});

test("expands Starshine's optimizing DAE2 spelling to the Binaryen sequence", () => {
  expect(normalizeBinaryenPassFlags(["--dae2-optimizing"])).toEqual([
    "--dae2",
    "--simplify-locals",
    "--vacuum",
  ]);
});
