---
kind: workflow
status: supported
last_reviewed: 2026-07-27
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_rume_tests.mbt
  - ./parity.md
---

# `remove-unused-module-elements` Fuzzing Profile

Use a freshly built native CLI and an explicit official Binaryen v131 oracle. On the 2026-07-27 audit, PATH `wasm-opt` was v116; all oracle commands therefore used:

- Starshine: `_build/native/release/build/cmd/cmd.exe`
- Binaryen: `.tmp/binaryen-version-131-bin/bin/wasm-opt`
- verified oracle text: `wasm-opt version 131 (version_131)`

## Dedicated aggregate

RUME now has a dedicated `rume-all` / `remove-unused-module-elements` GenValid aggregate with three deterministic families:

| Leaf profile | Weight | Case label | Main obligation |
| --- | ---: | --- | --- |
| `rume-dead-graph` | 4 | `rume:dead-module-graph` | whole-module dead graph removal and surviving-index repair |
| `rume-table-trap` | 3 | `rume:indirect-call-trap-retention` | table default, overlap, wrong-type/null writes, and indirect-call trap preservation |
| `rume-legacy-eh` | 3 | `rume:legacy-eh-remap` | decoded legacy `try` body/catch reachability and remapping |

The profile is intentionally separate from `random-all-profiles`; adding it to that aggregate would perturb the established random profile-selection corpus rather than merely add RUME coverage.

## 2026-07-27 explicit-v131 matrix

| Lane | Command shape | Out-dir | Result |
| --- | --- | --- | --- |
| Dedicated RUME GenValid | `--count 10000 --seed 0x5eed --gen-valid-profile rume-all` | `.tmp/pass-fuzz-rume-audit-genvalid-rume-all-10000-final` | `10000/10000` normalized matches; zero validation, property, generator, or command failures |
| Regular GenValid | `--count 100000 --seed 0x5eed` | `.tmp/pass-fuzz-rume-audit-genvalid-100000-final` | `100000/100000` normalized matches; zero failures |
| Random all-profiles | `--count 10000 --seed 0x5555 --gen-valid-profile random-all-profiles` | `.tmp/pass-fuzz-rume-audit-random-all-10000-final` | `9375` normalized matches and `625` inspected representation differences; zero validation/property/command failures |
| Explicit wasm-smith | `--wasm-smith --count 10000 --seed 0x5eed` | `.tmp/pass-fuzz-rume-audit-wasm-smith-10000-final` | `9956` comparable, `9955` normalized matches, one known Starshine win, and `44` Binaryen/tool failures |

All commands used `--pass remove-unused-module-elements --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt`.

## Random-all classification

All `625` random-all differences came from the `remove-unused-brs-control` selected profile and had the same measured result:

- Starshine canonical output was exactly one byte larger than Binaryen's.
- The affected modules used multi-value control encoding whose Binaryen-first path grouped a synthetic scalar scratch local with an earlier same-typed local run.
- Starshine's decode/re-encode path left that synthetic local in a later run, adding one local-declaration run byte.
- RUME's internal module dump was unchanged across the pass for the inspected family; no module-element keep/drop, nullification, liveness, or index-remap decision differed.

This is a real size-losing representation gap, not a claimed Starshine win. It is owned by multi-value decode/encode local-run canonicalization rather than RUME semantics. Reopen RUME only if a replay shows the pass itself changes a reachability, nullification, or remap decision in this family.

## wasm-smith classification

The sole comparable mismatch is the stable `case-004700` family:

- Binaryen retains a huge unused memory64 and two active data segments.
- Starshine emits an empty eight-byte module.
- Binaryen v131 truncates the huge minimum-byte computation through `Index(initial << pageSizeLog2)` and false-positives an out-of-bounds startup trap.
- Starshine uses full-u64 bounds and proves both writes in bounds.

This remains an intentional correctness-and-size win. The `44` other cases are Binaryen/tool command failures; Starshine had zero command, validation, or property failures.

## Focused and repository validation

- `src/passes/remove_unused_module_elements_test.mbt`: `43/43`
- `src/validate/gen_valid_rume_tests.mbt`: `2/2`
- full post-remote-merge `moon test`: `10002/10002`

The focused suite covers ordinary and non-function mode, imports/definitions, all module-element kinds, active/passive/declarative segments, declaration-only `ref.func`, table defaults/overlaps/traps/TNH, legacy EH, `call_ref`, `binaryen.js.called`, exact and typed `call.without.effects`, `configureAll` element operands, continuations and handler tags, descriptor-trapping initializers, recursive types, and index rewrites.

## Practical rule

Use the dedicated aggregate for RUME-owned closeout. Use random-all and wasm-smith as broad compatibility lanes, but classify their residuals by the owning transform instead of treating every canonical-byte difference as a RUME semantic mismatch.
