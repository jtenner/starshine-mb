# DAE generic constant-condition inter-argument defaults

## Question

Can `dae-optimizing` recover multiple exact-literal default arguments when a value-producing constant-condition `if` is followed by a stack-neutral dead `i32.const 0; if (void)` statement before the trailing literal argument, without widening the folded-multivalue suffix rule into arbitrary inter-argument operand localization?

## Findings

Yes, for a narrow literal-conditioned family.

The previous suffix-only recognizer from note `1564` deliberately rejected a resolved suffix when the instruction immediately before it had zero stack output. That preserved the selected Func323 path, but it also rejected a lower-definition generic shape where:

1. an earlier call argument is a value-producing `if` whose condition is an exact `i32` literal;
2. the selected arm resolves to a materializable exact literal;
3. a later `i32.const 0; if (void)` statement is provably dead because the condition is zero; and
4. the final argument is another exact literal.

The callsite collector now widens a trailing value slice over that dead zero-if pair only when the pair is immediately preceded by a direct literal-conditioned result `if`. The uniform-constant collector now resolves:

- ordinary one-instruction exact literals and existing structured constant carriers;
- two-instruction literal-condition result-if arguments by selecting only the statically executed arm; and
- the guarded dead-zero-if-plus-trailing-literal slice.

The chosen result-if arm must still reduce through the existing materializable constant rules. Effects or traps in the unchosen arm are not evaluated, matching WebAssembly constant-condition semantics. The widening does not admit arbitrary zero-output instructions between arguments.

## Func323 boundary

The selected Func323 regression remains green and selected. Its earlier result-if condition is an immutable `global.get`, not a direct `i32.const`, so the new bridge guard deliberately does not claim that artifact family. This slice therefore narrows the Func323 frontier from “all inter-argument debris” to the remaining immutable-global-conditioned/default-cleanup path plus any broader nonliteral operand localization.

Reopening evidence for widening this recognizer should include a reduced non-artifact fixture where the condition is proven constant through a generic fact, a focused negative for the corresponding effect/trap boundary, and direct compare evidence. Do not widen the bridge merely because an instruction has zero net stack output.

## Code changes

- `src/passes/dae_optimizing_test.mbt`
  - added `dae-optimizing removes generic constant-condition default suffix params across dead zero-if gap`
- `src/passes/dead_argument_elimination.mbt`
  - added a guarded callsite-shape bridge over `i32.const 0; if (void)` after a direct literal-conditioned result-if argument
  - centralized uniform exact-literal resolution by argument shape
  - added constant-condition result-if arm selection
  - shared immutable defined-i32-global value lookup with the existing Func323 selected matcher

## Validation

Red first:

- with the pre-change implementation restored temporarily, `moon test src/passes/dae_optimizing_test.mbt --filter '*generic constant-condition default suffix params across dead zero-if gap*'`
  - failed with `3 != 1`

Green after implementation:

- `moon test src/passes/dae_optimizing_test.mbt --filter '*generic constant-condition default suffix params across dead zero-if gap*'`
- `moon test src/passes/dae_optimizing_test.mbt --filter '*Func323 default suffix params*'`
- `moon test src/passes/dae_optimizing_test.mbt --filter '*generic forwarded default argument from folded multivalue callsite*'`
- `moon test src/passes/dae_optimizing_test.mbt`
  - `192/192` passed
- `moon test src/passes`
  - `5082/5082` passed
- `moon build --target native --release src/cmd`
  - passed with existing warnings
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-smoke-20260712-const-condition-gap --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe`
  - requested/compared `1000/1000`
  - normalized matches `1000`
  - cleanup-normalized matches `0`
  - mismatches `0`
  - validation/property/generator/command failures `0`
  - Binaryen cache `1000` hits / `0` misses

## Remaining gap after this slice

The DAE audit remains active. This closes one more generic operand-localization/default family but does not provide arbitrary inter-argument statement localization, immutable-global-conditioned Func323 genericization, the real public `precompute-propagate` sibling, full touched-function default-pipeline replay, GC parameter refinement, result refinement, or the remaining selected/artifact helper families.
