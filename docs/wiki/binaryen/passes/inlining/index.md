---
kind: entity
status: working
last_reviewed: 2026-05-13
sources:
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
  - ../../../raw/research/0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0391-2026-04-26-inlining-port-readiness.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/index.md
  - ../inline-main/index.md
  - ../duplicate-function-elimination/index.md
  - ../monomorphize/index.md
---

# `inlining`

## Role

`inlining` is Binaryen's plain whole-module inliner. It shares the upstream `src/passes/Inlining.cpp` engine with [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md), but it stops after inline planning, callsite rewrite, repair, and dead-helper cleanup. It does **not** run the optimizing sibling's nested useful-pass rerun.

Current Starshine status has changed since the older April port-readiness notes: `inlining` is now a **partial active module pass**, not boundary-only. It is owned by [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt), registered as a module pass in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), dispatched by [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt), and covered by focused public-pipeline tests in [`src/passes/inlining_test.mbt`](../../../../../src/passes/inlining_test.mbt).

Do not read that as universal Binaryen inliner parity. The current local implementation has accepted direct current-supported surfaces for optimizing `[INL]001` and plain `[INL]007`, but deferred breadth is still tracked in [`agent-todo.md`](../../../../../agent-todo.md) under `[INL]002`-`[INL]006`.

## Why this pass matters

- It is the smaller public contract behind the shared Binaryen inliner: same scan/plan/rewrite core, no optimizing suffix.
- It is the best place to teach the low-level inline rewrite requirements before adding `inlining-optimizing`'s scheduler obligations.
- The current Starshine implementation uses the same owner file for both names, so plain `inlining` is no longer merely a future sibling.
- It is easy to misdescribe as “inline small functions.” Real Binaryen behavior includes whole-module root/use accounting, layered heuristics, partial-inlining splitting, callsite surgery, type/local/label repair, and helper deletion.

## Beginner summary

A safe mental model:

1. Scan the module to summarize every function: size, refs, roots, calls, loops, `try_delegate`, trivial-wrapper class, and inline mode.
2. Classify callees as fully inlineable, split-inlineable, or uninlineable.
3. Plan reachable direct `call` / `return_call` actions.
4. Copy callee bodies into callers while remapping locals and repairing returns, labels, tail-call forms, reachability, and types.
5. Delete only private helpers that truly have no surviving roots or uses.
6. Stop. The optimizing sibling performs step 7: nested cleanup on touched functions.

## Current durable takeaways

- Upstream `version_129` chosen inline actions are source-backed as reachable direct `call` / `return_call` sites. `ref.func`, `call_ref`, and `call_indirect` still matter for root survival and copied-body repair, but the living docs should not teach broad `call_ref` selection unless a later source ingest proves it.
- `refs` is not just direct-call count. It includes `ref.func` uses, while exports and the start function mark global/root use.
- Full-inline profitability is layered: `try_delegate` bailout, tiny threshold, one-use special case, shrinking trivial wrapper class, flexible max size, shrink/speed policy, no-calls and loop policy.
- Partial inlining is real but narrow: two top-of-function conditional split families, enabled only by heavier speed settings and `partialInliningIfs`.
- Inline rewrite is structured IR surgery: operand storage, fresh caller locals, zeroing defaultable copied vars, copied-body metadata, return-to-break repair, nested `return_call*` repair, label uniquification, refinalization, and nondefaultable-local repair.
- Plain `inlining` must not accidentally run `precompute-propagate` or the default function pipeline. That difference is the public split from `inlining-optimizing`.

## Starshine status snapshot: 2026-05-13

Implemented subset:

- active module-pass names: `inlining`, `inlining-optimizing`, `no-inline`, `no-full-inline`, and `no-partial-inline`;
- bounded iterative direct `call` and `return_call` rewrite waves;
- tiny and one-use private defined callee eligibility;
- callee param/body-local appending and local-index remapping in callers;
- simple callee `return` rewrite to an inlined wrapper-block branch;
- private helper removal when surviving refs disappear;
- function-index rewriting after removals;
- focused tests for no-param helpers, parameter operand storage, exported tiny-helper survival, `return_call`, self-recursion skip, iterative race-guard follow-up, narrow shrinking-trivial binary-wrapper, `select`-wrapper, scalar-store-wrapper heuristics (`i32.store`, `i64.store`, `f32.store`, `f64.store`, `i32.store8`, `i32.store16`, `i64.store8`, and `i64.store16`), defaultable copied-local zero-init, plain helper deletion without optimizing retain counts, plain no-call unreachable value-block cleanup, registry wiring, optimizing trace marker, and the first `no-inline*` policy split fixtures including imported WAT identifiers, deduplication, no-match behavior, annotation and function-name remapping across helper compaction, post-compaction policy matching by surviving names, and local-name dropping after inlining body rewrites.

