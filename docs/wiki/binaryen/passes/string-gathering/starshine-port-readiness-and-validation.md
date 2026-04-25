---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md
  - ../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../reorder-globals/index.md
  - ../string-lowering/index.md
  - ../string-lifting/index.md
  - ../../../strings/string-const-surface.md
---

# Starshine port readiness and validation for `string-gathering`

Use this page after reading the status/code-map page in [`./starshine-strategy.md`](./starshine-strategy.md). That page says what exists today; this page says what the first faithful Starshine slices should look like and how to validate them.

The 2026-04-25 primary-source bridge in [`../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md`](../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md) found no teaching-relevant current-`main` drift from the tagged `version_129` contract. The port-readiness plan below therefore keeps [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md) as the tagged oracle and uses the new bridge only for freshness and local code-map anchors.

## Current readiness summary

`string-gathering` is **not implemented** in Starshine.

Current local state is still unusual compared with many other late-tail pass gaps:

- the no-DWARF wiki and `agent-todo.md` track the pass;
- Starshine has useful `string.const` / `stringrefs` literal infrastructure;
- but the public pass registry does **not** list `string-gathering` as boundary-only or removed yet.

So the first useful local slice is not the full rewrite. It is registry honesty.

## Slice 0: make the public pass spelling honest

### Goal

Teach Starshine that `string-gathering` is a known upstream/local-planned pass before any transform lands.

### Current code anchors

