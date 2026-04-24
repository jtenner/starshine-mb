---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/tests.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../strings/string-const-surface.md
  - ../../../../../docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../reorder-globals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
  - ../../../strings/string-const-surface.md
---

# Starshine Strategy For `string-gathering`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already matter, and the practical landing zone for a future port.

## The honest current status

`string-gathering` is still **unimplemented** in Starshine.
There is no `src/passes/string_gathering.mbt` owner file today.

There is also one important local wrinkle that was easy to miss before this follow-up:

- `src/passes/optimize.mbt:127` `pass_registry_boundary_only_names()` does **not** include `"string-gathering"`
- `src/passes/optimize.mbt:144` `pass_registry_removed_names()` also does **not** include `"string-gathering"`

So the current local story is not “the pass name is preserved and honestly rejected.”
It is:

- the pass is documented in the wiki and backlog
- the pass is part of the recorded Binaryen no-DWARF late tail
- the underlying `string.const` plumbing already exists in code
- but the public pass spelling still has **registry bookkeeping debt**

That is the most important current-status fact for future readers.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

### Scheduler and backlog truth

- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
  - the late no-DWARF post-pass sequence still records `string-gathering` between `remove-unused-module-elements` and `reorder-globals`
- `agent-todo.md:556`
  - `[SG]001 - String Collection and Canonicalization Rules`
- `agent-todo.md:559`
  - `[SG]002 - Feature Gate, Global Order, and Artifact Parity`

### Current registry truth

- `src/passes/optimize.mbt:127`
  - `pass_registry_boundary_only_names()`
- `src/passes/optimize.mbt:144`
  - `pass_registry_removed_names()`

Those two functions are worth reading directly because they make the current bookkeeping gap concrete: the pass is planned, but its spelling is not yet tracked in the registry surface.

### Current string-literal implementation surfaces that a future port would build on

- `src/binary/encode.mbt:72`
  - `with_binary_encode_stringrefs_context(...)`
- `src/binary/encode.mbt:87`
  - `encode_string_const_index(...)`
- `src/binary/encode.mbt:1580`
  - `encode_module_stringrefs(...)`
- `src/binary/decode.mbt:148`
  - `with_binary_decode_stringrefs_context(...)`
- `src/binary/decode.mbt:160`
  - `decode_string_const_literal(...)`
- `src/binary/tests.mbt:1817`
  - `module roundtrip preserves string.const literals and stringrefs section`
- `src/wast/lower_to_lib.mbt:7238`
  - `wast_to_binary_module lowers string.const literals`
- [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md)
  - the durable local wiki page for the current `string.const` surface

### Exact neighboring pass dossier

- [`../reorder-globals/index.md`](../reorder-globals/index.md)
  - the immediate downstream late-tail neighbor that should stay separate from `string-gathering`

That map is the main practical value of this page: readers can now jump directly from the upstream algorithm to the current local status, the real current code, and the next implementation boundary.

## What Starshine currently does have

Even without a pass owner file, the repo already has meaningful implementation pieces.

### 1. Stable `string.const` / `stringrefs` roundtrip plumbing

The encoder and decoder already preserve literal identity through the real binary stringrefs section.

The key code points are:

- `src/binary/encode.mbt:1580` `encode_module_stringrefs(mod_)`
  - collects unique `string.const` payloads deterministically across module globals and code
- `src/binary/encode.mbt:87` `encode_string_const_index(...)`
  - maps a literal payload back to its section index while encoding instructions
- `src/binary/decode.mbt:160` `decode_string_const_literal(...)`
  - resolves encoded indices back to literal bytes on decode

This is not `string-gathering` yet.
But it is the exact local infrastructure that makes a future `string-gathering` port possible without first reinventing literal identity.

### 2. Locked tests for literal lowering and binary roundtrip

The repo already has focused tests proving that string literals survive the current front-end and binary surfaces:

- `src/wast/lower_to_lib.mbt:7238`
  - WAST lowering keeps `string.const` literals intact
- `src/binary/tests.mbt:1817`
  - binary encode/decode roundtrip preserves `string.const` literals and the stringrefs section

Those tests matter for a future pass because Binaryen `string-gathering` deduplicates by literal payload.
If Starshine loses literal identity earlier, the later pass cannot match the upstream contract.

### 3. A real backlog and scheduler story

