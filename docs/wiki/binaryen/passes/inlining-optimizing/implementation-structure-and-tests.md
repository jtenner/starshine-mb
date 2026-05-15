---
kind: concept
status: supported
last_reviewed: 2026-05-14
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/implementation-structure-and-tests.md
---

# `inlining-optimizing`: implementation structure and tests

## One-line map

`inlining-optimizing` is Binaryen's shared `Inlining.cpp` inliner with the optimizing suffix enabled; Starshine currently implements a partial shared module-pass subset in `src/passes/inlining.mbt` with an approximate nested cleanup path.

## Binaryen owner files

| File | Role |
| --- | --- |
| `src/passes/Inlining.cpp` | shared inliner: summaries, heuristics, planner, splitter, rewrite, repair, helper cleanup |
| `src/passes/pass.cpp` | public registration of `inlining` / `inlining-optimizing`; late post-pass scheduling |
| `src/passes/opt-utils.h` | optimizing suffix: `precompute-propagate` + default function pipeline on changed functions |
| `src/pass.h` | heuristic defaults |
| `src/passes/NoInline.cpp` | no-inline policy flags consumed by the shared inliner |
| `src/ir/module-utils.cpp` | clone-survival of no-inline flags |

## Binaryen tests

Most tests are shared with plain `inlining` because the core rewrite is shared:

- `inlining.wast` - broad public behavior;
- `inlining_optimize-level=3.wast` - high-opt/flexible/root families;
- `inlining_enable-tail-call.wast` - tail-call repair;
- `inlining_splitting*.wast` - partial inlining;
- `inlining-trivial-*.wast` - trivial-wrapper heuristics;
- `inlining-unreachable.wast` - trap/unreachable preservation;
- `inlining-gc.wast` - nondefaultable/reference local repair;
- `no-inline*.wast` - no-inline policy and clone survival;
- `inline-main.wast` - shared low-level helper reuse.

The optimizing suffix is primarily proven by `opt-utils.h`, scheduler placement, and saved debug-log evidence rather than one isolated WAT shape.

## Current Starshine code map

| File | Current role |
| --- | --- |
| `src/passes/inlining.mbt` | shared implementation owner for both public names |
| `src/passes/inlining_test.mbt` | focused public-pipeline tests and regression fixtures |
| `src/passes/inlining_wbtest.mbt` | whitebox coverage for unreachable value-block pruning, predicted exact-helper padding, and the narrow hot-unsafe polymorphic self-call suffix detector |
| `src/passes/optimize.mbt` | registry category and preset omission |
| `src/passes/pass_manager.mbt` | module-pass dispatch, `optimize=true` routing, and optimize/shrink-level propagation into inlining |
| `agent-todo.md` | accepted `[INL]001` and `[INL]007`, active `[INL]002`, accepted `[INL]003`, deferred `[INL]005` and `[INL]006`, and latest artifact evidence |
| `CHANGELOG.md` | chronological implementation checkpoints |

## Current Starshine implementation clusters

- Summary and eligibility:
  - resolves function types;
  - counts imports/definitions;
  - scans direct refs and roots;
  - computes simplified size and shape flags, carries current caller size for combined-size action filtering, and tracks original touched callers for repeated-work caps;
  - marks inlineable when tiny, one-use private, a narrow shrinking-trivial two-parameter binary wrapper, an ordered direct-call wrapper, a narrow shrinking-trivial three-parameter `select` wrapper, a narrow shrinking-trivial parameter-passthrough memory/table/SIMD/GC operation wrapper (through the current supported SIMD plus GC heap-operation breadth slice), or the first speed-focused flexible no-direct-call/no-loop `size <= 20` subset at optimize level three with shrink level zero and block type is void/single-result; repeated outer iterations stop at Binaryen's five-iteration cap per original function.
- Rewrite:
  - recurses through structured bodies;
  - rejects actions over the default combined-size guard before copying;
  - rewrites direct `call` and `return_call`;
  - appends param/body locals;
  - maps local indices;
  - rewrites simple `return` to `br` depth;
  - emits wrapper block replacement.
