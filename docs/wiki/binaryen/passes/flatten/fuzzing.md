---
kind: workflow
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../scripts/test/pass-fuzz-normalization-fixtures.ts
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./implementation-structure-and-tests.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `flatten` Fuzzing Status

## Current state: active and signed off

`flatten` is admitted by the compare harness and has a dedicated `flatten-all` GenValid aggregate. Always compare with an explicitly rebuilt native release binary:

```text
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 --seed 0x5eed --pass flatten \
  --gen-valid-profile flatten-all \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --normalize local-cleanup-debris \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-flatten
```

The three normalizers are part of the documented compare contract:

- `local-cleanup-debris` removes Binaryen local-copy/forwarding preludes, adjacent one-use producer temporaries, rich reference producer temporaries, untargeted void block shells, unused local declarations, and local/label numbering differences.
- `unreachable-control-debris` removes structurally dead control shells around guaranteed unreachable paths.
- `drop-consts` removes pure dropped constants that Binaryen retains before guaranteed `unreachable` while Starshine deletes them.

These normalizers do not waive semantic differences. Their exact families have fixtures in [`scripts/test/pass-fuzz-normalization-fixtures.ts`](../../../../../scripts/test/pass-fuzz-normalization-fixtures.ts). The two final wasm-smith cases needing `drop-consts` are downstream-size nonregressing under matched `--vacuum --dce`: one is 71 Starshine bytes versus 72 Binaryen bytes, and one is 62 bytes on both sides.

## Final 2026-07-17 matrix

All rows used the current rebuilt native binary and the three normalizers above.

| Lane | Requested | Compared | Command failures | Validation failures | Mismatches |
| --- | ---: | ---: | ---: | ---: | ---: |
| default GenValid | 10,000 | 10,000 | 0 | 0 | 0 |
| `flatten-all` | 10,000 | 10,000 | 0 | 0 | 0 |
| random all profiles | 10,000 | 8,596 | 1,404 Binaryen failures | 0 | 0 |
| wasm-smith | 10,000 | 6,719 | 3,281 Binaryen failures | 0 | 0 |
| idempotence | 1,000 | 1,000 | 0 | 0 | 0 property failures |

The idempotence lane matched all 1,000 checked cases. The random-profile command failures are all Binaryen failures. The wasm-smith command failures contain no Starshine failures: 2,967 generic Binaryen failures, 226 bad-section-size failures, 39 zero-sized-rec-group failures, 48 table-index failures, and one invalid-type-index failure.

Artifact directories:

- `.tmp/pass-fuzz-flatten-final2-default-10000`
- `.tmp/pass-fuzz-flatten-final2-all-10000`
- `.tmp/pass-fuzz-flatten-final2-random-10000`
- `.tmp/pass-fuzz-flatten-final2-wasm-smith-10000`
- `.tmp/pass-fuzz-flatten-final2-idempotence-1000`

A prior default lane compared 100,000/100,000 cases with zero mismatches. The current-binary 10,000-case matrix is the normative signoff because it includes the final polymorphic-unreachable validation repair.

## Validation discrepancy found by wasm-smith

The first wasm-smith run found two Starshine validation failures among command failures. Both involved stack-polymorphic unreachable tails whose incidental transformed type differed from the declared control or function result type. A further focused reference test reproduced the same problem with `externref` versus `funcref`.

The red-first repair now:

- preserves equal or validator-proven subtype flow;
- drops incompatible dead tail values;
- materializes the declared defaultable result through its own typed temporary;
- uses the pass module context for reference subtype checks.

Focused coverage includes function, block, if, loop, numeric, and reference cases. The original wasm-smith inputs now lower and validate with `wasm-tools --features all`.

## `flatten-all` coverage

The aggregate samples portable scalar/control, stress, SSA, GC, reference/subtyping, local-coalescing, and call/convergence families by composing these profiles:

- `binaryen-oracle-portable`
- `pass-fuzz-stress`
- `ssa-nomerge-smoke`
- `heap2local-struct`
- `local-subtyping-straight-line`
- `coalesce-locals-structured`
- `dae-convergence`

Profile selection and family coverage are tested in [`src/validate/gen_valid_tests.mbt`](../../../../../src/validate/gen_valid_tests.mbt).

## Classification rule

Treat any future raw mismatch as open until it is classified with inspected artifacts, validation, semantic reasoning, and relevant size/downstream evidence. Do not call a difference safe merely because both outputs validate or one output is smaller.

The detailed discovery and repair record is [`docs/wiki/binaryen/passes/flatten/index.md`](./index.md).
