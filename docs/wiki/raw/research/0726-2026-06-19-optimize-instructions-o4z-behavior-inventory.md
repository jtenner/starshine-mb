# 0726 - `optimize-instructions` O4z behavior inventory

## Status

- Date: 2026-06-19
- Type: O4z release-gating behavior inventory and backlog slicing
- Scope: classify the current Starshine `optimize-instructions` implementation against the documented Binaryen `version_129` / current-main spot-check contract and split the remaining `[O4Z-AUDIT-OI]` work into small actionable slices.

## Sources reviewed

Local Starshine implementation and tests:

- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

Living dossier and raw research:

- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/binaryen/passes/optimize-instructions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/gc-casts-call_ref-and-trap-sensitive-rewrites.md`
- `docs/wiki/binaryen/passes/optimize-instructions/wat-shapes.md`
- `docs/wiki/binaryen/passes/optimize-instructions/fuzzing.md`
- `docs/wiki/raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md`
- `docs/wiki/raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md`
- `docs/wiki/raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `docs/wiki/raw/research/0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md`
- `docs/wiki/raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md`
- `docs/wiki/raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md`
- `docs/wiki/raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md`
- `docs/wiki/raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md`

Upstream primary-source anchors from the dossier:

- Binaryen `version_129` `src/passes/OptimizeInstructions.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/passes.h`
- Binaryen helper headers: `bits.h`, `branch-hints.h`, `drop.h`, `effects.h`, `eh-utils.h`, `gc-type-utils.h`, `literal-utils.h`, `load-utils.h`, `localize.h`, `manipulation.h`, `properties.h`, `type-updating.h`, `call-utils.h`
- Dedicated lit files listed in `0131`, especially default, sign_ext, bulk-memory, call_ref, GC, GC TNH/IIT, multivalue, branch-hints, strings, and struct-RMW surfaces.

## Current Starshine implementation inventory

`src/passes/optimize_instructions.mbt` is active and scheduled in both default O4z `optimize` / `shrink` slots. Current implemented behavior is a useful but narrow HOT subset:

- exact `i32.add` / `i64.add` constant folding only;
- `eqz(sub)` and `eqz(add const)` compare rewrites;
- compare-to-zero `eq` to `eqz`, with guards for remainder and selected `i64.eq 0` condition shapes;
- selected signed-constant to unsigned compare canonicalization;
- relational constant normalization around `0` / `1`;
- commutative canonicalization with local HOT use/effect guards;
- `add/sub` neutral-zero and negative-immediate rewrites;
- multiply-by-power-of-two to shift;
- shift immediate masking and `and`-mask removal;
- `if` condition rewrites, nested boolean rewrites, and boolean value-if `eqz` wrapping;
- constant-if folding, which is useful locally but is not generic upstream Binaryen `visitIf` behavior for this pass;
- duplicate branch collapse in then-regions;
- dead region suffix cleanup with fallback-branch / zero-sentinel preservation.

The pass descriptor now declares `use_def` and `effects` invalidation, but the separate `[AUDIT001-A/B]` descriptor-requires slice still covers whether `requires` metadata should explicitly list lazy analysis dependencies.

`src/passes/pass_manager.mbt` also has broad OI raw no-op gates:

- `large-local-optimize-instructions`
- `large-lowered-optimize-instructions-noop`
- `stack-carried-effect-optimize-instructions-noop`
- `load-call-optimize-instructions-noop`
- `call-local-write-optimize-instructions-noop`
- `structured-call-branch-optimize-instructions-noop`
- `block-return-call-branch-optimize-instructions-noop`
- `loop-branch-local-write-optimize-instructions-noop`

Those gates are likely artifact/performance guards, but they also hide broad Binaryen behavior on functions that combine loads, calls, local writes, branches, or loops. They need OI-specific boundary tests and timing attribution before the audit can close.

## Major missing Binaryen behavior families

### 1. Current-source matrix is stale for release closeout

The dossier is anchored to Binaryen `version_129` with a 2026-05-05 current-main spot check. The O4z audit should refresh against the local oracle version before implementing behavior slices, because later work elsewhere now treats local `wasm-opt --version` as `version_130`.

Action: create a current local-oracle source/lit matrix before declaring final OI parity.

### 2. Arithmetic/compare breadth is incomplete

Starshine has selected integer rewrites but not the full default lit surface. Obvious missing or underclassified families include:

- broader constant binary folding beyond `i32.add` / `i64.add`;
- neutral/absorbing identities for `and`, `or`, `xor`, `mul`, div/rem power-of-two forms, rotate/shift nesting, and compare/sub variations;
- float canonicalization and fast-math-sensitive rewrites;
- bit-width and max-bits driven compare/mask proofs;
- sign-extension synthesis and redundant sign-extension removal;
- relational operand canonicalization is present as a helper but disabled in the compare visitor with `if false`.

### 3. Whole-function local scanner is absent

Binaryen runs `LocalScanner` before the main walk to compute `maxBits` and `signExtBits` per local. Current Starshine has local HOT pattern matching but no equivalent whole-function prescan. This blocks many sign-extension, mask, comparison, and signed/unsigned lowering families.

### 4. Boolean/select/ternary shell parity is incomplete

