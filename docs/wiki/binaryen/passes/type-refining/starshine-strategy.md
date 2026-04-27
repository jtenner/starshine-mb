---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md
  - ../../../raw/research/0419-2026-04-27-type-refining-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md
  - ../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../gufa/index.md
  - ../global-refining/index.md
  - ../remove-unused-types/index.md
  - ../signature-pruning/index.md
  - ../signature-refining/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./normal-vs-gufa-and-fixups.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../gufa/index.md
  - ../remove-unused-types/index.md
  - ../global-refining/index.md
  - ../signature-pruning/index.md
  - ../signature-refining/index.md
  - ../constant-field-propagation/index.md
---

# Starshine Strategy For `type-refining`

Use this page together with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md) and [`../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.
For first-slice sequencing, validation fixtures, and Binaryen oracle lanes, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`type-refining` is still **unimplemented** in Starshine.
There is no `src/passes/type_refining.mbt`, `src/passes/type-refining.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `type-refining` in the registry as a known boundary-only name
- reject active requests honestly instead of silently no-oping
- keep the upstream closed-world GC/type-cluster contract visible in the wiki
- keep its absence from the canonical open-world no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document why a future port is module/type-graph work, not a HOT peephole
- keep the analyzer-first implementation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) visible until a real owner file exists

