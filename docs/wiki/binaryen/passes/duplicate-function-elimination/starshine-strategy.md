---
kind: concept
status: supported
last_reviewed: 2026-08-26
sources:
  - ./index.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/passes/duplicate_function_elimination_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-compaction-and-metadata.md
  - ./scheduler-validation-and-parity.md
  - ./parity.md
---

# Starshine strategy for `duplicate-function-elimination`

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
- public `optimize` / `shrink` schedule Binaryen's early and late DFE slots

White-box tests lock one-time hashing, candidate-only type normalization, complete body hashing, target-insensitive grouping, type/cleanup fact collection, and direct-target rewrite admission.

## 3. Function-reference rewrite surface

The function-index rewrite engine lives in `src/passes/duplicate_function_elimination.mbt:2523-2827`.

The highest-value owner functions are:

- `dfe_rewrite_func_idx(...)` at `:2523-2535`
- `dfe_rewrite_instruction_func_idxs(...)` at `:2537-2588`
- `dfe_rewrite_module_func_idxs(...)` at `:2712-2827`

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
  - rewrite function references through call / `ref.func` / export / start / elem surfaces, plus 2026-06-03 coverage for `return_call`, table initializers, and global initializer `ref.func`
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
