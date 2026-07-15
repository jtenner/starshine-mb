---
kind: workflow
status: supported
last_reviewed: 2026-07-14
sources:
  - ../../../raw/research/1608-2026-07-14-daeo-grouped-signature-reuse-final-matrix.md
  - ../../../raw/research/1607-2026-07-14-daeo-forwarding-component-final-matrix.md
  - ../../../raw/research/1606-2026-07-14-daeo-dead-callee-final-matrix.md
  - ../../../raw/research/1605-2026-07-14-daeo-computed-carrier-root-cause.md
  - ../../../raw/research/1604-2026-07-14-daeo-forwarded-cycle-final-matrix.md
  - ../../../raw/research/1603-2026-07-14-daeo-forwarded-cycle-precompute.md
  - ../../../raw/research/1602-2026-07-14-daeo-payoff-local-order-final-matrix.md
  - ../../../raw/research/1601-2026-07-14-daeo-payoff-local-order-single-scan.md
  - ../../../raw/research/1600-2026-07-14-daeo-payoff-type-stable-local-order.md
  - ../../../raw/research/1599-2026-07-14-daeo-adjacent-local-order-final-matrix.md
  - ../../../raw/research/1598-2026-07-14-daeo-adjacent-local-order-prefilter.md
  - ../../../raw/research/1597-2026-07-14-daeo-adjacent-type-stable-local-order.md
  - ../../../raw/research/1596-2026-07-13-daeo-func41-local-compaction-final-matrix.md
  - ../../../raw/research/1595-2026-07-13-daeo-removed-param-direct-prefilter.md
  - ../../../raw/research/1594-2026-07-13-daeo-broad-removed-param-local-compaction.md
  - ../../../raw/research/1593-2026-07-13-daeo-adjacent-chain-final-matrix.md
  - ../../../raw/research/1592-2026-07-13-daeo-adjacent-candidate-prefilter.md
  - ../../../raw/research/1591-2026-07-13-daeo-adjacent-constructor-chain-cleanup.md
  - ../../../raw/research/1590-2026-07-13-daeo-two-chain-final-matrix.md
  - ../../../raw/research/1589-2026-07-13-daeo-converged-chain-cleanup.md
  - ../../../raw/research/1588-2026-07-13-daeo-two-chain-bounded-closeout.md
  - ../../../raw/research/1587-2026-07-13-daeo-post-payoff-matrix-and-scheduled-refresh.md
  - ../../../raw/research/1586-2026-07-13-daeo-payoff-ranked-result-chain.md
  - ../../../raw/research/1585-2026-07-13-daeo-bounded-structured-copy-cleanup.md
  - ../../../raw/research/1584-2026-07-13-daeo-scheduled-mode-specific-blockers.md
  - ../../../raw/research/1583-2026-07-13-daeo-post-param-chain-gap-attribution.md
  - ../../../raw/research/1582-2026-07-13-daeo-scheduled-validation-and-timeout.md
  - ../../../raw/research/1581-2026-07-13-daeo-post-param-chain-direct-matrix.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../raw/research/1576-2026-07-13-daeo-low-result-caller-closure.md
  - ../../../raw/research/1575-2026-07-13-daeo-wide-null-default-worklist.md
  - ../../../raw/research/1574-2026-07-13-daeo-artifact-gap-attribution.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/1568-2026-07-13-daeo-fresh-dedicated-and-regular-compare.md
  - ../../../raw/research/1569-2026-07-13-daeo-fresh-wasm-smith-and-random-all.md
  - ../../../raw/research/1570-2026-07-13-daeo-scheduled-replay-localization-safety.md
  - ../../../raw/research/1571-2026-07-13-daeo-post-scratchfloor-regular-and-wasm-smith.md
  - ../../../raw/research/1572-2026-07-13-daeo-post-scratchfloor-random-all.md
  - ../../../raw/research/1573-2026-07-13-daeo-flattened-rec-group-type-repair.md
  - ../dead-argument-elimination/fuzzing.md
