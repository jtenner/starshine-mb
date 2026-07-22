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
| Stable exact-callsite path threshold | removed | removed | inactive direct-call facts now select the scope-aware collector at every module size; a 1,024-definition regression proves mandatory unreachable-tail repair remains valid when the call signature changes | reopen only if exact scope lookup itself becomes a measured hotspot; module cardinality must not return as value-legality evidence |
| Optimizing computed retry | definitions `<1024`; former limit `defined * 2 + 1` removed | 1 | the small-module lane now uses exact-definition dependency requeue to exhaustion, but broad-module availability still depends on later lifecycle ordering | route broad candidates through the same queue after shared boundary/component phases; defensive budget may remain only as fail-closed telemetry |
| Unread-parameter batch acceleration | production invocation at definitions `>=1024`; candidate construction itself has no definition threshold | 3 | the common scalar worklist remains authoritative at every size, so skipping this batch omits no required boundary change; unrestricted early invocation preempted established grouped-type and selected-control cleanup order in compact DAEO tests | replace the acceleration threshold only after exact phase/profitability evidence preserves those source-backed products; the skip is reason-coded as optional |
| Dropped-result batch acceleration | production invocation at definitions `>=1024`; candidate construction itself has no definition threshold | 3 | exact result-observer work remains available through the ordinary dispatcher at every size, so the batch is acceleration rather than legality; a compact white-box fixture proves candidate construction below the threshold | replace the acceleration threshold only after phase/profitability evidence shows unrestricted early batching preserves established DAEO products; the skip is reason-coded as optional |
| Forwarding component discovery | former maximum 8 components, 64 parameter nodes, 8 source-expansion rounds, 129-instruction search, and bounded sink/cycle retry loops removed | removed | monotonic node discovery, excluded-component accumulation, and parameter-count reduction provide finite convergence | reopen only if a minimized case demonstrates non-monotonic component growth or an independently measured defensive budget is needed |
| Small-module reverse loop | former `8`-iteration cap removed; exact-literal rewrites run until no productive candidate remains | removed | signature/parameter count decreases monotonically and every candidate is revalidated transactionally | reopen only for a minimized non-monotone case |
| Low forwarded-constant revisit | modules `<=4096`, first `4096`; former `64`-rewrite cap removed | 3 | retained as an optional phase-order profitability replay; broad modules use exact call-target/value-slice collectors, while widening the legacy scan preempts Binaryen's one-wave frontier and changes established output families | reopen only with an exact seed set that preserves the one-wave frontier and does not regress the retained artifact median |
| Broad nullable exact-literal lane | every module size, full definition range, min 8 nullable params; former `4096` gate/prefix and `64` productive cap removed | 1/3 | only the nullable-count shape threshold remains as phase/profitability policy | replace threshold with measured dependency/value evidence if broader cases appear |
| Immutable-global revisit | every module size; exact immediate materializable call-target discovery | removed | the small all-definition `<=4096` wave and selected scan/mutate helper are deleted; each candidate enters epoch-bearing `DaeUniformActualWork` with original ownership, current facts, and producer effects | reopen only for a minimized exact immutable-global dependency miss |
| Large uniform constants | exact materializable call-target discovery at every module size | removed | the `>4096` split is gone; candidate legality is exact and no-change call facts are cached until the graph changes | reopen only for a source-backed missing value-slice family |
| Adjacent high-payoff local cleanup | former `4097..8199` pair band and preceding-eight root window removed | removed | exact call-sink uniform boundaries form the productive cross-phase root frontier; adjacent pair shape remains semantic | reopen only for a minimized missing dependency edge |
| Low caller/callee bands | former caller prefix `64` and shifted range `64..128` deleted | removed | full exact wrapper-shape callee order and ordinary dependency work already own the behavior byte-identically | reopen only for a minimized missing dependency edge |
| Dropped-result dispatch | ordinary/high-payoff caps, `8192` disablements, and `4096` ascending/descending split removed | removed | current exact callers order candidates caller-first; deterministic lowest-definition fallback is used only inside cycles | reopen only for a minimized ordering dependency gap |
| Local body fixpoints | terminal-family swap caps `4/9` and const-local cap `4` removed; remaining bounded modes are finite enumerations or characterization-only | mostly removed | each retained productive loop must consume an instruction pattern or be a finite mode enumeration | keep auditing helper-only caps separately |
| Nested touched-set skip | removed | removed | the arbitrary `touched_count > 8` omission no longer selects visible DAEO cleanup; bounded coverage proves ten touched definitions enter the shared `precompute-propagate`-first roster, while candidate validation remains authoritative | reopen only if a measured defensive budget can stop optional work without changing the semantic worth-optimizing set |
| Nested module / broad-cleanup function size policies | full-roster module-size skip removed; touched functions above 128 locals / 1,000 instructions previously skipped the roster too | 2 | module, local, and instruction cardinality no longer suppress semantic nested replay. Local/instruction checks remain only in the earlier broad changed-boundary fast-skip discriminator so oversized cleanup keeps transactional ownership before the roster. A 101-definition replay is green and the two prior literal/global regressions are confirmed Binaryen-v131 cleanup parity | migrate the broad-cleanup discriminator to exact candidate facts, then measure the retained artifact |
| Material touched caller threshold | encoded body `>=2048`, removed-local count `>=16`, or exact small call-free/folded evidence | 3 | retained only to select the expensive isolated nested replay after required cheap cleanup has run; it never controls boundary repair or validity | reopen when pass-local cost is low enough to run the full roster on every changed body without losing the accepted artifact median |

