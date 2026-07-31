---
kind: workflow
status: supported
last_reviewed: 2026-07-31
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

## Current state: active; full closeout remains open

`flatten` remains admitted by the compare harness and has a dedicated `flatten-all` GenValid aggregate. A July 31, 2026 expanded O4z replay exposed a carried payload-branch dead-suffix validity gap that the July 17 direct matrix did not cover. The repair treats a direct unconditional root as the no-fallthrough proof, routes its payload before clearing branch arity, and preserves arbitrary later dead roots unless an existing exact ownership proof permits deletion. The focused fix, expanded aggregate, direct comparison matrix, original O4z corpus, and single-arm legacy-EH bridge have now been rerun with a rebuilt binary. Full closeout still requires classification of the remaining residual families, the deeper ownership/failure-atomicity audit, and exact historical candidate-dense performance remeasurement.

Always compare with an explicitly rebuilt native release binary:

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

## Previous 2026-07-17 matrix

All rows used the then-current rebuilt native binary and the three normalizers above. These results remain useful baseline evidence but are not the current closeout after the July 31 validity discovery.

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

A prior default lane compared 100,000/100,000 cases with zero mismatches. The 10,000-case matrix was the normative signoff for the polymorphic-unreachable repair, but the later payload-branch dead-suffix discovery now requires a fresh matrix.

## Validation discrepancy found by wasm-smith

The first wasm-smith run found two Starshine validation failures among command failures. Both involved stack-polymorphic unreachable tails whose incidental transformed type differed from the declared control or function result type. A further focused reference test reproduced the same problem with `externref` versus `funcref`.

The red-first repair now:

- preserves equal or validator-proven subtype flow;
- drops incompatible dead tail values;
- materializes the declared defaultable result through its own typed temporary;
- uses the pass module context for reference subtype checks.

Focused coverage includes function, block, if, loop, numeric, and reference cases. The original wasm-smith inputs now lower and validate with `wasm-tools --features all`.

## `flatten-all` coverage

The aggregate now consists only of dedicated deterministic `flatten` leaves, with one leaf for each Binaryen transform family or Starshine routing axis:

- `flatten-function-results`
- `flatten-operands`
- `flatten-blocks`
- `flatten-ifs`
- `flatten-loops`
- `flatten-tee`
- `flatten-br`
- `flatten-br-if`
- `flatten-br-table`
- `flatten-unreachable`
- `flatten-multivalue`
- `flatten-legacy-eh`

The fixtures cover explicit and implicit function results, ordinary nested operands, result-carrying block/if/loop/legacy-try owners, inputful loops, `local.tee`, all three payload-bearing branch forms, arbitrary dead suffixes, polymorphic unreachable placeholders, and multivalue results/payloads. `try_table` is not included: Binaryen v131's `--flatten` reaches its `unexpected expr type` assertion on a result-typed `try_table`, so it is an oracle failure boundary rather than a usable comparison family.

The rebuilt-native raw smoke at `.tmp/pass-fuzz-flatten-profiles-smoke3-20260731` selected every leaf across `120/120` generated cases with zero generator, command, or validation failures. It produced `16` raw matches and `104` raw mismatches. Each dedicated module now exports its runtime root so comparisons cannot become vacuous after cleanup. The current exported-root lane at `.tmp/pass-fuzz-flatten-profiles-runtime-idempotence-smoke6-20260731` uses the documented three normalizers, Node runtime execution, and Starshine idempotence: it produced `16` direct matches, `74` compare-normalized matches, `30` residual mismatches, `120/120` idempotence matches, and no property, command, generator, or validation failure. Its runtime matrix executed `166` exports with `154` equal results and `12` equal traps, zero semantic mismatches, and zero unsupported runtimes.

The earlier 120-case residuals were concentrated in `flatten-br-if` (`9`), `flatten-legacy-eh` (`8`), and `flatten-multivalue` (`13`). The `br_if` family is a measured Starshine win candidate: its representative raw output is `66` bytes versus Binaryen's `78`, runtime results agree, and both sides converge byte-for-byte to `33` bytes under Binaryen v131 `-Oz`. The multivalue profile now isolates plain, `br`, `br_if`, and `br_table` forms in four exported functions. Exact dropped-result ownership and reverse-lane proofs flatten all four public shapes; representative raw output is `197` bytes versus Binaryen's `468`, all runtime results agree, and both sides converge byte-for-byte to `59` bytes under v131 `-Oz`. First-class HOT lifting now admits single-arm tagged catches, typed catch payload lanes, `catch_all`, result-typed tries, direct delegates, and legacy `rethrow`; unrelated HOT pipelines lower those forms without flattening them. A representative legacy result try is `67` bytes versus Binaryen's `71`, with runtime agreement and byte-for-byte convergence to `37` bytes under v131 `-Oz`. Multi-arm legacy tries remain an explicit HOT representation boundary.

