---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1641-2026-07-17-daeo-func8184-null-guard-and-call-argument.md
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
---

# DAEO Func 8185 immutable field delay

## Goal and source attribution

Close the final two-byte difference between the accepted Starshine Func `8185` body and the direct Binaryen-v130 `simplify-locals-nostructure -> vacuum` probe, without adopting nullable/trapping reads, mutable fields, source writes, arbitrary structured movement, or non-profitable output shapes.

The accepted note-`1641` endpoint was raw `3203066`, canonical `3263956`, and `+1500` canonical bytes versus Binaryen v130. Func `8185` was canonical body `2464` versus the direct downstream probe's `2462` and final Binaryen DAEO's `2429`.

Fresh inspection showed the remaining direct-probe owner exactly:

- source local `0` is non-null `(ref 278)`;
- Type `278` field `6` is immutable;
- the source has no writes or tees;
- the target has exactly one set, four gets, and zero tees after selected copy retargeting and final local ordering;
- the first target read is reached through unconditional nested blocks before any branch or terminal boundary;
- Binaryen delays `local.get 0; struct.get 278 6; local.set target` to that first read as `local.get 0; struct.get 278 6; local.tee target`.

The read cannot trap because the source is non-null. Calls and other effects cannot change the field value because the field is immutable and the source local is unwritten. Delaying a pure nontrapping read across intervening effects or traps does not expose a new effect or trap; the tee executes before any branch in the only admitted nested-block path and preserves the value for the remaining three reads.

## Red-first coverage

The white-box positive test first referenced `run_hot_pipeline_dae_delay_immutable_struct_get_readbacks_instrs` and failed to compile because the helper did not exist. It now proves the exact one-set/four-get movement through two unconditional nested blocks while preserving a later three-read tail.

Negative coverage preserves the original body for:

- mutable fields;
- nullable source references;
- any source write;
- a fifth target read;
- loop/structured movement boundaries.

The public broad-high dispatcher fixture carries the same non-null immutable-field shape through a productive high-definition literal chain. Plain DAE performs only the shared signature work; optimizing DAEO alone delays the field read after the side call and retains the tee plus later reads.

## Retained implementation and safety

The optimizing-only post-finalization transaction runs after final selected local ordering. This order is intentional: an earlier probe moved the field producer before the final reorder and improved canonical size by two bytes but regressed raw size by one byte. Reordering first and delaying second improves both raw and canonical size.

Only productive definitions from the broad-high exact-literal chain are considered. A rewrite requires:

- source and target local indexes in range;
- the source is a parameter and the target is a body local;
- the source local type is non-null reference typed;
- source gets are nonzero, source sets are zero, and source tees are zero;
- target gets are exactly four, target sets exactly one, and target tees zero;
- the producer is exactly adjacent `local.get source; struct.get type field; local.set target`;
- the field is proved immutable through `run_hot_pipeline_dae_struct_field_is_immutable`;
- the first read is in the same straight-line region or through unconditional `block` descent;
- loops, `if`, `try_table`, branches, returns, throws, `unreachable`, and other terminal/control boundaries reject.

The candidate is deep-cloned, validates as a selected definition, and must be strictly smaller by encoded selected-function size. Failure, invalidity, equality, or growth rolls back. Plain `dead-argument-elimination` does not schedule the post-reorder transaction.

Broader probes were rejected rather than generalized:

- one-read immutable movement improved raw size but regressed canonical size by `+66` bytes;
- an exact two-read restriction changed Func `8187`, not the attributed Func `8185` owner;
- moving the exact four-read field before final local ordering improved canonical size by two bytes but added one raw byte;
- scanning all high touched definitions found additional safe size wins, but the retained scheduler was narrowed to the exact productive broad-high set so unrelated touched functions are not opportunistically rewritten.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-field6-final-accepted-20260717/`.

- raw size: `3203064`, `-2` versus note `1641`;
- canonical size: `3263954`, `-2` versus note `1641`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1498`;
- raw SHA-256: `3d2add8ec6099f0b2f7d634520a873ba16b0ae46e7225d6be7bf09f920d8d8c1`;
- canonical SHA-256: `c90f4859c6eae2ba9cc652e0af2aca1db07d5319c5bf3aed414fae8d04fb3994`;
- native SHA-256: `20a36db6f8b546a1571533dd134cbc2bed244b5aebb4b8323f63e6967db5dcc5`.

Canonical body matrix:

| defined Func | note `1641` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `11` | `11` | `11` | `0` |
| `8185` | `2464` | `2462` | `2429` | `+33` |
| `8186` | `10` | `10` | `10` | `0` |
| `8187` | `768` | `768` | `961` | `-193` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8185` traffic changes from `216/59/16` gets/sets/tees to `215/58/17`, exactly matching the delayed producer/readback tee accounting. The body now exactly matches the direct `simplify-locals-nostructure -> vacuum` probe at `2462`; the remaining `+33` versus final Binaryen DAEO belongs to later downstream cleanup/movement families and remains open.

The first and second raw outputs are byte-identical; their Binaryen-v130 canonical forms are byte-identical. All four outputs validate with all features.

## Runtime accounting

- first invocation: `82332738us` pass-local / `84.216s` wall;
- converged second invocation: `6269426us` pass-local / `8.094s` wall.

The first run is slower than note `1641`'s `75830002us`; no runtime win is claimed. It remains direct-pass evidence, not public preset wall-time closeout.

## Validation

- red-first compile failure: unbound `run_hot_pipeline_dae_delay_immutable_struct_get_readbacks_instrs`;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `283/283`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8899/8899`;
- native release build: passed with pre-existing warnings;
- first/second raw and canonical validation: passed;
- first/second raw and canonical comparison: byte-identical;
- dedicated `.tmp/pass-fuzz-dae-optimizing-field6-final-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-field6-final-regular-1000`: same result.

Both generated lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE normalizers. They are focused smokes, not replacements for the required four-lane closeout matrix.

No public API changed; `.mbti` review found no relevant diff. `moon.mod` formatter drift remains unrelated and unstaged.

## Remaining work

Func `8185` now exactly matches the direct no-structure/vacuum probe but remains `+33` versus final Binaryen DAEO. Re-probe the final downstream sequence and classify each residual family. Retain only movement subsets with exact non-null/immutable/effect/control proof and measured raw/canonical benefit; durably reject any nullable, mutable, alias-sensitive, path-sensitive, or size-losing shape.

The full four-lane closeout matrix and the public optimize/shrink/O4z pre-DAEO blockers from note `1584` remain outstanding.
