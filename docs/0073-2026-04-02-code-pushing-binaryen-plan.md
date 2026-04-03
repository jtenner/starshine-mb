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
- [`src/passes/code_pushing.mbt`](../src/passes/code_pushing.mbt) now exists in a
  rewrite-capable direct-pass form.
  CP001 landed Binaryen-style body-local SFA counting plus cached subtree
  summaries for local/global read-write sets and conservative
  unremovable-side-effect checks.
  CP002 now rewrites HOT regions directly for `if`, `br_if`, `br_on_*`, and
  `drop`-wrapped push points, including stable same-region reordering plus
  one-arm `if` sinking with the terminal-opposite-arm later-read exception.
- [`src/passes/optimize.mbt`](../src/passes/optimize.mbt) now registers
  `code-pushing` as an active hot pass and replays it in both `optimize` and
  `shrink` immediately after the early `precompute` slot.
- [`src/passes/pass_manager.mbt`](../src/passes/pass_manager.mbt) now dispatches
  `code-pushing` for direct hot-pass execution, and the CLI can invoke it
  directly via `--code-pushing`.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../scripts/lib/pass-fuzz-compare-task.ts)
  now includes `code-pushing` in the named compare-pass allowlist, so a dedicated
  differential fuzz lane exists even before debug-artifact replay is available in
  this workspace.
- The current debug-artifact replay is valid again after two conservative
  correctness fences in [`src/passes/code_pushing.mbt`](../src/passes/code_pushing.mbt):
  Starshine no longer reorders same-region roots inside non-void regions, and it
  no longer sinks `local.set` roots into result-producing `if` arms. The latest
  artifact compare still differs from Binaryen, but the remaining work is back to
  parity and runtime rather than invalid lowered output.
- Two narrower relaxations tried against the debug artifact are still unsound:
  allowing non-void rewrites only for regions with a simple trailing payload
  split, and allowing them only at the root region, both reintroduced the same
  `Func 1977` stack-underflow family. That means the next correctness step needs
  a smaller reducer for that family before the fence can be relaxed.
- The latest reduction attempt narrowed that family further: an isolated
  root-result sibling-`if` shift was not enough to recreate the validation
  failure by itself. The unsafe `Func 1977` diff also rewrites earlier
  result-carrier blocks (`if I32` becoming `if (Void)` with extracted carrier
  locals), so the next reducer needs to cover that broader non-void carrier
  shape rather than only the final root-region tail move.
- A second split-carry reducer narrowed it again: manually swapping the paired
  branch-local `local.set` roots inside a smaller carried `if` still validated
  after lowering. That suggests the remaining `Func 1977` bug depends on the
  enclosing non-void carrier-region rewrite, not only the branch-local order of
  those carried sets.
- Even combining that carried result shape with a later root-level sibling-`if`
  shift still validated in isolation. The remaining bad case therefore appears
  to need more of the original control-flow scaffolding than these reduced
  carrier-only shapes preserve, likely still inside the enclosing non-void
  carrier region that the current fence blocks entirely.
- A closer forwarder-style block scaffold also still validated after the same
  local-set-after-sibling-`if` move. So the missing ingredient is probably not
  just the nested result-block shell; the failing `Func 1977` family likely also
  depends on more of the real call/refcount behavior that those reducers still
  strip away.
- A temporary unfenced replay confirmed the exact invalid lowered family more
  concretely: the bad output really does split a carried payload upward through
  the parent escape block and retarget the surrounding branch payload there. But
  even a direct HOT lowering repro of that extracted-payload-through-parent-`br`
  scaffold still validated in isolation, and adding the matching inner
  carried-`if` demotion to `if (Void)` still validated too. So the remaining
  `Func 1977` blocker still needs extra real-function control-flow scaffolding
  beyond the carrier extraction plus inner carried-`if` rewrite alone.
- The validator offset for the real failure is now pinned too: the invalid module
  underflows at `br 3` to label `@8` in `Func 1977`, and a new focused HOT-verify
  repro now proves the mechanism behind that class of failure. If the parent
  escape block is also rewritten to become result-producing after the carried
  payload extraction and inner carried-`if` demotion, HOT verification rejects
  the branch with `InvalidBranchArity(_, _, 0, 1)`.
- There is now a smaller direct HOT-verify reducer for the same branch-arity
  class too. A tiny carried `if` fixture becomes invalid as soon as one arm's
  `br` is retargeted from the inner void work block to the outer result block,
  because that jump skips the result payload site entirely. That removes most of
  the earlier real-carrier scaffolding from the minimal proof.
- There is also now a middle-step parent-exit reducer between that tiny retarget
  case and the real-carrier helper: the smaller `parent-exit payload carry`
  fixture stays valid normally, but HOT verification rejects it with the same
  `InvalidBranchArity(_, _, 0, 1)` as soon as the parent exit block itself is
  rewritten to become result-producing. That bridges the gap between the direct
  retarget mechanism and the larger parent-escape carrier family.
- The pass suite now guards that same boundary directly too. A new
  `code_pushing_test.mbt` regression lifts the closer real carrier fixture and
  asserts that `code-pushing` leaves the parent `err` block as a single `Br`
  with the carrier body still in `Block, LocalSet(5), If, Store, Drop,
  LocalGet(3)` order, and a smaller parent-exit payload-carry pass regression
  now leaves its `exit` body in `Block, Br` form with the nested work block
  still `If, Unreachable`. So the current fence is pinned at the pass layer as
  well as in HOT verification.
