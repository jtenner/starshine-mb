---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ./1646-2026-07-17-ssa-nomerge-batch-writeback.md
  - ./1584-2026-07-13-daeo-scheduled-mode-specific-blockers.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../tests/repros/daeo-rub-func3397-multivalue-carrier.wasm
---

# RemoveUnusedBrs batch writeback and validity close the direct DAEO-prefix owner

## Scope

This slice follows note `1646`'s public-prefix attribution. It closes the direct current-artifact `remove-unused-brs` runtime owner without accepting the initially exposed invalid output, preserves the pass's trap/effect/control boundaries, and reattributes the earliest remaining public shrink owner.

Input:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- `3204405` bytes.

The DAEO implementation, optimizing-only scheduling, exact late slot, and plain-DAE separation are unchanged.

## Initial direct owner and first validity failure

Fresh pre-change direct evidence used the explicit note-`1646` native executable at SHA-256 `34a21a0bfba0c86520635429047ef8fb4cc0d32f50b0ff060b5d10327d04d680`.

Artifacts: `.tmp/daeo-public-blockers-20260717/direct-remove-unused-brs-before-batch/`.

Direct `--remove-unused-brs --tracing pass` completed only after:

- wall `580.178s`;
- user `577.444s`;
- `7779` pass timer events;
- only `510088us` of summed pass-local work in the original attribution run;
- `4234` mutation traces.

The output was `3188584` bytes with SHA-256 `c5879f4edaf05a5ce87af484f1f2f9cbe3db55856007cafcd926cc2c5dadc60a`, but it was invalid under `wasm-tools validate`: defined Func `3397` left values on the stack at the end of a block.

This invalidity forbade a naive validation-only optimization. The runtime owner was repeated per-function writeback validation, but batch validation could land only after the invalid transform families were locked red-first and made fail-closed.

## Func 3397: multivalue carrier reassociation

The selected function was extracted to `.tmp/daeo-public-blockers-20260717/rub-func3397/`. Its input validates; Starshine's old direct output does not; Binaryen-v130's direct output validates.

The invalid Starshine diff removed local carrier stores/tees around a multivalue result block and left the outer block/drop path with the wrong stack shape. A smaller hand-authored carrier did not reproduce the final invalidity by itself, so the exact extracted witness is checked in as:

- `tests/repros/daeo-rub-func3397-multivalue-carrier.wasm`;
- size `76103` bytes;
- SHA-256 `1a3046a5c927354400e8dd2ab0366baf10ca52d6dc1b740f5a6752cfc346bcf4`.

Red-first focused coverage requires the pass to preserve multivalue result regions whose root sequence feeds local carriers. The retained HOT guard:

- traverses both control regions and expression children, fixing the old guard's inability to see a result block nested under `drop`, `local.set`, or another expression node;
- rejects a result region when it has root `local.set` traffic and either multiple results or an existing stack-effect hazard;
- emits `result-local-set-stack-hazard-noop`;
- leaves the exact Func `3397` witness byte-identical and valid.

This is a conservative correctness boundary, not a claim that Binaryen cannot optimize the family.

## Func 6649: nullable return bypassing a non-null result region

After the Func `3397` guard, direct output exposed a second external-validator failure at defined Func `6649`: a block required a non-null reference result, but the rewritten fallthrough produced a nullable reference.

The extracted family is under `.tmp/daeo-public-blockers-20260717/rub-func6649/`. The key source shape is:

- an enclosing block returns a non-null reference;
- an inner value `if` can produce a nullable reference on its fallthrough path;
- a `return` immediately after that `if` legally bypasses the stricter block result and exits through the function's nullable result type;
- removing that `return` forces the nullable value through the non-null block result and invalidates the function.

A red-first hand-authored WAT regression reproduces the same legality boundary. The retained HOT guard is deliberately narrow:

