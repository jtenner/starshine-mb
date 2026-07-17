---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ./1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md
  - ./1646-2026-07-17-ssa-nomerge-batch-writeback.md
  - ./1645-2026-07-17-daeo-final-direct-closeout-matrix.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../tests/repros/daeo-dce-func62-result-control-self-branch.wasm
  - ../../../../tests/repros/daeo-dce-func3733-nested-struct-stack-builder.wasm
  - ../../../../tests/repros/daeo-rub-func3397-multivalue-carrier.wasm
---

# DCE batch writeback closes the public shrink validation owner

## Scope

This slice follows note `1647`'s public shrink attribution. It replaces repeated per-function `dead-code-elimination` writeback validation with rollback-capable changed-function batch validation, then closes every external-validator failure exposed by the current large artifact before reattributing public shrink.

Input:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- `3204405` bytes.

The direct DAEO endpoint from note `1645`, the optimizing-only DAEO/plain-DAE split, and the locked late public slot are unchanged.

## Red-first batch writeback

The initial white-box test referenced `run_hot_pipeline_dce_repair_batch_writeback(...)` and failed to compile because the helper did not exist.

The retained pass-manager path:

1. preserves DCE's existing original-function suspicious-carrier and large-local guards;
2. preserves changed-candidate invalid-escape-carrier and local-limit guards before deferring validation;
3. runs DCE once per function as before;
4. builds the final candidate module and collects only changed definitions;
5. validates that changed batch once against the candidate module context;
6. restores internally invalid definitions independently and emits `skip-invalid-lower` evidence;
7. falls back to the original per-function validation path if batch validation cannot produce a result.

DCE can change lowered bodies and may extend the type section through generic lowering preparation, so the final candidate module—not the original module—is the validation context.

## External validity failures and retained safety rules

The first batched direct run completed in `3.868s` but failed `wasm-tools validate --features all` at absolute Func `62`. Further externally validated iterations exposed Funcs `419`, `3397`, `3733`, `3852`, and `6404`. The internal changed-function validator did not reject all of these GC/multivalue stack failures, so batch validation alone was not accepted.

### Depth-aware control fallthrough

The raw DCE fallthrough predicate previously treated every terminating `br` inside a result block as making that block non-fallthrough. That is wrong when the branch targets the block's own label: the block completes and its declared results flow to the continuation.

A red-first white-box test now proves that a result block ending in `br 0` may fall through. The retained branch-depth scan accounts for self-targeting `br`, `br_if`, and `br_table` through nested control. This prevents the stack-polymorphic raw cleanup from voidifying typed `if` results whose arms still complete through result blocks. It closes the Func `62`, Func `419`, and Func `6404` families without moving effects, traps, branches, or payloads.

The reduced Func `62` witness is checked in as:

- `tests/repros/daeo-dce-func62-result-control-self-branch.wasm`;
- `1654` bytes;
- SHA-256 `95b42164179d006205e5f75c2c4caae913ad9d9546a3c116a2aca3671c59ab1a`.

Current direct DCE leaves it byte-identical and externally valid.

### Multivalue local-carrier boundary

The Func `3397` failure is the same extracted GC/multivalue carrier witness already used by note `1647`:

- `tests/repros/daeo-rub-func3397-multivalue-carrier.wasm`;
- `76103` bytes;
- SHA-256 `1a3046a5c927354400e8dd2ab0366baf10ca52d6dc1b740f5a6752cfc346bcf4`.

DCE could remove wrapper/dead-tail structure around a multivalue result immediately consumed by local carrier writes, after which HOT lowering left values on the stack. A strict red-first DCE test now preserves a source-backed multivalue result/local carrier shape. The raw guard resolves type-index block result arity through the module context and skips only functions containing a multivalue control result immediately drained by enough contiguous `local.set` / `local.tee` carrier writes.

The final artifact records `1855` `multivalue-local-carrier-dce-noop` skips. This is conservative safety accounting, not a Binaryen parity win. Regular and dedicated generated evidence below shows no sampled DCE behavior regression from this boundary.

### Unchanged HOT lowering must stay unchanged

Reduced Func `3733` showed a separate failure: DCE reported `changed=false`, but generic HOT lowering still rebuilt a flat GC constructor stack and produced an externally invalid function. The reduced witness is checked in as:

- `tests/repros/daeo-dce-func3733-nested-struct-stack-builder.wasm`;
- `1036` bytes;
- SHA-256 `e3e6a16a286f8c7ee35747977cdc3bf47004b068f2d9031e02104b8f091e693d`.

A red-first nested-struct stack-builder test first reached batch rollback. The retained rule now trusts DCE's unchanged result and returns the original function even if incidental HOT revision drift occurred. The existing narrow exception remains: a function with a proved dead `drop` after nonfallthrough control may still lower so the tested DCE dead-drop family survives. The full DCE test file proves that exception remains active.

Current direct DCE leaves the reduced Func `3733` witness byte-identical and externally valid. This same unchanged-function rule closes the Func `3852` family.

## Final direct artifact result

Authoritative fresh native executable:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `ddf228319e23af31a609bcbb6153950994db9e8ef28496617f59dcbb928be49a`.

Artifacts:

- `.tmp/daeo-public-blockers-20260717/direct-dead-code-elimination-final6/`.