- [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
  - `pass_registry_boundary_only_names()` lists many no-DWARF and late-boundary pass names, but currently omits `string-gathering`.
- [`src/passes/optimize.mbt#L144-L151`](../../../../../src/passes/optimize.mbt#L144-L151)
  - `pass_registry_removed_names()` also omits `string-gathering`.
- [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md#L34-L35`](../../no-dwarf-default-optimize-path.md#L34-L35)
  - the canonical post-pass phase still includes `string-gathering` before `reorder-globals` and `directize`.
- [`agent-todo.md#L563-L577`](../../../../../agent-todo.md#L563-L577)
  - the `SG` slice already tracks string collection, canonicalization, feature gating, global order, and artifact parity.

### Acceptance criteria

Before implementing the transform, a small registry-only change should make this true:

- `pass_registry_lookup("string-gathering")` returns a known entry;
- explicit pass requests fail with the same boundary-only message used by other planned-but-unimplemented late passes;
- `--help` / registry listing behavior stays consistent with whatever boundary-only policy the optimizer registry currently uses;
- the wiki and tracker stop describing the registry omission as current debt.

### Why this matters

Without this slice, users and future agents see `string-gathering` in the no-DWARF path and backlog but get an unknown-pass failure from the active registry. That is a documentation/UX mismatch, not a Binaryen strategy question.

## Slice 1: add a minimal module-pass owner with no rewrite drift

### Goal

Create the future landing zone without changing module behavior prematurely.

### Suggested owner shape

A future implementation should be a late **module pass**, not a HOT-only peephole:

- Binaryen scans whole-module string sites;
- it rewrites module-level globals as well as function bodies;
- it may reorder global declarations for validity;
- it must run immediately before `reorder-globals` in the no-DWARF tail.

### Minimum local surfaces to wire

- a dedicated pass owner file, likely `src/passes/string_gathering.mbt`;
- registry category change from boundary-only to module pass when behavior exists;
- dispatcher integration in the same style as other module passes;
- tests proving empty/no-string modules remain byte-equivalent or structurally unchanged.

### Non-goal for this slice

Do not fuse this with `reorder-globals`. Binaryen deliberately keeps the validity-first reorder in `string-gathering` separate from the stronger final layout work in [`../reorder-globals/index.md`](../reorder-globals/index.md).

## Slice 2: collect exact `string.const` sites by literal payload

### Goal

Match Binaryen's exact-slot mental model closely enough that later rewrites cannot accidentally revisit or miss defining initializers.

### Existing Starshine prerequisites

- [`src/wast/lower_to_lib.mbt#L2389`](../../../../../src/wast/lower_to_lib.mbt#L2389)
  - WAT `string.const` lowers to `Instruction::string_const(bytes)`.
- [`src/wast/lower_to_lib.mbt#L7238-L7262`](../../../../../src/wast/lower_to_lib.mbt#L7238-L7262)
  - focused test proves lowered global and function string constants validate.
- [`src/binary/encode.mbt#L72-L103`](../../../../../src/binary/encode.mbt#L72-L103)
  - encode-time stringrefs context and literal-to-index lookup.
- [`src/binary/encode.mbt#L1578-L1645`](../../../../../src/binary/encode.mbt#L1578-L1645)
  - deterministic collection of unique `string.const` payloads across current global/code surfaces.
- [`src/binary/decode.mbt#L148-L171`](../../../../../src/binary/decode.mbt#L148-L171)
  - decode-time stringrefs context and index-to-literal lookup.
- [`src/binary/decode.mbt#L3078-L3082`](../../../../../src/binary/decode.mbt#L3078-L3082)
  - binary opcode decode back to `Instruction::string_const(literal)`.

### Acceptance criteria

- collect every direct `Instruction::StringConst(bytes)` in defined function bodies;
- collect direct `StringConst` sites inside defined global initializers;
- decide and document whether Starshine's first slice supports other module-expression surfaces immediately or defers them explicitly;
- deduplicate by literal bytes, not by textual spelling or generated section index;
- preserve the original literal payloads exactly.

### Caveat

Binaryen source covers broad `walkModuleCode(...)` surfaces, while its dedicated lit file most directly proves global-initializer behavior. A Starshine first slice may start with functions plus globals, but any narrower choice must be documented as a temporary local subset.

## Slice 3: choose defining globals with Binaryen-compatible eligibility

### Goal

Preserve the upstream definition of a reusable canonical global.

### Reusable global checklist

A Starshine reusable defining global should be all of:

- defined, not imported;
- immutable;
- exact non-null `stringref` / `(ref string)` shape;
- direct `string.const` initializer;
- first matching reusable global in module order for that literal.

### Reject as reusable, even if they contain the same literal

- imported globals;
- mutable globals;
- nullable string globals;
- globals whose initializer only contains a nested string constant;
- globals already reading another global with `global.get`.

### Acceptance criteria

Reduced tests should cover:

- fresh canonical global creation for repeated body literals;
- reuse of an existing direct immutable non-null string global;
- first-match reuse when multiple direct immutable globals have the same literal;
- non-reuse for mutable and nullable globals;
- non-reuse for nested initializer expressions.

## Slice 4: rewrite non-defining literal sites to `global.get`

### Goal

Replace ordinary string constants with reads from the canonical defining global while preserving defining initializers.

### Key invariant

If an existing global is selected as the defining global, its own direct `string.const` initializer must remain a `string.const`. Otherwise the pass can accidentally create a self-referential `global.get` initializer.

### Acceptance criteria

- every non-defining collected `string.const` site for a literal becomes `global.get` of that literal's canonical global;
- selected defining initializers stay direct `string.const`;
- preexisting `global.get` users are not rewritten or treated as defining literals;
- result types remain valid without pretending this is full `string-lowering`.

## Slice 5: perform only validity-first global reorder

### Goal

Move canonical defining string globals early enough that rewritten global initializers validate.

### Correct boundary

This pass should only repair validity. It should not become a final global layout optimizer.

Use these pages together:

- [`./reuse-naming-and-ordering.md`](./reuse-naming-and-ordering.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)

### Acceptance criteria

- a global initializer containing `string.const` can rewrite to `global.get` of the canonical defining global;
- the defining global appears before that rewritten user;
- the reorder is stable outside the required defining-before-user repair;
- later `reorder-globals` remains responsible for final layout heuristics.

## Slice 6: scheduler and feature-gate parity

### Goal

Match Binaryen's late-tail placement and strings-feature gating.

### Source-backed scheduler facts

- Binaryen runs `string-gathering` only at sufficient optimize level and when strings are enabled.
- The canonical no-DWARF Starshine parity path places it between `remove-unused-module-elements` and `reorder-globals`.
- Full `string-lowering` is a related sibling/superset, not the same pass.

### Acceptance criteria

- explicit `--pass string-gathering` runs only after the pass is implemented;
- preset integration keeps the `remove-unused-module-elements -> string-gathering -> reorder-globals` order;
- strings-disabled modules skip or reject consistently with the chosen local policy and Binaryen parity target;
- tests prove the pass does not accidentally perform full [`../string-lowering/index.md`](../string-lowering/index.md) or reverse [`../string-lifting/index.md`](../string-lifting/index.md) work.

## Validation ladder

### 1. Unit/reduced module tests beside the implementation

Cover the direct official shape families first:

- repeated function-body literals;
- existing immutable direct string global reuse;
- mutable and nullable global non-reuse;
- first reusable global in module order;
- nested global-initializer users;
- validity-first global movement;
- no-op for modules without string constants.

### 2. Registry and CLI request tests

Cover the transition from current registry debt to honest unimplemented status and then to implemented status:

- unknown today;
- boundary-only rejection after Slice 0;
- module-pass success after the transform lands.

Keep this transition documented in [`./starshine-strategy.md`](./starshine-strategy.md) and [`../tracker.md`](../tracker.md).

### 3. Late-tail integration tests

Run the pass in the real neighborhood:

```text
remove-unused-module-elements -> string-gathering -> reorder-globals -> directize
```

The most important checks are:

- gathered globals still validate before and after `reorder-globals`;
- `directize` remains a separate downstream pass;
- string-related globals are not accidentally pruned by the preceding remove-unused pass.

### 4. Oracle and artifact comparison

Use the backlog's `[SG]002` intent:

- compare focused reduced modules against Binaryen `--string-gathering`;
- then replay the saved no-DWARF/debug-artifact late-tail path once registry and scheduler wiring exist.

## Beginner-to-advanced takeaway

For beginners, `string-gathering` means “turn repeated literal string constants into reads from one immutable string global.”

For advanced Starshine port work, the real checklist is sharper:

- fix registry honesty first;
- scan exact literal sites;
- reuse only direct immutable non-null defining globals;
- preserve defining initializer slots;
- rewrite other direct literals to `global.get`;
- reorder only enough for validity;
- keep final layout in `reorder-globals`;
- validate with feature-gated late-tail oracle comparison.

## Sources

- [`../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md`](../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md)
- [`../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md`](../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md)
- [`../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md`](../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
