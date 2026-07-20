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
| Early selected body cleanup | definitions `233, 236, 237, 256, 267, 268` | 2/4 | move reusable cleanup into shared passes; retain artifact fixtures as regressions |
| Selected dropped-result fallbacks | former definitions `3566, 3732, 3814` are removed from production; exact fact-selected candidates now run through `DaeDroppedResultWork` with refreshed graph epochs | 6 | fixed fallback list deleted; retain fixtures and reopen only for a classified exact result-dependency gap |
| Selected unread-parameter fallback | former definitions `505`, `538`, and `3799` deleted; existing dependency/uniform waves already produce byte-identical artifact output | removed | reopen only for a minimized exact invalidation gap |
| Mid/high exact-literal lists | former mid list `267, 268, 287, 288, 311, 408, 428, 504, 505, 538, 869, 1777, 4206, 4368`, immutable-global `313`, and high list `1720, 1755, 1775, 1794, 2156, 3736, 3799, 4117, 4134, 4303, 4320` removed; broad semantic seeds now include single-parameter nontrapping pure expressions | removed | focused arbitrary-definition coverage plus byte-identical artifact; reopen only for a source-backed pure-expression shape not represented generically |
| Late selected cleanup | definitions `287, 288, 298, 299, 311, 313, 408, 538, 867` and later selected lanes | 2/4 | shared local/control passes with touched filtering; fixtures stay |
| Func-288 local map | fixed 118-slot bitmap and explicit local-number groups | 2/4 | replace with generic liveness/coalescing evidence or remove the production rewrite |
| Func-237 cleanup family | numerous `Func237`-named recognizers and repeated selected scheduling | 2/4 | extract generic control/local transforms into owning passes; retain Func237 only as a regression artifact |
| Func-3737/3765 suffix bridge | exact `def_idx == 3765`, dependency on definition `3737` | 1/4 | uniform-value forwarding/component recognizer; remove identity test |
| Definition-505 special cleanup switch | `def_idx == 505` | 2/4 | prove a generic result/control cleanup predicate or remove |
| Zero-tee selected list | `215, 260, 261, 1137, 1978` | 2/4 | shared SimplifyLocals/vacuum ownership |

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
| Dropped-result dispatch | `<=4096 => 32`, `<=4608 => 14`, else `8`, disabled above `8192` | 1 | correctness/parity depends on module cardinality | result dependency worklist with current-fact requeue |
| Selected const-if/body loops | bounds `2`, `4`, `8`, and other local fixpoint caps | 2/3 | acceptable only for local cleanup if omission is semantics-neutral; not acceptable for boundary correctness | move to owning pass; prove monotonic local rewrite or retain as optional profitability guard |
| Nested touched-set skip | `touched_count > 8` | 2/3 | suppresses required optimizing cleanup | chunked/filterable shared pipeline with per-pass rollback |
| Nested function/module size skips | large function/local/control guards | 2/3/7 | some are validation safeguards, others broad performance proxies | classify each as correctness or performance; replace module-wide proxies with pass-local conservative bailouts |
| Material touched caller threshold | encoded body `>=2048` | 3 | may prioritize cleanup but cannot define touched semantics | keep only as optional heavy replay after all required cheap pipeline steps run |

## Other classified surfaces

### Category 4: regression-only fixtures

The retained startup-map/debug artifact and historical Func-specific WAT/body fixtures remain valuable. They must stop selecting production behavior. A fixture is complete when a non-artifact focused test proves the generic recognizer and the original artifact continues to pass through the same path.

### Category 5: diagnostic normalization

`drop-consts` and `unreachable-control-debris` remain compare-harness normalizers only. They do not justify mutating plain DAE with optimizing cleanup, hiding effect/trap/control differences, or relabeling an unmeasured mismatch as safe.

### Category 6: obsolete/unreachable candidates

The dropped-result branch guarded by `original_defined > 8192` inside an enclosing `original_defined <=8192` block is unreachable and should be removed or restructured when the generic result worklist lands. Definition `3799` is documented historically as an unproductive selected entry yet remains in the selected unread list; it requires a focused no-production proof and deletion.

### Category 7: narrow boundaries

The current call-free `try_table` liveness admission and conservative barriers around call-throw edges, legacy `try`, continuations, unknown indirect/reference callers, and indirect/reference tail calls are safety boundaries rather than artifact selections. They may remain fail-closed until the corresponding CFG/type relation is implemented, but each needs a focused negative test and reopening condition.

## Closure rule

The de-artifacting ledger is closed only when:

- no boundary-changing correctness path depends on a definition number, index window, module-size bucket, or arbitrary productive-attempt cap;
- every retained numeric guard omits only optional cleanup/profitability work;
- every retained guard is named in trace/diagnostics as correctness or performance policy;
- original artifact fixtures remain as regressions but exercise generic code;
- selected-only rewrite and guard-skip diagnostic counters are zero on the final release matrices, except for explicitly documented optional profitability paths.
