---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-untee-primary-sources.md
  - ../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md
  - ../../../raw/research/0279-2026-04-23-untee-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0523-2026-05-06-untee-direct-revalidation.md
  - ../../../../../src/passes/untee.mbt
  - ../../../../../src/passes/untee_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../code-pushing/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flattening-code-pushing-and-tee-boundaries.md
  - ./wat-shapes.md
  - ../code-pushing/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
---

# Starshine strategy for `untee`

## Current Starshine status

`untee` is now an active explicit Starshine module pass.
The pass owner is [`src/passes/untee.mbt`](../../../../../src/passes/untee.mbt), with focused fixtures in [`src/passes/untee_test.mbt`](../../../../../src/passes/untee_test.mbt).
It is still **not** part of the current no-DWARF default `optimize` / `shrink` preset; it is available as a direct pass only.

## Implemented behavior

The first Starshine implementation follows the source-backed Binaryen contract for the stable WAT-level families:

- rewrite every reachable `local.tee` into `local.set` followed by `local.get` for the same local index
- recurse through `block`, `loop`, `if`, and `try_table` bodies
- expand nested tee chains inside out by scanning the already-rewritten flat instruction stream
- delete a tee whose direct flat input is `unreachable`, leaving the unreachable producer in place
- preserve ordinary `local.set` / `local.get` operations and avoid broader locals cleanup

This is intentionally a small raw module pass rather than a hidden mode of `simplify-locals`.
That keeps `untee` separate from `simplify-locals-notee`, whose contract is broader and only forbids creating new tees.

## Local wiring

The active surfaces are:

- registry entry: [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `untee` is a `ModulePass`, not a removed pass
- dispatcher arm: [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - direct pipeline requests call `untee_run_module_pass`
- CLI adapter coverage: [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
  - `--untee` is accepted as an active command pass and produces validated output
- compare harness support: [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
  - `--pass untee` / `--untee` is accepted for Binaryen oracle comparison
- public API snapshot: [`src/passes/pkg.generated.mbti`](../../../../../src/passes/pkg.generated.mbti)
  - exposes `untee_summary` and `untee_run_module_pass`

## Validation evidence

2026-05-06 refreshed direct-pass evidence after the pass-audit harness changes:

- `moon info` passed with existing repo warnings.
- `moon fmt` passed.
- `moon test` passed `2800/2800`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass untee --out-dir .tmp/pass-fuzz-untee` reached `6759/10000` compared cases with `6759` normalized matches, `0` mismatches / validation failures / generator failures, and `20` Binaryen empty-recursion-group parser/canonicalization command failures.

Earlier 2026-04-26 direct-pass evidence:

- `moon info` passed with existing repo warnings.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file untee_test.mbt` passed `4/4`.
- `moon test --package jtenner/starshine/passes --file registry_test.mbt` passed `5/5`.
- `moon test --target native --package jtenner/starshine/cmd --file cmd_wbtest.mbt --filter 'run_cmd_with_adapter accepts untee as an active module pass'` passed `1/1`.
- `moon test src/passes` passed `687/687` after the neighboring `optimize-instructions` i64 compare-form regression was fixed.
- `moon test src/cmd` passed `127/127`.
- Full `moon test` passed `2696/2696`.
- `bun scripts/pass-fuzz-compare.ts --pass untee --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-untee-genvalid-10000-staged` passed with `10000/10000` compared cases, `10000` normalized matches, and `0` mismatches / validation failures / generator failures / command failures.
- Mixed-generator oracle evidence: `.tmp/pass-fuzz-untee-keepgoing-staged` reached `9975/10000` comparable cases with `9975` normalized matches, `0` mismatches, and `25` Binaryen-side command failures (`binaryen-rec-group-zero`, `binaryen-bad-section-size`, `binaryen-table-index-out-of-range`, `binaryen-invalid-tag-index`).
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --untee` wrote `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-866306`, with `Normalized WAT equal: yes` and `Canonical function compare equal: yes`.

## Validation ladder

Future direct-pass validation should remain isolated from default preset work:

1. `moon test src/passes`
2. `moon test src/cmd` if CLI or registry behavior changes further
3. `moon info`
4. `moon fmt`
5. `moon test`
6. `moon build --target native --release src/cmd`
7. `bun scripts/pass-fuzz-compare.ts --pass untee --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-untee-genvalid-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
8. `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass untee --out-dir .tmp/pass-fuzz-untee --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
9. `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --untee`

If any compare mismatch appears, classify it separately as:

- real `untee` semantic/output mismatch
- Binaryen parser/canonicalization limitation
- Starshine decode/validation issue
- unsupported unreachable-shape gap beyond the direct flat `unreachable; local.tee` case

## Preset policy

Do not add `untee` to `optimize` or `shrink` without a separate preset-order proof.
The current no-DWARF path does not require it, and Binaryen treats it as an explicit optional pass rather than a default slot for this repo's active artifact path.

## Remaining risks

- The implemented unreachable fast path covers direct flat `unreachable; local.tee` syntax. More complex Binaryen tree-level unreachable values may need reduced repros before broadening the deletion rule.
- The pass is raw-WAT shaped, so future HOT-local integrations should preserve the same exact direct-pass oracle before changing the landing zone.
- Runtime should be trivial on normal modules, but large artifact timings should still be captured in the standard signoff report.