The current full deterministic lanes use native SHA-256 `4b60d4b09f573a82419cef9d5ef5a6d88018a4a7edf6c18f7e44b97e017bb217` and explicit Binaryen v131:

- default GenValid: `10,000/10,000`, `4,200` direct plus `5,800` compare-normalized matches, zero mismatches or failures, and `10,000/10,000` idempotence;
- `flatten-legacy-eh`: `10,000/10,000` compare-normalized matches, zero failures, `10,000/10,000` idempotence, and zero runtime semantic mismatches;
- `merge-locals-legacy-eh`: `10,000/10,000` compare-normalized matches, zero failures, `10,000/10,000` idempotence, and zero runtime semantic mismatches;
- `flatten-all`: `10,000/10,000`, `1,632` direct plus `6,701` compare-normalized matches, `1,667` classified residuals, zero failures, and `10,000/10,000` idempotence. The residuals are now exactly `842` scalar-`br_if` and `825` multivalue Starshine-win candidates; all `820` legacy-EH bridge gaps moved into the normalized-match population;
- random-all-profiles: `9,629` comparable cases, `371` Binaryen-only command failures, `3,070` direct plus `5,778` compare-normalized matches, and `781` residuals, with zero Starshine command, generator, or validation failures. The fresh aggregate was resumed without property mode after the runtime/idempotence attempt exceeded the command timeout; the dedicated legacy and full aggregate lanes provide fresh `10,000/10,000` idempotence evidence, while the previous random-all run remains `10,000/10,000` idempotent. The new lift bridge removes all `38` `merge-locals-legacy-eh` residuals. The remaining eight families are `coverage-forced-portable` (`546`), `local-subtyping-control-refinalize` (`52`), `remove-unused-brs-constant-br-if` (`43`), `remove-unused-brs-selectify` (`38`), `merge-locals-type-boundary` (`36`), `precompute-gc-atomic-boundary` (`27`), `remove-unused-brs-result-refinalize` (`26`), and `remove-unused-brs-multivalue-drop` (`13`). Their inspected representatives remain fully flattened and smaller than Binaryen, pending final classification.

Artifacts are `.tmp/pass-fuzz-flatten-default-10000-hot-lift-20260731`, `.tmp/pass-fuzz-flatten-legacy-eh-hot-lift-10000-20260731`, `.tmp/pass-fuzz-flatten-merge-locals-legacy-eh-hot-lift-10000-20260731`, `.tmp/pass-fuzz-flatten-all-10000-hot-lift-20260731`, and `.tmp/pass-fuzz-flatten-random-all-10000-hot-lift-20260731`. The separate wasm-smith lane was not rerun because external-generator coverage is opt-in.

The exact historical `gen-valid-000003.wasm` repro now succeeds through public `--flatten` and `-O4z`, and both outputs validate with `wasm-tools --features all`. Replaying the first 1,000 inputs from the saved expanded RUB corpus through the rebuilt public `-O4z` path yields `1,000/1,000` valid outputs with zero command or validation failures; the latest artifacts are under `.tmp/rub-o4z-schedule-validity-1000-repaired4-20260731`.

Profile registration, exported runtime roots, family markers, aggregate selection, and manifest case labels are tested in [`src/validate/gen_valid_tests.mbt`](../../../../../src/validate/gen_valid_tests.mbt) and [`src/fuzz/main_wbtest.mbt`](../../../../../src/fuzz/main_wbtest.mbt).

## Classification rule

Treat any future raw mismatch as open until it is classified with inspected artifacts, validation, semantic reasoning, and relevant size/downstream evidence. Do not call a difference safe merely because both outputs validate or one output is smaller.

The detailed discovery and repair record is [`docs/wiki/binaryen/passes/flatten/index.md`](./index.md).
