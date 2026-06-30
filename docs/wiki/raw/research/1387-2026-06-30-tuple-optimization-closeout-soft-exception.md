# Tuple Optimization Closeout And Soft Performance Exception

Date: 2026-06-30

## Scope

This note records the closeout evidence gathered after the direct root fast-path slice for the `tuple-optimization` (`TO`) O4z audit. It covers full compare-pass lanes, the remaining dedicated-profile raw mismatch classification, pass-local timing, the accepted soft performance exception, and exact-slot/neighborhood evidence available in this workspace.

## Commands and results

Validation ladder:

- `moon info` completed with existing warnings only.
- `moon fmt` completed.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` passed `56 / 56`.
- `moon test src/passes` passed `3611 / 3611`.
- `moon test` passed `6991 / 6991`.
- `moon build --target native --release src/cmd` completed; native Starshine was used from `_build/native/release/build/cmd/cmd.exe`.

Full compare-pass lanes:

- Regular GenValid: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-100000-closeout-20260630 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Compared `100000 / 100000`; normalized matches `100000`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `1314` hits / `98686` misses.
- Wasm-smith: `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-wasm-smith-10000-closeout-20260630 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Compared `9956 / 10000`; normalized matches `9955`; raw mismatches `1`; validation/generator/property failures `0`; command failures `44`; wasm-smith cache `10000 / 0`; Binaryen cache `106` hits / `9850` misses; Binaryen failure cache `0` hits / `44` misses.
  - Command-failure classes: `binaryen-rec-group-zero` `39`, `binaryen-invalid-tag-index` `1`, `binaryen-table-index-out-of-range` `1`, `binaryen-bad-section-size` `3`.
  - The only raw mismatch is `case-009332-wasm-smith`, an unreachable/drop debris difference: Binaryen removes a `drop (unreachable)` before a following `unreachable`; Starshine leaves the dropped unreachable. Input effect/trap facts record `hasUnreachable=true` and `mayTrap=true`, with no calls or memory/table/global/exception/atomic effects. This is not a TO tuple-carrier family.
  - A confirming normalized rerun, `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-wasm-smith-10000-closeout-20260630-unreachable-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --normalize unreachable-control-debris`, compared `9956 / 10000`, had normalized matches `9955`, compare-normalized matches `1`, command failures `44`, and raw mismatches `0`.
- Dedicated TO profile: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-all-10000-closeout-20260630 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 12000 --keep-going-after-command-failures`
  - Compared `10000 / 10000`; normalized matches `0`; raw mismatches `10000`; validation/generator/property/command failures `0`; Binaryen cache `10000 / 0`.
  - Selected/profile-case counts: spill `5030`, tee `1674`, copy-chain `3296`.
  - Input effect/trap counts are all zero across the lane: no calls, memory/table/global mutation, exceptions, atomics, unreachable, or possible traps.
- Random all-profiles GenValid: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass tuple-optimization --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-random-all-profiles-10000-closeout-20260630 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 12000 --keep-going-after-command-failures`
  - Compared `10000 / 10000`; normalized matches `10000`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `642` hits / `9358` misses.
  - Selected profiles: `binaryen-oracle-portable` `1958`, `ssa-nomerge-smoke` `1973`, `coverage-forced-portable` `2037`, `ssa-nomerge-parity` `1970`, `pass-fuzz-stress` `2062`.

Dedicated-profile residual measurement over all `10000` failure dirs:

- `tuple-optimization:spill` (`5030` cases): Starshine is uniformly `-22` raw wasm bytes, `-279` printed WAT bytes, `-4` local declarations, and `-11` effective WAT ops versus Binaryen.
- `tuple-optimization:tee` (`1674` cases): Starshine is uniformly `-20` raw wasm bytes, `-266` printed WAT bytes, `-4` local declarations, and `-10` effective WAT ops versus Binaryen.
- `tuple-optimization:copy-chain` (`3296` cases): Starshine is uniformly `-20` raw wasm bytes, `-306` printed WAT bytes, `-6` local declarations, and `-10` effective WAT ops versus Binaryen.

Pass-local performance, direct candidate-heavy fixtures:

