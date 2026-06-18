---
kind: concept
status: supported
last_reviewed: 2026-06-17
sources:
  - ../../../raw/binaryen/2026-06-16-dead-code-elimination-v130-recheck.md
  - ../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-stack-switching.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `dead-code-elimination`: implementation structure and test map

This page closes a real teaching gap in the older dossier.
The earlier pages described a much broader pass with helper walkers, effect-driven dead-result pruning, flattening, and refinalization.
A direct re-read of Binaryen `version_130` shows the real pass is much smaller and more specific.
The 2026-05-05 current-main recheck and the 2026-06-16 `version_130` recheck keep that source map fresh without changing the contract story.

## Why this follow-up was needed

The existing folder already had a deep landing page, but it still lacked one compact source-confirmed answer to two practical questions:

1. what code actually owns Binaryen `dce`?
2. which shipped tests prove each part of the contract?

That mattered because the older living pages overstated the pass.
The source file does **not** implement a general dead-result optimizer over effect analysis.
It implements a single function-parallel postwalk that rewrites unreachable shapes and adjusts types with `TypeUpdater`.

## Exact upstream files that matter

### Core implementation

- `src/passes/DeadCodeElimination.cpp`
  - the whole public pass implementation in `version_130`
  - there is no sibling helper file for the core algorithm

### Registration and scheduler placement

- `src/passes/pass.cpp`
  - registers public pass name `dce`
  - short description: `removes unreachable code`
  - places `dce` immediately after `ssa-nomerge` in the no-DWARF default function pipeline

### Dedicated test surfaces

- `test/lit/passes/dce_all-features.wast`
  - large all-features shape roster for ordinary expression and control-flow rewrites
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
  - proves the intended neighborhood with `vacuum` and `remove-unused-names`
- `test/lit/passes/dce-eh.wast`
  - modern EH and `try_table` surface
- `test/lit/passes/dce-eh-legacy.wast`
  - legacy EH plus `pop`-movement safety surface
- `test/lit/passes/dce-stack-switching.wast`
  - stack-switching `resume` / `resume_throw` label-liveness surface

## Real implementation structure

Binaryen `version_130` `dce` is one small `WalkerPass<PostWalker<...>>` with four noteworthy pieces of state or behavior.

### 1. Function-parallel postwalk shell

The pass is declared as a function-parallel postwalk over expressions.
That means the algorithm is child-first and local to one function body at a time.
There is no module-wide fixed point and no separate analysis pass.

### 2. `TypeUpdater` owns the bookkeeping

The only persistent helper object in the pass is:

- `TypeUpdater typeUpdater;`

The pass uses it to:

- seed type/update state before walking the function body
- note replacements when `replaceCurrent(...)` swaps an expression
- note recursive removals when dead suffixes are trimmed away
- ask whether a `block` still has incoming `break`s
- change node types to `unreachable` when the concrete result type is no longer justified

This is the main source-backed correction to the earlier dossier.
The pass is centered on `TypeUpdater`, not on `EffectAnalyzer`.

### 3. Two EH-fixup booleans, not a broad repair pipeline

The pass tracks:

- `hasPop`
- `addedBlock`

Those are only used for one conservative end-of-function repair:

- if the function contains a `pop` and DCE created a new block, run `EHUtils::handleBlockNestedPops(...)`

That is much narrower than the old folder implied.
There is no general end-of-pass `Flatten::flatten(...)`, `ReFinalize`, or `handleNonDefaultableLocals(...)` call in `version_130` `DeadCodeElimination.cpp`.

### 4. One main visitor: `visitExpression(...)`

Almost the entire pass lives in one visitor.
It splits on whether the current node is a control-flow structure.

## Real algorithm by node family

### Non-control expressions

If a non-control expression has type `unreachable`, DCE checks whether **one of its children is already unreachable**.
If so, later children are dead and removed.
Earlier children are preserved by wrapping them in `drop`s, then the first unreachable child is kept, and if needed Binaryen materializes a new `block` containing:

- dropped earlier children
- the first unreachable child

This is the core “preserve what still executes, kill what cannot execute after the first unreachable child” rule. 2026-06-16 Starshine slices now cover the `dce_all-features.wast`-style `note-loss-of-non-control-flow-children` shape where a result block becomes unreachable before a later branch operand of a dropped binary expression, the `replace-unary-with-br-child` shape where a unary wrapper is dead around a branch-valued child, and `select` shapes where the condition or second value operand is the first unreachable child. The raw DCE pretrim voidifies branchless nonfallthrough result blocks for the binary/drop case, replaces unary-wrapper/drop tails with a direct drop of the preserved child, rewrites simple RPN `value value unreachable select drop` tails to dropped values plus the preserved `unreachable`, and rewrites `value unreachable value select drop` tails to a dropped first value plus the preserved `unreachable`.

