---
kind: research
status: current
last_reviewed: 2026-06-24
sources:
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/fuzz/main_wbtest.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ./0775-2026-06-20-heap-store-optimization-recursive-handoff-plan.md
  - ./1022-2026-06-21-heap-store-optimization-default-desc-catchable-later-field-result-try-table-store-boundary.md
---

# HSO dedicated GenValid profile

## Summary

Added a dedicated GenValid profile named `heap-store-optimization` for the HSO pass-specific compare lane. The profile emits valid GC modules with deterministic fresh-struct store-fold opportunities:

- a block-local `local.set(struct.new)` followed by `struct.set(local.get, value)`;
- an immediate `local.tee(struct.new)` store;
- a repeated same-field store chain where the final value wins.

The profile also accepts the alias `hso`.

## Validation run in this slice

Commands:

```sh
moon fmt
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt
moon build --target native --release src/cmd
moon run --target native src/fuzz -- --emit-gen-valid-batch --count 1 --seed 0x5eed --out-dir .tmp/hso-profile-emit --gen-valid-profile heap-store-optimization --manifest .tmp/hso-profile-emit/manifest.json --max-attempts 4
wasm-tools validate --features all .tmp/hso-profile-emit/gen-valid-000001.wasm
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-smoke-20-norm --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Results:

- Focused fuzz and validate tests passed.
- Native `src/cmd` build passed with existing `pass_manager.mbt` unused-function warnings.
- A single emitted profile artifact validated with `wasm-tools --features all`.
- The 20-case dedicated-profile compare with `--normalize local-cleanup-debris` compared `20/20`, had `20` compare-normalized matches, `0` raw mismatches after normalization, `0` validation failures, `0` generator failures, and `0` command failures. Binaryen oracle cache showed `20` misses on this first profile run.

## Raw-output drift classification

The same 20-case profile smoke without `--normalize local-cleanup-debris` compared `20/20` and reported `20` raw mismatches. Inspection of case `000001` showed the recurring family: Binaryen retains `(nop)` roots for folded `struct.set`s, while Starshine removes those dead roots entirely. The normalized outputs otherwise align.

Agent classification: Starshine-win cleanup drift, not a semantic mismatch. Removing pass-created nops is smaller canonical output and preserves validation/behavior for the generated straight-line HSO opportunities. Keep using `--normalize local-cleanup-debris` for this dedicated profile until the project either accepts the cleanup normalizer as ordinary HSO evidence or intentionally aligns Starshine's output shape with Binaryen nops.

## Follow-up

- Final HSO closeout now has a pass-specific GenValid profile candidate: `--gen-valid-profile heap-store-optimization`.
- Dedicated-profile signoff should report selected profile counts; current profile is a leaf, so every manifest entry has `selected_profile: "heap-store-optimization"`.
- If future slices add descriptor/control-flow HSO generators, either extend this profile or add a composite `heap-store-optimization-all` profile and update the closeout command accordingly.
