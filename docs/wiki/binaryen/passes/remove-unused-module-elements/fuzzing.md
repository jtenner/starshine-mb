---
kind: workflow
status: supported
last_reviewed: 2026-08-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_rume_tests.mbt
  - ./parity.md
---

# `remove-unused-module-elements` Fuzzing Profile

## 2026-08-21 composite `ref.func` repair

Runtime-used typed element expressions now recursively contribute nested `ref.func` references, and declaration-only composite expressions retain every function index inside the same indivisible expression while still pruning independent entries. Native SHA-256 is `fa740eba2fb1b5b1c167cc75c682b265995e19cffbc241567cfcb0f436ae8884`.

The renewed `rume-all` lane at `.tmp/pass-fuzz-rume-composite-ref-func-cleanup-10000-20260821` requested and compared **10,000/10,000** with `rume-all`, seed `0x5eed`, explicit Binaryen v131, `--jobs auto`, and `--normalize local-cleanup-debris`: **4,106** ordinary normalized matches plus **5,894** compare-normalized matches, zero remaining mismatches, validation failures, generator failures, property failures, or command failures, and Binaryen cache **10,000/0**. The compare normalizer is required after the CLI-wide encoding cleanup began omitting standalone function-body `nop`s; an unnormalized development run stopped at 3,432 compared with 2,011 output-shape mismatches, and inspected legacy-EH/index-remap representatives differed only by Binaryen-retained standalone `nop`s. This is an encoding-shape family, not a RUME liveness/remap regression.

Two binary-decoded focused fixtures own the repaired boundary because the local WAT helper does not yet parse these extended-const composite element forms. A passive typed elem containing `ref.func; struct.new` feeds `array.new_elem -> array.get -> struct.get -> call_ref` and returns **42** before/after the native pass; a declarative two-`ref.func` struct expression keeps both indices reference-only with `unreachable` bodies and externally validates. `wasm-tools --features all` validates both outputs. Pinned Binaryen v131 rejects the composite fixture while parsing (`unused expressions without block context`), so this exact proposal boundary has focused Starshine/runtime evidence rather than a direct Binaryen artifact comparison.

Use a freshly built native CLI and an explicit official Binaryen v131 oracle. On the 2026-07-27 audit, PATH `wasm-opt` was v116; all oracle commands therefore used:

- Starshine: `_build/native/release/build/cmd/cmd.exe`
- Binaryen: `.tmp/binaryen-version-131-bin/bin/wasm-opt`
- verified oracle text: `wasm-opt version 131 (version_131)`

## Dedicated aggregate

RUME's `rume-all` / `remove-unused-module-elements` aggregate now has seven deterministic families:

| Leaf profile | Weight | Case label | Main obligation |
| --- | ---: | --- | --- |
| `rume-dead-graph` | 3 | `rume:dead-module-graph` | whole-module dead graph removal and surviving-index repair |
| `rume-table-trap` | 2 | `rume:indirect-call-trap-retention` | table default, overlap, wrong-type/null writes, and indirect-call trap preservation |
| `rume-legacy-eh` | 2 | `rume:legacy-eh-remap` | decoded legacy `try` body/catch reachability and remapping |
| `rume-special-imports` | 3 | `rume:special-import-liveness` | ordinary/tail `call.without.effects` and ordinary/tail `configureAll` callable upgrades |
| `rume-callable-references` | 2 | `rume:callable-reference-liveness` | `call_ref`, table initializer, declarative references, and `binaryen.js.called` annotations |
| `rume-continuations-descriptors` | 2 | `rume:continuation-descriptor-liveness` | `cont.new` callable type edges plus descriptor-bearing recursive types and trapping initializers |
| `rume-index-remap-stress` | 3 | `rume:index-remap-stress` | sparse surviving functions/globals and high-to-low index repair |

Focused generator tests validate every leaf's feature floor. A pass-level generated test additionally runs the four new high-risk leaves through closed-world RUME and rejects any result in which a callable body becomes exactly `unreachable`.

The aggregate remains separate from `random-all-profiles`; widening that established selector would perturb unrelated corpus selection.

## Renewed 2026-07-27 explicit-v131 matrix

Current-master native SHA-256: `f4ea93419d8bb8c98d3e09c28a823b30a119ee436ee775c65d95b0386018545b`.

| Lane | Command shape | Out-dir | Result | Cache |
| --- | --- | --- | --- | --- |
| Dedicated RUME GenValid | `--count 10000 --seed 0x5eed --gen-valid-profile rume-all` | `.tmp/pass-fuzz-rume-rume-all-current-master` | `10000/10000` normalized; zero failures or mismatches | Binaryen `10000` hits / `0` misses |
| Regular GenValid | `--count 100000 --seed 0x5eed` | `.tmp/pass-fuzz-rume-regular-current-master` | `100000/100000` normalized; zero failures or mismatches | Binaryen `100000` hits / `0` misses |
| Random all-profiles | `--count 10000 --seed 0x5555 --gen-valid-profile random-all-profiles` | `.tmp/pass-fuzz-rume-random-all-current-master` | `9375` normalized plus `625` classified one-byte non-RUME residuals; zero validation/property/command failures | Binaryen `10000` hits / `0` misses |
| Explicit wasm-smith | `--wasm-smith --count 10000 --seed 0x5eed` | `.tmp/pass-fuzz-rume-wasm-smith-current-master` | `9956` comparable, `9955` normalized, one known Starshine win, `44` Binaryen/tool failures, zero Starshine failures | wasm-smith `10000/0`; Binaryen `9956` hits / `0` misses; failure cache `44` hits / `0` misses |

