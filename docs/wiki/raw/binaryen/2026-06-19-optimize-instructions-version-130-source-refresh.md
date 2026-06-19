# Binaryen `optimize-instructions` `version_130` source/lit matrix

_Capture date:_ 2026-06-19  
_Status:_ immutable source/lit refresh and Starshine coverage-owner matrix for `[O4Z-AUDIT-OI-A]`

## Scope

This note replaces the older 2026-05-05 spot check for release-gating O4z audit work. It treats Binaryen `version_130` as the current local release-oracle baseline because the repo's Binaryen release-horizon page and recent pass audits use `version_130` as the public release baseline, and the OI backlog requested a current local-oracle matrix before behavior changes.

This is a source/docs inventory only. It does not run Starshine, Binaryen, Moon, or compare-pass commands.

## Official primary sources

Core owner and registration:

- `src/passes/OptimizeInstructions.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/OptimizeInstructions.cpp>
- raw source opened during this slice: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/OptimizeInstructions.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `src/passes/passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/passes.h>
- `src/passes/opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h>

Helper surfaces reread or re-anchored from the existing dossier because they are semantically part of `OptimizeInstructions.cpp` legality:

- `src/ir/bits.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/bits.h>
- `src/ir/branch-hints.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/branch-hints.h>
- `src/ir/drop.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/drop.h>
- `src/ir/effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
- `src/ir/eh-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/eh-utils.h>
- `src/ir/gc-type-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/gc-type-utils.h>
- `src/ir/literal-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/literal-utils.h>
- `src/ir/load-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/load-utils.h>
- `src/ir/localize.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/localize.h>
- `src/ir/manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/manipulation.h>
- `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/properties.h>
- `src/ir/type-updating.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/type-updating.h>
- `src/passes/call-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/call-utils.h>

Dedicated lit roster re-anchored at `version_130`:

- `optimize-instructions-default.wast`
- `optimize-instructions-mvp.wast`
- `optimize-instructions-memory64.wast`
- `optimize-instructions-sign_ext.wast`
- `optimize-instructions-multivalue.wast`
- `optimize-instructions-atomics.wast`
- `optimize-instructions-bulk-memory.wast`
- `optimize-instructions-ignore-traps.wast`
- `optimize-instructions_idempotent.wast`
- `optimize-instructions_branch-hints-fold.wast`
- `optimize-instructions-call_ref.wast`
- `optimize-instructions-call_ref-roundtrip.wast`
- `optimize-instructions-exceptions.wast`
- `optimize-instructions-eh-legacy.wast`
- `optimize-instructions-iit-eh-legacy.wast`
- `optimize-instructions-gc.wast`
- `optimize-instructions-gc-atomics.wast`
- `optimize-instructions-gc-extern.wast`
- `optimize-instructions-gc-iit.wast`
- `optimize-instructions-gc-tnh.wast`
- `optimize-instructions-exact.wast`
- `optimize-instructions-all-casts.wast`
- `optimize-instructions-all-casts-exact.wast`
- `optimize-instructions-desc.wast`
- `optimize-instructions-nontrapping-float-to-int.wast`
- `optimize-instructions-strings.wast`
- `optimize-instructions-struct-rmw.wast`

Each file URL follows `https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/<file>`.

## Version_130 source-shape observations

The `version_130` `OptimizeInstructions.cpp` still teaches the same broad pass shape as the `version_129` dossier plus the 2026-05-05 current-main bridge:

- function-parallel post-walk pass with an initial `LocalScanner`;
- `LocalScanner` still initializes params pessimistically and non-params optimistically, then updates `maxBits` and `signExtBits` from fallthrough values, sign-extension idioms, and signed loads;
- `doWalkFunction()` still reads `fastMath`, `optimize-instructions-never-fold-or-reorder`, runs the scanner, performs the main walk, then runs deferred `ReFinalize`, `FinalOptimizer`, and `EHUtils::handleBlockNestedPops` when needed;
- `replaceCurrent()` still forms a local fixpoint, so one rewrite can expose another on the same node;
- helper dependencies remain part of the contract: bit facts, fallthrough/type facts, effect order, branch hints, dropped-child rebuilding, localizing, refinalization, GC type checks, memory/load utilities, and call-target conversion all gate visible rewrites.