Starshine has nested boolean `if` work, but the upstream pass includes broader `if`/`select` shell rewrites, conditionalization/profitability behavior, branch-hint preservation/flip behavior, and mode-sensitive no-fold/no-reorder boundaries. Starshine also lacks a branch-hint metadata representation, so branch-hint parity should be documented as an explicit boundary unless representation work is added.

### 5. Memory and bulk-memory surface is absent

Current OI does not cover the upstream memory and bulk-memory surface:

- tiny `memory.copy` lowering;
- tiny `memory.fill` lowering;
- zero-size bulk-memory cleanup under IIT/TNH modes;
- load/store offset or stored-value canonicalization that belongs to OI rather than `optimize-added-constants`;
- memory64-specific shapes.

The broad `load-call-optimize-instructions-noop` raw gate may hide some of these shapes.

### 6. `call_ref` directization is absent

Current OI does not model Binaryen `visitCallRef(...)`:

- `ref.func` target to direct `call` / `return_call`;
- `table.get` target to `call_indirect` / `return_call_indirect`;
- fallthrough-known `ref.func` target directization with target-side effect preservation;
- `select` of known direct targets to direct-call `if` forms.

This is a major upstream feature family and should be sliced separately from GC/type casts.

### 7. Reference, cast, descriptor, and null-trap surface is absent

Current OI lacks the upstream `ref.eq`, `ref.is_null`, `ref.test`, `ref.cast`, `ref.as_non_null`, exactness, descriptor, TNH, and IIT behavior. This is too large for one implementation slice; first slices should cover non-GC reference equality/null tests, then cast/test lattice families, then descriptor/exactness/TNH boundaries.

### 8. GC constructor/field/array/atomic surface is absent

Current OI does not model upstream visitors for `struct.new`, `struct.get`, `struct.set`, `array.new`, `array.new_fixed`, `array.get`, `array.set`, `array.len`, unshared field ordering relaxation, GC RMW, or GC cmpxchg. These should stay separate from the smaller cast/null family because they require field/array/heap mutability and atomic-ordering tests.

### 9. Tuple extraction and multivalue surface is absent

Current OI does not model `tuple.extract(tuple.make(...))` and related tee/drop reconstruction. This is a narrow enough family to become its own implementation slice.

### 10. Repair hooks differ

Binaryen runs deferred `ReFinalize`, a final optimizer, and `EHUtils::handleBlockNestedPops` after the OI walk. Starshine has HOT lower/writeback validation but no equivalent OI-local refinalization or EH-pop repair. OI should either add behavior-specific repair support when a slice needs it or record precise fail-closed boundaries for EH nested-pop shapes.

### 11. Direct/O4z evidence is stale for audit closeout

The old slot16/slot44 corruption witnesses are retired, but the OI epic still needs a modern direct compare lane and replay of the two O4z slots after behavior slices. No dedicated GenValid profile is documented for OI yet.

## Recommended backlog slicing

The updated `agent-todo.md` should keep `[O4Z-AUDIT-OI]` active and split it into independently testable slices:

1. `OI-A`: current local-oracle source/lit behavior matrix.
2. `OI-B`: baseline direct compare, O4z slot16/slot44 replay, and raw-gate timing inventory.
3. `OI-C`: raw skip/gate boundary tests and trace/timing purpose documentation.
4. `OI-D`: default arithmetic/compare matrix expansion, starting with missed scalar integer identities and disabled relational operand canonicalization.
5. `OI-E`: `LocalScanner`-style max-bits/sign-ext prescan design and first sign-extension slice.
6. `OI-F`: boolean/select/ternary shell parity and branch-hint/no-fold/no-reorder boundary documentation.
7. `OI-G`: memory and bulk-memory tiny-copy/fill/zero-size surface.
8. `OI-H`: `call_ref` directization surface.
9. `OI-I`: non-GC reference equality/null/cast/test surface.
10. `OI-J`: descriptor/exactness/TNH/IIT cast boundaries.
11. `OI-K`: GC constructor/field/array/default/ordering surface.
12. `OI-L`: GC atomics RMW/cmpxchg surface.
13. `OI-M`: tuple extraction/multivalue surface.
14. `OI-N`: final direct and O4z slot signoff after implemented/admitted behavior slices.

## Suggested first implementation target after analysis

After `OI-A`/`OI-B` establish the current oracle and compare evidence, the smallest high-leverage behavior slice appears to be `OI-D`:

- it stays inside the existing scalar HOT infrastructure;
- it can add red-first tests from `optimize-instructions-default.wast` without needing new GC/call/memory representation;
- it can decide whether the disabled relational operand canonicalizer is safe to enable, replace, or keep explicitly failed-closed;
- it reduces direct parity gaps before larger representation-heavy work begins.

The next representation-heavy track should be `OI-E` because the local scanner unlocks many default and sign_ext behaviors without committing to the much larger GC/call_ref surfaces.

## Validation note

This investigation was a source/docs/backlog inventory only. No Moon or compare-pass commands were run. Implementation slices should use the standard pass signoff ladder: focused OI tests first, `moon test src/passes`, native `src/cmd` build, direct `--pass optimize-instructions --count 10000`, plus slot16/slot44 replay when behavior touches O4z-adjacent shapes.
