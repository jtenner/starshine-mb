# 0892 - code-pushing final closeout

Date: 2026-06-25

## Question

Can `[O4Z-AUDIT-CP]` close for the v0.1.0 `-O4z` release gate with the current post-`0884`/post-`0887` behavior and the refreshed four-lane direct-compare matrix?

## Answer

Yes, for the direct `code-pushing` pass as a v0.1.0 release-gating audit. This closeout does **not** claim byte-for-byte Binaryen output parity, full source-line-for-source-line `CodePushing.cpp` reimplementation, or public `-O4z` preset-neighborhood parity. It closes the active `[O4Z-AUDIT-CP]` backlog item because the remaining known differences are now either:

- implemented positive Binaryen v130 movement families covered by focused tests and/or aggregate profile leaves;
- Binaryen-stationary boundaries backed by reduced local `wasm-opt version 130` probes and explicit focused coverage where the Starshine fixture surface can represent them;
- intentionally reported fixture/tooling boundaries, such as the `br_on_null` prefix-payload stationary probe that currently lacks direct Starshine HOT fixture coverage; or
- local cleanup/lowering output-shape debris that is narrowly normalized in compare lanes and classified separately from behavior parity.

The stop condition is source-backed and bounded: reopen `[O4Z-AUDIT-CP]` if a new reduced Binaryen v130/current-main probe shows a positive `code-pushing` movement family that Starshine leaves stationary, if a focused boundary starts moving in Binaryen, if direct compare finds a raw mismatch not explained by the documented local-cleanup normalizer or Binaryen/tool command-failure classes, if Starshine emits invalid wasm after `code-pushing`, if public preset-slot evidence requires a separate ordered-neighborhood change, or if a future Binaryen source/lit refresh expands the pass contract beyond the documented boundaries.

## Closeout evidence

### Source and focused coverage basis

