# 0073 - Code Pushing Binaryen Plan

## Scope

- Research Binaryen's `code-pushing` pass exactly on `version_125`.
- Record the real algorithm, not just the public one-line summary.
- Turn that research into a concrete HOT-IR implementation plan for this worktree.

## Primary Sources

- Binaryen implementation:
  [`src/passes/CodePushing.cpp`](https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/CodePushing.cpp#L38-L497)
- Binaryen default function-pipeline slot:
  [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/pass.cpp#L625-L710)
- Binaryen nested rerun helper:
  [`src/passes/opt-utils.h`](https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/opt-utils.h#L32-L64)
- Binaryen pass tests:
  [`code-pushing_into_if.wast`](https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/code-pushing_into_if.wast),
  [`code-pushing_ignore-implicit-traps.wast`](https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/code-pushing_ignore-implicit-traps.wast),
  [`code-pushing_tnh.wast`](https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/code-pushing_tnh.wast),
  [`code-pushing-gc.wast`](https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/code-pushing-gc.wast),
  [`code-pushing-eh.wast`](https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/code-pushing-eh.wast),
  [`code-pushing-eh-legacy.wast`](https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/code-pushing-eh-legacy.wast)
- Starshine docs and code reviewed before planning:
  [`src/ir/README.md`](../src/ir/README.md),
  [`0059`](./0059-2026-03-24-ir2-architecture-rules.md),
  [`0060`](./0060-2026-03-24-cfg-contract-and-block-boundary-rules.md),
  [`0061`](./0061-2026-03-24-local-ssa-policy.md),
  [`0062`](./0062-2026-03-24-pass-porting-checklist.md),
  [`0063`](./0063-2026-03-24-pass-port-batches-and-registry-map.md),
  [`0066`](./0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md),
  [`src/passes/optimize.mbt`](../src/passes/optimize.mbt),
  [`src/passes/pass_common.mbt`](../src/passes/pass_common.mbt),
  [`src/passes/pass_manager.mbt`](../src/passes/pass_manager.mbt),
  [`src/ir/effects.mbt`](../src/ir/effects.mbt),
  [`src/ir/hot_region_edit.mbt`](../src/ir/hot_region_edit.mbt),
  [`src/passes/heap_store_optimization.mbt`](../src/passes/heap_store_optimization.mbt)

## Binaryen Placement

- Binaryen adds `code-pushing` in the default function pipeline when
  `optimizeLevel >= 2 || shrinkLevel >= 2`.
- Its exact top-level slot is after the early `precompute` / `precompute-propagate`
  step and before `tuple-optimization`.
- Because `code-pushing` lives inside `addDefaultFunctionOptimizationPasses()`, it
  also reruns inside Binaryen's optimizing nested pipelines:
  `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing`.

## Exact Binaryen Behavior

### 1. Only Certain `local.set` Roots Are Pushable

- The pass only moves `local.set` roots.
- A candidate local must be in Binaryen's "SFA" form:
  - not a parameter
  - exactly one `local.set`
  - no `local.get` before that set in postorder
- The candidate must also have no remaining uses after the current block.
  Binaryen proves that by comparing `numGetsSoFar[index]` against the total get
  count when it visits a block in postorder.
- The set value must have no unremovable side effects.
  Traps are removable only under Binaryen's trap-relaxing modes; ordinary calls,
  writes, throws, and control transfer are not.

### 2. Push Points Are Very Specific

- Binaryen only tries to push across conditional control boundaries.
- The recognized push points are:
  - `if`
  - `br_on_*`
  - conditional `break` / `br_if`
  - a `drop` wrapped around one of those
- It does not try to sink across arbitrary instructions just because they look
  branchy or pure.

### 3. `optimizeSegment` Pushes Past The Push Point

- Inside one block list, Binaryen finds a segment from the first pushable item to
  the next push point.
- It scans backward from right before the push point.
- It accumulates the effects of:
  - the push point itself
  - any non-pushed intervening roots
  - any earlier pushable that could not move
- It explicitly ignores control-flow-transfer effects in that barrier set.
  The key reasoning is that if control leaves the block early, the pushed local is
  already proven dead on that path.
- Safe pushables are removed from their old positions and reinserted immediately
  before the push point, while preserving their original order.

### 4. `optimizeIntoIf` Can Sink Into Exactly One Arm

- When the push point is an `if`, Binaryen first tries a more specific rewrite:
  sink a `local.set` into one arm instead of only past the whole `if`.
- The barrier set starts with the `if` condition's effects.
- A sink into an arm is allowed only if:
  - that arm reads the local
  - the opposite arm does not read the local
  - there is no later read after the `if`, unless the opposite arm is
    unreachable
- If the sink succeeds, Binaryen prepends the `local.set` to that arm and leaves
  a `nop` in the old slot.
- It refuses to push an `unreachable`-typed set into an arm.
  Doing so would change surrounding block reachability and require refinalization.

### 5. Important Binaryen Bailouts

- No duplication: it never pushes into both arms.
- No recursive re-run after each successful sink.
  The pass relies on later optimizer cycles for follow-on cleanup.
- No special exception logic inside the pass itself beyond what `EffectAnalyzer`
  already models.
  That is why the EH test corpus is mostly effect-analysis coverage.
- Calls are only movable when Binaryen's effect model says they are effect-free.
  The positive test case uses `call.without.effects`; an effectful argument still
  blocks the sink.

## Binaryen Test-Backed Edge Cases

- One-arm use sinks; both-arm use does not.
- A use after the `if` blocks a sink, unless the opposite arm is unreachable.
- Multiple `local.set`s can sink in one segment and must preserve order.
- A non-pushed earlier or later root can block another sink by reading or writing
  the same local.
- Reads or writes in the `if` condition itself also block the sink.
- `br_on_cast` acts like a valid push point when the later use remains inside the
  same block.
- Caught EH can allow a sink; uncaught throws, rethrows, and delegates prevent it.
- `--ignore-implicit-traps` and `-tnh` widen what Binaryen considers removable.
- Binaryen has a GC case where sinking breaks non-nullable-local dominance and the
  pass runner repairs the local typing afterward.

## Current Starshine Surface

- The optimizer owns exactly one body IR: [`HotFunc`](../src/ir/README.md).
- Passes run through the HOT pipeline contract described in
  [`src/ir/README.md`](../src/ir/README.md) and [`0062`](./0062-2026-03-24-pass-porting-checklist.md):
  `lift -> verify -> analyze -> mutate -> verify -> lower`.
- [`src/passes/code_pushing.mbt`](../src/passes/code_pushing.mbt) now exists in an
  analysis-only direct-pass form.
  The first slice landed Binaryen-style body-local SFA counting plus cached
  subtree summaries for local/global read-write sets and conservative
  unremovable-side-effect checks, but it does not yet rewrite HOT regions.
- [`src/passes/optimize.mbt`](../src/passes/optimize.mbt) currently keeps
  `code-pushing` as a removed pass name and omits it from the `optimize` and
  `shrink` presets.
- [`src/passes/pass_manager.mbt`](../src/passes/pass_manager.mbt) now dispatches
  `code-pushing` for direct hot-pass execution, but the registry and presets do
  not expose it yet.
- HOT regions already store root lists directly for root, block, loop, then, else,
  try body, and catch regions.
  That means Starshine does not need Binaryen's `blockify(...)` step when it
  prepends a moved set into an `if` arm.

## Main Gaps Versus Binaryen

### Effect Modeling

- [`src/ir/effects.mbt`](../src/ir/effects.mbt) currently exposes a coarse bitmask.
- That is enough for broad "may read memory / may trap / may throw" checks, but it
  is not the same information Binaryen uses.
- Missing pieces for a faithful port:
  - per-local read/write sets
  - per-global read/write identity
  - removable-vs-unremovable trap distinction
  - `ignore implicit traps` / `traps never happen` policy flowing into hot passes

### Local Typing

- Some current local-handling surfaces still assume body locals are defaultable.
- That means Binaryen's non-nullable-local GC testcase is not a good first-slice
  parity target unless local-type repair support expands.

### Preset Fidelity

- Binaryen runs `code-pushing` between early `precompute` and
  `tuple-optimization` / `simplify-locals-nostructure`.
- Starshine does not yet have `tuple-optimization` or `simplify-locals-nostructure`,
  so the first landing can only model the exact slot relative to the implemented
  passes around it.

## Implementation Plan

### 1. Add A Dedicated Hot Pass

- Create:
  - [`src/passes/code_pushing.mbt`](../src/passes/code_pushing.mbt)
  - [`src/passes/code_pushing_test.mbt`](../src/passes/code_pushing_test.mbt)
- CP001 is the first checkpoint of that step.
  The files now host the direct-pass descriptor, the local SFA analyzer, cached
  subtree barrier summaries, and focused red-green coverage for the analysis
  layer.
- The new pass should mirror Binaryen's structure closely:
  - `code_pushing_descriptor()`
  - `code_pushing_summary()`
  - pass-local local analyzer
  - region-local pusher
  - cached pushable-effect summaries

### 2. Mirror Binaryen's SFA Logic Directly

- Do not start from the SSA overlay.
- Binaryen is not using SSA here; it is using a weaker and very specific SFA test.
- Implement a pass-local postorder walk over HOT nodes and region bodies that
  collects:
  - `num_sets`
  - `num_gets`
  - `sfa`
  - `num_gets_so_far`
- That keeps eligibility aligned with the oracle instead of inventing a stronger
  Starshine-specific criterion.

### 3. Add A Pass-Local Richer Effect Summary

- Keep the first slice local to `code_pushing.mbt` instead of widening
  [`src/ir/effects.mbt`](../src/ir/effects.mbt) immediately.
- Reuse the existing HOT effect mask as the coarse base.
- Layer on explicit pass-local scans for:
  - locals read
  - locals written
  - mutable globals read / written if needed
- Add a `cp_has_unremovable_side_effects(...)` predicate for default Starshine
  semantics first.
- Follow the caching pattern already used in
  [`src/passes/heap_store_optimization.mbt`](../src/passes/heap_store_optimization.mbt)
  so subtree summaries are not recomputed on every backward scan.

### 4. Land The Rewrite In Two Stages

- Stage A:
  Binaryen-style `optimizeSegment` for one region, with push points
  `If`, `BrIf`, `BrOnNull`, `BrOnNonNull`, `BrOnCast`, `BrOnCastFail`, and a
  top-level `Drop` wrapped around them.
- Stage B:
  Binaryen-style `optimizeIntoIf`, sinking into exactly one arm when the arm-use
  and post-`if` conditions match the oracle.
- Keep the first slice conservative:
  - no duplication
  - no sink of `unreachable`-typed values into `if` arms
  - no trap-relaxing modes yet unless pass options are extended first

### 5. Wire The Pass Into The Active Surfaces

- Activate `code-pushing` in:
  - [`src/passes/optimize.mbt`](../src/passes/optimize.mbt)
  - [`src/passes/pass_manager.mbt`](../src/passes/pass_manager.mbt)
- In today's reduced preset, place it immediately after the early `precompute`
  slot:
  `... -> pick-load-signs -> precompute -> code-pushing -> simplify-locals -> ...`
- That preserves the correct Binaryen neighborhood among the passes Starshine
  actually implements today.

### 6. Treat Full Binaryen Mode Parity As Follow-Up

- If exact Binaryen TNH / implicit-trap behavior matters, extend
  [`HotPipelineOptions`](../src/passes/pass_manager.mbt) and the hot pass context
  to carry trap-mode policy.
- Only after that add equivalents of Binaryen's:
  - `code-pushing_tnh.wast`
  - `code-pushing_ignore-implicit-traps.wast`
- Keep the non-nullable-local GC family out of the first landing unless local type
  repair support is made explicit.

## Initial Test Matrix

- `br_if` sink of one `local.set`
- multiple `local.set`s sink while preserving order
- blocked by a use after the containing region
- sink into `then` only
- sink into `else` only
- blocked when both arms read the local
- allowed when a post-`if` use exists but the opposite arm is unreachable
- blocked by condition-local read / write / tee interference
- blocked by an intervening non-pushed root that aliases the local
- `br_on_cast` positive and out-of-block-use negative
- caught-throw positive and uncaught-throw negative
- `call.without.effects` positive only when the call arguments are effect-free
- registry and preset trace coverage for the one CP slot

## Correctness Constraints

- Only move SFA `local.set` roots.
- Preserve original order among moved roots.
- Never duplicate computation.
- Never increase execution frequency; only sink behind extra conditions.
- Never move across barriers that can change observable local, global, memory,
  table, throw, or trap behavior.
- Match Binaryen's ordinary trap semantics first.
- Do not claim GC non-nullable-local parity until the pass pipeline can represent
  or repair that case soundly.

## Validation Plan

- Add red tests first in [`src/passes/code_pushing_test.mbt`](../src/passes/code_pushing_test.mbt).
- Run:
  - `moon info && moon fmt`
  - `moon test src/passes`
  - `moon test`
- Then compare against Binaryen with:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing`
  - an ordered-prefix replay centered on the early `precompute -> code-pushing`
    slot
- If the compare harness supports it cleanly, add a named pass-fuzz lane for
  `code-pushing`.

## Performance Impact

- The Binaryen algorithm is region-local and backward-scanning, so it should be
  much cheaper than CFG-wide transforms.
- The main cost risk is repeated subtree-summary recomputation.
  The implementation should cache pushable summaries per node and avoid rebuilding
  them inside every segment walk.
- HOT regions should make arm insertion cheaper than Binaryen's AST path because
  Starshine can prepend directly to region roots instead of creating wrapper
  blocks.

## Open Questions

- Whether the richer local/global effect data should remain pass-local or graduate
  into [`src/ir/effects.mbt`](../src/ir/effects.mbt) for later motion passes.
- Whether trap-mode policy should be threaded into
  [`HotPipelineOptions`](../src/passes/pass_manager.mbt) before `code-pushing`
  lands or immediately after the default slice.
- Whether current defaultable-local assumptions make the Binaryen GC `ref-into-if`
  testcase an intentional follow-up rather than a first-slice requirement.