### `block`

For `block`, DCE does two things.

1. It trims the suffix after the first child with type `unreachable`.
2. If the block still has a concrete result type but its last surviving child is `unreachable` and `TypeUpdater` sees no `break`s targeting the block, DCE changes the block type to `unreachable`.

If the trimmed block collapses to one child and that child is literal `unreachable`, DCE replaces the whole block with that child directly.

### `if`

For `if`, DCE handles two special cases.

1. If the condition is unreachable, the arms are recursively removed and the whole `if` becomes the condition.
2. If the `if` itself is not already unreachable, has an `else`, and both arms are unreachable, DCE changes the `if` type to `unreachable`.

That is narrower than “generic dead arm simplification.”
It is really type repair around already-unreachable parts. Starshine's 2026-06-16 `global.set` wrapper slice now covers the `dce_all-features.wast` family where a result `if` with both arms literally `unreachable` feeds a non-control side-effect wrapper: raw DCE voidifies the unreachable `if`, drops the dead `global.set`, and keeps the existing HOT lift path for return-valued typed `if` cases.

### `loop`

`loop` gets only one very small rule:

- if the body is literally `unreachable`, replace the loop with the body

The source comment explicitly notes that loops can have unreachable body type for normal reasons like branching back to the top, so DCE only looks for the fully-dead-body case.

### `try`

For legacy `try`, DCE checks whether:

- the try body is unreachable, and
- all catch bodies are unreachable

If both are true and the try node is not already marked unreachable, DCE changes the try type to `unreachable`.

Starshine does **not** yet claim full Binaryen legacy EH parity, but the local surface has moved past the old synthetic-only blocker. `@lib.Instruction` now has a real legacy `Try` node with body, catch bodies, and optional delegate label; WAST lowering preserves legacy `try` without `pop`; validation/typechecking covers the body/catch regions; HOT lift/lower can carry the narrow real-`Try` surface; and focused DCE tests now exercise the reachable-catch and all-unreachable cases through that node.

The latest blocker-enabling steps add a distinct legacy `pop` placeholder: WAST AST `Pop(ValueType)` and public `@lib.Instruction::Pop(ValType)` preserve `(pop i32)` through parser/AST-to-lib lowering and typechecking as a produced value. Typechecking now tracks a narrow per-catch payload context so `Pop` rejects outside legacy catches and rejects payload type mismatches. Binary module encode/decode supports a contextual payload bridge: complete direct, tag-type-matching catch-body `Pop` pseudo-instruction prefixes are stripped before writing binary and reinjected from tag payload signatures after module decode. The module encoder now also repairs broader represented binary catch-payload flows by storing the full catch payload into fresh carrier locals at catch entry and replacing exact once-only LIFO `Pop` uses with `local.get`, covering nested and interleaved module-binary `Pop` bodies while keeping uncontextualized instruction encoding, incomplete multi-payload prefixes, wrong-order/wrong-type payloads, and unsupported high-level text flows fail-closed with `CannotEncodeLegacyPop`. The high-level `wast_to_binary_module` and `wast_text_binary_roundtrip` entrypoints still allow only complete direct payload-prefix consumer text shapes, including single-payload `(drop (pop i32))`, direct `pop -> local.set` or `pop -> local.tee`, and multi-payload prefixes immediately consumed by `drop`/`local.set`/`local.tee`, plus selected DCE-only ingress patterns described below; broader Binaryen legacy `pop` text still rejects with an explicit diagnostic instead of admitting an incomplete full catch-payload implementation. The boundary remains guarded by focused negative tests for interrupted multi-payload prefixes and nested catch-payload `pop` in WAST text, plus positive module-binary tests for nested/interleaved represented payload flow.

