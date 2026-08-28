---
kind: entity
status: supported
last_reviewed: 2026-08-14
sources:
  - ../../release-horizon-and-oracles.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/tools/optimization-options.h
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
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
---

# `inlining`

## Status

Starshine's plain `inlining` pass is supported at Binaryen `version_131` behavior parity for the represented direct-inliner surface. The July 19, 2026 audit accounts for every v131 transform and policy family in `Inlining.cpp`:

- released `@binaryen.inline` Never/Always policy;
- tiny, one-caller, shrinking-trivial, may-grow-trivial, flexible, loop, and combined-size profitability;
- Binaryen's six public tuning flags and short aliases;
- reachable direct `call` / `return_call` planning and same-wave race avoidance;
- Pattern A and Pattern B partial splitting;
- parameter/local copying, default initialization, return repair, multivalue block typing, and helper removal;
- direct, indirect, and reference tail-call repair, including EH-aware operand localization and hoisting from `try_table`;
- export/start/element/table/global function-reference survival;
- function/name/annotation remapping after compaction;
- bounded repeated work and plain-pass stop-point behavior.

There is no open v131 pass-owned transform-family gap. Remaining limitations are shared representation or debug-metadata boundaries, not missing inliner behavior:

- legacy `try_delegate` is not a first-class local instruction surface;
- expression-level code metadata, branch hints, and source-map offset repair are not modeled locally;
- copied callee local/label debug names are not synthesized into callers, although valid caller names survive and stale rewritten label maps are dropped;
- indirect/ref **callee recovery** is not part of Binaryen v131's chosen-action planner and remains optional future research.

## Role

`inlining` is the plain sibling of [`inlining-optimizing`](../inlining-optimizing/index.md). Both use the same module-level planner and body-copy engine. Plain mode stops after rewrite, repair, and dead-helper cleanup; it must not run the optimizing sibling's nested `precompute-propagate` plus default function pipeline.

## Algorithm

1. Build whole-module function summaries: size, references, roots, direct calls, loops, trivial-instruction class, policies, and type information.
2. Classify each defined function as full-inlineable, partial-inlineable, or uninlineable.
3. Plan reachable direct calls while avoiding self-recursion and same-wave inline-into/inline-from conflicts.
4. Check Binaryen's strict estimated combined binary-size ceiling for each chosen action.
5. Copy the callee into the caller:
   - evaluate operands in order and store them into fresh parameter locals;
   - append and remap callee locals;
   - initialize defaultable body locals on every inline execution;
   - rewrite `return` into the inlined result block;
   - preserve tail calls at tail sites;
   - lower nested tail calls at non-tail sites;
   - localize operands and hoist nested EH tail calls so exception catchability is unchanged.
6. Preserve an inline result wrapper whenever the callee can escape to its implicit function label. The depth-aware scan covers `return*`, `br`, `br_if`, `br_table`, every represented `br_on_*` form including descriptor casts, and `try_table` catch targets. Hoist wrappers shift only targets outside the copied control depth, including catch-target depths.
7. Remove only private helpers whose direct and reference uses are gone and which are not globally rooted. The removal result remaps touched callers through the same old-index-to-new-index compaction map.
8. Run final adjacent `local.set; local.get` folding only for the sparse pass-local touched-function indices. This state is never written into `FuncAnnotationSec`, so user/tool annotations—including one named `starshine.inlining-finalize-fold`—survive structurally unchanged.
9. Repeat within Binaryen's bounded-work policy.

## Profitability policy

The implemented order matches v131:

1. reject explicit no-full-inline policy;
2. honor toolchain Never/Always hints;
3. admit `size <= alwaysInlineMaxSize`;
4. admit one-reference, non-rooted functions within `oneCallerInlineMaxSize` (`-1` means unbounded);
5. admit shrinking trivial instructions in all optimization modes;
6. enforce `flexibleInlineMaxSize`;
7. require optimize level at least 3 and shrink level 0 for flexible cases;
8. admit may-grow trivial instructions;
9. otherwise require no direct calls and no loops unless loop inlining is enabled.

Indirect calls, `call_ref`, `return_call_indirect`, and `return_call_ref` do not count as direct-call recursion hazards in this policy, matching Binaryen's scanner.

## Public tuning flags

The CLI accepts Binaryen's long and short spellings, with either separate values or `=value` where applicable:

- `--always-inline-max-function-size`, `-aimfs`;
- `--one-caller-inline-max-function-size`, `-ocimfs`;
- `--flexible-inline-max-function-size`, `-fimfs`;
- `--inline-max-combined-binary-size`, `-imcbs`;
- `--inline-functions-with-loops`, `-ifwl`;
- `--partial-inlining-ifs`, `-pii`.

The same values flow through `CliParseResult`, JSON config options, `OptimizeOptions`, `HotPipelineOptions`, and the shared inliner entrypoint.

## Partial inlining

Partial splitting is enabled only when optimize level is at least 3, shrink level is 0, and `partialInliningIfs > 0`.

- Pattern A flips a leading simple `if (...) return` guard and outlines the heavy suffix.
- Pattern B outlines up to the configured number of leading guarded bodies and retains an optional simple final value.
- Simple conditions match v131's `LocalGet` / `GlobalGet` plus the complete represented Binaryen Unary family and `RefIsNull`; loads, ref casts, and GC conversions are not over-admitted.
- Result arms may exit through return, tail call, trap, throw, or another represented terminal-unreachable instruction.
- `no-full-inline` still allows splitting; `no-partial-inline` and `no-inline` suppress it.

## 2026-08-27 plain-pass wall-time reduction

