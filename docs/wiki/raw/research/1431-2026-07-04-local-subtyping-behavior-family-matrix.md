# Local-subtyping behavior-family matrix

Date: 2026-07-04

## Question

After the direct closeout lanes and ordered-neighborhood cleanup classification, are the remaining `local-subtyping` (`LS`) behavior gaps still broad/hidden, or can they be reduced to precise implemented families, source-backed nullable/tooling boundaries, downstream cleanup owners, and targeted open Binaryen residuals?

## Source refresh

Commands and local artifacts:

- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- Downloaded Binaryen `version_130` primary sources into ignored local artifacts under `.tmp/ls-source-refresh-20260704/`:
  - `src/passes/LocalSubtyping.cpp` (`191` lines)
  - `test/lit/passes/local-subtyping.wast` (`608` lines)
  - `src/ir/local-structural-dominance.h` (`94` lines)
- Downloaded the corresponding `version_129` files and diffed them against `version_130`; the diffs were empty for all three files.

Durable source result: the earlier `version_129` dossier remains source-current for the installed `version_130` Binaryen oracle. The important upstream contract is unchanged: collect set/get sites for reference locals, compute LUBs from assigned values, gate non-null declarations with `LocalStructuralDominance`, rewrite body locals only, retag `local.get` and `local.tee` expression types, and repeat with `ReFinalize()` until stable.

## Behavior-family matrix

| Family | Binaryen v130 source/lit signal | Starshine status | Classification | Reopening / next action |
| --- | --- | --- | --- | --- |
| Reference-local scan, assignment LUB, body-local rewrite | `LocalSubtyping.cpp` scans reference locals, records sets/tees and gets, and rewrites locals from `getVarIndexBase()` onward. The lit file covers simple locals, mixed assignments, params, and no-assignment locals. | Implemented for reference-typed body locals. Params remain ABI/signature-owned and are guarded by focused tests. | Implemented/protected for active v0.1.0 scope. | Reopen only for a reduced direct mismatch showing wrong heap/nullability LUB or an accidental parameter rewrite. |
| Non-reference / tuple / nondefaultable locals | Binaryen lit preserves tuple/nondefaultable cases instead of rewriting them into invalid local declarations. | Starshine candidate selection only accepts single reference value types and skips other value classes. | Implemented as a conservative no-rewrite boundary. | Reopen only if Binaryen v130+ starts rewriting a non-reference or tuple shape that Starshine can safely represent. |
| Straight-line and same-scope non-null dominance | Source uses `LocalStructuralDominance` to allow non-null only when gets are structurally dominated by sets. Lit covers `become-non-nullable` and `already-non-nullable`. | Implemented and guarded by red-first straight-line tests, including `local.tee` assignment evidence and early-get nullable fallback. | Implemented/protected. | Reopen on validation failure or direct mismatch where every get is syntactically dominated in the same emitted scope. |
| Unnamed-block and branch-free structured dominance | `local-structural-dominance.h` explicitly says unnamed blocks can be ignored because they are not emitted, and lit has `become-non-nullable-block-unnamed`. | Implemented for branch-free blocks, branch-free block write post-state, branch-free loop-entry dominated gets, nested branch-free if arms, and root branch-free if dominated-entry gets. | Implemented/protected for the source-backed subsets. | Reopen only for a reduced unnamed/block/loop/if case whose dominance does not rely on branch/EH/handler post-state beyond the current subsets. |
| Named blocks, branch-skipped writes, loop writes, all-arm if writes, and try-body writes before outside gets | Binaryen lit keeps named-block or possibly-default gets nullable. Local v130 probes recorded in prior LS slices keep branch-skipped writes, branch-flow block post-state, loop post-state, all-arm if post-state, and try-body post-state nullable or signature-preserving. | Starshine has focused nullable fallback guards for these families. | Source/probe-backed nullable boundaries, not Starshine wins and not hidden broad gaps. | Reopen only with a v130+ source/lit/probe showing Binaryen narrows a specific post-state family that Starshine still keeps nullable. |
| Terminal branch / return / tail-call / throw dominated-get slices | Binaryen v130 probes from the recursive LS slices show non-null narrowing when gets are dominated before terminal `br`/`br_table`, root/block `return`, `return_call*`, `throw`, `throw_ref`, and already-dominated unreachable-tail gets. | Implemented for the documented terminal/path-skip/unreachable-tail subsets without propagating branch-carried writes to unsafe outer post-state. | Implemented/protected narrow subsets. | Reopen for a reduced terminal-control direct mismatch, or if the case needs post-state propagation rather than dominated gets before non-propagating terminal control. |
| `try_table` body dominated gets and body terminal tails | Binaryen lit only covers catch-result type preservation, but v130 probes from prior LS slices show body dominated-get and body terminal/tail subsets narrow. | Implemented for copied try-body dominated gets, terminal body `return`/`throw`/`throw_ref`/`return_call*`, and non-final body terminal tails whose later gets are already dominated. Try-body writes are not propagated outward. | Implemented/protected for body-local subsets; post-state remains nullable. | Reopen for a reduced body-only dominated-get mismatch; route handler/catch post-state separately. |
| EH catch/ref handler and handler post-state flow | Binaryen lit has `try_table-catch-result` and `try_table-ref` to avoid over-refining block result types in catch paths; current Starshine LS docs do not have focused local-declaration catch-ref/catch-all-ref handler-flow probes. | Not widened. Existing implementation only scans the try body, not handler payload/control-flow state. | Targeted open source/probe gap, no longer a broad hidden EH bucket. | Next LS slice should probe `catch_ref`/`catch_all_ref` local writes/gets and either add red-first coverage for a safe subset or document a source-backed nullable boundary. |
| Direct block-return nondefaultable-local unreachable-tail family | Prior v130 probes show Binaryen can narrow a direct block-write-then-return shape, but Starshine validation cannot yet prove the later unreachable get safe after non-defaultable local narrowing. | Starshine deliberately keeps the direct block-return post-state/unreachable-tail family nullable. | Precise validator/tooling blocker, not a Starshine win. | Reopen when Starshine validation models Binaryen's unreachable nondefaultable-local proof, or if a reduced case validates today and still mismatches. |
| `local.get` / `local.tee` expression retagging after declaration rewrite | `LocalSubtyping.cpp` explicitly updates all gets to the new declaration type and updates/finalizes tees. The lit file has unreachable get/tee and parent-expression cases. | Starshine rewrites body-local declarations and has focused validation that current tee narrowing is accepted, but it does not implement broad explicit expression retagging. | Real source-backed residual, not proven Starshine win. It is precise, not broad: declaration changes validate in current protected cases, but expression-type repair remains unported. | Add targeted red-first tests around unreachable `local.get` / `local.tee` parent expression typing and implement representation-aware retagging, or document why the current IR has no separate stale expression type to repair. |
| Iterative refinalization / reanalysis | `LocalSubtyping.cpp` calls `ReFinalize()` inside a do/while; lit has `refinalize`, `multiple-iterations-refinalize`, `multiple-iterations-refinalize-call-ref`, and bottom-call-ref coverage. | Starshine runs one assignment collection and rewrite pass and does not iterate after declaration changes. | Real source-backed residual, not a Starshine win. | Add a reduced red-first repeated-refinement test, especially a `call_ref` or select/block LUB shape where the first local narrowing sharpens a second local assignment. |
| Direct GenValid / wasm-smith residual | Direct GenValid has no LS mismatch. The sole raw wasm-smith mismatch is pass-independent `drop(unreachable)` cleanup debris and is size-losing for Starshine. | Cleanup-normalized with `--normalize unreachable-control-debris`. | Shared unreachable-control cleanup / normalizer blocker, not LS semantic behavior. | Reopen under LS only if the reduced case depends on LS narrowing, dominance, retagging, or refinalization. |
| Ordered GC/local neighborhood residual | The ordered `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` lane cleanup-normalizes under `local-cleanup-debris`. | Routed to downstream local-cleanup representation owners. | Downstream representation/tooling debt, not LS semantic behavior and not a Starshine win. | Reopen under LS only for a reduced case tied to LS-owned narrowing, dominance, retagging, refinalization, or reference-local interaction with `heap2local`/`optimize-casts`. |

