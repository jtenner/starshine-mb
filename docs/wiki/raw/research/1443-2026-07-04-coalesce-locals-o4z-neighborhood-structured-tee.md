---
kind: research
status: current
last_reviewed: 2026-07-04
sources:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/implementation-structure-and-tests.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/coalesce_locals.mbt
  - ../../../../src/passes/coalesce_locals_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../tests/repros/o4z-debug-startup-map-init-repro.wasm
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ./1442-2026-07-04-coalesce-locals-direct-refresh-loop-unused-locals.md
---

# `coalesce-locals` O4z GC/local neighborhood: structured `local.tee`, self-copy cleanup, copy/consume forwarding, ineffective writes, and dense-local bound

## Question

After the direct `coalesce-locals` structured/loop fix in note `1442`, does the checked-in O4z debug startup GC/local neighborhood still drift at the `+ coalesce-locals` / `+ local-cse` prefixes, and is any remaining drift owned by `coalesce-locals`?

The artifact under test is `tests/repros/o4z-debug-startup-map-init-repro.wasm`, the same artifact named in the earlier OC neighborhood note.

## Baseline replay after note `1442`

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
wasm-tools validate --features all tests/repros/o4z-debug-startup-map-init-repro.wasm
```

Fresh prefix replay commands used `bun scripts/self-optimize-compare.ts` with `_build/native/release/build/cmd/cmd.exe` and validated both raw outputs after each run.

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result |
| --- | --- | ---: | ---: | ---: | --- |
| `--heap2local` | `.tmp/self-compare-cl-neighborhood-prefix-01-h2l-20260704` | `192893` | `192893` | `0` | canonical wasm equal, normalized WAT equal |
| `--heap2local --optimize-casts` | `.tmp/self-compare-cl-neighborhood-prefix-02-h2l-oc-20260704` | `192893` | `192893` | `0` | canonical wasm equal, normalized WAT equal |
| `--heap2local --optimize-casts --local-subtyping` | `.tmp/self-compare-cl-neighborhood-prefix-03-h2l-oc-ls-20260704` | `192893` | `192893` | `0` | canonical wasm equal, normalized WAT equal |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-20260704` | `191379` | `191062` | `+317` | first diff `defined=1 abs=1` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-20260704` | `191378` | `191059` | `+319` | first diff `defined=1 abs=1` |

This reproduced the earlier owner localization almost exactly: prefixes before `coalesce-locals` are still equal, and the first drift appears when `coalesce-locals` is added.
The note `1442` fix reduced the historical deltas by two bytes (`+319 -> +317` and `+321 -> +319`) but did not eliminate the neighborhood size drift.

## Reduced owner inside the first diff

The first differing function uses non-loop structured `if` regions with `local.tee` roots.
Starshine still had a blanket skip for every structured function containing any `local.tee`, so it missed Binaryen-compatible slot sharing for branch-local values.
After removing that skip, the artifact shrank further but still left redundant self-copy debris because the structured conservative path rewrote indices without running the coalescing copy-pair cleanup.

Focused red-first tests were added for three safe subsets:

1. `coalesce-locals coalesces structured local-tee branch slots` replaces the old broad skip expectation. The fixture matches Binaryen's behavior for a `local.tee` condition whose written local is not a later distinct live value: branch result locals can share one exact-typed slot while the `local.tee` stack value is preserved.
2. `coalesce-locals removes structured self-copy debris after coalescing` protects the structured post-coloring cleanup case where coalescing turns `local.get x; local.set y` into `local.get x; local.set x`, which Binaryen deletes as a no-op.
3. `coalesce-locals forwards structured branch copies into dead param slots` protects the next reduced copy-chain subset from the same first-diff family: branch-local temps that are only copied through bounded local-copy chains into a dead exact-typed param slot may ignore the conservative cross-branch plain-liveness edge for that copy relationship.
4. `coalesce-locals drops structured ineffective copy sets` protects Binaryen-shaped cleanup for structured writes whose destination is not read later; pure local-copy sets become `local.get; drop`, while same-slot copies are still preserved long enough for the redundant-copy cleanup to emit `nop`.
5. `coalesce-locals coalesces structured derived branch carriers` protects the latest reduced first-diff subset: a non-loop structured source local that is explicitly written, then consumed into a derived branch carrier before any later source read, may share with that derived carrier and its bounded copy chain. The scan rejects branches/returns/loops/try-table control and rejects later source reads after a maybe-clobbering derived write.

Implementation changes:

- `src/passes/coalesce_locals.mbt` no longer rejects all non-loop structured `local.tee` functions.
- The non-loop structured path still uses the conservative plain-liveness interference overlay, so this does not admit loop/backedge path-sensitive merging.
- The structured path now runs the existing redundant-copy cleanup after index rewrite and applies the same conservative ineffective-write facts used by the action liveness model. It preserves newly self-copying ineffective sets until redundant-copy cleanup can remove them, while non-self ineffective sets become `drop` to preserve value effects.
- The structured coloring step now removes conservative interference edges for bounded, syntactically proven copy-forward chains only when the source body local's pending value is copied toward one destination and no destination local access occurs before that copy. The scan rejects loops, branches, returns, try tables, destination accesses before the copy, pending values crossing child control, source escapes, and overwritten pending values.
- A separate structured consume-forward scan now removes conservative interference edges when an explicitly initialized body local is read into a derived destination write and the source is not read again after that maybe-clobbering write before being overwritten. The removal also extends through bounded copy-weight chains rooted at the derived destination, which covers branch carriers such as derived `local.tee`/load results copied into dead param slots without admitting default-local or loop/backedge merging.
- The consume-forward scan also rejects destination reads after a source write and before the source is explicitly consumed back into that destination. This keeps source writes from silently clobbering a still-needed destination value when the two locals would share a slot.
- A path-disjoint branch-result scan now removes the remaining conservative plain-liveness edge when a body-local branch result and a destination slot are never read after the other may have clobbered them on the same path. It rejects uninitialized/default source reads, branches/returns, loops, and try-table control; ordinary `if` arms are merged path-sensitively so reads in the opposite arm do not force a spurious interference edge.
- Structured ineffective-write cleanup now uses branch-aware effective-write marking for rewrite cleanup while leaving the existing flattened coloring liveness in place. This preserves Binaryen-compatible coloring/profitability but no longer rewrites a live then-arm side-carrier copy to `drop` merely because a flattened action scan sees the else-arm write later.

## Replay after structured `local.tee` / self-copy fix

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-after-tee-cleanup-20260704` | `191230` | `191062` | `+168` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `19.317ms`, Binaryen `15.573ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-after-tee-cleanup-20260704` | `191229` | `191059` | `+170` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `19.962ms`, Binaryen `17.325ms` |