This is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"type-refining"`
    - it does **not** separately list upstream sibling spelling `"type-refining-gufa"` today
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`
- registry category lookup
  - [`src/passes/optimize.mbt#L363-L368`](../../../../../src/passes/optimize.mbt#L363-L368)
    - `pass_registry_category(...)` reads the cached entry category for known names
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `type-refining`
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path
- type-section and field representation a future port would have to rewrite
  - [`src/lib/types.mbt#L31-L159`](../../../../../src/lib/types.mbt#L31-L159)
    - `AbsHeapType`, `HeapType`, `RefType`, `ValType`, `FieldType`, `Mut`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph, exactness bit, field mutability, subtype metadata, and rec-group surface
  - [`src/lib/types.mbt#L720-L764`](../../../../../src/lib/types.mbt#L720-L764)
    - `StructNew*`, `StructGet*`, `StructSet`, `RefGetDesc`, `RefTest`, `RefCast`, descriptor casts, and branch casts are explicit instruction variants rather than pass-local syntax
  - [`src/lib/types.mbt#L4060-L4079`](../../../../../src/lib/types.mbt#L4060-L4079)
    - constructor helpers exist for `struct.new`, `struct.get*`, and `struct.set` instructions
- WAT parser and lowerer surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L171-L190`](../../../../../src/wast/parser.mbt#L171-L190)
    - WAT `StructFieldDef`, `TypeDefBody::Struct`, and `TypeDefBody::Array` model aggregate type declarations
  - [`src/wast/parser.mbt#L1889-L1914`](../../../../../src/wast/parser.mbt#L1889-L1914)
    - `struct.new*`, `struct.get*`, descriptor operations, and casts parse into WAST instruction nodes
  - [`src/wast/lower_to_lib.mbt#L2400-L2452`](../../../../../src/wast/lower_to_lib.mbt#L2400-L2452)
    - `struct.new*` and `struct.get*` lower from WAST to `@lib.Instruction` variants
  - current WAT caveat
    - local `@lib.StructSet` exists and validates, but this run did not find a WAT `struct.set` keyword/parser/lowerer path; future text-fixture work should fill that gap or use library/binary-level fixtures first
- validation surfaces a future port must preserve after refining field declarations
  - [`src/validate/env.mbt#L134-L154`](../../../../../src/validate/env.mbt#L134-L154)
    - validation resolves `TypeIdx` / `HeapType` references through the module type environment
  - [`src/validate/typecheck.mbt#L2075-L2185`](../../../../../src/validate/typecheck.mbt#L2075-L2185)
    - `struct.new_default_desc`, `struct.get*`, and `struct.set` typecheck against resolved struct fields, mutability, packedness, and expected reference/value stack types
  - [`src/validate/typecheck.mbt#L3261-L3285`](../../../../../src/validate/typecheck.mbt#L3261-L3285)
    - the main instruction dispatcher routes `StructNew*`, `StructGet*`, `StructSet`, descriptor, cast, and array instructions to validators
- binary encoder/decoder surfaces a future port must keep coherent after rewrites
  - [`src/binary/decode.mbt#L2930-L2985`](../../../../../src/binary/decode.mbt#L2930-L2985)
    - binary GC opcodes decode into `struct.new*`, `struct.get*`, and `struct.set` instruction variants
  - [`src/binary/encode.mbt#L2635-L2678`](../../../../../src/binary/encode.mbt#L2635-L2678)
    - struct access and mutation opcodes encode back to the binary GC opcode space
- nearby implemented struct-operation scanners
  - [`src/passes/pass_manager.mbt#L5581-L5604`](../../../../../src/passes/pass_manager.mbt#L5581-L5604)
    - the current HSO fast-skip scanner already recognizes `StructNew*` and `StructSet`; this is only a nearby scanner example, not a reusable field-LUB engine
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `type-refining` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `type-refining` slice

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `type-refining` changes declared private struct field types after whole-module closed-world analysis, then repairs affected instructions.
The transformed shapes appear across:

- private struct type declarations and subtype relationships
- function bodies and module-code expressions
- `struct.new`, `struct.new_default`, `struct.get`, `struct.set`, RMW, and cmpxchg sites
- field read result types and write operand types
- exactness and nullable-bottom repair forms
- public-type visibility boundaries
- control-flow expressions that need refinalization after field types change

A faithful Starshine port would need to reason over:

- the module's full heap-type inventory
- public versus private or externally visible heap-type boundaries
- GC and closed-world gates
- direct struct write/default/copy evidence
- the optional GUFA-style whole-program contents-oracle sibling surface
- hierarchy-aware field LUB propagation through supertypes and subtypes
- mutable-field equality constraints across subtype edges
- explicit read repair before or during type rewriting
- module-wide private type rewriting
- post-rewrite validation or refinalization
- write-site casts/nulls/unreachable repair after the new field types are in place

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or shared closed-world type-graph rewrite engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The base name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `type-refining` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- neighboring GC/type docs can point at one consistent local status
- future port work has to intentionally move the pass into an implemented category

### 2. The GUFA sibling is documented but not registered locally

Upstream Binaryen also publishes `type-refining-gufa`.
The living dossier documents it because the source-backed pass topic is incomplete without the sibling.
Current Starshine, however, only tracks the base `type-refining` spelling.

A future registry cleanup should decide whether to add `type-refining-gufa` as its own boundary-only name before implementation or keep it as an upstream-only sibling documented through [`../gufa/index.md`](../gufa/index.md) until local GUFA infrastructure exists.

### 3. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to refine field declarations
- the registry category remains executable documentation
- future implementation work will have to change the category and diagnostics intentionally

### 4. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `type-refining` has no open-world no-DWARF preset role in this repo today.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- return without rewriting when GC is unavailable
- require an explicit closed-world mode before running the pass
- keep public struct types frozen unless Starshine has a stronger documented visibility proof
- infer private field types from writes/defaults/copies, not ordinary reads
- preserve the normal-vs-GUFA split instead of pretending repeated local cleanups are equivalent to `ContentOracle`
- propagate `struct.new` facts upward through supertypes
- propagate `struct.set` / copied-read facts through both supertype and subtype directions where Binaryen does
- treat default ref fields as nullable-bottom evidence, not as a reason to keep the old wide heap type forever
- keep the tee / `br_if` copy boundary explicit for the normal mode
- enforce subtype legality after inference, including mutable-field equality relative to supertypes
- repair `struct.get` result types or replace impossible reads with `drop(ref); unreachable`
- rewrite private struct declarations coherently across the module
- refinalize or validate after type rewriting
- repair `struct.new`, `struct.set`, RMW, and cmpxchg writes that became too broad, including `ref.cast`, `ref.null bottom`, and `drop(value); unreachable` outcomes
- keep global-initializer constraints explicit for any GUFA-style mode because Binaryen's later write updater repairs function bodies, not global initializer expressions
- keep arrays out of scope until source-backed support is intentionally added

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `gufa`

See [`../gufa/index.md`](../gufa/index.md).

`gufa` is a whole-program contents-oracle rewrite family over expression uses.
`type-refining-gufa` borrows the same style of oracle to infer field declarations, then still runs the `type-refining` declaration-rewrite and read/write repair pipeline.
Do not teach GUFA as merely a stronger cost knob on the normal type-refining scanner.

### `remove-unused-types`

See [`../remove-unused-types/index.md`](../remove-unused-types/index.md).

`remove-unused-types` removes unused private types and remaps the heap-type graph.
`type-refining` changes field types of retained private struct declarations based on observed field contents.
Do not attribute type deletion or rec-group minimization to `type-refining` alone.

### `signature-pruning` and `signature-refining`

See [`../signature-pruning/index.md`](../signature-pruning/index.md) and [`../signature-refining/index.md`](../signature-refining/index.md).

Those passes operate on function signatures and call surfaces.
`type-refining` operates on struct field declarations and struct read/write repair.
They sit near each other in Binaryen's closed-world GC/type cluster, but they own different declaration surfaces.

### `global-refining`

See [`../global-refining/index.md`](../global-refining/index.md).

`global-refining` changes global declaration types after collecting global writes.
`type-refining` changes struct field declaration types after collecting field writes.
The passes share a broad closed-world type-tightening theme but not the same evidence model or rewrite targets.

### `constant-field-propagation`

See [`../constant-field-propagation/index.md`](../constant-field-propagation/index.md).

`constant-field-propagation` rewrites field reads to constant values when field contents are provable.
`type-refining` rewrites declared field types and repairs uses. A field can have a refined type without being a single constant.

## Validation plan for the eventual port

The maintained validation bridge is now [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). Keep the shorter checklist below as a status-page summary and update both pages together when local implementation status changes.

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists
   - decide explicitly whether `type-refining-gufa` gets a separate registry spelling
   - when the pass lands, update registry category, preset behavior if any, tests, tracker, and docs in the same change
2. feature and world gates
   - no-GC modules are unchanged
   - open-world requests fail or no-op according to the chosen Starshine API shape
   - closed-world test fixtures enable the rewrite explicitly
3. field-inference positives
   - direct `struct.set` and `struct.new` writes refine private fields
   - default constructors preserve nullability without pinning wide heap types
   - same-field copies do not keep the old wide type alive
   - ordinary reads do not constrain inference
4. hierarchy legality
   - parent and child field types stay valid after refinement
   - mutable child fields equal refined super fields
   - public struct types stay frozen while legal private descendants can still refine
5. normal-mode copy boundaries
   - tee / `br_if` fallthrough copy families remain conservative
   - block / `if` / try result families can still refinalize when safe
6. read/write repair
   - invalidated `struct.get` sites become trap-equivalent `drop + unreachable`
   - valid `struct.get` sites retag to the narrower field type
   - too-broad writes get casts when casts are valid
   - bottom/null/uninhabited repair shapes validate after rewrite
7. GUFA-specific layer, if implemented
   - whole-program locals/globals/calls/cycles can infer extra field precision
   - global initializer write constraints are handled before later function-body-only repair
   - exact/custom-descriptor and continuation limits match the official sibling tests
8. final validation
   - binary encode/decode roundtrips the rewritten struct ops
   - final module validation catches missed type-use or write repair

## Open local questions

- What will Starshine's closed-world option surface be for passes that upstream Binaryen hard-gates on `--closed-world`?
- Should `type-refining` share one type-graph rewrite engine with `remove-unused-types`, `minimize-rec-groups`, `type-merging`, `unsubtyping`, `signature-pruning`, and `signature-refining`?
- Should the first local implementation support only the normal direct-struct-traffic mode, or should it wait for GUFA/`ContentOracle`-equivalent infrastructure?
- Should the registry add boundary-only `type-refining-gufa` now for naming honesty, or keep the sibling documented only through the `type-refining` and `gufa` pages until implementation planning starts?
- Should WAT `struct.set` parsing/lowering be filled before implementation, or should early tests build `@lib.StructSet` fixtures directly? The current port-readiness bridge treats this as an explicit fixture caveat, not an implementation blocker for analyzer-only work.

Keep those questions explicit until an implementation plan answers them.

## Bottom line

Current Starshine has a safe boundary-only `type-refining` registry entry and reusable GC/type/parser/validator/binary infrastructure, but no pass implementation.
A future port must be a closed-world module/type-graph transform with field-content inference, public/private legality, hierarchy-aware field LUBs, declaration rewriting, read/write repair, optional GUFA-style inference, and final validation.
