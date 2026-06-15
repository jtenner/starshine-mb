# `inlining-optimizing` Behavior Inventory Against Binaryen v130

Date: 2026-06-15

## Question

The whole-command wall-time backlog entry `[WALL]002` identifies `inlining-optimizing` as the dominant pass in self-optimization. Before changing performance behavior, inventory what Starshine's pass currently does and compare it directly to Binaryen's `version_130` inliner contract.

## Sources inspected

Local Starshine sources:

- `src/passes/inlining.mbt`
- `src/passes/inlining_test.mbt`
- `src/passes/inlining_wbtest.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `agent-todo.md`

Existing wiki sources:

- `docs/wiki/binaryen/passes/inlining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/index.md`

Fresh upstream v130 sources fetched into `.tmp/binaryen-v130/` with Python `urllib` because `curl` is unavailable:

- `src/passes/Inlining.cpp` from <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Inlining.cpp>
- `src/pass.h` from <https://github.com/WebAssembly/binaryen/blob/version_130/src/pass.h>
- `src/passes/opt-utils.h` from <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h>
- `src/passes/NoInline.cpp` from <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/NoInline.cpp>
- `src/passes/pass.cpp` from <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>

Local `wasm-opt --version` reports `wasm-opt version 130 (version_130)`.

## Binaryen v130 contract, condensed

Binaryen `inlining-optimizing` is not a separate inliner. `pass.cpp` registers both `inlining` and `inlining-optimizing`; both use the shared `Inlining` pass, with the `optimize` boolean enabled for the latter. The default global optimization post-pass schedule adds `inlining-optimizing` when `optimizeLevel >= 2 || shrinkLevel >= 2`, after `dae-optimizing` and before duplicate-function/import cleanup.

Binaryen phases:

1. Build per-function `FunctionInfo`: refs from direct calls and `ref.func`, measured body size, direct-call/loop/try-delegate flags, global/root use from exports/start/etc., trivial-instruction class, and cached inlining mode.
2. Classify each defined function as full-inlineable, partial-inlineable, or uninlineable.
3. Plan reachable direct `call` / `return_call` actions in parallel, skipping unreachable callsites and self-inlining.
4. Choose actions sequentially in module function order, preventing same-wave inline-into/inline-from races and enforcing combined-size limits.
5. Rewrite selected callsites by copying the callee body into the caller, adding fresh locals, assigning operands, zeroing defaultable callee locals, preserving unreachable callsite type behavior, repairing returns and nested tail calls, uniquifying labels, refinalizing, and handling nondefaultable locals.
6. If `optimize=true`, run `OptUtils::addUsefulPassesAfterInlining(...)` on the touched functions: `precompute-propagate` followed by Binaryen's default function optimization pipeline under a filtered nested runner.
7. Remove callees only if all counted refs were inlined away and the function is not globally/root used.
8. Iterate until no touched functions, with at most original-function-count outer iterations and a per-function repeated-work cap of five.

Important Binaryen defaults from `pass.h`: `alwaysInlineMaxSize = 2`, `oneCallerInlineMaxSize = -1`, `flexibleInlineMaxSize = 20`, `maxCombinedBinarySize = 400 * 1024`, `allowFunctionsWithLoops = false`, and `partialInliningIfs = 0`.

## Starshine behavior inventory

### Public surface and scheduling

- `src/passes/optimize.mbt` registers both `inlining` and `inlining-optimizing` as module passes.
- Public `optimize` and `shrink` presets include `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`.
- `src/passes/pass_manager.mbt` dispatches `inlining` with `optimize=false` and `inlining-optimizing` with `optimize=true`, forwarding `optimize_level`, `shrink_level`, and trace for the optimizing sibling.

### Summary construction

Starshine's `InlFunctionInfo` records params, results, optional zero-param result type for multi-value wrapper blocks, instruction count, `has_return_call`, and `inlineable`. It does not persist Binaryen's full `FunctionInfo` shape (`refs`, `usedGlobally`, direct `hasCalls`, `hasLoops`, `hasTryDelegate`, `trivialInstruction`, cached mode) after classification, but computes enough local facts while building `inlineable`.

Starshine scans refs from code and marks global/root uses. Its ref scan and remap paths include direct `call`, `return_call`, `ref.func`, element/table/global/data initializer expressions, exports, and start sections. This aligns with Binaryen's rule that helper deletion depends on both rewritten direct calls and surviving roots/refs.

### Inlineability heuristic

Starshine marks defined functions inlineable when all of these hold:

- not blocked by local `no-full-inline` policy;
- result block type can be represented, synthesizing/reusing zero-param multi-result types as needed;
- no `try_table` body shape is seen;
- one of:
  - `size <= 2`,
  - shrinking trivial wrapper,
  - `refs[abs] == 1 && !used[abs]`,
  - speed-focused flexible case: `optimize_level >= 3 && shrink_level == 0 && !has_calls && !has_loops && size <= 20`.

This is close to Binaryen's default layered policy for full inlining, except Starshine's try guard is expressed as any `try_table` instead of Binaryen's `try_delegate` guard, and Starshine does not implement Binaryen's partial-inlining mode.

### Trivial-wrapper coverage

Starshine's test inventory shows broad shrinking-trivial coverage: ordered parameter passthrough for binary/unary/select operations, stores, memory/table operations, SIMD, GC heap wrappers, and direct-call wrappers. It also distinguishes may-not-shrink repeated-param wrappers under speed-focused `optimize_level >= 3 && shrink_level == 0`.

This matches the important Binaryen semantic split: exact ordered parameter passthrough always shrinks; repeated/skipped/constant operands are flexible speed-focused cases.

### Action discovery and same-wave guards

Starshine rewrites nested direct `call` and `return_call` instructions recursively. It skips self-inlining and skips rewriting a caller that was already inlined from in the same wave (`inlined_from[caller_abs]`). It also refuses to inline a callee that has already been touched in the same wave. That approximates Binaryen's same-wave race guards: do not inline into a function and then inline that function elsewhere in the same iteration.

Starshine differs in planning shape: Binaryen separates parallel discovery from deterministic choice over module function order. Starshine mutates while recursively scanning each function. Tests cover iteration after same-wave race cases and repeated recursive work caps, but this is not the same algorithmic structure.

### Body rewrite semantics

Starshine body copy currently:

- appends fresh caller locals for callee params and body locals;
- stores call operands into mapped callee params in reverse operand order, preserving stack evaluation order for stack-machine WAT lowering;
- zero-initializes defaultable copied callee locals;
- rewrites copied `local.get` / `local.set` / `local.tee` through the local map;
- rewrites copied `return` to `br` out of a wrapper block;
- wraps the copied body in a block with the callee result type, using synthesized zero-param type entries for multi-value results when needed;
- preserves nested `return_call*` at tail callsites and skips non-tail callees that contain return-call forms.

Binaryen does the same broad frame-illusion work, but has additional source-level repair that Starshine does not fully mirror: fresh named wrapper labels and collision avoidance, hoisting `return_call` inside try, nested `return_call_indirect` / `return_call_ref` downgrade paths for non-tail callsites, `UniqueNameMapper`, `ReFinalize`, and `TypeUpdating::handleNonDefaultableLocals` after body copy.

Starshine's current coverage includes multi-result wrappers, default-local zeroing, several tail-call preservation cases, and non-tail nested return-call bailout. It does not claim full Binaryen repair parity for label/name repair, partial splitting, or nondefaultable-local repair.

### Helper deletion and remapping

After rewriting, Starshine recomputes refs and used-root facts, removes only inlined-from helpers that are inlineable, have no refs, and are not used globally, then remaps:

- function section and code section;
- direct calls, return calls, and `ref.func`;
- exports and start;
- element kind expressions and active element offsets;
- table/global/data initializer expressions;
- function annotations;
- name sections.

Starshine deliberately keeps function names but drops function-scoped local/label name maps after compaction. That is a known accepted representation/debug-name gap, not a semantic transform difference.

The optimizing sibling adds extra retention/prediction logic for unreachable helper cycles and duplicate signatures. This is Starshine-specific artifact/parity scaffolding, not a Binaryen source-level phase. It exists to make normalized direct comparisons and debug-artifact fronts line up around unreachable private cycles.

### Optimizing cleanup suffix

Binaryen's optimizing suffix is simple at the source level: on touched functions, run `precompute-propagate` and then `addDefaultFunctionOptimizationPasses()` through a nested filtered runner.

Starshine's suffix is an approximation built in `inl_run_nested_cleanup`:

- skips the whole suffix for modules with more than `80` defined functions;
- has special unreachable/self-loop helper collapse paths before the generic scheduler;
- runs a private `precompute-propagate-prefix` first;
- then runs a hand-expanded touched-function pass list, gated by optimize/shrink levels:
  - optional `ssa-nomerge`,
  - DCE / remove-unused-names / remove-unused-brs / vacuum cluster,
  - optimize-instructions / heap-store-optimization,
  - optional pick-load-signs, precompute, optional code-pushing,
  - tuple-optimization, simplify-locals-nostructure, vacuum, reorder-locals, remove-unused-brs,
  - optional heap2local, merge-locals, optimize-casts, local-subtyping, local-cse,
  - simplify-locals / vacuum / local reorder-coalesce cluster,
  - optional code-folding,
  - merge-blocks / remove-unused-brs / remove-unused-names / merge-blocks / precompute / optimize-instructions / heap-store-optimization,
  - optional redundant-set-elimination,
  - final vacuum;
- restores untouched functions after nested cleanup;
- prunes/collapses dead unreachable roots and compacts unused locals.

This is behaviorally intended to approximate Binaryen's touched-function nested cleanup, but it is not an exact expansion of Binaryen's current default function pipeline. The large-module guard is especially relevant to the wall-time issue: on modules above the guard it avoids the nested cleanup cost entirely, but `[WALL]002` shows the self-optimization artifact still spends about 676.916s inside a top-level `pass:inlining-optimizing`, so the dominant cost is likely before or around summary/rewrite/iteration/prediction logic rather than the guarded generic suffix alone.

### Iteration and finalization

Starshine iterates up to `defined_func_count + 1`, tracks touched original absolute indices, and stops when any original function reaches a repeated-work count of five. This mirrors Binaryen's two bounds directionally: no more than the original function count and per-function cap of five.

Starshine also runs final `inl_finalize_module_pass_result(...)`; for optimizing modules with `<= 80` defined functions this can perform full defined-function local cleanup and type-section compaction. Binaryen does not have this separate Starshine-specific final local cleanup phase in the `Inlining.cpp` algorithm; its cleanup comes from the nested useful passes and helper removal.

## Direct comparison table

| Behavior area | Binaryen v130 | Starshine current | Classification |
| --- | --- | --- | --- |
| Public pass split | `inlining` and `inlining-optimizing` share engine; optimizing adds cleanup | Same shared entry with `optimize` boolean | Match |
| Default scheduling | Post global optimization: after DAE, before DFE/DIE | Same late-tail placement in public presets | Match for current preset intent |
| Summary facts | refs, size, hasCalls, hasLoops, hasTryDelegate, usedGlobally, trivial class, cached mode | computes refs/used/shape/trivial, stores reduced info | Mostly match; less explicit state |
| Direct-call action scope | reachable direct `call` / `return_call`; not indirect/ref calls | direct `call` / `return_call`; call_ref/indirect not inline actions | Match |
| `ref.func` handling | counts as ref/survival | scanned/remapped as survival ref | Match |
| Always-inline threshold | size <= 2 | size <= 2 | Match |
| One-use private threshold | refs == 1, !usedGlobally, size <= -1 default (effectively all sizes) | refs == 1 and !used | Match in effect |
| Flexible speed case | O3/no-shrink, size <= 20, no direct calls, no loops unless option | optimize>=3/shrink==0, size <= 20, no direct calls, no loops | Match for default no-loop policy |
| `try_delegate` | full-inline bailout | any `try_table` bailout | Conservative broader Starshine guard |
| Partial inlining | implemented but default-disabled (`partialInliningIfs=0`) | not implemented; `no-partial-inline` marker exists | Acceptable for default direct lane; deferred for wider parity |
| Same-wave guard | plan then choose deterministically; avoid inline-into/inline-from races | recursive rewrite with touched/inlined-from guards | Approximation; tests cover main race cases |
| Copy locals/params | fresh locals, operand assignment, zero defaultable vars | fresh locals, reverse param stores, zero defaultable locals | Match at semantic level |
| Return repair | return -> break to wrapper | return -> `br` depth | Match for ordinary returns |
| Tail-call repair | handles outer return_call and nested return_call* downgrade/try hoist | tail callsite support and non-tail nested return-call bailout/preservation tests | Partial; broader Binaryen repair deferred |
| Label repair | fresh named blocks, collision avoidance, uniquify | depth-based wrapper, drops local/label names; no full name repair | Partial/representation gap |
| ReFinalize/nondefaultable locals | explicit post-inline repair | validation-oriented local type handling; no full Binaryen equivalent visible | Potential parity gap; currently guarded/tested subset |
| Helper deletion | remove only when all refs inlined and not global | recompute refs/used and remove only inlined dead helpers | Match plus Starshine-specific retain counts in optimizing mode |
| Optimizing suffix | filtered touched functions: `precompute-propagate` + default function pipeline | hand-expanded touched-function approximation with guards and extra unreachable/local cleanup | Approximation; likely wall-time/complexity target |
| Large module behavior | no hard function-count skip in source contract | nested cleanup skipped above 80 defined funcs; final cleanup also gated | Intentional Starshine correctness/perf guard, not Binaryen parity |
| Artifact-specific unreachable cycle logic | not present as separate source phase | substantial predictor/pad/trim/collapse logic | Starshine-specific parity scaffolding; prime performance suspect |

## Performance-relevant suspects before optimization work

Given `[WALL]002`, add timers before changing semantics. The most likely expensive buckets in Starshine are:

1. `inl_original_reachable_private_cycle_funcs(...)` and the prediction helpers it calls. This code spans many graph/signature/dead-suffix recognizers and is run at least once per public pass invocation, with additional per-iteration graph decisions.
2. `inl_build_function_infos(...)`: scans every function body for refs, used roots, shape flags, instruction counts, and trivial wrappers each iteration.
3. `inl_rewrite_all_calls(...)`: recursively walks all defined function bodies each iteration, even if few callsites are eligible.
4. The iteration loop: up to defined function count plus one, with per-original-function count tracking. The cap prevents infinite recursion but may still allow many full-module scans on large artifacts.
5. Starshine-specific unreachable helper padding/trimming/collapse after each optimizing wave.
6. Nested cleanup only for modules with `<= 80` defined functions. It is still expensive on small/medium generated cases, but it should not explain a huge debug-CLI artifact if that artifact has more than 80 defined functions at the point the guard is checked.

## Suggested next instrumentation

Add timers matching `[WALL]002`'s requested buckets:

- `inl_original_reachable_private_cycle_funcs`
- `inl_prepare_multivalue_block_types`
- `inl_build_function_infos`
- `inl_rewrite_all_calls`
- `inl_remove_dead_inlined_helpers`
- `inl_run_nested_cleanup`
- `inl_remove_dead_unreachable_private_funcs`
- `inl_pad_unreachable_to_predicted_counts`
- `inl_trim_unreachable_to_predicted_counts`
- `inl_trim_unreachable_to_selected_counts`
- per-iteration counts: iteration number, functions touched, helpers removed, calls inlined, and whether the large-module nested-cleanup guard fired.

## Current audit conclusion

Starshine's direct inlining core is behaviorally close to Binaryen's default full-inlining path for direct calls, refs/roots, primary heuristics, helper deletion, and bounded iteration. The largest behavioral differences are not the basic eligibility thresholds; they are the repair/scheduler edges: broader `try_table` conservatism, no partial inlining, partial tail-call/name/nondefaultable repair, a hand-expanded optimizing suffix, a large-module suffix guard, and substantial Starshine-only unreachable-cycle prediction/trim scaffolding.

For the wall-time issue, do not start by rewriting Binaryen-compatible heuristics. First instrument the Starshine-only graph/prediction and repeated full-module scan phases. Those are the areas least directly mandated by Binaryen's source contract and most suspicious as proportionality bugs on the self-optimization artifact.