Agent classification: this slice reduced a CL-owned size/parity gap and preserved artifact validity, but the ordered neighborhood is not yet closed. The remaining first diff is still local-slot shape drift in function `defined=1 abs=1`: Starshine leaves three body locals and `local.set $1 (local.get $3)`-style cross-slot copies where Binaryen's CFG/value-numbering coalesces down to one body local and uses param slots more aggressively.

## Replay after bounded structured copy-chain forwarding and ineffective-write cleanup

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-ineffective-structured-20260704` | `191224` | `191062` | `+162` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `20.286ms`, Binaryen `23.199ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-ineffective-structured-20260704` | `191223` | `191059` | `+164` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `20.219ms`, Binaryen `22.751ms` |

The bounded copy-chain subset narrowed the previous `+168/+170` post-tee drift to `+162/+164`; structured ineffective-write cleanup preserves that size while matching another Binaryen cleanup family. This is still not closure. The remaining drift should stay classified as an active CL parity gap, not an accepted representation difference, because no Starshine size/performance win has been measured and Binaryen is smaller.

## Replay after derived branch-carrier consume-forwarding

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-derived-carriers-final-20260704` | `191215` | `191062` | `+153` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `25.494ms`, Binaryen `16.116ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-derived-carriers-final-20260704` | `191214` | `191059` | `+155` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `25.622ms`, Binaryen `16.564ms` |

The derived-carrier subset reduced the remaining checked startup-map drift by another nine bytes and made the first-diff function use one body local, matching Binaryen's body-local count for that function. The first diff is still not closed: Starshine now prefers a different exact-typed slot assignment inside the same one-body-local envelope, and Binaryen remains smaller at the ordered prefix. Keep this classified as an active CL parity gap rather than accepted representation drift until the residual is either eliminated or narrowly proven/approved with measured evidence.

The pass-local timings remain within the repository's `>=50%` Binaryen-speed target for pass work (`25.494ms <= 2 * 16.116ms` and `25.622ms <= 2 * 16.564ms`), even though the self-compare script's stricter “at least as fast” boolean is false.

## Destination-read guard after the derived-carrier replay

A follow-up safety slice added `coalesce-locals keeps structured destination reads after source writes`, reduced from the residual slot-choice hazard visible in the same first-diff family. The test failed before the guard because the structured coalescer could eliminate the only body local in a shape where both params were read after a body-local source write and before the source was copied into one destination. `CLConsumeForwardScan` now tracks a source-write/destination-clobber state and rejects consume-forward interference removal if the destination is read while that state is pending.