---

# `dae-optimizing` Fuzzing Profile

## Dedicated profile

The pass-owned GenValid profile is `dae-optimizing`; `dae-optimizing-closeout` is an alias. It emits a deterministic five-function private-helper/direct-caller module where core DAE removes an unused helper parameter and leaves identity-add debris for the touched-function optimizing replay.

Use the DAE cleanup normalizers on all generated DAEO lanes:

```sh
--normalize drop-consts --normalize unreachable-control-debris
```

These normalizers cover only the documented dropped-constant and unreachable/control debris families. Any remaining mismatch still requires an agent semantic, size, validity, or tool-failure classification.

Recommended dedicated closeout lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --gen-valid-profile dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## Required closeout matrix

Report these independently with a freshly built explicit native binary:

1. regular GenValid: `100000`, seed `0x5eed`;
2. explicit wasm-smith: `10000`, seed `0x5eed`, `--wasm-smith`;
3. dedicated `dae-optimizing`: `10000`, seed `0x5eed`;
4. `random-all-profiles`: `10000`, seed `0x5555`.

For each lane report requested/compared counts, normalized and cleanup-normalized matches, raw mismatches, validation/generator/property failures, command-failure classes, cache counters, and selected subprofile counts when available.

## Fresh current evidence

Research note [`1568`](../../../raw/research/1568-2026-07-13-daeo-fresh-dedicated-and-regular-compare.md) records post-tuple-cleanup evidence from native commit `cf08ff06f`:

- dedicated `.tmp/pass-fuzz-dae-optimizing-dedicated-10000-20260713-post-tuple`: `10000/10000` normalized, zero cleanup-normalized matches, mismatches, or failures, selected `dae-optimizing=10000`, Binaryen cache `10000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-20260713-post-tuple`: `100000/100000` normalized, zero cleanup-normalized matches, mismatches, or failures, Binaryen cache `100000/0`.

Research note [`1569`](../../../raw/research/1569-2026-07-13-daeo-fresh-wasm-smith-and-random-all.md) completes the fresh direct matrix:

- explicit wasm-smith requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, mismatches `0`, with `44` Binaryen/oracle tool failures and no Starshine failure;
- random-all requested/compared `10000/10000`, normalized `9633`, left `367` byte-identical previously reviewed residuals (`dae-effectful-args=124`, `coverage-forced-portable=243`), and had zero failures. The two residual families are agent-classified as measured/source-backed Starshine cleanup wins; the aggregate deltas are `-110219` raw, `-797486` canonical, and `-5465849` WAT bytes, with no canonical/WAT-positive case.

Research note [`1582`](../../../raw/research/1582-2026-07-13-daeo-scheduled-validation-and-timeout.md) refreshes scheduled evidence after the current matrix. Dedicated-profile `optimize`, `shrink`, and synthesized O4z each execute DAEO exactly once immediately after late HSO and before `inlining-optimizing`, emit the same valid 38-byte output, and spend `668us`, `665us`, and `733us` in DAEO.

No retained DAEO behavior changed in notes [`1583`](../../../raw/research/1583-2026-07-13-daeo-post-param-chain-gap-attribution.md) and [`1584`](../../../raw/research/1584-2026-07-13-daeo-scheduled-mode-specific-blockers.md), so the note `1581` four-lane direct matrix remains current. Note `1583` rejects both a size-losing result-only Func-12293/8429 endpoint and a size-winning but over-target selected-cleanup endpoint. Note `1584` refines scheduled ownership: large `--optimize` stalls in direct `vacuum`, while large `-O4z` stalls earlier in `ssa-nomerge`; neither reaches DAEO.

