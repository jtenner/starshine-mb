---
kind: concept
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/research/0554-2026-05-07-simplify-locals-notee-nostructure-backlog-closure.md
  - ../../../raw/research/0544-2026-05-06-slnns-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
  - ../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
  - ../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../flatten/index.md
  - ../local-cse/index.md
  - ../tracker.md
---

# Starshine `simplify-locals-notee-nostructure` port readiness and validation

## Why this page exists

The main dossier already explains what Binaryen does.
The Starshine strategy page already explains the current active direct-pass status.
A 2026-05-07 backlog-closure review then confirmed there is no separate active `SLNNS` backlog slice left in the no-DWARF parity queue.
This page now records the landed direct-pass boundary:

- what local slice is already honest and shipped?
- what must stay disabled so the sibling does not become full `simplify-locals`?
- why does the future `flatten -> simplify-locals-notee-nostructure -> local-cse` replay belong to aggressive-path work instead of the active backlog?

## Current hold point

Starshine now treats `simplify-locals-notee-nostructure` as an active direct hot pass with green direct-pass oracle evidence, but not as a preset-scheduled `-O4z` neighborhood member.
The state to preserve until broader preset work starts is:

- upstream Binaryen spelling: `simplify-locals-notee-nostructure`
- current active local spelling: `simplify-locals-notee-nostructure`
- current local category: hot pass
- current CLI behavior: accepted through the registry category gate
- current lower-level pipeline behavior: dispatched to the shared locals engine with `allowStructure=false` and `allowTee=false`
- current owner: `src/passes/simplify_locals.mbt`
- current preset role: explicit readiness-gated omission because the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` slot is outside the active no-DWARF parity target and still depends on `flatten`

## Exact local code map today

| Surface | Code location | Why it matters |
| --- | --- | --- |
| Active registry | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), `pass_registry_entries()` | Registers the exact upstream spelling as a hot pass while keeping presets unchanged. |
| CLI pass gate | [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt), `cmd_resolve_pipeline_steps(...)` | Accepts the pass through the normal hot-pass registry path. |
| Hot dispatcher | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt), `hot_pass_run(...)` | Dispatches the exact spelling to the no-tee / no-structure locals runner. |
| Shared locals implementation | [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), `simplify_locals_run_with_options(...)` | Owns the full pass and the stricter sibling policy mode. |
| Registry proof surface | [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | Covers active category and descriptor spelling. |
| Backlog truth | [`agent-todo.md`](../../../../../agent-todo.md) | No longer carries a standalone `SLNNS` slice after the 2026-05-07 closure review; future aggressive-prelude replay belongs to later `flatten` / scheduler work. |
| Neighbor scheduler context | [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) | Documents the sibling’s aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` slot, but not a local implementation. |

## Slice status

### Slice 0: registry honesty — landed

The chosen spelling policy is to activate the exact upstream `simplify-locals-notee-nostructure` name as a direct hot pass and keep presets unchanged.

### Slice 1: policy-mode skeleton — landed

The shared locals engine now models the two relevant policy axes for this sibling:

- `allowTee = false`
- `allowStructure = false`
- `allowNesting = true` by using existing nested consumer traversal rather than flatness-only traversal.

### Slice 2: direct no-tee / no-structure cleanup only — landed

The landed direct implementation uses the shared locals cleanup path for:

1. direct single-use local sinking into an already-existing consumer;
2. dead-overwrite cleanup on the current linear trace;
3. late equivalent-get canonicalization once the direct sink path is green;
4. final dead-set cleanup after the no-tee / no-structure policy is proven.

Exit criteria:

- dedicated positive tests cover direct sink families;
- dedicated positive tests cover dead-overwrite cleanup;
- focused regression coverage preserves the Binaryen const+nop loop shape and dummy-local parity fallback;
- no `local.tee` is introduced;
- no block / `if` / loop result carrier is introduced;
- no non-copy expression is moved under `drop`, call operands, arithmetic operands, branch payloads, or control conditions unless the source contract already allows it.

### Slice 3: late cleanup reuse — landed for direct-pass scope

The landed direct pass already reuses the late equivalent-local and dead-set cleanup families from the full pass for direct-pass scope.

Durable guardrails:

