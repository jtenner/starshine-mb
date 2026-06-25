---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0729-2026-06-19-optimize-instructions-oi-d-default-scalars.md
  - ../../../raw/research/0730-2026-06-19-optimize-instructions-oi-e-sign-ext-facts.md
  - ../../../raw/research/0731-2026-06-19-optimize-instructions-oi-f-boolean-select-shells.md
  - ../../../raw/research/0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md
  - ../../../raw/research/0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md
  - ../../../raw/research/0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md
  - ../../../raw/research/0735-2026-06-19-optimize-instructions-oi-g-local-fill.md
  - ../../../raw/research/0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md
  - ../../../raw/research/0737-2026-06-19-optimize-instructions-oi-g-wider-memory-copy.md
  - ../../../raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md
  - ../../../raw/research/0739-2026-06-19-optimize-instructions-oi-g-memory64-copy.md
  - ../../../raw/research/0740-2026-06-19-optimize-instructions-oi-g-memory64-fill.md
  - ../../../raw/research/0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md
  - ../../../raw/research/0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md
  - ../../../raw/research/0743-2026-06-19-optimize-instructions-oi-g-const-memory-offset.md
  - ../../../raw/research/0744-2026-06-19-optimize-instructions-oi-g-memory64-const-offset.md
  - ../../../raw/research/0745-2026-06-19-optimize-instructions-oi-g-load-call-offset-boundary.md
  - ../../../raw/research/0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md
  - ../../../raw/research/0747-2026-06-19-optimize-instructions-oi-g-const-store-value.md
  - ../../../raw/research/0748-2026-06-19-optimize-instructions-oi-g-byte-fill-const-truncation.md
  - ../../../raw/research/0749-2026-06-19-optimize-instructions-oi-g-pointer-add-boundary.md
  - ../../../raw/research/0850-2026-06-25-optimize-instructions-oi-g-byte-fill-call-raw-gate.md
  - ../../../raw/research/0851-2026-06-25-optimize-instructions-oi-g-reinterpret-store-memargs.md
  - ../../../raw/research/0852-2026-06-25-optimize-instructions-oi-g-wrap-store-memargs.md
  - ../../../raw/research/0854-2026-06-25-optimize-instructions-oi-g-wrap-store-multiuse-boundary.md
  - ../../../raw/research/0856-2026-06-25-optimize-instructions-oi-g-nonconst-load-call-boundary.md
  - ../../../raw/research/0853-2026-06-25-optimize-instructions-oi-m-multiresult-selected-boundary.md
  - ../../../raw/research/0855-2026-06-25-optimize-instructions-oi-m-selected-second-lane-boundary.md
  - ../../../raw/research/0857-2026-06-25-optimize-instructions-oi-m-full-simplify-boundary.md
  - ../../../raw/research/0858-2026-06-25-optimize-instructions-oi-g-parameterized-memory-copy.md
  - ../../../raw/research/0859-2026-06-25-optimize-instructions-oi-m-tuple-optimization-boundary.md
  - ../../../raw/research/0860-2026-06-25-optimize-instructions-oi-g-mixed-parameterized-memory-copy.md
  - ../../../raw/research/0861-2026-06-25-optimize-instructions-oi-g-parameterized-byte-fill.md
  - ../../../raw/research/0862-2026-06-25-optimize-instructions-oi-g-multiparam-bulk-memory.md
  - ../../../raw/research/0863-2026-06-25-optimize-instructions-oi-m-earlier-later-neighbor.md
  - ../../../raw/research/0864-2026-06-25-optimize-instructions-oi-g-global-bulk-memory.md
  - ../../../raw/research/0865-2026-06-25-optimize-instructions-oi-m-trapping-sibling.md
  - ../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md
  - ../../../raw/research/0867-2026-06-25-optimize-instructions-oi-m-selected-trapping-lane.md
  - ../../../raw/research/0868-2026-06-25-optimize-instructions-oi-g-v128-zero-memory-fill.md
  - ../../../raw/research/0869-2026-06-25-optimize-instructions-oi-m-selected-trapping-effectful-sibling.md
  - ../../../raw/research/0870-2026-06-25-optimize-instructions-oi-g-v128-nonzero-memory-fill.md
  - ../../../raw/research/0871-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-sibling.md
  - ../../../raw/research/0872-2026-06-25-optimize-instructions-oi-g-zero-bulk-effects.md
  - ../../../raw/research/0873-2026-06-25-optimize-instructions-oi-m-selected-trapping-earlier-later-siblings.md
  - ../../../raw/research/0815-2026-06-20-optimize-instructions-oi-g-signext-store-boundary.md
  - ../../../raw/research/0816-2026-06-20-optimize-instructions-oi-g-effectful-memory-copy-boundary.md
  - ../../../raw/research/0750-2026-06-19-optimize-instructions-oi-h-ref-func-call-ref.md
  - ../../../raw/research/0751-2026-06-19-optimize-instructions-oi-h-table-get-call-ref.md
  - ../../../raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md
  - ../../../raw/research/0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md
  - ../../../raw/research/0754-2026-06-19-optimize-instructions-oi-h-fallthrough-call-ref.md
  - ../../../raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md
  - ../../../raw/research/0756-2026-06-20-optimize-instructions-oi-h-call-ref-boundaries.md
  - ../../../raw/research/0811-2026-06-20-optimize-instructions-oi-h-call-indexed-table-get-boundary.md
  - ../../../raw/research/0757-2026-06-20-optimize-instructions-oi-i-ref-null-basics.md
  - ../../../raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md
  - ../../../raw/research/0759-2026-06-20-optimize-instructions-oi-i-known-non-null.md
  - ../../../raw/research/0760-2026-06-20-optimize-instructions-oi-i-ref-as-func.md
  - ../../../raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md
  - ../../../raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md
  - ../../../raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md
  - ../../../raw/research/0764-2026-06-20-optimize-instructions-oi-i-ref-func-test-cast.md
  - ../../../raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md
  - ../../../raw/research/0766-2026-06-20-optimize-instructions-oi-i-non-null-local-refs.md
  - ../../../raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md
  - ../../../raw/research/0768-2026-06-20-optimize-instructions-oi-i-non-null-local-i31-supertype-test-cast.md
  - ../../../raw/research/0769-2026-06-20-optimize-instructions-oi-i-null-nonnull-test-cast-surface.md
  - ../../../raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md
  - ../../../raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md
  - ../../../raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md
  - ../../../raw/research/0773-2026-06-20-optimize-instructions-oi-i-struct-array-supertype-test-cast.md
  - ../../../raw/research/0774-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-test-cast.md
  - ../../../raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md
  - ../../../raw/research/0776-2026-06-20-optimize-instructions-oi-i-same-local-i31-ref-eq.md
  - ../../../raw/research/0777-2026-06-20-optimize-instructions-oi-i-noop-cast-ref-eq.md
  - ../../../raw/research/0778-2026-06-20-optimize-instructions-oi-i-as-non-null-ref-eq.md
  - ../../../raw/research/0779-2026-06-20-optimize-instructions-oi-i-double-noop-cast-ref-eq.md
  - ../../../raw/research/0780-2026-06-20-optimize-instructions-oi-i-upcast-ref-eq.md
  - ../../../raw/research/0781-2026-06-20-optimize-instructions-oi-i-i31-upcast-ref-eq.md
  - ../../../raw/research/0782-2026-06-20-optimize-instructions-oi-i-nullable-target-miss-test-cast.md
  - ../../../raw/research/0783-2026-06-20-optimize-instructions-oi-i-nullable-target-success-test-cast.md
  - ../../../raw/research/0784-2026-06-20-optimize-instructions-oi-i-nullable-source-non-null-target-miss-test-cast.md
  - ../../../raw/research/0785-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-success-test-cast.md
  - ../../../raw/research/0786-2026-06-20-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast.md
  - ../../../raw/research/0787-2026-06-20-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast.md
  - ../../../raw/research/0788-2026-06-20-optimize-instructions-oi-i-effectful-ref-eq-null.md
  - ../../../raw/research/0789-2026-06-20-optimize-instructions-oi-i-effectful-ref-is-null.md
  - ../../../raw/research/0790-2026-06-20-optimize-instructions-oi-i-effectful-ref-test-success.md
  - ../../../raw/research/0791-2026-06-20-optimize-instructions-oi-i-effectful-impossible-ref-eq.md
  - ../../../raw/research/0792-2026-06-20-optimize-instructions-oi-i-effectful-ref-as-non-null.md
  - ../../../raw/research/0793-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null.md
  - ../../../raw/research/0794-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-test-cast.md
  - ../../../raw/research/0795-2026-06-20-optimize-instructions-oi-i-effectful-known-null-ref-eq.md
  - ../../../raw/research/0796-2026-06-20-optimize-instructions-oi-i-effectful-self-ref-eq.md
  - ../../../raw/research/0797-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-i31.md
  - ../../../raw/research/0798-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-as-non-null.md
  - ../../../raw/research/0799-2026-06-20-optimize-instructions-oi-i-effectful-same-local-ref-cast.md
  - ../../../raw/research/0800-2026-06-20-optimize-instructions-oi-i-effectful-nullable-source-nullable-target.md
  - ../../../raw/research/0801-2026-06-20-optimize-instructions-oi-i-effectful-nullable-source-non-null-target.md
  - ../../../raw/research/0802-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-nullable-target.md
  - ../../../raw/research/0803-2026-06-20-optimize-instructions-oi-i-effectful-ref-func-basics.md
  - ../../../raw/research/0804-2026-06-20-optimize-instructions-oi-i-effectful-nullable-i31-supertype.md
  - ../../../raw/research/0805-2026-06-20-optimize-instructions-oi-i-effectful-struct-array-ref-eq.md
  - ../../../raw/research/0806-2026-06-20-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq.md
  - ../../../raw/research/0807-2026-06-20-optimize-instructions-oi-i-effectful-non-null-source-non-null-target.md
  - ../../../raw/research/0808-2026-06-20-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null.md
  - ../../../raw/research/0809-2026-06-20-optimize-instructions-oi-i-nullable-i31-nonnull-target.md
  - ../../../raw/research/0810-2026-06-20-optimize-instructions-oi-i-known-null-nonnull-target.md
  - ../../../raw/research/0812-2026-06-20-optimize-instructions-oi-i-i31-array-local-ref-eq.md
  - ../../../raw/research/0813-2026-06-20-optimize-instructions-oi-i-same-heap-nonnull-ref-cast.md
  - ../../../raw/research/0814-2026-06-20-optimize-instructions-oi-i-indexed-i31-aggregate-ref-eq.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Current Starshine `optimize-instructions` HOT code map

