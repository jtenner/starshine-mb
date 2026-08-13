---
kind: workflow
status: supported
last_reviewed: 2026-07-28
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
  - ../../../../../src/validate/gen_valid_simplify_locals.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ./transform-family-inventory.md
---

# SimplifyLocals family fuzzing profiles

## Guarded SIMD rotate probe — 2026-08-13

After adding the full-pass raw rewrite for complementary split `i32x4` rotate temporaries, a 1,000-case `simplify-locals-all` probe used the explicit native release CLI and verified Binaryen-v131 oracle. It requested `1000`, compared `689`, and reported `500` normalized matches plus `189` residuals, with zero validation, property, and generator failures. The `311` command failures were Binaryen failures on every selected `simplify-locals-family-coverage` case.

All `189` comparable residuals selected the pre-existing `simplify-locals-structure-result` family and were 2..4 canonical bytes larger in Starshine, aggregate `+571`. No new residual family was attributable to the SIMD rewrite. This is focused development evidence only; it does not replace the required four-lane closeout matrix or reclassify the known structure-result debt as acceptable.

Artifacts: `.tmp/pass-fuzz-simplify-locals-simd-rewrite-1000`.

## Live-out repair refresh — 2026-08-12

Native SHA-256 `443fa73acbe3789b0e1b330fdf28652fe5f567c4e6df53470e46217b65b92d47` ran the dedicated `simplify-locals-all` aggregate against the verified Binaryen-v131 oracle at `.tmp/pass-fuzz-simplify-locals-liveout-final-443fa73-dedicated-10000-v131-20260812`. The lane compared `10000/10000`: `5000` normalized matches and `5000` deterministic structural residuals, with zero validation, property, generator, or command failures.

Agent inspection classifies the residuals as two existing generated shape families, not failures attributed by the harness:

- `3125` `simplify-locals-family-coverage` cases are fourteen canonical bytes smaller in Starshine, aggregate `-43,750`.
- `1875` `simplify-locals-structure-result` cases are `2..4` canonical bytes larger in Starshine, aggregate `+5,615`, because Starshine retains one generated `nop` per function around the result-structure/drop shape.

The net canonical residual delta is `-38,135` bytes. The second family is output-shape debt and is **not** an approved Starshine win: the outputs validate and the shape was present in the prior aggregate, but Starshine is larger and should align to Binaryen unless a future measured benefit proves otherwise. This refresh followed the structured-child live-out repair for the late SGO-owned SimplifyLocals wave; it does not replace the earlier five-variant renewal or claim runtime coverage for generated inputs.

## Binaryen-v131 profile refresh — 2026-07-27

All lanes used official `wasm-opt version 131 (version_131)` and the explicit native release binary `_build/native/release/build/cmd/cmd.exe` (SHA-256 `5935985cb02530a77aba751dd88f0103a3eadc6ada8e4a0c0b040c878ba4e5bf`).

| Variant | Refreshed aggregate (`10000`, seed `0x5eed`) | Canonical size classification | Idempotence (`1000`, seed `0x1d3a`) |
| --- | --- | --- | --- |
| `simplify-locals` | `7298` exact, `2702` differences | all smaller, `-8..-4` bytes | `1000/1000` |
| `simplify-locals-notee` | `2766` exact, `7234` differences | all smaller, `-54..-4` bytes | `1000/1000` |
| `simplify-locals-nostructure` | `7115` exact, `2885` differences | all smaller, `-12..-8` bytes | `1000/1000` |
| `simplify-locals-notee-nostructure` | `2766` exact, `7234` differences | all smaller, `-54..-10` bytes | `1000/1000` |
| `simplify-locals-nonesting` | `7684` exact, `2316` differences | all smaller, `-6..-2` bytes | `1000/1000` |

Every aggregate completed `10000/10000` comparisons with zero validation, property, generator, or command failures. The no-structure count intentionally supersedes the older exact-profile result: Starshine now removes pure `local.get; drop` observations and the local writes that become dead, preserving effects and validity while saving bytes.

The full-pass random-all regression corpus was also replayed against every one of its prior `2433` mismatches. `81` now match exactly; the remaining `2352` contain `2262` smaller and `90` equal-size Starshine outputs, with zero larger outputs, validation failures, property failures, or command failures. This replay specifically closes the former `175` size-losing cases and the later narrowed `63` cases.

The broad aggregate profiles exercise every pre-existing registered leaf. The July 28 follow-up adds a deterministic `simplify-locals-family-coverage` leaf for the source-owned `SL-01` through `SL-35` inventory and includes it in all five aggregates. New focused binary-path tests retain the discovered return-suffix and branch-result carrier witnesses.

