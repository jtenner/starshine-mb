---
kind: workflow
status: supported
last_reviewed: 2026-07-17
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ./transform-family-inventory.md
---

# SimplifyLocals family fuzzing profiles

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
