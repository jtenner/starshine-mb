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
- The pass now also descends through `Drop`-wrapped control roots when looking
  for nested rewrite regions. A new direct regression proves that
  `code-pushing` can now rewrite inside a `drop (block (result ...))` owner
  wrapper when an earlier plain `Block` root exits that dropped owner. That
  closes a real traversal blind spot in the earlier implementation and matches
  the `drop (block $block5 ...)` surface of the live artifact much more
  closely.
- That traversal fix did not move the first artifact diff yet. The fresh replay
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-121480` still has
  the same first `19348` `local.set $20` family, with the next early gaps still
  around `48981`, `61077`, `72008`, and the later structural family near
  `105624`. Runtime also regressed hard (`16579.566 ms` Starshine pass vs
  `49.523 ms` Binaryen; `19044.377 ms` total vs `347.409 ms`).
- So the blocker is narrower again: it is no longer just "the target region is
  hidden under a `Drop` root." The remaining live `19348` family still needs a
  closer reducer than the simple dropped-owner case. The next reduction should
  preserve more of the real predecessor shape, specifically the owner-self
  branch paths and the intervening call barrier that still separate the reduced
  passing case from the live artifact.
- That closer live-like reducer is now landed too. The pass suite now has a
  direct regression for a dropped-owner predecessor chain with owner-self
  branch paths, a later root-level `br`, and the intervening call barrier, and
  `src/ir/hot_lower_live_repro_test.mbt` proves the same reordered shape still
  lowers and validates. To admit that case without reopening the earlier
  carrier bugs, the non-void prefix guard now scans only the reachable prefix
  through the pushpoint: once an unconditional terminal root appears, earlier
  explicit exits no longer block rewrites in the unreachable suffix after it.
  Native `--code-pushing` output on `tests/node/dist/starshine-debug-wasi.wasm`
  still validates after that change.
- The direct parity status is now stale rather than unknown. The latest
  measured replay is still `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-121480`,
  because the new reachable-prefix rule has not been replayed against Binaryen
  yet. The next decisive step is another
  `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing`
  run to determine whether the first `19348` family finally moves and whether
  runtime recovers from the earlier regression.
- The smaller compare lane is no longer hand-wavy either. A new 100-case
  `gen-valid` pass-fuzz replay now finishes at
  `/home/jtenner/Projects/starshine-mb-code-pushing/.tmp/pass-fuzz-code-pushing-post-arity`
  with `100/100` compared cases, `100` normalized matches, `0` validation
  failures, `0` command failures, and `0` mismatches. Along the way it exposed
  and then cleared three local gaps: `code-pushing` was treating `LocalTee` as
  invisible to SFA analysis, it was scanning dead-set motion against the whole
  prefix instead of the actual crossed gap, and it was conservatively blocking
  dead-set motion across local-only gap roots that Binaryen still moves across.
  Those cases are now covered directly in `src/passes/code_pushing_test.mbt`.
- That dropped-result predecessor shape is now reflected in the pass too. The
  current non-void fence ignores earlier explicit exits under `Drop` roots, and
  the real debug-artifact compare stayed valid with that change. The new replay
  is `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-92230`: the
  first `19348` `local.set $20` mismatch family is still present, but the old
  `43657` `local.set $167` family is gone. Runtime did not improve yet
  (`10745.351 ms` Starshine pass vs `54.208 ms` Binaryen; `13345.644 ms` total
  vs `379.276 ms`), so the change is a real parity gain but not yet a
  performance win.
- The next narrowed safe case is now in-tree too. `src/passes/code_pushing_test.mbt`
  and `src/ir/hot_lower_live_repro_test.mbt` now both cover an earlier
  zero-result `Block` root that branches to itself and to the dropped outer
  owner inside the same root, and `code-pushing` now rewrites that case.
  Correctness is the good news; cost is the new blocker. To admit that shape,
  the non-void `Block`-root guard now tracks dropped-owner reachability more
  precisely, but the first implementation was far too expensive on
  `tests/node/dist/starshine-debug-wasi.wasm`. Caching dropped-owner lookups,
  caching per-root guard results, collapsing the `Block`-root decision into one
  cached owner-exit summary, and pruning summary walks when a node's cached
  effect summary has no control all helped. So did caching
  `cp_node_has_explicit_exit` and removing the per-branch temporary target
  array in the dropped-owner owner-exit walk. But the standalone native
  `--code-pushing` replay is still materially slower than the earlier fenced
  baseline. Live `gdb` samples now point at the remaining hot path directly:
  `cp_collect_block_owner_exit_summary` is still spending most of its time in
  `cp_collect_block_owner_exit_summary_for_region`, especially the repeated
  region-holder / root-count traversal under the recursive owner-exit walk. So
  the immediate next task shifted from "add the missing reducer" to
  "make the non-void `Block`-root guard cheap enough for a clean full replay,"
  then rerun
  `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing`
  to see whether the first `19348` family finally moves without keeping the new
  runtime regression.
- The later perf trims that stayed landed are all in that same owner-exit walk:
  live-node caching avoids repeated `free_nodes` scans, active-owner tracking is
  now mark-based instead of a linear owner array, region recursion walks raw
  holders directly, the branch-target path no longer copies `BrTable` target
  arrays or allocates a closure, and the dropped-owner value is threaded
  through the hot branch-target note path as a raw sentinel `Int` instead of an
  `Int?`. Later trims now replace the root-region and node non-void checks with
  exact type-tag tests that avoid copying result arrays, read
  `func.nodes[node_id]` directly inside `cp_collect_block_owner_exit_summary`,
  and remove a duplicate region walk from the recursive owner-exit traversal
  entirely. That last cut was real: a direct native `--code-pushing` replay now
  completes in `25.846s`, and the full compare replay completes again instead of
  being abandoned in the earlier minute-long band.
- A follow-on direct-read probe stays green too: the recursive summary walk now
  reads `func.nodes` and `func.children` directly in its hottest paths, the
  branch classifier no longer reloads branch targets through
  `hot_branch_target(...)` once it already has the node, and the branch-target
  note helper is flattened into the `Br` / `BrTable` summary loop. That did not
  change the basic outcome yet. After the later dead-gap and arity fixes, live
  stacks still sit inside `cp_collect_block_owner_exit_summary` /
  `cp_collect_block_owner_exit_summary_for_region`, so the accessor wrappers are
  no longer the main story; the recursive owner-exit walk itself is.
- The first live parity family has moved forward again with that runtime cut.
  The fresh compare replay is
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-442719`, and the
  first normalized WAT deltas now start at `48978`, `61074`, `72005`,
  `105621`, and `126757`. The earlier `19348` and `43657` families are no
  longer first. Runtime is still far from acceptable though: `24515.088 ms`
  Starshine pass time vs `50.151 ms` for Binaryen, and `27083.322 ms` total vs
  `363.237 ms`.
