# Precompute self-branch reduction slice

## Question

Reduce the regular GenValid mismatch family opened by [`0789`](0789-2026-06-20-precompute-native-path-and-bounded-evidence.md), starting from `.tmp/pass-fuzz-precompute-native-path-policy-direct-100/failures/case-000004-gen-valid`, and implement the smallest safe `precompute` behavior slice if the reduction exposes a clear parity gap.

## Files reviewed

- `docs/README.md` — pass-audit, TDD, validation, docs/wiki, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation contract.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass mismatch classification and signoff rules.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` blocker state.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` through `0789-2026-06-20-precompute-native-path-and-bounded-evidence.md` — status refresh chain.
- `src/passes/precompute.mbt` — HOT region cleanup and self-branch cleanup logic.
- `src/passes/precompute_test.mbt` — focused public-pipeline precompute tests.
- `.tmp/pass-fuzz-precompute-native-path-policy-direct-100/failures/case-000004-gen-valid/` — original mismatch artifacts.

## Reduction

The first sampled mismatch was not an O4z no-op or missing-native-path issue. It reduced to a direct `--precompute` HOT cleanup gap around a void `block` that exits to its own label with a constant `br_if`, followed by removable `nop`/dead-prefix debris before a final constant result:

```wat
(module
  (func (export "main") (result i32)
    i32.const 1
    drop
    (block
      i32.const 1
      br_if 0)
    nop
    i32.const 134))
```

Binaryen `--precompute` reduces that function to just the final `i32.const 134`. Starshine previously removed the dropped constant but left the self-exiting block and nops, so the regular GenValid case stayed a raw mismatch even with the documented PC cleanup normalizers.

A self-targeting void block with an exact constant `br_if` condition is a safe no-op: if the condition is false, control falls through to the end of the block; if it is true, the branch also exits to the end of the same void block. The condition is exact and side-effect-free in this slice.

## TDD and implementation

Added red-first coverage in `src/passes/precompute_test.mbt`:

- `precompute removes constant self-exiting blocks before a final const result`

The red run failed because the function body still contained the self-exiting block and `nop` residue.

Implemented the smallest HOT cleanup slice in `src/passes/precompute.mbt`:

- factored `precompute_control_is_const_self_br_if_noop(...)`;
- preserved the existing behavior that removes constant-false self-branching loops;
- extended the helper to remove constant true-or-false self-exiting void blocks with zero-arity labels;
- left constant-true self-branching loops intact because those are infinite loops, not no-op blocks.

## Commands and results

- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - Red-first result after adding the test: failed `precompute removes constant self-exiting blocks before a final const result`; the pretty body still had `nop(block (Void) (i32.const I32(1))(br_if (Label 0))(end))nop(i32.const I32(134))(end)`.
- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - After implementation: passed `34/34`.
- `moon fmt && moon test --package jtenner/starshine/passes --file precompute_test.mbt && moon test src/passes && moon build --target native --release src/cmd`
  - Passed. Focused precompute tests passed `34/34`; pass package tests passed `2691/2691`; native build completed and `_build/native/release/build/cmd/cmd.exe` was available. Native build printed pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Reduced replay with `_build/native/release/build/cmd/cmd.exe --precompute` on `.tmp/precompute-reduce/block-brif-prefix.wasm`
  - Starshine now prints the same reduced shape as Binaryen for the focused block witness: only `i32.const 134` remains.
- Original `case-000004-gen-valid` replay with the rebuilt native binary
  - The self-exiting-block subfamily is fixed. The remaining diff in this case is now the pre-existing constant-false self-branching loop shape: Starshine removes it to `nop`, while Binaryen keeps `loop (nop)`. This is agent-classified as a Starshine size/cleanup win, supported by the existing focused test `precompute removes constant-false self-branch loop debris`; it still needs compare-normalizer or explicit closeout handling before a raw lane can be called green.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-self-brif-fix-direct-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Compared `100/100`; normalized `3`; cleanup-normalized `77`; mismatches `20`; validation/generator/property/command failures `0`; Binaryen cache `100` hits / `0` misses. This is an improvement in raw/cleanup-normalized distribution but not a closeout-green regular lane.

## Classification

- Fixed behavior gap: self-exiting void block with exact constant `br_if` to its own zero-arity block label before removable const-result debris. This was a small Binaryen parity gap and is now covered by a focused regression.
- Remaining regular GenValid family: still open. The 100-case refresh still has `20` raw mismatches after PC normalizers.
- Remaining inspected subfamilies:
  - constant-false self-branching loop removed by Starshine but kept as `loop (nop)` by Binaryen. Agent classification: semantic-safe Starshine size/cleanup win, already focused-test-backed, but still needs explicit compare closeout handling;
  - constant-true self-branching loops and following dead tails where Binaryen rewrites toward `loop (br ...)` plus `unreachable` and Starshine leaves more original dead tail structure. Agent classification: open size-losing/optimization-parity gap, not a semantic-risk finding from this slice;
  - large root `nop` prefix differences in functions that also contain loop/control debris. Agent classification: mixed debris family; needs the loop/dead-tail decision before final regular GenValid classification.
- `[O4Z-AUDIT-PC]`: remains open. This slice fixed one reduced direct mismatch subfamily but did not close the regular GenValid family, the O4z no-op boundary decision, slot/neighborhood evidence, or final four-lane closeout matrix.

## Commands not run

- No full `moon test` was run before this note was filed; the focused pass package and native build were enough for the implementation loop, with broader validation scheduled before commit.
- No `100000` regular lane, `10000` wasm-smith lane, `10000` dedicated `precompute-all` lane, or `10000` `pass-fuzz-stress` lane was run because the regular 100-case blocker is still open.
- No historical slot19/slot43 replay was run because this slice targeted direct regular GenValid reduction first.

## Next work

1. Decide the compare-closeout handling for constant-false self-branching loops: either keep the existing Starshine cleanup as a documented size win with a source-backed normalizer/closeout rule, or align output shape to Binaryen if raw-lane parity is preferred.
2. Reduce the constant-true self-branching loop/dead-tail family from `.tmp/pass-fuzz-precompute-self-brif-fix-direct-100/failures/` and decide whether to implement Binaryen-style `loop (br ...)` / unreachable-tail cleanup or leave a precise backlog entry.
3. Rerun bounded regular GenValid after that decision before attempting the final closeout matrix.
