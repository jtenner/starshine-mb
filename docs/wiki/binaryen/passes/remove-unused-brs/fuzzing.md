---
kind: workflow
status: working
last_reviewed: 2026-08-31
sources:
  - ../../../raw/research/1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_remove_unused_brs_tests.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes_perf_long/remove_unused_brs_perf_test.mbt
---

# `remove-unused-brs` Fuzzing Profile

## 2026-08-31 shared HOT lower performance renewal

The explicit current native binary compared `10000/10000` regular GenValid cases with `--normalize local-cleanup-debris --normalize unreachable-control-debris`, `--jobs auto`, and `--max-subprocesses 8`: all `10000` are compare-normalized matches, with zero mismatches, validation failures, property failures, generator failures, or command failures. Starshine is canonically smaller in all `10000` cases: `41,528,182` versus Binaryen `42,007,429` bytes. Evidence: `.tmp/pass-fuzz-rub-hot-lower-20260831/`.

The new Moon component benchmark attributes the 3,000-block literal-multivalue fixture to shared HOT lowering rather than the RUB transform. Across five matched framework runs, the clean-HEAD/current median moves from `1120.00ms` to `10.38ms` for HOT lower (`-99.073%`, `107.900x`) and from `1260.00ms` to `22.10ms` end to end (`-98.246%`, `57.014x`). The optimization precomputes used labels once and skips future-root scans for roots without calls or local reads. The canonical production artifact remains byte-identical and timing-neutral before/after; current medians are `1127.151ms` no-trace command and `132.625ms` pass-local versus Binaryen `825.015ms` process and `303.228ms` pass-local.

## 2026-08-26 bounded safety renewal

Native SHA-256 `d7921ee49c6781c10f3388e7f594dd67445587d767ef4db3d37107045e93886b` and official Binaryen v131 compared `10000/10000` regular GenValid cases with `--normalize local-cleanup-debris --normalize unreachable-control-debris`: `278` direct plus `9722` cleanup-normalized matches, zero residual mismatches, and zero validation/property/generator/command failures. Canonical size is a Starshine win in every non-exact case: `9722` smaller, `278` equal, `0` larger; totals are `41,528,182` Starshine versus `41,662,491` Binaryen bytes. This confirms the apparent raw drift was exactly the already reviewed empty-control/local-debris family rather than an open parity gap.

The lane used `--jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20`; no mismatch bundles were needed because all cases matched directly or through the documented normalizers. Evidence: `.tmp/optimizer-fixes-20260826/post-rebase/remove-unused-brs/`.

## 2026-07-31 condition-preservation review reclose