- The new probe against that first live family changed the diagnosis
  materially. The printed `func $127` mismatch maps to pipeline `Func 148`
  because `tests/node/dist/starshine-debug-wasi.wasm` has `21` imported
  functions. In lifted HOT, the interesting node is not a flat top-level
  `LocalSet(310)` before a sibling `If`; it is a nested dropped-carrier
  shape. Top-level root `Drop#1987` owns `Block#1429`, whose body contains
  `Drop#1782`, whose child `Block#1659` contains `Block#1753`, whose body
  roots include `LocalSet(310)#1776`. The later `LocalSet(335)#2738` and
  `If#2747` are sibling roots outside that dropped carrier. Most importantly,
  `LocalSet(310)#1776` wraps `Call#1775` in HOT, so the current
  `cp_root_pushable_local` check rejects it on purpose. That means the first
  remaining parity gap now looks like a root-splitting / carrier-extraction
  problem rather than another traversal-gate or flat same-region `if`
  placement miss.
- One narrower family is no longer hypothetical now. `code-pushing` now admits
  only the exact owner-only carrier shape
  `LocalSet(Block(Block(Br(payload=If))), LocalGet)` when the payload `if`
  itself has no nested explicit exits, and `src/passes/code_pushing_test.mbt`
  now has two positive plus two negative reducers that pin that boundary. A
  fresh live probe against `If#2747` shows why the first `48978` diff still
  survives: the guard still stops at `offending_root=304`, but the carried
  payload there has `payload_explicit=true`. So the live blocker is not the
  newly-admitted simple owner-only carrier family; it is the nested-explicit-
  exit owner-carrier case.
- The next nested-explicit-exit carrier slice is now partly landed. The pass
  now admits direct payload exits back to the carrier's inner block owner, and
  both the direct and trailing-`LocalGet`-unrelated variants are now covered in
  `src/passes/code_pushing_test.mbt` plus
  `src/ir/hot_lower_live_repro_test.mbt`. The latest direct replay is
  `.tmp/self-opt-code-pushing-inner-owner-v2b`, which keeps the branch on the
  same `48978` / `72005` / `105621` / `126757` parity frontier while slightly
  improving pass time to `960.390 ms` vs Binaryen `52.076 ms`.
- The next widening boundary is also reduced now, but it is intentionally not
  in the pass. A carried-`if` payload that combines a direct inner-owner exit
  with a terminal exit still lowers and validates after the same manual
  reorder, and `src/ir/hot_lower_live_repro_test.mbt` now pins that HOT-safe
  shape directly. But widening the pass for that family removed the `48978`
  diff only by introducing a worse earlier structural mismatch around printed
  line `44251`, so the pass stays conservative there for now.
- The neighboring `simplify-locals` cleanup frontier is narrower too. A closer
  terminal-`if` tail reducer is now pinned in `src/passes/simplify_locals_test.mbt`:
  root `if` with a terminal `return` arm, then the same pure tail locals that
  feed the first direct `214` artifact family. Current behavior there is now
  explicit: `simplify-locals` still leaves the carried tail at top level except
  for the already-landed one-root cleanup (`root 1` becomes `nop`). A direct
  widening that tried to sink those tails into an explicit `else` branch was
  not kept because native `--simplify-locals` replay on
  `tests/node/dist/starshine-debug-wasi.wasm` reintroduced body-result stack
  underflow (`Func 40`, then `Func 141`). So that remaining lane is not “sink
  terminal tails under `if`”; it is “reduce the carried-result form that HOT
  lifting actually uses on the artifact.”
- That same blocked frontier is now pinned one step smaller too. A more direct
  explicit-exit `LocalSet(Block(...), LocalGet)` carrier with a terminal arm
  and an inner-owner `br` arm also lowers and validates after the same manual
  reorder, and `src/passes/code_pushing_test.mbt` now keeps that reducer as an
  explicit negative pass boundary while
  `src/ir/hot_lower_live_repro_test.mbt` keeps the HOT-valid manual reorder.
  A fresh retry that widened this exact block-carrier family wrote
  `.tmp/self-opt-code-pushing-20260408d` and immediately reintroduced the same
  earlier printed `44251` drift in `func $127`, so this smaller block-carrier
  shape now clearly belongs to the same not-kept terminal-owner family as the
  earlier condition-set reducer.
- That tighter blocker also reclassifies `72005`. The remaining printed
  `func $238` delta is no longer a separate same-region sink target: its
  earlier blocker is this same explicit-exit `LocalSet(Block(...), LocalGet)`
  carrier family before the alias `local.set $11` / later `if`. So another
  direct widening aimed at `72005` would only reopen the same blocked
  terminal-owner frontier. The next useful correctness work therefore stays on
  the distinct `48981` dropped-carrier / root-splitting frontier in
  `func $127`.
- The first explicit extraction boundary for that `48981` frontier is now
  pinned too. A smaller dropped-carrier reducer now exists where an alias
  `LocalSet(2)` still lives inside the dropped carrier while the later `if`
  sits outside it. `src/passes/code_pushing_test.mbt` keeps the current pass
  unchanged on that shape, and `src/ir/hot_lower_live_repro_test.mbt` proves
  that manually extracting the alias `local.set` across the carrier boundary
  still lowers and validates. That means the next real CP004 step is no longer
  another same-region sink rule; it is a deliberate dropped-carrier extraction
  rewrite.
- The random-corpus dead-gap family that briefly reopened parity is now closed
  again. After narrowing the dead-gap conflict check so pure crossed
  `global.get` reads do not block a dead `local.set`, the exact saved shape is
  pinned in `src/passes/code_pushing_test.mbt`, and the refreshed fuzz lanes
  are green at `.tmp/pass-fuzz-code-pushing-genvalid-1000-20260408c`
  (`1000/1000`) plus `.tmp/pass-fuzz-code-pushing-genvalid-10000-20260408b`
  (`10000/10000`), both with `0` mismatches and no validation or command
  failures. The mixed and smith-only lanes are semantically green too:
  `.tmp/pass-fuzz-code-pushing-both-1000-20260408b` reaches `289/289`
  normalized matches before the usual `20` Binaryen-side `wasm-smith` parser
  failures, and `.tmp/pass-fuzz-code-pushing-smith-1000-20260408b` reaches
  `165/165` normalized matches before the same parser ceiling.
