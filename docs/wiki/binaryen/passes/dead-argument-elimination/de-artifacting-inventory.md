---
kind: workflow
status: working
last_reviewed: 2026-07-19
sources:
  - ../../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ./completion-matrix.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../dae-optimizing/starshine-strategy.md
---

# DAE and DAEO de-artifacting inventory

This page classifies production dependencies on selected definitions, numeric bands, fixed iteration limits, module/touched-size guards, and artifact-shaped cleanup. It is an implementation ledger, not permission to keep those paths indefinitely.

The baseline scan used:

```text
rg Func[0-9]+
rg selected_defs / selected_scratch_defs
rg numeric comparisons on def_idx, original_defined, touched_count, body size
manual review of dae_run_core and the DAE nested pass manager
```

The raw scan is preserved locally at `.tmp/dae-release-baseline-20260719/production-inventory.txt` and is intentionally not committed.

## Classification rules

1. **Generic DAE semantics** — must become a fact-driven recognizer/worklist path.
2. **Generic nested cleanup** — belongs to a shared optimizer pass/pipeline, not DAE boundary semantics.
3. **Optional artifact profitability** — may remain only when it cannot affect correctness and has measured benefit plus reopening criteria.
4. **Regression-only fixture** — retain the test/input but remove its production identity gate.
5. **Diagnostic normalization** — stays in compare tooling and never mutates pass output.
6. **Obsolete/unreachable** — delete after proving no production need.
7. **Narrow permanent boundary** — allowed only with source-backed safety/performance rationale and explicit reopening evidence.

## Selected-definition and identity-dependent production paths

| Production surface | Current examples | Category | Required disposition |
|---|---|---:|---|
| Large reverse exact-literal chain | the former fixed definitions `4593, 4592, 4591, 4589, 4588, 4587, 4586, 4584` are deleted from production; original-module identity and scalar allocation/store constructor shapes seed a monotone current-module per-slot uniform solver, which runs after forwarding-component work in DAEO and at the final broad plain-DAE boundary | 6 | fixed identity list removed; retain the artifact fixture and reopen only if a current exact forwarding/value-slice dependency cannot recover the same boundary |
| Low wrapper/callee boundary order | former fixed wrapper list `128, 131, 133, ... 196` removed; exact shifted-forward wrapper shapes now produce a deterministic duplicate-free callee order | removed | reopen only if a minimized wrapper shape is not represented by exact current call/type evidence |
| Exact parameter chain | former definitions `37, 38, 41`, touched-definition `164` trigger, and private prefix cleanup deleted; the ordinary direct-GC batch already discovers the same exact boundaries | removed | byte-identical artifact and focused broad-module behavior prove the private identity lane was obsolete; reopen only for a minimized generic direct-GC dependency miss |
| Early selected body cleanup | former definitions `233/236/237/256/267/268` all removed from production | removed | `233/256` match direct v131 preservation, `237` was dead policy, `236` uses generic nested cleanup, and `267/268` use monotone rewritten-callee constant-equality/if folding |
| Selected dropped-result fallbacks | former definitions `3566, 3732, 3814` are removed from production; exact fact-selected candidates now run through `DaeDroppedResultWork` with refreshed graph epochs | 6 | fixed fallback list deleted; retain fixtures and reopen only for a classified exact result-dependency gap |
| Selected unread-parameter fallback | former definitions `505`, `538`, and `3799` deleted; existing dependency/uniform waves already produce byte-identical artifact output | removed | reopen only for a minimized exact invalidation gap |
| Mid/high exact-literal lists | former mid list `267, 268, 287, 288, 311, 408, 428, 504, 505, 538, 869, 1777, 4206, 4368`, immutable-global `313`, and high list `1720, 1755, 1775, 1794, 2156, 3736, 3799, 4117, 4134, 4303, 4320` removed; broad semantic seeds now include single-parameter nontrapping pure expressions | removed | focused arbitrary-definition coverage plus byte-identical artifact; reopen only for a source-backed pure-expression shape not represented generically |
| Late selected cleanup | former definitions `311/313/323/327/408/1794` are identity-free | removed | global suffix uses one exact current caller whose body changed from the immutable original; all other late families use touched/dependency/shape evidence |
| Func-288 local map | fixed 118-slot bitmap remains characterization-only | removed from production | direct v131 preserves the exported fixture without a boundary change; production schedule deleted |
| Func-237 cleanup family | all definition-`237` production scheduling removed; `Func237`-named recognizers remain only as white-box characterization pending absorption into owning control/local passes | regression-only | current artifact is byte-identical and every deterministic suite stays green without any production call; do not re-enable by identity |
| Func-3737/3765 suffix bridge | exact definitions `3737/3765`, caller `281`, and hard-coded `i32.const 1024` helpers deleted | removed | generic forwarding/uniform and unread families already produce byte-identical artifact output; reopen only for a minimized exact dependency miss |
| Definition-505 special cleanup switch | former `def_idx == 505` control-cleanup switch removed; branch-safe rewritten-control simplification now applies uniformly after validated parameter rewrites | removed | focused/full validation and byte-identical artifact output; reopen only for a minimized generic cleanup regression |
| Zero-tee selected list | definitions `215, 260, 261, 1137, 1978` and the private split helper deleted | removed | Binaryen-v131 direct DAEO preserves the tee shape on arbitrary definitions, and the lane was unproductive on the current artifact; focused expectations now match the oracle |