The active source basis is the local Binaryen oracle `wasm-opt version 130 (version_130)` and the 2026-06-20 source/lit bridge in [`../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md). The audit widened Starshine from the old narrow subset into the currently documented direct-pass surface:

- `if`-arm sinking including the narrow unreachable/non-fallthrough opposite-arm post-use allowance;
- ordinary void-`if`, dropped value-`if`, block-/loop-target `br_if`, value-block-target `br_if`, dropped void-label `br_on_null`, one-result-block `br_on_non_null`, dropped one-result-block `br_on_cast`, dropped one-result-block `br_on_cast_fail`, and two-result block-label `br_on_non_null` prefix-payload movement where the focused local/use proof succeeds;
- ordered adjacent multi-set movement, direct local-copy movement, and bounded separator-window movement for the documented `nop`, `drop(const)`, `drop(local.get)`, and ordinary-/dropped-`if` `drop(global.get)` subfamilies;
- pure-value movement across the documented global/table/memory/size/bulk/segment roots before a later push point;
- narrow disjoint-global read/write movement including direct roots and one-block nested roots with only direct disjoint writes plus trivial pure roots;
- source-backed barriers for calls, tag-based `throw`, rethrow-containing subtrees, `try_table` catch forms, state-reading values before relevant writes/growth, atomics stores, selected `br_table`/switch probes, and stationary prefix-/loop-label branch probes.

Focused Starshine pass coverage is current at `121` code-pushing tests in `src/passes/code_pushing_test.mbt`. The closeout validation below reran the focused file and the package/full suites after the final docs/evidence refreshes.

### Current four-lane direct-compare matrix

The current direct-compare final lanes are all post-`0884` behavior, post-`0887` focused coverage, and post-`0888`/`0889`/`0890` refreshes:

| Lane | Research note / out dir | Result | Classification |
| --- | --- | --- | --- |
| Dedicated `code-pushing-all` | [`0888`](0888-2026-06-25-code-pushing-all-post-0887-10000.md), `.tmp/pass-fuzz-code-pushing-all-10000-20260625-post-0887` | `10000/10000` compared; `4769` normalized; `5231` cleanup-normalized; raw mismatches/failures `0`; validation/generator/property/command failures `0`; all 19 leaves selected | Green dedicated aggregate lane. Cleanup-normalized cases are agent-classified local cleanup/lowering debris under `local-cleanup-debris`, not harness-proven semantic equivalence by themselves. |
| Explicit wasm-smith | [`0889`](0889-2026-06-25-code-pushing-wasm-smith-post-0888.md), `.tmp/pass-fuzz-code-pushing-wasm-smith-10000-20260625-post-0888` | `9956/10000` compared; `9956` normalized; raw mismatches `0`; validation/generator/property failures `0`; command failures `44` | Green external-generator lane for compared cases. The `44` command failures are cached Binaryen/tool classes: `39` rec-group-zero, `3` bad-section-size, `1` invalid-tag-index, `1` table-index-out-of-range. |
| Regular GenValid | [`0890`](0890-2026-06-25-code-pushing-regular-post-0889-100000.md), `.tmp/pass-fuzz-code-pushing-regular-100000-20260625-post-0889` | `100000/100000` compared; `100000` normalized; cleanup-normalized `0`; raw mismatches `0`; validation/generator/property/command failures `0` | Green regular GenValid lane. |
| Broad named GenValid | [`0891`](0891-2026-06-25-code-pushing-pass-fuzz-stress-post-0890-10000.md), `.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-0890` | `10000/10000` compared; `10000` normalized; cleanup-normalized `0`; raw mismatches `0`; validation/generator/property/command failures `0` | Green broad named `pass-fuzz-stress` lane. |

### Closeout validation commands

Run after confirming the worktree was clean and the local oracle was `wasm-opt version 130 (version_130)`:

```sh
moon info && \
moon fmt && \
moon test --target native src/passes/code_pushing_test.mbt && \
moon test src/passes && \
moon test && \
moon build --target native --release src/cmd
```

Result:

- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon fmt`: no work to do.
- focused `src/passes/code_pushing_test.mbt`: `121/121` passed.
- `moon test src/passes`: `2830/2830` passed.
- full `moon test`: `6160/6160` passed.
- native release `src/cmd` build: no work to do; current binary remains `_build/native/release/build/cmd/cmd.exe`.

## Accepted boundaries and non-claims

This closeout deliberately keeps the following boundaries visible instead of silently treating them as implemented broad movement:

- `br_table` / switch: simple no-branch-value block-exit, one value-carrying result-block, and one multi-label nested-block probes are Binaryen-stationary and protected. Broader switch shapes are not claimed as positive movement; reopen only with a reduced Binaryen-positive switch movement or generated mismatch.
- `br_on_*`: the implemented aggregate movement families are the listed block-label / dropped-label leaves. One-result loop-label `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` probes are Binaryen-stationary; two-result block-label `br_on_null`, `br_on_cast`, and `br_on_cast_fail` prefix-payload probes are stationary. The `br_on_null` prefix-payload boundary is source-backed by Binaryen but not directly covered by a focused Starshine fixture due to current fixture limitations.
- Ordered windows and local-copy chains: adjacent local-independent, direct local-copy, and the documented separator windows are covered. Arbitrary dependency chains or non-adjacent windows are not claimed unless future probes show Binaryen-positive movement and Starshine implements them.
- Effect ordering: source-backed call, EH, state-read/write, disjoint-global, atomics/GC, and pure-root windows are covered as documented. This is not a blanket implementation of every future `EffectAnalyzer::orderedBefore` nuance.
- EH / GC / trap options: reduced Binaryen v130 lit/probe families are covered or protected as stationary. Native HOT `Try` richness, mixed-arity `try_table` variants beyond the reduced probes, and future trap-option-specific behavior require new source-backed slices if evidence changes.
- Cleanup normalization: `local-cleanup-debris` is a narrow compare normalizer for known Starshine/Binaryen lowering and local-cleanup output-shape differences. It must continue to be reported separately and must not be used to hide control-flow, movement, validation, or semantic mismatches.
- Preset scope: this closes the direct-pass audit only. Public `-O4z` ordered-neighborhood and artifact evidence belongs to the surrounding preset/audit items.

## Decision

Close `[O4Z-AUDIT-CP]` as a v0.1.0 direct-pass release-gating audit. Preserve the pass wiki pages, focused tests, direct-compare matrix, and this reopening contract as the durable stop condition. Future work can still improve `code-pushing`, but it should enter as a new source-backed widening slice, a generated-mismatch fix, a preset-neighborhood audit, or a Binaryen-version refresh rather than keeping the old `[O4Z-AUDIT-CP]` item active.