No OI-A evidence says the Starshine implementation changed during this slice. The matrix below therefore maps upstream `version_130` behavior to the current local Starshine code/tests and existing `[O4Z-AUDIT-OI-*]` owners.

## Source visitor / helper matrix

| Binaryen `version_130` source family | Starshine status as of 2026-06-19 | Owner / reopening rule |
| --- | --- | --- |
| Pass registration and default/shrink scheduling in `pass.cpp` / `passes.h` | Starshine has active registry and early+late optimize/shrink slots in `src/passes/optimize.mbt`, plus registry tests. | Keep covered; `[O4Z-AUDIT-OI-B]` must baseline direct and slot evidence under the current toolchain. |
| `doWalkFunction()` shell: fast-math, never-fold/reorder arg, `LocalScanner`, postwalk, refinalize, final optimizer, EH nested-pop repair | Starshine has a HOT pass driver and validation, but no OI-local `LocalScanner`, no OI-local refinalize/EH repair equivalent, and no public never-fold/reorder mode. | `[O4Z-AUDIT-OI-E]` for scanner; `[O4Z-AUDIT-OI-F]` for no-fold/no-reorder and branch-hints boundary; later slices reopen repair when a rewrite needs it. |
| `LocalScanner` `maxBits` / `signExtBits` facts | Missing beyond local HOT pattern checks. | `[O4Z-AUDIT-OI-E]`. |
| `replaceCurrent()` local fixpoint | Starshine performs pass-local traversal/rewrite loops but does not intentionally mirror Binaryen's per-node fixpoint contract across every visitor family. | Track per behavior slice; add focused tests when enabling chains that depend on same-node reoptimization. |
| `FinalOptimizer` add/sub and signed-LEB-friendly spelling | Partially covered by local add/sub negative-immediate and negative-LEB preferences. | Covered for current scalar subset; expand in `[O4Z-AUDIT-OI-D]` if direct compare shows remaining scalar spelling gaps. |
| `visitBinary()` canonicalization: constants right, symmetric ordering, relational operand/opcode reversal | Partially covered for selected integer compares/commutative HOT-safe orders. Relational operand canonicalizer exists locally but remains disabled in one compare path. | `[O4Z-AUDIT-OI-D]` decides enable/replace/fail-close. |
| `visitBinary()` integer identities, add/sub/mul/shift, masks, divide/rem by powers of two, nested shifts/rotates | Starshine covers selected add/sub, mul-by-power-of-two, shift-mask and effective-zero shift cleanup, but not the full default arithmetic surface. | `[O4Z-AUDIT-OI-D]`. |
| Float arithmetic and fast-math-sensitive canonicalization | Missing. | `[O4Z-AUDIT-OI-D]` should either add scalar float cases or split a new float-only follow-up if representation/options block safe parity. |
| Sign-extension synthesis/removal, sign-extended comparisons, load sign updates | Mostly missing; current Starshine has no scanner-backed sign facts. | `[O4Z-AUDIT-OI-E]`. |
| `optimizeBoolean(...)` recursive boolean-context cleanup | Partially covered by local `eqz`, compare-to-zero, nested boolean `if`, and boolean value-if rewrites. | `[O4Z-AUDIT-OI-F]` for remaining boolean/select/try/block recursion breadth. |
| `visitIf(...)`: booleanize condition, arm flip on `eqz`, branch-hint flip, identical-arm fold, ternary optimization | Starshine has constant-if folding and some nested boolean cleanup, but upstream OI does not own generic constant-if picking. Branch hints are a local representation boundary. | `[O4Z-AUDIT-OI-F]`; document Starshine-only constant-if behavior as local HOT/precompute-adjacent divergence. |
| `optimizeSelect(...)` and `optimizeTernary(...)` | Mostly missing except adjacent boolean value-if shapes. | `[O4Z-AUDIT-OI-F]`. |
| `optimizeMemoryAccess(...)` / load/store offset and stored-value cleanup | Missing as an OI surface; some neighboring behavior may belong to `optimize-added-constants` or memory passes. | `[O4Z-AUDIT-OI-G]`; classify exact OI ownership before implementation. |
| `optimizeMemoryCopy(...)` / `optimizeMemoryFill(...)` | Missing. Current raw `load-call` gate may hide memory+call mixtures. | `[O4Z-AUDIT-OI-G]`, coordinated with `[O4Z-AUDIT-OI-C]`. |
| `visitCallRef(...)`: `ref.func` direct call, `table.get` indirect call, fallthrough-known direct target, select-of-known targets | Missing. | `[O4Z-AUDIT-OI-H]`. |
| `visitRefEq(...)` and `visitRefIsNull(...)` | Missing. | `[O4Z-AUDIT-OI-I]`. |
| `visitRefTest(...)`, `visitRefCast(...)`, `visitRefAs(...)`, cast-check lattice | Missing; descriptor/exactness/TNH/IIT modes are unclassified locally. | `[O4Z-AUDIT-OI-I]` for basic non-GC reference cases; `[O4Z-AUDIT-OI-J]` for descriptor/exactness/TNH/IIT boundaries. |
| `skipNonNullCast(...)`, `skipCast(...)`, `trapOnNull(...)` | Missing as a helper substrate. | `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]` / `[O4Z-AUDIT-OI-K]` depending on consumer instruction. |
| `visitStructNew`, `visitArrayNew`, `visitArrayNewFixed` default/repeated-value constructors | Missing. | `[O4Z-AUDIT-OI-K]`. |
| `visitStructGet`, `visitStructSet`, `visitArrayGet`, `visitArraySet`, `visitArrayLen`, `visitArrayCopy`, `ref.get_desc`, unshared ordering relaxation | Missing. | `[O4Z-AUDIT-OI-K]`; descriptor cases also feed `[O4Z-AUDIT-OI-J]`. |
| GC RMW/cmpxchg visitors and unshared lowering / non-mutating simplifications | Missing. | `[O4Z-AUDIT-OI-L]`. |
| `visitTupleExtract(...)` with `tuple.make` / tee/drop reconstruction | Missing. | `[O4Z-AUDIT-OI-M]`. |
| EH / exception cleanup and nested-pop repair surfaces | Starshine has general HOT/writeback validation and some ref-local try-table preservation tests, but not Binaryen's OI-local EH repair hook. | Keep as boundary until a behavior slice needs EH mutation; `[O4Z-AUDIT-OI-F]` and `[O4Z-AUDIT-OI-N]` must not close EH broadly without evidence. |
| Branch-hint/code-metadata behavior and `optimize-instructions-never-fold-or-reorder` | Local WAST/code-metadata representation is documented elsewhere; OI does not model expression-level branch-hint preservation/flip. | `[O4Z-AUDIT-OI-F]` explicit boundary with reopening criteria: add support once Starshine can preserve branch hints/code metadata through HOT rewrites. |
| Current raw no-op gates in `pass_manager.mbt` | Local-only gates skip large local/lowered, load+call, call+local-write, structured call/branch, block-return-call/branch, loop-branch-local-write, and stack-carried-effect functions. They are not upstream OI semantics. | `[O4Z-AUDIT-OI-C]`; OI-A records them as local release boundaries, not parity evidence. |