Still missing or incomplete:

- full Binaryen heuristic parity, including remaining trivial-instruction classes and flexible/O3 policy beyond the narrow shrinking binary-wrapper, `select`-wrapper, scalar-store-wrapper subsets (`i32.store`, `i64.store`, `f32.store`, `f64.store`, `i32.store8`, `i32.store16`, `i64.store8`, and `i64.store16`);
- partial-inlining-specific `no-inline`, `no-full-inline`, and `no-partial-inline` behavior after the splitter lands;
- partial Pattern A / Pattern B splitting;
- nested `return_call*` repair and `return_call`-inside-`try` hoisting;
- multi-result inlined wrapper block typing;
- exact label/name collision behavior and annotation/name-section repair;
- exact Binaryen action filtering, repeated-work caps, and giant-function size guard.

## Current evidence

Plain `inlining` direct signoff is accepted for the current supported surface. The standard plain seed lane is structurally clean after local-declaration stripping:

- `.tmp/pass-fuzz-inlining-seed-0x5eed-plain-moonrun-10k-full-after-plain-no-retain-prune`
- seed `0x5eed`
- `9975 / 10000` compared
- `9169` normalized matches
- `806` normalized mismatches, all local-declaration/allocation representation drift
- `0` structural mismatches after stripping `(local ...)` declaration lines
- `0` validation failures
- `25` ignored Binaryen/tool parse/canonicalization command failures

The broadened plain seed lane has the same classification:

- `.tmp/pass-fuzz-inlining-seed-0x1eed-plain-moonrun-10k-full-after-plain-no-retain-prune`
- seed `0x1eed`
- `9978 / 10000` compared
- `9208` normalized matches
- `770` normalized mismatches, all local-declaration/allocation representation drift
- `0` structural mismatches after stripping `(local ...)` declaration lines
- `0` validation failures
- `22` ignored Binaryen/tool parse/canonicalization command failures

The optimizing sibling's current-supported direct surface is also green. The standard optimizing seed lane is:

- `.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier`
- seed `0x5eed`
- `9975 / 10000` compared
- `9975` normalized matches
- `0` normalized mismatches
- `0` validation failures
- `0` generator failures
- `25` ignored Binaryen/tool parse/canonicalization command failures:
  - `22` `binaryen-rec-group-zero`
  - `1` `binaryen-bad-section-size`
  - `1` `binaryen-table-index-out-of-range`
  - `1` `binaryen-invalid-tag-index`

The broadened seed lane is green over compared cases:

- `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2`
- seed `0x1eed`
- `9978 / 10000` compared
- `9978` normalized matches
- `0` normalized mismatches
- `0` validation failures
- `0` generator failures
- `22` ignored Binaryen/tool `binaryen-rec-group-zero` parse failures
- `0` Starshine command failures; `case-008100-gen-valid` replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`

Per project policy and user preference, Binaryen parse/canonicalization failures are ignored oracle/tool failures, not Starshine semantic failures. The previous broadened mismatches are retired; exact nested scheduling remains `[INL]002`, deferred unsupported direct-inliner breadth now lives under `[INL]003`, `[INL]005`, and `[INL]006`, and plain `[INL]007` is accepted with local-declaration/allocation drift classified as representation-only.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - deep upstream strategy: phases, heuristics, direct-call action surface, partial-inlining patterns, rewrite/repair, and dead-helper cleanup.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Binaryen owner/helper/test map plus current Starshine code/test map.
- [`./heuristics-splitting-and-plain-vs-optimizing.md`](./heuristics-splitting-and-plain-vs-optimizing.md) - focused explainer for the pass's easiest misunderstandings.
- [`./compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md) - source-backed split between preserved `@metadata.code.inline` bytes and actual no-inline policy flags.
- [`./wat-shapes.md`](./wat-shapes.md) - WAT shape catalog for positives, bailouts, partial-inline shapes, repair shapes, and current Starshine subset/gaps.
- [`./starshine-strategy.md`](./starshine-strategy.md) - active partial Starshine implementation status and design map.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - validation/evidence bridge for the remaining Starshine work.

## Maintenance rule

Keep this folder as the canonical home for the plain inliner contract. Whenever the shared Starshine implementation changes, update this folder and [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md) together, but keep the public stop-point split explicit: plain `inlining` must not claim the optimizing suffix.