- The remaining CP004 blocker is therefore back to the direct artifact compare.
  The latest replay is `.tmp/self-opt-code-pushing-call-fed-carrier-20260408`,
  where canonical wasm and normalized WAT still differ, but the old `48981` /
  printed `func $127` / pipeline `Func 148` dropped-carrier family is now gone.
  The first normalized WAT deltas are now `72005`, `105621`, and `126757`, and
  Starshine is still slower than Binaryen (`1190.423 ms` vs `55.888 ms` pass;
  `4033.438 ms` vs `431.717 ms` total).
- The `func $127` family moved because the dropped-carrier frontier is now
  partially landed, not only reduced. `code-pushing` now performs direct alias
  `LocalSet(LocalGet ...)` extraction across a dropped carrier, and it also
  performs a narrow `i32` call-fed `LocalSet(Call ...)` extraction by
  splitting the root into `LocalTee(temp, Call ...)` inside the carrier plus a
  later alias `LocalSet(LocalGet temp)` after the sibling `if`. Both new
  reducers are covered in `src/passes/code_pushing_test.mbt` and
  `src/ir/hot_lower_live_repro_test.mbt`, and the carrier prefix still has to
  stay free of explicit exits for the call-fed form.
- One smaller dropped-carrier subcase is landed now too. The call-fed
  extraction path now ignores earlier prefix roots whose explicit exits
  already satisfy the same safe-explicit rules that the main non-void prefix
  guard uses for `LocalSet(If ...)`, `If`, and safe owner-only carriers. The
  new reduced pass and HOT-lowering repros are green, and the refreshed named
  lane `.tmp/pass-fuzz-code-pushing-genvalid-20260409b` stays `1000/1000`
  with `0` mismatches, validation failures, or command failures. But the fresh
  direct replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2`
  still begins at `48978`, `72005`, `105621`, and `126757`, so the live
  `func $127` blocker is still broader than this safe-prefix dropped-carrier
  variant.
- One nested dropped-carrier wrapper slice is landed now too. `code-pushing`
  can extract the same narrow `i32` call-fed `LocalSet(Call ...)` when that
  set lives one region deeper under a carrier-local `Block` or `Drop(Block)`
  root inside the dropped carrier: the pass now rewrites the nested body in
  place and still inserts the later alias `LocalSet(LocalGet temp)` after the
  sibling `if`. The new pass and HOT-lowering reducers are green, and the
  refreshed named lane `.tmp/pass-fuzz-code-pushing-genvalid-20260409c` stays
  `1000/1000` with `0` mismatches, validation failures, generator failures,
  or command failures. But the direct replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2`
  is still red at the same first two hunk starts `48978` and `72005`, so this
  nested-wrapper extraction is another safe reduced slice rather than the
  remaining live frontier.
- The first live hunk diagnosis is sharper again too. In the current replay,
  the visible `48978` delta is no longer explained by the simpler follow-on
  move `local.set $310 (local.get $397)` crossing a later `if` whose arms
  contain calls: a new direct pass regression already proves Starshine handles
  that plain local-only case. So the remaining `48978` blocker still needs
  extra artifact context beyond "alias `local.set(local.get ...)` across a
  call-containing `if`", likely in the extracted-alias predecessor chain
  around the real `func $127` / `Func 148` shape rather than in the plain
  barrier rule alone.
- The larger structural families are now classified more tightly too. The
  `105621` and `126757` diffs in printed `func $314` and `func $366` are not
  just more same-root reorder misses. In both cases Binaryen increases the
  local count, materializes extra alias locals before the shared `if`, and then
  forwards those aliases after the `if`. Starshine keeps the original smaller
  local set and only forwards the existing values after the `if`. So if exact
  parity on those families matters, the missing capability may be local
  synthesis or a neighboring canonicalization pass, not another guard-only
  widening inside the current `code-pushing` rewrite.
- The downstream cleanup oracle is open again. `simplify-locals` no longer
  aborts or emits invalid wasm on the debug artifact: dead `local.tee`
  rewrites are now limited to a sole `Drop` stack use, dead `local.set`
  rewrites are now limited to locals that are unread anywhere in the function,
  and `src/cmd/cmd_test.mbt` now has a native debug-artifact regression for
  direct `--simplify-locals`. Fresh native `cmd` runs validate both
  `--simplify-locals` and `--code-pushing --simplify-locals`, so the combined
  replay `.tmp/self-opt-code-pushing-plus-simplify-locals-20260408` now
  completes instead of failing early.
- That combined replay is still very much not a parity signoff though. Canonical
  wasm and normalized WAT both remain red, Starshine is still larger
  (`1956918` bytes vs `1791630`), and pass time is still behind (`1145.246 ms`
  vs `399.478 ms`). So the simplify-locals fix is a correctness repair and
  oracle unblocker, not evidence that the remaining `105621` / `126757`
  structural families belong inside `code-pushing`.
- `simplify-locals` does have one more safe local-forwarding slice now, but it
  is intentionally narrow. A top-level pure `local.set` whose value is only
  read by one later top-level `local.get` can now be collapsed directly, and
  the reduced pass repro is pinned in `src/passes/simplify_locals_test.mbt`.
  The broader structured `LocalSetDef` forwarding probe is explicitly not kept:
  native `--simplify-locals` replay on `tests/node/dist/starshine-debug-wasi.wasm`
  reintroduced stack-underflow (`Func 1910`, with an earlier smaller hit at
  `Func 104`). The kept root-only slice validates on the artifact and removes
  the saved fuzz alias case, but the remaining named `gen-valid` mismatches are
  still mostly `nop` vs `drop (const ...)` cleanup differences where Starshine
  is smaller than Binaryen rather than less safe.
- The next direct `simplify-locals` artifact frontier is pinned now too.
  `src/passes/simplify_locals_test.mbt` keeps the same-local result-`if`
  storeback shape unchanged: `local.set L (if (result T) cond then V else
  (local.get L))`, followed by a later `local.get L`. That matches the early
  direct compare families in `.tmp/self-opt-simplify-locals-20260408c`, where
  Binaryen narrows the storeback `if (result)` into a conditional update or a
  use-site forward. So the next meaningful simplify-locals work should reduce
  that storeback family, not reopen broader dead-local-set relaxations.