## Dedicated lit-family matrix

| Lit family | Upstream proof role | Current Starshine coverage / owner |
| --- | --- | --- |
| `default`, `mvp`, `memory64` | Default scalar arithmetic, compares, control shells, memory32/64 spelling | Partial scalar/control coverage; `[O4Z-AUDIT-OI-D]`, `[O4Z-AUDIT-OI-F]`, `[O4Z-AUDIT-OI-G]`. |
| `sign_ext` | Sign-extension op synthesis/removal and width/sign facts | Missing scanner-backed behavior; `[O4Z-AUDIT-OI-E]`. |
| `multivalue` | Tuple/multivalue extraction and reconstruction | Missing; `[O4Z-AUDIT-OI-M]`. |
| `atomics` | Ordinary atomic-adjacent instruction cases in default surface | Not separately covered; classify with `[O4Z-AUDIT-OI-G]` or `[O4Z-AUDIT-OI-L]` depending on concrete instruction family. |
| `bulk-memory`, `ignore-traps` | Tiny copy/fill, zero-size and trap-relaxed memory cleanup | Missing; `[O4Z-AUDIT-OI-G]` plus trap-mode boundary in `[O4Z-AUDIT-OI-J]` if mode controls are absent. |
| `optimize-instructions_idempotent` | Effect/idempotence-sensitive folding | Not explicitly covered beyond local HOT effect/use guards; `[O4Z-AUDIT-OI-D]`, `[O4Z-AUDIT-OI-F]`, `[O4Z-AUDIT-OI-I]` when effect-sensitive families are added. |
| `branch-hints-fold` | Branch-hint-aware fold/reorder/arm-flip behavior | Local boundary until expression code metadata/branch hints are represented; `[O4Z-AUDIT-OI-F]`. |
| `call_ref`, `call_ref-roundtrip` | Directization and roundtrip-safe call target rewrites | Missing; `[O4Z-AUDIT-OI-H]`. |
| `exceptions`, `eh-legacy`, `iit-eh-legacy` | EH-sensitive cleanup and nested-pop repair | Boundary until a slice mutates EH shapes; `[O4Z-AUDIT-OI-F]` / `[O4Z-AUDIT-OI-N]`. |
| `gc`, `gc-extern`, `gc-iit`, `gc-tnh` | Reference and GC cast/null-trap/default constructor behavior under default/IIT/TNH modes | Missing; `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, `[O4Z-AUDIT-OI-K]`. |
| `gc-atomics`, `struct-rmw` | GC atomic RMW/cmpxchg and unshared lowering | Missing; `[O4Z-AUDIT-OI-L]`. |
| `exact`, `all-casts`, `all-casts-exact`, `desc` | Exact and descriptor-aware cast/test behavior | Missing; `[O4Z-AUDIT-OI-J]`. |
| `nontrapping-float-to-int` | Nontrapping conversion and float/int boundary cases | Missing or unclassified; start in `[O4Z-AUDIT-OI-D]`, split if representation/options require. |
| `strings` | String-related OI shapes | Unimplemented/unclassified local boundary; should not block scalar OI slices, but must remain open for `[O4Z-AUDIT-OI-N]` unless explicitly sliced or accepted as upstream-only due local string representation. |

## Starshine coverage summary after OI-A

Covered or partially covered now:

- active direct pass registration and preset placement;
- selected integer constant folding and compare-to-zero / `eqz` rewrites;
- selected signed-constant compare canonicalization;
- HOT-guarded commutative ordering;
- add/sub neutral and negative-immediate rewrites;
- multiply-by-power-of-two to shift;
- shift-mask cleanup;
- nested boolean `if`, constant-`if`, duplicate-branch, and local dead-suffix/fallback preservation.

Explicit current local boundaries:

- branch hints / code metadata and `never-fold-or-reorder` mode;
- local raw skip gates in `pass_manager.mbt`;
- OI-local `ReFinalize` / EH-pop repair;
- strings and other proposal surfaces where local representation support is not yet confirmed.

Open implementation slice owners:

- `[O4Z-AUDIT-OI-B]`: direct/slot baseline evidence;
- `[O4Z-AUDIT-OI-C]`: raw gate tests and timing/purpose classification;
- `[O4Z-AUDIT-OI-D]`: scalar arithmetic/compare/default-lit breadth;
- `[O4Z-AUDIT-OI-E]`: local scanner and sign-extension facts;
- `[O4Z-AUDIT-OI-F]`: boolean/select/ternary and branch-hint/no-fold boundaries;
- `[O4Z-AUDIT-OI-G]`: memory and bulk-memory;
- `[O4Z-AUDIT-OI-H]`: `call_ref`;
- `[O4Z-AUDIT-OI-I]`: non-GC ref equality/null/cast/test basics;
- `[O4Z-AUDIT-OI-J]`: descriptor/exactness/TNH/IIT boundaries;
- `[O4Z-AUDIT-OI-K]`: GC constructors/fields/arrays/default/order;
- `[O4Z-AUDIT-OI-L]`: GC atomics;
- `[O4Z-AUDIT-OI-M]`: tuple/multivalue;
- `[O4Z-AUDIT-OI-N]`: final direct/O4z closeout.

## Validation

No Moon, Bun, Binaryen, or compare-pass commands were run. This slice only updated source/lit inventory and docs/backlog state, which the repo docs policy allows for docs-only commits unless generated contracts or executable examples change.
