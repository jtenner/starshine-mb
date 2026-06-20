---
kind: concept
status: supported
last_reviewed: 2026-06-20
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

This is the core “preserve what still executes, kill what cannot execute after the first unreachable child” rule. 2026-06-16 Starshine slices cover the `dce_all-features.wast`-style `note-loss-of-non-control-flow-children` shape where a result block becomes unreachable before a later branch operand of a dropped binary expression and the `replace-unary-with-br-child` shape where a unary wrapper is dead around a branch-valued child. A 2026-06-19 non-legacy slice added a reusable raw `DceRawInstructionEffect` summary for one-result non-control operators so the second-unreachable-child binary case also preserves already-evaluated operands as drops before the nonfallthrough child instead of leaving stale stack values. Follow-ups widened that same summary to zero-result store/table/memory mutation consumers and replaced the select-specific unreachable-condition / unreachable-second-value rewrites with a parameter-slot helper: for any modeled dead consumer, the raw pretrim can locate a first nonfallthrough child in an operand slot, drop the already-evaluated earlier operands, discard later operands and the dead consumer/result drop, voidify branchless nonfallthrough value control, and keep the nonfallthrough child. The summary now also groups module-context invocation effects under `run_hot_pipeline_dce_raw_call_instruction_effect(...)` for direct calls, `call_indirect`, `call_ref`, and their tail-call forms `return_call`, `return_call_indirect`, and `return_call_ref`, uses module-context tag type resolution for `throw` payload arity plus `throw_ref` as a one-input nonfallthrough consumer, and includes stack-neutral `nop`, simple value producers, numeric/atomic load result producers, table/dynamic-size one-result producers (`table.get`, `memory.size`, `table.size`, `memory.grow`, `table.grow`), GC struct field-read producers (`struct.get`, `struct.get_s`, `struct.get_u`), GC array read/length producers (`array.get`, `array.get_s`, `array.get_u`, `array.len`), GC allocation/constructor producers (`struct.new`, `struct.new_default`, `struct.new_desc`, `struct.new_default_desc`, `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, and `array.new_elem`, using module-context struct field counts and fixed-array arity where needed), string array decode/encode producers (`string.new_utf8_array`, `string.new_wtf16_array`, `string.new_lossy_utf8_array`, `string.new_wtf8_array`, `string.encode_utf8_array`, `string.encode_wtf16_array`, `string.encode_lossy_utf8_array`, and `string.encode_wtf8_array` as three-input/one-result stack effects), numeric saturating conversion producers (`i32.trunc_sat_f32_s`, `i32.trunc_sat_f32_u`, `i32.trunc_sat_f64_s`, `i32.trunc_sat_f64_u`, `i64.trunc_sat_f32_s`, `i64.trunc_sat_f32_u`, `i64.trunc_sat_f64_s`, and `i64.trunc_sat_f64_u` as one-input/one-result stack effects), GC mutators (`struct.set`, `array.set`, `array.fill`, `array.copy`, `array.init_data`, and `array.init_elem`) plus segment drops (`data.drop`, `elem.drop`) as zero-result stack effects for unevaluated suffixes after a nonfallthrough operand, reference/i31 producers and casts/tests (`any.convert_extern`, `extern.convert_any`, `ref.i31`, `i31.get_s`, `i31.get_u`, `ref.as_non_null`, `ref.test`, `ref.cast`, `ref.get_desc`, `ref.test_desc`, and `ref.cast_desc_eq` with its two-input descriptor stack effect), a broad SIMD/vector stack-effect helper for v128 constants, loads, splats, lane ops, unary/binary/ternary vector producers, and vector stores, and a broad atomic stack-effect helper for atomic fences, memory atomic loads/stores, notify/wait, RMW, cmpxchg, and GC struct atomic field reads, plus local/global set and tee stack effects, so dead call or tail-call consumers with an unreachable argument can preserve already-evaluated arguments and remove unevaluated later arguments plus the call that cannot execute. The raw helper no longer treats the instruction offset as the operand offset for the suffix after the first nonfallthrough child: it scans modeled stack effects forward, tracks how many stack values were produced at or after the cut, and recognizes the dead consumer even when later operands have multi-instruction, structured control (`block`, `loop`, `if`, or `try_table` with module-context block-type arity, and with `if` additionally consuming its condition), load-result, table/dynamic-size query/grow, GC/ref, GC constructor, or SIMD/vector producers. A 2026-06-20 follow-up also models `return` as a function-result-count consumer in this same summary and adds a reusable prefix stack-height calculation for block-shaped branchless nonfallthrough cuts: when the dead consumer is removed and the result block is voidified, already-existing modeled stack values before that block are preserved as explicit drops so the rewrite remains valid instead of leaving stale stack values. A later 2026-06-20 non-legacy slice generalizes that cleanup into `run_hot_pipeline_dce_raw_drop_stack_before_nonfallthrough_cut(...)`: branchless nonfallthrough cuts now describe how many control operands are already present in the rewritten prefix (`block` has none, `if` has its condition), the helper finds a modeled suffix that produces those operands, inserts drops for unrelated prefix stack values before that suffix, and then keeps the control operand code in place before the voidified cut. Focused coverage locks a multi-instruction `if` condition so the cleanup preserves condition code while dropping only the unrelated earlier call result. A later 2026-06-20 non-legacy slice threads a structured label-result context through recursive raw DCE trimming and models direct `br` as consuming the targeted label payload arity, with block labels using block results and loop labels using loop parameters. A follow-up extends that same label-result semantic structure to `br_table`: all table targets are resolved through the current label stack, target result vectors must agree, and the effect consumes the common payload arity plus the selector. The next non-legacy branch slice factors these under a branch-effect helper and adds a conditional-branch effect for `br_if`: it consumes the target payload arity plus the i32 condition, leaves the payload arity on the fallthrough path, and marks those fallthrough results discardable when an earlier nonfallthrough operand proves neither the branch nor fallthrough path can execute. A follow-up extends the same reusable branch-effect helper to typed reference branch forms: `br_on_null` consumes the target payload plus the nullable reference and leaves the payload plus refined non-null reference on fallthrough; `br_on_non_null` requires a target label whose final value is a reference, consumes the target payload including the tested reference, and leaves the non-reference prefix on fallthrough; `br_on_cast` and `br_on_cast_fail` require the same final-reference label shape and preserve the label arity on fallthrough. All of these mark fallthrough values discardable when an earlier nonfallthrough operand proves no edge can execute. That lets the same dead-consumer scan remove a direct branch, conditional branch, branch table, or typed reference branch that cannot execute after an earlier nonfallthrough payload while preserving the already-evaluated prefix as drops, instead of adding branch-specific rewrites. The effect record now keeps stack counts distinct from explicit safety booleans for suffix scanning and dead-consumer eligibility, which is a step toward Binaryen-like semantic summaries instead of overloading arity alone. A 2026-06-20 effect-category refactor keeps the previously scattered simple/local/global/select, string array, reference/i31/descriptor, GC access, GC constructor, and memory/table/bulk/segment-drop arity groups in named helpers (`run_hot_pipeline_dce_raw_simple_instruction_effect(...)`, `..._string_array_instruction_effect(...)`, `..._ref_instruction_effect(...)`, `..._gc_access_instruction_effect(...)`, `..._gc_constructor_instruction_effect(...)`, and `..._memory_table_instruction_effect(...)`) so the remaining non-legacy audit can reason about broad instruction categories instead of one long generic match. A follow-up primitive-effect structure slice gives the remaining top-level primitive checks the same shape by routing unary producers, binary producers, and plain loads through named helpers (`run_hot_pipeline_dce_raw_unary_instruction_effect(...)`, `..._binary_instruction_effect(...)`, and `..._plain_load_instruction_effect(...)`). The next structure slice factors variable access and mutation effects (`local.get`, `global.get`, `local.set`, `global.set`, and `local.tee`) into `run_hot_pipeline_dce_raw_variable_instruction_effect(...)`, keeping local/global stack behavior separate from constants, returns, drops, and select in the simple helper. Focused coverage includes a three-input zero-result `memory.fill` whose middle value operand is unreachable, direct, indirect, and ref three-argument calls whose middle argument is unreachable, the same direct-call family with a later `i32.add(call, call)` operand, a tag `throw` whose first unreachable payload makes the later payloads and throw dead, a multi-value `return` whose first result is an already-unreachable block and whose later result/return are dead while an unrelated earlier stack value is preserved as a drop before the voidified block, a direct `br`, `br_if`, `br_table`, and typed reference branch (`br_on_null`, `br_on_non_null`, `br_on_cast`, `br_on_cast_fail`) whose target payload is first produced by a nonfallthrough block and whose earlier stack value is preserved as a drop before the voidified payload block, a direct-call family with dead later structured-control value operands (`block`, `loop`, `if`, and `try_table`) whose block-type stack effects are resolved through the reusable instruction summary, a direct-call family with a dead stack-neutral `nop` before a later producer argument, a direct-call family with a dead later `i32.load(i32.const 0)` argument, direct-call families with dead later `local.get`, `global.get`, `table.get`, `memory.size`, `table.size`, `memory.grow`, `table.grow`, `struct.get`, `array.get`, `array.len`, `i31.get_s(ref.i31(...))`, `ref.eq(ref.null eq, ref.null eq)`, SIMD `i8x16.splat` / `i8x16.add`, atomic load/RMW/cmpxchg arguments, and GC constructor arguments (`struct.new`, `struct.new_default`, `struct.new_default_desc`, `array.new_fixed`, and `array.new_data`), string array decode/encode arguments (`string.new_utf8_array` and `string.encode_utf8_array`), a numeric saturating conversion argument (`i32.trunc_sat_f32_s`), a GC mutator suffix (`array.fill`), a dead `table.fill` suffix after an unreachable call argument, and direct/indirect/ref tail-call consumers with an unreachable middle argument; in each case Starshine preserves/drops only the operands that already execute and removes the dead consumer. Legacy `pop`-containing prefixes are detected recursively and remain excluded from this general non-legacy rewrite so broad legacy compatibility stays deferred to the late phase.

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

The latest blocker-enabling steps add a distinct legacy `pop` placeholder: WAST AST `Pop(ValueType)` and public `@lib.Instruction::Pop(ValType)` preserve `(pop i32)` through parser/AST-to-lib lowering and typechecking as a produced value. Typechecking now tracks a narrow per-catch payload context so `Pop` rejects outside legacy catches and rejects payload type mismatches. Binary module encode/decode supports a contextual payload bridge: complete direct, tag-type-matching catch-body `Pop` pseudo-instruction prefixes are stripped before writing binary and reinjected from tag payload signatures after module decode. The module encoder now also repairs broader represented binary catch-payload flows by storing the full catch payload into fresh carrier locals at catch entry and replacing exact once-only LIFO `Pop` uses with `local.get`, covering nested and interleaved module-binary `Pop` bodies while keeping uncontextualized instruction encoding, incomplete multi-payload prefixes, and wrong-order/wrong-type payloads fail-closed with `CannotEncodeLegacyPop`. The high-level `wast_to_binary_module` and `wast_text_binary_roundtrip` entrypoints now allow complete direct payload-prefix consumer text shapes, including single-payload `(drop (pop i32))`, direct `pop -> local.set` or `pop -> local.tee`, multi-payload prefixes immediately consumed by `drop`/`local.set`/`local.tee`, a conservative nop-interleaved root-prefix consumer subset, a nested block/loop subset that can be represented by the binary carrier encoder, and a non-prefix direct-call argument-list subset over a small modeled value stack (constants/local.get/ref constants/nop, `global.get`, direct call result producers (including multivalue producers), indirect call result producers when the table selector and callee type stack effect can be modeled, and `call_ref` consumers/producers when the function-reference operand plus type stack effect can be modeled, loads and simple unary/broad binary producers, block/loop result carriers, direct `br`, `return`, no-parameter direct `return_call`, parameterized direct `return_call` when the complete payload prefix exactly supplies the callee params, operand `return_call_indirect` / `return_call_ref` tails when the prefix either is dropped for no-param tail types or exactly supplies the tail params before the already-present table-index/function-reference operand, and `unreachable` cut points, and exact once-only LIFO payload `pop` uses), plus selected DCE-only ingress patterns described below. Broader Binaryen legacy `pop` text still rejects with an explicit diagnostic instead of admitting an incomplete full catch-payload implementation. The boundary remains guarded by focused negative tests for incomplete interleaved payloads, wrong-order call payload flow, and branch-alternative `if` payload use, plus positive module-binary and high-level WAST tests for nested/interleaved/call/effectful-load/block-result represented payload flow.

Remaining blockers are narrower but still release-relevant for full parity: high-level legacy-pop WAST ingestion is only the narrow direct complete-prefix consumer subset plus DCE-ingress cases where a complete prefix flows into an admitted nonfallthrough branch argument, into the Binaryen `pop-within-block` shape `drop(ref.eq(struct.new(pop), unreachable))` with exact struct-field/payload type matching, or into the conservative `struct.new(pop); br/return` void-nonfallthrough slice where DCE must preserve the allocation side effect before discarding the dead caller. That ingress now lets the local DCE pipeline remove the dead call/ref-eq wrapper after the raw candidate/trimming helpers learned to inspect legacy `try` bodies and catches. The WAST-lowered path now repairs a surviving contiguous root `pop` prefix before a branch with either a void target or matching value target results, before `return` when the function is void or the complete payload prefix exactly matches the function result types, before the exact `struct.new; unreachable` remnant of `pop-within-block` by preserving the allocation through `drop`, before `struct.new; br/return` when the target/function result is void by preserving and dropping the allocation before the nonfallthrough instruction, and before a conservative computed `br_table` selector slice whose stack effect is independently i32-only and whose targets are all void or have the same matching value target results. The selector slice now covers multi-instruction pure i32/local expressions such as `i32.const; i32.const; i32.add` and `local.get; i32.const; i32.rem_u`; it still deliberately rejects calls, memory/global/table effects, nested control, and other unmodeled selector flows. Void targets still route carriers through `drop` (`pop; local.set; local.get; drop; br/br_table/return`) and the struct-new void-nonfallthrough slice uses the same carrier-local move before replaying `struct.new; drop; br/return`, while value branch, value `br_table`, and nonvoid return targets preserve the payload (`pop; local.set; local.get; br/br_table/return`), narrowing the Binaryen local.set/local.get repair-shape gap without claiming exact nested block output parity. The raw repair now resolves type-index block labels and function result types from module context, and focused coverage locks both multivalue and explicit `(type $pair)` branch/`br_table` payload preservation, single-value and multivalue nonvoid-return payload preservation, arbitrary i32 selector preservation, the struct-new call-argument-before-branch movement case, and a mismatched arbitrary-selector `br_table` fail-closed guard. Focused coverage also locks that those fresh carriers are allocated after the function parameter plus existing body-local index budget, so repair locals do not clobber pre-existing locals. Binary catch-payload flow now covers complete direct contextual pseudo-pop prefixes plus represented nested/interleaved/call-argument pseudo-pop bodies by routing payloads through fresh carrier locals during encode, and high-level WAST text has been widened to the conservative carrier-encodable nested block/loop, nop-interleaved prefix, and modeled direct-call argument-list subsets. The latest DCE-only text ingress and repair slices admit dead call argument payload flows where a later branch/return makes the call unreachable even when the payload is not a direct root prefix, preserving earlier evaluated call arguments as drops and routing the payload through a fresh carrier before the nonfallthrough terminator. Focused coverage now includes side-effecting and multivalue direct call results, indirect call consumers and result producers with modeled table-index stack effects, `call_ref` consumers and result producers with modeled function-reference operands, multiple evaluated arguments, compound effectful expressions, global.get, simple unary/binary, effectful-load, and nested-block-result dead-call remnants, plus both void and value branch/return targets for the load/block cases, so the repair drops the carrier only for void targets and preserves it for matching result targets. Narrow follow-ups admit single-payload simple-value, evaluated-load, parameterless single-result direct-call, parameterless single-result block, parameterless single-result loop, simple unary, and modeled broad binary dead-call remnants before parameterized direct/indirect/ref `return_call*` tails, routing the payload through a carrier `local.get` as the tail-call argument while dropping the earlier value/call/control result and replaying the already-present table-index/function-reference operand for indirect/ref tails. The multi-payload non-prefix tail-param slices remain narrow but no longer simple-value-only: they admit a modeled evaluated prefix (stack-neutral `nop`, simple values including `string.const`, string array decode prefixes (`string.new_utf8_array` / `string.new_wtf16_array` / `string.new_lossy_utf8_array` / `string.new_wtf8_array`) whose concrete array reference and start/end operands fit the modeled prefix stack and whose produced string is immediately dropped after replay, string encode-array write prefixes (`string.encode_utf8_array` / `string.encode_wtf16_array` / `string.encode_lossy_utf8_array` / `string.encode_wtf8_array`) whose stringref, mutable array reference, and i32 start operands fit the modeled prefix stack and whose produced i32 count is immediately dropped after replay, `memory.size` and `memory.grow` prefixes whose dynamic memory result is immediately dropped after replay (with `memory.grow` preserving the modeled i32 delta operand and growth side effect), bulk memory mutation prefixes (`memory.fill`, `memory.copy`, and `memory.init`) whose operands fit the modeled prefix stack and whose side effects are replayed before the later dead prefix result is dropped, `table.size` and `table.grow` prefixes whose dynamic table result is immediately dropped after replay (with `table.grow` preserving the modeled reference value plus i32 delta operands and growth side effect), `global.set` prefixes whose single operand fits the modeled prefix stack and whose side effect is replayed before the later dead prefix result is dropped, void table mutation prefixes (`table.set`, `table.fill`, `table.copy`, and `table.init`) whose operands fit the modeled prefix stack and whose side effects are replayed before the later dead prefix result is dropped, zero-input `struct.new_default` allocations whose produced reference is immediately dropped after replay, `struct.new` allocations whose resolved field operands fit the modeled prefix stack and whose produced reference is immediately dropped after replay, `struct.new_desc` allocations whose resolved field operands plus descriptor operand fit the modeled prefix stack and whose produced reference is immediately dropped after replay, `struct.new_default_desc` allocations whose descriptor operand fits the modeled prefix stack and whose produced reference is immediately dropped after replay, `array.new` allocations whose modeled element and i32 length operands fit the prefix stack and whose produced array reference is immediately dropped after replay, `array.new_default` allocations whose modeled i32 length operand fits the prefix stack and whose produced array reference is immediately dropped after replay, `array.new_fixed` allocations whose declared element count fits the modeled prefix stack and whose produced array reference is immediately dropped after replay, `array.new_data` and `array.new_elem` allocations whose modeled i32 source-offset and length operands fit the prefix stack and whose produced array reference is immediately dropped after replay, `local.tee` over a previously-produced value, direct calls whose params fit the modeled prefix stack and whose result arity is nonzero, `call_indirect` / `call_ref` producers whose params plus already-modeled table-index/function-reference operand fit the modeled prefix stack and whose result arity is nonzero, untyped and nonempty typed `select` prefixes whose operands fit the modeled prefix stack, `ref.is_null` and `ref.eq` reference-operator prefixes whose operands fit the modeled prefix stack, `any.convert_extern`/`extern.convert_any`, `ref.i31`, `i31.get_s`/`i31.get_u`, `ref.as_non_null`, `table.get`, `struct.get`/`struct.get_s`/`struct.get_u`, `ref.test`/`ref.cast`, and descriptor `ref.get_desc`/`ref.test_desc`/`ref.cast_desc_eq` one-value-in/one-value-out prefixes whose operands fit the modeled prefix stack, no-param single-result block/loop carriers, plain loads, simple unary operators, numeric conversion/sign-extension/reinterpret operators, and modeled binary operators over supported stack values) before a complete LIFO catch-payload prefix whose pop order exactly matches the tail callee params. Raw repair replays the earlier prefix, drops all produced prefix results, stores each pop in a fresh local, replays the locals as tail params, and emits either the direct `return_call` or the already-present simple table-index/function-reference operand followed by `return_call_indirect` / `return_call_ref`; broader arbitrary/effectful multi-payload prefixes and unmodeled call/indirect/ref stack effects remain open. Tail-call operand slices admit root-prefix and DCE-dead-call remnants before no-parameter `return_call_indirect` and `return_call_ref`, but only after a modeled single table-index or function-reference operand; the no-param case routes/drops the payload through a carrier before replaying the operand and tail call. Parameterized operand-tail calls are now admitted only for root-prefix `pop; operand; return_call_indirect/ref` shapes where the complete catch-payload prefix exactly supplies the tail params and the table-index/function-reference operand remains immediately before the tail call, so the payload remains the tail-call argument and does not need carrier repair. The direct-tail slice likewise admits the exact Binaryen-style parameterized `pop; return_call` root-prefix shape when the complete catch-payload prefix exactly supplies the callee params; broader non-prefix direct/indirect/ref tail-call params remain guarded beyond the single-payload simple-value/evaluated-load/direct-call-result/block-result/loop-result/simple-unary/broad modeled-binary repairs and the narrow multi-payload modeled single-result direct/indirect/ref tail repairs because arbitrary argument and operand stack preservation has not been proven. DCE still lacks broader Binaryen pop movement/repair coverage beyond the represented repair fixtures plus these contiguous root-pop-prefix-before-nonfallthrough, struct-new-before-void-nonfallthrough, tail-call operand, exact direct-tail-param, and narrow dead-call-argument text-path repairs. HOT lift/lower now preserves individual legacy catch tags and catch-all arm boundaries for the represented no-`pop` surface, so exact catch-arm shape is no longer the blocker it was after the first real-`Try` slice. Reopen for full parity when the remaining `pop`/payload and stack-switching surfaces exist, then extend repair deliberately rather than treating the representation slices as complete parity.

### `try_table`

For `try_table`, DCE uses the simpler rule that the construct can finish normally only if its body finishes normally.
So if the body is unreachable and the `try_table` type is still concrete, DCE changes the node type to `unreachable`.
Starshine locks this with focused 2026-06-16 fixtures in `src/passes/dead_code_elimination_test.mbt`: a void `try_table` with an unreachable body must make the following root suffix dead, and a result `try_table` with an unreachable body must collapse through its following `drop` so later roots are trimmed. The local HOT fallthrough rule intentionally ignores `try_table` catch-list regions as normal fallthrough paths; catch clauses branch to labels rather than completing the `try_table` normally. A 2026-06-20 non-legacy follow-up also models `try_table` block-type params/results in the shared raw `DceRawInstructionEffect` structured-control helper, so a dead later `try_table` value operand after an earlier nonfallthrough call argument can be removed by the same semantic suffix scan as `block`, `loop`, and `if`, still under the recursive legacy-`pop` exclusion. A later 2026-06-20 explicit-cut follow-up treats no-exception-edge branchless result `try_table` as value control rather than deleting the whole construct before a following explicit cut: DCE voidifies the `try_table` result type, preserves the nonfallthrough body/catch-label structure, and then lets the following cut remain when needed for the enclosing result context. This matches the Binaryen `case-038405` family instead of accepting the smaller Starshine-only deletion as an undocumented drift.

## Current Starshine non-legacy instruction-effect audit

A 2026-06-20 local audit compared the dirty-worktree DCE raw-effect model against `src/lib/types.mbt`'s `@lib.Instruction` enum and the named helpers in `src/passes/pass_manager.mbt` (`DceRawInstructionEffect`, the primitive/load helpers, simple/variable/invocation/throw/control/branch helpers, and GC/ref/string/SIMD/atomic/memory-table helpers). This is an auditability slice, not a red-first behavior-gap fix.

The current non-legacy stack-effect model has explicit semantic buckets for:

- explicit nonfallthrough and polymorphic cuts: `unreachable`, `return`, `throw`, `throw_ref`, direct/ref/indirect tail calls, direct `br`, `br_if`, `br_table`, and typed reference branches through the structured label-result context;
- structured controls used as operands or cuts: `block`, `loop`, `if`, and non-legacy `try_table`, with block-type arity resolved through module context and branchless-control cleanup preserving existing control operands before voidification;
- pure primitive producers: constants, unary numeric/ref operators, binary numeric/ref operators including `ref.eq`, and plain loads;
- variable, table, memory, and bulk effects: local/global get/set/tee, table get/set/grow/size/fill/copy/init, memory size/grow/fill/copy/init, stores, and segment drops;
- module-context invocation and constructor effects: direct calls, indirect calls, ref calls, their tail-call forms, tag payload arity for throws, GC struct/array constructors, GC field/array reads, GC mutators, string array decode/encode, dynamic-size queries, SIMD/vector operators, and atomics.

The audit did not identify an obvious remaining non-legacy `@lib.Instruction` family that is both represented locally and absent from the reusable effect model. The apparent enum gaps are either:

- intentionally deferred legacy compatibility surfaces: `Try`, `Pop`, and `Rethrow`, plus broader legacy EH payload repair and arbitrary `pop` movement;
- represented stack-switching/tooling gaps outside this local `@lib.Instruction` enum/effect path and still deferred until the final legacy/representation phase;
- operators that are covered through predicate helpers rather than visible in the top-level effect helper match, especially plain loads and primitive binary operators.

This conclusion is an audit checkpoint, not final closeout. Reopen the non-legacy effect audit if a focused red repro shows a represented non-legacy instruction missing from the stack-effect scan, if `@lib.Instruction` grows, or if compare-pass finds a mismatch family that cannot be classified as Binaryen-equivalent or a measured Starshine win.

A follow-up 2026-06-20 red-first slice found a non-legacy validation gap in the general cut-cleanup structure rather than in a missing operator family: a result block body could compute an unrelated prefix value, hit an explicit `unreachable`, and have a later dead suffix trimmed, leaving the prefix value undropped before the cut. Starshine now reuses modeled stack-height cleanup for zero-operand explicit nonfallthrough cuts and skips that cleanup when a legacy `pop` is already in the rewritten prefix. The same slice also made branchless-control voidification respect the current result context more conservatively, so a result-context suffix cut is not removed merely because a preceding branchless control is nonfallthrough.

A second 2026-06-20 red-first result-context slice narrowed that conservatism: when branchless nonfallthrough value control is followed by an explicit cut in a non-void current-result context, raw DCE now voidifies the value control but continues scanning so the following cut stays available for validation. This fixes the final-probe `case-023083` raw mismatch without special-casing SIMD or saturating-conversion operators: the reusable context rule prevents a typed dead result block from lowering as an extra `drop(unreachable)` before the final cut.

A third 2026-06-20 slice narrowed the legacy synthetic-try guard so it no longer treats an ordinary one-arm non-legacy block body followed by `unreachable` as a lowered legacy `try` with reachable alternatives. The guard now requires at least two block/loop arms before the synthetic trailing `unreachable`, preserving the documented legacy boundary while allowing normal branchless nonfallthrough block replacement to run for final-probe `case-046375`. The same slice added a reusable branchless nonfallthrough value-block replacement helper that preserves evaluated body effects in void current-result contexts instead of keeping a dead value wrapper that later lowers to nested `drop(unreachable)` debris.

A fourth 2026-06-20 non-legacy slice addressed side-effect boundaries in explicit-cut tails. `run_hot_pipeline_dce_raw_suffix_min_initial_stack_height(...)` computes how many pre-existing stack values a later live suffix still needs, and `run_hot_pipeline_dce_raw_drop_prefix_values_before_boundary(...)` drops dead prefix value segments before stack-neutral side-effect boundaries such as `data.drop`, `elem.drop`, and `atomic.fence`. This aligns the `case-021671` and `case-035735` families with Binaryen's direct-drop shape instead of forcing lowering to synthesize locals for dead values kept across a side-effect boundary.

The final 2026-06-20 non-legacy classification pass found no remaining unclassified non-legacy DCE mismatches in the current final evidence. Direct final probe `.tmp/pass-fuzz-dead-code-elimination-nonlegacy-final-100000-trytable-cut-preserve` had `0` mismatches. The stronger DCE-profile lane `.tmp/pass-fuzz-dead-code-elimination-nonlegacy-final-genvalid-dce-50000-trytable-cut-preserve` had two raw mismatches, both classified as measured Starshine wins after inspecting the normalized WAT and validating Starshine outputs: `case-021369` removes a pure `v128.const`/`nop` prefix before an unconditional `unreachable` inside a preserved no-exception-edge `try_table` (`98` to `78` bytes), and `case-041989` keeps the side-effecting `global.set` plus both dead multi-result drops before the cut while using a smaller tuple-local/drop shape (`117` to `103` normalized bytes, `103` to `101` raw bytes). These classifications do not broaden legacy EH or stack-switching; those remain the remaining DCE parity phase.

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
- non-control expressions with an unreachable child where earlier children must be converted to `drop`; Starshine has focused coverage for the branch-operand-after-unreachable-child binary/drop shape, unary-wrapper branch-child shape, select unreachable-condition / unreachable-second-value shapes, zero-result store last-operand trimming, three-input memory mutation middle-operand trimming, module-context direct/indirect/ref call, tail-call, return, direct-branch, conditional-branch, branch-table, and typed-reference-branch argument or result trimming, structured label-context branch arity, stack-polymorphic `unreachable` later operands, block-prefix stack-height cleanup before voidified nonfallthrough result blocks, generalized branchless-control cleanup that preserves a multi-instruction `if` condition while dropping unrelated prefix stack values, and a stack-depth scan that reaches consumers after multi-instruction, structured-control (`block`/`loop`/`if`), load, table, dynamic-size, GC struct field-read, GC array read/length, GC constructor, GC mutator/segment-drop, string array decode/encode, numeric saturating conversion, reference/i31, SIMD/vector, and atomic later operands via the shared instruction-effect/parameter-slot helper, but broader non-control expression coverage should continue to be widened under the active audit

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