- That storeback family is now partially implemented too. Root-level
  `local.set L (if (result T) cond then V else (local.get L))` now rewrites
  into a void `if` whose `then` arm performs the `local.set`, and the reduced
  pass regression is green. Native `--simplify-locals` replay on
  `tests/node/dist/starshine-debug-wasi.wasm` remains valid, and the fresh
  direct compare `.tmp/self-opt-simplify-locals-20260408d` moves the old `529`
  family toward Binaryen by removing the outer result-`if` storeback wrapper.
  The overall parity story is still open though: size is unchanged, the first
  direct hunk at `214` is still intact, and the later `641` family still wants
  deeper use-site forwarding than this rewrite provides.
- That next `641`-style frontier is pinned now too. `src/passes/simplify_locals_test.mbt`
  keeps the simpler producer/use pair unchanged for now: a root-level
  `local.set` whose child is a result-`if`, followed immediately by a root that
  consumes that local via `local.get`. That shape is closer to the remaining
  direct compare lane than the earlier same-local storeback family, so the next
  meaningful simplify-locals work should target immediate-use forwarding from
  that producer/use pair instead of reopening the rejected broader dead-local
  relaxations or nested `local.tee` probes that did not move the artifact.
- A direct structured-forwarding attempt against that frontier is now explicitly
  not kept too. Replaying native `--simplify-locals` on
  `tests/node/dist/starshine-debug-wasi.wasm` aborted during lowering because a
  cloned control-valued producer still carried live label structure that the
  local clone helper did not remap. The kept boundary is therefore tighter than
  "single-use structured producer": the in-tree tests now pin both the simple
  immediate-use case and the nested-explicit-exit variant as current negatives,
  and the next useful step is a reducer for the real `641` artifact family
  rather than another broad control-value clone probe.
- One narrower immediate-use forwarding slice is now landed safely though.
  `src/passes/simplify_locals.mbt` now moves a root-level `local.set` of a
  result-`if` into the lone immediate later use slot when the consumer path is
  unique, the crossed prefix is pure, and the producer `if` has no nested
  explicit exits. The kept rewrite reuses the original HOT producer node
  instead of cloning it, so native `--simplify-locals` replay on
  `tests/node/dist/starshine-debug-wasi.wasm` stays valid. The fresh compare
  `.tmp/self-opt-simplify-locals-20260408h` trims Starshine from `1958511` to
  `1958408` bytes, but it still does not move the old `641` hunk, so that
  direct frontier remains the next meaningful simplify-locals reducer target.
- One tee-preserving immediate-use slice is now landed too.
  `simplify-locals` can move a root-level `local.set` of a result-`if` into
  the immediate later use as a `local.tee` when the crossed path is the single
  child-chain into the next root and every remaining read of that SSA value
  stays in a later root of the same holder. The reduced pass test is green,
  native `--simplify-locals` replay on `tests/node/dist/starshine-debug-wasi.wasm`
  still validates, and the fresh compare `.tmp/self-opt-simplify-locals-20260408i`
  trims Starshine again from `1958408` to `1958404` bytes. But it still does
  not move the first direct hunk at `214`, so the next useful simplify-locals
  step is no longer the plain tee-preserving lane; it is the multi-root
  storeback/extraction family that also feeds the later `$2` set before the
  final consumer.
- That tee-preserving mover is now broader in one safe direction too.
  `simplify-locals` now admits read-only structured producers, not just
  result-`if` producers: a root-level `local.set` whose value subtree uses only
  local reads plus structured control with no explicit exits and no nested
  local writes can also move into the immediate later use as a `local.tee`
  under the same single-child-chain / later-same-holder-read constraints. The
  reduced pure-producer pass test is green, native `--simplify-locals` replay
  still validates on `tests/node/dist/starshine-debug-wasi.wasm`, and the fresh
  compare `.tmp/self-opt-simplify-locals-20260408j` cuts Starshine much further
  from `1958404` to `1950336` bytes. The first direct hunk at `214` is still
  unchanged though, so this broader read-only structured mover is useful
  cleanup, not the final fix for the remaining multi-root storeback/extraction
  family.
- That remaining multi-root family is now pinned more directly too.
  `src/passes/simplify_locals_test.mbt` now keeps a closer `214`-style chain
  in-tree: same-local result-`if` storeback, then the `$2`-style pure
  local-set fed by the updated local, then the final consumer local-set.
  Current behavior is explicit there now: `simplify-locals` narrows the first
  root into a void `if`, but still leaves the later two `local.set` roots in
  place. So the next useful step is to decide whether that live family wants a
  deliberate multi-root extraction rewrite or a bounded second
  `simplify-locals` round, instead of reopening more one-root forwarding
  variants blindly.
- That decision point is now explicit too. `src/passes/simplify_locals_test.mbt`
  also reruns that closer multi-root fixture for two consecutive hot rounds,
  and it still leaves the later two `local.set` roots in place. The direct
  artifact experiment says the same thing:
  `.tmp/self-opt-simplify-locals-twice-20260408` shrinks further from
  `1950336` to `1950197`, but the first direct hunk at `214` is still
  unchanged. So the remaining frontier is not just "run simplify-locals
  again"; it needs a deliberate multi-root extraction rewrite if we want to
  move that family.
- One more smaller non-repro is still relevant too. `src/passes/code_pushing_test.mbt`
  proves that `code-pushing` already handles the simpler tee-fed sibling shape
  where the movable `local.set` is followed by a kept condition `local.set`,
  then the later `if`, then later reads. That is now mostly historical context:
  the surviving direct-artifact blocker is no longer `48981`, because the
  dropped-carrier extraction frontier has moved far enough to remove that live
  family entirely.
- The analogous `simplify-locals` carried-tail assumption is narrower now too.
  `src/ir/hot_lower_live_repro_test.mbt` now proves that a direct carried block
  with body roots `If, LocalSet, LocalSet, LocalSet, Br` still lowers and
  validates after those terminal tail roots are sunk into an explicit `else`.
  So the first remaining direct `214` family is not blocked by the plain direct
  carried-tail form itself; it needs extra lifted carrier scaffolding above
  that simpler shape.
- The parent-exit version is green too. The same HOT file now proves that the
  sink still lowers and validates when the final payload `br` exits to a parent
  outer result block rather than the local carrier itself. So the first
  remaining direct `214` family is narrower again: it is not explained by the
  plain parent-exit carried-tail form either.