## Deterministic source-family coverage — 2026-07-28

The `simplify-locals-family-coverage` leaf emits one dense valid module spanning all 35 source-owned transform rows. It covers repeated-local cycles, structured carriers, no-tee/no-structure policy, effects, `try_table`, transparent copy chains, and nondefaultable references. The follow-up repairs structure formation in walker postorder, preserve Hot IR value/label ownership, lower payload-bearing `br_if` statements without spill locals, restore aggregate first-cycle deferral, distinguish direct copies from refined fallthrough equivalence, and keep variant gates explicit.

This deterministic leaf complements the larger 10,000-case aggregate and measured-win evidence above: it is a reproducible interaction probe, while the broad lanes remain authoritative for the integrated pass's stronger pure-drop and dead-local cleanup classifications.

The post-rebase integrated native binary completed five fresh 100-case lanes with zero validation, property, generator, or command failures:

| Variant | Result | Classification |
| --- | --- | --- |
| `simplify-locals` | `100/100` differences, uniformly `-14` encoded bytes | measured stronger dead-local/pure-drop cleanup |
| `simplify-locals-notee` | `100/100` differences, uniformly `-1` encoded byte | measured dead aggregate-copy observation cleanup |
| `simplify-locals-nostructure` | `100/100` differences, uniformly `-3` encoded bytes | measured transparent-copy/pure-drop cleanup |
| `simplify-locals-notee-nostructure` | `100/100` exact normalized matches | exact |
| `simplify-locals-nonesting` | `100/100` exact normalized matches | exact |

The three differing lanes retain effects and trap order while deleting only local carrier traffic or pure dropped reads. They are the same measured-win policy already established by the larger v131 aggregate and random-all evidence, not new parity gaps. Artifacts are `.tmp/pass-fuzz-simplify-locals-v131-family-post-rebase-final-100`, `.tmp/pass-fuzz-simplify-locals-notee-v131-family-post-rebase-final-100`, `.tmp/pass-fuzz-simplify-locals-nostructure-v131-family-post-rebase-final-100`, `.tmp/pass-fuzz-simplify-locals-notee-nostructure-v131-family-post-rebase-100`, and `.tmp/pass-fuzz-simplify-locals-nonesting-v131-family-post-rebase-100`.

## Canonical aggregate profiles

Every Binaryen public variant now has a direct aggregate GenValid name:

| Pass | Aggregate profile |
| --- | --- |
| `simplify-locals` | `simplify-locals` / `simplify-locals-all` |
| `simplify-locals-notee` | `simplify-locals-notee` / `simplify-locals-notee-all` |
| `simplify-locals-nostructure` | `simplify-locals-nostructure` / `simplify-locals-nostructure-all` |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure` / `simplify-locals-notee-nostructure-all` |
| `simplify-locals-nonesting` | `simplify-locals-nonesting` / `simplify-locals-nonesting-all` |

Compatibility pass spellings resolve to their canonical aggregate where applicable.

## Shared family leaves

The four newly covered aggregates select from:

- `simplify-locals-local-traffic`;
- `simplify-locals-structure-result`;
- `simplify-locals-flat-parent`;
- `simplify-locals-effect-order`;
- `simplify-locals-stress`.

The established no-structure aggregate retains its existing straight-line, tee-control, and effect-order leaves for replay continuity.

The body generator now emits dedicated structure-result and nonesting parent-position slices instead of falling through to the broad SSA matrix. Effect/stress leaves deliberately keep memory and global barriers while excluding random calls, function-result tails, and table/reference/tag shapes that obscured the intended pass family or exceeded the installed Binaryen oracle's decoding surface. Call barriers remain covered by focused tests and the regular generator lane.

## Red-first evidence

The aggregate/profile test was added before the constructors and failed to compile for all nine new leaf/aggregate constructors. After implementation, `gen_valid_tests.mbt` passes `150/150` and proves canonical resolution, composite membership, and feature envelopes.

## Initial profile audit

The first profile-backed compare runs successfully generated valid modules and removed the earlier generic-profile validation/unsupported-heap failures. They also exposed real residual families rather than being declared green:

- structure-enabled output-shape differences around redundant arm blocks/nops;
- effect-order gaps where Binaryen moves or clones local carriers across read-only loads and later consumers;
- no-tee fresh-local spill differences on repeated-local flat-parent shapes;
- dead effectful local-write cleanup differences in nonesting;
- one no-structure canonical wrapper difference.

The profile was then narrowed to void, family-owned bodies and rerun with Node runtime execution. Across five 100-case canonical lanes, every residual mismatch was strictly smaller in canonical Starshine wasm, with zero runtime semantic mismatches. The residual families are therefore classified as measured Starshine wins for these leaves: redundant structure-arm block/nop removal and stronger dead local-write cleanup that preserves effect/trap execution as `drop`. The no-structure lane reached raw parity on one 100-case run and had one `-3` byte Starshine-win cleanup on the independent runtime run.

## Smoke command

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <canonical-pass> --count 1000 --seed <seed> \
  --gen-valid-profile <canonical-pass> --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-<canonical-pass>-profile-1000
```

