---
kind: workflow
status: working
last_reviewed: 2026-07-18
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ./index.md
---

# `coalesce-locals` Fuzzing Profile

Recommended direct smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass coalesce-locals --out-dir .tmp/pass-fuzz-coalesce-locals --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: use `coalesce-locals-all` for the required pass-specific closeout lane. It is a composite over three deterministic leaves:

- `coalesce-locals-straight-line` — same-typed local copy chains without structured control.
- `coalesce-locals-structured` — bounded block-local copy chains.
- `coalesce-locals-loop-copy-through` — conservative loop-local single-use copy-through shapes.

Aliases accepted by `GenValidConfig::profile(...)`: `coalesce-locals`, `coalesce-locals-closeout`, `coalesce-locals-all-profiles`, `cl`, and `cl-closeout`.

Required dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass coalesce-locals --gen-valid-profile coalesce-locals-all --out-dir .tmp/pass-fuzz-coalesce-locals-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Latest closeout evidence:

- Regular GenValid: `.tmp/pass-fuzz-coalesce-locals-genvalid-100000-structured-scalar-order-final-20260704` requested/compared `100000/100000`, normalized `100000`, zero mismatches/failures, Binaryen cache `100000` hits / `0` misses. This refresh supersedes the earlier green `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-genvalid-100000-20260704` lane.
- Dedicated GenValid profile: `.tmp/pass-fuzz-coalesce-locals-profile-10000-structured-scalar-order-final-20260704` requested/compared `10000/10000`, normalized `10000`, zero mismatches/failures, Binaryen cache `10000` hits / `0` misses. Selected leaves: `coalesce-locals-straight-line=4290`, `coalesce-locals-structured=2885`, `coalesce-locals-loop-copy-through=2825`.
- Explicit wasm-smith: raw `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-20260704` compared `9956/10000`, normalized `9955`, one raw no-local `drop(unreachable); unreachable` cleanup-debris mismatch, and 44 Binaryen/oracle command failures (`binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`). Cleanup-normalized `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-normalized-20260704` with `--normalize unreachable-control-debris` converts the debris case to one compare-normalized match and leaves zero mismatches with the same command failures. The raw debris case remains the documented narrow boundary, not a correctness blocker.
- Random all-profiles: the earlier `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-random-all-profiles-10000-20260704` timed out before `result.json`, and the first diagnostics exposed `163` mismatches (`125` `ssa-nomerge-smoke`, `38` `heap2local-struct`). Concrete-ref direct-`struct.get` packing plus preferred-first GC-ref ordering closed the `heap2local-struct` subfamily; immediate tee/drop cleanup, nested block-escape liveness, label-aware branch/return liveness, tail param reuse, and structured-scalar coloring order then closed the sampled `ssa-nomerge-smoke` family. Replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-structured-scalar-order-final-20260704` normalized all previously active `125/125` residuals. The refreshed diagnostic `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-smoke-1000-structured-scalar-order-final-20260704` compared/normalized `1000/1000`; the required closeout lane `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704` requested/compared `10000/10000`, normalized `10000`, and had zero validation/property/generator/command failures. Selected profile counts in the 10k lane: `coverage-forced-portable=1250`, `ssa-nomerge-parity=1250`, `pass-fuzz-stress=1250`, `binaryen-oracle-portable=1250`, `ssa-nomerge-smoke=1250`, `local-subtyping-straight-line=821`, `heap2local-struct=538`, `coalesce-locals-straight-line=545`, `coalesce-locals-structured=355`, `coalesce-locals-loop-copy-through=350`, `heap2local-array=355`, `heap2local-ref=357`, and `local-subtyping-structured=429`.

Manifest triage: inspect `genValidSelectedProfileCounts` for composite selection and each failure directory's `genValidManifestEntry.selected_profile`. The dedicated profile is expected to exercise local-copy opportunities in every generated case; broad `random-all-profiles` may also select neighboring pass-owned profiles that reveal direct `coalesce-locals` local-declaration cleanup gaps.