Remaining blockers are narrower but still release-relevant for full parity: high-level legacy-pop WAST ingestion is only the narrow direct complete-prefix consumer subset plus DCE-ingress cases where a complete prefix flows into an admitted nonfallthrough branch argument, into the Binaryen `pop-within-block` shape `drop(ref.eq(struct.new(pop), unreachable))` with exact struct-field/payload type matching, or into the conservative `struct.new(pop); br/return` void-nonfallthrough slice where DCE must preserve the allocation side effect before discarding the dead caller. That ingress now lets the local DCE pipeline remove the dead call/ref-eq wrapper after the raw candidate/trimming helpers learned to inspect legacy `try` bodies and catches. The WAST-lowered path now repairs a surviving contiguous root `pop` prefix before a branch with either a void target or matching value target results, before `return` when the function is void or the complete payload prefix exactly matches the function result types, before the exact `struct.new; unreachable` remnant of `pop-within-block` by preserving the allocation through `drop`, before `struct.new; br/return` when the target/function result is void by preserving and dropping the allocation before the nonfallthrough instruction, and before a conservative computed `br_table` selector slice whose stack effect is independently i32-only and whose targets are all void or have the same matching value target results. The selector slice now covers multi-instruction pure i32/local expressions such as `i32.const; i32.const; i32.add` and `local.get; i32.const; i32.rem_u`; it still deliberately rejects calls, memory/global/table effects, nested control, and other unmodeled selector flows. Void targets still route carriers through `drop` (`pop; local.set; local.get; drop; br/br_table/return`) and the struct-new void-nonfallthrough slice uses the same carrier-local move before replaying `struct.new; drop; br/return`, while value branch, value `br_table`, and nonvoid return targets preserve the payload (`pop; local.set; local.get; br/br_table/return`), narrowing the Binaryen local.set/local.get repair-shape gap without claiming exact nested block output parity. The raw repair now resolves type-index block labels and function result types from module context, and focused coverage locks both multivalue and explicit `(type $pair)` branch/`br_table` payload preservation, single-value and multivalue nonvoid-return payload preservation, arbitrary i32 selector preservation, the struct-new call-argument-before-branch movement case, and a mismatched arbitrary-selector `br_table` fail-closed guard. Focused coverage also locks that those fresh carriers are allocated after the function parameter plus existing body-local index budget, so repair locals do not clobber pre-existing locals. Binary catch-payload flow now covers complete direct contextual pseudo-pop prefixes plus represented nested/interleaved module-binary pseudo-pop bodies by routing payloads through fresh carrier locals during encode, but high-level WAST text remains intentionally narrower and DCE still lacks broader Binaryen pop movement/repair coverage beyond the represented repair fixtures plus these contiguous root-pop-prefix-before-nonfallthrough and struct-new-before-void-nonfallthrough text-path repairs. HOT lift/lower now preserves individual legacy catch tags and catch-all arm boundaries for the represented no-`pop` surface, so exact catch-arm shape is no longer the blocker it was after the first real-`Try` slice. Reopen for full parity when the remaining `pop`/payload and stack-switching surfaces exist, then extend repair deliberately rather than treating the representation slices as complete parity.

### `try_table`

For `try_table`, DCE uses the simpler rule that the construct can finish normally only if its body finishes normally.
So if the body is unreachable and the `try_table` type is still concrete, DCE changes the node type to `unreachable`.
Starshine locks this with focused 2026-06-16 fixtures in `src/passes/dead_code_elimination_test.mbt`: a void `try_table` with an unreachable body must make the following root suffix dead, and a result `try_table` with an unreachable body must collapse through its following `drop` so later roots are trimmed. The local HOT fallthrough rule intentionally ignores `try_table` catch-list regions as normal fallthrough paths; catch clauses branch to labels rather than completing the `try_table` normally.

## What the source does **not** do here

These older dossier claims are not source-confirmed for Binaryen `version_130` `DeadCodeElimination.cpp`:

- no `BranchSeeker` or `UnneededBlockSeeker`
- no `EffectAnalyzer`-based `canRemove(...)`
- no special `visitDrop(...)` dead-result engine
- no general typed-control voidification pass over `drop` wrappers
- no `Flatten::flatten(...)`
- no `ReFinalize`
- no `TypeUpdater::handleNonDefaultableLocals(...)`

Some of those ideas belong more to nearby passes like `vacuum`, or to older/imagined DCE designs, but they are not the actual `version_130` implementation in this file.

## Test map: what each lit file is really proving

### `dce_all-features.wast`

This is the broad ordinary-contract file.
It proves that DCE handles shapes like:

- blocks with dead suffixes after `br`, `return`, `br_table`, and `unreachable`; Starshine's 2026-06-16 focused fixtures also lock raw nested explicit-suffix trimming and literal-unreachable block/loop collapse when conservative load/call/set, loop-outer-branch, or no-candidate raw skips would otherwise skip the HOT pass
- ifs whose condition is unreachable
- ifs whose arms are both unreachable, including a result `if` feeding `global.set` where DCE must trim the dead non-control wrapper while preserving the unreachable control expression
- loops whose body becomes fully unreachable
- non-control expressions with an unreachable child where earlier children must be converted to `drop`; Starshine has focused coverage for the branch-operand-after-unreachable-child binary/drop shape, unary-wrapper branch-child shape, and select unreachable-condition / unreachable-second-value shapes, but broader non-control expression coverage should continue to be widened under the active audit

