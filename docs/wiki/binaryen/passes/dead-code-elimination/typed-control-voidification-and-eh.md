---
kind: concept
status: supported
last_reviewed: 2026-06-17
sources:
  - ../../../raw/binaryen/2026-06-16-dead-code-elimination-v130-recheck.md
  - ../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-stack-switching.wast
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
The 2026-05-05 current-main recheck kept the narrower source-backed contract unchanged.
The source-confirmed `version_130` pass does something narrower:

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

Starshine now has a first real legacy-`try` representation slice: `@lib.Instruction::Try` carries a body, catch bodies, and an optional delegate label; WAST lowering preserves legacy `try` without `pop` as that node, validation/typechecking can check the body/catch regions, and HOT lift/lower can carry the represented catch arms without collapsing tag-specific catches into a synthetic catch-all shape. Focused DCE coverage now runs the reachable-catch and all-unreachable legacy-`try` cases through a real local `Try` node instead of the old synthetic sequential check block.

The next blocker-enabling surface is a placeholder for catch payload consumption: WAST AST `Pop(ValueType)` and public `@lib.Instruction::Pop(ValType)` can now carry `(pop i32)` through parser/AST-to-lib lowering and validation as a value producer, while final binary encoding fails closed with `CannotEncodeLegacyPop`. Validation now also starts modeling catch-payload availability: a `Pop` must occur inside a legacy `catch` with a matching tag payload type, and `pop` outside a catch or with the wrong type rejects. HOT now has a `HotOp::Pop` exact-payload node, seeds tag payload types while lifting legacy catch arms, lowers catch-arm root spans independently so `pop` consumers stay in the same reconstructed arm, and exposes `hot_func_has_legacy_pop` as the local `hasPop` prerequisite for DCE repair.

The first DCE-side repair slice implements the narrow Starshine equivalent for represented HOT shapes after a DCE mutation in a function that had legacy `pop`: if a legacy catch arm contains a root whose subtree has `pop` nested under a block, DCE extracts that payload into a fresh local before the catch root and replaces the nested use with `local.get`, then updates the legacy catch-arm root counts. This directly targets the Binaryen nested-pop hazard, but it is still a first local subset rather than complete Binaryen legacy EH parity.

The follow-up repair slice covers a closer represented analogue of Binaryen's `$call-pop-catch` hazard: when DCE replaces a non-control root whose child is already `unreachable`, it preserves evaluated children before the first unreachable as roots/drops inside a new block and drops the dead operator plus later children. If one of those preserved children is a legacy catch `pop`, the same end-of-pass repair extracts it to a fresh local before the catch root and rewrites the nested use to `local.get`. The repair now also tolerates catch-arm root counts becoming stale after DCE removes roots from the combined HOT catch region, rebuilding legacy arm root counts from the surviving roots instead of indexing past the shortened catch body.

The next blocker slice extends that represented repair toward Binaryen's `$pop-within-block` shape: a dead `drop` wrapper around a non-control child with a nonfallthrough child, such as `drop(ref.eq(struct.new(pop), typed-unreachable-block))`, is now rewritten using the child-preserving block path before the same legacy-pop repair hoists the nested payload. This keeps the work scoped to blocker-enabling nested-pop repair, not broad ordinary expression parity.

Binary encode/decode now supports the no-`pop` legacy `try`/`catch`/`catch_all` subset, and `wast_text_binary_roundtrip(...)` covers a real legacy `try` without catch-payload consumption. The same blocker-enabling binary surface now preserves legacy `rethrow` opcode `0x09` as `@lib.Instruction::Rethrow(LabelIdx)`, and validation only accepts it under an active legacy catch depth. The latest catch-payload slices strip only a complete direct, tag-type-matching `Pop` pseudo-instruction prefix from legacy catch bodies while module-encoding, then reinject direct `Pop` pseudo-instructions during module decode from the decoded tag payload signature. Multi-payload tags are handled in the same LIFO order as validation, but incomplete prefixes remain fail-closed instead of silently encoding a partial payload reconstruction. A deliberately narrow high-level WAST gate now allows complete direct payload-prefix consumer shapes, including single-payload `(drop (pop i32))`, direct `pop -> local.set` or `pop -> local.tee`, and multi-payload prefixes immediately consumed by `drop`/`local.set`/`local.tee`, through text/binary roundtrip; uncontextualized instruction encoding and unsupported WAST pop flows still reject with explicit diagnostics. Focused boundary tests now lock that nested/interleaved catch-payload flow is not accidentally admitted: interrupted multi-payload prefixes and nested `pop` payloads reject in WAST roundtrip, and module binary encode rejects interleaved or nested `Pop` catch bodies with `CannotEncodeLegacyPop`.

Remaining blockers: high-level WAST-to-binary legacy `pop` support is still only the direct complete-prefix consumer subset and keeps Binaryen `$call-pop-catch`-style flows fail-closed, binary catch-payload decode/encode only covers complete direct contextual pseudo-pop prefixes rather than broad nested/interleaved payload flow, and broader Binaryen `pop` movement/repair shapes still need coverage beyond the currently represented HOT block-subtree, direct non-control-unreachable-child, and drop-wrapped nonfallthrough-child extraction cases. Stack-switching representation/tooling remains missing for `cont`, `resume`, `resume_throw`, and `on` handler-label liveness.

### `try_table`

If the `try_table` body is unreachable, then the whole `try_table` cannot finish normally, so DCE changes its type to `unreachable`.

The modern EH test file exists largely to lock in these exact reachability distinctions.

## Why the old "voidification" story was misleading

The earlier pages implied a pass that broadly kept control wrappers but erased their result type.
That is not what `version_130` `DeadCodeElimination.cpp` actually implements.

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

Starshine currently cannot express this fixture locally because the WAST/lib surface lacks `cont`, `resume`, `resume_throw`, and `on` handler-label instructions; this remains a tooling blocker with the same semantic reopening criterion. The 2026-06-16 boundary slices now make the WAST-to-binary entrypoints fail closed with explicit stack-switching diagnostics for those tokens, rather than relying on generic parser/type errors.

So a future port must preserve this lesson:

- result-dead-looking surface syntax does not override handler-target liveness.

## Porting rules to preserve

- Do not implement generic control voidification under the name `dce`.
- Keep the block `hasBreaks(...)` guard before collapsing block type to `unreachable`.
- Keep `if`, `loop`, `try`, and `try_table` as separate special cases.
- Preserve the exact EH repair trigger: `hasPop && addedBlock` once real `pop` is represented; do not claim this using synthetic lowering.
- Treat stack-switching handler labels as part of the real liveness boundary.
