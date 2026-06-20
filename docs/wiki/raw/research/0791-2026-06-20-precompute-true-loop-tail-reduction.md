# Precompute true-loop tail reduction

## Question

Continue reducing the regular GenValid mismatch family left open by [`0790`](0790-2026-06-20-precompute-self-branch-reduction.md), focusing on the constant-true self-branching loop / dead-tail subfamily visible in `.tmp/pass-fuzz-precompute-self-brif-fix-direct-100/failures/case-000008-gen-valid`.

## Files reviewed

- `docs/README.md` — pass-audit, TDD, validation, docs/wiki, and commit rules.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation contract.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass mismatch classification and signoff rules.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` state and remaining release-gating blockers.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier and fuzzing guidance.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` through `0790-2026-06-20-precompute-self-branch-reduction.md` — current recursive-chain evidence.
- `src/passes/precompute.mbt` — HOT and raw cleanup implementations.
- `src/passes/precompute_test.mbt` — focused public-pipeline precompute tests.
- `.tmp/pass-fuzz-precompute-self-brif-fix-direct-100/failures/case-000008-gen-valid/` — sampled remaining regular GenValid mismatch.

## Reduction

The sampled `case-000008-gen-valid` still contained the previously described constant-true loop/dead-tail family. A minimal direct witness is:

```wat
(module
  (func (export "main") (result i32)
    (loop
      i32.const 1
      br_if 0)
    i32.const 310))
```

Binaryen `--precompute` rewrites the loop body to an unconditional branch and marks the following result tail unreachable:

```wat
(loop $label
  (br $label))
(unreachable)
```

Starshine already rewrote the simple raw form's `br_if` to `br`, but left the following value tail as reachable output. In HOT-shaped generated cases, the true self-branch loop could still retain `br_if` until this slice. A constant-true self-branching loop never falls through, so any following result-producing root is unreachable; replacing the result suffix with one `unreachable` is semantics-preserving and matches Binaryen's observable precompute shape for this family.

## TDD and implementation

Added focused coverage in `src/passes/precompute_test.mbt`:

- `precompute marks constant-true self-branch loop tails unreachable`
- `precompute marks constant-true self-branch loop tails unreachable after block debris`

The first test was added red-first before implementation and failed because Starshine still emitted the final `i32.const 310` after the infinite loop. The block-debris fixture covers a cleanup-heavy shape adjacent to the GenValid family.

Implemented the smallest safe slice in `src/passes/precompute.mbt`:

- raw path: after a void `loop` whose body is exactly `br 0`, replace a following suffix made only of `nop` plus flat value roots with one `unreachable`;
- HOT path: for a root void `loop` whose only body root is a constant-true `br_if` to the loop's own zero-arity label, rewrite the body to `br` and replace a following result-producing root suffix with one `unreachable`;
- constant-false loop cleanup remains unchanged and still removes Starshine's no-op loop debris to `nop`.

## Commands and results

- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - Red-first result after adding `precompute marks constant-true self-branch loop tails unreachable`: failed because the body still had `(loop (Void) (br (Label 0))(end))(i32.const I32(310))(end)`.
- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - After raw implementation: passed `35/35`.
- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - After adding the block-debris coverage and HOT implementation: passed `36/36`.
- `moon fmt && moon test --package jtenner/starshine/passes --file precompute_test.mbt && moon test src/passes && moon build --target native --release src/cmd`
  - Passed. Focused precompute tests passed `36/36`; pass package tests passed `2693/2693`; native build completed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Reduced replay with `_build/native/release/build/cmd/cmd.exe --precompute` on `.tmp/precompute-reduce/true-loop-tail.wasm`, followed by `wasm-opt --all-features -S --strip-debug` diff against Binaryen.
  - Starshine now matches Binaryen on the reduced true-loop witness: loop body is `br` and the result tail is `unreachable`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-true-loop-hot-fix-direct-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Compared `100/100`; normalized `16`; cleanup-normalized `64`; mismatches `20`; validation/generator/property/command failures `0`; Binaryen cache `100` hits / `0` misses.
  - The true-loop result-tail subfamily is fixed in sampled case `000008`; the remaining raw mismatches are still dominated by Starshine removing constant-false self-branching loops to `nop` while Binaryen preserves `loop (nop)`, plus mixed root `block (br self)` / `nop` debris around the same control-cleanup family.

## Classification

- Fixed behavior gap: constant-true self-branching void loop followed by a result-producing dead tail. Starshine now rewrites the self-branch to unconditional `br` and marks the following result suffix unreachable in both raw and HOT cleanup paths.
- Remaining regular GenValid family: still open. The bounded 100-case lane remains at `20` raw mismatches after PC normalizers, even though normalized matches increased from `3` to `16`; do not treat the regular lane as closeout-green.
- Current remaining agent classification:
  - constant-false self-branching loop cleanup is still a focused-test-backed Starshine size cleanup (`loop (br_if 0 (i32.const 0))` to `nop`) while Binaryen keeps `loop (nop)`; this needs an explicit compare closeout decision or a Starshine alignment change;
  - mixed root `block (br self)` and `nop` debris appears in many remaining mismatch dirs next to the false-loop family and still needs a source-backed closeout rule or follow-up reduction;
  - no Starshine validation, generator, property, or command failure was found in this slice.
- `[O4Z-AUDIT-PC]`: remains open. This slice reduced one regular GenValid subfamily but did not decide the constant-false loop closeout rule, O4z no-op boundary/slot evidence, or final four-lane closeout matrix.

## Commands not run

- No `100000` regular GenValid lane, `10000` wasm-smith lane, `10000` dedicated `precompute-all` lane, or `10000` `pass-fuzz-stress` lane was run because the bounded regular lane still has an open mismatch family.
- No historical O4z slot19/slot43 replay was run; this slice targeted the direct regular GenValid loop/dead-tail blocker first.

## Next work

1. Decide the constant-false self-branching loop closeout policy: either keep Starshine's smaller `nop` output as an explicitly documented Starshine size/cleanup win with compare-normalizer support, or align Starshine to Binaryen's `loop (nop)` if raw-lane parity is required.
2. Reduce the mixed `block (br self)` / root `nop` debris that remains in `.tmp/pass-fuzz-precompute-true-loop-hot-fix-direct-100/failures/` after the true-loop fix.
3. Only after the remaining regular GenValid family is explicit, resume the O4z boundary/slot evidence decision and final four-lane closeout matrix.
