---
kind: concept
status: supported
last_reviewed: 2026-07-04
sources:
  - ../../../raw/research/0534-2026-05-06-local-subtyping-direct-revalidation.md
  - ../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/1429-2026-07-03-local-subtyping-closeout-lane-evidence.md
  - ../../../raw/research/1430-2026-07-04-local-subtyping-ordered-neighborhood-cleanup.md
  - ../../../raw/research/1431-2026-07-04-local-subtyping-behavior-family-matrix.md
  - ../../../raw/research/1432-2026-07-04-local-subtyping-retag-representation-and-unreachable-boundary.md
  - ../../../raw/research/1433-2026-07-04-local-subtyping-iterative-refinalization.md
  - ../../../raw/research/1434-2026-07-04-local-subtyping-select-lub-refinalization.md
  - ../../../raw/research/1435-2026-07-04-local-subtyping-call-ref-refinalization.md
  - ../../../raw/research/1438-2026-07-04-local-subtyping-raw-unreachable-tee-boundary.md
  - ../../../raw/research/1439-2026-07-04-local-subtyping-ref-catch-raw-assignment.md
  - ../../../raw/research/1440-2026-07-04-local-subtyping-final-closeout-evidence.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
---

# Starshine strategy for `local-subtyping`

Use this page together with the corrected Binaryen source manifest in [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md), the source-correction note in [`../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md`](../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md), the upstream implementation/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The 2026-05-06 repo-source correction replaced an older stale reading: `local-subtyping` is already active in Starshine.

## Honest current status

`local-subtyping` is an active Starshine module pass.

It has:

- a real owner file;
- a registry entry;
- a dispatcher case;
- CLI support via `--local-subtyping`;
- preset-slot coverage in the default hot optimize path.