The guard is a correctness hardening, not a size win for the checked startup-map artifact. Fresh O4z prefix replay after rebuilding native `src/cmd` stayed at the same residual size gap:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-dest-read-guard-20260704` | `191215` | `191062` | `+153` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `27.059ms`, Binaryen `15.263ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-dest-read-guard-20260704` | `191214` | `191059` | `+155` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `25.625ms`, Binaryen `21.769ms` |

Both Starshine pass-local timings are still within the repository's `>=50%` Binaryen-speed target (`27.059ms <= 2 * 15.263ms`, `25.625ms <= 2 * 21.769ms`). The remaining `+153/+155` residual stays classified as an active CL parity gap because Binaryen remains smaller and no Starshine win has been measured.

## Source-write / destination-read interference hardening

A subsequent reduction of the same `defined=1 abs=1` first diff showed a second safety/profitability issue outside `CLConsumeForwardScan`: safe-copy/consume edge removal could still leave the coloring step free to map a body-local source into a destination slot even when the original program writes the source and later reads the destination before the destination is explicitly restored. In the startup-map family this made the inner branch/index carrier share the later mask slot, which was both size-losing and semantically risky.

`src/passes/coalesce_locals.mbt` now restores a direct interference edge after the copy/consume relaxations when a non-loop scan sees a maybe-clobbering source write followed by a destination read. Direct `local.get dest; local.set/tee source` copies are exempted as same-value writes; blocks and `if` branches propagate the pending clobber state, while loops/try-table and conditional branch exits stay conservative.

The existing `coalesce-locals coalesces structured derived branch carriers` regression was tightened to assert the residual startup-map carrier slot itself: the first branch/index `local.tee` and the later then-arm carrier read must stay on the body slot (`Local2`) rather than sharing the mask/destination slot (`Local1`). That assertion failed before this slice as `LocalTee(LocalIdx(1))` and passed after the restored interference.

Fresh O4z prefix replay after rebuilding native `src/cmd` improved the ordered size drift by two bytes and changed the first diff to the narrower remaining then-result slot-choice family:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-source-write-hazard-20260704` | `191213` | `191062` | `+151` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `26.862ms`, Binaryen `16.352ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-source-write-hazard-20260704` | `191212` | `191059` | `+153` | first diff `defined=1 abs=1`; both raw outputs validate | Starshine `27.445ms`, Binaryen `27.395ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`26.862ms <= 2 * 16.352ms`, `27.445ms <= 2 * 27.395ms`). The remaining `+151/+153` residual is still an active CL parity gap, not accepted drift: Binaryen is smaller, and the first diff is now narrowed to the then-arm result slot choice where Starshine writes/reads body `Local2` and Binaryen reuses param `Local0`.

## Path-disjoint branch-result slot reuse

The then-arm result slot-choice family was reduced to `coalesce-locals reuses param slots across exclusive branch result writes`: a branch-local source is written only after the original parameter value has been consumed on that path, while parameter reads in the other arm are mutually exclusive. Before the fix the focused test kept one body local; after the fix both branch result carriers reuse the parameter slot.

`src/passes/coalesce_locals.mbt` now runs `cl_remove_path_disjoint_branch_result_interferences` after the source-write/destination-read restoration. The scan is deliberately narrower than a general CFG allocator: it tracks source writes, destination writes, source/destination reads, and initialized source state through blocks and `if` arms, but fail-closes on branch/return, loop, and try-table control. It removes an interference edge only when no path can read the destination after a source write may have clobbered it, no path can read the source after a destination write may have clobbered it, and the body-local source is initialized before any source read.

Fresh replay after rebuilding native `src/cmd` reduced the checked startup-map drift by another six bytes and moved the first differing function from `defined=1 abs=1` to `defined=2 abs=2`:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-path-disjoint-20260704` | `191207` | `191062` | `+145` | first diff `defined=2 abs=2`; both raw outputs validate | Starshine `29.837ms`, Binaryen `16.851ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-path-disjoint-20260704` | `191206` | `191059` | `+147` | first diff `defined=2 abs=2`; both raw outputs validate | Starshine `77.361ms`, Binaryen `60.390ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`29.837ms <= 2 * 16.851ms`, `77.361ms <= 2 * 60.390ms`). The remaining `+145/+147` residual is still an active CL parity gap, not accepted drift: Binaryen remains smaller, and the new first diff is another structured local-slot assignment family in `defined=2 abs=2`.

## Branch-aware structured effective-write marking

The `defined=2 abs=2` inspection exposed a correctness hazard inside the residual slot-assignment family: the flattened effective-write scan could mark a live then-arm side-carrier copy ineffective because the else-arm write to the same original local appears later in flattened action order. In the startup-map function that meant the then path could compute the small-bin index, rewrite the live copy to `drop`, and later read the pre-branch masked size value instead. This is not safe representation drift.

Red-first `coalesce-locals preserves structured side-carrier writes across branch arms` reduces that shape with two post-`if` carriers: the `if` result and a side carrier consumed after the merge. `src/passes/coalesce_locals.mbt` now computes a second branch-aware effective-write map for rewrite cleanup. `if` arms are analyzed independently from the same live-after state and merged with unioned live-at-entry facts, so a write needed on either path remains effective. Coloring still uses the historical flattened liveness plus the conservative structured interference overlay, avoiding the earlier precision regression in self-copy cleanup.

Fresh replay after rebuilding native `src/cmd` keeps the first diff at `defined=2 abs=2`; it intentionally gives back one byte relative to the unsafe path-disjoint replay because the live side-carrier copy is no longer dropped:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-structured-liveness-20260704` | `191208` | `191062` | `+146` | first diff `defined=2 abs=2`; both raw outputs validate | Starshine `28.401ms`, Binaryen `25.108ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-structured-liveness-20260704` | `191207` | `191059` | `+148` | first diff `defined=2 abs=2`; both raw outputs validate | Starshine `26.697ms`, Binaryen `16.452ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`28.401ms <= 2 * 25.108ms`, `26.697ms <= 2 * 16.452ms`). The remaining `+146/+148` residual is still an active CL parity gap, not accepted drift: Binaryen remains smaller, and Starshine now preserves a live side-carrier write that the prior replay had incorrectly dropped.

## Effective-copy weighting and copy-connected coloring order

The latest `defined=2 abs=2` reduction showed that the side-carrier copy was now correct but still size-losing: inactive/dead local-copy actions could influence copy weights and let an unrelated post-branch local claim a copy-connected carrier source slot before the final side carrier. That left branch-local body-to-body copies where Binaryen coalesces the carrier chain first.

Red-first `coalesce-locals colors structured side-carrier copy chains before unrelated locals` models the first-diff size-class/index carrier with a later unrelated live local. The implementation now:

- weights only effective local-copy actions, using the branch-aware effective-write map in the structured path and the ordinary liveness map in the straight-line path;
- tries the existing natural and reverse greedy orders plus copy-connected-first natural/reverse orders;
- keeps all existing interference checks unchanged, so the new order changes profitability/slot choice only when the same safety graph already permits the merge.

Fresh replay after rebuilding native `src/cmd` reduced the checked startup-map drift by another four bytes and moved the first differing function from `defined=2 abs=2` to `defined=3 abs=3`:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-copy-weighted-20260704` | `191204` | `191062` | `+142` | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `29.817ms`, Binaryen `15.674ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-copy-weighted-20260704` | `191203` | `191059` | `+144` | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `29.216ms`, Binaryen `16.187ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`29.817ms <= 2 * 15.674ms`, `29.216ms <= 2 * 16.187ms`), even though the self-compare script's stricter “at least as fast” boolean is false. The remaining `+142/+144` residual is still an active CL parity gap, not accepted drift: Binaryen remains smaller overall. A later per-function split below shows the `defined=3 abs=3` first textual diff is locally Starshine-smaller, so the largest current measured size-loss owner is loop-heavy `defined=18 abs=18`.

## Direct pass freshness after the fix

After the structured `local.tee`, self-copy, bounded copy-chain, derived branch-carrier consume-forwarding, source-write/destination-read hardening, path-disjoint branch-result slot reuse, branch-aware structured effective-write marking, effective-copy weighting/copy-connected coloring order, ineffective-write, loop unread-local scratch, loop adjacent/non-adjacent copy-through, dense-local guard, and `[AUDIT006-D]` comment changes:

```sh
moon fmt
moon info
moon test --package jtenner/starshine/passes --file coalesce_locals_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass coalesce-locals \
  --out-dir .tmp/pass-fuzz-coalesce-locals-copy-weighted-10000-20260704 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- `moon fmt`: passed
