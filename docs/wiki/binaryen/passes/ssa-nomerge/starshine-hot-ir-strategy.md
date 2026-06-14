---
kind: concept
status: supported
last_reviewed: 2026-06-14
sources:
  - ../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md
  - ../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/ssa_destroy.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ./parity.md
  - ../ssa/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `ssa-nomerge` HOT-IR strategy

This page describes the **current local MoonBit implementation**, not the full upstream Binaryen `SSAify(false)` contract.

## Current local surface

Starshine exposes `ssa-nomerge` as an active hot pass with:

- descriptor name: `ssa-nomerge`
- summary text: `Freshen single-source locals and materialize defaults while preserving merge traffic.`
- required HOT analyses:
  - CFG
  - local SSA
- broad invalidation after mutation:
  - CFG
  - dominance
  - liveness
  - use-def
  - effects
  - loop info
  - SSA

That summary string is intentionally no-merge-shaped after `[SSANM-006b3]`.
Upstream Binaryen `ssa-nomerge` is a **no-merge** LocalGraph rewrite, and the current Starshine public summary now describes the same visible policy: freshen single-source write traffic, materialize legal default reads, and keep merge traffic canonical instead of advertising predecessor-copy lowering as normal behavior.

The safe teaching headline is now:

- Binaryen `ssa-nomerge` avoids materializing merge locals
- current Starshine `ssa-nomerge` routes completed ordinary families through LocalGraph-planned raw reasons or explicit no-op boundaries
- retained HOT SSA destruction and raw copy-like helpers still exist, but they are fallback/boundary or sibling-SSA surfaces, not the normal no-merge behavior claim

## Current local code map

The easiest way to follow the in-tree implementation is this file map. The same map is also summarized with upstream proof surfaces in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md):

- `src/passes/ssa_nomerge.mbt:2`
  - `ssa_nomerge_descriptor()` declares the public pass name, required analyses, and invalidation set
- `src/passes/ssa_nomerge.mbt:15`
  - `ssa_nomerge_summary()` owns the registry/help text; `[SSANM-006b3b]` changed it away from predecessor-copy wording
- `src/passes/ssa_nomerge.mbt`
  - `ssa_nomerge_has_local_writes(...)` is the cheap early gate
  - `ssa_nomerge_needs_rewrite(...)` decides whether either overlay phis or concrete local-write defs make rewriting worthwhile for the retained lifted fallback
  - `ssa_nomerge_run(...)` is the retained lifted fallback wrapper: it requires CFG + local SSA and calls `@ir.ssa_destroy_into_hot(...)` only when the raw dispatcher has not already handled the function
- `src/ir/ssa_destroy.mbt:33`
  - `HotSsaDestroyPolicy` currently exposes only `ReusePhiLocals`
- `src/ir/ssa_destroy.mbt:157`
  - `ssa_destroy_build_predecessor_copy_nodes(...)` turns scheduled copies into explicit `local.get` -> `local.set` HOT nodes
- `src/ir/ssa_destroy.mbt:455`
  - `ssa_insert_predecessor_copies(...)` inserts those copies at predecessor-block boundaries
- `src/ir/ssa_destroy.mbt:527`
  - `ssa_destroy_into_hot(...)` is the real local SSA-destruction bridge used by the pass
- `src/passes/pass_manager.mbt:5768`
  - `run_hot_pipeline_raw_append_local_read(...)` owns raw default-value materialization and alias-resolved local reads
- `src/passes/pass_manager.mbt:5915`
  - `run_hot_pipeline_raw_initialized_locals(...)` seeds raw default-local knowledge from params plus zero-init locals
- `src/passes/pass_manager.mbt`
  - the raw `ssa-nomerge` dispatcher builds `SsaNoMergeRewritePlan` and routes completed straight-line, default, canonical-merge, mixed normal-control, ordinary block/if, decorated loop-backedge, and retained boundary families before lifted HOT fallback
  - remaining raw helper names such as `structured-local-writes-mutated` are boundary-helper surfaces for branch/table/typed/EH ABI repair, not ordinary no-merge predecessor-copy claims
  - the pass-manager hook selects the raw special case before ordinary lift/writeback; the lifted hot-pass dispatch remains the fallback path
- `src/passes/optimize.mbt:158`
  - registry entry wiring for the public pass name
- `src/passes/optimize.mbt:246`
  - first preset slot in `optimize`