- The function-body version is green too. The same HOT file now proves that the
  sink still lowers and validates when the suffix ends in a top-level `return`
  instead of a carrier `br`. So the first remaining direct `214` family is not
  explained by any of these plain terminal-tail carrier shapes by themselves.
- The next live family at `72005` is narrower in the same way. A new reducer in
  `src/passes/code_pushing_test.mbt` proves the pass already handles the
  simpler alias-set form from that diff too: alias `local.set`, then a kept
  loaded condition `local.set`, then the later `if`, then later reads. So the
  surviving `72005` artifact family also still depends on broader artifact
  context than ordinary same-region sibling motion.
- One narrower terminal-owner subfamily is now landed too. `code-pushing` now
  admits the exact earlier explicit-exit `LocalSet(Block(...), LocalGet)`
  carrier whose payload `if` has one terminal arm and one direct inner-owner
  exit arm, but only when the trailing `local.get` is the same payload-written
  local. The focused pass reducer is green and the kept replay
  `.tmp/self-opt-code-pushing-terminal-inner-owner-20260408` stays valid while
  preserving the same live frontier (`72005`, `105621`, `126757`), so that
  exact family is safe but still not the real artifact blocker.
- The current tree is fail-closed again on the real artifact. `src/passes/pass_manager.mbt`
  now keeps the original function when lowered `code-pushing` output trips the
  existing suspicious escape-carrier guard, and fresh native replay
  `.tmp/code-pushing-native-20260410h.wasm` validates again on
  `tests/node/dist/starshine-debug-wasi.wasm`.
- The kept fallback is intentionally narrower than a whole-function validation
  fence. A temporary variant that also revalidated every changed lowered
  function against the module environment restored validity too, but traced
  replay showed the debug artifact only ever skipped `Func 1948` and `Func
  1977`, both for `suspicious-escape-carrier`, and direct compare stayed very
  slow. The kept version therefore reuses only the existing invalid/suspicious
  escape-carrier detectors instead of layering a broader writeback-validation
  barrier on top of every changed `code-pushing` function.
- The newer fallback is still narrow, but it is no longer a blind heuristic
  veto. `src/passes/code_pushing_wbtest.mbt` now proves one real terminal-owner
  / parent-escape carrier still lowers and validates even though the lowered
  Wasm matches the coarse suspicious escape-carrier heuristic.
  `src/passes/pass_manager.mbt` therefore now rechecks suspicious
  `code-pushing` lowers with
  `run_hot_pipeline_precompute_writeback_validation_error`, and it only keeps
  the original when that full-module writeback validation still fails.
- The current guard is narrower again. `src/passes/code_pushing.mbt` now keeps
  the one-off high-risk alias-if-tail fence for the old `Func 1977` invalid
  family, but it no longer blocks repeated alias-if ladders. That readmits the
  earlier valid `Func 1948` rewrite chain while still keeping `Func 1977`
  unchanged before lower/writeback. The refreshed named lane
  `.tmp/pass-fuzz-code-pushing-genvalid-20260410w` stays `10000/10000` with
  `0` mismatches, validation failures, or command failures, native replay
  `.tmp/code-pushing-native-20260410w.wasm` validates on
  `tests/node/dist/starshine-debug-wasi.wasm`, and `src/cmd/cmd_test.mbt` now
  pins both artifact facts directly: traced replay still rewrites `Func 1948`,
  and it no longer reports `skip-invalid-lower` for `Func 1977`.
- One smaller Binaryen mismatch is now closed explicitly. A reduced nested-block
  repro showed that Binaryen keeps a `local.set` outside a nested `if` when the
  same local is still read after the enclosing block; Starshine used to sink
  that set anyway because it only checked later reads inside the nested region.
  `src/passes/code_pushing.mbt` now tracks ancestor-continuation reads through
  cached region-parent links before treating a nested-region `local.set` as
  pushable, the new regression in `src/passes/code_pushing_test.mbt` is green,
  and the direct reduced WAT now matches Binaryen exactly. The refreshed
  compare-pass lane `.tmp/pass-fuzz-code-pushing-genvalid-20260410aa` is also
  `10000/10000` with `0` mismatches, validation failures, generator failures,
  or command failures.
- One broader expression-position family is now pinned too. Binaryen also
  rewrites nested `block (result ...)` carriers when they sit under ordinary
  wrapper expressions, not just when the region holder is already a root or a
  dropped carrier. Reduced oracle checks now cover the same pushed shape through
  `local.set`, `local.tee`, and `global.set` value-block carriers, and
  `src/passes/code_pushing_test.mbt` keeps all three reduced families green in
  tree. The kept implementation does not widen semantics further than that: it
  precomputes a per-iteration `subtree_has_region_holder` bitmap before the
  nested child walk so generic expression trees without any nested region holder
  are skipped entirely. The refreshed same-tree compare-pass lane
  `.tmp/pass-fuzz-code-pushing-genvalid-20260410ac3` is `10000/10000` with `0`
  mismatches, validation failures, generator failures, or command failures.
- That same tree is still not a runtime signoff. A direct release replay with
  `_build/native/release/build/cmd/cmd.exe --code-pushing --out ...
  tests/node/dist/starshine-debug-wasi.wasm` stayed above `5` minutes of CPU
  time and was aborted, so the new bitmap proves the expression-position parity
  slice without yet closing the artifact runtime gap.
- A kept performance slice is landed now too. `cp_try_rewrite_region(...)`
  only runs `cp_try_sink_into_if(...)`,
  `cp_try_extract_local_set_from_dropped_carrier(...)`, and
  `cp_try_push_to_pushpoint(...)` on actual pushpoint roots, and the latter two
  target-specific helpers now resolve the target `if` / pushpoint before
  scanning non-void prefixes for explicit exits. The refreshed compare-pass
  lane `.tmp/pass-fuzz-code-pushing-genvalid-20260410ab` is
  `10000/10000` with `0` mismatches, validation failures, generator failures,
  or command failures.
