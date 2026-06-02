---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-06-02-global-type-optimization-current-main-recheck.md
  - ../../../raw/research/0694-2026-06-02-global-type-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md
  - ../../../raw/research/0467-2026-05-05-global-type-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md
  - ../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../constant-field-propagation/index.md
  - ../unsubtyping/index.md
  - ../type-merging/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./field-removal-subtyping-js-interop-and-traps.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../constant-field-propagation/index.md
  - ../unsubtyping/index.md
  - ../type-merging/index.md
---

# Starshine Strategy For `global-type-optimization`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-06-02-global-type-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-global-type-optimization-current-main-recheck.md) and the older 2026-04-24 manifest in [`../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`global-type-optimization` is still **unimplemented** in Starshine.
There is no `src/passes/global_type_optimization.mbt`, `src/passes/global-type-optimization.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `global-type-optimization` in the registry as a known boundary-only name
- reject active requests honestly instead of silently no-oping
- keep the upstream `gto` alias and closed-world GC/type-cluster contract visible in the wiki
- keep the pass absent from the canonical open-world no-DWARF path
- keep the missing dedicated backlog slice explicit
- document why a future port is module/type-graph and instruction-repair work, not a HOT peephole

This is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
    - `pass_registry_boundary_only_names()` includes `"global-type-optimization"`
    - it does **not** include upstream shorthand `"gto"` today
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`
- registry category lookup
  - [`src/passes/optimize.mbt#L363-L368`](../../../../../src/passes/optimize.mbt#L363-L368)
    - `pass_registry_category(...)` reads the cached category for known names
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` preset entries expand only the currently implemented module/HOT sequence and do not include `global-type-optimization`
  - [`src/passes/optimize.mbt#L303-L332`](../../../../../src/passes/optimize.mbt#L303-L332)
    - the public preset-expansion helpers also omit `global-type-optimization`
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path
- type-section and field representation a future port would have to rewrite
  - [`src/lib/types.mbt#L31-L159`](../../../../../src/lib/types.mbt#L31-L159)
    - `AbsHeapType`, `HeapType`, `RefType`, `ValType`, `FieldType`, `Mut`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph, exactness bit, field mutability, subtype metadata, and rec-group surface
  - [`src/lib/types.mbt#L736-L743`](../../../../../src/lib/types.mbt#L736-L743)
    - `StructNew`, `StructNewDefault`, descriptor constructors, `StructGet*`, and `StructSet` are explicit library instruction variants
  - [`src/lib/types.mbt#L4050-L4077`](../../../../../src/lib/types.mbt#L4050-L4077)
    - constructor helpers exist for `struct.new`, `struct.get*`, and `struct.set` instructions
- WAT parser and lowerer surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L171-L190`](../../../../../src/wast/parser.mbt#L171-L190)
    - WAT `StructFieldDef`, `TypeDefBody::Struct`, and `TypeDefBody::Array` model aggregate type declarations
  - [`src/wast/parser.mbt#L1889-L1914`](../../../../../src/wast/parser.mbt#L1889-L1914)
    - `struct.new*`, `struct.get*`, descriptor operations, and casts parse into WAST instruction nodes
  - [`src/wast/lower_to_lib.mbt#L271-L362`](../../../../../src/wast/lower_to_lib.mbt#L271-L362)
    - WAST struct field declarations lower to `@lib.FieldType` with `StorageType` plus `Mut`
  - [`src/wast/lower_to_lib.mbt#L2400-L2452`](../../../../../src/wast/lower_to_lib.mbt#L2400-L2452)
    - `struct.new*` and `struct.get*` lower from WAST to `@lib.Instruction` variants
  - current WAT caveat
    - local `@lib.StructSet` exists and validates, but this run did not find a WAT `struct.set` keyword/parser/lowerer path; future text-fixture work should fill that gap or use library/binary-level fixtures first
- validation surfaces a future port must preserve after mutability/removal rewrites
  - [`src/validate/typecheck.mbt#L1976-L2185`](../../../../../src/validate/typecheck.mbt#L1976-L2185)
    - `struct.new*`, `struct.get*`, and `struct.set` typecheck against resolved struct fields, mutability, packedness, descriptor-bearing constructors, defaultability, and expected reference/value stack types
- binary encoder/decoder surfaces a future port must keep coherent after rewrites
  - [`src/binary/decode.mbt#L2930-L2985`](../../../../../src/binary/decode.mbt#L2930-L2985)
    - binary GC opcodes decode into `struct.new*`, `struct.get*`, and `struct.set` instruction variants
  - [`src/binary/encode.mbt#L2635-L2678`](../../../../../src/binary/encode.mbt#L2635-L2678)
    - struct access and mutation opcodes encode back to the binary GC opcode space
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `global-type-optimization` in the active open-world route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `global-type-optimization` slice

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `global-type-optimization` changes private struct field declarations, reorders or removes fields, repairs affected struct instructions while old types are still available, and then performs a module-wide heap-type remap.
The transformed shapes cross:

- private struct type declarations and subtype relationships
- field mutability and field presence/order
- function bodies and module-code expressions
- `struct.new`, `struct.new_default`, descriptor constructors, `struct.get`, and `struct.set` sites
- atomic struct RMW / cmpxchg sites in Binaryen's official contract
- exported/imported JS-boundary flow for custom-descriptor prototype fields
- global initializer trap preservation
- field names and every remaining type use that mentions changed private heap types

A faithful Starshine port would need to reason over:

- the module's full heap-type inventory
- public versus private or externally visible heap-type boundaries
- GC and closed-world gates
- exact/inexact field traffic
- hierarchy-aware propagation through supertypes and subtypes
- two different removability queries: reads anywhere and self/super reads-or-writes
- field permutation and parent/child layout compatibility
- JS descriptor prototype keepalive rules
- instruction-before-type rewrite ordering
- side-effect and trap preservation for removed fields
- module-wide private type rewriting and validation afterward

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass plus shared closed-world type-graph / struct-field rewrite infrastructure, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The local descriptive name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `global-type-optimization` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- neighboring GC/type docs can point at one consistent local status
- future port work has to intentionally move the pass into an implemented category

### 2. The upstream shorthand is not registered locally

Upstream Binaryen exposes the pass as `gto`.
Current Starshine does not register `gto` as an alias.
That is useful to keep explicit because future CLI compatibility work must decide whether to add the short alias or keep the descriptive local spelling only.

### 3. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to rewrite private struct layouts
- the registry category remains executable documentation
- future implementation work will have to change the category and diagnostics intentionally

### 4. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `global-type-optimization` has no open-world no-DWARF preset role in this repo today.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- return without rewriting when GC is unavailable
- require an explicit closed-world mode before running the pass
- keep public struct types frozen unless Starshine has a stronger documented visibility proof
- track runtime `struct.set`, `struct.get`, RMW, and cmpxchg evidence separately from constructor traffic
- treat constructor operands as rewrite/trap-preservation inputs, not as liveness evidence that keeps a field alive by itself
- add JS-interface prototype-field reads for custom-descriptor field `0` when values can flow out to JS
- propagate field facts through subtype hierarchies in both “subs and supers” and “self plus supers” directions
- make mutable fields immutable only when no family writes exist and inherited parent slots can make the same choice
- remove fields only when no compatible reads need them or only strict subtypes need them
- compute a field permutation/removal map rather than a plain removed-bitset
- rewrite affected instructions while old type layouts are still available
- preserve side effects and null-trap order for removed `struct.set` sites
- preserve trapping removed module-initializer operands with an equivalent `gto-removed-*` mechanism
- repair field names after permutation/removal
- rewrite every affected private type use coherently across the module
- validate or refinalize after the rewrite

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./field-removal-subtyping-js-interop-and-traps.md`](./field-removal-subtyping-js-interop-and-traps.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` changes private struct field **value types** from observed contents and then repairs reads/writes.
`global-type-optimization` changes field **mutability and layout** from read/write liveness.
Both need closed-world struct-field infrastructure, but they do not optimize the same declaration fact.

### `constant-field-propagation`

See [`../constant-field-propagation/index.md`](../constant-field-propagation/index.md).

`constant-field-propagation` rewrites field reads to constants when contents are provable.
`global-type-optimization` may remove an unread field or make a field immutable even when the surviving field value is not a single constant.
Do not teach `gto` as constant propagation.

### `remove-unused-types`

See [`../remove-unused-types/index.md`](../remove-unused-types/index.md).

`remove-unused-types` deletes unused private heap-type identities and remaps the graph.
`global-type-optimization` keeps the type identities that still matter but mutates their private struct fields.
A later `remove-unused-types` pass may benefit from `gto`, but the two passes own different graph facts.

### `global-refining`

See [`../global-refining/index.md`](../global-refining/index.md).

`global-refining` changes global declaration types after collecting global writes.
`global-type-optimization` changes private struct field mutability/order/presence after collecting field reads and writes.
They sit near each other in the closed-world cluster, but the rewrite targets differ.

### `global-struct-inference`

See [`../global-struct-inference/index.md`](../global-struct-inference/index.md).

`global-struct-inference` rewrites field reads from globals when a unique object/value is known.
`global-type-optimization` rewrites the private struct layout itself.
The `gto_and_cfp_in_O.wast` family shows why earlier `gto` can unlock later global cleanup and field-content passes, but it is not itself GSI.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists
   - decide explicitly whether upstream alias `gto` gets a local spelling
   - when the pass lands, update registry category, preset behavior if any, tests, tracker, and docs in the same change
2. feature and world gates
   - no-GC modules are unchanged
   - open-world explicit requests reject or no-op according to the chosen Starshine API shape
   - closed-world test fixtures enable the rewrite explicitly
3. field evidence
   - constructor-only fields can disappear
   - runtime reads keep fields alive
   - runtime writes block immutability but do not by themselves keep unread fields alive
   - RMW/cmpxchg families keep fields alive and mutable if Starshine exposes those struct atomic surfaces
4. hierarchy legality
   - parent-only unread fields can disappear
   - fields used only by strict subtypes trigger reorder/append-compatible layouts
   - public parents freeze inherited prefixes
   - child-only suffix fields under public parents can still optimize when legal
5. instruction repair
   - removed constructor operands preserve side effects and traps
   - removed `struct.set` values keep side effects before null-trap checks
   - surviving `struct.get` / `struct.set` sites are reindexed
   - module-code removed trapping operands still execute during instantiation
6. type and name rewrite
   - private struct declarations update mutability/order/presence
   - field names follow the old-to-new permutation
   - all remaining type uses validate after remapping
7. parity coverage
   - compare targeted fixtures against Binaryen `wasm-opt --closed-world --gto` first
   - only then include the pass in combined closed-world GC/type clusters with `type-refining`, `remove-unused-types`, `constant-field-propagation`, and `global-struct-inference`

## Current uncertainty and recommendation

The main local uncertainty is where shared closed-world struct-field/type-graph infrastructure should live.
A one-off `global-type-optimization` port would duplicate machinery that nearby passes also need:

- [`type-refining`](../type-refining/index.md) needs closed-world field evidence, declaration rewriting, and read/write repair.
- [`constant-field-propagation`](../constant-field-propagation/index.md) needs closed-world field fact collection and subtype-aware propagation.
- [`remove-unused-types`](../remove-unused-types/index.md) and [`type-merging`](../type-merging/index.md) need module-wide type-use rewriting.
- [`unsubtyping`](../unsubtyping/index.md) needs descriptor/subtype graph proofs and allocation repair.

Two local representation gaps also need planning before parity work:

- WAT `struct.set` parsing/lowering was not found in this run, even though the library, binary, and validator layers have `StructSet`.
- Binaryen's `gto-removals-rmw.wast` contract uses struct atomic RMW/cmpxchg field operations, while the currently visible Starshine instruction enum exposes ordinary memory atomics but no dedicated struct atomic field operations.

Until a backlog slice decides those architecture questions, keep `global-type-optimization` documented as boundary-only and unimplemented.

## Bottom line

Current Starshine has a safe boundary-only `global-type-optimization` registry entry and reusable GC/type/parser/validator/binary infrastructure, but no pass implementation.
A future port must be a closed-world module/type-graph transform with private struct field liveness, mutability and layout rewriting, subtype-layout repair, JS descriptor keepalive, trap-preserving instruction rewrite, module-wide type-use remapping, and final validation.
