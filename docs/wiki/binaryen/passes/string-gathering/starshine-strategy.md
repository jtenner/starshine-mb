---
kind: concept
status: supported
last_reviewed: 2026-05-19
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
  - ../../../../../src/binary/tests.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../strings/string-const-surface.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../reorder-globals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-globals/index.md
  - ../../../strings/string-const-surface.md
---

# Starshine Strategy For `string-gathering`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md) and the 2026-05-04 current-main recheck in [`../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already matter, and the practical landing zone for remaining late-tail work. For the validation ladder, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`string-gathering` is now an active direct Starshine module pass.

The current implementation:

- lives in [`src/passes/string_gathering.mbt`](../../../../../src/passes/string_gathering.mbt)
- is registered as a module pass in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- dispatches through [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- is accepted by the CLI and compare harness through [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) and [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)

It collects direct `string.const` payloads from defined function bodies first, then module-level expression sites; deduplicates by literal bytes; sorts the deduplicated literal list for deterministic fresh-global creation; reuses eligible existing immutable non-null direct string globals as canonical definitions while preserving reusable-global module order; creates immutable string globals for literals without a reusable definition; rewrites gathered non-defining sites to `global.get`; aliases later matching globals; and remaps existing defined-global traffic around the validity-first global order.

Direct revalidation evidence:

- `moon info`, `moon fmt`, `moon test src/passes`, and full `moon test` passed on 2026-05-18 after existing-global reuse and ordering fixes landed.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass string-gathering --out-dir .tmp/pass-fuzz-string-gathering-order-20260518` reached 6759 / 10000 compared cases, 6759 normalized matches, 0 semantic mismatches, 0 validation failures, 0 generator failures, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.

Remaining caveats:

- existing-global reuse is now covered for the direct immutable non-null `string.const` shape, including first-match reuse, reusable-global module order, sorted fresh literals, imported-global non-reuse, nested-initializer non-reuse, and later-alias behavior;
- nullable string global non-reuse is known from Binaryen but locally hard to test because Starshine's current `ValType::stringref()` representation is the nullable abstract string ref shape (`AbsHeapTypeRefType(String)`), so the exact nullable/non-null stringref distinction is not expressible cleanly in this pass fixture today;
- binary decoding of some standalone string-proposal type encodings remains outside this pass and can fail before the pass runs;
- public `optimize` / `shrink` presets now append `string-gathering -> reorder-globals -> directize`; after regenerating `tests/node/dist/starshine-debug-wasi.wasm` with `moon build --target wasm`, targeted replay reached canonical wasm equality and normalized WAT equality.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

### Scheduler and backlog truth

- [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md#L34-L35`](../../no-dwarf-default-optimize-path.md#L34-L35)
  - the late no-DWARF post-pass sequence still records `string-gathering` between `remove-unused-module-elements` and `reorder-globals`
- [`agent-todo.md#L563-L569`](../../../../../agent-todo.md#L563-L569)
  - `[SG]001 - String Collection and Canonicalization Rules`
- [`agent-todo.md#L570-L577`](../../../../../agent-todo.md#L570-L577)
  - `[SG]002 - Feature Gate, Global Order, and Artifact Parity`

### Current registry and dispatcher truth

- [`src/passes/string_gathering.mbt#L573-L601`](../../../../../src/passes/string_gathering.mbt#L573-L601)
  - module-pass implementation and rewrite entry point
- [`src/passes/string_gathering_test.mbt#L37-L43`](../../../../../src/passes/string_gathering_test.mbt#L37-L43)
  - registry lookup test
- [`src/passes/string_gathering_test.mbt#L48-L57`](../../../../../src/passes/string_gathering_test.mbt#L48-L57)
  - no-op behavior test
- [`src/passes/optimize.mbt#L259-L259`](../../../../../src/passes/optimize.mbt#L259-L259)
  - active module-pass registry entry
- [`src/passes/pass_manager.mbt#L8709-L8709`](../../../../../src/passes/pass_manager.mbt#L8709-L8709)
  - module-pass dispatcher arm
- [`src/cmd/cmd_wbtest.mbt#L4170-L4201`](../../../../../src/cmd/cmd_wbtest.mbt#L4170-L4201)
  - explicit CLI/module-pass acceptance coverage

The old registry-bookkeeping gap is closed for direct pass execution.

### Current owner and scan anchors

- [`src/passes/string_gathering.mbt#L2-L3`](../../../../../src/passes/string_gathering.mbt#L2-L3)
  - public summary string and pass spelling
- [`src/passes/string_gathering.mbt#L160-L166`](../../../../../src/passes/string_gathering.mbt#L160-L166)
  - function-body-before-module-code collection order

### Current string-literal implementation surfaces that a future port would build on

- [`src/binary/encode.mbt#L72-L103`](../../../../../src/binary/encode.mbt#L72-L103)
  - `with_binary_encode_stringrefs_context(...)` and `encode_string_const_index(...)`
- [`src/binary/encode.mbt#L1578-L1645`](../../../../../src/binary/encode.mbt#L1578-L1645)
  - `encode_module_stringrefs(...)`
- [`src/binary/decode.mbt#L148-L171`](../../../../../src/binary/decode.mbt#L148-L171)
  - `with_binary_decode_stringrefs_context(...)` and `decode_string_const_literal(...)`
- [`src/binary/decode.mbt#L3078-L3082`](../../../../../src/binary/decode.mbt#L3078-L3082)
  - binary opcode decode back to `Instruction::string_const(literal)`
- [`src/binary/tests.mbt#L1817-L1854`](../../../../../src/binary/tests.mbt#L1817-L1854)
  - `module roundtrip preserves string.const literals and stringrefs section`
- [`src/wast/lower_to_lib.mbt#L2389`](../../../../../src/wast/lower_to_lib.mbt#L2389)
  - WAT string literal lowering to `Instruction::string_const(bytes)`
- [`src/wast/lower_to_lib.mbt#L7238-L7262`](../../../../../src/wast/lower_to_lib.mbt#L7238-L7262)
  - `wast_to_binary_module lowers string.const literals`
- [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md)
  - the durable local wiki page for the current `string.const` surface

### Exact neighboring pass dossier

- [`../reorder-globals/index.md`](../reorder-globals/index.md)
  - the immediate downstream late-tail neighbor that should stay separate from `string-gathering`

That map is the main practical value of this page: readers can now jump directly from the upstream algorithm to the current local status, the real current code, and the next implementation boundary.

## What Starshine currently does have

With the pass owner file now landed, the repo has the key implementation pieces in place.

### 1. Stable `string.const` / local `stringrefs` roundtrip plumbing

The encoder and decoder already preserve literal identity through Starshine's implemented binary `stringrefs` section. Treat that section as a local/proposal-facing surface rather than stable core WebAssembly: the canonical caveat and section-id map now live in [`../../../binary/type-table-memory-global-tag-sections.md`](../../../binary/type-table-memory-global-tag-sections.md).

The key code points are:

- [`src/binary/encode.mbt#L1578-L1645`](../../../../../src/binary/encode.mbt#L1578-L1645) `encode_module_stringrefs(mod_)`
  - collects unique `string.const` payloads deterministically across module globals and code
- [`src/binary/encode.mbt#L87-L103`](../../../../../src/binary/encode.mbt#L87-L103) `encode_string_const_index(...)`
  - maps a literal payload back to its section index while encoding instructions
- [`src/binary/decode.mbt#L160-L171`](../../../../../src/binary/decode.mbt#L160-L171) `decode_string_const_literal(...)`
  - resolves encoded indices back to literal bytes on decode

This is not `string-gathering` yet.
But it is the exact local infrastructure that makes a future `string-gathering` port possible without first reinventing literal identity.

### 2. Locked tests for literal lowering and binary roundtrip

The repo already has focused tests proving that string literals survive the current front-end and binary surfaces:

- [`src/wast/lower_to_lib.mbt#L7238-L7262`](../../../../../src/wast/lower_to_lib.mbt#L7238-L7262)
  - WAST lowering keeps `string.const` literals intact
- [`src/binary/tests.mbt#L1817-L1854`](../../../../../src/binary/tests.mbt#L1817-L1854)
  - binary encode/decode roundtrip preserves `string.const` literals and Starshine's local `stringrefs` section

Those tests matter for a future pass because Binaryen `string-gathering` deduplicates by literal payload.
If Starshine loses literal identity earlier, the later pass cannot match the upstream contract.

### 3. A real backlog and scheduler story

The pass is not just a vague someday idea.
The repo already has:

- a recorded late-tail slot in the no-DWARF pipeline doc
- no active v0.1.0 SG/RG/DIR preset-order blocker in `agent-todo.md`
- a neighboring `reorder-globals` dossier that already assumes `string-gathering` should run first

So current Starshine strategy is not “plan the first pass.”
It is “maintain the landed direct module pass, keep the public preset tail honest, and only add remaining decoder or combined-tail performance work when the evidence justifies it.”

## What Starshine does **not** have yet

A future contributor should be careful not to overread the landed direct pass.
Starshine does **not** currently have:

- binary-decoder coverage for every standalone string-proposal type encoding accepted by Binaryen
- broader standalone string-proposal decoder coverage
- integration tests that prove the whole late-tail neighborhood after `simplify-globals-optimizing`

So the current repo status is best summarized as:

- literal plumbing exists
- direct module pass exists
- behavior and direct oracle evidence exist
- preset-order proof and regenerated-debug-artifact replay both exist for the appended late tail

## The right next Starshine follow-up shape

The current docs and code now suggest a narrower follow-up story: keep `string-gathering` as a **late direct module pass built on existing literal-plumbing infrastructure**, and extend it only where remaining oracle or preset evidence says it must grow.

A good local follow-up ladder is:

1. keep the active registry/dispatcher/CLI/harness surface stable
2. keep existing-global reuse covered in focused tests and direct oracle lanes
3. broaden standalone string-proposal binary decoder coverage so more binary inputs can reach the pass
4. preserve the current narrow validity-first reorder rather than fusing layout work into this pass
5. revisit combined-tail performance if it becomes a user-visible optimize-time blocker; the regenerated replay measured `62.619ms` Starshine pass runtime vs `28.215ms` Binaryen for the tail

That split still matters.
The neighboring dossier documents that Binaryen keeps `string-gathering` and `reorder-globals` as separate responsibilities, and the local direct port should stay teachably comparable instead of absorbing downstream layout work.

## The most important local dependency boundary

### `string-gathering` should continue to sit on top of current literal identity support

See [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md) plus:

- [`src/binary/encode.mbt#L72-L103`](../../../../../src/binary/encode.mbt#L72-L103), [`#L1578-L1645`](../../../../../src/binary/encode.mbt#L1578-L1645)
- [`src/binary/decode.mbt#L148-L171`](../../../../../src/binary/decode.mbt#L148-L171), [`#L3078-L3082`](../../../../../src/binary/decode.mbt#L3078-L3082)
- [`src/binary/tests.mbt#L1817-L1854`](../../../../../src/binary/tests.mbt#L1817-L1854)
- [`src/wast/lower_to_lib.mbt#L2389`](../../../../../src/wast/lower_to_lib.mbt#L2389), [`#L7238-L7262`](../../../../../src/wast/lower_to_lib.mbt#L7238-L7262)
- [`src/ir/hot_builders.mbt#L285-L293`](../../../../../src/ir/hot_builders.mbt#L285-L293), [`src/ir/hot_lift.mbt#L1291-L1294`](../../../../../src/ir/hot_lift.mbt#L1291-L1294), and [`src/ir/hot_lower.mbt#L196-L197`](../../../../../src/ir/hot_lower.mbt#L196-L197)

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

Current Starshine `string-gathering` strategy is direct-pass-landed with late-tail proof still pending:

- the encoder, decoder, and tests preserve the literal identity the pass depends on
- the active module pass hoists and rewrites direct string constants
- refreshed direct pass-fuzz evidence is green under the 2026-05-18 harness
- public preset scheduling appends `string-gathering -> reorder-globals -> directize`; regenerated debug-artifact replay is canonical/WAT green
- the boundary with `reorder-globals` remains clear: `string-gathering` creates canonical string globals; `reorder-globals` owns final global layout
