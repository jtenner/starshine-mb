# 0141 - Binaryen `ssa-nomerge` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the `global-struct-inference` dossier.
- Follow the repo wiki process in `docs/README.md`.
- Consult the updated tracker and choose one still-eligible pass.
- Deepen the docs for the earliest function pass in the canonical no-DWARF optimize path.
- Produce durable notes that help a future Starshine maintainer preserve the real Binaryen contract for `ssa-nomerge`, which is easy to overstate into “full SSA” or understate into “just rename some locals.”

## Candidate selection

- `docs/wiki/binaryen/passes/tracker.md` now lists `ssa-nomerge` as the strongest remaining implemented landing-page target after `global-struct-inference`.
- `ssa-nomerge` is still only `landing`, not `deep`, in the tracker at the start of this thread.
- It is eligible under the campaign rules.
- `agent-todo.md` still has **no dedicated `SSA` slice** today; the live repo references are indirect:
  - the canonical no-DWARF ordered path puts `ssa-nomerge` first in the function cluster
  - the shared HOT replay and worker-queue slices talk about the `ssa-nomerge -> dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals` hot batch
  - the current dedicated living wiki surface is only a landing page plus parity note

## Why this pass is worth deepening now

- In Binaryen's public scheduler, `ssa-nomerge` is the first function optimization pass in the default no-DWARF path.
- In the saved generated-artifact `-O4z` audit, it appears at top-level slot `8` and still matches Binaryen exactly at the WAT level, so it is already a pass where the repo has evidence worth consolidating.
- That same audit shows it is also a major runtime hotspot.
  - Slot `8` summary:
    - exact wasm equal: `no`
    - normalized WAT equal: `yes`
    - Starshine wall/runtime: `10299.164 ms`
    - Binaryen wall/runtime: `496.466 ms`
    - Starshine in-pass time: `1341.831 ms`
    - Binaryen in-pass time: `286.388 ms`
    - input validates: `yes`
    - output validates: `yes`
- The saved Binaryen debug log shows that `ssa-nomerge` is not just a one-off top-level pass.
  - The first top-level run appears immediately after `gsi` and before `flatten`.
  - The same log also shows many nested `precompute-propagate -> ssa-nomerge -> flatten -> simplify-locals-notee-nostructure` reruns.
- The pass is easy to misunderstand in both directions:
  - too broad: “this converts the function into proper SSA”
  - too narrow: “this only does straight-line local renaming”

So this is a high-value dossier candidate because it sits at a critical scheduler boundary, already has artifact-backed parity evidence, and still lacked a real implementation-oriented explanation.

## Local repo context that matters