- `src/passes/optimize.mbt:258`
  - first preset slot in `shrink`
- `src/passes/optimize.mbt:379`
  - public `optimize_preset_passes(...)` definition
- `src/passes/optimize.mbt:394`
  - public `shrink_preset_passes(...)` definition
- `src/passes/ssa_nomerge_test.mbt`
  - LocalGraph planner, straight-line/default, canonical-merge, mixed normal-control, decorated loop-backedge, fail-closed branch/table, EH, and typed-control boundary fixtures. Use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the current detailed test map instead of older predecessor-copy-shaped line anchors.
- `src/cmd/cmd_wbtest.mbt:2394`
  - debug-artifact CLI replay coverage
- `src/cmd/cmd_wbtest.mbt:2434`
  - extracted `Func 523` writeback-type-mismatch retirement check

## How the local pass works today

## 1. The lifted HOT fallback is tiny because it delegates to local SSA destruction

`ssa_nomerge_run(...)` is still intentionally short, but after `[SSANM-006b2*]` it should be read as a retained lifted fallback rather than the normal ordinary no-merge route. It does this:

1. bail out if the function has no local writes
2. bail out on known exceptional, typed-loop, branch-heavy, or nested CFG-sensitive boundaries
3. require CFG
4. require local SSA
5. bail out if there are neither overlay phis nor local-set/local-tee SSA defs worth rewriting
6. call `@ir.ssa_destroy_into_hot(func, cfg, ssa)`
7. mark the function mutated only if the HOT revision changed

The ordinary completed no-merge families are expected to return from the raw dispatcher before this bridge. If a new ordinary family reaches this bridge and creates predecessor-copy-style merge traffic, treat that as a rerouting regression or new SSANM slice, not as expected no-merge behavior.

## 2. The real HOT rewrite surface lives in `ssa_destroy.mbt`

The local destruction helper is the reason Starshine differs so much from Binaryen's no-merge mode.

`ssa_destroy_into_hot(...)`:

- assigns concrete locals to SSA values,
- collects phi-input copies per predecessor block,
- schedules those copies safely,
- inserts explicit predecessor copy nodes,
- and rewrites local gets/sets/tees back onto the chosen concrete locals.

That is closer in spirit to upstream Binaryen full `--ssa` destruction than to upstream `ssa-nomerge`.
The key consequence is now scoped narrowly:

- retained lifted fallback can still materialize merge traffic explicitly,
- while upstream Binaryen `ssa-nomerge` deliberately keeps merge reads on canonical original slots,
- so ordinary public no-merge work should be routed through LocalGraph-planned raw reasons or explicit boundaries rather than through this bridge.

## 3. Overlay phis are first-class local rewrite triggers

`ssa_nomerge_needs_rewrite(...)` returns true when either:

- `ssa.phis.length() != 0`, or
- any SSA value origin came from a `LocalSetDef` or `LocalTeeDef`

So the local pass treats overlay phi presence itself as enough reason to run.
That makes sense in a HOT-SSA-based implementation, because the interesting work is often in how those phis are destroyed back into ordinary locals.

This is another point where the local strategy should not be conflated with Binaryen's no-merge rule.

## 4. The raw path is the ordinary no-merge route for completed families

`run_hot_pipeline_raw_ssa_nomerge(...)` is a real special-case implementation family.
It does not merely short-circuit into the HOT pass wrapper.

Its top-level split is now best understood as:

- skip entirely if there are no writes and no default-local reads to materialize
- build and consume the LocalGraph-backed `SsaNoMergeRewritePlan` for completed straight-line, default, canonical-merge, mixed normal-control, ordinary block/if, and narrow loop-backedge families
- return explicit no-op boundary reasons for retained branch/table-decorated loop-backedge families that should not fall into HOT destruction
- keep branch/table/typed/EH scratch helpers under their named boundary owners
- otherwise leave the retained lifted HOT fallback as a source-reachable risk surface to reduce or classify in a later SSANM slice

Any future maintenance or parity discussion needs to say whether it is broadening a planned LocalGraph family, preserving a boundary helper, or touching the retained HOT fallback.

## 5. The straight-line raw path consumes the LocalGraph no-merge plan

The old straight-line alias-allocator description is superseded by `[SSANM-003a]` and `[SSANM-003b]`: straight-line `local.set` and `local.tee` now build `SsaNoMergeRewritePlan`, freshen only planned single-source writes, retarget only planned single-source gets, and preserve canonical locals when the plan says the write or read participates in merge traffic. Focused public-pipeline tests lock both `local.set` and `local.tee` routing through `straight-line-local-writes-localgraph-plan`.

