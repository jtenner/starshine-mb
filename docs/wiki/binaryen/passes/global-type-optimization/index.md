---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md
  - ../../../raw/research/0467-2026-05-05-global-type-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md
  - ../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../global-refining/binaryen-strategy.md
  - ../global-struct-inference/binaryen-strategy.md
  - ../remove-unused-types/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./field-removal-subtyping-js-interop-and-traps.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
  - ../index.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
  - ../remove-unused-types/index.md
---

# `global-type-optimization`

## Role

- `global-type-optimization` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); follow the exact local status in [`./starshine-strategy.md`](./starshine-strategy.md).
- Upstream Binaryen `pass.cpp` registers the short CLI name:
  - `gto`
- The local tracker and registry use the fuller descriptive name:
  - `global-type-optimization`
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `globally optimize GC types`

That summary is true, but too small.

A better beginner summary is:

- Binaryen scans private struct-field traffic across related GC heap types,
- makes fields immutable when no runtime write reaches them,
- removes unread fields when subtype layout still permits it,
- rewrites affected `struct.*` instructions before changing the type graph,
- and preserves JS-visible descriptor prototype fields plus runtime or instantiation-time trap behavior while doing so.

So this is not generic GC type inference.
It is **closed-world private-struct mutability and layout cleanup**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `global-type-optimization` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `global-refining`, `remove-unused-types`, and `global-struct-inference` dossiers already record it as a real closed-world scheduler neighbor.
- `agent-todo.md` still has **no dedicated `global-type-optimization` slice**, so a stable wiki home matters even more here.
- The official implementation hides several teaching traps that deserve an explicit dossier:
  - upstream uses the short CLI alias `gto` while local docs track the full name
  - the pass body itself hard-requires `--closed-world`
  - it does **not** refine field value types
  - constructor traffic does **not** keep fields alive or mutable in the actual decision phase
  - subtype layout compatibility and JS-descriptor exposure both constrain removals
  - removed writes and removed module-initializer operands still must preserve side effects and traps

## Most important durable takeaways

- `global-type-optimization` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** after `global-refining`.
- The pass body itself checks:
  - GC features enabled
  - `--closed-world` enabled, or else it throws a fatal error
- The pass only optimizes **private struct types**.
- The pass changes **mutability** and **field presence/order**, not field value types.
- The actual decision logic is driven by runtime `struct.set` / `struct.get` / atomic field traffic and JS-exposure rules, not by `struct.new` traffic.
- Field removal is hierarchy-aware and may reorder parent fields so children can still append compatible layouts.
- Instruction rewrite happens before type rewrite.
- Removed writes preserve value side effects and null-trap ordering, and removed trapping module-initializer operands become fresh globals.
- A 2026-05-05 current-main recheck, captured in [`../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-global-type-optimization-current-main-recheck.md), plus the earlier 2026-04-24 primary-source manifest, found no teaching-relevant drift in the reviewed owner, registration, helper, or lit surfaces beyond the existing `version_129` contract.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen globally improves GC heap types.

The safer mental model is:

- Binaryen looks only at **private struct fields**,
- decides whether those fields can become immutable or disappear,
- keeps subtype layout valid while doing so,
- protects JS-visible prototype fields on descriptors,
- repairs affected instructions before changing the type graph,
- and then rebuilds private struct types plus all remaining type uses consistently.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a broad GC-type optimizer

What it actually is in `version_129`:

- a closed-world, private-struct-only module pass with:
  - field read/write tracking
  - subtype-safe immutability and removal reasoning
  - JS prototype exposure handling for custom descriptors
  - side-effect and trap preservation during field removal
  - field-name repair and whole-module type remapping

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, and the exact phase order.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `GlobalTypeOptimization.cpp`, `struct-utils.h`, `type-updating.*`, `js-utils.h`, and the official lit roster, plus the narrow current-`main` freshness note.
- [`./field-removal-subtyping-js-interop-and-traps.md`](./field-removal-subtyping-js-interop-and-traps.md)
  - Focused guide to the hardest half of the pass: subtype-layout constraints, public-parent limits, JS-exposed descriptor prototype fields, and trap-preserving instruction rewrites.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering immutability positives, unread-field removals, subtype reordering, JS-descriptor keepalive cases, and the main bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and future-port map: boundary-only local registry entry, no `gto` alias, no owner file, active request rejection, preset omission, reusable GC/type/parser/validator/binary surfaces, and the module/type-graph infrastructure a faithful port would need.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Future-port bridge for the exact local code map, validation ladder, and Binaryen oracle lanes a real module/type-graph implementation would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `global-type-optimization` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep the upstream/local naming split explicit:
  - `gto` upstream
  - `global-type-optimization` in the local registry/tracker
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md)
- [`../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md`](../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md`](../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../global-refining/binaryen-strategy.md`](../global-refining/binaryen-strategy.md)
- [`../global-struct-inference/binaryen-strategy.md`](../global-struct-inference/binaryen-strategy.md)
- [`../remove-unused-types/binaryen-strategy.md`](../remove-unused-types/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalTypeOptimization.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/permutations.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalTypeOptimization.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto_and_cfp_in_O.wast>
