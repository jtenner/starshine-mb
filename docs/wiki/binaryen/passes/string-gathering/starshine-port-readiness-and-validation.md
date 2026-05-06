---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0526-2026-05-06-string-gathering-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md
  - ../../../raw/research/0431-2026-05-04-string-gathering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md
  - ../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/string_gathering.mbt
  - ../../../../../src/passes/string_gathering_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
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

Use this page after reading the status/code-map page in [`./starshine-strategy.md`](./starshine-strategy.md). That page says what exists today; this page now records which first slices have landed and what remains to validate before preset scheduling.

The 2026-05-04 primary-source recheck in [`../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md) found no teaching-relevant current-`main` drift from the tagged `version_129` contract. The port-readiness plan below therefore keeps [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md) as the tagged oracle and uses the new bridge only for freshness and local code-map anchors.

## Current readiness summary

`string-gathering` is implemented as an active direct Starshine module pass.

Landed local state:

- the no-DWARF wiki and `agent-todo.md` track the pass;
- Starshine has useful `string.const` / `stringrefs` literal infrastructure;
- `src/passes/string_gathering.mbt` owns the direct module rewrite;
- the registry, dispatcher, CLI acceptance, and pass-fuzz harness surfaces are wired;
- focused tests cover direct hoisting, deduplication, global remapping, scan order, no-op behavior, and nested structured bodies;
- the 2026-05-06 refreshed direct lane is green: `.tmp/pass-fuzz-string-gathering` reached 6759 / 10000 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.

Earlier direct debug-artifact compare evidence remains useful historical coverage, but AUD002 is closed by the refreshed harness lane above.

Remaining readiness is late-tail scheduling proof, not direct-pass existence.

## Slice 0: make the public pass spelling honest — landed

### Goal

Expose `string-gathering` as an honest active pass everywhere users and validation tooling expect it.

### Current code anchors

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - active module-pass registry entry
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - module-pass dispatcher arm
- [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
  - explicit CLI acceptance coverage
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
  - compare harness pass allowlist
- [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md#L34-L35`](../../no-dwarf-default-optimize-path.md#L34-L35)
  - canonical late-tail slot before `reorder-globals` and `directize`

### Acceptance criteria

The landed direct pass makes this true:

- `pass_registry_lookup("string-gathering")` returns an active module-pass entry;
- explicit pass requests execute through the module-pass dispatcher;
- CLI and compare tooling accept the pass spelling;
- the wiki and backlog no longer describe the registry omission as current debt.

### Why this matters

This closes the earlier documentation and UX mismatch between the no-DWARF plan and the active pass registry.

## Slice 1: land the direct module-pass owner — landed

### Goal

Create the real late-tail landing zone as a module pass, not as a HOT-only peephole.

### Landed owner shape

The current implementation in [`src/passes/string_gathering.mbt`](../../../../../src/passes/string_gathering.mbt):

- scans whole-module direct string sites with function bodies visited before module expression sites;
- rewrites module-level globals as well as function bodies;
- inserts fresh immutable string globals after imported globals and before existing defined globals;
- keeps the internal reorder validity-first and separate from downstream layout work.

### Landed local surfaces

- dedicated owner file
- active module-pass registry category
- dispatcher integration
- empty/no-string module no-op coverage

### Non-goal for this slice

Do not fuse this with `reorder-globals`. Binaryen deliberately keeps the validity-first reorder in `string-gathering` separate from the stronger final layout work in [`../reorder-globals/index.md`](../reorder-globals/index.md).

## Slice 2: collect exact `string.const` sites by literal payload — landed for direct sites

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
- collect direct `StringConst` sites inside table initializers, defined global initializers, element expressions, data offsets, and function bodies reached by the current raw module walker;
- deduplicate by literal bytes, not by textual spelling or generated section index;
- preserve the original literal payloads exactly.

These direct-site criteria are covered by `src/passes/string_gathering_test.mbt`. Existing-global reuse remains a separate follow-up if future string-heavy oracle inputs require it.

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

Current coverage should prove the landed active state, not the old transition story:

- registry lookup returns an active module-pass entry;
- explicit CLI requests succeed;
- compare-harness pass selection accepts `string-gathering`.

Keep the old transition retired in [`./starshine-strategy.md`](./starshine-strategy.md) and [`../tracker.md`](../tracker.md).

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
- keep the landed direct evidence current (`.tmp/pass-fuzz-string-gathering`, plus older `.tmp/pass-fuzz-string-gathering-genvalid-10000-native`, `.tmp/pass-fuzz-string-gathering-10000-native-keepgoing`, and `.tmp/self-opt-string-gathering-debug` lanes);
- then replay the saved no-DWARF/debug-artifact late-tail path once preset scheduling wiring exists.

## Beginner-to-advanced takeaway

For beginners, `string-gathering` means “turn repeated literal string constants into reads from one immutable string global.”

For advanced Starshine follow-up work, the real checklist is sharper:

- keep registry/dispatcher/CLI/harness truth intact;
- scan exact direct literal sites;
- decide with evidence whether existing direct immutable non-null globals must be reused;
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
