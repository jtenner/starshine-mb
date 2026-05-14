---
kind: concept
status: supported
last_reviewed: 2026-05-14
sources:
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/implementation-structure-and-tests.md
---

# `inlining`: implementation structure and tests

This page maps the upstream Binaryen owner/test surface and the current Starshine owner/test surface. Use it when you need exact follow-along files before editing code or interpreting compare artifacts.

## Binaryen source map

### `src/passes/Inlining.cpp`

Shared owner for:

- `inlining`;
- `inlining-optimizing`;
- `inline-main`'s low-level helper path.

Important pieces:

| Piece | Role |
| --- | --- |
| `InliningMode` | `Unknown`, `Uninlineable`, `Full`, `SplitPatternA`, `SplitPatternB` classification |
| `TrivialInstruction` | `NotTrivial`, `Shrinks`, `MayNotShrink` wrapper policy |
| `FunctionInfo` | size, refs, calls/loops/delegate/root flags, trivial class, cached inline mode |
| `FunctionInfoScanner` | module-wide summary pass |
| `Planner` | reachable direct `call` / `return_call` action discovery in reviewed `version_129` |
| `FunctionSplitter` integration | partial Pattern A/B helper creation |
| `doCodeInlining(...)` | actual callsite rewrite and wrapper construction |
| `Updater` | copied-body local, return, label, tail-call, and branch-depth repair |
| `updateAfterInlining(...)` | label uniquification, refinalization, EH/local/type repair |
| `Inlining::run(...)` | preparation, waves, action filtering, optional optimizing suffix, helper cleanup |
| `InlineMainPass` | small special-case wrapper pass using the low-level helper |

### `src/passes/pass.cpp`

Defines public names and scheduler placement:

- registers `inlining`, `inlining-optimizing`, `inline-main`;
- registers `no-inline`, `no-full-inline`, `no-partial-inline`;
- schedules `inlining-optimizing`, not plain `inlining`, in the ordinary late no-DWARF optimize tail.

### `src/passes/opt-utils.h`

Negative source for plain `inlining`, positive source for the optimizing sibling. The helper prepends `precompute-propagate` then reruns the default function optimization pipeline on changed functions. Plain `inlining` must not call this helper.

### `src/pass.h`

Default heuristic knobs:

- `alwaysInlineMaxSize = 2`;
- `oneCallerInlineMaxSize = -1`;
- `flexibleInlineMaxSize = 20`;
- `maxCombinedBinarySize = 400 * 1024`;
- `allowFunctionsWithLoops = false`;
- `partialInliningIfs = 0`.

### `src/passes/NoInline.cpp`

Implements the real no-inline policy pass family. It wildcard-matches function names and sets `Function::noFullInline` / `Function::noPartialInline`.

### `src/ir/module-utils.cpp`

`copyFunction` preserves `noFullInline`, `noPartialInline`, and function annotations. This explains `no-inline-monomorphize-inlining.wast` clone-survival behavior.

### Helper headers that matter

- `branch-utils.h`: branch-target collection and label collision checks.
- `branch-hints.h`: branch-hint preservation when splitting guards.
- `literal-utils.h`: zero-value detection for copied locals.
- `metadata.h`: copied expression metadata.
- `return-utils.h`: split-candidate return checks.
- `type-updating.h`: nondefaultable-local repair.
- `eh-utils.h`: nested-pop repair.
- `localize.h`: children localized before repaired `return_call*` lowering.
- `properties.h`: trivial-instruction classification.
- `find_all.h`: `inline-main` callsite lookup.

## Binaryen official tests and what they prove