- `moon info`: passed with pre-existing warnings
- focused `coalesce_locals_test.mbt`: `20/20` after the derived-carrier slice; `21/21` after the destination-read guard and source-write/destination-read interference hardening; `22/22` after path-disjoint branch-result slot reuse; `23/23` after branch-aware structured effective-write marking; `24/24` after effective-copy weighting and copy-connected coloring order; `25/25` after loop unread-local scratch coalescing; `26/26` after loop adjacent copy-chain coalescing; `27/27` after loop non-adjacent copy-through coalescing
- `moon test src/passes`: `4002/4002` after the derived-carrier slice; `4003/4003` after the destination-read guard and source-write/destination-read interference hardening; `4004/4004` after path-disjoint branch-result slot reuse; `4005/4005` after branch-aware structured effective-write marking; `4006/4006` after effective-copy weighting and copy-connected coloring order; `4007/4007` after loop unread-local scratch coalescing; `4008/4008` after loop adjacent copy-chain coalescing; `4009/4009` after loop non-adjacent copy-through coalescing
- full `moon test`: `7425/7425` after the derived-carrier slice; `7426/7426` after source-write/destination-read interference hardening; `7427/7427` after path-disjoint branch-result slot reuse; `7428/7428` after branch-aware structured effective-write marking; `7431/7431` after loop adjacent copy-chain coalescing
- native `src/cmd` build: passed with pre-existing warnings after the derived-carrier slice, after the destination-read guard, after source-write/destination-read interference hardening, after path-disjoint branch-result slot reuse, after branch-aware structured effective-write marking, after loop adjacent copy-chain coalescing, and after loop non-adjacent copy-through coalescing
- direct compare lane after the dense guard: `.tmp/pass-fuzz-coalesce-locals-dense-guard-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after derived-carrier consume-forwarding: `.tmp/pass-fuzz-coalesce-locals-derived-carriers-final-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after the destination-read guard: `.tmp/pass-fuzz-coalesce-locals-dest-read-guard-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after source-write/destination-read interference hardening: `.tmp/pass-fuzz-coalesce-locals-source-write-hazard-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after path-disjoint branch-result slot reuse: `.tmp/pass-fuzz-coalesce-locals-path-disjoint-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after branch-aware structured effective-write marking: `.tmp/pass-fuzz-coalesce-locals-structured-liveness-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after effective-copy weighting and copy-connected coloring order: `.tmp/pass-fuzz-coalesce-locals-copy-weighted-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after loop unread-local scratch coalescing: `.tmp/pass-fuzz-coalesce-locals-loop-unread-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after loop adjacent copy-chain coalescing: `.tmp/pass-fuzz-coalesce-locals-loop-copy-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- direct compare lane after loop non-adjacent copy-through coalescing: `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-10000-20260704` requested/compared `10000/10000`, normalized matches `10000`, cleanup-normalized `0`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `10000` hits / `0` misses.
- closeout-scale regular GenValid lane after loop non-adjacent copy-through coalescing: `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-genvalid-100000-20260704` requested/compared `100000/100000`, normalized matches `100000`, cleanup-normalized `0`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `10312` hits / `89688` misses.
- explicit wasm-smith lane after loop non-adjacent copy-through coalescing: raw lane `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-wasm-smith-10000-20260704` compared `9956/10000`, normalized `9955`, mismatches `1`, command failures `44`; the one mismatch is the no-local `drop(unreachable); unreachable` debris case `case-009332-wasm-smith`, and the same lane with `--normalize unreachable-control-debris` at `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-wasm-smith-10000-normalized-20260704` compared `9956/10000`, normalized `9955`, compare-normalized `1`, mismatches `0`, command failures `44` classified as Binaryen/oracle tool boundaries (`binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`).
- random-all-profiles GenValid closeout lane remains incomplete: `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-random-all-profiles-10000-20260704` timed out after 1200s with no `result.json` after writing `4433` cases and `619` failure dirs; rerun/classify in a later slice before final closeout.
- `git diff --check`: passed after source-write/destination-read interference hardening, after path-disjoint branch-result slot reuse, after branch-aware structured effective-write marking, after effective-copy weighting/copy-connected coloring order, and after loop adjacent copy-chain coalescing.

## Loop unread-local scratch coalescing and residual size-owner split

A follow-up loop hardening slice targeted a safe subset of the large loop residual visible in the same checked startup-map replay: locals that are written by `local.set` / `local.tee` in loop functions but never read by `local.get` do not carry values across loop backedges. Before the fix, the loop fallback treated every syntactic set/tee as an accessed local and kept one slot per dead-write local.

Red-first `coalesce-locals coalesces unread loop locals without clobbering live locals` covers that boundary. The loop fallback now distinguishes syntactic reads from writes: read locals still keep conservative distinct slots, write-only locals of the same exact type share a dead scratch body slot, and completely unused locals can still collapse into any compatible existing slot. The dead scratch is deliberately not a param or read-local slot, so the preserved writes cannot clobber values that are later read.

Fresh startup-map replay after rebuilding native `src/cmd` did not change the checked artifact's aggregate size, indicating the artifact's remaining loop-heavy size loss is not made of this simple unread-local subset:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-loop-unread-20260704` | `191204` | `191062` | `+142` | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `28.752ms`, Binaryen `15.456ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-loop-unread-20260704` | `191203` | `191059` | `+144` | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `31.416ms`, Binaryen `16.825ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`28.752ms <= 2 * 15.456ms`, `31.416ms <= 2 * 16.825ms`). Runtime artifact safety validation passed for the original startup-map repro and both new Starshine raw outputs with `wasm-tools validate --features all`.

A code-body size split of the `+ coalesce-locals` replay shows why the first textual diff is not sufficient to classify the whole residual. Function `defined=3 abs=3` is actually a local Starshine size win in code-body bytes (`341` vs Binaryen `355`, `-14`), and other functions `26`, `27`, and `31` are also Starshine-smaller. The largest current size-losing owner is loop-heavy function `18` (`581` vs Binaryen `501`, `+80`), followed by smaller positive deltas in functions `5`, `6`, `10`, `14`, `28`, `37`, and `40`; aggregate code-body delta is `+66` bytes (`23544` vs `23478`). Agent classification: the `defined=3` first diff can be treated as a measured local Starshine-win shape for size, but the ordered CL neighborhood as a whole remains an active parity/size gap because Binaryen is still smaller overall and loop-heavy function `18` is not yet reduced or accepted.

## Loop adjacent copy-chain coalescing

The next loop slice targeted the measured function-18 owner without enabling general loop coloring. The safe subset is an adjacent single-use copy-through shape inside any loop function: `local.set tmp; local.get tmp; local.set dest`, where `tmp` is a same-typed body local with exactly one syntactic `local.set`, exactly one syntactic `local.get`, and no `local.tee`. Reusing the resolved destination slot moves the overwrite earlier only by the immediately following `local.get tmp`; recursive redundant-copy cleanup then removes the resulting self-copy pairs. This also handles bounded chains such as function 18's `block-result -> tmp -> carrier` and `tmp -> tmp -> loop-carrier` shuttles while leaving non-adjacent read loop locals conservative.

Red-first `coalesce-locals coalesces adjacent loop copy chains` covered that shape. It failed before implementation with three i32 body locals and now passes with one final carrier local. The loop fallback now counts syntactic gets/sets/tees, marks adjacent single-use copy-through locals, resolves transitive copy-through chains to an already allocated destination slot, and runs redundant-copy cleanup after loop index rewriting.

Fresh startup-map replay after rebuilding native `src/cmd` materially reduced the residual ordered drift but did not close it:

| Prefix | Out dir | Starshine bytes | Binaryen bytes | Delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-loop-copy-20260704` | `191081` | `191062` | `+19` | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `29.031ms`, Binaryen `15.339ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-loop-copy-20260704` | `191080` | `191059` | `+21` | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `30.134ms`, Binaryen `17.690ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`29.031ms <= 2 * 15.339ms`, `30.134ms <= 2 * 17.690ms`). Runtime artifact safety validation passed for the original startup-map repro and both new Starshine raw outputs with `wasm-tools validate --features all`.

The updated code-body split for the `+ coalesce-locals` replay is: aggregate code-body delta `+33` bytes (`23511` vs `23478`); function `defined=3` remains a local Starshine size win (`341` vs `355`, `-14`); function `18` is still the largest measured size-losing owner but narrowed from `+80` to `+59` (`560` vs `501`). Remaining positive owners are functions `5` `+6`, `6` `+4`, `28` `+9`, `37` `+1`, and `40` `+3`; functions `26`, `27`, and `31` remain Starshine-smaller. Agent classification: this slice reduced the CL-owned ordered size gap and removed a proven safe loop copy-through subset, but the ordered neighborhood remained active because Binaryen was still smaller overall and function 18 still had residual loop-carrier drift.

## Loop non-adjacent copy-through coalescing

The next loop slice kept the same conservative loop boundary while widening the copy-through subset from immediately adjacent copies to a single flat basic-segment window. A same-typed body local with exactly one syntactic `local.set`, exactly one syntactic `local.get`, and no `local.tee` may reuse the destination slot when its only `local.get` is followed by `local.set dest`, no branch/return/structured-control barrier sits between the source set and that final copy, and the destination is not accessed in the intervening window. This covers function 18's loop-carrier shuttle locals such as `new-index -> temp -> loop-index` and `new-count -> temp -> loop-count` without allowing general read loop-local coloring or crossing backedges.

Red-first `coalesce-locals coalesces non-adjacent loop copy-through locals` covered the new shape. It failed before implementation with two i32 body locals and now passes with one final carrier local. The loop fallback now marks bounded non-adjacent copy-through locals with the same syntactic single-use counters, resolves them through the existing passthrough chain, and still rejects params as passthrough sources, type mismatches, repeated gets/sets/tees, destination accesses in the move-earlier window, and branch/loop/block/if/try/return barriers.

Fresh startup-map replay after rebuilding native `src/cmd` moved the ordered GC/local neighborhood from a size-losing residual to a raw and aggregate-code-body Starshine win, while preserving the existing first textual diff:

| Prefix | Out dir | Starshine raw bytes | Binaryen raw bytes | Raw delta | Code-body delta | Compare result | Pass-local timing |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals` | `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-nonadj-copy-20260704` | `191042` | `191062` | `-20` | `-6` (`23472` vs `23478`) | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `30.231ms`, Binaryen `24.896ms` |
| `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` | `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-nonadj-copy-20260704` | `191041` | `191059` | `-18` | `-4` (`23471` vs `23475`) | first diff `defined=3 abs=3`; both raw outputs validate | Starshine `30.471ms`, Binaryen `21.769ms` |