Research note [`1570`](../../../raw/research/1570-2026-07-13-daeo-scheduled-replay-localization-safety.md) adds post-fix scheduled evidence: public `optimize`, public `shrink`, and synthesized `-O4z` each run DAEO exactly once in the locked late neighborhood and produce the same valid `38`-byte output as Binaryen O4z on the dedicated profile. It also fixes an artifact-discovered scratch-local collision and reruns the dedicated lane at `10000/10000` normalized. The current stripped wasm-gc artifact meets the pass-local ratio target (`9692.498ms` Starshine versus `8083.49ms` Binaryen) but remains blocked at Starshine final validation on nondefaultable GC body-local initialization.

Research note [`1571`](../../../raw/research/1571-2026-07-13-daeo-post-scratchfloor-regular-and-wasm-smith.md) refreshes two more lanes with the post-fix native binary SHA-256 `5ee57c2cb70bc0a73faff5831fbc93db45ad3b7f9aac522e6d714f52f4ff50da`:

- regular GenValid `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-post-scratchfloor-20260713`: `100000/100000` normalized, zero mismatches or failures, Binaryen cache `100000/0`;
- explicit wasm-smith `.tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-post-scratchfloor-20260713`: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, zero mismatches and no Starshine failures; the `44` command failures are the unchanged Binaryen/oracle classes (`rec-group-zero=39`, invalid-tag=1, table-index=1, bad-section-size=3), with caches wasm-smith `10000/0`, Binaryen `9956/0`, and Binaryen failures `44/0`.

Research note [`1572`](../../../raw/research/1572-2026-07-13-daeo-post-scratchfloor-random-all.md) completes the post-fix matrix with `.tmp/pass-fuzz-dae-optimizing-random-all-10000-post-scratchfloor-20260713`: `10000/10000` compared, `9633` normalized, `367` mismatches, and zero validation/generator/property/command failures. The failure-directory set and all `3670` residual files are byte-identical to the pre-fix lane. The residuals remain exactly `dae-effectful-args=124` and `coverage-forced-portable=243`, with aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive cases. They remain agent-classified measured/source-backed Starshine cleanup wins, not harness claims.

Research note [`1573`](../../../raw/research/1573-2026-07-13-daeo-flattened-rec-group-type-repair.md) fixes a DAEO-owned flattened rec-group type lookup/append correctness bug and reruns the full matrix with native binary SHA-256 `be413f169ff1cc8fc779168c4093fca8291fa86fa7d672d2c2a4bb54fae73c6d`:

- dedicated: `10000/10000` normalized, zero failures;
- regular: `100000/100000` normalized, zero failures;
- wasm-smith: `9955` normalized plus `1` cleanup-normalized out of `9956` comparable cases, zero mismatches and no Starshine failures, with the same `44` Binaryen/oracle failures;
- random-all: `9633` normalized plus the same `367` measured/source-backed Starshine cleanup wins, zero failures, and `0` changed files across `3670` comparisons with the preceding lane.

