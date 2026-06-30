# Tuple Optimization Batched Root Removal

Date: 2026-06-29

## Question

Can the simple pure/drop-only source elision path avoid per-group `local.set -> nop` replacement and the later full `prune-nops` cleanup by collecting removable source roots and removing them in one post-rewrite region pass?

## Change Kept

The kept implementation adds a TO rewrite cleanup plan that records source `local.set` definitions eligible for deferred root removal. For the already-narrow pure/drop-only source elision contract, root `local.set` definitions are no longer rewritten to temporary `nop`s per group. Instead, TO records their node ids, skips per-group mutation marking when all work is deferred, and the post-rewrite cleanup removes recorded roots in a single region traversal. When the rewrite did not generate any temporary nops, that same traversal also prunes existing nops so the old cleanup behavior is preserved without emitting the separate `prune-nops` phase.

The change intentionally stays inside the current narrow elision surface: simple two-lane `i32, i64` type-indexed block source groups with pure payload lanes and only direct-drop lane uses. Other rewrite families still use the existing temporary-nop cleanup path.

## Red-First Coverage

Added `tuple-optimization batched root removal skips nop prune for pure drop-only elision` in `src/passes/tuple_optimization_wbtest.mbt`.

Observed failures before the kept implementation:

- Before root-removal batching, the test failed because no `cleanup-post-rewrite:remove-elided-drop-only-roots` timer existed and the pure/drop-only fixture still emitted `cleanup-post-rewrite:prune-nops`.
- After initial batching but before mutation-mark skipping, the same test was tightened and failed with `3 != 1` because two source groups plus cleanup emitted three `pass[tuple-optimization]:mutated` trace lines. The kept follow-up now emits one mutation marker for the batched cleanup in that fixture.

## Validation

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*batched root removal*'` — failed before implementation as described, then passed `1/1`.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` — passed `53/53`.
- `moon test src/passes` — passed `3608/3608`.
- `moon build --target native --release src/cmd` — passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-batched-root-removal --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` — compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, Binaryen cache `1000/0`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-batched-root-removal --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures` — stopped at the known raw-mismatch cap after `80/100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80/0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. This lane remains inside the previously documented narrow scalar-spelling residual surface; this slice did not broaden that classification.
- `moon fmt && git diff --check` — passed.

## Candidate-Heavy Performance

Command pattern:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-batched-root-removal-markskip \
  --timing-only --tuple-optimization
```

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | 0.845ms | 0.033ms |
| 500 | 7.000ms | 0.163ms |
| 1000 | 19.080ms | 0.300ms |
| 2000 | 70.095ms | 0.912ms |

Compared with the previous aggregate-rewrite-timer slice (`1.170ms`, `7.932ms`, `24.379ms`, `78.062ms` for 100/500/1000/2000), this is a kept improvement at every measured size, but it is still far outside the pass-local target.

1000-pair detail totals after this slice:

- `rewrite-use-def-build`: `4.484ms`
- `ensure-split-locals`: `1.982ms`
- `rewrite-group-defs`: `5.661ms`
- `rewrite-group-defs:source`: `5.307ms`
- `rewrite-group-defs:elide-simple-drop-only-source`: `1.731ms`
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `0.740ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots`: `4.670ms`
- `cleanup-post-rewrite`: `4.913ms`

Interpretation: the pass-level root-removal batch and mutation-mark skip moved the pure/drop-only source replacement overhead down substantially (`replace-defs` from about `4.541ms` to `0.740ms` at 1000 pairs) and removed thousands of mutation trace lines. The remaining cleanup scan itself is still a significant owner, and total TO performance remains a closeout blocker.

## Remaining Work

- Continue TO performance work. Current 1000-pair owners are the batched root-removal cleanup traversal (`~4.7ms`), rewrite-time use-def build (`~4.5ms`), source rewrite (`~5.3ms`), split-local preparation (`~2.0ms`), and build-rewrite-mask (`~0.9ms`).
- The dedicated `tuple-optimization-all` profile remains raw-red in the known narrow scalar-spelling family. Do not broaden the Starshine-win classification without fresh diff inspection and measured evidence.
- Final TO audit closeout remains incomplete: refreshed general/direct lanes, exact-slot/neighborhood evidence, full required closeout ladder, and 100k lane(s) are still pending.
