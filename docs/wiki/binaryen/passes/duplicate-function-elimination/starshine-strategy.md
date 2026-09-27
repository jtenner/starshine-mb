---
kind: concept
status: supported
last_reviewed: 2026-09-25
sources:
  - ./index.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/passes/duplicate_function_elimination_wbtest.mbt
  - ../../../../../src/passes/duplicate_function_type_prune_perf_wbtest.mbt
  - ../../../../../src/passes/duplicate_function_fixed_point_perf_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - https://webassembly.github.io/spec/js-api/#exported-functions
  - https://webassembly.github.io/spec/js-api/#dom-table-get
  - https://webassembly.github.io/spec/core/valid/instructions.html#valid-ref.eq
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-compaction-and-metadata.md
  - ./scheduler-validation-and-parity.md
  - ./parity.md
---

# Starshine strategy for `duplicate-function-elimination`

## September 27 follow-up allocation campaign renewal

The [final follow-up campaign](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
supersedes pending-renewal notes for its allocation changes below. The frozen
source passes 12,583 default tests. Its 220,000 comparisons across 22 affected
lanes report no validation, generator, property-counter, command or observed
Starshine/original semantic failures. The report retains exact tool identities,
all artifact timings, active fixtures, residual/size replays and runtime limits.
Per-change measurements are historical isolated pairs, not additive gains.
Remaining timing, output-quality and runtime-coverage gaps stay open; rejected
prototypes remain rejected.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## September 24, 2026 shape-collision measurement

Function shape hashing intentionally omits call targets so wrappers can merge after targets become canonical. In a large shape bucket, DFE groups normalized functions by an exact structural hash each round, then retains exact equality checks inside each collision group. At this stage, a sampled duplicate-heavy fast path kept direct comparisons when the first eight members were mergeable; the September 25 guard below supersedes that sample. The [native white-box direct-pass benchmark](../../../../../src/passes/duplicate_function_elimination_collision_perf_wbtest.mbt) with wrappers calling distinct imports improved from `119.31` to `20.45 µs` (5.83×) at 128 wrappers and `456.71` to `39.99 µs` (11.42×) at 256. The 128 identical-wrapper control moved from `19.09` to `19.67 µs` (3.0% slower). One new and 39 existing focused tests pass. These are synthetic Starshine pass-local timings; full-pipeline and Binaryen comparisons remain unmeasured.

## September 25, 2026 duplicate-prefix collision guard

The eight-member sample could choose pairwise comparison for a bucket whose first eight wrappers were equal and the remainder distinct, reintroducing quadratic work. DFE now checks the whole live group before taking that shortcut. The [native direct-pass benchmark](../../../../../src/passes/duplicate_function_elimination_collision_perf_wbtest.mbt) with eight equal wrappers followed by distinct imported targets improved **126.77 → 33.01 µs** at 128 wrappers and **459.34 → 66.57 µs** at 256. The 128 all-duplicate control slowed **19.48 → 20.96 µs** (7.6%) because it now checks every member before pairwise merging. This measured tradeoff favors mixed collision groups, which previously scaled quadratically. The test confirms seven duplicate removals and preservation of all distinct target calls; full-pipeline impact remains unmeasured.

## September 25, 2026 tag-signature premarking

Simple-type pruning now marks signatures referenced by defined and imported tags before probing the module for each remaining type. This extends the existing direct marks for function declarations and function imports. The native-release `dfe_prune_unused_simple_types` benchmark with 512 no-op body instructions, distinct defined tag signatures, and one unused tail fell from **27.75 to 20.19 µs** at 64 tags (27.2%) and from **62.64 to 37.82 µs** at 128 tags (39.6%). The fixture validates before and after pruning; a focused imported-tag test and the existing tag parity tests pass. This measures the pruning helper, not the complete DFE pass or production throughput.

## September 25, 2026 unused-signature bulk probe

When two or more signatures remain unmarked after direct function, import, and tag references, simple-type pruning now probes them together in one full-module scan. If that scan finds any reference, the existing per-signature probes still identify exactly which types are live; recursive type dependencies retain their existing closure. On a validated fixture with one 1,024-instruction body and 64 or 128 distinct unused signatures, the [native white-box benchmark](../../../../../src/passes/duplicate_function_type_prune_perf_wbtest.mbt) improved **428.03 → 14.57 µs** (29.4×) and **868.04 → 19.13 µs** (45.4×). The one-unused controls stayed near baseline, and a block-only type-reference regression exercises the positive fallback. These are helper timings; full-pass and Binaryen-v132 parity impact remain unmeasured.

## September 25, 2026 unchanged fixed-point groups

After a DFE merge round, a hash group whose surviving functions refer only to targets below the first replaced function index cannot gain a new duplicate: its normalized bodies were already compared in the previous round. DFE now skips rebuilding and rechecking those groups until a referenced target can change. Groups containing dependent callers still run through the existing exact comparison and identity checks.

The [native direct-elimination benchmark](../../../../../src/passes/duplicate_function_fixed_point_perf_wbtest.mbt) uses two dependent call chains and 128 distinct import wrappers in a separate unchanged shape group. With 16 chain levels, mean time fell from **250.80 → 73.32 µs** (3.42×); with 32 levels, from **538.32 → 184.18 µs** (2.92×). An initial fixture placed wrappers in the same affected shape group and showed no reliable speedup, which bounds the result. The new four-level regression, 35 existing DFE tests, and four white-box tests pass. These are synthetic direct-helper timings; full-pipeline impact remains unmeasured.

## First correction

Despite the older historical page filename, this is **not** a HOT-IR pass in Starshine today.
It is an active **module pass**.
That is the honest description for both the upstream Binaryen contract and the current local implementation.

The 2026-04-26 health cleanup renamed the living page from `starshine-hot-ir-strategy.md` to `starshine-strategy.md` so the filename no longer contradicts the strategy. Older raw/research notes may still mention the historical filename as immutable audit evidence.

## Why Starshine keeps it module-scoped

Even upstream Binaryen DFE is whole-module:

- it compares defined functions against other defined functions
- it rewrites function references across bodies and module-level surfaces
- it cares about survivor choice and module ordering

Current Starshine adds still more module-only work around that core:

- compactable element-expression canonicalization
- duplicate simple function-type compaction after a successful merge
- broad type-index rewriting needed by that compaction
- name-section stripping
- function-annotation-section rewrite bookkeeping

So the practical rule is simple:

- keep `duplicate-function-elimination` documented and tested as a module pass
- do not force it into HOT-IR terminology just for symmetry with the hot-pass folders

## Public code-location map

### 1. Registry and dispatcher surface

- `src/passes/optimize.mbt:241`
  - registers `duplicate-function-elimination` as an active **module pass** entry, not a hot pass
- `src/passes/pass_manager.mbt:8672-8673`
  - dispatches the module-pass name to `dfe_run_module_pass_with_perf(...)`
- `src/passes/optimize.mbt`
  - current public `optimize` / `shrink` presets include DFE twice in the source-backed Binaryen neighborhoods: early before `remove-unused-module-elements -> memory-packing`, and late after `dae-optimizing -> inlining-optimizing` before `duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`

That already tells readers two important local facts:

- the pass is public and runnable by name
- it is also scheduled in public presets in the same top-level DFE neighborhoods as Binaryen's no-DWARF optimizer

## 2. Fixed structural partition and canonical-remap convergence

The current local core lives in `src/passes/duplicate_function_elimination.mbt`.

The main entrypoints are:

- `dfe_eliminate_duplicate_functions(...)`
- `dfe_run_module_pass_with_perf(...)`
- `dfe_run_module_pass(...)`

What this local core does:

1. computes canonical simple-type identities once
2. hashes every defined function once into target-insensitive structural collision groups
3. records type-use, unreachable-cleanup, and maximum direct-function-target facts during that same recursive body traversal
4. lazily normalizes type indices only for functions that enter a collision group
5. repeatedly exact-compares the fixed groups under the current canonical function remap, without rebuilding or rehashing the whole module between transitive waves
6. keeps the earliest equal function as the survivor
7. rebuilds function/type arrays once after convergence
8. rewrites only surviving function bodies whose maximum direct target is at or beyond the earliest removed function
9. restricts later type-index and unreachable-debris cleanup to functions marked by the initial structural traversal

The target-insensitive hash is deliberately an over-approximation: direct `call`, `return_call`, and `ref.func` targets use opcode-shape hashes, while exact equality after canonical remapping remains the safety proof. Structured bodies, locals, annotations, and non-remappable instruction payloads remain part of the partition key.

The important current local boundary is direct behavior versus broader no-DWARF preset parity:

- direct `duplicate-function-elimination` converges transitive callee/caller duplicates over one fixed candidate partition
- fast public `optimize` / `shrink` queues contain the early DFE slot; O4z also
  queues Binaryen's late DFE slot

The scheduled slots remain in the queue, but execution now skips preset-origin
DFE when the original or current module has any imports or exports. Such a
boundary can expose a function reference through exports, tables, globals, or
imported callbacks; merging equal bodies would then collapse distinct host
identities. Closed modules still run the scheduled DFE slot. Direct
`--duplicate-function-elimination` now keeps each exported or
address-materialized defined function outside duplicate groups, even when
bodies match. The conservative address scan covers `ref.func` in function
bodies, table initializers, and global initializers, plus active and passive
element entries. Declarative-only element entries do not instantiate a runtime
reference. Direct calls and `start` remain rewriteable because they invoke a
function without materializing its address.

The JavaScript API converts a WebAssembly function address to a cached Exported
Function object when `Table.get` or an exported global exposes it. Merging two
functions stored in an exported `funcref` table or globals therefore changes
observable JavaScript `===` identity even when both bodies return the same
value. Core WebAssembly `ref.eq` cannot provide the equivalent in-module test:
its validation rule requires `(ref null eq)` operands, and function references
are outside that hierarchy. The [Node host regression](../../../../../tests/optimizer/regressions/host-identity.test.ts)
checks table and global identity plus the alias relationship between them. This
guard is a correctness improvement over the earlier direct-pass contract and
can differ from Binaryen's output shape; narrowing the broad preset gate still
requires sound escape analysis and measured size/performance evidence.
The CLI's pure O4z size portfolio filters DFE from its automatic candidate
rosters on the same host-boundary condition, so a shorter candidate cannot
bypass the preset-origin guard. Mixed explicitly named passes do not use that
portfolio.

White-box tests lock one-time hashing, candidate-only type normalization, complete body hashing, target-insensitive grouping, type/cleanup fact collection, and direct-target rewrite admission.

## 3. Function-reference rewrite surface

The function-index rewrite engine lives in `src/passes/duplicate_function_elimination.mbt:2523-2827`.

The highest-value owner functions are:

- `dfe_mark_identity_visible_func(...)`
- `dfe_identity_visible_defined_funcs(...)`
- `dfe_rewrite_func_idx(...)`
- `dfe_rewrite_instruction_func_idxs(...)`
- `dfe_rewrite_module_func_idxs(...)`

This is where the current local pass rewrites the survivor mapping through module surfaces such as:

- direct calls and `ref.func`
- exported function indices
- `start`
- element segments
- other module-level function-index carriers

This is the local mirror of the core upstream Binaryen DFE contract.

## 4. Local extra cleanup that goes beyond upstream DFE proper

### Element canonicalization and name stripping

- `dfe_canonicalize_elem_kind(...)` / `dfe_canonicalize_elem_segments(...)` at `src/passes/duplicate_function_elimination.mbt:62-114`
- `dfe_strip_name_sec(...)` at `:116-118`

These helpers are Starshine-local extras.
They canonicalize compactable `ref.func` element-expression segments back to `funcs` form and drop the name section.

### Duplicate simple-type compaction

- `dfe_duplicate_simple_type_canonical_map(...)` at `src/passes/duplicate_function_elimination.mbt:142-183`
- `dfe_canonicalize_duplicate_simple_type_indices(...)` at `:3172-3243`

This is the main local feature that most obviously goes beyond upstream Binaryen DFE.
It only runs after a successful function merge and then compacts duplicate simple function types.

### Wide type-index rewriting needed by that compaction

The type-rewrite machinery spans most of the file because it must reach many type-bearing surfaces:

- scan-and-rewrite helpers begin around `src/passes/duplicate_function_elimination.mbt:185-2394`
- the function-body scan path most readers should start from is `dfe_scan_rewrite_func_type_idxs(...)` at `:1088-1116`
- the whole-module type rewrite entrypoint is `dfe_rewrite_module_type_idxs(...)` at `:2394-2521`

The important teaching point is not every helper name.
It is the contract:

- once Starshine compacts duplicate simple types, it must rewrite typed blocks, typed selects, concrete ref forms, call-indirect/call-ref signatures, GC type uses, and related module metadata coherently

### Annotation and type-name repair

- `dfe_rewrite_func_annotation_sec(...)` / `dfe_rewrite_func_annotation_sec_in_module(...)` at `src/passes/duplicate_function_elimination.mbt:2663-2711`
- `dfe_rewrite_type_name_sec(...)` at `:2903-2940`

These helpers are another clear line between upstream DFE proper and the broader local cleanup bundle.

## 5. How the current local pass is ordered

`dfe_run_module_pass_with_perf(...)` makes the local stage order explicit:

1. build one structural partition and converge duplicate replacements under canonical function remaps
2. rebuild and rewrite function-index surfaces once
3. clean only preflight-marked unreachable-debris bodies
4. canonicalize compactable element segments and strip names
5. compact duplicate simple types and rewrite only preflight-marked type-bearing bodies, while retaining the required module-level type rewrite surface

If no function merges, the existing element canonicalization and name stripping behavior remains available without running the merge-only type-compaction path.

That is a very different story from upstream Binaryen's smaller hash/equality/rewrite loop.
The local docs should keep saying that plainly.

## Current strengths

- exact module-pass ownership is now easy to trace in one file
- whole-module function-reference rewriting is explicit and tested
- the local extra-cleanup bundle is substantial and documented rather than hidden
- perf hooks are wired through the module-pass entrypoints and detailed stages
- the hash prefilter covers complete function structure while intentionally ignoring only remappable direct function targets
- transitive duplicate chains no longer trigger repeated full-module hashing and reconstruction
- type normalization, function-body remapping, type rewriting, and unreachable cleanup are admitted by exact per-function facts rather than broad rescans

## 2026-08-26 serial performance checkpoint

On the canonical 4,977,401-byte production artifact, the original measured implementation spent about `1.309s` inside DFE and about `2.397s` for the complete command, including seven full-module fixed-point iterations. The accepted serial checkpoint reduces representative pass-local samples to roughly `177-210ms` and complete no-trace command samples to roughly `1.247-1.301s` while preserving the exact 4,889,180-byte raw output SHA-256 `9b0b49c2813dbad2354eac3918716ba0c6aac4ff401d7eb8b14963340d38dbbe`.

The final one-warmup/three-sample medians are `210.187ms` pass-local / `1,301.106ms` no-trace command versus Binaryen v131 at `94.465ms` / `637.146ms`, or `2.225x` / `2.042x`. This is an accepted roughly 6-7x serial speedup, not closure of the repository's `<=2x` P0 gates. Reaching Binaryen-local parity would require another exact serial reduction or native parallel hashing/rewrite support; whole-command 1x is additionally blocked by Starshine's larger shared decode/validation/encoding floor.

Validation for this checkpoint is 4/4 white-box tests, 30/30 focused behavior tests, 7,047/7,047 pass-package tests, and 10,731/10,731 full Moon tests. The pinned-v131 regular lane compares 10,000/10,000 cases with 9,942 normalized matches and 58 pre-existing canonical-smaller Starshine residuals, zero canonical size losses, and zero failures. Runtime-callable self semantics are exact 100/100.

## Current deliberate differences from Binaryen

### Narrower than Binaryen

- no direct-pass iteration-budget knob; direct Starshine DFE uses fixed-point behavior while Binaryen's pass options choose a budget
- broader no-DWARF preset parity still depends on neighboring pass audits and repeated cleanup slots outside DFE

### Broader than Binaryen

- element-expression canonicalization back to `funcs`
- duplicate simple function-type compaction
- broad type-index rewriting required by that compaction
- name-section stripping
- function-annotation-section rewrite bookkeeping

That two-way split is the main parity rule for this folder.

## Read-along test map

Focused local pass tests live in `src/passes/duplicate_function_elimination_test.mbt`:

- early focused tests
  - rewrite direct call / export / start surfaces and preserve identities
    materialized by body `ref.func`, table/global initializers, and
    active/passive elements
- white-box hash coverage
  - locks whole-body hash prefilter behavior so sparse same-sample functions do not share one collision bucket
- transitive-unlock coverage
  - locks direct fixed-point callee-unlocking behavior
- type-compaction tests
  - lock duplicate simple-type compaction and the resulting typed block / typed select / concrete-ref rewrite surfaces
- element-kind tests
  - lock compactable element-expression canonicalization even without function merges
- metadata tests
  - lock name stripping and annotation-map rewrite bookkeeping
- 2026-06-08 expanded audit tests
  - lock import exclusion, function-type/local-layout negatives, annotation equality/inequality, earliest survivor, nested `block` / `if` / `loop` rewrites, typed/mixed element expressions, `call_indirect` / tag type repair, descriptor/supertype/non-function type-compaction boundaries, and public preset DFE scheduling

CLI coverage lives in `src/cmd/cmd_wbtest.mbt:4010-4036`, which proves the explicit `--duplicate-function-elimination` command-line surface.

## 2026-05-06 direct validation refresh

The refreshed direct explicit-pass lane is green after the fuzzer / compare harness changes:

- `moon info`, `moon fmt`, and `moon test` passed.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination` reported `6759 / 10000` compared cases, `6759` normalized matches, `0` mismatches, and `20` Binaryen empty-recursion-group parser/canonicalization command failures.

This proves the current direct module-pass surface under the refreshed harness. It does not add DFE to public presets.

## 2026-06-03 audit update

The O4z audit refresh kept the explicit direct-pass semantics green while improving both shape coverage and pass-local runtime:

- Added focused module-surface tests for Binaryen-relevant reference rewrites that were implemented but under-tested locally: `return_call`, table initializer `ref.func`, and global initializer `ref.func`.
- Replaced the sparse function-body hash sample with a whole-body instruction hash. This keeps the hash phase closer to Binaryen's full body prefilter and prevents large unrelated functions with identical sampled instructions from falling into one quadratic exact-comparison bucket.
- The adversarial `.tmp/dfe-collision-stress.wasm` fixture improved from `20.315 ms` Starshine pass-local versus `0.717 ms` Binaryen before the change to `0.812 ms` Starshine versus `0.957 ms` Binaryen after the change, with canonical wasm equality and no raw skip.
- The duplicate-pair stress fixture `.tmp/dfe-duplicate-pairs-stress.wasm` measured `3.022 ms` Starshine pass-local versus `1.672 ms` Binaryen after the change, staying within the repo's `<= 2x Binaryen` pass-local target while still doing real deduplication work.

## Practical validation rule

For the full scheduler checklist, read [`scheduler-validation-and-parity.md`](./scheduler-validation-and-parity.md). It makes explicit that focused explicit-pass tests and public preset scheduling are separate proof surfaces; both are now covered for DFE's direct behavior and two-slot Binaryen neighborhoods.

When you need to validate or review current Starshine behavior, read the code in this order:

1. `src/passes/optimize.mbt:231-240`
2. `src/passes/pass_manager.mbt:8627-8648`
3. `src/passes/duplicate_function_elimination.mbt:3245-3534`
4. `src/passes/duplicate_function_elimination.mbt:2523-2827`
5. `src/passes/duplicate_function_elimination.mbt:3172-3243`
6. `src/passes/duplicate_function_elimination_test.mbt:99-848`

That path gives the cleanest local explanation from registry -> dispatcher -> module-pass core -> rewrite surface -> extra cleanup -> proof tests. After that, use [`scheduler-validation-and-parity.md`](./scheduler-validation-and-parity.md) to decide whether a change is preserving explicit-pass behavior, changing local extra cleanup, or changing the now-source-backed public preset scheduler slots.

## September 27, 2026: one-pass type-reference discovery

Simple-type pruning now scans module roots once, then follows retained type
references through a monotone queue. It preserves the existing declaration
premarking shortcut, pruning admission rules, ascending type compaction and
remapper. The collector follows that remapper's admitted instruction surface;
future proposal support must update both together. Type definitions contribute
supertypes, descriptor metadata, fields, function signatures and embedded
resolved definitions. Module roots include locals, tags, nested control and
handler bodies, table/global initializers, and element/data offset expressions.

A bounded red-first fixture previously scanned the whole module 16 times; it
now scans once and retains/remaps the body-only signature. Structural fixtures
compare every collected slot with the original probes across reference surfaces.
A valid transitive GC dependency chain checks closure and exact rewriting.
The old rewrite/equality probes also treated an unchanged NaN initializer as a
reference to every candidate type. A separate red-first regression now removes
two unused signatures (eight bytes), and restoring only the original type
section reproduces every original byte, including the NaN payload.

The 62 focused tests include DFE, OI/Precompute cleanup and the active command
dispatcher. Same-binary native controls compare exact output before timing:
32 candidate types and 2,048 body instructions improve **467.46 → 11.77 µs**;
128 types improve **1.81 ms → 11.90 µs**. One contended build/benchmark round
was excluded; the accepted round recorded no competing heavy process. The large OI pipeline improves **3,255.510 → 2,709.490 ms** in isolated
alternating pairs (one warmup, three accepted rounds), preserving bytes and
passing independent validation. Shared-consumer artifact renewal continues
under `.tmp/pass-perf-next-20260927/`; final aggregate fuzz renewal remains
pending.
This shared helper also serves OptimizeInstructions, DAE2 and selected
Precompute/type-cleanup paths; a helper gain alone does not close those passes.

Sources: [pruner](../../../../../src/passes/duplicate_function_elimination.mbt),
[collector](../../../../../src/passes/type_reference_scan.mbt),
[bounded reference and payload invariants](../../../../../src/passes/type_reference_scan_wbtest.mbt),
[native controls](../../../../../src/passes/type_reference_scan_perf_wbtest.mbt), and
[dispatcher fixture](../../../../../src/cmd/perf_type_reference_scan_wbtest.mbt).