This page is the exact MoonBit helper/code-map companion to [`./starshine-strategy.md`](./starshine-strategy.md).
It describes the **current local implementation**, not upstream Binaryen's AST pass.
For the upstream contract, start with [`./binaryen-strategy.md`](./binaryen-strategy.md).

## Short version

Current Starshine `src/passes/optimize_instructions.mbt` is **much narrower** than Binaryen `OptimizeInstructions.cpp`. The 2026-06-19 `version_130` matrix is now the release-gating owner map for the missing visitor and lit families.

The in-tree implementation is still a real, useful hot pass.
Its center of gravity is:

- exact integer binary constant folding, including add and sub
- non-constant `eqz` / compare-to-zero rewrites, same-local integer compare and binary operand folding, pure and effect-preserving i32/i64 masked unsigned-compare folds plus first recursive pure/effect-preserving i32/i64 `shr_u`/`and` bounded unsigned-compare folds, and relational constant plus guarded operand canonicalization
- commutative operand ordering with HOT use-def safety guards
- add/sub/mul/shift rewrites, scalar float spelling rewrites, and `i32.wrap_i64` constant folding
- first local scanner-style sign-extension facts, redundant sign-extension removal, and shift-pair sign-extension idiom rewrites
- constant-`if` folding
- nested boolean-`if` normalization and `eqz` wrapping
- constant-condition `select` cleanup when the dropped arm is side-effect-free
- tiny `memory.copy` lowering for constant sizes `1`/`2`/`4`/`8`/`16`, including the size-16 `v128.load` / `v128.store` shape, direct-core memory64 copy fixtures for `i64` address preservation, and flat stack-carried raw-gate escapes whose address operands may independently be local/constant/global operands, no-param direct-call operands, or direct calls with pure local/constant/global arguments, preserving destination-before-source evaluation order; mixed flat tiny-copy/byte-fill functions are admitted by the same tiny bulk-memory gate
- constant/local-value `memory.fill` lowering for selected sizes (`1`, constant `2`/`4`/`8`, constant size-16 repeated-byte fill via `v128.const` + `v128.store`, and local.get `2`/`4`/`8`), including size-1 constant low-byte canonicalization, a flat stack-carried byte-fill raw-gate escape for local/global/no-param-call values and direct-call destination/value forms with pure local/constant/global arguments, and direct-core memory64 fill fixtures after the local typechecker length fix
- stored-value/load-result cleanup for redundant masks in either `and` operand order plus constant stored-value truncation before `i32.store8` / `i32.store16` and, as documented, `i64.store8` / `i64.store16` / `i64.store32`, direct `i32.wrap_i64` i32-store widening with source memargs preserved, direct reinterpret-store representation rewrites (`f32.store(f32.reinterpret_i32 x)` -> `i32.store x`, etc.) with source memargs preserved, direct one-use full-width reinterpret-load result rewrites (`f32.reinterpret_i32(i32.load p)` -> `f32.load p`, etc.), and one-use i32-load plus `i64.extend_i32_*` rewrites to matching i64 loads (`i64.load32_*`, `i64.load8_*`, `i64.load16_*`) where the loaded value semantics are identical; representation-load rewrites preserve the original load memarg offset and alignment, while local-carried/shared load-result, reinterpret-store, and `i32.wrap_i64` store-value spellings are now documented keep-spelling boundaries
- constant-pointer static-offset folding for scalar loads/stores: memory32 uses Binaryen's nonnegative `i32` range guard and memory64 uses Binaryen's unsigned `u64` no-wrap guard; the public/raw pipeline now admits the narrow `i32.const; nonzero-offset scalar load; drop; call` load/call shape so direct OI can fold Binaryen's observed call-followed offset case
- an explicit nonconstant pointer-add offset boundary: Binaryen `version_130` `optimize-instructions` keeps tested `local.get + const` memory addresses as arithmetic plus the original static offset, so Starshine does not claim that shape as OI-owned load/store canonicalization
- an explicit sign-extension-before-narrow-store boundary: Binaryen `version_130` canonicalizes shift-pair sign extensions to extension opcodes before narrow stores but keeps those extension opcodes, so Starshine also keeps `i32.extend8_s` / `i32.extend16_s` / `i64.extend16_s` before matching narrow stores instead of claiming a stored-value cleanup gap
- a narrowed stack-carried call raw boundary: the public/raw pipeline now admits the simple no-param direct-call plus pure `local.get`/constant commutative integer binop form so `local.get + call` can reach HOT and canonicalize to call-first spelling, admits flat tiny bulk-memory forms whose operands independently use no-param direct calls, pure local/constant/global operands, or direct calls with pure local/constant/global arguments so the existing HOT tiny-copy/byte-fill lowerings can match Binaryen's effectful-call shapes, and no longer rejects a straight-line function merely because it mixes tiny `memory.copy` with byte `memory.fill`. The `global.get` extension is deliberately bulk-memory-specific and not part of the commutative binop gate because calls may mutate globals. Broader stack-carried effect/control/localizing cases remain blocked.
- a narrowed public-pipeline `load-call-optimize-instructions-noop` boundary: the exact constant-address/nonzero-offset scalar-load/drop/direct-call fixture now escapes and folds the offset, while nonconstant-pointer load/drop/call fixtures are source-backed keep-spelling boundaries and broader mixed plain-load plus call functions still skip the pass
- direct `ref.func` target directization for `call_ref` / `return_call_ref`, constant-index and call-indexed `table.get` target lowering to `call_indirect` / `return_call_indirect` with the table index call preserved, zero-argument select-of-direct-`ref.func` lowering to an `if` with direct `call` / `return_call` arms, argument-bearing select-of-direct-`ref.func` lowering that localizes single-result call arguments before the direct-call `if`, fallthrough-known block target directization with the target expression dropped for effects and localized single-result arguments reloaded for the direct call, and fail-closed boundary tests for mixed select arms plus multi-result argument select-of-`ref.func` shapes
- first null-reference basics from OI-I: `ref.is_null(ref.null)` folds to `i32.const 1`, `ref.eq(x, null)` and `ref.eq(null, x)` rewrite through `ref.is_null(x)`, and `ref.eq(null, null)` folds to `i32.const 1`
- known-non-null and literal/disjoint equality basics from OI-I: `ref.is_null(ref.i31)`, `ref.is_null(ref.func)`, and `ref.is_null(local.get)` for declared non-null reference locals fold to `i32.const 0`, preserving an effectful immediate `ref.i31` operand as `drop(operand)` or an already-evaluated prefix such as `drop(call $effect)` before the folded `i32.const 0`; `ref.eq(ref.i31, null)` / `ref.eq(null, ref.i31)` and null equality against declared non-null local refs fold to `i32.const 0`, preserving an effectful immediate `ref.i31` operand as `drop(operand)` before the folded `i32.const 0`; known-null equality folds also preserve already-evaluated effectful prefixes such as `drop(call $effect)` before known-null/known-null `i32.const 1` or known-null/known-non-null `i32.const 0`; same-local equality folds likewise preserve already-evaluated prefixes before the folded `i32.const 1`; `ref.eq` between immediate `ref.i31(i32.const)` operands folds to `i32.const 1` for equal payloads or `i32.const 0` for unequal payloads; `ref.eq(ref.i31(local.get N), ref.i31(local.get N))` folds to `i32.const 1` while preserving already-evaluated effectful prefixes; same-local `ref.eq` also folds through immediate nullable no-op `ref.cast` operands, including the both-operands cast variant, when each cast target heap exactly matches the local declaration, and through immediate nullable absolute-heap upcast `ref.cast` operands for the existing absolute `struct` / `array` supertype helper plus the absolute `i31` supertype helper, preserving already-evaluated effectful prefixes such as `drop(call $effect)` before the folded `i32.const 1`; it folds through immediate nullable-local `ref.as_non_null(local.get N)` by preserving one trapped non-null check before `i32.const 1`, including already-evaluated effectful prefixes such as `drop(call $effect)`; `ref.eq` between a definitely non-null `i31` value and a local whose declared heap cannot be `i31` folds to `i32.const 0`, preserving represented effectful immediate `ref.i31` operands as `drop(operand)` before the folded result and preserving already-evaluated effectful prefixes such as `drop(call $effect)` before local `i31`/struct and local `i31`/array equality misses, including indexed/defined struct and array local heap surfaces; and `ref.eq` between absolute local `struct` / `array` heaps folds to `i32.const 0` when at least one operand is declared non-null, preserving already-evaluated effectful prefixes such as `drop(call $effect)` before the folded miss; the validator now accepts non-null `ref.is_null` operands so those fixtures can be authored through WAT
- first `ref.as_non_null` basics from OI-I: `ref.as_non_null(ref.null)` rewrites to `unreachable` while preserving already-evaluated effectful prefixes such as `drop(call $effect)`, `ref.as_non_null(ref.i31(x))` rewrites to `ref.i31(x)` while preserving effectful payloads such as `ref.i31(call $effect)`, `ref.as_non_null(ref.func f)` rewrites to `ref.func f` while preserving already-evaluated effectful prefixes, `ref.as_non_null(local.get)` rewrites to the original `local.get` for declared non-null reference locals, and exact `ref.cast(unreachable)` collapses to `unreachable` so stacked cast shapes lower validly
- first null-operand `ref.test` / `ref.cast` basics from OI-I: nullable `ref.test (ref null T)` fed by `ref.null` folds to `i32.const 1`, nullable `ref.cast` fed by `ref.null` rewrites to the null child, non-null `ref.test (ref T)` fed by `ref.null` folds to `i32.const 0`, and non-null `ref.cast (ref T)` fed by `ref.null` rewrites to `unreachable`; already-evaluated effectful prefixes such as `drop(call $effect)` are preserved before known-null non-null-target `ref.test` / `ref.cast` folds
- successful and failed local-i31 `ref.test` / `ref.cast` basics from OI-I: `ref.test` fed by a local `ref.i31` constructor folds to `i32.const 1` for absolute targets `i31`, `eq`, and `any`, and matching `ref.cast` targets rewrite to the constructor child; known-miss immediate `ref.i31` tests against `struct`, `array`, or indexed heap targets fold to `i32.const 0`, and matching casts rewrite to `unreachable` after the validator accepts disjoint `eq`-hierarchy sibling heap types; nullable `(ref null i31)` locals tested or cast against non-null aggregate targets also fold to `i32.const 0` / `unreachable` because null misses non-null targets and non-null `i31` values cannot be aggregates; effectful immediate-`ref.i31` operands are preserved as a `drop` before the folded result or trap, and already-evaluated effectful prefixes are preserved before nullable-local non-null-target misses
- successful local-`ref.func` `ref.test` / `ref.cast` basics from OI-I: exact `ref.test (ref func)` fed by local `ref.func` folds to `i32.const 1`, and exact `ref.cast (ref func)` fed by local `ref.func` rewrites to the constructor child; already-evaluated effectful prefixes such as `drop(call $effect)` are preserved before exact `ref.func` `ref.test`, `ref.cast`, `ref.is_null`, and `ref.as_non_null` simplifications; target-supertypes and arbitrary function-subtype facts remain open
- declared non-null local `ref.test` / `ref.cast` basics from OI-I: `ref.test (ref T)` fed by a `local.get` whose declared type is non-null `(ref T)` folds to `i32.const 1`, and exact `ref.cast (ref T)` fed by that local rewrites to the local child; additionally, declared non-null `(ref i31)` locals and declared non-null absolute `struct` / `array` locals fold successful `ref.test` / `ref.cast` for absolute target supertypes `eq` and `any`, including nullable-target successful casts/tests for non-null absolute aggregate locals because the operand cannot be null; declared non-null absolute `struct` / `array` locals also fold failed `ref.test` / `ref.cast` against the other absolute aggregate sibling to `i32.const 0` / `unreachable`, including nullable-target sibling casts/tests because the non-null operand cannot be null and preserving already-evaluated effectful prefixes such as `drop(call $effect)` before nullable-target success and sibling-miss results; the same already-evaluated effectful prefixes are preserved before non-null-target success and sibling-miss results for non-null absolute aggregate sources; nullable local absolute `struct` / `array` sources also fold non-null-target sibling `ref.test` / `ref.cast` to `i32.const 0` / `unreachable` because both null and the opposite aggregate sibling miss a non-null target; nullable local sources whose declared heap is accepted by the existing absolute `i31` or absolute aggregate supertype helper fold nullable-target successful `ref.test` / `ref.cast` to `i32.const 1` / the original local because null also matches a nullable target, preserving already-evaluated effectful prefixes such as `drop(call $effect)`; exact same-heap nullable-source non-null-target `ref.cast` lowers to `ref.as_non_null`, preserving the operand effect and null trap while keeping narrowing heap-checking casts as `ref.cast`; broader subtype, indexed-type, flow-sensitive, descriptor, exactness, TNH, and IIT facts remain open
- duplicate-branch collapse in then-regions
- `tuple.extract(tuple.make(...))` forwarding for one-use tuples: pure non-selected siblings are omitted, selected trapping lanes remain evaluated as the returned value, selected trapping lanes with an earlier effectful sibling preserve the effect before the exact selected load, selected trapping lanes with a later effectful sibling are stored before the sibling call and reloaded after it, and the covered single-result effectful-sibling case preserves earlier sibling effects, preserves trapping load siblings as dropped effects, localizes the selected lane when later effects exist, drops later sibling effects, reloads the selected value, and remains explicit through focused `simplify-locals-nostructure` neighbor replays for both the first later-effect subset and an earlier+later effectful-sibling direct-HOT subset; full `simplify-locals` and dedicated `tuple-optimization` on the public multivalue-block probe remain boundaries where Binaryen uses tuple scratch but Starshine keeps the block/drop spelling, and direct-HOT replay of the full-neighbor shape currently hits `InvalidChildRef`; multi-result selected lanes and multi-result non-selected siblings are explicit tuple-scratch localization boundaries
- dead-region-suffix cleanup with explicit fallback-branch and zero-sentinel preservation