- Removal/remap:
  - removes inlined private helpers when refs disappear;
  - remaps function indices in exports/start/elements/tables/globals/code/data where represented;
  - remaps function annotations and function names after compaction so no-inline policy and later function-name lookups stay attached to surviving functions, while dropping local/label name maps until full body-name repair exists;
  - exposes `no_inline_copy_policy_annotations(...)` for future clone/copy transforms to preserve no-inline policy markers.
- Nested approximation:
  - emits trace marker;
  - prepends the private touched-only `precompute-propagate-prefix` helper and traces that nested-pass slot explicitly;
  - converts absolute touched-function bits to defined-function bits before running filtered nested helpers so imports do not shift the touched set;
  - runs the remaining cleanup lane through touched-function filtered hot-pass adapters plus narrow touched adapters for module-shaped `local-subtyping`, `coalesce-locals`, `local-cse`, and `reorder-locals`;
  - keeps body restoration as a safety net, but no longer launches the old whole-module cleanup batch;
  - compacts unused locals on touched functions;
  - collapses conservative unreachable-root shapes.
- Exact-unreachable predictor:
  - predicts alive exact-unreachable helper counts by signature;
  - pads missing exact helpers to predicted signature counts before final trimming;
  - includes refinements for private cycles and shadowed void-cycle result-helper representatives.

## Focused tests in `src/passes/inlining_test.mbt` and `src/passes/inlining_wbtest.mbt`

- active module category for both names;
- tiny helper inline/remove;
- parameter operand remap;
- repeated parameter-passthrough binary, direct-call, `select`, and memory/table/SIMD/GC operation wrappers as narrow shrinking-trivial heuristic subsets, including the latest supported SIMD plus GC heap-operation wrappers;
- optimize-level-three/no-shrink flexible policy for a repeated-param helper and `call_indirect` body that are intentionally not inlined under default plain `inlining`, O3+shrink mode, or when the callee contains a loop or surviving direct imported call;
- exported tiny helper survival;
- narrow direct `return_call` inline;
- self-recursive skip;
- iterative wave after same-wave race guard;
- unreachable private cycles reached from dead suffixes;
- self-looping unreachable private cycles;
- duplicate exact-unreachable helper retention;
- non-inlined duplicate exported-signature retention;
- root unreachable collapse cleanup;
- no-inlining unreachable value-block pruning;
- shadowed void-cycle result-helper retention;
- optimizing nested-cleanup trace marker plus a focused first nested-pass trace for `precompute-propagate-prefix`;
- trace coverage proving the nested suffix no longer launches the old `pipeline:start requested=29` whole-module cleanup batch;
- trace coverage proving the local cleanup neighborhood includes `simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs`;
- touched-caller/default-local prefix folding coverage that keeps an untouched sibling's body-local `local.get` shape unchanged;
- whitebox predicted exact-helper padding;
- whitebox detection of polymorphic self-call suffixes before the approximate hot cleanup lane.

## Current evidence and classification

Latest standard-lane artifact:

```text
.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier
seed 0x5eed
9975 compared
9975 normalized matches
0 mismatches
0 validation failures
0 generator failures
25 ignored Binaryen/tool command failures
```

Broadened closure artifact:

```text
.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2
seed 0x1eed
9978 compared
9978 normalized matches
0 mismatches
0 validation failures
0 generator failures
22 ignored Binaryen/tool command failures
```

Binaryen parse/canonicalization failures are classified as ignored oracle/tool failures, not Starshine semantic failures. The latest seed `0x1eed` lane has no Starshine command failures; `case-008100-gen-valid` replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`.

## Remaining implementation/test surfaces

- full heuristic matrix from Binaryen lit files;
- no-inline flag fixtures;
- partial split fixtures;
- nested `return_call*` / `try` hoist fixtures;
- multi-result wrapper fixtures;
- nondefaultable local fixtures;
- broader exact touched-function scheduler tests for callers/callees/removed helpers after the prefix;
- exact Binaryen default-function pipeline ordering/options after the current filtered approximation;
- direct plain `--pass inlining` standard compare evidence;
- direct optimizing `--pass inlining-optimizing` compare with zero mismatches across the agreed standard and broadened seed lanes after each scheduler expansion.
