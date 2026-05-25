# SGO next-slice probe inventory refresh

Date: 2026-05-25

Slice: `[SGO]003A` Next-Slice Probe Inventory Refresh

## Scope

Refresh the post-`0632` simplify-globals-optimizing gap list before choosing another behavior-bearing slice. This is a research/backlog slice only: no optimizer behavior changes, no test changes, and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

Inputs checked:

- `agent-todo.md` `[SGO]003A` through `[SGO]003P` split.
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md` current SGO matrix.
- `src/passes/simplify_globals_optimizing.mbt` matcher families, especially FlowScanner, read-only-to-write wrapper dispatch, no-catch `try_table`, loop fallback, same-init writes, and runtime fact propagation.
- `src/passes/simplify_globals_optimizing_test.mbt` current focused coverage names and fixture clusters.
- Recent post-0603 through 0632 notes, especially the no-catch `try_table` breadth and refactor-only matcher consolidation series.

## Inventory result

The matrix and source now show heavy coverage for direct/pure/select/nested-if/no-catch-`try_table` read-only-to-write self guards, startup/global-initializer folds, current same-init direct literal/ref/null/ref.func cases, runtime local facts inside selected structured bodies, and direct-call write-set filtering for runtime facts. The next implementation slice should therefore avoid broad analogy-based expansion from the already-covered no-catch `try_table` or nested-if families.

The most useful remaining work falls into three groups:

1. **Behavior-bearing but bounded:** wrapper/control shapes where Binaryen can be probed with tiny positive/negative pairs and Starshine can reject unsafe consumers locally.
2. **Research dependency:** call/read summaries and loop/catch/control broadening where safety depends on effects, dominance, or backedge reasoning rather than a local syntactic matcher.
3. **Parser/refinalization blockers:** GC replacement surfaces such as `ref.cast(ref.func-global)` that need a fixture path and validation/type-repair plan before implementation.

## Ranked candidate slices

### 1. `[SGO]003B` narrow transparent wrapper grammar around current FlowScanner guards

Recommended next implementation slice if behavior work is desired.

Exact positive fixture shapes to probe first:

- A same-global read-only-to-write guard whose condition is a `block (result i32)` containing only nested transparent `block (result i32)` wrappers around an already-supported `global.get $g` / pure-condition FlowScanner chain, followed immediately by the no-else `if (then i32.const <same-init>; global.set $g)` body.
- The same shape through a clean no-value prefix wrapper before the result block, where the prefix has no branch, return, call, candidate-global read, candidate-derived consumer, or same-global write.
- A two-wrapper combination around an already-supported external pure condition chain, not around a new opcode family.

Required negative fixture pairs:

- Wrapper body contains `br`, `br_if`, `return`, or other control transfer before the yielded candidate-derived condition.
- Wrapper consumes the candidate-derived value in a trapping load or `table.get` before the final branch.
- Wrapper contains a direct/indirect/reference call whose operand is candidate-derived.
- Wrapper contains an extra dropped same-global read, or a same-global write not matching the final guard.
- Wrapper adds an `else` or post-join observable use.

Expected Binaryen behavior to confirm:

- Binaryen removes/replaces fake same-global traffic for the transparent positive shapes.
- Binaryen preserves the negative shapes because the candidate read either has an observable consumer, additional same-global traffic, control transfer, or join ambiguity.

Current Starshine behavior/risk from source audit:

- Starshine already has `sgo_block_or_no_catch_try_table_body(...)`, FlowScanner chains, direct/`i32.eqz`/compare/reverse-compare guard dispatch, and nested transparent block coverage in several families, but the grammar is deliberately split by family and may not accept every nested wrapper combination.
- Risk is **medium-low** if the slice only composes existing wrapper extraction and FlowScanner-safe chains, with explicit negatives. Avoid adding calls, new side-effect families, or loop/catch handling in this slice.

### 2. `[SGO]003G` no-catch `try_table` wrapper composition inventory, not catch-bearing transparency

Recommended as a research-first slice, or a tiny behavior slice only if probes show an uncovered positive that reuses existing no-catch matchers.

Exact positive fixture shapes to probe first:

- `try_table (result i32)` with no catches wrapping an already-supported transparent result block, then the existing direct/`i32.eqz`/compare self guard.
- `try_table (result i32)` with no catches wrapping an already-supported external pure FlowScanner chain, then exact `if return; global.set` tail.
- `try_table (result funcref)` with no catches wrapping a transparent `block (result funcref)` around `global.get $g`, followed by existing `ref.is_null` guard families.

Required negative fixture pairs:

- Any catch-bearing `try_table`, even if the body is otherwise identical.
- Handler/control-transfer body with branch/return/throw/rethrow/delegate-like behavior.
- Post-`try_table` fact/join use rather than immediate self-guard use.
- Candidate-derived trapping load/table/call operand inside the body.

Expected Binaryen behavior to confirm:

- Binaryen is expected to treat some no-catch wrappers as transparent when the value still flows exclusively to the same-global guard, matching earlier 0603-0619 families.
- Catch-bearing wrappers must remain conservative unless a fresh oracle contradicts that; previous Starshine policy intentionally rejects them.

Current Starshine behavior/risk from source audit:

- Starshine now has extensive no-catch immediate, compare, select, ref.is_null, pure-post, and exact if-return tail machinery after 0603-0632. The remaining likely gaps are wrapper composition rather than a new semantic family.
- Risk is **medium**: easy to accidentally broaden caught `try_table` or post-join facts if the matcher becomes too generic. Keep caught negatives paired with every positive.

### 3. `[SGO]003I` callee global-read summaries before any call-shaped read-only-to-write positives

Recommended research/dependency slice before touching `[SGO]003E` call behavior.

Exact probe shapes:

- Direct callee with no candidate operands and no candidate global read/write between the initial read and final same-global write.
- Direct callee that reads the candidate global but does not write it.
- Direct callee that writes the candidate global.
- Direct callee that reads/writes a different global.
- Imported call, indirect call, `call_ref`, `return_call`, and recursive call-cycle variants.

Required negative fixture pairs:

- Candidate-derived call operands.
- Imported or dynamic calls without complete summaries.
- Recursive cycles where read/write facts are not at a fixed point.
- Callee reads the candidate global in a way that would make the original read observable if removed.

Expected Binaryen behavior to confirm:

- Existing local guardrails already show calls do not count as local syntactic read-only-to-write events in Starshine. Binaryen probes should decide whether that is a true Binaryen boundary or an analysis gap.
- Runtime trace propagation already benefits from write summaries, but read-only-to-write removal may require read summaries too.

Current Starshine behavior/risk from source audit:

- Starshine tracks direct-call global writes for runtime fact invalidation but does not track callee reads as a syntactic read-only-to-write safety fact.
- Risk is **high** for implementation and **low** for research. Do the summary design first; do not add call positives directly from local operand cleanliness.

## Downranked or blocked slices

- `[SGO]003C` nested-if arm breadth is already broad and test-heavy. More work is possible, but exact value-flow positives should come from probes, not from adding more supported post-consumers by analogy.
- `[SGO]003D` safe side-effect independence is broad and easy to over-whitelist. Prefer exact instruction-family probes only after `[SGO]003B`/`003G` wrapper composition is exhausted.
- `[SGO]003F` loop self-guard broadening remains high risk because backedges and branch/control bodies can make local FlowScanner reasoning unsound. Keep current non-branching value-loop subset unless a fresh probe gives an exact safe grammar.
- `[SGO]003J` same-init expression equivalence is not a good next implementation slice. Prior probes found block-wrapped/read-present and imported-provenance negatives, so broader expression equivalence needs a new source-backed positive.
- `[SGO]003L` GC refinalization is blocked on parser/lib lowering and validation/type repair for the narrow `ref.cast(ref.func-global)` positive. Resolve the fixture/refinalization path before implementation.
- `[SGO]003O` refactor-only work is lower priority after the 0623-0632 consolidation streak; do it only when it unlocks a behavior slice or materially reduces duplication.

## Recommended next action

Pick one of these next, in order:

1. `[SGO]003B` as a narrow behavior-bearing wrapper-composition slice with tests first and paired negatives.
2. `[SGO]003G` as a no-catch `try_table` wrapper-composition probe/implementation slice, with caught negatives mandatory.
3. `[SGO]003I` as a research-only read/write summary design before any call-shaped read-only-to-write implementation.

Keep `[SGO]003` active/partial after any one of these. Do not claim full Binaryen `SimplifyGlobals.cpp` parity from the inventory or from one follow-up slice.

## Validation

No code behavior changed in this slice. Commit validation should include at least docs/backlog diff hygiene and the standard quick gate requested for pass work.