Both pass-local timings remain within the repository's `>=50%` Binaryen-speed target (`30.231ms <= 2 * 24.896ms`, `30.471ms <= 2 * 21.769ms`). Runtime artifact safety validation passed for the original startup-map repro and both new Starshine raw outputs with `wasm-tools validate --features all`.

The `+ coalesce-locals` code-body split is now aggregate Starshine-smaller: function `18` shrank from `+59` to `+20` (`521` vs `501`), function `3` remains a local Starshine size win (`341` vs `355`, `-14`), functions `26`, `27`, and `31` remain Starshine-smaller, and small size-losing functions remain `5` `+6`, `6` `+4`, `28` `+9`, `37` `+1`, and `40` `+3`. Agent classification: the previously active ordered CL-owned startup-map size gap is now closed as a measured Starshine raw/code-body size win for these two checked prefixes, but exact textual/canonical equality is still not claimed and preset widening still needs the remaining direct closeout lanes.

## Dedicated GenValid profile and broad-lane diagnostic

A follow-up closeout-matrix slice added the missing pass-specific GenValid profile in `src/validate/gen_valid.mbt`, with focused coverage in `src/validate/gen_valid_tests.mbt`. The stable aggregate profile is `coalesce-locals-all`; aliases are `coalesce-locals`, `coalesce-locals-closeout`, `coalesce-locals-all-profiles`, `cl`, and `cl-closeout`. The aggregate samples three pass-owned leaves:

