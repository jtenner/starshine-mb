# Binaryen / Starshine `once-reduction` follow-up: local strategy map, code locations, and dossier completion

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/once-reduction/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/once-reduction/index.md`
- `docs/wiki/binaryen/passes/once-reduction/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/once-reduction/dominance-propagation-and-cycle-safety.md`
- `docs/wiki/binaryen/passes/once-reduction/wat-shapes.md`
- `docs/wiki/binaryen/passes/once-reduction/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/parity.md`

## Why this follow-up existed

The `once-reduction` folder already covered the upstream Binaryen side well:

- the landing page explained the pass purpose and scheduler role,
- the Binaryen strategy page covered `OnceReduction.cpp`,
- the implementation/test-map page explained the four-owner split,
- the dominance page covered the most failure-prone reasoning,
- and the WAT-shape page covered the concrete transformed families.

But one practical gap remained for Starshine contributors:

- the folder still lacked the dedicated Starshine strategy/code-map page that the surrounding implemented module-pass dossiers now treat as standard.

That mattered because `once-reduction` is an active implemented pass in this repo, not just upstream research.
Without a dedicated local strategy page, readers had to reconstruct the MoonBit implementation from scattered references in:

- `index.md`
- `parity.md`
- the pass registry / pass-manager files
- and `src/passes/once_reduction.mbt` itself.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/once-reduction/` folder
- `src/passes/once_reduction.mbt`
- `src/passes/once_reduction_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `CHANGELOG.md`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed

Primary official Binaryen sources reviewed for this follow-up:

- Binaryen GitHub release page for `version_129`
- Binaryen `version_129` `src/passes/OnceReduction.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/ir/intrinsics.h`
- Binaryen `version_129` `test/lit/passes/once-reduction.wast`
- Binaryen current `main` `src/passes/OnceReduction.cpp`
- Binaryen current `main` `test/lit/passes/once-reduction.wast`

These were used to keep the new Starshine page honest about:

- the released upstream oracle surface,
- the exact idempotent-annotation behavior that still differs locally,
- and the current-main freshness claim as of **2026-04-21**.

As of **2026-04-21**, the official GitHub release page still labels `version_129` as the latest Binaryen release, so this dossier continues to treat `version_129` as the released oracle rather than an older convenience snapshot.

## Main local code locations captured in the new living page

The new Starshine strategy page now points readers directly to the in-tree owner sites:

- `src/passes/once_reduction.mbt:2`
  - summary string used by the registry and docs
- `src/passes/once_reduction.mbt:153`
  - `or_find_once_global(...)`: current exact once-wrapper matcher
- `src/passes/once_reduction.mbt:183`
  - `or_scan_instrs(...)`: candidate-global read/write scan and dataflow-interest prefilter
- `src/passes/once_reduction.mbt:239`
  - `or_analyze_instrs(...)`: recursive summary propagation with `if`-intersection and loop / try-table conservatism
- `src/passes/once_reduction.mbt:299`
  - `or_rewrite_instrs(...)`: recursive direct-call and redundant-`global.set` rewrite pass
- `src/passes/once_reduction.mbt:398`
  - `or_optimize_once_bodies(...)`: local empty-body and single-call-wrapper cleanup
- `src/passes/once_reduction.mbt:452`
  - `once_reduction_run_module_pass(...)`: end-to-end candidate discovery, fixed point, and module rewrite
- `src/passes/once_reduction_test.mbt:17`
  - repeated once-call elimination coverage
- `src/passes/once_reduction_test.mbt:44`
  - exported-global bailout coverage
- `src/passes/once_reduction_test.mbt:74`
  - empty once-body collapse coverage
- `src/passes/once_reduction_test.mbt:97`
  - multiple independent once-global coverage
- `src/passes/pass_manager.mbt:8642`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:234`
  - registry entry
- `src/passes/optimize.mbt:245`
  - optimize preset placement
- `src/passes/optimize.mbt:257`
  - shrink preset placement
- `src/passes/registry_test.mbt:76`
  - module-pass-category assertion
- `src/cmd/cmd_wbtest.mbt:5760`
  - CLI pass-chain coverage inside the explicit flag roster

