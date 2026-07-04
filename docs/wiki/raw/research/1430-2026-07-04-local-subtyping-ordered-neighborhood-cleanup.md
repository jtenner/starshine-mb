# Local-subtyping ordered-neighborhood cleanup classification

Date: 2026-07-04

## Question

Can the ordered GC/local neighborhood blocker for `local-subtyping` be reduced from a broad timeout/mismatch blocker into a precise owner classification, without claiming an unmeasured Starshine win?

The ordered neighborhood under review is:

```sh
heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse
```

## Commands and results

All commands used `_build/native/release/build/cmd/cmd.exe` as the explicit Starshine binary.

- Cleanup-normalized 200-case probe:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass heap2local --pass optimize-casts --pass local-subtyping --pass coalesce-locals --pass local-cse --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-200-local-cleanup-20260704 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: requested/compared `200/200`, normalized `18`, cleanup-normalized `182`, mismatches `0`, validation/generator/property/command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `200` hits / `0` misses; Binaryen failures `0/0`.
- Cleanup-normalized 10000-case ordered-neighborhood lane:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --pass optimize-casts --pass local-subtyping --pass coalesce-locals --pass local-cse --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-local-cleanup-20260704 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: requested/compared `10000/10000`, normalized `634`, cleanup-normalized `9366`, mismatches `0`, validation/generator/property/command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `209` hits / `9791` misses; Binaryen failures `0/0`.
  - Manifest profile: `binaryen-oracle-portable=10000`.
  - Input facts: `hasUnreachable=10000`, `mayTrap=10000`, no calls/memory/table/global/exception/atomic facts.

## Relationship to the timed-out raw lane

The prior raw lane `.tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-20260703` used the same ordered pass sequence and seed without normalizers. It timed out after 3600s with only `200` partial cases and `182` mismatch dirs. Sample `case-000001-gen-valid` differed only in local declaration shape after the ordered neighborhood: Binaryen removed or coalesced unused local declarations while Starshine retained extra locals. The 200-case cleanup-normalized probe re-ran that same prefix cardinality and normalized exactly the previous `18` raw matches plus `182` local-cleanup mismatches.

The scaled 10000-case cleanup-normalized lane confirms the raw timeout was dominated by writing and retaining many local-cleanup mismatch artifacts, not by LS semantic failures or command failures.

## Agent classification

Classification: ordered-neighborhood local-cleanup representation residual, not a direct `local-subtyping` semantic mismatch.

Rationale:

- Direct LS lanes remain green for the same current binary: regular 100000 GenValid has zero mismatches/failures, dedicated `local-subtyping-all` has zero mismatches/failures, random-all-profiles has zero mismatches/failures, and explicit wasm-smith has only the separately classified unreachable-control debris case.
- The raw ordered-neighborhood sample drift is local declaration/count cleanup after downstream `coalesce-locals` / `local-cse`, not an observable LS narrowing/get-retagging/dominance/refinalization disagreement.
- The `local-cleanup-debris` normalizer converts the ordered-neighborhood drift to cleanup-normalized matches at both 200 and 10000 cases with zero validation failures and zero remaining mismatches.
- This is not a Starshine win. The sampled raw direction retained extra local declarations in Starshine, so it should remain a local-cleanup/downstream representation owner unless a later slice measures a Starshine benefit or fixes the shape.

## Reopening criteria

Reopen this under `local-subtyping` only if a reduced ordered-neighborhood case shows that a remaining difference depends on at least one LS-owned behavior:

- local declaration narrowing to the wrong heap/nullability type;
- missing or wrong dominance proof for `local.get` / `local.tee` uses;
- broad get/tee expression type retagging after LS narrowing;
- repeated refinalization/reanalysis triggered by LS changes;
- LS-specific interaction with `optimize-casts` output or with `heap2local` reference-local materialization.

Otherwise route raw ordered-neighborhood local declaration/count or trivial local debris drift to `coalesce-locals`, `local-cse`, `reorder-locals`, shared local-cleanup normalization, or encoder/local-declaration cleanup owners.

## Current closeout status

This resolves the broad ordered-neighborhood timeout into a precise cleanup-normalized owner classification for the v0.1.0 LS closeout track. It does not by itself close LS because the final behavior-family review remains open, especially:

- full structural dominance beyond the implemented source-backed subsets;
- broader EH/`try_table` catch/ref post-state and handler flow;
- broader loop backedge/post-state and `if` join/post-state propagation;
- broad `local.get` / `local.tee` expression retagging;
- repeated refinalization/reanalysis;
- the direct block-return nondefaultable-local validator/tooling boundary.