### Canonical no-DWARF scheduler placement

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` records the canonical open-world no-DWARF function cluster as beginning:

- `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`

Binaryen `pass.cpp` makes the placement logic slightly more precise:

- it runs when `optimizeLevel >= 3 || shrinkLevel >= 1`
- the motivating comment is that untangling to semi-SSA form is helpful, but merges should be ignored to avoid introducing new copies

That means the pass is meant to prepare later function cleanups without immediately paying the code-size cost of explicit phi materialization.

### Current in-tree Starshine implementation

The local implementation lives in:

- `src/passes/ssa_nomerge.mbt`
- `src/passes/ssa_nomerge_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`

The current local pass is **not** a direct AST-to-AST Binaryen port.
It is a HOT pass that:

- invalidates CFG, dominance, liveness, use-def, effects, loop-info, and SSA analyses
- bails out immediately when there are no local writes
- requires cached HOT CFG + SSA overlays
- calls `@ir.ssa_destroy_into_hot(func, cfg, ssa)`
- reports unchanged when the HOT revision does not change

The current raw pipeline around it in `pass_manager.mbt` is also much more specialized than Binaryen:

- it has raw-skip fast paths for:
  - `no-local-writes`
  - `default-local-reads`
  - `straight-line-local-writes`
  - `structured-local-writes`
- it has writeback validation guards that can fail closed with:
  - `writeback-validate:*`
  - `suspicious-escape-carrier`
- it keeps direct artifact replay green by rejecting lowered rewrites that would invalidate the surrounding module

So the local pass already embodies useful Binaryen-inspired behavior, but through a HOT overlay + safe-writeback architecture rather than upstream's direct AST walker.

### Current local evidence

The current parity page and in-tree tests establish these durable local facts:

- the dead-param write family is fixed in-tree
- current source-mode `ssa-nomerge` replay on `tests/node/dist/starshine-debug-wasi.wasm` validates and matches Binaryen on normalized WAT and canonical per-function comparison
- a reduced `Func 523` compare-carrier family is checked in both lift and pass tests
- exact raw-byte parity is still not claimed because direct artifact replay still records fail-closed writeback skips

Important current local remaining gap:

- the fresh artifact replay still records one `Func 523` `writeback-validate:type mismatch` skip and many `suspicious-escape-carrier` skips

### Current local registry surface

The local registry treats:

- `ssa-nomerge` as an active `HotPass`
- plain `ssa` as **not** a separately exposed active pass

That matters because upstream Binaryen implements both `ssa` and `ssa-nomerge` in the same `SSAify.cpp` source file.
The repo currently documents only the no-merge variant as an active public pass.

## Official Binaryen source inventory

Primary `version_129` sources:

- `src/passes/SSAify.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/local-graph.h`
- `src/ir/LocalGraph.cpp`
- `src/ir/ReFinalize.cpp`

Important official test surfaces:

- dedicated `ssa-nomerge` pass test:
  - `test/passes/ssa-nomerge_enable-simd.wast`
  - `test/passes/ssa-nomerge_enable-simd.txt`
- shared `ssa` test that still exercises shared helper behavior in `SSAify.cpp`:
  - `test/lit/passes/ssa.wast`
- helper-level LocalGraph behavior examples:
  - `test/gtest/local-graph.cpp`

Important helper dependencies visible in the implementation:

- `LocalGraph`
- `FindAll<LocalSet>`
- `FindAll<LocalGet>`
- `LiteralUtils`
- `Builder`
- `ReFinalize`
- CFG walking and flow logic in `LocalGraphFlower`

## Freshness check done for this note

I did a narrow direct comparison against current upstream `main` for the owning and immediately relevant helper surfaces.

Direct result:

- `version_129` `src/passes/SSAify.cpp` == current `main` `src/passes/SSAify.cpp`
- `version_129` `src/ir/local-graph.h` == current `main` `src/ir/local-graph.h`
- `version_129` `src/ir/LocalGraph.cpp` == current `main` `src/ir/LocalGraph.cpp`
- `version_129` `src/ir/ReFinalize.cpp` == current `main` `src/ir/ReFinalize.cpp`
- `version_129` `test/passes/ssa-nomerge_enable-simd.wast` == current `main` same file
- `version_129` `test/passes/ssa-nomerge_enable-simd.txt` == current `main` same file

The only `pass.cpp` drift I found in a direct compare was unrelated typo cleanup in other pass descriptions.

So there is **no visible semantic post-`version_129` drift** in the owning `ssa-nomerge` source file, the LocalGraph helpers it relies on directly, or the dedicated official `ssa-nomerge` golden test.

## What the pass sounds like versus what it actually is

### Easy wrong mental model

A beginner can easily hear `ssa-nomerge` and imagine one of two wrong things:

1. **Too broad**
   - “This converts wasm locals into full SSA form, just without explicit phi instructions.”
2. **Too narrow**
   - “This only renames a few straight-line `local.set` / `local.get` pairs.”

Both are incomplete.

### Better source-backed mental model

Binaryen's actual `ssa-nomerge` behavior is:

1. build a whole-function LocalGraph that knows which sets can reach which gets
2. classify which original local indexes are already effectively SSA enough
3. inspect each individual `local.set` and ask a **per-set** question:
   - do any of the gets influenced by this set read from more than one possible set?
4. if the answer is **no**, rename that set to a fresh local index of the same type
5. rewrite gets with a single reaching set to that set's index
6. rewrite gets with only the entry/default value to:
   - the original parameter slot, or
   - an explicit zero literal when the type has one
7. deliberately do **nothing** for gets with multiple reaching sets in no-merge mode

So the pass is best understood as:

- **LocalGraph-based untangling of single-source local traffic**
- with **explicit refusal to materialize merge locals in no-merge mode**

That is narrower than full SSA, but broader than a naive straight-line peephole.

## Actual Binaryen implementation structure

## 1. `SSAify.cpp` implements both `ssa` and `ssa-nomerge`

The source file is shared.

- `createSSAifyPass()` constructs `SSAify(true)`
- `createSSAifyNoMergePass()` constructs `SSAify(false)`

The `allowMerges` flag is the central difference.

That is an important durable point for the wiki:

- `ssa-nomerge` is not a separate unrelated algorithm
- it is the same SSAify infrastructure with one key policy switch

## 2. The pass is function-parallel and explicitly invalidates DWARF

Upstream `SSAify` reports:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

So Binaryen treats local-index rewriting as a per-function transformation, but one that really does disturb debug-location assumptions.

## 3. `runOnFunction(...)` has a small but loaded structure

For each function, Binaryen does:

1. construct `LocalGraph graph(func, module)`
2. `graph.computeSetInfluences()`
3. `graph.computeSSAIndexes()`
4. `createNewIndexes(graph)`
5. `computeGetsAndPhis(graph)`
6. `addPrepends()`
7. `ReFinalize().walkFunctionInModule(func, module)` if needed

This sequence matters because:

- the pass first understands the old local traffic
- then renames sets
- only then rewrites gets
- only after all of that does it prepend any entry copies and repair types

## 4. LocalGraph is whole-function CFG flow, not just local scanning

`LocalGraph` builds a CFG-oriented flow model over `local.get` and `local.set` actions.

The core internal helper is `LocalGraphFlower`, which:

- walks the function into basic blocks
- records block-local action order
- records the last set per local index in each block
- skips unreachable code when building actions
- then performs backwards flow from gets to find their reaching sets

Important source-backed properties:

- `nullptr` in a get's reaching-set set means the entry/default value:
  - parameter value for params
  - zero-init for vars
- if an index has **no sets anywhere**, LocalGraph short-circuits and assigns the entry/default value
- LocalGraph deliberately overestimates in unreachable code
  - it may include the entry/default value even when real reachability would exclude it
  - the helper comments say this is acceptable because unreachable code should disappear later anyway

So a future port must preserve this important nuance:

- the graph is precise enough for optimization
- but not promised to be debugger-perfect inside unreachable code

## 5. “Already SSA” means more than “every get sees one set”

`computeSSAIndexes()` does not use the loosest possible definition.

The helper comment in `local-graph.h` says an index is treated as SSA only if:

- all gets for that index see a single set
- that set dominates the gets
- no other explicit set for the index exists, aside from the implicit zero-init

This extra rule matters because it blocks falsely calling an index “SSA enough” when a later unrelated set of the same index could interfere with later local-based rewrites.

So upstream `ssa-nomerge` is already conservative before its main no-merge policy even begins.

## 6. The central no-merge decision is made per set, not per local index

`createNewIndexes(graph)` iterates every `LocalSet` in the function.

For each set:

- if the original index is already SSA, do nothing
- otherwise, if `allowMerges` is true or `hasMerges(set, graph)` is false, assign a fresh local index of the same type to the set

`hasMerges(set, graph)` is simple but powerful:

- scan every get influenced by this set
- if any such get has more than one reaching set, this set is considered merge-participating

This means the important unit is **the set**, not just the original local slot.

A single original local can therefore split into mixed behavior:

- early straight-line sets can get fresh locals
- merge-feeding sets can stay on the canonical original slot
- later straight-line sets can get fresh locals again after the merge region

That exact mixed pattern is visible in the dedicated official `ssa-nomerge_enable-simd` `nomerge` golden test.

## 7. `computeGetsAndPhis(...)` rewrites gets in three main cases

### Case A: zero reaching sets

- treat as unreachable and ignore

### Case B: exactly one reaching set

If the single reaching set is an actual `LocalSet`:

- rewrite the `local.get` index to that set's (possibly fresh) index

If the single reaching set is `nullptr`:

- parameter -> leave the param index alone
- non-param with a defaultable type -> replace the `local.get` expression with an explicit zero literal of that type
- nondefaultable type -> leave it alone

That means `ssa-nomerge` is not just local-index renaming.
It is also a **default-value materialization pass** for gets that are proven to read only the entry value.

### Case C: multiple reaching sets

If `allowMerges` is false, as in `ssa-nomerge`:

- do nothing
- keep the get on the canonical original slot

This is the most important defining rule.

The full `ssa` path would instead create a fresh phi-like local, insert tees or prepended entry sets, and retarget the get to that new local.

`ssa-nomerge` deliberately refuses that work.

## 8. Full phi materialization exists in the source, but is gated off here

The same `computeGetsAndPhis(...)` contains the full merge-handling logic for `allowMerges == true`.

That full-SSA path:

- allocates a new local for the merged value
- rewrites the get to that new local
- writes to the new local from each reaching explicit set by wrapping the set value in `local.tee`
- prepends `local.set` copies at function entry when a parameter is one of the incoming values

That is useful context because it shows what `ssa-nomerge` is **choosing not to do**.

Important implication:

- `addPrepends()` exists in the source file for the full `ssa` case
- in `ssa-nomerge`, that vector is normally empty because multi-set gets are skipped instead of materialized

## 9. `ReFinalize` plays a narrow but real role

The pass sets `refinalize = true` only in a narrow shared helper case:

- when a `local.get` of reference type is replaced by an explicit null/default literal

The code comment explains why:

- replacing a local.get with null can refine what the parent receives to a bottom-like type

So `ssa-nomerge` is usually not a heavy type-repair pass, but it does rely on refinalization when default-value materialization sharpens types.

This is why the shared `ssa.wast` test is still relevant even though it is not a dedicated `ssa-nomerge` file:

- it locks shared `SSAify.cpp` behavior around nullable refs and tuple-default replacement that the no-merge variant also uses when the same helper path is reached

## What the dedicated official `ssa-nomerge` test actually teaches

The dedicated upstream golden file `test/passes/ssa-nomerge_enable-simd.wast` is compact but very informative.

It covers these core families:

- basic straight-line untangling of repeated writes into fresh locals
- keeping parameter gets on the canonical param slot until a non-merge overwrite happens
- default-value materialization for uninitialized locals
  - `i32`, `f32`, `i64`, `f64`
  - `v128` via explicit zero splat
- one-arm and two-arm `if` merge cases that deliberately keep the canonical local slot
- the central `nomerge` mixed example where some writes to the same source local are renamed and some are not

What it does **not** show directly:

- loop-specific merge behavior
- broader GC/ref cases
- function-entry prepends, because those are full-`ssa` behavior

So when discussing loops or ref-type default materialization in the living wiki, those should be labeled as:

- source-backed inference from `SSAify.cpp` / LocalGraph
- or shared-SSAify helper behavior, not dedicated no-merge golden coverage

## What the shared `ssa.wast` file still adds

Even though it is not a dedicated no-merge golden file, `test/lit/passes/ssa.wast` still matters for this dossier because it covers shared helper behavior in `SSAify.cpp`, including:

- rewriting non-nullable parameter overwrites through fresh locals
- replacing default reads with explicit null/zero/tuple values
- triggering refinalization when that replacement sharpens types

That is relevant because those helper paths are not conceptually “merge-only.”
They are shared logic in the same file.

## What the pass does not do

Binaryen `ssa-nomerge` does **not**:

- build proper phi instructions in the AST
- create merge locals when a get has multiple reaching sets
- try to coalesce or remove the fresh locals it introduces
- perform DCE on now-dead writes by itself
- reason precisely about unreachable code for debugging-quality provenance
- try to rewrite arbitrary value trees; it is specifically about local traffic

That is why later passes matter so much:

- `dce`, `remove-unused-*`, and `vacuum` clean up residue
- `coalesce-locals` can remove many of the fresh untangling locals
- `flatten` and later aggressive local passes in `-O4` build on the simpler local traffic `ssa-nomerge` leaves behind

## Biggest differences from the current Starshine implementation

## 1. Binaryen works directly on the AST and LocalGraph; Starshine works through HOT SSA destruction

Upstream:

- AST + LocalGraph + direct local index rewrite

Current Starshine:

- HOT lift / analyses / SSA overlay / `ssa_destroy_into_hot` / lower / writeback

That is an architectural difference, not automatically a semantic one.

## 2. Binaryen's no-merge rule is explicit in `createNewIndexes()`; Starshine's equivalent behavior is distributed

Local MoonBit behavior is spread across:

- the HOT SSA analysis and destruction helpers
- raw fast-path rewrites in `pass_manager.mbt`
- writeback validation safety rails

So the local pass can already preserve many Binaryen-visible shapes while taking a very different internal route.

## 3. Starshine currently has artifact-level fail-closed writeback guards that upstream Binaryen does not need

Binaryen's direct AST rewrite does not need repo-local concepts such as:

- `suspicious-escape-carrier`
- `writeback-validate:type mismatch`

Those belong to the repo's HOT/lowering architecture rather than the upstream pass contract itself.

## What a future Starshine port or refactor must preserve

A future strict-parity Starshine port or refactor must keep these source-backed rules honest:

- `ssa-nomerge` is the shared `SSAify` algorithm with `allowMerges = false`
- LocalGraph whole-function flow, not just straight-line scanning, determines which writes are eligible to untangle
- the decision is **per set**, not “rename this entire original local or do not”
- already-SSA indexes stay untouched
- any set whose influenced gets ever see multiple reaching sets must stay on the canonical slot
- default-value gets may be rewritten to explicit zeros when the type is defaultable
- params keep their original slot when the entry value is still the only source
- full phi-local insertion, tees, and function-entry prepends belong to full `ssa`, not `ssa-nomerge`
- unreachable-code overestimation in LocalGraph is a deliberate helper tradeoff, not an accidental bug in this pass
- refinalization is required when replacing ref-typed default gets with sharper null values

If local code intentionally differs, that divergence should be documented explicitly as a local architectural tradeoff.

## Durable conclusions

- Binaryen `ssa-nomerge` is not full SSA construction and not a simple peephole.
- The real contract is LocalGraph-driven untangling of **single-source** local traffic, with merge-producing sets and gets deliberately left on canonical slots.
- The pass's most important subtlety is that the no-merge decision is made **per set**, not per source local.
- Default-value materialization and narrow refinalization are real parts of the pass contract, not incidental cleanup.
- A narrow 2026-04-20 freshness check found no semantic post-`version_129` drift in `SSAify.cpp`, the relevant LocalGraph / ReFinalize helper files, or the dedicated `ssa-nomerge` golden test surface.