| Test | Main proof |
| --- | --- |
| `inlining.wast` | broad base behavior, plain vs optimizing examples, root/reference and feature interactions |
| `inlining_optimize-level=3.wast` | high-opt flexible cases, root survivors, recursion/conservatism |
| `inlining_enable-tail-call.wast` | `return_call` and copied tail-call repair families |
| `inlining_splitting.wast` | Pattern A/B partial splitting, helper creation/naming, feature-sensitive simple guards |
| `inlining_splitting_basics.wast` | partial inlining is opt-in with `partialInliningIfs` |
| `inlining-trivial-instructions.wast` | `Shrinks` vs `MayNotShrink` trivial classes |
| `inlining-trivial-calls-1.wast` | trivial call families that shrink even in size-aware modes |
| `inlining-unreachable.wast` | unreachable/trap reachability preservation |
| `inlining-gc.wast` | nondefaultable/reference local repair |
| `no-inline.wast` | `no-inline`, `no-full-inline`, `no-partial-inline` policy split |
| `no-inline-monomorphize-inlining.wast` | clone-surviving no-inline flags |
| `inline-main.wast` | tiny special-case pass using shared low-level rewrite helper |
| `inline-hints*.wast` | preserved `@metadata.code.inline` annotation bytes, distinct from no-inline flags |

## Current Starshine source map

### `src/passes/inlining.mbt`

Owner for both local public names.

Main clusters:

| Cluster | Current role | Known gap |
| --- | --- | --- |
| summaries | import/defined counts, type lookup, simple size scan, refs/roots, shape flags | no full Binaryen cost/trivial/flexible/depth model |
| eligibility | tiny, one-use private, narrow shrinking-trivial two-parameter binary-wrapper, narrow shrinking-trivial three-parameter `select`-wrapper, or narrow shrinking-trivial parameter-passthrough memory/table operation-wrapper defined callee (`i32.store`, `i64.store`, `f32.store`, `f64.store`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, `i64.store32`, `v128.store`, `v128.store8_lane`, `v128.store16_lane`, `v128.store32_lane`, `v128.store64_lane`, `table.set`, `table.grow`, `memory.fill`, `memory.copy`, `memory.init`, or `table.fill`); block type must be void/single-result; skip `try_table` and return-call-containing callees; honor internal full-inline suppression from `no-inline` / `no-full-inline` | remaining `Shrinks` / `MayNotShrink` classes, partial splitter, flexible/O3 policy, multi-result support, partial-inlining-specific no-inline behavior |
| rewrite | direct `call` / `return_call` replacement, param/body-local append, local remap, simple return-to-branch | incomplete nested `return_call*`, label collision, nondefaultable-local, metadata/name repair |
| removal | private helper deletion after refs disappear, function-index remap across module surfaces, function annotation remap, and function-name remap; local/label name maps are dropped until full repair exists | exact Binaryen helper/name cleanup beyond currently remapped function names is not complete |
| optimizing approximation | trace marker, broad cleanup lane with untouched-body restoration, touched unused-local compaction, unreachable-root collapse | not exact `precompute-propagate` + touched-function filtered default pipeline |
| exact-unreachable predictor | retained/trimmed/padded private unreachable helper count refinements for the retired direct mismatch frontiers | seed-`0x5eed` and seed-`0x1eed` direct lanes are green over compared cases |

### `src/passes/optimize.mbt`

Current registry status:

- `pass_registry_entry_module("inlining", inlining_summary())`;
- `pass_registry_entry_module("inlining-optimizing", inlining_optimizing_summary())`;
- `pass_registry_entry_module("no-inline", no_inline_summary())` and sibling entries for `no-full-inline` / `no-partial-inline`;
- all five names are no longer in `pass_registry_boundary_only_names()`.

Preset status:

- public `optimize` / `shrink` presets still do not include the late Binaryen `INL` slot;
- direct pass selection works through module-pass dispatch.

### `src/passes/pass_manager.mbt`

Current dispatch:

- `"inlining" => inlining_run_module_pass(mod_, optimize=false, pass_name="inlining")`;
- `"inlining-optimizing" => inlining_run_module_pass(mod_, optimize=true, trace=Some(options.trace), pass_name="inlining-optimizing")`;
- dynamic `no-inline=<pattern>` / `no-full-inline=<pattern>` / `no-partial-inline=<pattern>` names are normalized through the registry and dispatched to `no_inline_run_module_pass(...)`.
- WAT lowering now maps function identifiers into structured function names, so the policy passes can match text inputs without a separate hand-authored name section.