## Conclusion

The behavior-family review is now complete enough to replace the previous broad LS blocker list with a precise residual list.

Closed or protected for the active v0.1.0 direct-pass/`-O4z` audit scope:

- body-local assignment LUB narrowing and parameter preservation;
- conservative non-reference / nondefaultable no-rewrite handling;
- straight-line, unnamed/branch-free structured, terminal-control, root unreachable-tail, and try-body dominated-get subsets already covered by focused tests and required-size generated evidence;
- source/probe-backed nullable post-state fallbacks for named/branch-flow/block-skip/loop/if/try-body writes;
- cleanup-normalized direct wasm-smith and ordered-neighborhood residual routing.

Still open and therefore LS is not finally closed in this slice:

1. broad explicit `local.get` / `local.tee` expression retagging after declaration narrowing;
2. iterative refinalization/reanalysis after one narrowing exposes sharper assigned value types;
3. focused EH catch-ref/catch-all-ref handler and handler post-state local-flow probes/classification;
4. the direct block-return nondefaultable-local unreachable-tail validator/tooling boundary.

No remaining residual should be described as a measured Starshine win. The two cleanup residuals are normalized/routed blockers, the direct block-return family is a tooling blocker, and retagging/refinalization are source-backed unimplemented Binaryen behavior that need targeted implementation or a representation-specific proof before closeout.

## Validation

No Moon or compare lanes were rerun in this slice because it changed documentation/research only and did not alter code, generator behavior, or pass scheduling. Source refresh used primary Binaryen `version_130` files and local diff checks against `version_129`; the existing 2026-07-03/2026-07-04 LS direct and ordered evidence remains current for the unchanged binary.