- That runtime fix also sharpened the remaining parity story. On
  `/tmp/code-pushing-trace-perf1.log`, traced serial replay still changes only
  `Func 148` and `Func 1948`, but total `pass:code-pushing` drops from
  `4454138 us` to `934833 us`, unchanged `Func 3665` drops from `3311870 us`
  to `858 us`, `Func 148` improves from `16157 us` to `12956 us`, and
  `Func 1948` improves from `123505 us` to `100100 us`. The refreshed whole
  compare at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3345552`
  is still canonically and normalized red at `44251` / `44254`, but runtime is
  now `928.451 ms` vs Binaryen `55.628 ms` in the pass and `3496.840 ms` vs
  `373.614 ms` overall. Comparing Binaryen no-pass-vs-pass output against
  Starshine no-pass-vs-pass output also shows that the old stable `48978`
  dropped-carrier move is already present on both sides, so the current live
  frontier really is the later `func $127` local / tuple-materialization family
  rather than another miss on that historical `48978` alias move.
- Traced serial replay is now tighter than the older writeback-validation
  checkpoint. On `/tmp/code-pushing-native-trace-20260410w.log`,
  `code-pushing` changes only `Func 148` and `Func 1948`, `Func 1977` stays
  unchanged, and there are `0` `skip-invalid-lower` lines in the whole replay.
- Direct compare is still red, but the first reopened family moved again.
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1655370` now
  reaches normalized WAT with the first hunk at `44251` in printed `func $127`
  instead of the newer `48978` alias move. The visible shape is broader too:
  Binaryen is materializing extra locals and a carried
  `block $block1 (result i32)` / `br` structure around the earlier
  terminal-owner family, while Starshine still keeps the older straight-line
  local setup there.
- Runtime is still well outside the target bar. The current direct compare
  reports Starshine pass time `4413.342 ms` vs Binaryen `51.978 ms`, and total
  runtime `7013.947 ms` vs `370.277 ms`. Traced serial replay says that runtime
  is still concentrated in the same live function set: `Func 1948` alone spends
  about `125.0 ms` in `code-pushing` on the serial trace, so future
  performance work should stay focused on that now-smaller changed set instead
  of broad whole-module scans.
- The reduced nested-block outer-read fix did not change the current artifact
  frontier. Direct compare at
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-4176613` is still
  canonically and normalized red with the first hunk at `44251`, and the newer
  serial trace `/tmp/code-pushing-trace-20260410aa.log` still changes only
  `Func 148` and `Func 1948` while spending most of its time in unchanged
  `Func 3665` (`3337746 us`). The current run happened to come in a bit faster
  at `4135.998 ms` vs Binaryen `53.811 ms`, but that is still far outside the
  target bar and does not represent a frontier move by itself.
- One more reduced lowering family is now closed, but the artifact frontier did
  not disappear with it. `src/ir/hot_lower.mbt` now rebases label depths when a
  parent-exit `br` is sunk into an `if` arm, and it keeps the original
  result-`if` plus trailing-`br` form when exactly one arm is already
  nonfallthrough. The new reduced regression in
  `src/passes/code_pushing_test.mbt` is green, `moon test src/passes` is back
  at `507/507`, `moon test src/ir` is back at `234/234`, the native
  debug-artifact `cmd` lane is `3/3`, and the refreshed compare-pass lane
  `.tmp/pass-fuzz-code-pushing-genvalid-20260410x` is `10000/10000` with `0`
  mismatches.
- That repair changed what the first live artifact blocker is. Direct compare at
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3313274` is still
  red, but the old top-of-`func $127` dropped-live-value corruption is no
  longer the first actionable issue. The first visible diff is now later in the
  same function at `44254`, where Binaryen and Starshine still disagree on
  local / tuple temp materialization (`local $474` / `$475` `i32` vs `i64`,
  plus later tuple temp numbering), while runtime is still poor at
  `4611.631 ms` vs `55.247 ms` in the pass and `7421.741 ms` vs `407.483 ms`
  overall.