The first P0 performance slice reduces canonical plain `inlining` from the inventory baseline of `18.798s` pass-local / `20.059s` command to one-warmup/three-sample medians of `2.452s` pass-local / `3.641s` no-trace command. Paired Binaryen v131 medians are `1.032s` / `1.601s`, so the pass remains open at `2.376x` pass-local and `2.274x` command against the `<=2x` gates.

The retained implementation caches trivial-mode classifications for unchanged functions across helper compaction, decides tiny/one-caller/policy-forced profitability before classification, proves any represented structured body is neither Shrinks nor MayNotShrink without HOT lift, skips optimizing-only cycle/dead-suffix graph prediction in plain mode, prepares multivalue block types only in the first default plain round, records direct targets during the existing reference scan so only callers with inlineable targets enter rewrite traversal, reconstructs caller arrays only along paths containing an actual inline, and preflights final dead-unreachable-drop pruning before allocating rewritten functions. The canonical raw output remains byte-identical to pre-repair output at 5,230,205 bytes, SHA-256 `bc8988df20e39e1430f9ef5246081346918acf3c92a55fc9f0b65040b18bdce4`; native SHA-256 is `ae0f3a06cac025de34e729295b4343ce14bd2a85b9b92192900c2ea148a0f1c1`.

The remaining serial owner is the final 2.37MB caller. Its late convergence round changes one function after scanning roughly 6,102 direct calls; naive indexed flat-call, subtree-preflight, eager remap-COW, body-summary-cache, type-index, suffix-stop, and body-reference-remap experiments were measured and rejected when they were neutral or slower. Continue with an exact planner/action index or iteration fusion that preserves bounded-work ordering and canonical bytes.

## 2026-08-13 implicit function-label runtime repair

A post-signoff review found valid wrong-code when a callee used `br` to the implicit function label: omitting the inline result block let the copied branch exit an enclosing caller control and skip caller-side effects. `inl_instrs_have_function_label_escape(...)` now performs a depth-aware scan before wrapper omission, and `inl_push_inline_replacement(...)` no longer unwraps a single-block replacement when its instruction escapes through that block. The scanner covers ordinary branch, table, GC/reference `br_on_*`, descriptor branch, return/tail-return, and `try_table` catch-target families. A native Node runtime regression in [`../../../../../scripts/test/inlining-function-label-runtime.ts`](../../../../../scripts/test/inlining-function-label-runtime.ts) executes root/nested `br`, `br_if`, `br_table`, `br_on_null`, and a `try_table catch_all` function-label escape before and after plain inlining; CI runs it against the prebuilt native release CLI. Final adjacent `local.set; local.get` folding is also touched-function-only and copy-on-write, with trace counters for visited functions, reconstructed instructions, arrays, and folds. As of the 2026-08-14 metadata repair, touched callers are transported as sparse pass-local indices after helper compaction rather than through a temporary function annotation; regressions preserve an identically named user annotation and prove that removing a helper before the touched caller does not redirect finalization to the wrong function.

## Evidence

Current focused validation after the 2026-08-14 touched-state repair:

- inlining behavior: `135/135`;
- native function-label runtime script: retained;
- full repository suite: `10412/10412`;
- full wasm-gc CI profile: green;
- README/API sync: green;
- pinned-v131 `pass-inlining`: `10000/10000` normalized, zero mismatches or failures;
- pinned-v131 `inlining-optimizing-all`: `10000/10000` normalized, zero mismatches or failures.

The required production artifact refresh exposed a separate pre-existing current-HEAD runtime blocker rather than an inlining compare failure. Native SHA-256 `165611733d7536f4b853c2642414e6ce213e0c0a39d164aed11326d910ebd78d` optimized and externally validated `105/105` retained O4z modules, but exact WIPC is `0` pass / `102` fail / `3` timeout. Final native SHA-256 `da005c82e948716b16ec7ff90d07db41d2737ae56240ed85a88867858f6b5dc0` keeps the representative naive `bool` output byte-identical because every corpus input is below the new 2,000-definition artifact-scale CFG guard. An isolated clean-HEAD build emits the identical failing `bool` artifact, so [`../../../../../agent-todo.md`](../../../../../agent-todo.md) tracks this under `[REVIEW-ARTIFACT]001` instead of attributing it to the pass-local metadata repair.

The CLI/parser and earlier closeout counts below remain historical evidence for the original v131 audit rather than this review-sized repair.

Official v131 GenValid closeout, using `_build/native/release/build/cmd/cmd.exe` and `.tmp/binaryen-version-131-bin/bin/wasm-opt`:

- plain: `.tmp/pass-fuzz-inlining-v131-closeout-10000` — `10000/10000` compared, `10000` normalized matches, zero mismatches or failures;
- optimizing: `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000` — `10000/10000` compared, `10000` normalized matches, zero mismatches or failures.

Both runs used explicit `wasm-opt version 131 (version_131)` and reported zero command failures. The 2026-08-13 refreshes using native SHA-256 `659a002fec66e17d76cae02a24bb854a77ae844a970acef767527daf5ca209fe` are also exact: `pass-inlining` `10000/10000` and `inlining-optimizing-all` `10000/10000`, each with zero mismatches, validation/property/generator failures, or command failures.

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md): upstream phases and rationale.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): local owner/helper/test map.
- [`heuristics-splitting-and-plain-vs-optimizing.md`](./heuristics-splitting-and-plain-vs-optimizing.md): policy and sibling distinctions.
- [`compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md): separate metadata and policy channels.
- [`wat-shapes.md`](./wat-shapes.md): representative transform shapes.
- [`starshine-strategy.md`](./starshine-strategy.md): implementation-specific summary.
- [`starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): signoff and reopening criteria.
