# Remove-unused-brs GC disjoint-cast slice

Date: 2026-06-29

## Question

Can `[O4Z-AUDIT-RUB-Q]` safely shrink the remaining GC `optimizeGC(...)` backlog beyond the earlier no-payload nullable-source/non-null-target split?

## Source evidence

Binaryen `version_130` `RemoveUnusedBrs.cpp` runs `optimizeGC(...)` as a postwalk over `BrOn` nodes. For `br_on_cast*`, it computes the fallthrough ref type with `Properties::getFallthroughType(...)`, optionally refines `castType`, calls `GCTypeUtils::evaluateCastCheck(...)`, flips the result for `br_on_cast_fail`, and then handles these outcomes:

- `Success`: replace with a direct branch carrying the ref value.
- `Failure`: replace with the fallthrough ref value.
- `SuccessOnlyIfNonNull`: for `br_on_cast`, rewrite to `br_on_non_null` plus appended `ref.null`.
- `SuccessOnlyIfNull`: explicitly remains a TODO in `version_130`.
- `Unreachable`: replace with dropped children plus `unreachable`.

Descriptor `BrOnCastDescEq*` success cases remain conservative because type compatibility is not enough to prove descriptor equality. Broader cases use `ChildLocalizer`, optional cast insertion, and dropped-child construction to preserve evaluation order and type validity.

Primary source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveUnusedBrs.cpp> (`optimizeGC(...)`, `Optimizer::visitBrOn(...)`, `GCTypeUtils::evaluateCastCheck(...)`). Lit evidence remains in `remove-unused-brs-gc.wast`, `remove-unused-brs-desc.wast`, and `remove-unused-brs-exact*.wast`.

## Local slice

Implemented one additional locally provable no-payload subset:

- HOT root is `br_on_cast`, `drop(br_on_cast)`, or `br_on_cast_fail` with exactly one ref child.
- The source child is statically non-null.
- The child and cast target have disjoint abstract heap families that the local proof can classify without module-subtype or descriptor reasoning, currently covering i31/struct/array and func/extern/exn family disjointness.
- There are no payload/prefix children, descriptor operands, localizing side-effectful siblings, inserted casts, or unreachable-input child construction.

The replacement mirrors Binaryen's `Failure` / flipped-`Success` outcomes:

- definitely failing `br_on_cast` becomes the fallthrough ref value, or a `drop(ref)` when the original cast sat under a `drop` shell;
- definitely failing `br_on_cast_fail` becomes a direct `br` carrying the original ref.

## Tests

Added red-first positives:

- `remove-unused-brs removes definitely failing non-null br_on_cast`
- `remove-unused-brs rewrites definitely failing non-null br_on_cast_fail to branch`

Added source-backed boundary coverage:

- `remove-unused-brs boundary keeps nullable disjoint br_on_cast checks`

The boundary keeps the nullable disjoint `SuccessOnlyIfNull` case closed because Binaryen `version_130` itself leaves that outcome as a TODO, and the local implementation should not invent a divergent transform there without a new source-backed design.

Initial red-first focused run before implementation:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
failed 193/195: the two new definite-failure positives still contained br_on_cast / br_on_cast_fail
```

## Validation

Commands run after implementation and docs updates:

- `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes && moon info` passed. Results: fmt finished; focused RUB tests passed `195/195`; `moon test src/passes` passed `3601/3601`; `moon info` passed with six pre-existing warnings (`decode_maybe_exact_heap_type`, `encode_exact_heap_type`, an unreachable `hot_verify.mbt` block, unused derived `Eq` / `Debug` in `gen_valid.mbt`, and unused `gen_valid_ssa_instr_is_forbidden_control`).
- `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-gc-disjoint-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed. Result: requested `1000`, compared `1000`, `normalizedMatchCount=142`, `cleanupNormalizedMatchCount=858` (reported by the harness as compare-normalized matches), `mismatchCount=0`, `validationFailureCount=0`, `generatorFailureCount=0`, `propertyFailureCount=0`, `commandFailureCount=0`, command failure classes `{}`, cache `binaryenHits=1000`, `binaryenMisses=0`, wasm-smith hits/misses `0/0`.
- `git diff --check` passed with no output.

Pass-local timing was not reported by this compare lane.

## Remaining GC boundaries

Still open under `[O4Z-AUDIT-RUB-Q]`:

- payload/prefix-child BrOn forms that need Binaryen-like `ChildLocalizer` proof;
- descriptor `br_on_cast_desc_eq*` forms, which are absent from local `Instruction` / `HotOp` and require descriptor-value reasoning;
- broader fallthrough-type / local.tee cast insertion;
- unreachable-input dropped-child construction;
- nullable disjoint `SuccessOnlyIfNull`, which is a Binaryen `version_130` TODO rather than a Starshine implementation gap for this release oracle.

Reopen the new disjoint-cast subset only for a semantic mismatch, a Starshine validation failure, new Binaryen source that changes `SuccessOnlyIfNull`, or local type/descriptor infrastructure that can prove additional disjoint/fallthrough cases while preserving evaluation order and branch payload arity.
