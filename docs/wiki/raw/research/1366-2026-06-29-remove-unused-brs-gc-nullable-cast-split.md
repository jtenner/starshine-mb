# Remove-unused-brs GC nullable-cast split slice

Date: 2026-06-29

## Question

Can `[O4Z-AUDIT-RUB-Q]` safely shrink the broader GC `optimizeGC(...)` backlog by implementing Binaryen's `SuccessOnlyIfNonNull` `br_on_cast` rewrite for a narrow local HOT subset?

## Source evidence

Binaryen `version_130` `RemoveUnusedBrs.cpp` handles `BrOnCast` / `BrOnCastFail` inside `optimizeGC(...)` after computing the fallthrough ref type and evaluating the cast check with `GCTypeUtils::evaluateCastCheck(...)`. For the `SuccessOnlyIfNonNull` result, upstream rewrites a nullable-source / non-null-target `br_on_cast` into a `br_on_non_null` using the original branch target, followed by an appended `ref.null` in a result block. It keeps descriptor success cases conservative because type compatibility does not prove descriptor-value equality, and uses child localization / optional casts for broader fallthrough and descriptor/prefix cases.

Primary source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveUnusedBrs.cpp> (`optimizeGC(...)`, `Optimizer::visitBrOn(...)`, `GCTypeUtils::SuccessOnlyIfNonNull`).

## Local slice

Implemented only the locally provable no-payload subset:

- HOT root is `br_on_cast` or `drop(br_on_cast)` with exactly one ref child.
- The source ref type is nullable.
- The cast target type is non-null.
- The source ref type refined to non-null matches the target ref type under the local validator `Match` relation.
- There are no payload/prefix children, descriptor operands, inserted casts, or localizing side-effectful siblings.

The replacement builds a result block containing:

1. `br_on_non_null` to the original branch target using the original ref child.
2. `ref.null` for the nullable target heap type.

When the original HOT root was `drop(br_on_cast)`, the replacement wraps the split block in a `drop` so the surrounding stack contract is unchanged.

## Tests

Updated the former fail-closed nullable split test into the red-first positive:

- `remove-unused-brs splits nullable br_on_cast success-only-if-non-null`

Red-first result before implementation:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
failed 185/186; the fixture still contained br_on_cast instead of br_on_non_null/ref.null
```

Post-implementation focused result:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
passed 186/186
```

The existing GC boundaries remain active:

- `remove-unused-brs fail-closed keeps br_on payload children`
- `remove-unused-brs keeps unknown br_on_cast checks`

## Validation

Commands run after implementation and docs updates:

- `moon fmt` passed.
- `moon info` passed with six pre-existing warnings: unused `decode_maybe_exact_heap_type`, unused `encode_exact_heap_type`, unreachable code in `hot_verify.mbt`, unused derived `Eq` / `Debug` implementations in `gen_valid.mbt`, and unused `gen_valid_ssa_instr_is_forbidden_control`.
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed: `186/186`, then `3592/3592`.
- `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-gc-cast-split-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed. Result: requested `1000`, compared `1000`, `normalizedMatchCount=142`, `cleanupNormalizedMatchCount=858`, `mismatchCount=0`, `validationFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`, command failure classes `{}`, cache `binaryenHits=1000`, `binaryenMisses=0`, wasm-smith hits/misses `0/0`.
- Final focused check `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && git diff --check` passed: `186/186`, and no diff-check output.

## Remaining GC boundaries

Still open under `[O4Z-AUDIT-RUB-Q]`:

- payload/prefix-child BrOn forms that need Binaryen-like `ChildLocalizer` proof
- descriptor `br_on_cast_desc_eq*` forms not represented by local `Instruction` / `HotOp`
- broader fallthrough-type / local.tee cast insertion
- unreachable-input dropped-child construction

Reopen the payload/prefix branch only with source-backed child-localization tests that prove evaluation order and branch payload arity are preserved.
