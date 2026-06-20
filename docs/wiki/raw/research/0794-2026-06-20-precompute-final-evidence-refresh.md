# Precompute final evidence refresh

## Question

Run the next bounded current-code evidence slice for canonical pass `precompute` after the O4z no-op boundary decision in [`0793`](0793-2026-06-20-precompute-o4z-boundary-decision.md). Determine whether `[O4Z-AUDIT-PC]` can enter final closeout, or whether refreshed lanes expose a new gap that must stay visible.

## Files reviewed

- `docs/README.md` — repo docs/wiki, pass signoff, validation, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — final pass closeout matrix and mismatch-classification rules.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` release-gating state.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier and final-lane guidance.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` through `0793-2026-06-20-precompute-o4z-boundary-decision.md` — recursive status chain.
- `docs/wiki/raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md` — `atomic.fence` pass-preservation boundary.
- `src/passes/precompute_test.mbt` — focused direct-pass behavior and new atomic-fence preservation guard.
- `.tmp/pass-fuzz-precompute-final-refresh-wasm-smith-10000/failures/case-006523-wasm-smith/` — newly exposed wasm-smith mismatch.

## Validation and compare commands

- `git status --short --branch`
  - Initial result: clean branch header `## starshine-gsi`.
- `moon info`
  - Passed with the three pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon fmt`
  - Passed.
- `moon test --package jtenner/starshine/passes --file precompute_test.mbt`
  - Passed `36/36` before the new boundary test.
- `moon test src/passes`
  - Passed `2693/2693` before the new boundary test.
- `moon test`
  - Passed `6015/6015` before the new boundary test.
- `moon build --target native --release src/cmd`
  - Completed with no work to do; `_build/native/release/build/cmd/cmd.exe` exists and `target/native/release/build/cmd/cmd.exe` remains absent.

### Direct regular GenValid bounded refresh

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-final-refresh-direct-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `1000/1000`; normalized `157`; cleanup-normalized `843`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `222` hits / `778` misses.

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-final-refresh-direct-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `10000/10000`; normalized `1547`; cleanup-normalized `8453`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `1002` hits / `8998` misses; selected profile `binaryen-oracle-portable=10000`.

This is strong refreshed regular evidence, but it is not the required final `100000` regular lane.

### Dedicated `precompute-all` GenValid lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-final-refresh-precompute-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `10000/10000`; normalized `5413`; cleanup-normalized `4587`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `10000` hits / `0` misses. Selected-profile counts: `precompute-scalar=2323`, `precompute-control=1560`, `precompute-global=1535`, `precompute-drop-cleanup=1518`, `precompute-effect-boundary=1509`, `precompute-direct-prefix-watch=793`, `precompute-gc-atomic-boundary=762`.

### Broad named GenValid lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass precompute --gen-valid-profile pass-fuzz-stress --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-final-refresh-pass-fuzz-stress-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `10000/10000`; normalized `1529`; cleanup-normalized `8471`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `14` hits / `9986` misses; selected profile `pass-fuzz-stress=10000`.

### Explicit wasm-smith lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-final-refresh-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: compared `9956/10000`; normalized `9952`; cleanup-normalized `3`; mismatches `1`; validation/generator/property failures `0`; command failures `44`; Binaryen cache `106` hits / `9850` misses; Binaryen failure cache `0` hits / `44` misses; wasm-smith cache `10000` hits / `0` misses. Command-failure classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, and `binaryen-table-index-out-of-range=1`.

The sole mismatch is `.tmp/pass-fuzz-precompute-final-refresh-wasm-smith-10000/failures/case-006523-wasm-smith`.

## New mismatch classification: reachable `atomic.fence` before branch-to-end

The reduced shape is:

```wat
(module
  (func (export "main")
    atomic.fence
    br 0
    atomic.fence))
```

Binaryen `--precompute` reduces this to a function body containing only `nop`. Starshine preserves a block containing the reachable `atomic.fence` followed by a branch to the block/function end; later dead tail is irrelevant. The wasm-smith input has atomics (`inputEffectTrapFacts.hasAtomics=true`) and no Starshine validation failure.

Agent classification: **intentional Starshine correctness boundary / Binaryen-output divergence**, not a safe cleanup implementation target for this slice. The supporting source is `docs/wiki/raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`, which records that `atomic.fence` has no stack or memory operands but must still be preserved by passes as an ordering barrier. Removing it merely to match Binaryen would be a size win but risks violating Starshine's local atomic-ordering contract.

To keep this boundary from being accidentally erased while chasing compare parity, this slice added a focused guard in `src/passes/precompute_test.mbt`:

- `precompute intentionally preserves reachable atomic fence before branch-to-end`

This is a boundary/fail-closed test, not a red-first behavior implementation. A temporary red-first attempt to assert Binaryen-shaped removal instead failed at fixture parsing because Starshine's WAT parser does not expose textual `atomic.fence`; the final guard builds the module through core instruction constructors and asserts the fence and branch remain.

Post-test validation:

- `moon test --package jtenner/starshine/passes --file precompute_test.mbt` — passed `37/37`.
- `moon fmt && moon test --package jtenner/starshine/passes --file precompute_test.mbt && moon test src/passes && moon build --target native --release src/cmd && git diff --check` — passed; focused precompute tests `37/37`, pass package tests `2694/2694`, native build no work to do, diff check clean.

## Classification

- Direct regular GenValid: refreshed green through `10000` with PC normalizers and explicit `_build` native path; final required `100000` lane still not run.
- Dedicated `precompute-all`: refreshed green for the required `10000` lane with all seven leaves sampled.
- Broad named `pass-fuzz-stress`: refreshed green for `10000`.
- Explicit wasm-smith: not green. It has one inspected mismatch, classified as a Starshine atomic-fence preservation boundary, plus `44` Binaryen/oracle command failures in known external-generator classes.
- O4z boundary: unchanged from `0793`; no slot19/slot43 replay was run because `.artifacts` remains absent.
- `[O4Z-AUDIT-PC]`: remains open. The newly found wasm-smith atomic-fence divergence must remain visible in backlog/final reports, and final closeout still needs the `100000` regular lane plus a decision on whether the atomic-fence boundary is accepted for pass closure.

## Commands not run

- Regular GenValid `100000` was not run in this slice; the `10000` lane completed quickly and gives current evidence, but it does not replace final closeout.
- No rerun of wasm-smith after behavior change was run because pass behavior intentionally did not change; the preserved-fence boundary is now tested and documented.
- No historical O4z slot19/slot43 replay was run because `.artifacts` is absent.
- No pass-local timing was reported by the compare harness result JSON for these lanes; runtime execution was off.

## Next work

1. Decide at project/audit level whether the reachable-`atomic.fence` wasm-smith mismatch is an accepted Starshine correctness boundary for `precompute` closure. If not accepted, the only closeout path is a deliberate policy change that allows `precompute` to erase reachable fences, which currently conflicts with the local atomics docs.
2. Run the missing final regular GenValid `100000` lane with PC normalizers and `_build/native/release/build/cmd/cmd.exe`.
3. If the atomic-fence boundary is accepted, update the final closeout report/backlog accordingly and keep the focused boundary guard. If it is not accepted, keep `[O4Z-AUDIT-PC]` open with this mismatch as an explicit blocker.