- `coalesce-locals-straight-line`: same-typed straight-line local copy chains.
- `coalesce-locals-structured`: bounded block-local copy chains.
- `coalesce-locals-loop-copy-through`: conservative loop-local single-use copy-through shapes.

A red-first generator test first failed because these profile constructors did not exist. After implementation, focused validate-profile coverage passed and the dedicated compare lane scaled to the required closeout size:

```sh
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass coalesce-locals \
  --gen-valid-profile coalesce-locals-all \
  --out-dir .tmp/pass-fuzz-coalesce-locals-profile-10000-20260704 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results: focused validate tests `125/125`; dedicated profile lane requested/compared `10000/10000`, normalized `10000`, mismatches `0`, validation/property/generator/command failures `0`, Binaryen cache `10000` hits / `0` misses. Selected leaves were `coalesce-locals-straight-line=4290`, `coalesce-locals-structured=2885`, and `coalesce-locals-loop-copy-through=2825`.

A smaller broad `random-all-profiles` diagnostic also completed after adding the CL profile, replacing the earlier timed-out-only state with a classified active gap:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5555 \
  --pass coalesce-locals \
  --gen-valid-profile random-all-profiles \
  --out-dir .tmp/pass-fuzz-coalesce-locals-random-all-profiles-smoke-1000-20260704 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results: requested/compared `1000/1000`, normalized `837`, mismatches `163`, zero validation/property/generator/command failures, Binaryen cache `530` hits / `470` misses. Failure-dir sampling and manifest counting classify the mismatches as direct CL local-declaration cleanup parity gaps exposed by neighboring-profile inputs, not by the new CL-owned leaves: `125` selected `ssa-nomerge-smoke` and `38` selected `heap2local-struct`; no `coalesce-locals-*` selected case failed. The `heap2local-struct` sample is a local-declaration compaction/unused-leading-local gap around same-typed GC reference locals. The `ssa-nomerge-smoke` sample is a broader structured/control local-slot cleanup gap with parameter and body-local slot choices. These are not accepted Starshine wins and not final signoff evidence; reduce/fix/classify them before counting the broad lane as closed.

Later focused fixes closed the sampled `heap2local-struct` subfamily without accepting drift. Red-first `coalesce-locals packs accessed GC refs before unused leading locals` reduced `case-000006` to a concrete nullable struct-ref local that is written multiple times and read directly by `struct.get` after unused leading scalar/function-ref locals. `src/passes/coalesce_locals.mbt` first used that narrow direct-struct-get/multi-set signal as a coloring tie-breaker, so it did not reorder broad `anyref` or single-set typed-ref cases that Binaryen keeps in original order. Replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case6-direct-structget-pack-20260704` compared/normalized `1/1`, and the follow-up diagnostic `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-smoke-1000-direct-structget-pack-20260704` narrowed the broad sample to `152` mismatches (`ssa-nomerge-smoke=125`, `heap2local-struct=27`).

The next red-first regression, `coalesce-locals packs accessed GC refs before unused trailing refs`, reduced `case-000022`: the used concrete nullable struct-ref local sits between unused function-ref and array-ref locals, and Binaryen still lets it claim body slot `0` before preserving unused typed-ref debris in natural order and scalars after refs. `src/passes/coalesce_locals.mbt` now adds a preferred-first order candidate for exactly the already-narrow direct-`struct.get`/multi-set concrete GC-ref signal, with copy-removal count and body-local count still taking precedence. Replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case22-preferred-gcref-first-20260704` compared/normalized `1/1`; replaying all `152` failures from the previous diagnostic at `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-preferred-gcref-first-20260704` normalized `27` formerly failing `heap2local-struct` cases and left `125` mismatches. The refreshed broad diagnostic `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-smoke-1000-preferred-gcref-first-20260704` compared `1000/1000`, normalized `875`, left `125` mismatches, and had zero validation/property/generator/command failures; all remaining failure dirs are selected from `ssa-nomerge-smoke`.

A later focused `ssa-nomerge-smoke` slice reduced `case-000007`'s final `i32.const; local.tee; drop` debris. Red-first `coalesce-locals removes ineffective tee debris before immediate drop` showed the pass left `i32.const; nop; drop`; this was semantically valid but forced Starshine encoding/normalization through an avoidable scratch-local shape. `cl_remove_redundant_copy_pairs(...)` now drops a `nop` immediately before `drop`, so the final sequence becomes direct `i32.const; drop`. Replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case7-tee-drop-cleanup-20260704` still mismatches because the same case also contains broader structured/control slot drift and dead-tail block cleanup differences. Replaying the `125` residuals at `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-tee-drop-cleanup-20260704` leaves `125` mismatches with zero validation/property/generator/command failures; all are still selected from `ssa-nomerge-smoke`. The residual sample is therefore narrower but not closed: in the replay set, Starshine raw code is still `+10` bytes per case while canonical post-`wasm-opt` code is `-5` bytes per case, so this must remain an active direct-CL structured/control cleanup parity gap rather than an accepted Starshine win.