## Main findings

### 1. The local pass is a module-level boundary port of the same broad idea, but not the same proof engine

The strongest local headline is:

- **Starshine implements the same basic “private once-bit plus redundant direct call / write cleanup” idea, but it does so with recursive instruction-array scans and rewrites instead of Binaryen's CFG + `DomTree` + nested-pass engine.**

That difference matters because the local code should not be described as if it already had full upstream merge reasoning, current-main idempotent support, or the same exact wrapper matcher.

### 2. The current matcher is much stricter than Binaryen's released wrapper matcher

Binaryen recognizes a top-level block body whose first two items are:

- `if (global.get $g) return`
- `global.set $g (nonzero const)`

Local Starshine currently recognizes only the much tighter four-instruction boundary shape:

- `global.get`
- `if { return }`
- nonzero integer const
- `global.set`

So the MoonBit implementation is not yet a structural clone of the upstream block-based matcher.
That narrower local shape should stay explicit in the living docs.

### 3. The local fixed point is real, but the control-flow proof is simpler than Binaryen's

Binaryen's released pass does fixed-point propagation over function summaries using:

- `CFGWalker`
- `DomTree`
- immediate-dominator entry facts
- internal summary reruns until cardinality convergence

Starshine also iterates summaries to a fixed point, but the actual reasoning is simpler:

- recursive expression traversal,
- `if` joins by explicit set intersection,
- no loop propagation,
- and `try_table` effectively treated as a conservative stop for summary flow.

So the right teaching is not “Starshine copied Binaryen's dominator engine,” but rather:

- “Starshine copied the high-level once-summary idea using a smaller local control-flow model.”

### 4. The current local rewrite surface is slightly sideways from upstream because it knows `ReturnCall`

`or_scan_instrs(...)`, `or_analyze_instrs(...)`, and `or_rewrite_instrs(...)` explicitly mention `ReturnCall`.
That is broader than the official Binaryen `OnceReduction.cpp` surface documented elsewhere in the dossier.

I did not prove in this follow-up whether that is:

- a harmless local extension,
- dead code for current artifacts,
- or a future parity hazard.

So the new page keeps it explicit as a local divergence rather than smoothing it away.

### 5. The current local tests are a clear floor, not full upstream parity evidence

The local focused tests prove:

- repeated direct once calls can become `nop`
- exported globals block the optimization
- trivial once bodies can collapse to `nop`
- multiple independent once-globals can be tracked simultaneously

That is useful coverage, but it is much smaller than the official `once-reduction.wast` surface, which also covers:

- idempotent annotations
- after-merge conservatism
- richer loop and cycle families
- imported / exported / non-integer boundaries
- and EH robustness.

So the green saved-artifact slot should still be taught as “good on the exercised slice,” not “full source parity.”

## Durable conclusions filed back into the living wiki

- `once-reduction` now has the full implemented-pass dossier shape used by the surrounding pass wiki, including a dedicated Starshine strategy/code-map page.
- The correct local teaching headline is: **Starshine implements a narrower recursive once-bit module pass, not the full CFG/dominator `OnceReduction.cpp` engine.**
- The current biggest source-backed upstream gap remains the official `@binaryen.idempotent` path.
- The current local matcher and control-flow proof are both meaningfully narrower than Binaryen's released `version_129` behavior, and the living docs now say that explicitly.
- The touched area is healthier because the folder landing page, parity page, pass-folder map, tracker row, top-level wiki index, and changelog now all agree that `once-reduction` has both upstream and Starshine strategy coverage.

## Files updated in this change

- `CHANGELOG.md`
- `docs/wiki/raw/research/0238-2026-04-21-once-reduction-starshine-strategy-followup.md`
- `docs/wiki/binaryen/passes/once-reduction/index.md`
- `docs/wiki/binaryen/passes/once-reduction/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Binaryen release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` `OnceReduction.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `intrinsics.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- Binaryen `version_129` `once-reduction.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- Binaryen current `main` `OnceReduction.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp>
- Binaryen current `main` `once-reduction.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast>