It is the best single file for the pass's ordinary AST rewrite surface.

### `dce_vacuum_remove-unused-names.wast`

This file proves a different point:

- Binaryen expects `dce` to leave useful cleanup opportunities for `vacuum` and `remove-unused-names`

So the file is not evidence that DCE alone does all final simplification.
It is evidence that the intended neighborhood matters.

### `dce-eh.wast`

This file covers modern EH and `try_table` behavior, including:

- reachable catch making later code still reachable
- both body and catch unreachable allowing later code to die
- `try_table` body-unreachable cases where catch labels are exits, not normal fallthrough
- `throw` and `throw_ref` dead-wrapper cleanup that preserves the actually executing path

### `dce-eh-legacy.wast`

This file covers legacy EH `try` plus the subtle `pop` story.
Most importantly, it demonstrates why `hasPop` plus `addedBlock` triggers `EHUtils::handleBlockNestedPops(...)` at function end.
The file includes shapes where DCE-created blocks would otherwise leave nested `pop`s in invalid positions.
Starshine currently treats the full file as a tooling/representation blocker, not a closed DCE behavior surface, because the local lib IR has no real legacy `Try` or `pop` instruction. The current focused tests only cover the safe synthetic-lowering reachability subset described above, plus an explicit fail-closed `pop` diagnostic fixture sourced from Binaryen v130's `call-pop-catch` shape. Binaryen v130 proof lives in `.tmp/dce-legacy-pop-boundary/call-pop-catch.dce.wat`; local Starshine proof is the DCE boundary test in `src/passes/dead_code_elimination_test.mbt`.

### `dce-stack-switching.wast`

This file proves DCE must respect stack-switching label liveness.
In particular, a surrounding `drop` does **not** mean the block result is dead if stack-switching handlers can still branch to that block and use its result type.
Starshine currently documents this as an unsupported tooling boundary: the WAST/lib/binary surface still does not lower `cont`, `resume`, `resume_throw`, or their `on` handler labels. The local DCE test asserts rejection rather than inventing fake coverage. A 2026-06-16 follow-up made both WAST-to-binary entrypoints reject these stack-switching tokens with an explicit `stack-switching` diagnostic, including the missing API names, so the boundary is fail-closed and easy to reopen when the representation lands. A 2026-06-18 probe keeps the same fail-closed policy but adds token-specific diagnostics for isolated `cont`, `resume`, `resume_throw`, and `on` fixtures, which is a minimal tooling improvement rather than representation support. Follow-up WAST parser probes now roundtrip `(type $c (cont $f))` as a type-body placeholder, `(resume $cont (on $tag $label) ...)`, and `(resume_throw $cont $tag (on $tag $label) ...)` as instruction placeholders at the AST/text layer. The focused DCE boundary fixture now mirrors Binaryen's exact stack-switching lit shape more closely by including `(tag $tag (type $function))`, `$resume`, and `$resume_throw`, then still confirms lowering rejects before lib/binary conversion. `on` handler-label liveness remains unimplemented.

## Scheduler map

`pass.cpp` keeps the top-level no-DWARF placement:

- `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`

The combined test file and scheduler placement together support a simple rule:

- DCE should make later cleanup easier, not try to subsume `vacuum` or `remove-unused-names`.

## Current `main` drift check

A 2026-06-16 `version_130` recheck found `src/passes/DeadCodeElimination.cpp` and representative ordinary/EH `dce` lit files byte-identical to the previously reviewed `version_129` snapshots. `src/passes/pass.cpp` changed between the tags, but the inspected diff does not change the `dce` registration or pass contract.
The earlier narrow current-main source diff on `src/passes/DeadCodeElimination.cpp`, `pass.cpp`, and representative ordinary/EH tests did not surface a teaching-relevant drift in the pass contract.
So the `version_130` file remains the current oracle for this dossier.

## What a future Starshine port must preserve

- Use a child-first function-local postwalk mental model.
- Preserve earlier children as `drop`s when a later child makes a non-control expression unreachable.
- Trim block suffixes after the first unreachable child.
- Use block-break knowledge before collapsing a concrete block type to `unreachable`.
- Keep the tiny special cases for `if`, `loop`, `try`, and `try_table` separate instead of pretending there is one generic dead-result rule.
- Preserve the EH nested-pop repair trigger exactly: `hasPop && addedBlock`.
- Do not over-implement the pass as a generic effect-driven dead-result optimizer unless the source oracle changes.