The next `case-000007` slice fixed one semantic component of that same residual: a nested `block { br 1 }` skips the following tail writes in the parent block, so branch-carrier writes before the nested escape remain live at the parent block exit. Red-first `coalesce-locals preserves branch-carrier writes before nested block escape` failed with those live writes rewritten to `drop`. `cl_instr_makes_rest_unreachable(...)` / structured rewrite liveness now recognize nonlocal nested block escapes and ignore the skipped tail actions while keeping local-index rewriting aligned. Focused replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case7-nested-escape-20260704` still mismatches, but the sampled `37/38` and `80/82` branch-carrier writes are preserved. Replaying all `125` residuals at `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-nested-escape-20260704` still leaves `125` mismatches with zero validation/property/generator/command failures. Size classification intentionally remains open and active: the semantic fix increases raw size in the replay set (`+14` to `+26` bytes, aggregate `+2062`) while canonical post-`wasm-opt` output is still `-1` byte per case, and the next visible subfamily is label-aware branch liveness for `return` and branch-to-block-continuation arms rather than an accepted Starshine win.

A follow-up label-aware liveness slice fixed those sampled control-continuation bugs. Red-first `coalesce-locals drops writes that only reach return` showed that a `local.set` immediately before `return` must not inherit the post-`if` live-after set; it now rewrites to `drop` while preserving the produced value. Red-first `coalesce-locals preserves writes before branch to outer block continuation` showed that a write before `br 1` inside an `if` nested in a block is live at the outer block exit because the branch skips the block tail write; it now remains `local.set`. Structured rewrite liveness now carries a stack of label live sets and handles `return`, `br`, `br_if`, and `br_table` according to their terminal or target-continuation liveness. Focused replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case7-label-live-20260704` still mismatches, but the return-arm dead write, branch-to-block-continuation live write, and pre-`br_if` continuation write now match the Binaryen shape in the sampled diff. Replaying all `125` residuals at `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-label-live-20260704` still leaves `125` mismatches with zero validation/property/generator/command failures. The replay set is raw-size-larger (`+15` to `+27` bytes, aggregate `+2187`) and canonical post-`wasm-opt` wasm sizes are equal per case, so the remaining family is still active and not a Starshine-win classification; sampled diffs are now local slot-order drift such as old body locals choosing `$2`/`$3` in the opposite order and a later `local.tee` choosing body `$2` where Binaryen reuses param `$0`.

A tail-reuse slice then fixed the sampled later-tee param slot component without closing the broad family. Red-first `coalesce-locals ignores dead structured writes when reusing param slots` reduced the shape where an early body-local write is ineffective and rewritten to `drop`, a later structured condition reads the param, and a final top-level effective `local.tee` of that same body local should reuse the dead exact-typed param slot. The source-write/destination-read guard now consults branch-aware effective-write facts, and a narrow tail-reuse relaxation removes the restored param interference only when the effective source write and later source read are top-level after the final destination read; action-depth collection mirrors reachable-action collection so dead tails do not misalign the proof. Focused replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case7-tail-reuse-depths-20260704` still mismatched, but the sampled `i32.const 121` tee used `$0` like Binaryen. Replaying all `125` residuals at `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-tail-reuse-20260704` still left `125` mismatches with zero validation/property/generator/command failures; raw size deltas remained `+15` to `+27` bytes per case, aggregate `+2187`, and canonical post-`wasm-opt` sizes were equal. The residual was narrowed in `case-000007` to the early body-local slot-order swap (`101`/`103` choosing `$2`/`$3` opposite Binaryen), not the later param-tee family.

A final structured-scalar coloring slice closed that slot-order residual. Red-first `coalesce-locals prefers structured scalar scratch before simple early scratch` reduced the `case-000007` shape: after copy-removal/body-local-count ties, an i32 body local used as a structured branch condition and later `local.tee` scratch should claim the lower body slot before an unrelated simple early set/get scratch. `src/passes/coalesce_locals.mbt` now marks exact i32 body locals that feed structured `if` / `br_if` conditions and are written more than once, adds a structured-scalar order candidate, and uses a structured-scalar slot score only after copy-removal count, body-local count, and the existing concrete-GC-ref preferred score tie. This preserves the earlier concrete-ref and copy-connected order priorities while giving Binaryen-shaped numbering to the sampled scalar structured scratch.

Evidence:

- Focused `coalesce_locals_test.mbt`: red at first (`LocalSet(LocalIdx(2)) != LocalSet(LocalIdx(3))`), then green `35/35` after the structured-scalar order implementation.
- Focused replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-case7-structured-scalar-order-20260704`: compared `1/1`, normalized `1`, mismatches/failures `0`.
- Replay of all previous random-all residuals `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-structured-scalar-order-final-20260704`: compared `125/125`, normalized `125`, mismatches/failures `0`.
- Refreshed 1k diagnostic `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-smoke-1000-structured-scalar-order-final-20260704`: compared/normalized `1000/1000`, zero failures.
- Required random all-profiles lane `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704`: requested/compared `10000/10000`, normalized `10000`, zero validation/property/generator/command failures; selected-profile counts include `ssa-nomerge-smoke=1250`, `heap2local-struct=538`, and all `coalesce-locals-*` leaves matching.
- Refreshed regular GenValid `.tmp/pass-fuzz-coalesce-locals-genvalid-100000-structured-scalar-order-final-20260704`: requested/compared `100000/100000`, normalized `100000`, zero failures.
- Refreshed dedicated profile `.tmp/pass-fuzz-coalesce-locals-profile-10000-structured-scalar-order-final-20260704`: requested/compared `10000/10000`, normalized `10000`, zero failures.
- Refreshed explicit wasm-smith raw `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-20260704`: compared `9956/10000`, normalized `9955`, one documented no-local unreachable-control cleanup-debris mismatch, `44` Binaryen/oracle command failures. Cleanup-normalized `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-normalized-20260704` converted that debris to one compare-normalized match and left zero mismatches.

Agent classification: the previously active broad random-all local-declaration cleanup family is fixed, not accepted as drift. The only remaining direct-matrix raw mismatch is the already documented wasm-smith no-local unreachable-control debris boundary, which is green under the explicit normalizer and is not a CL correctness blocker.

