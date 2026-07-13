# 1568 - O4z backlog reconstruction

_Date:_ 2026-07-13

_Status:_ current backlog audit

_Scope:_ Binaryen `version_130` top-level `-O4 --shrink-level 4` path, Starshine public preset expansion, direct-pass status, and the active work that belongs in `agent-todo.md`.

## Question

Which Binaryen O4z pass owners still require implementation, behavior-parity work, modern closeout evidence, or scheduler integration, and which completed audit diaries should be removed from the active backlog?

## Sources reviewed

- `AGENTS.md`
- `docs/README.md`
- `.pi/skills/starshine-pass-implementation/SKILL.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- pass owner files and living pass dossiers under `docs/wiki/binaryen/passes/`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `docs/wiki/raw/research/0714-2026-06-07-o4z-behavior-parity-inventory.md`
- current closeout notes through `1567`

Local oracle and artifact:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)

BINARYEN_PASS_DEBUG=1 wasm-opt \
  _build/wasm/debug/build/cmd/cmd.wasm \
  --all-features -O4 --shrink-level 4 \
  -o .tmp/o4z-backlog-audit/binaryen-o4-shrink4.wasm \
  > .tmp/o4z-backlog-audit/binaryen-o4-shrink4.log 2>&1
```

The command completed and printed 56 top-level passes. This is a scheduler inventory, not new semantic closeout evidence for every pass.

## Current Binaryen v130 O4z top-level path

1. `duplicate-function-elimination`
2. `remove-unused-module-elements`
3. `memory-packing`
4. `once-reduction`
5. `global-refining`
6. `remove-unused-module-elements`
7. `gsi`
8. `ssa-nomerge`
9. `flatten`
10. `simplify-locals-notee-nostructure`
11. `local-cse`
12. `dce`
13. `remove-unused-names`
14. `remove-unused-brs`
15. `remove-unused-names`
16. `optimize-instructions`
17. `heap-store-optimization`
18. `pick-load-signs`
19. `precompute-propagate`
20. `code-pushing`
21. `tuple-optimization`
22. `simplify-locals-nostructure`
23. `vacuum`
24. `reorder-locals`
25. `remove-unused-brs`
26. `heap2local`
27. `merge-locals`
28. `optimize-casts`
29. `local-subtyping`
30. `coalesce-locals`
31. `local-cse`
32. `simplify-locals`
33. `vacuum`
34. `reorder-locals`
35. `coalesce-locals`
36. `reorder-locals`
37. `vacuum`
38. `code-folding`
39. `merge-blocks`
40. `remove-unused-brs`
41. `remove-unused-names`
42. `merge-blocks`
43. `precompute-propagate`
44. `optimize-instructions`
45. `heap-store-optimization`
46. `rse`
47. `vacuum`
48. `dae-optimizing`
49. `inlining-optimizing`
50. `duplicate-function-elimination`
51. `duplicate-import-elimination`
52. `simplify-globals-optimizing`
53. `remove-unused-module-elements`
54. `string-gathering`
55. `reorder-globals`
56. `directize`

This confirms the historical 56-slot generated-artifact roster against the current local `version_130` oracle.

## Current Starshine public preset

`src/passes/optimize.mbt` currently expands both `optimize` and `shrink` to 51 passes, including the intentional Starshine-only final `strip-debug` pass.

Compared with Binaryen v130 O4z, the preset has these material differences:

