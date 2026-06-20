# Precompute loop-nop closeout normalizer

## Question

Decide the remaining regular GenValid constant-false self-branching loop / mixed root-debris closeout handling left open by [`0791`](0791-2026-06-20-precompute-true-loop-tail-reduction.md): should Starshine align to Binaryen's `loop (nop)` output shape, or keep its smaller no-op cleanup and make the compare normalizer source-backed enough for bounded evidence.

## Files reviewed

- `docs/README.md` — pass-audit, mismatch classification, docs/wiki, validation, and commit rules.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation contract.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass compare, normalizer, and closeout requirements.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` state and remaining release-gating blockers.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier and fuzzing guidance.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` through `0791-2026-06-20-precompute-true-loop-tail-reduction.md` — current recursive-chain evidence.
- `src/passes/precompute.mbt` and `src/passes/precompute_test.mbt` — existing focused behavior proving Starshine removes constant-false self-branching loop debris and self-exiting blocks.
- `scripts/lib/pass-fuzz-compare-task.ts` and `scripts/lib/pass-fuzz-compare-task.test.ts` — compare normalizer implementation and focused normalizer tests.
- `.tmp/pass-fuzz-precompute-true-loop-hot-fix-direct-100/failures/` — remaining bounded regular GenValid mismatch artifacts.

## Decision

Keep Starshine's current cleanup as an intentional Starshine size/cleanup win for exact void no-op control wrappers, and extend the existing `unreachable-control-debris` compare normalizer to treat `block` / `loop` bodies containing only `nop` as no-op control debris.

Rationale:

- A void `loop` with an empty or all-`nop` body executes once and falls through; removing the wrapper preserves behavior.
- A void `block` with an empty or all-`nop` body similarly preserves behavior when erased.
- Existing Starshine behavior is already focused-test-backed for the main generated family: `precompute removes constant-false self-branch loop debris` removes `loop { i32.const 0; br_if 0 }` instead of keeping Binaryen's later `loop (nop)` residue.
- A minimal replay with a following `local.get` shows the current Starshine output is smaller than Binaryen's preserved wrapper: `.tmp/precompute-loop-nop-closeout/false-loop-local.binaryen.wasm` is `43` bytes while `.tmp/precompute-loop-nop-closeout/false-loop-local.starshine.wasm` is `40` bytes. The canonical WAT differs only by Binaryen's `loop (nop)` versus Starshine's `nop` before the same `local.get`.
- The remaining mixed `block (br self)` / root-`nop` cases are the same no-op-control family: a self-targeting void block exits to its own end, and the existing normalizer already erases that shape; it was blocked only when paired against Binaryen's `loop (nop)` residue.

This is not a claim that arbitrary loop or block drift is safe. The normalizer stays syntax-scoped to standalone void control expressions whose body is empty or contains only literal `nop`, plus the pre-existing constant self-branch forms. It does not erase control containing locals, globals, memory/table ops, calls, branches other than the existing exact self-branch patterns, traps, values, or nested effectful operations.

## TDD and implementation

Added red-first normalizer coverage by extending `scripts/lib/pass-fuzz-compare-task.test.ts` test `unreachable-control-debris normalizes constant self-branch blocks and loops` with a Binaryen-shaped `loop (nop)` before a standalone `nop`. The focused test failed before implementation because the old normalizer erased empty loops but not loops with a `nop` body.

Implemented the smallest tooling change in `scripts/lib/pass-fuzz-compare-task.ts`: `isSimpleEmptyVoidControlNoop(...)` now accepts zero or more standalone `nop` body lines for otherwise empty `block` / `loop` wrappers.

No pass behavior changed in this slice.

## Commands and results

- `bun test scripts/lib/pass-fuzz-compare-task.test.ts -t "unreachable-control-debris normalizes constant self-branch blocks and loops"`
  - Red-first result before implementation: failed because the normalized Binaryen text still contained the new `loop (nop)` wrapper.
- `bun test scripts/lib/pass-fuzz-compare-task.test.ts -t "unreachable-control-debris normalizes constant self-branch blocks and loops"`
  - After implementation: passed `1` focused test.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-loop-nop-normalizer-direct-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Compared `100/100`; normalized `16`; cleanup-normalized `84`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `100` hits / `0` misses.
- Minimal size replay under `.tmp/precompute-loop-nop-closeout/false-loop-local.*`
  - Binaryen preserved `loop (nop)` before `local.get 0` and wrote `43` bytes.
  - Starshine emitted `nop` before the same `local.get 0` and wrote `40` bytes.

## Classification

- Regular bounded GenValid family: addressed for the 100-case smoke. The previous `.tmp/pass-fuzz-precompute-true-loop-hot-fix-direct-100` `20` raw mismatches normalize to `0` mismatches with the tightened, source-backed PC normalizer in `.tmp/pass-fuzz-precompute-loop-nop-normalizer-direct-100`.
- Agent classification: semantic-safe, size-winning Starshine cleanup for exact no-op void control wrappers; covered by focused pass behavior tests and focused normalizer tests.
- Direct pass closeout: not complete. This bounded `100`-case lane does not replace the required regular GenValid `100000`, explicit wasm-smith `10000`, dedicated `precompute-all` `10000`, and broad `pass-fuzz-stress` `10000` lanes.
- `[O4Z-AUDIT-PC]`: remains open. The next blockers are the remaining O4z no-op boundary/slot evidence decision and the final four-lane matrix with `_build/native/release/build/cmd/cmd.exe`.

## Commands not run

- No Moon tests were required for pass behavior because only compare tooling and docs changed; executable pass behavior did not change.
- No final closeout lanes were run because this slice was the bounded closeout decision for the regular GenValid mismatch family, not the final signoff.
- No historical O4z slot19/slot43 replay was run; that remains the next release-gating slice.

## Next work

1. Decide/document the remaining O4z release boundary for HOT-only cleanup and historical slot/neighborhood evidence, including exact reopening criteria if any no-op surface is accepted for v0.1.0.
2. Refresh direct/O4z evidence with current code and `_build/native/release/build/cmd/cmd.exe`.
3. Only after the O4z decision is explicit, run the final four-lane closeout matrix.
