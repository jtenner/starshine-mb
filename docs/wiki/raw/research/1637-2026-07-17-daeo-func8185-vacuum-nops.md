---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ./1636-2026-07-17-daeo-func8185-branch-result-if.md
---

# DAEO Func 8185 final-vacuum nop cleanup

## Goal

Continue the source-backed DAEO parity audit at defined Func `8185` / absolute Func `8206` after note `1636`, while preserving exact control/signature safety, plain-DAE separation, validation, convergence, the canonical-module `< +10000` boundary, and explicit runtime accounting.

The pre-slice endpoint was raw `3203203`, canonical `3264119`, and canonical-module gap `+1663` versus Binaryen v130. Func `8185` was canonical body `2590` versus Binaryen's `2429` (`+161`), with `59` printed blocks, `38` branches, zero `unreachable`, and a run of `24` top-level `nop` placeholders left by selected coalescing.

## Fresh source and pass attribution

Binaryen's `OptUtils::optimizeAfterInlining(...)` prepends `precompute-propagate` and runs the default function optimization pipeline on every DAE-changed function. In Binaryen v130 `pass.cpp`, that pipeline runs `vacuum` immediately after both the early no-structure locals phase and the later full `simplify-locals`, repeats it after local coalescing/reordering, and ends with a final `vacuum` "just to be safe."

Fresh individual Binaryen-v130 probes against the accepted note-`1636` Starshine output attributed the next exact owner:

| direct v130 probe on note `1636` output | Func `8185` canonical body | locals | gets/sets/tees | printed blocks/branches/unreachable |
|---|---:|---:|---:|---:|
| accepted baseline | `2590` | `101` | `241/86/16` | `59/38/0` |
| `vacuum` | `2566` | `101` | `241/86/16` | `38/38/0` |
| `coalesce-locals` | `2549` | `22` | `228/71/16` | `38/38/0` |
| `simplify-locals` | `2512` | `101` | `215/58/17` | `38/38/0` |
| `merge-blocks` | `2590` | `101` | `241/86/16` | `38/38/0` |

These are attribution probes, not accepted module endpoints: running a Binaryen pass directly changes many unrelated functions and the module/type layout. The load-bearing result is narrower: direct v130 `vacuum` removes exactly the `24` nops and yields the same `2566` Func `8185` body and the same local/control counts as the retained Starshine slice. `merge-blocks` changes the printed block shape without reducing the encoded Func body, so the former nine-extra-block count is no longer a direct byte owner. The remaining encoded `+137` is now principally a local simplification/coalescing gap, not unexplained branch or unreachable debris.

## Red-first coverage

A white-box pass-manager test first referenced the new recursive nop cleaner and failed to compile because the helper did not exist. The retained test proves that nested nops are removed while an effectful call and `br 0` remain in the same order and at the same label depth.

The existing public broad-high normalized-literal fixture now also asserts that optimizing DAEO emits no `nop` debris. It continues to assert:

- plain DAE keeps its parameter and `65` locals;
- optimizing DAEO converges the high literal chain;
- the branch-result family has no `unreachable`;
- exact `touch` and `sink` call counts remain unchanged;
- the output validates.

## Retained implementation and safety

The optimizing-only broad-high selected structural cleanup now recursively removes `nop` instructions after all coalescing, structural folds, local-spill sinking, and branch-depth-sensitive rewrites have finished.

- `nop` removal preserves every non-nop instruction in source order.
- Blocks, loops, `if` arms, and `try_table` bodies are rebuilt with identical block types, catch vectors, and nesting.
- No branch instruction is rewritten; label depths are byte-for-byte values from the original instruction nodes.
- No local access, call, trap, effect, signature, result type, or producer/consumer order changes.
- The cleanup remains inside the optimizing broad-high selected-definition transaction. Plain `dead-argument-elimination` does not schedule it.
- Existing selected-definition deep-clone validation, selected-function encoded-size profitability, and rollback remain authoritative. The candidate is retained only because the selected function shrinks.

This is not permission for generic dead-code deletion or control flattening. It removes only `nop`, which has no operands, result, effect, trap, or label identity.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-vacuum-nops-final-20260717/`.

- raw size: `3203179`, `-24` versus note `1636`;
- canonical size: `3264095`, `-24` versus note `1636`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1639`;
- raw SHA-256: `6281d2ef0249e8dc8d3e8c1d97ebefc240b70878d39f6fd374d36bbf65e7a753`;
- canonical SHA-256: `4732fcdcd66b4e155d85ca90d2bc4c4c0ce670f0dd38712b0f21b73d7c5c7cca`;
- native SHA-256: `355e915122fd976198876709798ad9bbfa10ad75eac52085ac8f14bec2716fbf`.

Canonical body matrix:

| defined Func | note `1636` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2590` | `2566` | `2429` | `+137` |
| `8186` | `11` | `11` | `10` | `+1` |
| `8187` | `767` | `767` | `961` | `-194` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8185` now has zero nops, `101` locals, `241/86/16` gets/sets/tees, and `38/38/0` printed blocks/branches/unreachable. This exactly matches the direct Binaryen-v130 `vacuum` probe on the pre-slice function. The final Binaryen DAEO body has `50/38/0`, so Starshine's lower printed block count is explained by the source-owned vacuum result on Starshine's input rather than accepted as arbitrary drift. It is not claimed as an independent Starshine win; the measured retained win is the exact `24` raw/canonical bytes removed by deleting nops.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 `--all-features -O0 --strip-debug` canonical form. Both raw and canonical outputs validate with `wasm-tools validate --features all`.

## Runtime accounting

The retained run records `77467760us` pass-local / `79.274s` wall, slightly faster than note `1636`'s `77860456us` / `79.662s` while removing `24` bytes.

The converged second invocation records `5135614us` pass-local / `6.763s` wall.

## Validation

- red-first white-box test: failed before implementation with unbound `run_hot_pipeline_dae_remove_nops_instrs`;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `274/274`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8890/8890`;
- native release build: passed with pre-existing warnings;
- first/second raw and canonical validation: passed;
- first/second raw and canonical `cmp`: byte-identical;
- dedicated profile `.tmp/pass-fuzz-dae-optimizing-vacuum-nops-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular GenValid `.tmp/pass-fuzz-dae-optimizing-vacuum-nops-regular-1000`: same result.

Both compare lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused slice smokes, not replacements for the full required four-lane closeout matrix.

No public API changed; `.mbti` review found no relevant diff.

## Remaining work

Func `8185` remains the leading direct body owner at `+137`. Fresh source-backed probes rank the next local owner as full `simplify-locals` (`2512`, a further `54` bytes closer than the retained endpoint) followed by Binaryen `coalesce-locals` (`2549`). The next slice should inventory the exact `26` removed gets / `28` removed sets / one introduced tee from the v130 `simplify-locals` probe and implement only a proved movement-safe subset. Do not retry blanket local ordering, Starshine's rejected full selected structured coloring, or the rejected all-generic productive replay without new evidence.

Func `8184 +16`, Func `8186 +1`, the full four-lane DAEO closeout matrix, and the pre-slot public optimize/shrink/O4z blockers remain active.