The repaired pass uses native Starshine SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174`, official `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`, and the `drop-consts` plus `unreachable-control-debris` normalizers.

| Lane | Result | Classification |
| --- | --- | --- |
| Regular GenValid, count `100000`, seed `0x5eed` | `14604` direct plus `85396` cleanup-normalized | Zero residuals or failures. |
| wasm-smith, count `10000`, seed `0x5eed` | `9954` direct plus `2` cleanup-normalized across `9956` comparable | Zero Starshine failures; 44 Binaryen-only cached parser/tool failures. |
| `remove-unused-brs-all`, count `10000`, seed `0x5eed` | `7251` direct, `404` cleanup-normalized, `2345` residuals | Every residual is a strictly smaller Starshine cleanup, range `-51..-1`, total `-51852` bytes; zero ties or losses. |
| Random all-profiles, count `10000`, seed `0x5555` | `7669` direct, `1595` cleanup-normalized, `736` residuals | Every residual is smaller, range `-49..-1`, total `-3638` bytes; zero ties or losses. |

Dedicated residuals are exactly the source-backed GC, sink-block, switch, cleanup, control, and literal multivalue-drop families. Random-all residuals add the established unread-tee and terminal-return wins. Focused Node runtime separately confirms that call/global mutation, `local.tee`, out-of-bounds load, and division-by-zero conditions are evaluated before the common branch. There are zero Starshine validation, generator, property, or command failures and zero true semantic mismatches.

The 2026-07-31 closeout measured `595.227ms` Starshine and `294.046ms` Binaryen pass medians, a marginal `2.024x` relative-floor miss. The completed 2026-08-01 speedup slice preserves the reviewed artifact bytes and now measures `227.250ms` Starshine versus `289.650ms` Binaryen (`0.785x` by independent medians, `0.780x` paired median), a `61.8%` Starshine pass improvement and about `1.27x` Binaryen throughput. Whole-command median falls from about `11.565s` to `3.328s` (`71.2%`), and the current 3,000-block native pipeline median is `377390us`, `4.5%` below the prior `395298us` result. This performance re-sign is a maintainer-approved bounded closeout rather than a replacement full matrix. Near-final `100`-case smokes are regular `13` direct plus `87` cleanup-normalized, wasm-smith `99/99` comparable exact with one Binaryen-only failure, dedicated `72` direct plus `3` cleanup-normalized plus `25` residuals, and random-all `65` direct plus `20` cleanup-normalized plus `15` residuals, with zero Starshine failures. The corrected final binary repeats the dedicated `100/100` result exactly, and a prior-slice dedicated `1000/1000` smoke also had zero failures. Full dedicated attempts timed out at `1713/10000` and `2274/10000`; the 2026-07-31 full matrix remains the behavior baseline, and future output-byte or residual-family drift reopens the pass.

## Historical 2026-07-30 Binaryen v131 closeout

This matrix predates the 2026-07-31 same-target condition-evaluation review. It remains provenance; the refreshed runtime and matrix above supersede its direct closeout status.

The historical native Starshine binary is SHA-256 `e748800660b375c40741181a53aaeaf2dd2c436ddbbfdf6c4ee80834a19e5090`; the explicit official oracle is `wasm-opt version 131 (version_131)`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

- Regular `.tmp/pass-fuzz-remove-unused-brs-closeout-finalhash-regular-100000-20260730`: `100000/100000`, zero mismatches or failures.
- wasm-smith `.tmp/pass-fuzz-remove-unused-brs-closeout-finalhash-wasm-smith-10000-20260730`: `9956/10000` comparable, zero mismatches or Starshine failures, with the established `44` Binaryen/tool malformed-input failures.
- Expanded dedicated `.tmp/pass-fuzz-remove-unused-brs-closeout-finalhash-dedicated-10000-20260730`: `10000/10000`, zero command or validation failures; `2345` residual text shapes are confined to six source-backed cleanup families, and every one is canonically smaller in Starshine, totaling `-51852` bytes.
- Random-all `.tmp/pass-fuzz-remove-unused-brs-closeout-finalhash-random-all-10000-20260730`: `10000/10000`, zero failures; all `736` residuals are smaller Starshine outputs, totaling `-3638` bytes.
- O4z-option direct replay `.tmp/pass-fuzz-remove-unused-brs-closeout-o4z-direct-10000-20260730`: `6853` canonical byte matches plus `3147` strictly smaller Starshine outputs, aggregate delta `-54270` bytes, with zero command failures, equal-size-different-byte outputs, or Starshine-larger outputs. This lane runs only `remove-unused-brs` with `optimize_level=4` and `shrink_level=4`, isolating scheduled pass behavior from unrelated full-preset validity owners.
- Full-preset boundary probe `.tmp/rub-o4z-schedule-validity-1000`: `837` valid outputs and `163` Starshine command failures. The first traced failure becomes invalid in `flatten` before the first RUB application; every later RUB sees the pre-existing stack-underflow state and fails closed. This remains an `[O4Z-PRESET]001` validity blocker separate from the then-reopened, now-reclosed direct RUB condition-preservation gap; placement itself remains closed.

`remove-unused-brs-all` now contains 21 focused leaves. In addition to the prior constant branch, single-target table, multi-function, result-refinalization, multivalue-drop, wrapper, selectification, win-boundary, control, switch, cleanup, and GC families, it covers tail flow, one-arm `if`, loop cleanup, block sinking, EH caught throws, jump-threading, tablification, `local.set`/`local.tee` optimization, restructure-if, and adjacent branch cleanup.

Performance evidence is bounded and explicit. On the skipped native-release 3,000-block literal-multivalue lane, median end-to-end `run_hot_pipeline` time improved from about `609825us` before linear use accounting to `422420us` in the final replay after linear drop-use accounting and the literal-consumer fast path. Nine interleaved traced pass-local samples measure Starshine at `8117us` median versus Binaryen v131 at `12786us`, a `0.635x` ratio (about `1.58x` faster). The current whole-command fixture remains slower (`398426us` versus `14482us` median) because Starshine's decode, HOT lift/lower, validation, and emit path dominates outside the pass timer; that aggregate overhead remains `[WALL]001`, not a RUB-local performance blocker.

## 2026-07-26 post-repair Binaryen v131 renewal

The required matrix used native Starshine SHA-256 `47afafb4d7e26532520e885c21a89cb4c87d9e3651c4f1ce0cc9e3032abf076a`, official `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`, the persistent `.tmp/pass-fuzz-cache`, explicit binary paths, `--jobs auto`, and both `drop-consts` and `unreachable-control-debris` normalizers.

- Regular `.tmp/pass-fuzz-remove-unused-brs-regular-100000-v131-renewal`: `100000/100000` compared, `14604` direct normalized plus `85396` cleanup-normalized, and zero mismatches or failures. Binaryen cache: `314` hits / `99686` misses.
- wasm-smith `.tmp/pass-fuzz-remove-unused-brs-wasm-smith-10000-v131-renewal`: `9956/10000` compared, `9954` direct plus `2` cleanup-normalized, zero mismatches or Starshine failures, and `44` Binaryen-only command failures (`39` empty recursion groups, `3` bad section sizes, `1` invalid tag index, `1` table index out of range). wasm-smith cache: `10000/0`; Binaryen cache: `106/9850`, failure cache `0/44`.
- Dedicated `.tmp/pass-fuzz-remove-unused-brs-dedicated-10000-v131-renewal-noreduce`: `10000/10000` compared and `10000` raw mismatches, with zero command, validation, generator, or property failures. Selected leaves were control `5030`, switch `3296`, and cleanup `1674`. Every Starshine canonical output is larger than Binaryen by `18..140` bytes; aggregate canonical delta is `+538137` bytes. The families contain no calls, mutable global/memory/table effects, exceptions, or atomics, but validity and effect absence do not make the size-losing output drift acceptable parity. Representative diffs retain scratch locals, missed selectification/control folding, broader result types, and dead structured shells that Binaryen removes. Agent classification: **size-losing parity gaps**, superseding the earlier approved-substitute closeout. The first reducer-enabled attempt reached `782` mismatches before a one-hour command timeout; the final full lane used `--no-reduce-mismatches` only to avoid repeating expensive reduction for every generated mismatch.
- Random-all `.tmp/pass-fuzz-remove-unused-brs-random-all-10000-v131-renewal`: `10000/10000` compared, `7281` direct plus `1849` cleanup-normalized, `870` residual mismatches, and zero failures. The `648` `ssa-nomerge-smoke` residuals remove an unread `local.tee` and are uniformly `-2` canonical bytes; the `41` `local-subtyping-unreachable-tail` residuals remove a redundant terminal `return` and are uniformly `-1` byte. Those `689` cases are agent-classified measured Starshine wins. The remaining `181` were open parity gaps: `63` `dae-optimizing-immutable-field` missed safe selectification (`+1` byte), `51` `precompute-control` scratch-local debris (`+6`), `53` `local-subtyping-control-refinalize` missed selectification/result narrowing, and `14` `dae-optimizing-structured-locals` scratch-local debris (`+4`). A smaller canonical encoding alone did not close the control-refinalization family because the Binaryen shape had the stronger result type and no measured Starshine semantic or downstream benefit.

## 2026-07-26 first parity-repair replay

Native Starshine SHA-256 `6f40622612e9b417d1bea7b18d9cba8fbae0b61ce4c7c52e424b8da92bab1d24` adds red-first coverage and narrow repairs for `struct.get`-conditioned pure-ref selectification, direct select lowering without scratch wrappers, exact `ref.i31` arm speculation, equal-arm select typing, and compatible single-result block refinalization. The pass-specific lowerer option preserves default HOT roundtrip behavior and enables unused one-result wrapper removal only for `remove-unused-brs`.

- `.tmp/pass-fuzz-remove-unused-brs-random-all-870-replay-tdd-final` replays every residual from the original random-all lane: `181/870` now match and the remaining `689` are exactly the already classified smaller Starshine unread-tee and terminal-return wins. There are zero validation, generator, property, or command failures.
- `.tmp/pass-fuzz-remove-unused-brs-dedicated-10000-replay-tdd-final` remains `10000/10000` mismatches with zero failures. The canonical delta improves from `+538137` to `+496291` bytes; every output remains larger by `9..136` bytes. This is progress, not signoff.

The original matrix plus these replays verify that the first repair slice retires the known random-all parity gaps without regressing the measured Starshine wins.

## 2026-07-26 dedicated implementation and profile expansion

The next red-first slice identifies the dominant dedicated fingerprint as a whole-function admission bug: multivalue-return functions with ordinary root `local.set` traffic were rejected by `result-local-set-stack-hazard-noop`, leaving their constant carried branches, same-target switches, value `if`s, and wrappers untouched. Root multivalue results are now admitted; nested multivalue carriers and root call/memory stack hazards remain conservatively blocked and retain deterministic tests.

The dedicated profile surface now includes:

- `remove-unused-brs-constant-br-if`
- `remove-unused-brs-single-target-br-table`
- `remove-unused-brs-multi-function`
- `remove-unused-brs-result-refinalize`
- `remove-unused-brs-multivalue-drop`
- `remove-unused-brs-wrapper-cleanup`
- `remove-unused-brs-selectify`
- `remove-unused-brs-win-boundary`

`remove-unused-brs-all` samples the first seven parity leaves together with the prior control, switch, cleanup, and GC stress leaves. The measured-win boundary remains a singleton outside the exact-parity aggregate. `random-all-profiles` now includes `remove-unused-brs-all`. Generator tests validate every focused leaf and its trigger; public pass tests prove the constant-branch, same-target-table, multi-function, multivalue-return, and selectification leaves reach their owned cleanup behavior.

The nested wrapper-cleanup blocker was then repaired with a CFG-backed continuation query. `cfg_region_root_can_reach_next` follows mapped CFG successors and conservatively falls back to the root terminator contract for embedded value-control regions that the function CFG does not map individually. RUB runs a post-transform, postorder sweep that removes only the exact dead filler owned by the focused family: a trailing `unreachable` after a direct return, or after an outward `br` / `br_table` inside an unused inner block that is itself immediately followed by the enclosing result wrapper's unreachable sink. The cutoff root, ordered payload/effect prefix, self-target branches, conditional fallthrough, branch-payload `if` rewrites, and multivalue return ladders remain intact.

Fresh development evidence with native Starshine SHA-256 `124657ff132c6af1132915807eb97c62675a6f71d5fae12b64e7e256c5dd2138` and official `wasm-opt version 131 (version_131)`:

- `.tmp/pass-fuzz-remove-unused-brs-wrapper-cleanup-1000-cfg-prune-final`: `1000/1000` normalized matches, zero mismatches or failures.
- `.tmp/pass-fuzz-remove-unused-brs-dedicated-10000-cfg-prune-final`: `5655/10000` normalized matches and `4345` residuals, with zero validation, generator, property, or command failures. The wrapper-cleanup leaf is `1250/1250` exact; result-refinalize is `625/625`; selectify is `1250/1250`; and single-target-br-table is `1250/1250`.

The former uniformly size-losing dedicated blocker is eliminated. The next lowering slice admits exact type-indexed literal multivalue blocks consumed only by their result drops, then flattens them under RUB's existing opt-in lowering. Raw admission recognizes the adjacent type-indexed-block/two-drop floor, while the HOT proof requires an unused label, zero block parameters, literal result roots matching the result arity, and no users other than the corresponding drops.

Fresh native Starshine SHA-256 `6a7c5b980eb20b7763a4916bc2259b937237b58c6ff6f9361d2697d76a3d786c` evidence:

- `.tmp/pass-fuzz-remove-unused-brs-multivalue-drop-1000-flat`: all `1000` cases are measured Starshine wins, uniformly `-12` canonical bytes, with zero failures.
- `.tmp/pass-fuzz-remove-unused-brs-dedicated-10000-multivalue-flat`: `5655/10000` normalized matches and `4345` residuals, zero failures, and aggregate residual delta `-81681` bytes. All `3125` size-different residuals are now smaller Starshine outputs; the remaining `1220` are equal-sized constant-branch and multi-function reference-typing/output-shape gaps.

The multivalue-drop `+1` blocker is therefore closed as a measured, source-backed Starshine win rather than forced into Binaryen's four-scratch-local shape.

The final dedicated typing slice refinalizes only exact lowered two-instruction null branch blocks: `(ref.null <hierarchy>); br 0`. It rewrites both the block result and `ref.null` immediate to the hierarchy bottom (`nofunc`, `noextern`, `noexn`, `nocont`, or `none`). Requiring an exact two-instruction body intentionally excludes selector-drop prefixes originating from `br_table`, matching Binaryen's distinction while avoiding the earlier invalid HOT-only narrowing.

Fresh native Starshine SHA-256 `c64e283735f273181846a112538b926f1e281a4bc39a7c7a87ccd6b8fe5f28ed` evidence:

- `.tmp/pass-fuzz-remove-unused-brs-constant-br-if-1000-null-refine`: `1000/1000` exact, zero failures.
- `.tmp/pass-fuzz-remove-unused-brs-dedicated-10000-null-refine-v2`: `6875/10000` exact and `3125` residuals, zero failures, aggregate residual delta `-81681` bytes. Constant-br-if, multi-function, result-refinalize, selectify, single-target-br-table, and wrapper-cleanup leaves are all exact. The only residual leaves are control, cleanup, switch, GC, and multivalue-drop; every residual is canonically smaller by `12..51` bytes.

Representative inspection ties the smaller residuals to deterministic, source-backed Starshine behaviors already covered by focused tests: unread `local.tee` elimination, void self-branch block removal, exact wrapper cleanup, literal multivalue flattening, and narrower safe result typing. The dedicated aggregate therefore has no remaining unclassified parity gap, validation failure, or size loss.

## Final 2026-07-26 v131 renewal

All lanes use native Starshine SHA-256 `c64e283735f273181846a112538b926f1e281a4bc39a7c7a87ccd6b8fe5f28ed`, official `wasm-opt version 131 (version_131)`, and the `drop-consts` plus `unreachable-control-debris` normalizers.

- Regular: `.tmp/pass-fuzz-remove-unused-brs-regular-100000-final-renewal`, `100000/100000`, `14604` direct plus `85396` cleanup-normalized, zero mismatches or failures.
- Dedicated: `.tmp/pass-fuzz-remove-unused-brs-dedicated-10000-null-refine-v2`, `6875/10000` direct plus `3125` classified measured Starshine wins totaling `-81681` canonical bytes, zero failures.
- Random-all: `.tmp/pass-fuzz-remove-unused-brs-random-all-10000-final-renewal`, `7028` direct plus `1683` cleanup-normalized and `1289` measured wins, zero failures. Residuals are `625` `remove-unused-brs-control` cleanups (`-20..-34`), `625` `ssa-nomerge-smoke` unread-tee removals (`-2`), and `39` `local-subtyping-unreachable-tail` terminal-return removals (`-1`).
- wasm-smith: `.tmp/pass-fuzz-remove-unused-brs-wasm-smith-10000-final-renewal`, `9956` comparable cases with `9954` direct plus `2` cleanup-normalized, zero mismatches or Starshine failures. The `44` Binaryen-only failures are `39` empty recursion groups, `3` bad section sizes, `1` invalid tag index, and `1` table index out of range.

Runtime execution remained off for that historical matrix, so it is differential/validation evidence rather than exhaustive runtime execution. The 2026-07-30 closeout above supersedes its scheduler caveat: direct behavior and all three v131 RUB slots are now closed.

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-brs --out-dir .tmp/pass-fuzz-remove-unused-brs --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: `remove-unused-brs-all` is the maintained 21-leaf RUB-focused aggregate. Aliases `remove-unused-brs`, `remove-unused-brs-closeout`, `remove-unused-brs-all-profiles`, `rub`, and `rub-closeout` resolve to it, and the selected leaf is recorded in `genValidSelectedProfileCounts`.

Current DAEO-prefix repair status (2026-07-17): note [`1647`](../../../raw/research/1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md) adds rollback-capable changed-function batch validation plus fail-closed multivalue-carrier, nullable-return/non-null-result, and giant-table convergence guards. The final explicit-native regular lane is `10000/10000` with `1520` normalized plus `8480` cleanup-normalized and zero mismatches/failures. The dedicated runtime sample reproduces the accepted `115`-mismatch side-effect-free family with zero validation failures and Node runtime `89` equal results / `26` equal traps / `0` semantic mismatches. Direct current-artifact RUB falls from `580.178s` and invalid output to valid deterministic `3.239s` / `3.068s` repeats; three productive applications reach a byte-identical fixed point.

Current RUB-Q signoff status (2026-06-29): notes [research note 1386](./index.md) and [research note 1387](./index.md) refresh the final-lane status. Completed green lanes include regular GenValid `100000/100000` at `.tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized-rerun-long` (`14604` normalized, `85396` cleanup-normalized, `0` mismatches/failures), regular GenValid `10000/10000` (`1520` normalized, `8480` cleanup-normalized, `0` mismatches/failures), explicit wasm-smith `9956/10000` (`9954` normalized, `2` cleanup-normalized, `0` mismatches, `44` Binaryen/oracle command failures), and broad named `pass-fuzz-stress` `10000/10000` (`1397` normalized, `8603` cleanup-normalized, `0` mismatches/failures). The prior regular `100000` timeout remains only partial/historical evidence.

Historical RUB-Q dedicated-profile closeout used an approved substitute rather than normalized-green output. The 2026-07-26 full v131 lane above supersedes that acceptance because all `10000` current dedicated outputs are canonically larger than Binaryen. The older compact `1000` run at `.tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3` produced `1000` Starshine validation failures before Binaryen comparison (`remove-unused-brs-control=487`, `remove-unused-brs-switch=338`, `remove-unused-brs-cleanup=175`), and note [research note 1388](./index.md) reduced the suffix-loss shape. Note [research note 1389](./index.md) supersedes that validation blocker for current source: the reduced CLI replay validates when using the current `_build/native/release/build/cmd/cmd.exe` binary, the new binary-decode public pipeline regression passes, and current dedicated smokes report `0` Starshine validation failures. The absorbed dedicated-classification probes establish the approved substitute directly: a capped current-binary run compared `115` mismatches with zero validation/generator/property/command failures, while a runtime-enabled sample checked `35/35` as equal (`27` equal results, `8` equal traps). The profile disables calls/imports/memory/table/tag/element/data/tail-call surfaces; sampled effect facts also exclude global/exception/atomic effects. Reduced constant-`br_if` and same-target-`br_table` cases show Starshine deleting dead structured shells that Binaryen leaves. Normalized size favors Starshine in every sampled mismatch (`115/115`, `-12527` bytes; runtime sample `35/35`, `-3832` bytes), though raw size is mixed. RUB-Q was therefore historically closed as an explicit Starshine win under the approved-substitute clause. The fresh full lane has now triggered its own reopening criterion—unaccepted size loss—and direct parity is open again.