Two independent direct runs from the original input are byte-identical and externally valid:

- traced wall `2.847s`;
- untraced repeat wall `2.471s`;
- pipeline `2049357us`;
- changed-function batch validation `359328us`;
- output size `3201864` bytes;
- output SHA-256 `cee196791f45a5bb3dc4b64e3cfdc251c367f2c2b2333c28486a947aec232ac2`.

Direct trace accounting:

- `3651` DCE pass timers totaling `399682us`, maximum `227376us`;
- `13152` raw DCE timers totaling `738574us`, maximum `367423us`;
- `162` HOT `changed=true` results and `3489` `changed=false` results;
- skip counts: `no-dce-candidates=5592`, `loop-outer-branch-dce-noop=1999`, `multivalue-local-carrier-dce-noop=1855`, `dce-stack-polymorphic-raw-cleanup=51`, `large-local-dce-noop=8`, and `result-control-tail-dce-noop=4`.

The initially invalid naive batch output is not retained as evidence of success. Only the final externally valid output above is authoritative.

## Convergence

Repeated direct applications are finite and externally valid:

| Application | Size | SHA-256 | Same as previous |
|---|---:|---|---|
| 1 | `3201864` | `cee196791f45a5bb3dc4b64e3cfdc251c367f2c2b2333c28486a947aec232ac2` | n/a |
| 2 | `3201696` | `bbd2f2b3ef6144095d17a88f694018958ce232c00a07da3b4047b581bd02c463` | no |
| 3 | `3201696` | `bbd2f2b3ef6144095d17a88f694018958ce232c00a07da3b4047b581bd02c463` | yes |

DCE therefore reaches a byte-identical fixed point after two productive applications. No same-size SHA churn remains.

## Binaryen-v130 generated evidence

All commands used Binaryen `wasm-opt version 130 (version_130)`, `--jobs auto`, and the explicit fresh native Starshine binary.

Regular GenValid with the documented DCE normalizer:

- artifacts: `.tmp/pass-fuzz-dce-daeo-blocker-regular-10000-20260717/`;
- requested/compared `10000/10000`;
- normalizer `local-cleanup-debris`;
- normalized `10000`;
- cleanup-normalized `0`;
- mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

Dedicated `dead-code-elimination-all`:

- artifacts: `.tmp/pass-fuzz-dce-daeo-blocker-dedicated-10000-20260717/`;
- requested/compared `10000/10000`;
- normalized `7513`;
- mismatches `2487`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- selected-profile counts are unchanged from the established DCE closeout corpus.

Agent classification of the `2487` mismatches is exactly the pre-existing measured Starshine-win set:

- `842` branch-payload-forwarder wrapper cleanups;
- `825` structured-prefix pure-dead-value cleanups;
- `820` effectful-structured-prefix cleanups that preserve the sampled effects/traps.

All `809` split-local-set-wrapper cases still match Binaryen. No new mismatch family, size-losing generated family, validation failure, or true semantic mismatch was introduced by the batch/safety slice.

## Public shrink reattribution

Artifacts:

- `.tmp/daeo-public-blockers-20260717/public-shrink-after-dce-batch/`.

A fresh explicit-final-binary `--shrink --tracing pass` run passes SSA no-merge, DCE, and remove-unused-brs, then times out after `600.011s` in `vacuum` raw preclean work:

- DCE batch validation completes in `397703us`;
- the trace reaches repeated `pass[vacuum]:skip-raw reason=raw-vacuum-guarded-hazard`;
- `103` such vacuum hazard traces are emitted before timeout;
- DAEO does not start;
- no output artifact is produced.

DCE is therefore no longer the public shrink blocker. Public shrink now shares the independently reproduced pre-DAEO `vacuum` owner already blocking public optimize. O4z remains separate in true HSO pass-local hotspots led by Funcs `1004`, `445`, `1513`, and `60`.

## Moon and API status

Red-first evidence:

- missing DCE batch repair helper compile failure;
- result-control self-branch fallthrough assertion failed before depth-aware fallthrough;
- multivalue local-carrier preservation failed before the raw boundary;
- nested struct stack-builder test reached invalid-candidate rollback before unchanged DCE returned the original function.

Passing focused evidence before final full signoff:

- `dead_code_elimination_test.mbt`: `65/65`;
- DCE-filtered `pass_manager_wbtest.mbt`: `3/3`;
- direct artifact/repeat/convergence and all three extracted safety witnesses validate externally;
- no `.mbti` or public API diff.

The unrelated `moon.mod` formatter drift remains unstaged.

## Decision

The DCE per-function validation owner is closed with strict red-first coverage, candidate-context batch validation, independent invalid-function rollback, fallback, external validation, finite convergence, and generated parity protection.

The DAEO release audit remains incomplete. Direct DAEO closeout stays valid at note `1645`'s raw `3203060`, canonical `3263950`, accepted `+1494` endpoint with both DAE normalizers. Remaining public pre-slot owners are now:

1. optimize and shrink: shared `vacuum` `raw-vacuum-guarded-hazard` preclean runtime;
2. O4z: HSO pass-local hotspots.

The next bounded slice should analyze and accelerate the shared vacuum owner without weakening its existing branch/control/effect/trap guards, then rerun optimize and shrink to the locked late DAEO slot. O4z HSO remains a separate follow-up.