- The current safe non-void relaxation is now narrower than "branch-free whole
  region" but still broader than the old blanket fence. `code-pushing` may now
  reorder inside a non-void region when the prefix up through the pushpoint has
  no explicit exits, even if a later root in the same region branches. That
  landed with direct pass coverage for both a branch-free nested/root non-void
  region and a "later branch root" non-void case, and it moved the first
  debug-artifact parity diff forward from line `17460` to line `19345` in
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-43607`, with
  Starshine pass time dropping from `12662.937 ms` to `9907.976 ms`.
- A follow-on attempt to relax that fence further by ignoring earlier
  zero-result branch roots did not hold on the real artifact. The smaller local
  fixture still validates in isolation, but the debug artifact reintroduced the
  same `Func 1977` stack-underflow under that rule, so zero-result explicit-exit
  prefixes are still conservatively blocked in the last known-valid state.
- `src/ir/hot_lower_live_repro_test.mbt` now records that local non-repro
  directly too: manually reordering a reduced earlier-zero-result-branch prefix
  to `Block, If, LocalSet, LocalGet` still lowers and validates. So that
  earlier-zero-result prefix shape is not sufficient by itself; the remaining
  bad family still needs extra surrounding carrier scaffolding from the real
  `Func 1977` case.
- That non-repro now extends one step outward as well. Wrapping the same
  earlier-zero-result prefix in an outer result carrier with a payload `br`
  still lowers and validates after the same reorder. So the remaining bad
  family needs more than just "earlier zero-result branch root + outer result
  carrier"; it still depends on richer real-function scaffolding.
- It also survives a simplified parent-escape extraction now. A reduced
  parent-escape carrier with the earlier zero-result branch root still validates
  after both the local reorder and the same "extract payload into parent err
  block" rewrite pattern that is valid on the simpler carrier fixtures. So the
  remaining `Func 1977` failure still needs more than that extracted
  parent-escape shape too.
- That boundary now extends to the closer real-carrier scaffold too. Manually
  inserting the same earlier zero-result branch root into the real parent-escape
  carrier body and reordering it into the broader-relaxation shape still lowers
  and validates. So the remaining bad family is narrower again: it needs more
  than just "real carrier plus earlier zero-result prefix" and still depends on
  a richer rewrite path than the local carrier reorder alone.
- Even the next closer extraction step still validates on that real carrier.
  After the same earlier zero-result branch root is inserted, extracting the
  moved payload through the parent `err` block and demoting the carried `if` to
  `if (Void)` still lowers and validates. But forcing that same parent `err`
  block to become result-producing immediately trips the same
  `InvalidBranchArity(_, _, 0, 1)` mechanism as the smaller reducers. So the
  remaining artifact gap still needs more than "real carrier + earlier zero-
  result prefix + parent-err extraction"; it also needs the outer rewrite step
  that turns the parent escape block into a result carrier.
- A separate predecessor-root reduction also stayed valid: an earlier dropped
  result-carrying block root before two later `local.set`s and a sinkable `if`
  still lowers after moving the unused `local.set` past the `if`. So the live
  diff still needs more than "earlier explicit-exit predecessor root before the
  sink" in isolation too.
- The next closer predecessor-root reduction also stays valid in HOT. A
  self-contained earlier `Block` root whose internal payload branches stay
  entirely inside nested labels still lowers after the same `local.set` sink.
  A first owner-aware pass attempt to relax that family was too broad and got
  rolled back because it also weakened the known-unsafe zero-result and
  split-carry blockers. So the next pass change still needs a narrower notion
  than "earlier root has no escaping explicit exits".
- That narrower self-contained `Block`-root rule is now landed in the pass
  too. The current non-void fence still ignores earlier `Drop` roots outright,
  and it now also ignores earlier `Block` roots when every explicit exit inside
  that block stays within nested labels owned by the same block. Escaping exits
  from the block still block the sink. The fresh real-artifact replay
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-109759` stayed
  valid with that refinement and improved Starshine runtime versus
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-92230` (`9754.809
  ms` pass vs `10745.351 ms`; `12203.915 ms` total vs `13345.644 ms`).
- That refinement did not move the earliest parity family though. The first
  normalized WAT mismatch is still the same `19348` `local.set $20` case, with
  later early gaps still around `48981`, `61077`, `72008`, and the larger
  structural family near `105624`.
- Inspection of the remaining `19348` function now suggests the non-void fence
  is probably no longer the immediate blocker there. In the corresponding live
  `func $67` slice, `local $20` still appears as multiple `local.set`,
  `local.get`, and later `local.tee` sites, so the next reduction likely needs
  to explain how Binaryen sinks that non-SFA-looking local-set or prove a
  narrower Starshine local-analysis rule instead.
- That dropped-result predecessor shape is now reflected in the pass too. The
  current non-void fence ignores earlier explicit exits under `Drop` roots, and
  the real debug-artifact compare stayed valid with that change. The new replay
  is `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-92230`: the
  first `19348` `local.set $20` mismatch family is still present, but the old
  `43657` `local.set $167` family is gone. Runtime did not improve yet
  (`10745.351 ms` Starshine pass vs `54.208 ms` Binaryen; `13345.644 ms` total
  vs `379.276 ms`), so the change is a real parity gain but not yet a
  performance win.
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
- CP001 and CP002 are the first two checkpoints of that step.
  The files now host the direct-pass descriptor, the local SFA analyzer, cached
  subtree barrier summaries, the region rewrite core, and focused red-green
  coverage for both analysis and direct HOT rewrites.
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
- CP002 landed the default-semantics direct-pass version of Stage A and Stage B
  on HOT regions, including same-region order-preserving reinsertion and the
  later-read exception when the opposite arm cannot fall through.
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
- Treat non-void-region root reordering and result-producing `if`-arm sinking as
  explicitly deferred until a smaller proof shows those rewrites preserve HOT
  region result structure.

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