All commands used `--pass remove-unused-module-elements --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures`.

The expanded aggregate selected every leaf: `rume-special-imports` `1784`, `rume-index-remap-stress` `1744`, `rume-dead-graph` `1764`, `rume-legacy-eh` `1203`, `rume-table-trap` `1190`, `rume-callable-references` `1183`, and `rume-continuations-descriptors` `1132`.

Each new high-risk singleton also ran independently for `10000/10000` exact normalized matches with zero failures or mismatches:

- `.tmp/pass-fuzz-rume-rume-special-imports-current-master`
- `.tmp/pass-fuzz-rume-rume-callable-references-current-master`
- `.tmp/pass-fuzz-rume-rume-continuations-descriptors-current-master`
- `.tmp/pass-fuzz-rume-rume-index-remap-stress-current-master`

Each singleton used `10000` Binaryen cache hits and `0` misses.

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

- Red confirmation in a detached pre-fix worktree: `44/52` passed, with eight expected failures in the new tail/special-import/configureAll regressions.
- Repaired focused RUME: `52/52`.
- Dedicated generator tests: `3/3`.
- Current-master native full `moon test`: `10012/10012`.
- Retained-versus-fresh DAE boundary tests: `3/3`; topology-change guard: `1/1`.
- Current-master native and wasm-gc release CLI builds plus external wasm validation: green.
- Stable two-step no-pass release-artifact roundtrip: byte-identical and externally valid.
- Current-master deterministic wasm-gc binary-roundtrip smoke: `2944` attempts, green.
- Bounded DAE comparison against Binaryen v131: `10000/10000` normalized with zero validation, property, generator, command, or mismatch failures.
- README/API sync: green.
- CI-profile fuzz suites at deterministic seed `0x5eed`: all individual suites green, including `5000` valid modules, `2650` invalid AST cases, `400` invalid binaries, `400` static invalid texts, `384` dynamic invalid texts, `390` invalid spec seeds, `86820` deterministic binary roundtrips, and `4096` command-harness cases.

The aggregate `bun validate full --profile ci --target wasm-gc` wrapper reproduced the repository's known child-process no-return-code failure at its initial `moon info`. The aggregate wasm-gc `all` fuzz command likewise aborted without preserving its diagnostic after accumulated suites; running every suite serially, both with a fresh default seed and with CI seed `0x5eed`, passed. These wrapper failures are tooling/process aggregation failures, not RUME validation failures.

## 2026-08-28 performance-change renewal

Final native SHA-256 `4bca82a57ea2582360b460aebf0f19e623fc9359239a04075786c69a0b2f7461` completed the full required matrix:

- regular GenValid, seed `0x5eed`, `100000/100000`: `100000` cleanup-normalized matches, zero residual mismatches or failures. The normalizer accounts for the established CLI-wide standalone-`nop` omission; canonical Starshine is exactly one cleanup byte smaller per case;
- explicit wasm-smith, seed `0x5eed`: `9956/10000` comparable, `9955` normalized, the established `case-004700` full-u64 memory64 correctness/size win, zero Starshine failures, and 44 Binaryen/tool failures (`39` empty recursive groups, `3` bad section sizes, `1` invalid tag index, `1` table index out of range);
- dedicated `rume-all`, seed `0x5eed`, `10000/10000`: `4106` ordinary normalized plus `5894` cleanup-normalized, zero mismatches or failures. Selection remains special imports `1784`, index-remap stress `1744`, dead graph `1764`, legacy EH `1203`, table traps `1190`, callable references `1183`, and continuations/descriptors `1132`;
- random-all-profiles, seed `0x5555`, `10000/10000`: `7982` ordinary normalized, `1764` cleanup-normalized, `254` residuals, and zero failures. Replaying the identical saved corpus through clean HEAD produced exactly the same match counts, residual count, raw/canonical totals, and smaller/equal/larger directions. Persisted representatives are the established non-RUME local-run encoding and control-shell representation families;
- runtime-callable self semantics: exact `100/100`, zero failures.

The performance change therefore introduces no new compare family. Evidence is under `.tmp/pass-fuzz-rume-perf-regular-final-100000`, `.tmp/pass-fuzz-rume-perf-wasm-smith-final-10000`, `.tmp/pass-fuzz-rume-perf-rume-all-final-10000`, `.tmp/pass-fuzz-rume-perf-random-all-final-10000`, `.tmp/pass-fuzz-rume-clean-head-random-all-10000`, and `.tmp/pass-fuzz-rume-perf-runtime-final-100`.

## Practical rule

Use the expanded dedicated aggregate for RUME-owned closeout and report selected-leaf counts. In addition to canonical comparison, keep the pass-level callable-body invariant test green so liveness-strength regressions cannot hide behind valid bytes. Use random-all and wasm-smith as broad compatibility lanes, but classify residuals by the owning transform instead of treating every canonical-byte difference as a RUME semantic mismatch.
