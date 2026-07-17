---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/coalesce_locals.mbt
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ./1634-2026-07-17-daeo-func8186-stack-carried-literal-suffix.md
  - ./1633-2026-07-17-daeo-func8185-productive-cleanup-order.md
---

# DAEO Func 8185 conservative linear coalescing

## Goal

Continue the source-backed DAEO output-parity audit at defined Func `8185` / absolute Func `8206` after note `1634`, without accepting unexplained representation drift or retrying blanket local ordering / the rejected all-generic productive replay.

The accepted pre-slice endpoint was raw `3203392`, canonical `3264245`, and canonical-module gap `+1789` versus Binaryen v130. Func `8185` was the largest remaining direct body owner at canonical `2716` versus `2429` (`+287`). Its dominant visible residue was local copy traffic plus block/branch/unreachable shape.

## Attribution

Binaryen sends every DAE-changed function in `worthOptimizing` through filtered `OptUtils::optimizeAfterInlining(...)`. The default function pipeline contains `coalesce-locals` and later local cleanup. Note `1633` intentionally skipped the full generic replay on large productive intermediates after it cost `102574320us` and failed profitability.

Fresh canonical WAT inspection after note `1634` found the first exact remaining family at Func `8185`'s entry: same-typed values passed through long local-copy chains before later uses. Starshine retained `126` body locals and `265/110/16` local gets/sets/tees, while Binaryen retained `107` locals and `156/142/18`. This justified a bounded selected `coalesce-locals` subset, not another order pass.

## Red-first coverage

The public broad-high normalized-literal fixture now gives its large productive intermediate:

- `65` declared body locals;
- a same-typed local shuttle whose copy is separated from its producer by seven pure dropped constants;
- repeated later reads feeding the existing effectful `touch` / `sink` calls;
- the existing exact call counts, effect order, validation, convergence, and plain-DAE separation checks.

Before the retained implementation, optimizing DAEO left three body locals where the test requires one. Plain DAE still retains all `65` declared locals and its original parameter.

White-box pass-manager tests separately prove:

- the conservative selected helper merges a distant exact copy shuttle and removes one local;
- an early read of the destination blocks the merge and leaves the module unchanged.

## Rejected full selected coalescing probe

Running the full structured `coalesce-locals` adapter on the selected large intermediate was rejected:

- raw module: `3203430`, `+38` versus note `1634`;
- canonical module: `3264396`, `+151` versus note `1634`;
- Func `8185`: canonical `2835`, `+119` versus the pre-slice body;
- Func `8185` locals: `129`, worse than the pre-slice `126`;
- pass-local / wall: `98245785us` / `100.101s`.

Validity alone did not make that representation acceptable. The probe was fully superseded by the bounded linear subset.

## Retained implementation and safety

- Run only for large non-final productive definitions already owned by the broad-high exact-literal chain. Plain DAE and ordinary DAEO scheduling are unchanged.
- Reuse `coalesce-locals`' conservative linear fallback instead of dense structured coloring.
- Keep read locals distinct except for an exact same-typed one-set/one-get/no-tee copy-through chain.
- Require no destination access before the copy and no intervening structured or terminal boundary.
- Share only same-typed body-local slots that are written but never read; they cannot carry an observable local value.
- Preserve parameter indexes and compact/remap through the existing coalesce helper.
- Deep-clone the selected definition, validate the candidate, and roll back on failure.
- Retain strict selected-function encoded-size shrink as the normal gate. For a proven local-count reduction, allow equality but never encoded growth; this covers declaration-grouping ties while preserving raw non-regression.
- Continue the existing dead-write, structural cleanup, final access-frequency ordering, and selected-definition validation/profitability transaction afterward.

This is not permission for broad structured coloring or arbitrary local aliasing. The full selected coalescing probe was concretely size-losing and remains rejected.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-linear-coalesce-final-20260717/`.

- raw size: `3203257`, `-135` versus note `1634`;
- canonical size: `3264173`, `-72` versus note `1634`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1717`;
- raw SHA-256: `8c69133044eda59fcf43dd58a36b39125773e9fa8085e61d8844ec8e4a904bef`;
- canonical SHA-256: `33e666bad2c5239516397259e09a1483e618fd4296c66fee3f2203a6cd2060b0`;
- native SHA-256: `9bea4ab087d91d338dff2388a9603a3da505e5d0f52e36aad5fff68e33dddee8`.

Canonical body matrix:

| defined Func | note `1634` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2716` | `2644` | `2429` | `+215` |
| `8186` | `11` | `11` | `10` | `+1` |
| `8187` | `767` | `767` | `961` | `-194` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8185` improves by `72` canonical body bytes and its open gap falls from `+287` to `+215`. Declared locals fall from `126` to `101`; canonical local traffic becomes `241/86/16` gets/sets/tees. Binaryen still has materially fewer gets and control wrappers (`156/142/18`, `50` blocks, `38` branches, zero `unreachable`) than Starshine (`68` blocks, `47` branches, nine `unreachable`). That remaining `+215` is still a parity gap, not accepted representation drift.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 `--all-features -O0 --strip-debug` canonical form. Both raw and canonical outputs validate with `wasm-tools validate --features all`.

## Runtime accounting

The final uncontaminated run recorded `77548061us` pass-local / `79.353s` wall. This is about `5.2%` faster than note `1634`'s best retained `81795817us` trace and essentially tied with note `1633`'s `77550540us` endpoint while reducing another `72` canonical body bytes.

The converged second invocation is `4991916us` pass-local / `6.624s` wall.

The rejected full selected coalescing probe's `98245785us` pass-local result is preserved as evidence against broadening this slice.

## Validation

- red-first public fixture: failed before the retained implementation with `3 != 1` body locals;
- focused selected linear-coalescing white-box tests: `2/2`;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `271/271`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8887/8887`;
- native release build: passed with pre-existing warnings;
- first/second raw and canonical validation: passed;
- first/second raw and canonical `cmp`: byte-identical;
- dedicated profile `.tmp/pass-fuzz-dae-optimizing-func8185-linear-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular GenValid `.tmp/pass-fuzz-dae-optimizing-func8185-linear-regular-1000`: same result.

Both compare lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused slice smokes, not replacements for the full required four-lane closeout matrix.

## Remaining work

Func `8185` remains the next direct body owner at `+215`, now dominated by residual local-get traffic and `18` extra blocks, `9` extra branches, and `9` extra `unreachable` instructions relative to Binaryen. Continue from one exact source-backed control/local family; do not retry blanket local ordering, full selected structured coalescing, or the rejected all-generic replay without new evidence.

Func `8184 +16`, the full four-lane DAEO closeout matrix, and pre-slot public optimize/shrink/O4z blockers remain active.