- The reopened `44251` direct hunk is not a stable raw-oracle boundary by
  itself. `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --require-binaryen-nop-converged --code-pushing`
  fails because Binaryen no-pass writeback still does not converge within five
  roundtrips on this artifact (`/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2309436/binaryen.nop5.wasm`).
  A fixed-roundtrip replay at
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2325799` is still
  red, but its first normalized WAT hunks move up to `27790`, `27841`,
  `28246`, and later `45771` / `46157` instead of starting at `44251`. So part
  of the reopened raw WAT drift is still mixed with Binaryen's own multivalue /
  local-materialization writeback noise rather than being a stable pass-only
  frontier.
- One obvious performance idea was tested and rejected. A temporary memoization
  of the simple-owner payload, terminal-inner-owner payload, and ignorable
  non-void prefix-carrier shape checks made traced serial replay slower, not
  faster: total `pass:code-pushing` rose from `4198179 us` on
  `/tmp/code-pushing-trace-20260410n.log` to `4552778 us` on
  `/tmp/code-pushing-trace-20260410r.log`, the unchanged hotspot `Func 3665`
  worsened from `3139111 us` to `3466464 us`, and the live changed `Func 1948`
  barely moved (`118911 us` to `119868 us`). That probe was rolled back. The
  next performance work should therefore avoid more prefix-carrier memoization
  and instead target the remaining huge unchanged whole-function cost directly.
- Traced serial replay on the current safe tree shows that `code-pushing` only
  changes four functions on the debug artifact: `Func 737`, `Func 1566`,
  `Func 1948`, and `Func 1977`. The latter two then hit
  `pass[code-pushing]:skip-invalid-lower` for `suspicious-escape-carrier`. So
  the current runtime and parity gap is concentrated in a very small live set,
  not in broad whole-module churn.
- One more real blind spot is gone now, but it was not the whole live family.
  `src/passes/code_pushing.mbt` now walks branch payload children before
  classifying explicit-exit carrier safety, and it now treats block / loop /
  if / try region bodies as part of explicit-exit detection instead of only
  scanning node children. The new reduced regressions in
  `src/passes/code_pushing_test.mbt` plus
  `src/passes/code_pushing_wbtest.mbt` prove two narrower risks are gone: the
  pass no longer trusts an earlier `LocalSet(Block(...))` prefix that mixes an
  owner exit, a terminal path, and a hidden parent-escape branch inside the
  carried branch payload, and it no longer rewrites past an earlier nested
  branch that appears only in a block body region. The refreshed named lane
  `.tmp/pass-fuzz-code-pushing-genvalid-20260410h` stays `10000/10000` with
  `0` mismatches, validation failures, or command failures on the kept safe
  tree. So reduced parity is still clean even though whole-artifact parity is
  not.
- A narrower unary `Call(LocalTee(Call ...))` extraction probe was reduced
  during this checkpoint too, because the remaining `Func 238` structural diff
  still looks like Binaryen alias-local forwarding more than another plain
  `local.set(local.get ...)` reorder. The small reducer plus HOT-lowering proof
  were both green, but the real debug artifact still re-hit the same `Func
  1977` stack-underflow cliff, so that probe was rolled back instead of being
  kept as another local extraction rule. That makes the next correctness target
  clearer historically: regain direct artifact validity on the live `Func 1977`
  family first, then revisit the broader `Func 238` alias-local synthesis lane.
- Direct compare is honest again now, and it reopens the older semantic
  frontier. `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1323760`
  validates to completion but is still canonically and normalized red, with the
  first WAT hunk back at `48978` in printed `func $127`, followed by a broader
  cluster at `136878`, `137324`, and `137684` in printed `func $393`, then
  later families at `146681`, `150584`, `152641`, `166964`, and beyond. So the
  current branch is no longer blocked on invalid output; it is blocked on a
  still-open missed-move / ordering frontier.
- Runtime is still well outside the target bar even after restoring validity.
  The current valid compare reports Starshine pass time `4640.306 ms` vs
  Binaryen `59.083 ms`, and whole-command time `7306.772 ms` vs `396.894 ms`.
  Because trace shows only four changed functions, the next runtime work should
  focus on those few live hot functions and their root-motion scans rather than
  on whole-pass policy plumbing.
- The closer call-prefixed carrier slice is landed now too. `code-pushing`
  still requires the same terminal-inner-owner local-match rule, but it no
  longer rejects the carrier just because the inner owner block does extra
  non-exiting work before the final payload `br`. The updated pass regression
  is green, the existing HOT-lowering proof for the same manual reorder still
  validates, and the refreshed named lane
  `.tmp/pass-fuzz-code-pushing-genvalid-20260409d` stays `1000/1000` with `0`
  mismatches, validation failures, or command failures.
- That means the old `72005` checkpoint is no longer the right description of
  the remaining `Func 238` family. After landing the call-prefixed carrier
  slice, the direct debug-artifact replay still differs in `Func 238`, but the
  visible mismatch has widened into a broader root-structure hunk starting at
  printed line `71748` instead of the old smaller `local.set`-only `72005`
  delta. So this family is still live, but it has moved past the exact
  call-prefixed terminal-inner-owner carrier that used to be intentionally
  blocked.
- A fresh retry confirmed that the terminal-owner family is still not ready to
  land, even under a narrower local-type fence. Re-admitting only the `i32`
  version of that direct inner-owner plus terminal-exit carrier still
  reintroduced the same earlier printed drift at `44254`, while again removing
  the old `48978` family. So the pass is back on the conservative fence, and
  `src/passes/code_pushing_test.mbt` now keeps that direct terminal-owner
  carrier as an explicit negative boundary while the HOT-only proof remains in
  `src/ir/hot_lower_live_repro_test.mbt`.
- The earlier `44254` drift is now pinned more precisely too. A temporary live
  trace on the widened pass showed that `Func 148` does not need some second
  earlier carrier rewrite to trigger that mismatch. The actual admission is
  still the same terminal-owner family around `LocalSet(335)#2738`, but in the
  live function it crosses one extra sibling `LocalSet` first: after the
  widening, roots `2738`, `2741`, `2747` become `2741`, `2747`, `2738`, while
  the rest of the traced root prefix stays put. So the earlier printed drift is
  downstream lowering fallout from that same move, not a separate earlier
  `code-pushing` rewrite. `src/passes/code_pushing_test.mbt` and
  `src/ir/hot_lower_live_repro_test.mbt` now pin that closer
  `candidate-set -> condition-set -> later-if` terminal-owner shape directly:
  manual reorder still lowers and validates, but the pass intentionally keeps
  it fenced off.
- Two more safe non-crossed-prefix families are now in-tree as well. The pass
  now ignores earlier explicit-exit `LocalSet(If ...)` carriers with nested
  local writes when those exits stay terminal-or-safe, and it now ignores the
  same terminal-or-safe earlier explicit-exit `If` roots directly. Both landed
  with matching pass plus HOT-lowering reducers.
- That moved the second live family for real. The fresh compare replay at
  `.tmp/self-opt-code-pushing-if-root-v4` removes the old `61077` mismatch
  entirely, so the first normalized WAT deltas now start at `48981`, `72008`,
  `105623`, and `126731`. The first blocker is still the traced dropped-carrier
  `LocalSet(call)` family in printed `func $127` / pipeline `Func 148`, not one
  more flat same-region `if` prefix guard.
- One more smaller non-repro is now pinned beside that live family. A reduced
  root shape with an earlier zero-result branch root, one intervening used
  `LocalSet`, and then a branch-free crossed gap before the later `if` still
  lowers and validates when manually reordered. But letting the pass rewrite
  that shape directly was not keepable: the real debug artifact immediately
  reintroduced the same `Func 1977` stack underflow. So the pass stays
  conservative there for now, and the new reduced HOT-lowering fixture is
  useful only as another proof that the missing ingredient still lives in the
  larger real-function scaffolding rather than in that local gap shape alone.
- That crossed-gap non-repro now also survives the next real-carrier wrappers.
  The same local pattern still lowers and validates after being wrapped in a
  parent-escape carrier, after extraction through the parent `err` block, in a
  closer real carrier with the later store/drop tail, and after extraction
  through the real parent `err` block as well. So the current nearest positive
  result is sharper than before: even the crossed-gap variant of the closer
  real-carrier family is still not enough by itself to reproduce the invalid
  module. The remaining unsafe ingredient is still beyond that local tail
  pattern and those extraction steps.
- The nearest failing step for that crossed-gap ladder is now pinned too. Once
  the extracted real crossed-gap carrier makes the parent `err` block
  result-producing, HOT verify hits the same `InvalidBranchArity(_, _, 0, 1)`
  as the older zero-result family. So this newer branch still lands on the same
  final cliff; it just takes the larger parent-`err` result rewrite to get
  there.
- That cliff is earlier than the extracted-real step though. The reordered real
  crossed-gap carrier already hits the same `InvalidBranchArity(_, _, 0, 1)`
  once the parent `err` block becomes result-producing, and the smaller
  parent-escape crossed-gap carrier does too. So the crossed-gap tail itself is
  no longer the distinguishing ingredient; the remaining unsafe rewrite sits
  upstream in the transition that makes the parent `err` block result-producing.