No new production `FuncNNN` or fixed-definition gate may be added during DAE completion.

## Numeric windows and iteration policies

| Policy | Current value/shape | Category | Why it is not release closure | Replacement/reopening criteria |
|---|---|---:|---|---|
| Stable exact-callsite path threshold | total functions `<1024` | 7, temporarily | measured uncached path-resolution slowdown on the fixed artifact | cache containing scope, instruction index, and entry-stack arity; remove after artifact median is no worse than the prior caller scan |
| Optimizing computed retry | definitions `<1024`; former limit `defined * 2 + 1` removed | 1 | the small-module lane now uses exact-definition dependency requeue to exhaustion, but broad-module availability still depends on later lifecycle ordering | route broad candidates through the same queue after shared boundary/component phases; defensive budget may remain only as fail-closed telemetry |
| Forwarding component discovery | former maximum 8 components, 64 parameter nodes, 8 source-expansion rounds, 129-instruction search, and bounded sink/cycle retry loops removed | removed | monotonic node discovery, excluded-component accumulation, and parameter-count reduction provide finite convergence | reopen only if a minimized case demonstrates non-monotonic component growth or an independently measured defensive budget is needed |
| Small-module reverse loop | former `8`-iteration cap removed; exact-literal rewrites run until no productive candidate remains | removed | signature/parameter count decreases monotonically and every candidate is revalidated transactionally | reopen only for a minimized non-monotone case |
| Low forwarded-constant revisit | modules `<=4096`, first `4096`; former `64`-rewrite cap removed | 1 | cardinality gate/prefix remains, but admitted work now converges by no-progress | remove the remaining module window through common candidate scheduling |
| Broad nullable exact-literal lane | modules `>4096`, first `4096`, min 8 nullable params; former `64` productive cap removed | 1/3 | remaining prefix and nullable-count admission mix correctness/parity with artifact profitability | generic candidate discovery across exact dependency components; keep size heuristics only after correctness candidates are complete |
| Immutable-global revisit | modules `<=4096`, first `4096`, `64` rewrites | 1 | module-size correctness bypass | dependency queue and cached global facts |
| Large uniform constants | modules `>4096`, callee node count `>=64`, max `512` | 1/3 | useful prefilter, but cannot be the only correctness path | separate generic correctness queue from optional heavy-body profitability prioritization |
| Low caller/callee bands | caller prefix `64`, shifted range `64..128`; limits `14` and `21` | 1 | artifact-derived scheduling | explicit caller/callee and forwarding dependencies |
| Dropped-result dispatch | productive caps and the `8192` disablement removed; ascending through `4096`, descending above it remains | 1/2 | work is generic and finite, but ordering still depends on module cardinality | derive ordering from result dependencies rather than definition count |
| Selected const-if/body loops | bounds `2`, `4`, `8`, and other local fixpoint caps | 2/3 | acceptable only for local cleanup if omission is semantics-neutral; not acceptable for boundary correctness | move to owning pass; prove monotonic local rewrite or retain as optional profitability guard |
| Nested touched-set skip | broad `touched_count > 8` remains; small call-free functions with any removed local now enter isolated nested cleanup instead of requiring `>=16` removed locals | 2/3 | exact semantic admission closes the former Func236 gap without violating one-wave frontier; broad chunked/filterable shared pipeline still required |
| Nested function/module size skips | large function/local/control guards | 2/3/7 | some are validation safeguards, others broad performance proxies | classify each as correctness or performance; replace module-wide proxies with pass-local conservative bailouts |
| Material touched caller threshold | encoded body `>=2048` | 3 | may prioritize cleanup but cannot define touched semantics | keep only as optional heavy replay after all required cheap pipeline steps run |

## Other classified surfaces

### Category 4: regression-only fixtures

The retained startup-map/debug artifact and historical Func-specific WAT/body fixtures remain valuable. They must stop selecting production behavior. A fixture is complete when a non-artifact focused test proves the generic recognizer and the original artifact continues to pass through the same path.

### Category 5: diagnostic normalization

`drop-consts` and `unreachable-control-debris` remain compare-harness normalizers only. They do not justify mutating plain DAE with optimizing cleanup, hiding effect/trap/control differences, or relabeling an unmeasured mismatch as safe.

### Category 6: obsolete/unreachable candidates

The dropped-result `8192` disablement and its unreachable inner branch are removed; current-fact candidate waves now run at every module size. Definition `3799` is also gone from production with the selected unread list.

### Category 7: narrow boundaries

The current call-free `try_table` liveness admission and conservative barriers around call-throw edges, legacy `try`, continuations, unknown indirect/reference callers, and indirect/reference tail calls are safety boundaries rather than artifact selections. They may remain fail-closed until the corresponding CFG/type relation is implemented, but each needs a focused negative test and reopening condition.

## Closure rule

The de-artifacting ledger is closed only when:

- no boundary-changing correctness path depends on a definition number, index window, module-size bucket, or arbitrary productive-attempt cap;
- every retained numeric guard omits only optional cleanup/profitability work;
- every retained guard is named in trace/diagnostics as correctness or performance policy;
- original artifact fixtures remain as regressions but exercise generic code;
- selected-only rewrite and guard-skip diagnostic counters are zero on the final release matrices, except for explicitly documented optional profitability paths.
