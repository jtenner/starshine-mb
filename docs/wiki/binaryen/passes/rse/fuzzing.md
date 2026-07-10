---
kind: workflow
status: supported
last_reviewed: 2026-07-05
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/rse.mbt
  - ../../../../../src/passes/rse_test.mbt
---

# `rse` Fuzzing Profile

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass rse --out-dir .tmp/pass-fuzz-rse --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Latest refreshed direct smoke evidence:

- 2026-07-04 `.tmp/pass-fuzz-rse-mixed`: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures.

## Dedicated GenValid profile

`rse` is a composite pass-owned profile for redundant-set-elimination closeout. It samples the following leaf profiles and records the selected leaf in the GenValid manifest as `selected_profile`:

| Leaf profile | Weight | Coverage intent |
| --- | ---: | --- |
| `rse-core-same-value` | 3 | same-value `local.set` / `local.tee` shell removal while preserving RHS evaluation |
| `rse-local-copy-self-set` | 2 | local-copy and self-set identity facts, including unknown-value self get/set/tee shells |
| `rse-cfg-merge` | 3 | branch/block merge agreement and disagreement around same-value sets |
| `rse-loop-flow` | 2 | loop-entry/backedge facts, loop-invariant defaults, and same-write loop bodies |
| `rse-refined-get` | 2 | strict-subtype equivalent-local `local.get` retargeting |
| `rse-refinement-wrappers` | 2 | identity-preserving refinement wrappers such as `ref.as_non_null` and `ref.cast` |
| `rse-aggregate-refinalize` | 2 | GC aggregate accessor retarget/refinalization after redundant tee removal |
| `rse-exception-boundaries` | 1 | exception/control boundaries that must not become generic effect deletion |
| `rse-hazard-boundary` | 2 | memory/table/global hazard boundaries while keeping the pass locals-only |
| `rse-vacuum-tail` | 2 | paired RSE cleanup debris that later cleanup passes may remove |

Aliases accepted by the profile parser are `redundant-set-elimination`, `rse-closeout`, `rse-all`, and `rse-all-profiles`.

Recommended closeout lane:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass rse --gen-valid-profile rse --out-dir .tmp/pass-fuzz-rse-profile --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Final closeout matrix refresh on 2026-07-05 with rebuilt `_build/native/release/build/cmd/cmd.exe`:

- Regular GenValid `.tmp/pass-fuzz-rse-genvalid-100000-closeout-20260705`: `100000/100000` compared, `100000` normalized matches, `0` mismatches/failures.
- External wasm-smith `.tmp/pass-fuzz-rse-wasm-smith-10000-closeout-20260705`: `9956/10000` compared, `9955` normalized matches, `44` Binaryen/tool command failures, and `1` raw mismatch. The mismatch is classified as non-RSE unreachable-control debris (`drop(unreachable)` before `unreachable`) from a no-local-candidate input; supplementary `.tmp/pass-fuzz-rse-wasm-smith-10000-closeout-20260705-unreachable-normalized` with `--normalize unreachable-control-debris` reports `1` compare-normalized match and `0` remaining mismatches.
- Dedicated profile `.tmp/pass-fuzz-rse-genvalid-profile-10000-closeout-20260705`: `10000/10000` compared, `10000` normalized matches, `0` mismatches/failures.
- Random all-profiles `.tmp/pass-fuzz-rse-genvalid-random-all-profiles-10000-closeout-20260705`: `10000/10000` compared, `10000` normalized matches, `0` mismatches/failures.

Latest dedicated-profile evidence:

- 2026-07-04 `.tmp/pass-fuzz-rse-profile-4`: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures.
- 2026-07-04 `.tmp/pass-fuzz-rse-tail-rse-only` (`--gen-valid-profile rse-vacuum-tail`): `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures.

## Paired `rse -> vacuum` boundary

The dedicated profile intentionally contains `rse-vacuum-tail` cases because Binaryen often relies on following cleanup to erase debris exposed by same-value set removal. Direct `--pass rse` is green on those cases. Direct `--pass rse --pass vacuum` still exposes inherited Starshine/Binaryen `vacuum` representation/cleanup differences for live local-set debris. Do not close that lane by adding generic dead-store elimination to `rse`; RSE's contract remains same-value local shell removal plus strict-subtype equivalent-local retargeting.
