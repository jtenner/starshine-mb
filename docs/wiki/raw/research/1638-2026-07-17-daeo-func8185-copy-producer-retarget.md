---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1637-2026-07-17-daeo-func8185-vacuum-nops.md
---

# DAEO Func 8185 copy-producer retargeting

## Goal

Continue the source-backed `simplify-locals` parity audit for defined Func `8185` / absolute Func `8206` after note `1637`, without adopting Binaryen's movement of six `struct.get` reads across later code. Preserve producer order, exact control/signature safety, plain-DAE separation, selected validation/profitability/rollback, convergence, and the canonical-module `< +10000` boundary.

The pre-slice endpoint was raw `3203179`, canonical `3264095`, and `+1639` canonical bytes versus Binaryen v130. Func `8185` was canonical body `2566` versus Binaryen's `2429` (`+137`), with `101` locals and `241/86/16` local gets/sets/tees.

## Source and diff attribution

A direct Binaryen-v130 `simplify-locals -> vacuum` probe on the accepted note-`1637` output produces Func `8185` body `2462`, only `+33` versus final Binaryen DAEO. The flat diff shows a movement-sensitive prefix:

- thirteen field values are first stored in temporary locals;
- twenty-five top-level `local.get source; local.set destination` copy pairs forward those values;
- Binaryen removes the copy pairs, changes one producer/set/readback to a tee, replaces two never-read result stores with drops, and moves six field reads later.

The retained Starshine slice implements only the movement-free owner. It retargets the original producer's `local.set` to the final copy destination and deletes the later copy pair. The producer instruction stack remains at its original position, so field mutability, aliasing, nullable-reference trap timing, intervening calls, and effect order do not need a movement proof.

## Red-first coverage

The white-box positive test first referenced `run_hot_pipeline_dae_retarget_copy_producers_instrs` and failed to compile because the helper did not exist. It now proves a two-link copy chain collapses while both independent producers remain in their original order.

Negative coverage preserves the original body for:

- an early destination read;
- mismatched local types;
- multiple source reads;
- multiple source writes;
- a source tee;
- an intervening structured-control boundary;
- an intervening terminal-control boundary.

The public broad-high normalized-literal fixture now includes three non-adjacent producer/copy chains and asserts that all three sink calls and literal values remain present. Plain DAE still retains the original broad function locals and parameter behavior.

## Retained implementation and safety

The optimizing-only broad-high structural cleanup runs a bounded fixed point after selected coalescing and structural spill cleanup, before final nop removal and local compaction.

A rewrite requires:

- source and destination are valid body-local indexes;
- exact matching local types;
- source has exactly one set, one get, and no tee in the function;
- the copy is an adjacent `local.get source; local.set destination` pair;
- the unique producer is an earlier `local.set source` in the same flat region;
- no destination read, set, or tee occurs between producer and copy;
- no block, loop, `if`, `try_table`, return/tail return, throw, `unreachable`, branch, branch table, or `br_on_*` boundary intervenes.

The rewrite changes only the producer's local index and deletes the later get/set pair. Calls and possibly trapping/effectful producers remain exactly where they were. Selected-definition deep-clone validation, encoded-size profitability, and rollback remain authoritative. Plain `dead-argument-elimination` does not schedule this helper.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-copy-retarget-final-20260717/`.

- raw size: `3203087`, `-92` versus note `1637`;
- canonical size: `3263975`, `-120` versus note `1637`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1519`;
- raw SHA-256: `110efc05c7de2c9f968de282b6ef8d90598cf3a603a2deac5b5ec08edfb312e7`;
- canonical SHA-256: `07af99f3f9ce7e954aafd2e4cd443261b7ea51fc3ed97409c808f93700a513c1`;
- native SHA-256: `afe3fd177be17e180d81eea5c05fccec9806e81826271f3c321456f0409e1784`.

Canonical body matrix:

| defined Func | note `1637` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2566` | `2466` | `2429` | `+37` |
| `8186` | `11` | `11` | `10` | `+1` |
| `8187` | `767` | `768` | `961` | `-193` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8185` now has `76` locals and `216/61/16` gets/sets/tees, removing exactly the `25` gets and `25` sets in the inspected copy family. It remains at `38/38/0` printed blocks/branches/unreachable and zero nops. The one-byte Func `8187` encoding shift remains inside its measured Starshine-win body (`-193` versus Binaryen) and accompanies a net module reduction; it is not used to excuse any remaining positive body gap.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 canonical form. Both raw and canonical outputs validate with all features.

## Runtime accounting

- first invocation: `78123690us` pass-local / `79.918s` wall;
- converged second invocation: `5156784us` pass-local / `6.783s` wall.

This is close to note `1637`'s `77467760us` pass-local result while removing another `120` canonical bytes. No runtime win is claimed.

## Validation

- red-first white-box compile failure: unbound `run_hot_pipeline_dae_retarget_copy_producers_instrs`;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `276/276`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8892/8892`;
- native release build: passed with pre-existing warnings;
- first/second raw and canonical validation: passed;
- first/second raw and canonical `cmp`: byte-identical;
- dedicated `.tmp/pass-fuzz-dae-optimizing-copy-retarget-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-copy-retarget-regular-1000`: same result.

Both generated lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE normalizers. They are focused smokes, not replacements for the required four-lane closeout matrix.

No public API changed; `.mbti` review found no relevant diff.

## Remaining work

Func `8185` is now `+37`; the direct `simplify-locals -> vacuum` probe remains `+33`. The next exact movement-free residual is the two writes to a never-read result local: each producer must remain evaluated and become `drop`, after which selected compaction may remove the final dead local. Keep Binaryen's six delayed field reads out of scope unless field mutability, aliasing, trap, and effect order are separately proved.

Func `8184 +16`, Func `8186 +1`, the full four-lane DAEO closeout matrix, and the pre-slot public optimize/shrink/O4z blockers remain active.
