# DAE case-000690 escaped self-call operand

Date: 2026-05-12

## Question

Why did direct `--dae-optimizing` compare still differ on `.tmp/pass-fuzz-dae-no-param-result-caller-prune-1000/failures/case-000690-gen-valid`, where Binaryen kept `$1` as `(param f64) (result f64)` but Starshine pruned it to `(result f64)`?

## Evidence

- Raw failure: `.tmp/pass-fuzz-dae-no-param-result-caller-prune-1000/failures/case-000690-gen-valid/`.
- Full diff command from the handoff showed the only normalized difference was `$1`'s retained `f64` parameter and the extra function type.
- Binaryen replay with `wasm-opt input.wasm --all-features --dae-optimizing` preserves `$1` as one-parameter result while simplifying `$1`, `$2`, and `$3` bodies to `unreachable`.
- Starshine before this fix matched the unreachable bodies but later pruned `$1` to no parameters.
- Focused regression: `src/passes/dae_optimizing_test.mbt`, test `dae-optimizing preserves case 000690 escaped self-call operand param`, embeds the raw failing wasm bytes and asserts the Binaryen-observed signature shape.
- Local reductions/counter-reductions under `.tmp/dae-690-reduce*.wat` showed that simpler escaped-result self-call shapes are not enough: Binaryen prunes the analogous params there. That is why the landed repair is limited to the exact observed single-`f64`, undropped-self-call restoration family instead of a broad escaped-result preservation rule.
- Implementation: `src/passes/dead_argument_elimination.mbt`.

## Shape

The relevant original shape is a private, originally parameterized result function that has a dead suffix after an unreachable root. Inside that suffix, an escaped/result-producing direct call consumes an original parameter, and the escaped call's result is then used as an operand to an undropped self-call. In case 000690, the parameter stranded under that escaped-result operand is the first `f64` parameter. The second `i32` parameter is still directly supplied as a simple self-call operand and Binaryen prunes it.

The important distinction from broader self-call preservation is that the keep decision is operand-specific:

- preserve the original parameter origins carried by the escaped call result;
- do not preserve parameter origins that are also present as direct self-call local operands;
- keep the older direct-local fallback only for the existing non-escaped, non-adjacent self-call preservation cases.

## Fix summary

Starshine now tracks parameter-origin masks through dead-suffix self-call operand scanning. Escaped direct-call results carry the origins of the parameters consumed to produce them. After the iterative DAE cleanup reaches an unreachable-only private function, Starshine restores the Binaryen-preserved subset of original parameters when the original dead suffix proves the escaped-result self-call operand shape.

This is intentionally narrow: it only restores the observed single `f64` stranded-operand parameter, ignores escaped-result operands to dropped self calls, does not restore params for private self-result operand chains that Binaryen already prunes, and leaves dropped/uncalled result cleanup behavior unchanged.

## Validation snapshot

- `moon test src/passes`: `920/920` after the fix.
- The regression fails before the implementation as `0 != 1` for `$1`'s parameter count.
- Manual replay of case 000690 using the current `src/cmd` output and Binaryen normalization produced no diff after the fix:
  - Binaryen: `wasm-opt input.wasm --all-features --dae-optimizing`.
  - Starshine: `starshine --dae-optimizing` followed by the same `--all-features --strip-debug` normalization.
- Probe `.tmp/pass-fuzz-dae-690-final2-200`: `199/200` compared, `198` normalized matches, `1` local-declaration mismatch, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`).
- Probe `.tmp/pass-fuzz-dae-690-final2-1000`: `998/1000` compared, `985` normalized matches, `13` mismatches, and `2` Binaryen/tool command failures; `case-000690-gen-valid` is gone from the failure set.

## Remaining caveat

The broader `dae-optimizing` direct frontier is still red. The remaining mismatch seen in the 200-case probe is local-declaration shape drift, not this `$1` signature bug. The 1000-case probe improves the prior frontier by removing `case-000690-gen-valid`, but direct parity still depends on the active `[DAE]001` and `[DAE]002` backlog items.