- it tracks whether traversal is inside a single-result non-null reference control region;
- it activates only when the function itself has a single nullable reference result;
- a nested `return` then forces `return-bypasses-result-type-noop`;
- integer, multivalue, and same-result-type return cleanups continue to run, as protected by the existing full RUB test file.

The extracted Func `6649` module now validates after direct RUB; selected Func `0` emits the new skip reason.

## Giant `br_table` convergence boundary

The first retained batch/valid artifact was deterministic for a fixed input but repeated direct applications did not converge. After size stabilized, each invocation still rewrote one giant `br_table` target vector in defined Func `7353`; WAT diffs showed only repeated label-target reshaping among a table with more than 250 destinations.

A red-first boundary test builds a 129-target table. The retained guard:

- traverses the complete HOT tree once with a seen set;
- preserves any `br_table` with at least `128` explicit targets;
- emits `giant-br-table-convergence-noop`.

The current artifact reports this skip only three times. The rule prevents representation-only target churn while leaving the existing small and medium table rewrite/parity surface intact.

## Batch writeback repair

The new white-box test first referenced `run_hot_pipeline_remove_unused_brs_repair_batch_writeback(...)` and failed to compile because the helper did not exist.

The retained pass-manager path:

1. runs RUB once per function exactly as before;
2. defers only the expensive per-function module-context validation;
3. builds the final candidate code section;
4. collects every changed defined function;
5. validates the changed batch once against the candidate module context;
6. restores each internally invalid candidate independently and emits `skip-invalid-lower` with `writeback-batch-validate` evidence;
7. falls back to the original per-function path if batch validation itself cannot return a result.

The candidate module is the validation context intentionally. RUB changes function bodies but not function signatures or type definitions. The external Func `3397` and Func `6649` checks remain necessary because the current internal validator did not reject every GC/multivalue invalidity exposed by the large artifact.

## Final direct artifact result

Authoritative final native executable:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `391fc0fd7acf112aa7b5a34b9c9138c857b71e1fbda576cf84638d2a176c961f`.

Artifacts: `.tmp/daeo-public-blockers-20260717/direct-remove-unused-brs-final2/`.

Two independent direct runs from the same input are byte-identical and valid:

- traced wall `3.239s`;
- untraced repeat wall `3.068s`;
- pipeline `2395030us`;
- changed-function batch validation `390153us`;
- `1136` final changed candidates;
- `83` internally invalid candidates restored independently;
- `7779` pass timer events summing to `283343us`;
- `1913` retained mutation traces;
- output size `3193120` bytes;
- output SHA-256 `bd27a23626de8626cbf89851a1b10b37b922c00768305236c679690644288f74`.

This reduces direct wall time by about `179x` (`580.178s -> 3.239s`) while replacing the old invalid output with a valid deterministic result.

Skip counts on the final traced artifact are:

- `result-local-set-stack-hazard-noop`: `4382`;
- `return-bypasses-result-type-noop`: `512`;
- `giant-br-table-convergence-noop`: `3`.

These counts are conservative safety accounting, not parity wins.

## Convergence

Repeated direct applications remain finite and externally valid:

| Application | Size | SHA-256 | Same as previous |
|---|---:|---|---|
| 1 | `3193120` | `bd27a23626de8626cbf89851a1b10b37b922c00768305236c679690644288f74` | n/a |
| 2 | `3193133` | `1603f0a7fa2bdca3fe92e5f54a148f28ff24a8dc692a9911bca89f34cf2596bb` | no |
| 3 | `3193127` | `850bfa95248df0b8dc25ecdcb49751cab4200310854a5898cabd7a3760bbf986` | no |
| 4 | `3193127` | `850bfa95248df0b8dc25ecdcb49751cab4200310854a5898cabd7a3760bbf986` | yes |

RUB therefore reaches a byte-identical fixed point after three productive applications. The giant-table boundary removes the prior unbounded same-size target-vector churn.

## Generated parity and runtime evidence

All final compare commands used:

- Binaryen `wasm-opt version 130 (version_130)` by prepending `.tmp/binaryen-v130-bin/binaryen-version_130/bin` to `PATH`;
- explicit final native Starshine binary;
- both `drop-consts` and `unreachable-control-debris` normalizers;
- `wasm-tools` external validation.

Regular GenValid:

- artifacts: `.tmp/pass-fuzz-remove-unused-brs-daeo-blocker-final-regular-10000-20260717/`;
- requested/compared `10000/10000`;
- normalized `1520`;
- cleanup-normalized `8480`;
- mismatches `0`;
- validation/generator/property/command failures `0`.

Dedicated `remove-unused-brs-all` runtime sample:

- artifacts: `.tmp/pass-fuzz-remove-unused-brs-daeo-blocker-final-dedicated-1000-runtime-20260717/`;
- compared `115/1000` before the existing `100`-failure cap;
- selected leaves `control=50`, `switch=48`, `cleanup=17`;
- mismatches `115`;
- validation/generator/property/command failures `0`;
- Node runtime checked `115/115`;
- equal results `89`;
- equal traps `26`;
- semantic mismatches `0`;
- sampled effects still exclude calls, memory/table/global mutation, exceptions, and atomics.

This is the exact already-approved note-`1392` side-effect-free dead-shell/control-debris family, now with all `115` sampled mismatches runtime-checked rather than only the prior smaller runtime subset. It is not reclassified merely because both outputs validate.

## Moon and API signoff

- red-first multivalue carrier test: failed on missing skip, then passed;
- red-first batch repair test: failed to compile on the missing helper, then passed;
- red-first nullable/non-null result-return test: failed on missing skip, then passed;
- red-first giant-table convergence test: transformed the table before the guard, then passed;
- `remove_unused_brs_test.mbt`: `223/223`;
- `pass_manager_wbtest.mbt`: `287/287`;
- `moon test src/passes`: `5449/5449`;
- full `moon test`: `8906/8906`;
- `moon fmt`: passed;
- `moon info`: passed with existing warnings;
- native release build: passed with existing warnings;
- no `.mbti` or public API change.

The unrelated formatter drift in `moon.mod` remains unstaged.

## Refreshed public owners

A fresh final-binary `--shrink --tracing pass` replay now reaches the post-SSA `dead-code-elimination` slot and times out after `120.011s` at absolute Func `729`:

- only `227` DCE pass events had run;
- summed DCE pass-local work was `36994us`;
- the trace spent almost all wall time outside pass-local timers.

This reattributes the earliest current shrink owner to repeated per-function DCE writeback validation, the same accounting class already repaired for SSA no-merge and RUB. A longer same-slice replay reached Func `7085` after `1200.016s` while summed DCE pass-local time was only `3018017us` over `2987` events.

Direct RUB itself is no longer the public-prefix blocker. Public shrink still does not reach the late DAEO slot because DCE now owns the earliest remaining validation wall.

The other independent note-`1646` owners remain open and were not changed by this RUB-only slice:

1. optimize: vacuum raw-preclean runtime;
2. shrink: DCE per-function writeback validation;
3. O4z: HSO pass-local hotspots led by Funcs `1004`, `445`, `1513`, and `60`.

## Decision

The direct remove-unused-brs owner is closed with red-first correctness guards, rollback-capable batch validation, external validity, deterministic repeated output, finite fixed-point convergence, regular generated parity, and dedicated runtime evidence.

DAEO itself remains directly closed at note `1645`'s canonical `+1494` endpoint. Release signoff is still blocked only by independent public pre-slot owners. The next bounded safe slice is DCE changed-function batch validation with the same requirements: preserve its existing nonvalidation guards, restore invalid candidates independently, fall back on batch failure, validate the current artifact externally, rerun generated parity, and then refresh public shrink attribution. Optimize vacuum and O4z HSO remain separate workstreams.