Research note [`1581`](../../../raw/research/1581-2026-07-13-daeo-post-param-chain-direct-matrix.md) refreshes the full required direct matrix after note `1580` with native SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812`: dedicated `10000/10000` normalized; regular `100000/100000` normalized; explicit wasm-smith `9955` normalized plus `1` cleanup-normalized out of `9956` comparable cases with the unchanged `44` Binaryen/oracle failures; random-all `9633` normalized plus the same `367` measured/source-backed cleanup wins. The random-all failure-directory set and all `3670` files are byte-identical to the post-recgroup lane, so the `coverage-forced-portable=243` / `dae-effectful-args=124` agent classifications and `-110219` raw / `-797486` canonical / `-5465849` WAT aggregate deltas remain current. There are no unknown/risky, size-losing generated, validation, or true-semantic residuals.

Research notes [`1585`](../../../raw/research/1585-2026-07-13-daeo-bounded-structured-copy-cleanup.md) and [`1586`](../../../raw/research/1586-2026-07-13-daeo-payoff-ranked-result-chain.md) retained new optimizing-only behavior after note `1581`, so that older complete matrix is historical rather than current closeout evidence. Research note [`1587`](../../../raw/research/1587-2026-07-13-daeo-post-payoff-matrix-and-scheduled-refresh.md) records the post-change refresh using explicit native SHA-256 `2e69c9602f2fa252f8e7ef13f40659b8cc8e6ef763fb12ab1a3041fd4e1d3905`: dedicated `10000/10000` normalized, regular `100000/100000` normalized, and wasm-smith `9955` normalized plus `1` cleanup-normalized with the unchanged `44` Binaryen/oracle failures. Random-all timed out after `1800s` with only `307/10000` records. Its `12` partial mismatch directories are byte-identical to prior known measured/source-backed cleanup families, but a partial run cannot satisfy closeout. The current required four-lane matrix is therefore incomplete. DAEO also retains a `+14846` canonical artifact gap and pre-slot large optimize/shrink/O4z blockers.

Research note [`1590`](../../../raw/research/1590-2026-07-13-daeo-two-chain-final-matrix.md) supersedes that incomplete matrix after notes [`1588`](../../../raw/research/1588-2026-07-13-daeo-two-chain-bounded-closeout.md) and [`1589`](../../../raw/research/1589-2026-07-13-daeo-converged-chain-cleanup.md). It records the intermediate complete four-lane matrix before the adjacent-chain behavior landed.

Research note [`1593`](../../../raw/research/1593-2026-07-13-daeo-adjacent-chain-final-matrix.md) is the complete pre-Func-41 matrix after notes [`1591`](../../../raw/research/1591-2026-07-13-daeo-adjacent-constructor-chain-cleanup.md) and [`1592`](../../../raw/research/1592-2026-07-13-daeo-adjacent-candidate-prefilter.md).

Research note [`1599`](../../../raw/research/1599-2026-07-14-daeo-adjacent-local-order-final-matrix.md) is the historical adjacent-pair matrix. Research note [`1602`](../../../raw/research/1602-2026-07-14-daeo-payoff-local-order-final-matrix.md) is the historical payoff-order matrix. Research note [`1604`](../../../raw/research/1604-2026-07-14-daeo-forwarded-cycle-final-matrix.md) is the historical forwarded-cycle matrix. Research note [`1606`](../../../raw/research/1606-2026-07-14-daeo-dead-callee-final-matrix.md) is the historical unread-sink matrix after note [`1605`](../../../raw/research/1605-2026-07-14-daeo-computed-carrier-root-cause.md) corrected the computed-zero hypothesis.

Research note [`1607`](../../../raw/research/1607-2026-07-14-daeo-forwarding-component-final-matrix.md) is the forwarding-component matrix. It closes the named Func `7007` / `7008` / `7010` / `7024` parameter component but leaves a `+32` raw pre-canonical residue.

Research note [`1608`](../../../raw/research/1608-2026-07-14-daeo-grouped-signature-reuse-final-matrix.md) is current after grouped-signature reuse. With explicit native SHA-256 `052744e643849edf18f8987497d04922e41d972ba697789fa97250d25f3684fd`, Binaryen v130, and both DAE normalizers: dedicated is `10000/10000` normalized; regular is `100000/100000` normalized; wasm-smith is `9955` normalized plus `1` cleanup-normalized out of `9956` comparable cases with only the unchanged `44` Binaryen/oracle failures; random-all completes `10000/10000` with `9633` normalized and `367` mismatches under `--no-reduce-mismatches --max-failures 10000`. The random-all failure-directory set is unchanged. Exactly one saved semantic artifact changes: `coverage-forced-portable` case `002853` reduces only `starshine.raw.wasm` by `5` bytes while canonical wasm and WAT remain byte-identical. The established `coverage-forced-portable=243` / `dae-effectful-args=124` measured/source-backed Starshine cleanup-win classification therefore remains valid with aggregate `-110224` raw / `-797486` canonical / `-5465849` WAT deltas. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals. Public optimize, shrink, and `--optimize -O4z` execute DAEO exactly once immediately before `inlining-optimizing`. The raw type-section residue is closed as a measured Starshine win; DAEO remains open for the `+12335` canonical artifact gap and pre-slot large scheduled blockers.