- `bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260630-closeout-soft --timing-only --tuple-optimization`
  - `100` pairs: Starshine/Binaryen pass `0.122ms / 0.037ms`.
  - `500` pairs: `0.460ms / 0.148ms`.
  - `1000` pairs: `0.892ms / 0.301ms`.
  - `2000` pairs: `1.705ms / 0.580ms`.
  - These still miss the formal `<= 2x Binaryen` pass-local target, but the absolute direct-pass cost is microsecond/sub-millisecond at up to `1000` pairs and low-millisecond at `2000` pairs.
  - Latest `1000`-pair detail owners: direct validation `493us`, single-root-region proof `480us`, targeted root cleanup `367us`, direct fast path `497us`, simple fast path `386us`, pass total `892us`.

Exact-slot/neighborhood evidence:

- The large historical debug artifact `tests/node/dist/starshine-debug-wasi.wasm` is absent in this workspace, so the old full-artifact exact-slot replay could not be refreshed here.
- The available exact-slot neighborhood was refreshed on the synthetic candidate-heavy fixture: `bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-1000.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/to-exact-slot-candidate-heavy-1000-20260630 --code-pushing --tuple-optimization --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs`.
  - Canonical wasm equal: `no`; normalized WAT text equal: `no`; normalized WAT equal: `yes`; canonical function compare equal: `yes`.
  - Starshine/Binaryen whole command: `21.281ms / 26.194ms`; Starshine at least as fast: `yes`.
  - Starshine/Binaryen pass-local: `0.987ms / 6.563ms`; Starshine pass at least as fast: `yes`.

## Classification

The regular GenValid lane and random all-profiles lane are green with zero mismatches/failures.

The wasm-smith lane has no tuple-carrier residual. Its one raw mismatch is classified as unreachable-control debris outside TO's tuple-local behavior surface, confirmed by the `--normalize unreachable-control-debris` rerun reducing it to a compare-normalized match. The command failures are Binaryen/tool failures in already-known wasm-smith parser/canonicalization families, not Starshine semantic mismatches.

The dedicated `tuple-optimization-all` lane is intentionally raw-red. All `10000` cases are the known simple type-indexed pure/drop-only tuple-carrier surface with zero side-effect/trap facts. Both Binaryen and Starshine scalarize away the tuple carrier, but Starshine keeps a compact scalar spelling that is uniformly smaller and uses fewer locals/effective operations than Binaryen across every sampled spill, tee, and copy-chain case. This remains a narrow measured Starshine-win family, not a general license to accept arbitrary TO drift. Reopen if a future case includes effects, traps, non-drop lane uses, raw Starshine tuple/block carrier debris, raw/text/local/op regressions, broader unproven types/lane counts, runtime semantic differences, or Binaryen source drift.

## Soft performance exception

The direct candidate-heavy fixtures still miss the formal pass-local target. Reasonable TO-owned optimization attempts have now removed the major repeated-analysis and rewrite costs: use-def-bounded root lookup, drop-only elision, detached replacement deletion, root-removal experiment rejection, cleanup fast-skips, aggregate timers, batched/targeted root removal, rewrite use-def reuse, elision masks, source/no-copy/payload fast paths, no-tee/no-new-local/no-scalarized cleanup fast paths, local-set root elision, no-result/no-scalar/no-copy link skips, simple root-elision, pre-collect validation, and the final direct no-seed-group allocation recognizer.

The remaining measured owners are mostly the minimum whole-root validation and one root-region filtering pass needed to safely remove roots. Further attempts are diminishing-return and correctness-sensitive. Per the user's 2026-06-30 caveat, TO is soft-accepted on performance despite missing the formal `<= 2x Binaryen` target, with this evidence and the residual mismatch classification above.

## Remaining caveat

The historical full debug-artifact exact-slot replay could not be refreshed because `tests/node/dist/starshine-debug-wasi.wasm` is not present in this workspace. The O4z TO closeout therefore uses the available exact-slot neighborhood candidate-heavy replay plus the full direct-pass compare matrix. Recreate the large artifact and rerun the historical exact-slot command if release process requires that specific artifact again.
