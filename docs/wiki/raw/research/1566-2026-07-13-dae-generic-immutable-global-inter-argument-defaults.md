# DAE generic immutable-global inter-argument defaults

## Question

Can `dae-optimizing` recover the remaining Func323-style default-parameter family generically when a value-producing result `if` is conditioned by an immutable defined `i32` global, followed by a dead `i32.const 0; if (void)` statement and a trailing exact literal, without admitting mutable globals or discarding effects from the statically chosen arm?

## Findings

Yes. The default-parameter specialization is now index-independent.

The callsite bridge from note `1565` now treats either of these as a statically known result-if condition:

- a direct `i32.const`; or
- a `global.get` whose referenced global is defined locally, immutable, typed `i32`, and initialized by one exact `i32.const`.

A generic module scan identifies direct callees reached through the immutable-global result-if plus dead-zero-if plus trailing-literal shape before the ordinary DAE core can peel only the final literal. Those callees run through the shared uniform exact-literal collector with immutable-global facts enabled. This ordering matters: it lets the collector recover both default parameters from the original callsite and rewrite them atomically when both are materializable.

The recognizer does not depend on Func313 or Func323 indices, the artifact's literal values, or a fixed parameter count. Mutable and imported globals are not static-condition facts. The selected result-if arm must still resolve through the existing materializable constant rules. If the chosen arm contains an observable call, trap-capable operation, or another unsupported prefix, that argument remains live; a separate trailing exact literal may still be removed safely.

## Selected Func323 boundary

The former selected 8/9-parameter Func323 default rewrite and its Func313-specific caller matcher are removed. The high-definition Func323 regression stays green through the generic immutable-global recognizer.

One narrower selected cleanup remains after the generic rewrite: when the already-seven-parameter artifact caller contains a dropped folded suffix block with the historical Func313 residual shape, the selected helper may strip that block and trim artifact locals. This is not default-parameter specialization. It remains artifact-local because there is no reduced non-artifact fixture demonstrating a reusable residual carrier family.

Reopen that residual cleanup only with:

1. a low-definition fixture reproducing the post-rewrite dropped folded-block shape without absolute function indices or artifact literal values;
2. focused effect/trap and mutable/imported-global negatives where relevant; and
3. direct compare or artifact evidence showing the generic cleanup is needed and remains valid.

## Tests

Red first on the pre-change implementation:

- `moon test src/passes/dae_optimizing_test.mbt --filter '*immutable-global-conditioned default suffix params*'`
  - failed with `3 != 1`
- `moon test src/passes/dae_optimizing_test.mbt --filter '*chosen-arm effects while removing immutable-global trailing default*'`
  - failed with `3 != 2`
- `moon test src/passes/dae_optimizing_test.mbt --filter '*mutable-global-conditioned default across dead zero-if gap*'`
  - passed as the safety boundary

The new fixtures prove:

- a low-definition immutable-global-conditioned result-if, dead-zero-if gap, and trailing literal removes both exact default parameters;
- an unreachable unchosen arm is not evaluated;
- an observable call in the statically chosen arm is preserved while the independent trailing default is removed; and
- a mutable global is not folded as a static condition.

## Validation

- `moon info`
  - passed with existing warnings
- `moon fmt`
  - passed; unrelated formatter-only changes were reverted
- `moon test src/passes/dae_optimizing_test.mbt`
  - `195/195` passed
- `moon test src/passes`
  - `5085/5085` passed
- `moon build --target native --release src/cmd`
  - passed with existing warnings
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-smoke-20260713-immutable-global-gap --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe`
  - requested/compared `1000/1000`
  - normalized matches `1000`
  - cleanup-normalized matches `0`
  - mismatches `0`
  - validation/property/generator/command failures `0`
  - Binaryen cache `1000` hits / `0` misses

## Remaining gap after this slice

The Func323 default-parameter family is no longer a selected behavior gap. The DAE audit remains active for the real public `precompute-propagate` sibling, fuller touched-function default-pipeline replay, broader operand localization beyond the guarded direct-literal and immutable-defined-global condition families, GC parameter refinement, result refinement, and inventory/classification of the remaining selected artifact helpers. The residual seven-parameter Func323 dropped folded-block cleanup is an explicit artifact-local boundary with the reopening evidence above.