## Final 2026-07-17 closeout

All commands used the explicit native release binary, `--jobs auto`, default caches, and the required seeds.

| Variant | Regular GenValid (`100000`, `0x5eed`) | wasm-smith (`10000`, `0x5eed`) | Dedicated (`10000`, `0x5eed`) | Random all profiles (`10000`, `0x5555`) |
| --- | --- | --- | --- | --- |
| full | `100000` matches | `6718/6719`, `1` measured win | `7298` matches, `2702` measured wins | `5915/8983`, `3068` classified differences |
| no-tee | `100000` matches | `6718/6719`, `1` measured win | `2766` matches, `7234` measured wins | `5915/8983`, `3068` classified differences |
| no-structure | `100000` matches | `6718/6719`, `1` measured win | `10000` matches | `7160/8983`, `1823` classified differences |
| no-tee/no-structure | `100000` matches | `6718/6719`, `1` measured win | `4572` matches, `5428` measured wins | `6215/8983`, `2768` classified differences |
| nonesting | `100000` matches | `6719/6719` matches | `7684` matches, `2316` measured wins | `8018/8983`, `965` classified differences |

Every lane had zero validation, property, generator, and Starshine command failures. The wasm-smith lane's shared `3281` command failures were Binaryen/tool decode failures: `2967` generic parser failures, `226` bad-section-size failures, `39` empty-rec-group failures, `48` table-index failures, and `1` invalid-type-index failure. Random-all's shared `1017` failures were Binaryen parser rejection of `coverage-forced-portable` table encodings.

Dedicated-profile selected-leaf counts were nonzero for every member. Full and no-tee selected `2766/1770/2702/1863/899` local-traffic/effect/structure/flat/stress cases; no-structure selected `4290/2885/2825`; no-tee/no-structure selected `2766/1770/1806/2759/899`; nonesting selected `3107/1523/1546/3031/793` local/effect/structure/flat/stress cases.

### Residual classification

No residual is a true semantic mismatch or an unmeasured size regression.

- Dedicated residuals are strictly smaller Starshine outputs. They remove redundant result-arm blocks/nops, clone only proven constants in nesting-enabled no-tee modes, and replace zero-read effectful writes with effect/trap-preserving drops.
- Random-all residuals are confined to deterministic SSA, coalesce-locals, and local-subtyping leaves. Starshine is strictly smaller except full `ssa-nomerge-parity`, where canonical sizes are equal; that family has `43` Starshine IR nodes versus `45` Binaryen nodes and converges to equal `-Oz` (`35` bytes) and vacuum-cleaned (`122` bytes) output.
- The one comparable wasm-smith residual removes an unreachable result block while preserving the same `memory.size`, constant evaluation, and final trap; Starshine is `5` bytes smaller.
- Five independent 100-case Node lanes reported zero runtime semantic mismatches. Final idempotence lanes compared `1000/1000` cases per variant with zero property failures.

### O4z neighborhood and rerun proof

The exact `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood completed both ordinary and pass-owned `10000`-case lanes. The ordinary lane had `4200` raw matches and `5800` strictly smaller Starshine outputs (`-510..-123` bytes). The dedicated lane had `10000` strictly smaller Starshine outputs (`-48..-4` bytes). The per-variant idempotence lanes prove the shared implementation reaches the same fixed point when rerun.

### Timing

Representative pass-local timings meet the repository's `Starshine <= 2 * Binaryen` target using medians where microsecond noise was material: full about `1.75x`, no-tee about `1.98x`, no-structure `0.82x`, no-tee/no-structure about `1.53x`, and nonesting about `1.11x`. Whole-command Starshine time was faster in every timing replay.

The family is closed under the current behavior-parity contract. Reopen only for a new source-owned transform family, a true semantic mismatch, a validation failure, or a measured output/performance regression.
