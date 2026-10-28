---
kind: concept
status: supported
last_reviewed: 2026-10-28
sources:
  - ./index.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-stack-switching.wast
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_label_targets_wbtest.mbt
  - ../../../../../src/cmd/dce_label_targets_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination`: control-type changes and EH repair

This page replaces an older wrong summary.
The earlier dossier talked about broad typed-control **voidification**.
The 2026-05-05 current-main recheck kept the narrower source-backed contract unchanged, and the 2026-06-28 `version_130` source refresh found the same shape.
The source-confirmed Binaryen pass does something narrower:

- it sometimes changes a control-flow node's type to `unreachable`, and
- it sometimes replaces an entire node with an already-unreachable child,
- then it may run one narrow EH nested-pop fixup.

That is not the same thing as a general result-to-void rewrite engine.

## The safe mental model

For Binaryen `dce`, the right question is usually **not**:

- “can I erase this typed wrapper because its value is dead?”

The right question is:

- “has this control structure become unable to finish normally?”

If the answer is yes, DCE often changes the node's type to `unreachable`.

## `block`: concrete type can collapse to `unreachable`

After trimming dead suffixes, DCE checks a block with three conditions:

- the block still has a concrete type,
- its last surviving child is unreachable,
- and `TypeUpdater` sees no `break`s targeting the block.

Only then does DCE change the block type to `unreachable`.

So the real source-backed rule is:

- the pass does **not** generally voidify blocks,
- it narrows concrete block type to `unreachable` when the block no longer has a normal way to produce its value.

The incoming-break check is the key safety gate.

## `if`: two narrow cases

### Unreachable condition

If the condition itself is unreachable, DCE removes the arms and replaces the `if` with the condition expression.

### Both arms unreachable

If the `if` has an `else`, is not already unreachable, and both arms are unreachable, DCE changes the `if` type to `unreachable`.

Again, this is not a generic dead-result-to-void rewrite.
It is a reachability/type fact.

## `loop`: only replace when the body is literally unreachable

The source comment is explicit here: loops can have unreachable body type for ordinary reasons like branching back to the loop top.
So DCE only handles the strongest case:

- the body expression itself is `unreachable`

Then the loop is replaced by the body.

## `try` and `try_table`: EH reachability, not generic EH simplification

### `try`

If the try body is unreachable and every catch body is unreachable, DCE changes the try node type to `unreachable`.

### `try_table`

If the `try_table` body is unreachable, then the whole `try_table` cannot finish normally, so DCE changes its type to `unreachable`.

The modern EH test file exists largely to lock in these exact reachability distinctions.

## Why the old "voidification" story was misleading

The earlier pages implied a pass that broadly kept control wrappers but erased their result type.
That is not what `version_129` `DeadCodeElimination.cpp` actually implements.

What the source actually does is much smaller:

- replace some nodes with an unreachable child,
- trim dead suffixes,
- or mark a node itself as unreachable.

That is a control/reachability normalization story, not a generic "dead result wrapper" story.

## EH repair is one exact end-of-function hook

The pass tracks two booleans while walking a function:

- `hasPop`
- `addedBlock`

At function end it runs:

- `EHUtils::handleBlockNestedPops(curr, *getModule())`

only if both booleans are true.

So the real EH rule is:

- DCE does not run a broad EH repair pipeline,
- it only repairs the nested-`pop` hazard introduced when DCE-created blocks interact with `pop`.

## Why `dce-eh-legacy.wast` matters

The legacy EH file includes cases where DCE creates new blocks around surviving effects while a `pop` remains part of the reachable path.
That file is the strongest direct evidence for the `hasPop && addedBlock` rule.

Without that repair, DCE could leave `pop` in an invalid nested position after simplifying a larger expression.

## Why `dce-stack-switching.wast` matters

The stack-switching file guards against a tempting mistake: assuming a surrounding `drop` means a result type is dead.

In the `resume` / `resume_throw` tests, the result type of a handler block must remain because the handler can branch to that block and still depend on its typed label contract.

So a future port must preserve this lesson:

- result-dead-looking surface syntax does not override handler-target liveness.

## Starshine local representation boundaries as of 2026-09-22

Starshine has focused and generated coverage for modern `try_table`, including a `catch_ref` leaf in `dead-code-elimination-all`. Stack-switching instructions are also represented in canonical IR. The remaining legacy EH surfaces are representation/tool boundaries:

- canonical `src/lib` instructions include `TryTable`, `Throw`, `ThrowRef`, `Resume`, `ResumeThrow`, and `ResumeThrowRef`, but no legacy `Try` or old-EH `Pop` instruction;
- WAST legacy `try` / `rethrow` input is lowered before optimizer passes: legacy `try` becomes a synthetic block/check shape ending in `unreachable`, and accepted legacy `rethrow` lowers to `unreachable` rather than a preserved old-EH node;
- `pop` is not represented in the canonical instruction enum, so Binaryen's `hasPop && addedBlock` nested-pop repair has no local pass-time analogue to run;
- DCE reads `hot_continuation_targets(...)` into its incoming-label bitset. This protects handler-only targets; the broader claim that it protected mixed ordinary/handler targets was incomplete (see BURN-009 below);
- focused direct-HOT and active-dispatcher regressions cover a handler-targeted `(ref null cont)` block whose ordinary return path is unreachable. Before the repair, DCE changed the block result to `void`; final writeback validation restored the original after reporting a resume-handler label arity mismatch.

Reopen the remaining legacy boundary if Starshine adds canonical old-EH `try`/`pop`, or if Binaryen changes DCE so the same safety issue has a modern `try_table`/`throw_ref` equivalent.

## Porting rules to preserve

- Do not implement generic control voidification under the name `dce`.
- Keep the block `hasBreaks(...)` guard before collapsing block type to `unreachable`.
- Keep `if`, `loop`, `try`, and `try_table` as separate special cases.
- Preserve the exact EH repair trigger for any future old-EH representation: `hasPop && addedBlock`.
- Treat stack-switching handler labels as part of the real liveness boundary.

## BURN-009: mixed incoming edges (2026-10-28)

At unchanged master `3d1deec7cecf1caaf65b42799777ff52ef210245`, the
original `workers/control/burn_control_dce_v4_wbtest.mbt` from the evidence
packet at `04abb7dc6eb5e8ee5ee0f98453e112d74765f1e6` reproduces one direct
HOT failure and one passing public-pipeline control. A dropped i32 block has
an ordinary conditional branch carrying 5 and a `try_table` catch carrying
tag payload 7. Input validation, HOT verification and initial lowering pass.
Direct DCE changes the block to void and removes the ordinary payload;
lowered validation then reports `catch types (payload) do not match label types`.
This establishes an invalid direct API output, not a public defect or runtime
change. The original test now lives in the implementing file. Local replay
compiled it with `moon test src/passes/burn_control_dce_v4_wbtest.mbt --target js
-j 1`; Node was absent, so Bun executed the generated whitebox JS with
`file_and_index=[["burn_control_dce_v4_wbtest.mbt",[{"start":0,"end":2}]]]`:
one pass, one assertion failure with the exact diagnostic above. The generated
runner itself exits zero even when its result records contain a failure.
Subsequent Moon commands use a temporary `node` symlink to Bun. A separate
baseline mixed-continuation regression fails after lowering; the ordinary-only
optimization control passes. The dispatcher baseline returns valid output but
uses invalid-lower fallback; the new dispatcher test requires valid completion
without that fallback, rather than claiming an existing public invalid result.

The owning dropped-result rewrite now rejects labels with catch or continuation
incoming edges. Its ordinary branch-user scan also builds a separate signature
constraint bitset for all four catch forms and `hot_continuation_targets`
(shared by Resume, ResumeThrow and ResumeThrowRef). These implicit payloads
never enter the editable ordinary branch list. The bitset shares the existing
live/attached filtering and cache invalidation. Ordinary-only result removal
remains enabled. This supersedes only the earlier mixed-target safety claim;
it does not close broader pass parity or legacy EH boundaries.

Sources and bounded tests:

- [Owner and direct regression/control](../../../../../src/passes/dead_code_elimination.mbt).
- [Mixed continuation and existing catch/handler controls](../../../../../src/passes/dead_code_elimination_label_targets_wbtest.mbt).
- [Active command dispatcher control](../../../../../src/cmd/cmd.mbt), which
  asserts completed execution without invalid-lower fallback.

No continuation runtime, Binaryen comparison, large fuzz campaign or benchmark
was run for this repair. The required correctness cost is one label-sized
bitset per ordinary-user cache build, a node-kind check within that existing
scan, catch/handler target marking, and an O(1) admission check; no additional
whole-function scan is introduced. Mixed exceptional targets retain their
required result/drop and ordinary payload rather than emitting invalid code.
Performance remains unmeasured. Measurement should compare ordinary-only,
catch-only, mixed catch and mixed continuation workloads, including many labels
and repeated cache invalidations, through the owner scan/rewrite and public DCE
route. Ordinary-only output is covered by a direct arity assertion.

Validation for this bounded repair (serial; `PATH=/data/home/.moon/bin:$PATH`,
plus the temporary Bun launcher for JS tests):

```sh
moon info
moon fmt
moon test src/passes/dead_code_elimination{,_test,_wbtest,_cache_wbtest,_label_targets_wbtest,_live_repro_test,_round2_test}.mbt --target js -j 1
moon test src/cmd/cmd.mbt src/cmd/dce_label_targets_wbtest.mbt src/cmd/dce_oi_loop_regression_wbtest.mbt --filter '*DCE*' --target js -j 1
moon test src/cmd/dce_oi_loop_regression_wbtest.mbt --target js -j 1
moon build -j 1
```

Results: 94/94 pass tests, 3/3 dispatcher DCE tests, 1/1 dispatcher loop
regression, and full build exit 0. Info and formatting also exit 0. Reviewed
and discarded unrelated formatter churn and generated `.mbti` Int/UInt to
Int32/UInt32 spelling churn; no public API changes remain. Existing compiler
warnings remain. The full test suite and broad parity gates were outside the
requested scope.
