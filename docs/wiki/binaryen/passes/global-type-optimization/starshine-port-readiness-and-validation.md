---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md
  - ../../../raw/research/0467-2026-05-05-global-type-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md
  - ../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./field-removal-subtyping-js-interop-and-traps.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../constant-field-propagation/index.md
  - ../unsubtyping/index.md
---

# Starshine port-readiness and validation for `global-type-optimization`

Use this page together with [`./starshine-strategy.md`](./starshine-strategy.md), the Binaryen contract pages in [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./field-removal-subtyping-js-interop-and-traps.md`](./field-removal-subtyping-js-interop-and-traps.md), and [`./wat-shapes.md`](./wat-shapes.md), plus the freshness bridge in [`../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md).

This is a **future-port** page, not an implementation page.
Starshine still does not implement `global-type-optimization`.

## Current local status

- registry category: boundary-only
- active owner file: none
- active module dispatcher branch: none
- active `agent-todo.md` slice: none
- active preset role: none

The current local behavior is honest rejection, not silent no-oping.

## Exact local code map

The fastest read-along path is:

- `src/passes/optimize.mbt:127-132`
  - `pass_registry_boundary_only_names()` includes `"global-type-optimization"`
  - it does **not** include upstream shorthand `"gto"`
- `src/passes/optimize.mbt:307-312`
  - boundary-only names are converted into boundary-only registry entries
- `src/passes/optimize.mbt:517-523`
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with the boundary-only diagnostic
- `src/passes/pass_manager.mbt`
  - there is no `global-type-optimization` dispatcher branch today
- `src/lib/types.mbt:31-159`
  - `AbsHeapType`, `HeapType`, `RefType`, `ValType`, `FieldType`, `Mut`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph a future port must rewrite
- `src/lib/types.mbt:736-743`
  - `StructNew`, `StructNewDefault`, descriptor constructors, `StructGet*`, and `StructSet` are explicit instruction variants already available to a future pass
- `src/lib/types.mbt:4050-4077`
  - constructor helpers already exist for `struct.new`, `struct.get*`, and `struct.set` instructions
- `src/wast/parser.mbt:171-190`
  - WAT `StructFieldDef`, `TypeDefBody::Struct`, and `TypeDefBody::Array` model the type declarations a future port can reuse for fixtures
- `src/wast/parser.mbt:1889-1914`
  - `struct.new*`, `struct.get*`, descriptor operations, and casts already parse into WAST instruction nodes
- `src/wast/lower_to_lib.mbt:271-362`
  - WAT struct field declarations lower to `@lib.FieldType` with `StorageType` plus `Mut`
- `src/wast/lower_to_lib.mbt:2400-2452`
  - `struct.new*` and `struct.get*` lower into `@lib.Instruction` variants
- `src/validate/typecheck.mbt:1976-2185`
  - `struct.new*`, `struct.get*`, and `struct.set` typecheck against resolved struct fields, mutability, packedness, descriptor-bearing constructors, defaultability, and expected reference/value stack types
- `src/binary/decode.mbt:2930-2985`
  - binary GC opcodes decode into `struct.new*`, `struct.get*`, and `struct.set` instruction variants
- `src/binary/encode.mbt:2635-2678`
  - struct access and mutation opcodes encode back to the binary GC opcode space
- `../../no-dwarf-default-optimize-path.md`
  - the canonical open-world no-DWARF path omits `global-type-optimization`
- `../../../../../agent-todo.md`
  - there is currently no dedicated `global-type-optimization` slice

## Why the future port is module-level, not HOT-level

Binaryen `global-type-optimization` rewrites private struct field declarations, repairs affected instructions while old layouts still exist, and then performs a module-wide heap-type remap.
That means the future Starshine shape must own:

- the module's full heap-type inventory
- public versus private visibility classification
- GC and closed-world gates
- exact/inexact field-traffic scanning
- hierarchy-aware propagation through supertypes and subtypes
- JS-interface prototype-field reads for custom descriptors
- field permutation/removal maps
- instruction-before-type rewrite ordering
- side-effect and trap preservation for removed fields
- module-wide type remapping and validation afterward

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

## Validation ladder for the eventual port

### 1. Registry behavior

- keep boundary-only rejection until the transform exists
- once implemented, move the pass out of the boundary-only category in the same change that adds the code path
- keep the CLI spelling and registry status aligned

### 2. Feature and world gates

- no-GC modules should remain unchanged
- closed-world should stay the gating precondition for the real rewrite
- if Starshine chooses a different API shape, the docs must say so explicitly instead of implying Binaryen semantics where they do not exist

### 3. Type-graph positives

Start with the source-backed families from [`./wat-shapes.md`](./wat-shapes.md):

- constructor-only fields that become removable
- fields that become immutable because runtime writes are absent
- parent/child reorder families
- public-parent freeze families
- JS-descriptor keepalive families
- removed-write and module-initializer trap-preservation families

### 4. JS and trap blockers

Prove the negative gates before widening the rewrite:

- custom-descriptor prototype fields
- exact versus inexact boundary propagation
- exported/imported function and table exposure
- trapping removed constructor operands
- atomic RMW / cmpxchg field traffic
- public heap-type visibility boundaries

### 5. Rewrite and repair coverage

- all type uses update consistently
- expression result types remain valid after the rewrite
- field names and subtype layouts stay coherent
- the module still validates after the pass

### 6. Binaryen oracle lanes

- compare the focused fixture set against `wasm-opt --gto`
- keep the comparison targeted to `global-type-optimization` rather than widening to unrelated type passes too early
- only then consider broader closed-world type-cluster replay

## Open design question

The unresolved local architecture question is whether the shared type-graph rewrite machinery should live in a standalone module pass, a reusable closed-world helper, or a small set of coordinated type passes that share analysis and rewrite plumbing.

A faithful port should not duplicate the same module-wide type-graph machinery across `remove-unused-types`, `type-refining`, `type-ssa`, `minimize-rec-groups`, and `unsubtyping`.

## Related pages

- Overview: [`./index.md`](./index.md)
- Binaryen strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Upstream implementation map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Layout / JS / trap guide: [`./field-removal-subtyping-js-interop-and-traps.md`](./field-removal-subtyping-js-interop-and-traps.md)
- Shape catalog: [`./wat-shapes.md`](./wat-shapes.md)
- Current Starshine status: [`./starshine-strategy.md`](./starshine-strategy.md)
- Port-readiness / validation bridge: [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
- Related GC/type passes: [`../global-refining/index.md`](../global-refining/index.md), [`../global-struct-inference/index.md`](../global-struct-inference/index.md), [`../remove-unused-types/index.md`](../remove-unused-types/index.md), [`../type-refining/index.md`](../type-refining/index.md), [`../constant-field-propagation/index.md`](../constant-field-propagation/index.md), [`../unsubtyping/index.md`](../unsubtyping/index.md)