- One smaller crossed-gap overblock is now closed again too. The later
  condition-set alias guard had grown broad enough to block a reduced earlier
  explicit-exit `LocalSet(Block(...), LocalGet)` fixture whose carrier is
  already one of the pass's whitelisted self-contained owner-payload shapes.
  The current pass now excludes those whitelisted carriers from the risky
  crossed-gap alias guard, which restores the reduced nested self-owner move
  without reopening the blocked `candidate-set -> condition-set -> later-if`
  terminal-owner family. Focused `code-pushing` and native `cmd` tests are
  green again, but the whole-artifact replay still needs to be refreshed on the
  kept fence.
- On the performance side, a fresh live native stack sample no longer landed in
  the recursive owner-exit walk first. It hit `cp_region_roots_copy` through
  repeated `hot_region_get` / holder lookup instead. Deferring that copy until
  a rewrite candidate actually survives `cp_try_push_to_pushpoint` moved the
  native debug-artifact path from the last `28.597s` sample down to `26.373s`
  and `26.904s`. That is still far from Binaryen, but it confirms whole-region
  root copies are another real hot cost on the current path.
- The next hotspot after that was much larger. A fresh live sample moved into
  `effects_accumulate_node_cached` via `cp_effect_summary_for_node`, and the
  cause was direct: `cp_effect_summary_for_node` was still calling
  `effects_for_node`, which allocates fresh `node_masks` / `ready` arrays and
  recursively rebuilds masks for each query. Reusing the pass pipeline's cached
  `HotEffectsSummary.node_masks` inside `CpSummaryCache` dropped the native
  debug-artifact path again, from the `26.3s` band to `8.430s` and `8.449s`,
  both with valid output. That finally puts the direct native path below the
  earlier `< 1s or >= 50% of Binaryen where possible` guardrail on the same
  order of magnitude, even though the full compare replay still needs to be
  rerun.
- After the shared effects-cache cut, the next cheap structural win was
  function-level rejection. `code-pushing` was still paying for local analysis,
  summary-cache setup, and region traversal on functions with no possible
  candidate shape. A new linear live-node pre-scan now bails out before any
  summary-cache work when a function has no non-param `local.set`/`local.tee`
  and no pushpoint op at all, and a second gate exits before region rewriting
  when local analysis finds no SFA locals. That pushed the native
  debug-artifact path down again from the `8.4s` band to `7.100s` and `7.109s`,
  both with valid output. So the remaining work is no longer just “cut obvious
  GC churn”; the direct native lane is now much closer to the compare-signoff
  threshold, and the next meaningful question is what the full replay looks
  like.
- The next perf tranche stayed in whole-function setup rather than parity
  widening. `code-pushing` now pulls cached effect node masks directly from
  [`HotAnalysisCache`](../src/ir/analysis_cache.mbt), allocates real
  `CpSummaryCache` bitsets lazily instead of eagerly for every live node,
  precomputes dropped-owner/global scans once per function, and carries the
  reachable-prefix start index directly instead of rescanning from region start
  on each guarded move. Those changes moved the direct native debug-artifact
  path from the `7.1s` band down into the `4.7s` to `5.1s` band, while traced
  local runs dropped `analysis:effects` to about `0.25s` and
  `pass:code-pushing` to about `2.44s-2.62s`.
- The next whole-second cut then came from a stronger traversal disqualifier.
  `code-pushing` now rejects functions and nested regions unless they contain
  an SFA `LocalSet` root with a cheap movable value before a later `If` or
  conditional pushpoint root, memoizes that by region holder, and reuses the
  same region cache during the actual rewrite walk. That pushed the same direct
  native debug-artifact path down again from `5.072s` to `4.205s` and then
  `3.604s`, while traced `pass:code-pushing` dropped from `2469578 us` to
  `1731189 us` and then `1290492 us`. The biggest unchanged parser outliers
  were effectively removed too: `Func 3617` fell from `337161 us` to `574 us`,
  `Func 1558` from `254285 us` to `410 us`, and `Func 1530` from `197051 us`
  to `242 us`.
- The next perf tranche stayed in the actual backward scans rather than the
  whole-function entry gate. `code-pushing` now ignores terminal unrelated
  pushpoints during traversal gating, caches the last root index that reads
  each local per region, maintains an incremental dead-gap summary instead of
  rescanning crossed gaps for dead-set motion, and memoizes both trivial
  dead-gap roots and pushable `LocalSet` roots within an iteration. That moved
  the same direct native debug-artifact path down again from `3.604s` to
  `3.559s`, `3.348s`, and then `3.160s-3.162s`, while traced
  `pass:code-pushing` dropped from `1290492 us` to `1245985 us`, then
  `1136216 us`, and finally `1095736 us`. The unchanged share fell again too,
  from `963639 us` to `809435 us`.
- That changed the hotspot mix again. `Func 1678` is no longer the dominant
  unchanged outlier; it fell from `75809 us` to `27783 us`, while the top
  remaining pass-local costs are now the real mutating `Func 1816`
  (`164475 us`) plus unchanged functions `Func 2609` (`35147 us`), `Func 1910`
  (`28200 us`), `Func 1678` (`27783 us`), and `Func 2010` (`18059 us`). The
  next performance decision is therefore narrower than before: either keep
  attacking those remaining late rewrite scans, especially on the real mutating
  `Func 1816`, or accept that the next large wall-time chunk is now increasingly
  outside `code-pushing` itself and spend the next budget on permission-gated
  parity replay instead.
- The next perf cut stayed in unchanged-region overhead rather than deeper
  effect modeling. `code-pushing` now reads valid region roots through a
  pass-local precomputed root view instead of repeated
  `hot_region_root_count(...)` / `hot_region_get(...)` accessor calls,
  rebuilds moved roots sparsely instead of allocating root-sized `movable` /
  `move_after_target` arrays for every pushpoint scan, and reuses that same
  root view across same-region sink and push rewrites. That pushed the direct
  native debug-artifact path down again into the `2.996s-3.176s` band, and the
  latest traced native replay `/tmp/code-pushing-trace-pass3.log` now has
  `pass:code-pushing = 978556 us`, `analysis:effects = 249694 us`,
  `lift = 1274934 us`, and `lower = 60600 us`. The hotspot mix narrowed again:
  mutating `Func 1816` dropped from `191303 us` to `149339 us`, while the
  largest unchanged outliers are now `Func 2609` (`30802 us`), `Func 1910`
  (`27009 us`), `Func 1678` (`25576 us`), and `Func 2010` (`19791 us`).
  So the next perf question is sharper still: either attack the 19 rewrite
  iterations inside `Func 1816`, or stop shaving local pass cost and spend the
  next budget on the permission-gated full compare replay.
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