| Difference | Current status |
| --- | --- |
| Missing second early `remove-unused-module-elements` after `global-refining` | Scheduler gap; direct RUME is closed. |
| Missing `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude | `flatten` is removed/unimplemented; SLNNS is direct-only; the extra LCSE slot is absent. |
| Extra early `vacuum -> remove-unused-brs` before `optimize-instructions` | Starshine-specific schedule difference; must be removed or justified by ordered-neighborhood evidence. |
| Both `precompute-propagate` slots are replaced by plain `precompute` | Public `precompute-propagate` is removed; only a private prefix helper exists. |
| Missing `merge-locals` after `heap2local` | Direct pass is active-partial and not preset-ready. |
| Missing `code-folding` | Direct pass is active but documented as a narrower subset and lacks preset proof. |
| Missing late `rse -> vacuum` | Direct RSE behavior/performance is closed; scheduling and final cleanup placement remain open. |
| Extra final `strip-debug` | Intentional Starshine extension; keep, but measure artifact impact separately. |

## Unique pass-owner status

There are 38 unique pass owners in the 56-slot path.

| Pass | O4z status for backlog purposes |
| --- | --- |
| `duplicate-function-elimination` | Direct behavior closed; both top-level slots scheduled. |
| `remove-unused-module-elements` | Direct behavior closed; second early slot missing. |
| `memory-packing` | Closed. |
| `once-reduction` | Closed. |
| `global-refining` | Closed. |
| `global-struct-inference` / `gsi` | Closed for ordinary GSI. |
| `ssa-nomerge` | Closed; full sibling `ssa` remains separate non-O4z work. |
| `flatten` | **Unimplemented/removed.** |
| `simplify-locals-notee-nostructure` | Direct pass implemented; no modern pass-specific closeout profile/matrix; unscheduled. |
| `local-cse` | Direct behavior closed; aggressive prelude slot missing. |
| `dead-code-elimination` / `dce` | Closed. |
| `remove-unused-names` | Closed. |
| `remove-unused-brs` | Closed direct; Starshine has one extra preset slot to reconcile. |
| `optimize-instructions` | Closed under the 2026-07-12 maintained parity contract. |
| `heap-store-optimization` | Closed. |
| `pick-load-signs` | Behavior-closed on existing evidence, but **modern four-lane closeout remains open**. |
| `precompute-propagate` | **Public pass unimplemented/removed**; private prefix helper is not a direct/preset replacement. |
| `code-pushing` | Closed. |
| `tuple-optimization` | Closed with the accepted pass-local performance exception. |
| `simplify-locals-nostructure` | Closed with the accepted pass-local performance caveat. |
| `vacuum` | Direct behavior closed; preset placement differs and final slot is missing. |
| `reorder-locals` | Closed; three public slots are present. |
| `heap2local` | Closed. |
| `merge-locals` | **Active-partial**; broader LocalGraph-equivalent control-flow parity and preset proof remain open. |
| `optimize-casts` | Closed. |
| `local-subtyping` | Closed. |
| `coalesce-locals` | Closed for direct and checked O4z neighborhood scope. |
| `simplify-locals` | Closed. |
| `code-folding` | **Active narrow direct pass**; living docs still disclaim full Binaryen coverage and preset readiness. |
| `merge-blocks` | Closed for the current v0.1.0 behavior audit; current-source correction did not identify a concrete new mismatch. |
| `redundant-set-elimination` / `rse` | Direct behavior and 1x timing closed; preset slot missing. |
| `dae-optimizing` | **Active-partial and release-relevant.** Direct DAE remains raw-red; generic breadth and real touched-function nested cleanup remain open. |
| `inlining-optimizing` | Direct audit and 1x timing closed; exact nested roster still depends on shared scheduler prerequisites. |
| `duplicate-import-elimination` | Closed direct and scheduled. |
| `simplify-globals-optimizing` | Closed direct and scheduled. |
| `string-gathering` | Accepted direct/preset status; remaining decoder/performance ideas are non-blocking. |
| `reorder-globals` | Accepted direct/preset status. |
| `directize` | Accepted default direct/preset status; optional pass-arg breadth is deferred. |

## Active O4z implementation and closeout queue

The primary queue is finite:

1. implement `flatten`;
2. modern-close and schedule `simplify-locals-notee-nostructure` in the aggressive prelude;
3. expose and implement public `precompute-propagate`, including both top-level slots and nested use;
4. complete `merge-locals` beyond the current linear copy-retargeting subset;
5. finish full source-backed `code-folding` parity and schedule it;
6. complete `dae-optimizing`, especially generic direct behavior and touched-function nested cleanup;
7. run the final modern `pick-load-signs` four-lane matrix;
8. reconcile the exact 56-slot preset: second RUME, aggressive LCSE slot, extra early VQ/RUB removal or proof, late RSE/final VQ, aliases, feature gates, and exact order;
9. prove nested reruns for DAE, inlining, and SGO against the final representable function pipeline.

## Tertiary work retained

These are not additional pass implementations, but they remain relevant to O4z completion and should stay in a concise backlog:

- startup-map/runtime regression fixture and conservative-guard recovery;
- repeatable `json-as` artifact validation/runtime/size replay;
- `strip-debug` artifact-size measurement;
- whole-command wall-time attribution outside pass-local signoff;
- raw skip/gate boundary tests;
- DAE de-artifacting/genericization;
- self-opt compare normalization symmetry;
- full public `ssa` sibling work, clearly separated from the O4z `ssa-nomerge` slot.

## Backlog cleanup decision

`agent-todo.md` should no longer contain completed per-slice diaries for OI, HSO, TO, SLNS, RUB, DCE, coalesce-locals, local-subtyping, reorder-locals, heap2local, inlining-optimizing, SGO, DIE, or other closed audits. Durable evidence belongs in the pass dossiers, research notes, wiki log, and git history.

The rebuilt backlog should contain:

- the 38-pass status ledger above;
- only the nine primary O4z work slices;
- concise tertiary O4z support work;
- concise explicitly deferred future-release work.

## Limits of this audit

- The current Binaryen command proves top-level order on the generated `cmd.wasm`; it does not independently sign off every pass.
- Closed/open judgments use current committed source and living docs, including explicit accepted exceptions and reopening criteria.
- Current-main drift beyond Binaryen `version_130` is not automatically a v0.1.0 blocker unless a pass dossier identifies a concrete behavior change.