The implementation still appends fresh locals and rewrites raw instructions locally, but the eligibility decision is no longer a standalone syntactic alias heuristic.

## 6. The structured raw path is split between planned LocalGraph rewrites and boundary helpers

`run_hot_pipeline_raw_ssa_nomerge_structured(...)` delegates to recursive raw instruction helpers, but the current ownership split matters:

- planned LocalGraph reasons (`structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-one-arm-merge-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan`) are the ordinary no-merge surfaces;
- retained no-op reasons such as `structured-loop-backedge-boundary-noop` avoid misleading success claims while keeping boundary shapes out of lifted HOT SSA destruction;
- legacy copy-like raw helper output belongs to branch/table/typed/EH ABI repair, not to ordinary Binaryen `SSAify(false)` predecessor-copy materialization.

So when a fixture shows copy-like local traffic, first classify whether it is a retained boundary helper. Do not treat predecessor-copy-shaped output as the default structured no-merge contract.

## 7. Default local reads are explicitly materialized locally too

The raw helper family also materializes default local reads directly when a local has never been initialized in the relevant raw model.
That mirrors one part of upstream Binaryen's visible behavior, but the implementation route is different:

- Binaryen uses LocalGraph and `nullptr` entry sources inside `SSAify.cpp`
- Starshine raw mode uses explicit initialized-local tracking plus `run_hot_pipeline_raw_append_local_read(...)`

So the shared beginner lesson is still valid:

- default entry values may become explicit literals

But the local mechanism is repo-specific.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `ssa-nomerge` is a LocalGraph-based no-merge rewrite that refuses to materialize merge locals
- current Starshine `ssa-nomerge` should describe ordinary behavior the same way: single-source freshening, default materialization, and canonical merge preservation
- retained HOT SSA destruction and copy-like raw helpers still exist, but they are fallback/boundary or sibling-SSA surfaces that must be explicitly classified

That split is visible in both the code and the tests.

So the safe local teaching headline is not:

- “Starshine already implements Binaryen `ssa-nomerge`.”

It is:

- “Starshine implements the same broad early-SSA-cleanup goal, but with a very different local representation strategy.”

## Current local tests and what they prove

The focused tests in `src/passes/ssa_nomerge_test.mbt` currently prove these local contracts. For the exact test-map table, including CLI artifact replay surfaces, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md):

- straight-line local writes can stay canonical on simple shapes
- repeated straight-line aliases can move onto fresh locals
- dead param writes and tees can be redirected to fresh locals
- structured param writes may remain on canonical param slots
- branch and loop merge regions covered by completed LocalGraph slices preserve canonical merge locals instead of entering predecessor-copy HOT fallback
- retained branch/table, EH, and typed-control boundary fixtures validate, preserve their opcodes or helper shapes, and reject ordinary planned LocalGraph reasons when the helper remains out of scope
- root loop headers avoid synthetic entry copies
- structured early-return and block-target branch families preserve a canonical join local story only when classified by their boundary owner
- result-typed `if` / typed-control merge repairs remain boundary-helper work unless a later slice admits a narrower LocalGraph family
- reduced unreachable compare-carrier followups from the artifact slice remain valid

The CLI tests in `src/cmd/cmd_wbtest.mbt` add two higher-level proofs:

- the checked-in debug artifact still replays successfully under `--ssa-nomerge`
- the extracted `Func 523` slice no longer records the old writeback type-mismatch skip that earlier parity notes had singled out

The 2026-05-01 implementation-source refresh keeps this as Starshine-local validation evidence, not as proof that the local strategy is a direct clone of upstream `SSAify(false)`.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree hot pass,
- an increasingly LocalGraph-planned raw no-merge implementation for ordinary families,
- retained HOT-SSA destruction and copy-like helper surfaces that must be classified before use,
- and **not** a direct AST clone of upstream Binaryen `SSAify(false)`.

Future work on this pass should answer one question explicitly:

- is this an ordinary LocalGraph no-merge family that should freshen/retarget/default/canonicalize without predecessor copies,
- or is it a branch/table/typed/EH/full-SSA boundary that needs a named helper, no-op, or sibling pass?

Those are materially different goals, and the wiki should keep that difference explicit.