### `src/passes/inlining_test.mbt`

Focused tests currently cover:

- registry classification for `inlining`, `inlining-optimizing`, and the three `no-inline*` policy names;
- tiny no-param callee inlining and helper removal;
- operand storage into remapped params;
- repeated parameter-passthrough binary, `select`, and memory/table operation wrappers inline as narrow shrinking-trivial heuristic subsets;
- exported tiny helper inlines but survives;
- direct `return_call` callee inline subset;
- self-recursion skip;
- bounded iterative wave after same-wave inline-into/from race guard;
- unreachable private-cycle cleanup families;
- duplicate exact-unreachable helper retention;
- shadowed void-cycle result-helper representative retention;
- no-inlining unreachable value-block pruning and predicted exact-helper padding;
- optimizing nested-cleanup trace marker;
- no-inline wildcard policy blocking full inlining, WAT identifier based matching for defined and imported functions, command-level sequencing before plain `inlining`, `no-full-inline` vs `no-partial-inline` split behavior, repeated-policy marker deduplication, no-match behavior, annotation and function-name remapping across helper compaction, post-compaction policy matching by surviving names, dropping function-scoped local names after inlining body rewrites, copy-helper policy propagation for cloned functions, and the fact that `@metadata.code.inline` function hints are not no-inline policy.

These tests are necessary but not sufficient for Binaryen parity.

## Current artifact evidence

Latest recorded compare evidence from the parent thread:

```text
.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier
seed 0x5eed
9975/10000 compared
9975 normalized matches
0 normalized mismatches
0 validation failures
0 generator failures
25 ignored Binaryen/tool command failures
```

The seed-`0x5eed` command failures classify as oracle/tool parse/canonicalization failures, not Starshine semantic failures:

- `22` `binaryen-rec-group-zero`;
- `1` `binaryen-bad-section-size`;
- `1` `binaryen-table-index-out-of-range`;
- `1` `binaryen-invalid-tag-index`.

Broadened closure evidence is red:

```text
.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2
seed 0x1eed
9978/10000 compared
9978 normalized matches
0 normalized mismatches
0 validation failures
0 generator failures
22 ignored Binaryen/tool command failures
```

For seed `0x1eed`, all `22` command failures are ignored Binaryen/tool `binaryen-rec-group-zero` parse failures. The former `case-008100-gen-valid` Starshine nested-cleanup command failure replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`.

## File-to-concept map

| Topic | Best file |
| --- | --- |
| Upstream shared inliner | Binaryen `src/passes/Inlining.cpp` |
| Upstream heuristic defaults | Binaryen `src/pass.h` |
| Upstream public pass split | Binaryen `src/passes/pass.cpp` |
| Optimizing suffix | Binaryen `src/passes/opt-utils.h` |
| No-inline policy | Binaryen `src/passes/NoInline.cpp` + `module-utils.cpp` |
| Starshine no-inline policy | `src/passes/no_inline.mbt` plus `src/passes/inlining.mbt` policy lookup |
| Starshine active implementation | `src/passes/inlining.mbt` |
| Starshine registry/presets | `src/passes/optimize.mbt` |
| Starshine dispatch | `src/passes/pass_manager.mbt` |
| Starshine focused tests | `src/passes/inlining_test.mbt` |
| Active backlog | `agent-todo.md` accepted `[INL]001` and `[INL]007`, keeps `[INL]002` active, and tracks deferred breadth `[INL]003`, `[INL]005`, and `[INL]006` |

## Validation guidance

A future implementation slice should validate in this order:

1. focused Moon tests in `src/passes/inlining_test.mbt` for each new shape;
2. direct `bun scripts/pass-fuzz-compare.ts --pass inlining ...` for plain stop-point behavior;
3. direct `bun scripts/pass-fuzz-compare.ts --pass inlining-optimizing ...` for optimizing behavior;
4. saved mismatch replay from `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2` until retired or split;
5. late-tail neighborhood replay only after direct pass semantics are green across the agreed seed lanes.
