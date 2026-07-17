---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1638-2026-07-17-daeo-func8185-copy-producer-retarget.md
---

# DAEO Func 8185 never-read result stores

## Goal

Close the next exact movement-free residual in the source-backed Binaryen-v130 `simplify-locals -> vacuum` probe for defined Func `8185` / absolute Func `8206`. Preserve every producer evaluation, effect, trap, control edge, signature, selected validation/profitability/rollback boundary, and plain-DAE separation.

The pre-slice endpoint from note `1638` was raw `3203087`, canonical `3263975`, and `+1519` canonical bytes versus Binaryen v130. Func `8185` was canonical body `2466` versus Binaryen's final `2429` (`+37`), with `76` body locals and `216/61/16` local gets/sets/tees.

## Source and diff attribution

The direct Binaryen-v130 `simplify-locals -> vacuum` probe recorded in note `1638` replaces two stores to a never-read result local with `drop`. The stored producers may call, trap, or otherwise have effects, so removing the producer is not valid. Replacing only `local.set dead` with `drop` preserves stack consumption and leaves producer evaluation exactly in place.

This retained slice deliberately matches only the exact observed family:

- the destination is a body local, not a parameter;
- the destination has zero gets;
- the destination has exactly two sets;
- the destination has zero tees.

One-write, three-write, read, tee, and parameter families remain untouched. This exactness prevents the source-backed artifact slice from silently widening into a general dead-store pass.

## Red-first coverage

The white-box positive test first referenced `run_hot_pipeline_dae_drop_two_write_never_read_locals_instrs` and failed to compile because the helper did not exist. It now proves that two call results are each consumed by `drop` while both calls and their order remain unchanged.

Negative coverage preserves the original instruction sequence for:

- one write;
- three writes;
- any destination read;
- any destination tee;
- parameter destinations.

The public broad-high normalized-literal fixture adds two effectful `$touch` calls stored to a never-read local and asserts that both literal arguments and all seven calls remain. Plain DAE still retains the original broad function shape.

## Retained implementation and safety

The optimizing-only broad-high structural cleanup computes recursive local get/set/tee counts after copy-producer retargeting. It marks only exact two-write/zero-read/zero-tee body locals, recursively replaces their `local.set` instructions with `drop`, and then relies on the existing selected local compaction to remove the now-unused declaration.

The rewrite does not move or remove the producer. It changes no block type, branch depth, catch vector, function signature, call order, effect order, or trap timing. Selected-definition deep-clone validation, encoded-size profitability, and rollback remain authoritative. Plain `dead-argument-elimination` does not schedule this helper.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-dead-result-final-20260717/`.

- raw size: `3203083`, `-4` versus note `1638`;
- canonical size: `3263973`, `-2` versus note `1638`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1517`;
- raw SHA-256: `76f01aa60695677c8bd1ab47c13aea4fabe5187ec408033667c7cd45395318d3`;
- canonical SHA-256: `c23de82f8b0d37f9510a06cff60cd506e455a6baf8e2b1271233fc9388be4668`;
- native SHA-256: `23753ece5222807f661a13ef1cd3e14519b2db33ec35d28cd1b26ca707766a94`.

Canonical body matrix:

| defined Func | note `1638` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2466` | `2464` | `2429` | `+35` |
| `8186` | `11` | `11` | `10` | `+1` |
| `8187` | `768` | `768` | `961` | `-193` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8185` now has `75` body locals and `216/59/16` gets/sets/tees. The two sets disappeared, producer calls became drops in place, and selected compaction removed one declaration. Blocks/branches/unreachable remain `38/38/0`; nops remain zero.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 canonical form. Both raw and canonical outputs validate with all features.

The direct `simplify-locals -> vacuum` probe remains body `2462`, so this endpoint is only two bytes larger than that probe. Those final two bytes belong to the still-blocked producer/readback tee and delayed-field-read movement subset, not to the now-closed dead-result-store family. Final Binaryen DAEO remains a separate `35`-byte frontier.

## Runtime accounting

- first invocation: `77517612us` pass-local / `79.289s` wall;
- converged second invocation: `5129655us` pass-local / `6.764s` wall.

This remains in the same range as the preceding focused slices. No runtime win is claimed.

## Validation

- red-first white-box compile failure: unbound `run_hot_pipeline_dae_drop_two_write_never_read_locals_instrs`;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `278/278`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8894/8894`;
- native release build: passed with pre-existing warnings;
- first/second raw and canonical validation: passed;
- first/second raw and canonical `cmp`: byte-identical;
- dedicated `.tmp/pass-fuzz-dae-optimizing-dead-result-profile-1000`: `1000/1000` normalized, zero compare-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-dead-result-regular-1000`: same result.

Both generated lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused smokes, not replacements for the required four-lane closeout matrix.

No public API changed; `.mbti` review found no relevant diff.

## Remaining work

Func `8185` is now only two bytes larger than the direct full-`simplify-locals -> vacuum` probe. Do not adopt Binaryen's delayed field reads or producer/readback tee until field mutability, aliasing, nullable-reference trap timing, intervening effects, and control placement are separately proved. Against final Binaryen DAEO, Func `8185` remains `+35` and requires new source-backed downstream attribution if the movement-sensitive subset stays blocked.

Func `8184 +16`, Func `8186 +1`, the full four-lane DAEO closeout matrix, and the pre-slot public optimize/shrink/O4z blockers remain active.