That is a meaningful implemented pass.
But it is not yet the same surface as upstream Binaryen.

## Exact local code map

### Registry and preset placement

The public registry surface lives in `src/passes/optimize.mbt`:

- `optimize_instructions_descriptor()` declares the active HOT descriptor
- `optimize_instructions_summary()` provides the public help text
- `pass_registry_entries()` registers `optimize-instructions` as a hot pass
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` place it in both the early and late cleanup slots of the default preset order

That file is the local answer to:

- is the pass active?
- how is it described publicly?
- where does it sit in the preset order?

### Pass-manager dispatch

The main pipeline handoff lives in `src/passes/pass_manager.mbt`:

- `run_hot_pipeline_run_descriptor(...)` dispatches the descriptor name `optimize-instructions` into `optimize_instructions_run(...)`

The O4z/raw pipeline also has explicit pre-lift skip gates for currently expensive or representation-sensitive shapes. The 2026-06-19 OI-C audit made those gates trace-accountable for large local-heavy functions, lowered instruction-count blowups, stack-carried effect barriers, load/call mixes, call/local-write mixes, and structured call/branch meshes. The 2026-06-24/2026-06-25 raw-gate narrowing admits the exact straight-line `pure local.get/const; no-param direct call; commutative integer binop` subset, flat tiny `memory.copy` sequences with no-param direct-call/local/constant operands plus the exact one-pure-argument direct-call address subset, and flat byte `memory.fill` sequences with the same local/constant/no-param-call operand proof through the stack-carried-effect gate; it also admits the exact `i32.const; nonzero-offset scalar load; drop; call` load/call offset-fold shape. Broader stack-carried effects and broader load/call mixes remain skipped.

That means there are two local execution layers to keep distinct:

- ordinary direct pass behavior happens after HOT lift in `src/passes/optimize_instructions.mbt`
- O4z/raw safeguards in `src/passes/pass_manager.mbt` remain release performance/representation boundaries until later behavior slices narrow them

### Core algorithm owner file

The main implementation lives in `src/passes/optimize_instructions.mbt`.
The fastest read-along path is:

- descriptor and summary
  - `optimize_instructions_descriptor()`
  - `optimize_instructions_summary()`
- HOT-specific traversal scaffolding
  - `OptimizeInstructionsScratch::new(...)`
  - `optimize_instructions_mark_loop_input_nodes(...)`
  - `optimize_instructions_scan_sign_ext_facts(...)`
  - `optimize_instructions_can_cross_local_get(...)`
- constant and control cleanup helpers
  - `optimize_instructions_try_fold_constant_if_condition(...)`
  - `optimize_instructions_try_optimize_if_condition(...)`
  - `optimize_instructions_negate_boolean_expr_recursive(...)`
  - `optimize_instructions_try_wrap_boolean_if_value_in_eqz(...)`
  - `optimize_instructions_try_fold_const_select(...)`
  - `optimize_instructions_try_directize_ref_func_call_ref(...)`
  - `optimize_instructions_ref_is_known_non_null(...)`
  - `optimize_instructions_try_fold_ref_is_null(...)`
  - `optimize_instructions_try_fold_ref_as_non_null(...)`
  - `optimize_instructions_try_fold_ref_test_null(...)`
  - `optimize_instructions_try_fold_ref_cast_null(...)`
  - `optimize_instructions_try_replace_ref_cast_unreachable_operand(...)`
  - `optimize_instructions_try_rewrite_ref_eq_null(...)`
  - `optimize_instructions_replace_with_store_exact(...)`
  - `optimize_instructions_repeated_fill_i32(...)`
  - `optimize_instructions_repeated_fill_i64(...)`
  - `optimize_instructions_repeated_fill_i32_for_local_get(...)`
  - `optimize_instructions_repeated_fill_i64_for_local_get(...)`
  - `optimize_instructions_try_expand_tiny_memory_copy(...)`
  - `optimize_instructions_try_expand_tiny_memory_fill(...)`
  - `optimize_instructions_memory_access_with_memarg(...)`
  - `optimize_instructions_try_fold_const_memory_access_offset(...)`
  - `optimize_instructions_store_value_is_i64(...)`
  - `optimize_instructions_try_truncate_narrow_store_const_value(...)`
  - `optimize_instructions_try_drop_narrow_store_value_mask(...)`
  - `optimize_instructions_try_rewrite_reinterpret_store_value(...)`
  - `optimize_instructions_try_rewrite_reinterpret_load_result(...)`
  - `optimize_instructions_try_collapse_duplicate_then_branch(...)`
  - `optimize_instructions_try_collapse_dead_region_suffix(...)`
- canonicalization helpers
  - `optimize_instructions_try_canonicalize_commutative(...)`
  - `optimize_instructions_try_canonicalize_relational_const(...)`
  - `optimize_instructions_try_canonicalize_relational_operands(...)`
  - `optimize_instructions_try_canonicalize_compare_const(...)`
- arithmetic and compare rewrites
  - `optimize_instructions_try_rewrite_add_sub(...)`
  - `optimize_instructions_try_rewrite_float_binary(...)`
  - `optimize_instructions_try_rewrite_mul_shift(...)`
  - `optimize_instructions_try_rewrite_shift(...)`
  - `optimize_instructions_try_remove_redundant_sign_ext(...)`
  - `optimize_instructions_try_rewrite_sign_ext_idiom(...)`
  - `optimize_instructions_try_rewrite_compare_eqz(...)`
- walker and driver
  - `optimize_instructions_visit_node(...)`
  - `optimize_instructions_run(...)`

That exact code map is the main practical improvement in this refresh: readers can now jump straight from the strategy summary to the owning MoonBit helper clusters.

### Focused local proof lanes

The local tests are intentionally split across multiple files:

- `src/passes/optimize_instructions_test.mbt`
  - focused reduced pass behavior: exact constant folding, Binaryen-aligned literal-constant `eqz` preservation, non-constant `eqz` and compare canonicalization, arithmetic rewrites, scalar float spelling, `i32.wrap_i64` constant folding, sign-extension fact and idiom rewrites, nested boolean-`if` cleanup, constant-condition `select` cleanup with effect/trap negatives, direct-core `ref.func` `call_ref` / `return_call_ref` directization, `table.get` `call_ref` / `return_call_ref` indirect-call lowering, zero-argument select-of-`ref.func` `call_ref` / `return_call_ref` if-lowering, argument-bearing select-of-`ref.func` call_ref localization coverage, fail-closed non-direct select-arm and argument-bearing fallthrough boundaries, fallthrough-known block target `call_ref` / `return_call_ref` directization, first `ref.is_null` / `ref.eq` null-reference rewrites plus known-non-null constructor folds, duplicate-branch collapse, dead-region-suffix trimming, commutative reordering, relational constant/operand normalization, and guard-heavy no-reorder cases
- `src/passes/registry_test.mbt`
  - registry/descriptors exposure for the public HOT pass surface
- `src/cmd/cmd_wbtest.mbt`
  - CLI-visible `--optimize-instructions` replay on the debug artifact and on the saved generated-artifact slot-16 / slot-44 predecessor lanes

A useful local honesty note is that there is no dedicated `perf_test.mbt` or `optimize_test.mbt` lane for this pass today.
The strongest evidence surface is the focused reduced pass file plus the CLI replay coverage.

## What Starshine already models reasonably well

## 1. Exact integer and compare peepholes

The local file has dedicated helpers for:

- exact constant folding of integer add/sub binary ops
- float spelling rewrites for sub-to-add-negative and divide-by-two to multiply-by-half
- `i32.wrap_i64` constant folding
- first sign-extension facts and idiom rewrites from `[O4Z-AUDIT-OI-E]`: signed-load/default-local/fallthrough-local facts, redundant sign-extension removal, and `shl` + `shr_s` sign-extension synthesis
- `eqz` rewrites such as subtraction/addition compare lowering while intentionally preserving literal-constant `eqz` nodes to match Binaryen's direct pass output
- compare-to-zero rewrites
- same-local integer compare folding, plus direct same-local integer binary folds for `sub`/`xor` to zero and `and`/`or` to the local value
- pure and effect-preserving i32/i64 masked unsigned-compare folding when an `and` with a nonnegative mask bounds the value below an out-of-range constant, plus first i32/i64 `shr_u` bounded unsigned-compare folds for constant shift amounts `1..31` / `1..63`, dropping evaluated masked/shifted values before the folded constant
- guarded relational operand canonicalization
- relational-constant normalization

This is the part of the implementation that most closely matches the popular mental model of the upstream pass.

## 2. Commutative canonicalization with HOT-specific safety proof

The local file has explicit machinery for:

- moving constants to the preferred side
- sorting local gets and some node kinds conservatively
- refusing reordering across same-local writes, shared tee payloads, trapping loads, and loop-carried inputs

That matches the *strategy* of upstream Binaryen — canonicalize first so later peepholes have fewer spellings to handle — but the proof substrate is very local-HOT-specific.

Note: the *general* commutative canonicalizer (`optimize_instructions_try_canonicalize_commutative`) is now live for ranked HOT value nodes, including `HotOp::Call`, `HotOp::CallIndirect`, and `HotOp::CallRef`, and is gated by the same `optimize_instructions_subtrees_can_swap` Binaryen-style reorder proof used by the leading `(0 - x) + y -> y - x` rewrite (see section 3). Calls rank before locals/constants to match Binaryen's call-first commutative spelling, but they still swap only when the proof finds no memory/table/global/local conflict and no may-trap-past-side-effect hazard. The public/raw layer now lets the simplest straight-line no-param direct-call plus pure local/constant commutative integer binop forms reach this HOT canonicalizer; broader stack-style call-operand fixtures can still be skipped earlier by `stack-carried-effect-optimize-instructions-noop` until the raw gate/localization layer is narrowed further.

## 3. Add / sub / mul / shift rewrites

The in-tree HOT pass includes helpers for:

- add/sub normalization
- multiply-by-power-of-two to shift rewrites
- redundant shift-mask removal
- effective-zero shift cleanup
- compare-to-zero reductions

Two add/sub/mul negation rewrites carry their own soundness contracts:

- the leading `(0 - x) + y -> y - x` and i64 twin reorder the two value
  computations, so both i32/i64 leading branches are gated by
  `optimize_instructions_can_swap_leading_operands`, which delegates to
  `optimize_instructions_subtrees_can_swap` (no RAW/WAR/WAW region conflict on
  locals/globals/memory/tables, no may-trap/throw operand past a side effect,
  no control-flow operands). The trailing `y + (0 - x) -> y - x` keeps operands
  in order and needs no guard.
- `-x * -y -> x * y` (`optimize_instructions_try_rewrite_mul_negation`, i32 and
  i64) strips both `(0 - x)` wrappers in place, so it needs no reorder proof
  and applies even for effectful factors such as `(0 - call) * (0 - y)`.

So Starshine already covers a meaningful subset of the classic arithmetic rewrite surface.

## 4. Boolean and nested-`if` cleanup

The local file goes fairly deep on HOT-IR boolean and control patterns.
It can:

- optimize `if` conditions directly
- fold constant conditions
- recursively negate nested boolean trees
- wrap certain boolean value-`if`s in `eqz`
- flip some nested conditions when the tree is unshared
- fold constant-condition `select`s only when the dropped arm is side-effect-free and any effectful chosen arm is uniquely used
- collapse duplicate then-branch `if`s into a direct branch

This is one area where the local code is more explicit than the upstream `visitIf()` teaching surface because several helpers exist mainly to preserve local HOT/writeback behavior.

## 5. Artifact-backed dead-suffix and fallback-branch cleanup

The current local pass includes logic for:

- truncating dead suffixes after escaping control
- preserving value-carrying fallback branches in mixed-label and nested-return shapes
- keeping explicit zero sentinels when the result carrier still flows to a `drop` or another value-preserving boundary

Those are not a direct copy of Binaryen `OptimizeInstructions.cpp`.
They are local HOT-IR and writeback-survival work shaped by this repo's artifact history.

## What upstream Binaryen does that Starshine still lacks

This is still the bigger story.

## 1. No broad AST reference / GC optimization surface yet

The local file now implements or explicitly covers the first fifty-seven OI-I reference basics: `ref.is_null(ref.null)` / `ref.eq` with null operands, known-non-null constructor folds for `ref.i31` / `ref.func` null tests and `ref.i31` null equality with effectful immediate-`ref.i31` null misses preserved as `drop(operand); i32.const 0`, declared non-null `local.get` folds for `ref.is_null`, null equality, and `ref.as_non_null`, `ref.as_non_null(ref.null)` with already-evaluated prefix effects preserved before `unreachable`, `ref.as_non_null(ref.i31(x))`, `ref.as_non_null(ref.func f)`, exact `ref.cast(unreachable)` validity repair, nullable and non-null null-operand `ref.test` / `ref.cast` cleanup with already-evaluated prefix effects preserved before known-null non-null-target folds, successful local-`ref.i31` `ref.test` / `ref.cast` folds for absolute `i31` / `eq` / `any` targets, failed local-`ref.i31` cast/test folds against `struct`, `array`, and indexed heap targets, successful local-`ref.func` `ref.test` / `ref.cast` folds for exact `func` targets, immediate literal-`i31` `ref.eq` folding, direct same-local `ref.eq(local.get N, local.get N)` folding, same-local `ref.eq(ref.i31(local.get N), ref.i31(local.get N))` folding, same-local nullable exact no-op and absolute-heap upcast `ref.cast(local.get N)` equality folding including absolute `struct` / `array` and `i31` supertype helpers, same-local nullable `ref.as_non_null(local.get N)` equality folding with one preserved trap, narrow impossible `ref.eq` folding between definitely non-null `i31` values and locals whose declared heap cannot be `i31` including the effect-prefix local `i31`/array subset, exact same-heap declared non-null local `ref.test` / `ref.cast` folds, declared non-null `(ref i31)` local `ref.test` / `ref.cast` folds for absolute `eq` / `any` target supertypes, declared non-null absolute `struct` / `array` local `ref.test` / `ref.cast` folds for absolute `eq` / `any` target supertypes including nullable-target success coverage, failed declared non-null absolute `struct` / `array` local `ref.test` / `ref.cast` folds against the other absolute aggregate sibling including nullable-target miss coverage, nullable local absolute `struct` / `array` source folds for non-null-target aggregate sibling misses, nullable `(ref null i31)` local folds for non-null aggregate target `ref.test` / `ref.cast` misses with already-evaluated effect-prefix preservation, nullable-source nullable-target success coverage for absolute aggregate and `i31` local supertypes, effect-preserving successful `ref.test` folding and impossible `ref.eq` folding for effectful immediate `ref.i31` operands, effect-preserving `ref.as_non_null(ref.i31(call))` cleanup, and effect-prefix preservation for known-null `ref.as_non_null` / non-null-target `ref.test` / `ref.cast` / exact `ref.func` reference-basic folds. It still does not implement the broader upstream visitor families for things like:

- impossible `ref.eq` / known-non-null equality proofs beyond the covered null-vs-known-non-null, literal-i31, direct same-local, same-local `ref.i31(local.get)`, same-local nullable exact no-op and absolute-heap upcast `ref.cast(local.get)` including the absolute `i31` upcast subset, same-local nullable `ref.as_non_null(local.get)`, narrow definitely-non-null `i31` vs non-`i31` local subsets including indexed/defined aggregate coverage, and the absolute non-null local `struct` / `array` subset
- definitely successful `ref.cast` / `ref.test` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, absolute `struct` / `array` local-supertype, nullable-source nullable-target absolute aggregate-supertype, nullable-source nullable-target absolute `i31` supertype, and effectful immediate `ref.i31` successful-`ref.test` and `ref.as_non_null` subsets, plus broader failed cast/test cases beyond the immediate/local `ref.i31`, nullable-source non-null-target `i31`, absolute struct/array sibling miss proofs, nullable-target non-null aggregate-local miss coverage, and nullable-source non-null-target aggregate sibling miss coverage
- broader flow-sensitive `ref.as_non_null` cleanup
- descriptor-aware casts
- exactness-aware cast tightening

So the upstream cast/null-trap/descriptor story is still largely missing locally.

## 2. Partial `call_ref` directization surface

The local HOT implementation now models seven upstream `visitCallRef(...)` known-target slices plus three superseded boundary notes and two current boundary-negative slices:

- `ref.func` targets lower to direct `call` / `return_call`
- constant-index `table.get` targets lower to `call_indirect` / `return_call_indirect`
- call-indexed `table.get` targets whose table index is a no-param one-result direct call and whose already-evaluated call arguments are pure local/constant stack operands now escape the raw `stack-carried-effect` gate and lower to `call_indirect` / `return_call_indirect`, preserving the index call in the callee-index position
- zero-argument typed `select` targets whose arms are direct `ref.func`s lower to an `if` with direct `call` / `return_call` arms
- argument-bearing typed `select` targets whose arms are direct `ref.func`s lower to an argument-localizing block followed by an `if` with direct `call` / `return_call` arms for the covered single-result argument subset
- fallthrough-known block targets lower to a dropped target expression followed by direct `call` / `return_call`, preserving target-side effects; argument-bearing forms localize covered single-result call arguments before dropping the target and reload them for the direct call
- the older argument-bearing select, argument-bearing fallthrough, and call-indexed `table.get` fail-closed notes remain as superseded boundary history for why localization/raw-gate escape proof was required
- current fail-closed boundary coverage keeps select targets unchanged when an arm is not a direct `ref.func`
- current fail-closed boundary coverage keeps multi-result argument select-of-`ref.func` `call_ref` / `return_call_ref` unchanged; Binaryen localizes the probed `call $pair` through tuple scratch plus scalar locals before direct call or tail-call `if` arms, but Starshine's localizer currently proves only scalar single-result argument children

The remaining upstream `visitCallRef(...)` surface is still open for `[O4Z-AUDIT-OI-H]` when future source/oracle work identifies more locally representable known-target shapes.

So `call_ref` is no longer entirely missing, but full upstream directization parity is still incomplete.

## 3. Narrow bulk-memory lowering surface

The local pass now covers no-mode-dependent upstream bulk-memory shapes in narrow slices:

- constant-size `1` `memory.copy` to `i32.load8u` + `i32.store8`
- constant-size `2`/`4`/`8`/`16` `memory.copy` to exact `i32.load16u`/`i32.load`/`i64.load`/`v128.load` plus matching stores
- flat stack-carried tiny `memory.copy` sequences whose destination/source operands independently use local/constant/global operands, no-param direct-call operands, or `pure local/constant/global...; direct call` operands with matching parameter count and one result now escape the raw stack-effect gate and lower to the same load/store pairs while preserving destination-before-source evaluation order; mixed tiny-copy/byte-fill straight-line functions are covered when every bulk operation matches its narrow size rules
- direct-core memory64 `memory.copy` fixtures proving the same size-`1` and size-`8` lowering preserves `i64` destination/source address operands
- direct-core memory64 `memory.fill` fixtures proving size-`1` and size-`8` lowering preserves `i64` destination operands after the validator/typechecker accepts `i64` lengths
- constant-size `1` `memory.fill` to `i32.store8`, with constant fill values canonicalized to the low byte and flat stack-carried local/global/no-param-call plus direct-call value forms with pure local/constant/global arguments admitted through the raw gate
- constant-value size `2` `memory.fill` to repeated-byte `i32.store16`
- constant-value size `4` `memory.fill` to repeated-byte `i32.store`
- constant-value size `8` `memory.fill` to repeated-byte `i64.store`
- constant-value size `16` `memory.fill` to repeated-byte `v128.const` plus `v128.store`
- local.get value size `2` `memory.fill` to `(value & 255) * 257` plus `i32.store16`
- local.get value size `4` `memory.fill` to `(value & 255) * 16843009` plus `i32.store`
- local.get value size `8` `memory.fill` to `i64.extend_i32_u(value & 255) * 72340172838076673` plus `i64.store`
- explicit keep-spelling boundary coverage for non-local wider `memory.fill` values: Binaryen `version_130` keeps probed direct-call and computed `i32.add` fill values for sizes `2`/`4`/`8`, so Starshine also keeps those forms instead of counting them as missing materialization; size-1 byte fills are the covered `i32.store8` exception

The local pass still does not cover broader upstream families like:

- non-`1`/`2`/`4`/`8`/`16` constant-size `memory.copy` sequences and any future multi-store copy shapes; size `16` is covered by the one-load/one-store SIMD proof
- nonconstant-size `memory.copy` / `memory.fill`, because a dynamic size expression is not part of the exact tiny lowering proof; call-backed dynamic-size operands are now explicit keep-spelling boundaries under Binaryen `version_130`
- any future source-backed nonconstant wider `memory.fill` materialization beyond the covered direct `local.get` subset and constant size-16 repeated-byte fill case; call-backed and computed `i32.add` values for sizes `2`/`4`/`8` are now explicit keep-spelling boundaries under Binaryen `version_130`, while size-1 local/no-param-call and pure-argument direct-call values are covered
- trap-relaxing zero-size bulk-memory cleanup; zero-size `memory.copy` and `memory.fill` are explicit no-ignore-traps/TNH/IIT boundaries today, including effectful call operands that Binaryen also keeps
- broader stored-value/load-result canonicalization for the general load/store surface; only the current redundant-mask subset is covered (either `and` operand order for `i32.store8` / `i32.store16` plus a local Starshine-win `i64.store8` / `i64.store16` / `i64.store32` generalization that Binaryen `version_130` does not perform), Binaryen-style constant stored-value truncation before narrow stores, direct one-use `i32.wrap_i64` i32-store widening, direct reinterpret-store representation rewrites with memarg preservation, one-use full-width reinterpret-load result rewrites, and one-use `i64.extend_i32_*` load-result rewrites. Local-carried/shared `local.tee(i32.load)` plus reinterpret/extend spellings are explicit Binaryen-matching load-result boundaries, local-carried/shared `local.tee(f32.reinterpret_i32(...))` or `local.set`/`local.get` before `f32.store` are explicit Binaryen-matching stored-value boundaries, and local-carried/shared `i32.wrap_i64` store values are explicit Binaryen-matching keep-spelling boundaries, not claimed as one-use representation parity. For offset canonicalization, Starshine covers the narrow Binaryen-style memory32 and memory64 constant-pointer static-offset folds; tested nonconstant pointer-add address forms are now a Binaryen `version_130` OI no-change boundary, and public-pipeline mixed load/call functions remain behind `load-call-optimize-instructions-noop`, so static-offset folds apply only when the raw gate lets the pass run

## 4. Partial GC constructor / field surface; GC RMW/cmpxchg boundary

The local pass now models several upstream non-atomic GC constructor/field/array visitors in narrow OI-K slices: pure one-use `struct.get(struct.new(...))`, defaultable non-descriptor `struct.get(struct.new_default(...))`, selected `array.len`, constant-index `array.get`, and fresh-array `array.set` families.

Important upstream behaviors are still absent locally, especially:

- broader `StructSet` and effect/localizing field updates
- descriptor-bearing constructor forms
- dynamic-index or effectful-sibling array rewrites beyond the covered boundaries
- `StructRMW`
- `StructCmpxchg`
- `ArrayRMW`
- `ArrayCmpxchg`

For OI-L specifically, Binaryen `version_130` optimizes non-mutating aggregate RMW/cmpxchg forms such as `struct.atomic.rmw.add 0`, `struct.atomic.rmw.and -1`, and `struct.atomic.rmw.cmpxchg` with equal expected/replacement values to `struct.get`-like reads for probed acqrel/acqrel forms. Starshine currently has text/core support for `struct.atomic.get*` only, not aggregate RMW/cmpxchg constructors, so these remain an explicit representation boundary rather than hidden parity.

## 5. Partial tuple extraction surface

The local file now models the first `visitTupleExtract(...)` family for one-use `tuple.extract(tuple.make(...))` producers:

- when every non-selected tuple child is pure, the extract forwards the selected lane directly, including selected lanes that may trap such as `i32.load`;
- when non-selected siblings have effects or traps and produce at most one value, Starshine preserves/drops earlier effects before the selected lane, localizes the selected lane to a temp local when later effects exist, preserves/drops later effects or trapping loads, then reloads the selected value; the combined selected-trapping earlier-plus-later sibling fixture now locks the `drop(Call); LocalSet(i32.load); drop(Call); LocalGet` order against Binaryen's tuple-scratch oracle;
- local-carried/multi-use tuple extraction is now an explicit Binaryen-matching keep-spelling boundary for the probed shape;
- multi-result non-selected siblings are a current tuple-scratch localization boundary: Binaryen `version_130` materializes tuple scratch and scalar drops for the probed shape, while Starshine keeps the direct-HOT tuple spelling until a safe multi-result sibling localizer exists;
- multi-result selected children are also a current tuple-scratch localization boundary: Binaryen materializes tuple scratch, drops non-selected lanes, stores the chosen scalar, and reloads it for both covered selected-first and selected-second probes, while Starshine keeps the direct-HOT tuple spelling until a safe selected-child localizer exists;
- broader tee/drop reconstruction, any future safe multi-use tuple proof, public text-surface coverage, tuple-scratch localization, and broader tuple-neighbor signoff remain open under `[O4Z-AUDIT-OI-M]`; current `simplify-locals-nostructure` neighbor replays cover only the existing single-result effectful-sibling localization subset, including the earlier+later effectful-sibling direct-HOT fixture, and the public full-`simplify-locals` plus `tuple-optimization` multivalue-block probes are boundary coverage rather than parity.

## 6. First local sign-extension facts, but not full Binaryen `LocalScanner`

Upstream Binaryen runs a whole-function `LocalScanner` to infer:

- `maxBits`
- `signExtBits`

As of `[O4Z-AUDIT-OI-E]`, Starshine has a first conservative HOT-local sign-extension fact scan. It initializes params pessimistically, treats non-param scalar locals as default-zero until writes update or invalidate them, records straight-line `local.set` fallthrough facts, recognizes signed loads and explicit sign-extension ops, removes redundant sign extensions, and rewrites the first shift-pair sign-extension idioms.

This is still narrower than Binaryen's full scanner. Starshine now has narrow direct unsigned `maxBits` compare facts and direct i32 sign-extension equality range facts, but it does not yet model CFG joins, loop-carried fact merging, i64 sign-extension equality, signed relational range folds, or broad compare proofs through this substrate.

## 7. No deferred `ReFinalize` / EH-pop-fixup equivalent inside this pass

Upstream Binaryen explicitly depends on:

- deferred `ReFinalize`
- `EHUtils::handleBlockNestedPops(...)`

The current local HOT pass has its own HOT / lower / writeback validity story, but it is not the same helper contract.

## Important current divergence: constant `if` folding

One of the most useful durable differences between the local and upstream implementations is:

- current Starshine has an explicit `optimize_instructions_try_fold_constant_if_condition(...)`
- upstream Binaryen `version_129` `visitIf()` does **not** do generic constant-if folding here

That does not automatically make the local rule wrong.
But it does mean:

- the local pass is not a direct copy of the upstream phase boundary
- some landed local behavior belongs more naturally to `precompute` in the Binaryen mental model

## Important current boundary: branch hints and no-fold/no-reorder mode

`[O4Z-AUDIT-OI-F]` records that Starshine still has no expression-level branch-hint/code-metadata representation for this pass and no Binaryen-equivalent `optimize-instructions-never-fold-or-reorder` pass argument. Binaryen branch-hint copy/flip/apply/clear behavior and option-gated fold/reorder suppression are therefore unsupported metadata/options boundaries until Starshine grows the representation, parser/lowerer or opaque-section policy, pass-option plumbing, and focused remap tests.

## Important current divergence: artifact-driven dead-region cleanup

Several local helpers are clearly tailored to HOT / lowering issues rather than directly to upstream source structure.
Examples include:

- duplicate-then-branch collapse helpers
- dead-region-suffix cleanup with sentinel preservation
- nested boolean-tree inversion and wrapping logic
- fallback-branch preservation around escaping `if`s and carried labels

Those local rules may still be useful or necessary.
But they should be documented as:

- current Starshine HOT-IR and writeback strategy

not automatically as:

- direct evidence of how upstream Binaryen `OptimizeInstructions.cpp` is structured

## Ordered-artifact blocker story: now retired, still important context

The saved generated-artifact `-O4z` audit originally found two hard failure slots for `optimize-instructions`:

- slot `16`
- slot `44`

The durable repo-local conclusion is still:

- both slots are now retired
- the fixes were not new upstream-shape peepholes inside the pass
- they were HOT-lowering / writeback safety fixes around carried-result wrappers and parent-exit payload packing

So the remaining gap is breadth and honesty of upstream parity, not a still-open hard corruption witness.

## What a future honest Starshine port must preserve

A future port does **not** need to copy the entire Binaryen file literally.
But it does need to preserve these big truths:

1. the pass is broader than arithmetic
2. canonicalization is part of the algorithm
3. helper substrate matters
4. phase boundaries should stay honest when local behavior intentionally differs

## Practical maintenance rule

Treat the current local implementation as:

- a real implemented HOT pass
- strongest today on integer / boolean / control canonicalization
- intentionally carrying extra writeback-safety logic for local artifact history
- still missing any further source-backed `call_ref` known-target shapes beyond the covered select/table/fallthrough subset, multi-result argument localization beyond the documented tuple-scratch boundary, broader load/store canonicalization, GC, broader tuple/multivalue reconstruction including tuple-scratch handling for multi-result selected children and siblings, and helper-substrate surface

For this pass, "what Starshine does today" and "what Binaryen `version_130` expects for release-gating O4z parity" are not the same thing.
The wiki should keep that difference explicit and use `[O4Z-AUDIT-OI-*]` slice owners from the 2026-06-19 matrix when expanding coverage.