## Other classified surfaces

### Category 4: regression-only fixtures

The retained startup-map/debug artifact and historical Func-specific WAT/body fixtures remain valuable. They must stop selecting production behavior. A fixture is complete when a non-artifact focused test proves the generic recognizer and the original artifact continues to pass through the same path.

### Category 5: diagnostic normalization

`drop-consts` and `unreachable-control-debris` remain compare-harness normalizers only. They do not justify mutating plain DAE with optimizing cleanup, hiding effect/trap/control differences, or relabeling an unmeasured mismatch as safe.

### Category 6: obsolete/unreachable candidates

The dropped-result `8192` disablement and its unreachable inner branch are removed; current-fact candidate waves now run at every module size. Definition `3799` is also gone from production with the selected unread list.

### Category 7: narrow boundaries

The current call-free `try_table` liveness admission and conservative barriers around call-throw edges, legacy `try`, continuations, unknown indirect/reference callers, and indirect/reference tail calls are safety boundaries rather than artifact selections. They may remain fail-closed until the corresponding CFG/type relation is implemented, but each needs a focused negative test and reopening condition.

## 2026-07-21 closure ledger

The current native binary is SHA-256 `100397722893a76c76a3d3eed486e38c60df932b4b73da36574d35d17112520f`. The retained predecessor artifact is `2,991,228` bytes, SHA-256 `ce58ad84dd0579421ad43c9439846fb9b772487e79a89f34f65b3f42fd58d4f6`.

Plain DAE now validates the artifact after a fail-closed local-projection fix: a removed slot that the exact body still reads cannot alias an unrelated local when cached use evidence says unread. Three productive runs are byte-identical at `2,991,169` bytes, SHA-256 `f7bbacf174d6b1edacddc3f60abef4a107b385b14f86fc5373d7c3e6ac025c72`, with median `85.329s`; three idempotent runs are byte-identical with median `64.277s`. Binaryen-v131 canonicalization gives Starshine `3,077,218` bytes versus Binaryen `3,086,888`, a `-9,670`-byte Starshine result. The canonical body ledger is `677 / +2,607` larger, `377 / -12,362` smaller, and `5,631` equal, net `-9,755`; only `17` bodies have extra locals, totaling `22`.

DAEO remains byte-identical at `2,991,168` bytes, SHA-256 `2a510c274cbf83958c2d98cbbc05edb3f507f5e32aac2d900c68529a59df6bbe`. Reusing epoch-stable large-uniform call facts until a commit and avoiding dependency-graph construction for an empty dropped-result set reduce the measured productive median from `47.956s` to `25.440s` and the idempotent median from `44.490s` to `21.475s`, with no output change.

The renewed direct DAEO comparison is raw Starshine `2,991,168` versus Binaryen `3,062,068` (`-70,900`). After Binaryen-v131 canonical re-encoding, Starshine is `3,077,203` and Binaryen is `3,072,885` (`+4,318`): type `+90`, function `+9`, code `+4,219`, custom `0`. The canonical body ledger is `802 / +15,626` larger, `267 / -11,435` smaller, and `5,616` equal, net `+4,191`. The leading current positive definitions are `4254 +1,574`, `4256 +1,194`, `367 +502`, `4311 +470`, `6648/6650 +445`, `296 +443`, `5725 +368`, `3252 +319`, and `4255 +286`. They correlate with the shared nested local-layout/remap gap: DAEO has `126` extra-local bodies totaling `2,538` locals and `1,054` function type-index differences. Plain DAE is already canonically `9,670` bytes smaller, while Binaryen's optimizing suffix gains about `14KB` and Starshine's shared suffix gains only `15` bytes. Therefore the remaining gross-positive/remap family belongs to the shared `simplify-locals` / `coalesce-locals` / local-ordering scheduler implementations, not DAE boundary semantics; it remains visible under the neighboring-pass owner and must not be described as a DAE win.

Public `optimize`, `shrink`, and `-O4z` on the representative small fixture each execute DAEO exactly once after late RSE/vacuum and immediately before `inlining-optimizing`; all three emit the same externally valid 37-byte module. A targeted large late-prefix replay `heap-store-optimization -> redundant-set-elimination -> vacuum -> dae-optimizing` completes in `28.258s`, validates externally, and emits `2,950,277` bytes, SHA-256 `83b10590ed50fa139b83233698f9a34e9c58b2ca64d16eb32ee673803b034db3`. The full large `-O4z` command does not reach DAEO within 1,800 seconds; its trace is still inside the earlier `simplify-locals-nostructure` slot at function 459, so that wall-time blocker is explicitly non-DAE-owned.

## Closure rule

The de-artifacting ledger is closed only when:

- no boundary-changing correctness path depends on a definition number, index window, module-size bucket, or arbitrary productive-attempt cap;
- every retained numeric guard omits only optional cleanup/profitability work;
- every retained guard is named in trace/diagnostics as correctness or performance policy;
- original artifact fixtures remain as regressions but exercise generic code;
- selected-only rewrite and guard-skip diagnostic counters are zero on the final release matrices, except for explicitly documented optional profitability paths.

The 2026-07-21 evidence closes this ledger for DAE boundary semantics. The remaining canonical-positive family is explicitly retained under the shared neighboring local-cleanup passes, not hidden or offset against DAE's aggregate wins.
