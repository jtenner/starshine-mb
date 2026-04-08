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
- One more smaller non-repro is still relevant too. `src/passes/code_pushing_test.mbt`
  proves that `code-pushing` already handles the simpler tee-fed sibling shape
  where the movable `local.set` is followed by a kept condition `local.set`,
  then the later `if`, then later reads. That is now mostly historical context:
  the surviving direct-artifact blocker is no longer `48981`, because the
  dropped-carrier extraction frontier has moved far enough to remove that live
  family entirely.
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
- The closer live-shaped retry is now explicitly blocked too. A fresh probe on
  `Func 238` showed that the actual `72005` blocker is an earlier explicit-exit
  `LocalSet` whose value block has a call-prefixed inner block before the final
  payload `br`. Widening that exact call-prefixed carrier wrote
  `.tmp/self-opt-code-pushing-call-prefixed-carrier-20260408` and reintroduced
  an earlier structural drift around printed line `71748`, so that broader
  terminal-inner-owner family was rolled back immediately.
- That call-prefixed blocker is now pinned directly in the reduced suites too.
  `src/passes/code_pushing_test.mbt` keeps the pass negative for the
  call-prefixed terminal-inner-owner carrier, while
  `src/ir/hot_lower_live_repro_test.mbt` proves the same manual reorder still
  lowers and validates. So the `72005` frontier is now split cleanly between
  one exact landed terminal-inner-owner carrier and the closer live-shaped
  call-prefixed variant that remains intentionally blocked.
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