A final ordered-prefix replay after this slice reconfirmed the startup-map status with the current native binary: `.tmp/self-compare-cl-neighborhood-prefix-04-h2l-oc-ls-cl-structured-scalar-final-20260704` stayed Starshine-smaller at `191042` vs Binaryen `191062` (`-20` raw bytes), and `.tmp/self-compare-cl-neighborhood-prefix-05-h2l-oc-ls-cl-lcse-structured-scalar-final-20260704` stayed Starshine-smaller at `191041` vs `191059` (`-18` raw bytes). Both Starshine/Binaryen raw outputs validate; first diff remains `defined=3 abs=3`; Starshine pass-local times remain within the repo floor (`32.210ms <= 2 * 15.098ms`, `32.748ms <= 2 * 25.718ms`) though not as fast as Binaryen.

## Dense interference / large-local-count bound

A follow-up hardening slice audited the current dense coloring path. `cl_compute_interferences(...)` and `cl_copy_weights(...)` allocate dense `locals x locals` matrices, so the path was unbounded for huge non-loop functions even though ordinary O4z startup-map functions are small.

The implemented boundary is deliberately narrow:

- non-loop dense coloring is skipped when `params.length() + body_local_count > 4096`;
- loop functions still use the existing conservative unused-local path, which does not allocate the dense interference/copy-weight matrices;
- the skipped huge non-loop function is left unchanged rather than partially coalesced;
- `coalesce-locals intentionally skips dense coloring above local-count guard` in `src/passes/coalesce_locals_test.mbt` locks the boundary with a 4097-local fixture.

Agent classification: this is a finite, documented runtime/GC-churn guard, not a Starshine optimization win and not direct Binaryen shape parity for huge functions above the guard. Reopen it if generated or real-world artifacts hit the guard and the raw output is a release-significant size/performance gap, or when a sparse interference representation is available.

## Remaining work

The `[O4Z-AUDIT-CL]` direct and checked ordered-neighborhood scope is closed for the current v0.1.0 evidence set.

Remaining non-blocking follow-ups:

- Keep the O4z prefix drift closed on future cumulative changes: the latest checked `+ coalesce-locals` and `+ local-cse` prefixes are Starshine raw/code-body size wins (`-20`/`-18` raw bytes) even though first diff remains `defined=3 abs=3` and function `18` remains a smaller residual local size loser (`+20` code-body bytes). Exact normalized/canonical text equality is not claimed.
- Preserve the current loop safety boundary, restored source-write/destination-read interference, path-disjoint branch-result safety checks, branch-aware structured effective-write marking, effective-copy weighting/copy-connected coloring order, structured-scalar slot-order tie-breaker, unread-loop-local scratch rule, adjacent/non-adjacent single-use loop copy-through rules, narrow concrete-ref direct-struct-get packing tie-breaker, and preferred-first GC-ref order candidate. Do not widen to general read loop-local coloring or broad ref-local reordering without a new red-first proof.
- Treat the raw wasm-smith no-local `drop(unreachable); unreachable` mismatch as the documented unreachable-control-debris boundary unless a future change aims to match Binaryen's exact raw cleanup shape. The normalized lane is green with zero mismatches.
- Dense interference allocation is bounded for non-loop functions by the 4096-local guard above. Replace the boundary with sparse coloring only if artifacts or generator profiles show release-significant missed coalescing above the guard.
- `[AUDIT006-D]` is resolved for the local `coalesce-locals` abort by the inline comment in `src/passes/coalesce_locals.mbt`; the broader `[AUDIT006]` docs/helper-test/checklist items remain tracked separately.

## Reopening criteria for this subset

Reopen the structured `local.tee`, self-copy cleanup, copy-chain, consume-forward, and ineffective-write subset if:

- a non-loop structured `local.tee` fixture loses the stack value or clobbers a later live local;
- the structured path starts using flattened effective-write deletion and drops a write that may be needed on another branch;
- bounded copy-chain or loop copy-through forwarding aliases a source with a destination across a destination access, loop, branch, try, return, source escape, pending-value overwrite, repeated temp get/set/tee, or non-exact type match;
- derived-carrier consume-forwarding aliases a default/uninitialized local, crosses loop/try/branch/return control, permits a source read after a maybe-clobbering derived destination write before the source is overwritten, or permits a destination read after a source write while that source write could have clobbered the destination slot;
- source-write/destination-read interference restoration fails to keep a body-local source separate from a destination that is read after a maybe-clobbering effective source write and before explicit destination restoration, or tail-reuse relaxation aliases through an effective source write before the final destination read, a nested/depthful tail source write/read, a non-exact type match, or an unreachable-action/depth mismatch;
- path-disjoint branch-result slot reuse aliases a body-local source with a destination across a same-path source-after-destination-clobber read, destination-after-source-clobber read, uninitialized/default source read, branch/return, loop, or try-table boundary;
- branch-aware structured effective-write marking marks a live branch-arm side-carrier write ineffective because of a mutually exclusive sibling-arm write, or broadens coloring liveness enough to regress the protected structured self-copy cleanup;
- effective-copy weighting lets ineffective/dead copy traffic dominate a live branch-carrier slot choice, or copy-connected-first ordering regresses safety by bypassing an interference edge rather than only changing greedy order;
- structured-scalar slot ordering regresses copy-removal count, body-local count, concrete-GC-ref preferred ordering, or any interference safety edge instead of only breaking tied scalar slot-number choices;
- structured ineffective-write cleanup drops a value-producing expression instead of preserving it with `drop`, or prevents a new self-copy from reaching redundant-copy cleanup;
- direct `--coalesce-locals` develops a validation failure or normalized mismatch in the covered family;
- an ordered O4z replay shows the `local.tee` change caused a new semantic/runtime artifact failure rather than only reducing the known local-slot size drift.