The pass is not just a vague someday idea.
The repo already has:

- a recorded late-tail slot in the no-DWARF pipeline doc
- explicit backlog slices `[SG]001` and `[SG]002`
- a neighboring `reorder-globals` dossier that already assumes `string-gathering` should run first

So current Starshine strategy is not “ignore this pass.”
It is “finish the registry surface, then build the late module pass on top of the already-landed string literal infrastructure.”

## What Starshine does **not** have yet

A future contributor should be careful not to overread the existing code.
Starshine does **not** currently have:

- a registry entry for `string-gathering` in `src/passes/optimize.mbt`
- a dedicated pass owner file such as `src/passes/string_gathering.mbt`
- pass-specific CLI or dispatcher coverage for the public spelling
- late-module rewrite logic that scans the module and rewrites repeated `string.const` uses into canonical global gets
- integration tests that check the `string-gathering -> reorder-globals` interaction

So the current repo status is best summarized as:

- literal plumbing exists
- backlog exists
- scheduler knowledge exists
- public pass registry wiring still missing
- transform itself still missing

## The right future Starshine implementation shape

The current docs and code strongly suggest that a future local `string-gathering` port should be taught as a **late module pass built on existing literal-plumbing infrastructure**, not as more parser/encoder work and not as a merged `reorder-globals` port.

A good local design ladder is:

1. add the upstream spelling to the registry surface in `src/passes/optimize.mbt`
2. add a dedicated module-pass owner file
3. scan the whole module for direct `string.const` uses
4. preserve exact literal identity using the already-landed binary/lib plumbing
5. create or reuse canonical defining string globals
6. keep the reorder narrow and validity-first
7. leave final layout quality to the later `reorder-globals` pass

That last split matters.
The neighboring dossier already documents that Binaryen keeps these as separate responsibilities.
A local port that fuses them too early would be harder to compare and harder to teach.

## The most important local dependency boundary

### `string-gathering` should sit on top of current literal identity support

See [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md) plus:

- `src/binary/encode.mbt:72`, `:87`, `:1580`
- `src/binary/decode.mbt:148`, `:160`
- `src/binary/tests.mbt:1817`
- `src/wast/lower_to_lib.mbt:7238`

Why it matters:

- Binaryen groups by literal payload, not by parser spelling or section index accident
- Starshine already has the exact literal payload preserved through lowering, validation, binary encode, and decode
- a future pass should reuse that infrastructure instead of creating a second string-identity mechanism

### `string-gathering` should remain separate from `reorder-globals`

See [`../reorder-globals/index.md`](../reorder-globals/index.md).

Why it matters:

- Binaryen uses `string-gathering` for canonical defining globals and only the minimum reorder needed for validity
- `reorder-globals` then does the stronger whole-global ordering work
- the local backlog and scheduler docs already teach this as two late-tail steps, not one combined pass

That makes `reorder-globals` the key immediate downstream neighbor for future work.

## Validation plan for the eventual port

The current code and docs imply the right validation ladder.
A future real implementation should validate in this order:

1. focused string-global shape tests
   - repeated function-body literals
   - reusable immutable direct string globals
   - nullable and mutable non-reuse
   - preserved defining-initializer slots
2. module-level string user tests
   - global initializer users
   - any other supported module-expression users Starshine chooses to cover explicitly
3. late-tail interaction tests
   - `string-gathering` before `reorder-globals`
   - feature-gated behavior when strings are disabled
4. artifact and oracle comparison
   - the backlog already names this explicitly in `[SG]002`

That is a much clearer local plan than “compare with Binaryen later,” because it points directly at the real code surfaces already present in this repo.

## Bottom line

Current Starshine `string-gathering` strategy is honest backlog-plus-plumbing with one real bookkeeping gap:

- the late-tail scheduler and backlog already know the pass
- the encoder, decoder, and tests already preserve the literal identity the pass depends on
- the pass is still unimplemented
- the pass spelling is still missing from the public pass registry surface in `src/passes/optimize.mbt`
- the future landing zone is a dedicated late module pass that composes with, but does not merge into, `reorder-globals`

So the right mental model today is not “nothing exists locally.”
It is:

- **literal infrastructure exists**
- **backlog intent exists**
- **registry entry still missing**
- **transform still missing**
- **future boundary with `reorder-globals` is already clear**
