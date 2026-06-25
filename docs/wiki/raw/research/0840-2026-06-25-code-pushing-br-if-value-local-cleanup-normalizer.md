# Code-pushing value br_if local-cleanup normalizer

Date: 2026-06-25

## Scope

Follow-up for `[O4Z-AUDIT-CP]` after the targeted `code-pushing-br-if-value` leaf remained outside `code-pushing-all` due to value-branch temporary-local output drift recorded in [`0833`](0833-2026-06-25-code-pushing-br-if-value-lowering-blocker.md).

## Finding

Representative mismatch: `.tmp/pass-fuzz-code-pushing-br-if-value-refresh-100-20260625/failures/case-000001-gen-valid`.

Both Binaryen and Starshine sink the generated user-local sets after the value-block-target `br_if`. The remaining shape difference is a local cleanup / lowerer carrier around the fallthrough result:

- Binaryen emits `drop (br_if $block (i32.const 42) (local.get $cond))` before the moved user locals.
- Starshine emits `local.set tmp (br_if ...)`, then later `drop (local.get tmp)` after the moved user locals.

Agent classification: narrow compare-normalized local cleanup/lowering debris after the code-pushing movement fix. The temp local is only written by the `br_if` result and later dropped; removing the unused temp write and wrapping the original `br_if` in a `drop` keeps the branch/control expression at its original evaluation point and does not hide moved-local ordering drift.

## TDD and implementation

Added a red-first harness normalizer test in `scripts/lib/pass-fuzz-compare-task.test.ts`:

- `local-cleanup-debris erases single-use br_if result drop temps`

The test failed before implementation because `local-cleanup-debris` kept the extra local declaration, `local.set tmp (br_if ...)`, and later `drop (local.get tmp)`.

Implemented a narrow `local-cleanup-debris` normalizer in `scripts/lib/pass-fuzz-compare-task.ts` for named-local WAT where:

- a `local.set tmp` directly wraps a `br_if` expression;
- `tmp` appears exactly twice in the function, as that set and the later dropped use;
- the normalizer rewrites the set to `drop (br_if ...)` at the original branch evaluation point and removes the later dropped temp use.

Focused validation:

```sh
bun test scripts/lib/pass-fuzz-compare-task.test.ts -t 'br_if result drop temps'
# failed before implementation

bun test scripts/lib/pass-fuzz-compare-task.test.ts
# passed 35/35
```

## Targeted profile refresh

The targeted value-`br_if` lane is clean under the documented `local-cleanup-debris` normalizer at 200 requested cases:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-if-value --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-if-value-copydrop-normalized-200-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
# compared 200/200; normalized 0; cleanup-normalized 200; raw mismatches 0; validation/generator/property/command failures 0
# cache: wasm-smith 0 hits/0 misses; Binaryen 200 hits/0 misses; Binaryen failures 0 hits/0 misses
```

## Next work

Before adding `code-pushing-br-if-value` to `code-pushing-all`, run a larger targeted lane, preferably `1000` requested cases with the same normalizer. If green, add the leaf to the aggregate with red-first GenValid aggregate tests and rerun a bounded aggregate smoke.