- equivalent-copy cleanup works on flat local-copy classes;
- dead-set cleanup removes only now-dead local shells;
- the same negative fixtures still prove no fresh teeing or structure synthesis.

## Negative tests future widening should keep in mind

Keep these families explicit before widening the pass or the aggressive neighborhood:

- multi-use non-copy temp that full `simplify-locals` could tee;
- computed value consumed by `drop`;
- computed value consumed by `call`;
- computed value consumed by arithmetic;
- computed value used as an `if` condition;
- branch payload temp where inlining would create nested payload computation;
- block / `if` / loop local-set patterns that full `simplify-locals` might convert to result carriers;
- effectful producer followed by memory/global/table/atomic/EH barrier;
- dangling-pop or EH-sensitive value shape if the local HOT surface can represent it.

The core rule is simple: if the expected output contains a new non-copy expression under an ordinary consumer, the test should fail for this pass.

## Binaryen oracle evidence

Direct-pass validation on the landed slice:

1. 2026-05-06 refreshed standard signoff:
   - `moon info`
   - `moon fmt`
   - `moon test`
   - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-notee-nostructure --out-dir .tmp/pass-fuzz-simplify-locals-notee-nostructure`
     - `6759/10000` comparable mixed-generator cases
     - `6759` normalized matches
     - `0` mismatches, validation failures, or generator failures
     - `20` Binaryen/tool command failures: `17` empty-recursion-group rejects plus one each of bad-section-size, table-index-out-of-range, and invalid-tag-index classes

Earlier direct-pass evidence collected on 2026-05-04:

- `.tmp/pass-fuzz-slnns-smith-10000-after-local`: `8983/8983` comparable `wasm-smith` cases matched Binaryen, with `0` mismatches and `0` validation failures. The `1017` command failures were parser/corpus coverage failures outside the compared semantic lane.
- `.tmp/pass-fuzz-slnns-genvalid-1000-fixed`: `1000/1000` comparable `gen-valid` cases matched Binaryen, with `0` mismatches, `0` validation failures, and `0` command failures after the emitted batch profile was narrowed to Binaryen-oracle-safe scalar/function surfaces.
- `.tmp/pass-fuzz-slnns-10000-after-genvalid-fix`: `9496/9496` comparable mixed-generator cases matched Binaryen, with `0` mismatches and `0` validation failures; the remaining `504` command failures are Binaryen/canonicalization rejects from the `wasm-smith` half, not from `gen-valid`.
- `.tmp/self-opt-slnns-after-local-bin128`: direct self-opt compare on `tests/node/dist/starshine-debug-wasi.wasm` passed with normalized WAT equality and canonical function equality against Binaryen 128.

Next oracle scope remains the ordered aggressive neighborhood: add `flatten -> simplify-locals-notee-nostructure -> local-cse` only after both neighbors are active enough to replay and compare honestly. Keep `--simplify-locals`, `--simplify-locals-nostructure`, and local active `simplify-locals` as contrast lanes, not as the oracle for this sibling.

That future replay should reopen as a new aggressive-path / `flatten` task, not as a reopened standalone `SLNNS` direct-pass item.

## What not to do

Do not start by routing this name to the active full `simplify-locals` implementation.
That would immediately violate the Binaryen contract because the active pass has structure rewrites and ordinary nested sinks that the no-tee / no-structure variant must reject.

Do not add the pass to `optimize` or `shrink` presets during the first port.
The source-backed role is a flatten-neighbor / explicit-pipeline sibling, not part of the current Starshine no-DWARF preset.

Do not hide the local spelling mismatch.
The current repo says `simplify-locals-no-tee-no-structure`; the upstream pass says `simplify-locals-notee-nostructure`.
A faithful port should make that choice visible in tests.

## Sources

- [`../../../raw/research/0554-2026-05-07-simplify-locals-notee-nostructure-backlog-closure.md`](../../../raw/research/0554-2026-05-07-simplify-locals-notee-nostructure-backlog-closure.md)
- [`../../../raw/research/0544-2026-05-06-slnns-direct-revalidation.md`](../../../raw/research/0544-2026-05-06-slnns-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- [`../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md)
- [`../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- Binaryen `version_129` sources are enumerated in the raw primary-source manifest above.
