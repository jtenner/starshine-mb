---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md
  - ../../../raw/research/0419-2026-04-27-type-refining-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md
  - ../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./normal-vs-gufa-and-fixups.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./normal-vs-gufa-and-fixups.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
  - ../signature-pruning/index.md
  - ../signature-refining/index.md
  - ../gufa/index.md
---

# Starshine Port Readiness And Validation For `type-refining`

Use this page as the implementation bridge between the source-backed Binaryen dossier and a future Starshine port.
It is intentionally conservative: current Starshine still treats `type-refining` as **boundary-only and unimplemented**, so this page defines the safe first slices and validation ladder rather than pretending parity already exists.

## Current local status checkpoint

Before any implementation work, verify these facts still hold:

- `type-refining` is listed in [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139) as a boundary-only registry name.
- Boundary-only entries are constructed through [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268).
- Active requests are rejected in [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462) with the boundary-only diagnostic.
- The active `optimize` / `shrink` preset arrays in [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263) and [`src/passes/optimize.mbt#L384-L413`](../../../../../src/passes/optimize.mbt#L384-L413) omit `type-refining`.
- There is no `src/passes/type_refining.mbt` owner file today.
- The upstream sibling `type-refining-gufa` is documented in this folder, but is not a separate Starshine registry spelling today.

Those facts are not incidental. They are the honest executable status until a real module/type-section pass lands.

## Why an analyzer-first slice is the right first step

Binaryen changes declared private struct field types, then repairs every affected read and write.
That is not a local expression peephole.
A premature mutating port would have to solve field evidence, public/private visibility, subtype legality, type-section rewriting, read repair, write repair, and final validation all at once.

A safer first slice is a **no-rewrite analyzer** that reports the same candidate and bailout families a future mutating pass will need:

| Analyzer result | What it should prove | Why it matters |
| --- | --- | --- |
| GC/world gate | module has GC features and an explicit closed-world mode | Binaryen hard-gates on both; Starshine has no implicit open-world equivalent |
| private struct candidate | heap type is private and not ABI-visible | public types must stay frozen |
| array bailout | array types are ignored | Binaryen still marks arrays as TODO for this pass |
| direct write evidence | `struct.new`, `struct.new_default`, and `struct.set` values can be classified per field | normal `type-refining` is write/default/copy-driven |
| ordinary-read non-evidence | `struct.get` alone does not widen inferred contents | reads are repaired later; they do not constrain inference |
| hierarchy status | supertype/subtype field constraints remain legal after refinement | mutable field equality and subtype field covariance are correctness constraints |
| repair requirement | each affected read/write is valid, cast-repairable, null-bottom-repairable, or trap-repairable | declaration rewriting without instruction repair can create invalid modules |
| GUFA-only marker | candidate needs locals/globals/calls/cycles beyond direct struct traffic | base `type-refining` and `type-refining-gufa` must not be conflated |

The analyzer can validate the future implementation's shape coverage without mutating the module yet.
It should have tests that assert both positive candidate summaries and explicit bailout reasons.

## First mutating slice

After the analyzer is trustworthy, the smallest useful mutating slice should be deliberately narrow:

1. Keep the pass disabled outside explicit closed-world mode.
2. Support only private struct types.
3. Support only fields whose candidate type comes from direct `struct.new`, `struct.new_default`, and direct `struct.set` evidence.
4. Ignore arrays completely.
5. Ignore GUFA-only candidates.
6. Refuse candidates that require global-initializer write repair.
7. Run hierarchy legality before any declaration rewrite.
8. Retag `struct.get` results when the refined field type is still readable.
9. Replace impossible reads with `drop(ref); unreachable` only when that preserves the source trap semantics from the Binaryen strategy pages.
10. Rewrite the private field declaration.
11. Repair too-broad `struct.new` / `struct.set` operands with explicit casts or bottom/null/trap forms only where Starshine validation already proves the shape.
12. Run full module validation after mutation.

This slice is not full Binaryen parity. It is a safe local foothold that maps directly to the source-backed positive shapes in [`./wat-shapes.md`](./wat-shapes.md).

## Shape-to-validation checklist

Use the following cases as the first fixture ladder.
When text WAT cannot express a case locally because `struct.set` parsing/lowering is still missing, build the fixture through the library or binary path and keep that caveat in the test name.

| Fixture family | Expected local behavior | Source-backed page |
| --- | --- | --- |
| no-GC module | unchanged / rejected according to pass API | [`./binaryen-strategy.md`](./binaryen-strategy.md) |
| open-world module | unchanged / rejected according to explicit closed-world API | [`./binaryen-strategy.md`](./binaryen-strategy.md) |
| private struct, field always written with child subtype | field narrows when hierarchy remains legal | [`./wat-shapes.md`](./wat-shapes.md) |
| private struct, `struct.new_default` nullable ref field | nullable-bottom/default evidence is modeled without keeping the old wide type unnecessarily | [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md) |
| public/exported heap type | declaration stays unchanged | [`./wat-shapes.md`](./wat-shapes.md) |
| direct read after refinement | `struct.get` result type is repaired | [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md) |
| read whose old type cannot survive the new field type | read becomes trap-equivalent `drop + unreachable` | [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md) |
| too-broad write after field narrows | write gets a validating cast or safe bottom/trap repair | [`./binaryen-strategy.md`](./binaryen-strategy.md) |
| same-field copy positive | direct copy evidence can refine | [`./wat-shapes.md`](./wat-shapes.md) |
| tee / `br_if` copy boundary | normal mode remains conservative | [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md) |
| locals/globals/calls/cycles inference win | base pass marks GUFA-only instead of rewriting | [`../gufa/index.md`](../gufa/index.md) |
| arrays | no rewrite | [`./binaryen-strategy.md`](./binaryen-strategy.md) |

## Starshine code surfaces to wire

A future port will need new owner code, but these existing surfaces are the current read-along map:

- registry and active-pass plumbing
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139) for the current boundary-only spelling
  - [`src/passes/optimize.mbt#L240-L268`](../../../../../src/passes/optimize.mbt#L240-L268) for active preset omission and boundary-only entry construction
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462) for the active request guard
- type and instruction representation
  - [`src/lib/types.mbt#L31-L159`](../../../../../src/lib/types.mbt#L31-L159) for heap/ref/field/type-section structures
  - [`src/lib/types.mbt#L720-L764`](../../../../../src/lib/types.mbt#L720-L764) for GC instruction variants including `StructNew*`, `StructGet*`, and `StructSet`
  - [`src/lib/types.mbt#L4060-L4079`](../../../../../src/lib/types.mbt#L4060-L4079) for constructor helpers
- WAT fixture caveat
  - [`src/wast/parser.mbt#L171-L190`](../../../../../src/wast/parser.mbt#L171-L190) models struct fields and types
  - [`src/wast/parser.mbt#L1889-L1914`](../../../../../src/wast/parser.mbt#L1889-L1914) parses many struct ops, but no local `struct.set` keyword path was found in this run
  - [`src/wast/lower_to_lib.mbt#L2400-L2452`](../../../../../src/wast/lower_to_lib.mbt#L2400-L2452) lowers struct constructors and reads; direct mutation fixtures may need library/binary construction first
- validation and binary coherence
  - [`src/validate/env.mbt#L134-L154`](../../../../../src/validate/env.mbt#L134-L154) resolves type references in the validation environment
  - [`src/validate/typecheck.mbt#L2075-L2185`](../../../../../src/validate/typecheck.mbt#L2075-L2185) validates struct constructors, reads, and writes
  - [`src/validate/typecheck.mbt#L3261-L3285`](../../../../../src/validate/typecheck.mbt#L3261-L3285) dispatches GC instruction validators
  - [`src/binary/decode.mbt#L2930-L2985`](../../../../../src/binary/decode.mbt#L2930-L2985) decodes GC struct opcodes
  - [`src/binary/encode.mbt#L2635-L2678`](../../../../../src/binary/encode.mbt#L2635-L2678) encodes GC struct opcodes

## Binaryen oracle lanes

Once Starshine has a mutating slice, compare against Binaryen in progressively larger lanes:

1. Handwritten closed-world GC fixtures for direct struct-field positives and public-type negatives.
2. `--type-refining --closed-world` against Binaryen for base-pass fixtures.
3. Negative comparison against `--type-refining-gufa --closed-world` to show which wins are intentionally GUFA-only.
4. RMW/cmpxchg and exactness fixtures from the official lit family after Starshine can represent the relevant atomics and exact/custom-descriptor surface.
5. Fuzz lanes only after the type-section rewrite and validation repair are stable enough to diagnose mismatches.

Keep the command names explicit: Binaryen exposes both `type-refining` and `type-refining-gufa`; Starshine currently exposes only boundary-only `type-refining`.

## Health guardrails for future edits

- Do not move this pass into active presets until Starshine has a real closed-world option and a validated module/type-section rewrite.
- Do not describe GUFA-only inference as an optional aggressiveness flag for the base pass.
- Do not teach reads as inference constraints; they are repair targets.
- Do not imply arrays are supported by Binaryen's `type-refining` until the upstream TODO changes and the raw source manifest is refreshed.
- Keep the WAT `struct.set` fixture caveat visible until local parser/lowerer support exists.
- Update [`./starshine-strategy.md`](./starshine-strategy.md), [`../tracker.md`](../tracker.md), [`../index.md`](../index.md), and the top-level [`../../../index.md`](../../../index.md) whenever implementation status changes.

## Bottom line

`type-refining` is ready for a careful Starshine implementation plan, not for a one-shot HOT rewrite.
The safest path is analyzer first, then a narrow closed-world private-struct mutating slice, then hierarchy/read/write repair, then optional GUFA-sibling work after shared contents-oracle infrastructure exists.