What it does **not** have yet is full Binaryen parity.
The current implementation is a narrower subset that narrows body locals from write-site evidence, with early nullable-to-non-null declaration narrowing when every observed `local.get` is after a dominating write in a straight-line root, inside a branch-free `block` or `loop` entered after that write, inside the source-backed loop tail-`br_if` backedge case entered after that write, after a branch-free `block` write that dominates a later outer get, before a terminal `br` / `br_table` whose branch does not need to propagate writes to an outer post-state, inside branch-free nested `if` arms in such a dominated region, inside branch-free root `if` arms entered after that write, inside direct `return_call`, `return_call_indirect`, `return_call_ref`, `throw`, or `throw_ref` if-arms that skip a later dominating write/get path, or before a root/block terminal `return`, direct `return_call`, `return_call_indirect`, or `return_call_ref`, before a root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` whose later gets are already dominated and unreachable, a nested block terminal `return` or `throw` inside a return/return_call/throw-skipped `if` arm, root/block terminal `throw`/`throw_ref`, or a `try_table` body whose get is dominated by that write, including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails whose later gets are already dominated. It also has source-backed nullable fallback guards for loop writes before outside gets, all-arm `if` writes before outside gets, block writes followed by branch flow before outside gets, `try_table` body writes before outside gets, `br_if` paths that can skip a later block write, and parameter writes that leave signature params unchanged, focused validation for non-null `local.tee` assignment/use narrowing, an iterative rewrite/re-lift loop that covers Binaryen's local-get `multiple-iterations` chain, a source-backed adjacent-local-get `select`/LUB repair that covers Binaryen's `multiple-iterations-refinalize` select shape, and represented zero-param adjacent-local-get `call_ref` refinalization including the bottom-call-ref unreachable value replacement.

## Exact local code map today

- `src/passes/local_subtyping.mbt:1-19`
  - summary and public pass description.
- `src/passes/local_subtyping.mbt`
  - heap subtype helpers, assignment collection, candidate narrowing, adjacent-local-get select/LUB annotation repair, zero-param adjacent-local-get call_ref immediate repair and bottom-call-ref unreachable value replacement, straight-line/block/loop/nested-if/root-if dominance scanning including the narrow tail-`br_if` loop-backedge subset, branch-free block write post-state propagation, terminal `br` / `br_table` dominated-get admission without outer post-state propagation, root/block terminal-`return`/direct `return_call`/`return_call_indirect`/`return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` unreachable-tail-get admission, if-arm nested block terminal-`return`/`throw`, root/block terminal-`throw`/`throw_ref`, and `try_table` body dominated-get admission including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails with already-dominated gets, and function-local rewrite.
- `src/passes/registry_test.mbt:78-82`
  - registry category proof: `local-subtyping` is a module pass.
- `src/passes/optimize.mbt:284-285, 296-312`
  - registry entry plus `optimize` / `shrink` preset inclusion.
- `src/passes/pass_manager.mbt:8937-8940`
  - active hot-pass dispatcher case.
- `src/passes/optimize_test.mbt:491-495, 522-526`
  - preset honesty plus exact local-subtyping slot placement in the optimize preset.
- `src/passes/local_subtyping_test.mbt`
  - direct active-pass tests for registry lookup, write-site narrowing, tee assignments, straight-line non-null dominance, branch-free block/loop dominance/fallback, loop tail-`br_if` backedge dominance, terminal `br` / `br_table` dominated-get narrowing, branch-free block-write post-state propagation, branch-free nested block-if dominance, source-backed nullable loop/if/branch-flow/`br_if`-skipped-write post-state fallback, parameter preservation, branch-free root-if dominance/fallback, root/block terminal-return and direct return_call, root non-final return/tail-call unreachable-tail-get coverage, direct if-arm return_call/throw/throw_ref-skip, if-arm nested block terminal-return/throw, and root/block terminal-throw/throw_ref dominance, and try_table body dominance including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails with already-dominated gets.
- `src/cmd/cmd_wbtest.mbt:4376-4439`
  - CLI integration test for `--local-subtyping` on wasm inputs.
- `src/validate/gen_valid.mbt` and `src/validate/gen_valid_tests.mbt`
  - dedicated `local-subtyping-all` GenValid aggregate with `local-subtyping-straight-line`, `local-subtyping-structured`, and `local-subtyping-unreachable-tail` trigger leaves for closeout evidence.

## What the current implementation actually does

The current Starshine code path is intentionally small:

1. lift each function into HOT form;
2. collect assignment result types from `local.set` and `local.tee`;
3. pre-scan the raw straight-line body, branch-free `block` bodies, branch-free block writes before later outer gets, terminal `br` / `br_table` block bodies whose gets are already dominated before the branch, `loop` bodies entered after prior writes including the narrow source-backed tail-`br_if` backedge subset, branch-free nested `if` arms inside such dominated regions, branch-free root `if` arms, conditional-`return` branches, direct `return_call` / `return_call_indirect` / `return_call_ref` arms, and direct `throw` / `throw_ref` arms that skip a later write/get path, and root/block terminal `return`/direct `return_call` / `return_call_indirect` / `return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` tails before already-dominated unreachable-tail gets, if-arm nested block terminal `return`/`throw`, root/block terminal `throw`/`throw_ref`, or a `try_table` body (non-throwing, ending in terminal body `return`/`throw`/`throw_ref`, or containing a source-backed non-final body `return`/`throw`/`throw_ref` before already-dominated unreachable-tail gets) after dominated gets to decide where a nullable body local may safely become non-null because reads are dominated by an earlier write, while keeping nullable fallbacks at the source-backed loop/if/branch-flow post-state boundaries, direct block-return validator boundary, try-table body post-state boundary, `br_if` paths that can skip writes, and preserving parameters as signature-owned locals;
4. pick the most specific safe common reference subtype, falling back to nullable when dominance is not proven;
5. rewrite body-local declarations only;
6. repair the source-backed adjacent-local-get `select`/LUB annotation when narrowed local declarations make a sharper reference LUB available;
7. rebuild and re-lift the module while declarations, select annotations, or call_ref repairs keep changing, so dependent `local.get`, select, and call_ref assignment types can sharpen after earlier declaration rewrites;
8. return the original module unchanged when no rewrite is needed.

That gives Starshine a real, active `local-subtyping` pass without pretending to have the whole upstream contract yet.

## What is still missing versus Binaryen

The 2026-07-04 behavior-family matrix refreshed Binaryen `version_130` primary sources and found no diff from the earlier `version_129` source/lit basis. That review reduces the previous broad gap list to targeted residuals.

Implemented or protected for the active v0.1.0 audit scope:

- body-local assignment LUB narrowing, conservative no-rewrite behavior for non-reference/nondefaultable shapes, and parameter preservation;
- straight-line and same-scope non-null dominance;
- unnamed/branch-free block, loop-entry, nested-if, root-if, terminal-branch, return/tail-call/throw/throw_ref, unreachable-tail, and try-body dominated-get subsets that have focused coverage;
- source/probe-backed nullable fallbacks for named/branch-flow block post-state, branch-skipped writes, loop writes before outside gets, all-arm `if` writes before outside gets, try-body writes before outside gets, and the direct block-return validator/tooling boundary, whose reduced Binaryen non-null output is currently rejected by `wasm-tools` and Starshine validation;
- `catch_ref` / `catch_all_ref` skipped-write local-flow parity for the probed result-flow shapes by using a conservative raw assignment collector that matches Binaryen's nullable exact-child narrowing without granting non-null dominance through ref-catch paths;
- cleanup-normalized routing for the direct wasm-smith unreachable-control debris and ordered-neighborhood local-cleanup residuals.

Two precise Binaryen-relevant surfaces remain intentionally unimplemented until the validator/tooling story changes:

1. a validator/tooling solution or validating Binaryen output repair for the direct block-return nondefaultable-local unreachable-tail family;
2. a validator/tooling solution for the raw-unreachable-before-write nondefaultable-local tee/get family exposed by Binaryen's retag lit shape. The 2026-07-04 refresh reduced this to an exact nullable function-local tee/get shape: Binaryen v130 narrows it to non-null exact, `wasm-tools` rejects that output with `uninitialized local: 1`, and rebuilt Starshine keeps a nullable exact local that validates.

These are not Starshine wins. Reopen either boundary if the non-null output starts validating, Starshine validation intentionally adopts a spec-backed proof, Binaryen repairs the output shape, or LS can safely repair/avoid the later get while preserving valid emitted wasm. Reopen ref-catch under LS only for a reduced case outside the raw-assignment subset, such as a catch-payload result join or unknown producer that cannot safely fall back to the declared local type.

The represented zero-param adjacent-local-get `multiple-iterations-refinalize-call-ref` and bottom-call-ref lit surfaces are now implemented. Reopen `call_ref` refinalization for non-adjacent target flow, parameterized bottom-call replacement, argument side-effect preservation, or type-immediate rewrites with non-identical params.

The broad explicit `local.get` / `local.tee` retagging item is no longer a Starshine emitted-representation gap: `src/lib/types.mbt` stores only local indexes for those instructions, and Starshine rebuilds the original lib body with new declarations rather than lowering a stale typed HOT graph. Focused tee-parent coverage validates after narrowing without a retag repair pass.

So the right mental model is:

- **active pass**: yes;
- **many direct behavior families protected**: yes;
- **active v0.1.0 `-O4z` audit scope closed**: yes, with two explicit nondefaultable-local validator/tooling boundaries and cleanup-normalized representation residuals documented with reopening criteria rather than hidden as broad LS behavior gaps.

## Validation posture

Current shipped coverage proves:

- registry category is active module-pass;
- the pass narrows a body local to a child heap type;
- mixed sibling writes keep the common parent type;
- the CLI path accepts `--local-subtyping`;
- the default optimize preset keeps the pass in the `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` neighborhood.

The 2026-07-04 final closeout refresh after the ref-catch raw-assignment fix ran focused `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` (`73/73`), `moon info`, `moon fmt`, `moon test src/passes` (`3983/3983`), full `moon test` (`7390/7390`), native `src/cmd` build, regular GenValid `100000`, explicit wasm-smith `10000`, a cleanup-normalized wasm-smith replay, dedicated `local-subtyping-all` `10000`, and random-all-profiles `10000`. Regular `.tmp/pass-fuzz-local-subtyping-genvalid-100000-20260704-refcatch` compared/normalized `100000/100000` with zero failures. Explicit wasm-smith `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch` compared `9956/10000`, normalized `9955`, had zero validation/generator/property failures, `44` Binaryen/tool command failures, and one raw mismatch. Agent classification: the one mismatch is pass-independent unreachable-control cleanup debris (`drop(unreachable)` before final `unreachable`) and not an LS semantic mismatch or Starshine win. The replay `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch-unreachable-normalized` with `--normalize unreachable-control-debris` converts that one case to a cleanup-normalized match and leaves zero mismatches. Dedicated `.tmp/pass-fuzz-local-subtyping-genvalid-all-10000-20260704-refcatch` and broad `.tmp/pass-fuzz-local-subtyping-random-all-profiles-10000-20260704-refcatch` both compared/normalized `10000/10000` with zero failures. The 2026-07-04 ordered-neighborhood rerun `.tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-local-cleanup-20260704` used `--normalize local-cleanup-debris` for `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` and compared `10000/10000` with `634` normalized matches, `9366` cleanup-normalized matches, zero mismatches, and zero failures. Agent classification: the ordered raw timeout is local-cleanup representation drift after the neighborhood, not a direct LS semantic mismatch and not a Starshine win. The earlier 2026-05-06 refreshed direct pass signoff ran `moon info`, `moon fmt`, `moon test`, and a 10000-case regular compare with 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.

The newest LS audit slices add focused coverage for direct `local.tee` assignments including non-null tee assignment/use validation, tee-parent validation without emitted retag repair, straight-line nullable-to-non-null narrowing after a dominating write, branch-free `block` and `loop` gets dominated by an earlier write, a source-backed loop tail-`br_if` backedge get dominated by an earlier write, branch-free `block` writes that dominate later outer gets, terminal `br` / `br_table` block bodies whose gets are already dominated before the branch, gets inside a branch-free nested `if` in a dominated region, branch-free root `if` gets dominated by an earlier write, conditional-`return` branches, direct `return_call`, `return_call_indirect`, and `return_call_ref` arms, and direct `throw` / `throw_ref` arms that skip the later write/get path, root/block terminal `return` and direct `return_call` / `return_call_indirect` / `return_call_ref` after a dominated get, root non-final return/tail-call tails before already-dominated unreachable-tail gets, if-arm nested block terminal `return`/`throw` after a dominated get, root/block terminal `throw`/`throw_ref` after a dominated get, `try_table` body dominated gets including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails with already-dominated tail gets, represented zero-param adjacent-local-get `call_ref` and bottom-call-ref refinalization, ref-catch skipped-write nullable exact-child narrowing through the raw assignment collector, and nullable fallback when a `local.get` can observe the default value before the first write, inside an earlier block/if arm, after a raw `unreachable` before the write, after a branch-free loop write, after all-arm `if` writes, after a block write followed by branch flow before a later outside get, when a `br_if` can skip a later block write, or at the direct block-return validator boundary. The straight-line, block-entry, block-write post-state, terminal-branch, loop-entry, loop-backedge, nested block-if, root-if, conditional-return, direct return_call/return_call_indirect/return_call_ref skip, direct-throw/direct-throw_ref skip, root/block terminal-return/return_call/return_call_indirect/return_call_ref, root non-final return/tail-call unreachable-tail-get positives, if-arm nested block terminal-return/throw, root/block terminal-throw/throw_ref, try_table body non-null positives including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails, ref-catch skipped-write nullable exact positives, and tee-parent retag-representation positive are protected; optimized modules are validated after narrowing.

Future reopening tests should cover:

1. the direct block-return nondefaultable-local validator/tooling boundary if Starshine validation can prove Binaryen's unreachable-tail shape or Binaryen repairs the output;
2. the raw-unreachable-before-write nondefaultable-local validator/tooling boundary if Starshine validation can prove Binaryen's tee/get retag lit shape or LS can repair the later get safely;
3. any future EH `catch_ref` / `catch_all_ref` local-flow case outside the raw-assignment skipped-write subset, especially catch-payload result joins that must stay broad;
4. keeping the ordered GC/local neighborhood residual precisely routed. The raw ordered attempt `.tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-20260703` for `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` timed out after 3600s with only `200` partial cases (`18` matches, `182` mismatches), but the cleanup-normalized rerun `.tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-local-cleanup-20260704` compared `10000/10000` with zero failures under `--normalize local-cleanup-debris`. Treat this as a downstream local-cleanup representation owner with LS reopening criteria rather than a broad hidden LS blocker.
5. using the required-size-green `local-subtyping-all` GenValid aggregate as the dedicated closeout profile. Its current leaves cover straight-line local.set/local.tee dominance, branch-free block/loop/if dominated reads, and root return/unreachable-tail reads over nullable `anyref` body locals written with non-null `struct.new_default` values.

## Bottom line

`local-subtyping` in Starshine is real and active today.
For the active v0.1.0 `-O4z` audit scope, the recursive LS closeout is complete; future work is reopening only under the documented validator/tooling, EH, or cleanup-owner criteria.
