---
kind: workflow
status: working
last_reviewed: 2026-07-30
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

Dedicated GenValid profile: use `coalesce-locals-all` for the required pass-specific closeout lane. It is a composite over eleven deterministic leaves:

- `coalesce-locals-straight-line` — same-typed local copy chains without structured control.
- `coalesce-locals-structured` — bounded block-local copy chains.
- `coalesce-locals-loop-copy-through` — conservative loop-local single-use copy-through shapes.
- `coalesce-locals-entry-values` — explicit-zero versus implicit-default value numbering.
- `coalesce-locals-copy-preference` — copy-connected greedy-order profitability.
- `coalesce-locals-tee-copies` — `local.tee`-produced copy values and cleanup.
- `coalesce-locals-inter-block` — copy traffic across a structured block boundary.
- `coalesce-locals-unreachable` — local traffic in unreachable control with memory effects preserved.
- `coalesce-locals-legacy-eh` — protected-body and catch-all local-copy traversal.
- `coalesce-locals-large-unused` — bounded large unused-local declaration compaction.
- `coalesce-locals-exact-types` — mixed exact local types that must remain distinct.

Aliases accepted by `GenValidConfig::profile(...)`: `coalesce-locals`, `coalesce-locals-closeout`, `coalesce-locals-all-profiles`, `cl`, and `cl-closeout`.

Required dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass coalesce-locals --gen-valid-profile coalesce-locals-all --out-dir .tmp/pass-fuzz-coalesce-locals-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Latest closeout evidence:

- 2026-08-11 bounded dense-tee interval refresh: rebuilt native SHA-256 `9ea22fb8c00ca903b1d58ee8e100169c95a7a090730b84dde7f0c1039158859f` ran `.tmp/pass-fuzz-coalesce-locals-profile-10000-dense-tee-interval-20260811` with `--gen-valid-profile coalesce-locals-all`, seed `0x5eed`, 16 workers, and the explicit native binary. It compared `10000/10000`: `8125` normalized matches plus `1875` inspected Starshine wins, with zero validation, property, generator, or command failures. The residuals are exactly `1250` `coalesce-locals-structured` and `625` `coalesce-locals-inter-block` cases; every Starshine raw output is three bytes smaller by deleting an unbranched unused-label void block (`-5625` bytes aggregate), and common verified-v131 `-Oz --strip-debug --all-features` makes all `1875/1875` pairs byte-identical. Binaryen cache was `9974` hits / `26` misses. This is an agent-classified cleanup win, not a harness semantic-safety verdict.
- 2026-07-30 post-closeout correctness refresh: review found path-insensitive legacy-EH aliasing and loop-backedge aliases that could bypass the final copy. The repair adds definite-assignment joins for legacy `if`/`try` control, pre-`try`-only catch-entry facts, earlier-backedge rejection, and complete represented branch/control-transfer barriers including GC `br_on_*`. Rebuilt native SHA-256 `84bcf115d3ce400923aa7b239c94d20f278eb1bd6455bb031c87b284f12006fd` against explicit `wasm-opt version 131 (version_131)` gives `.tmp/review-fix-coalesce-regular-100000-20260730-final` at `100000/100000` exact and `.tmp/review-fix-coalesce-dedicated-10000-20260730-final` at `10000/10000` exact, with zero validation, property, generator, command, or comparison failures. Focused tests pass `62/62`; a transform-bearing Node runtime fixture preserves implicit-default, copied, and skipped-tail loop values.
- 2026-07-30 closeout: native SHA-256 `0b4acafce19b6c0d96b849445a342ac67d1be891592609f8388e9e096a96231a` against official `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. Regular `.tmp/audit-coalesce-locals-regular-100000-closeout-v131-20260730` compares `100000/100000` exactly with external wasm-tools validation and zero failures; Binaryen cache `100000` hits / `0` misses. The eleven-leaf dedicated `.tmp/audit-coalesce-locals-profile-10000-closeout-v131-20260730` compares `10000/10000` exactly with wasm-tools validation, idempotence, and zero failures; Binaryen cache `10000` hits / `0` misses. Dedicated leaf counts are straight-line `1875`, structured/copy-preference/loop-copy-through `1250` each, and `625` each for entry-values, tee-copies, inter-block, unreachable, legacy-EH, large-unused, and exact-types.
- Final explicit wasm-smith `.tmp/audit-coalesce-locals-wasm-smith-10000-closeout-v131-20260730` compares `9956/10000`: `9955` direct plus one `unreachable-control-debris` compare-normalized match, zero mismatches or Starshine failures, and the established `44` Binaryen/tool failures (`39` zero-length rec groups, one invalid tag index, one table index out of range, and three bad section sizes). Cache: wasm-smith `10000/0`, Binaryen successes `9956/0`, Binaryen failures `44/0` hits/misses.
- Final random-all `.tmp/audit-coalesce-locals-random-all-10000-closeout-v131-20260730` compares all `10000`: `8750` exact plus `1250` direct cleanup-shape differences, split evenly between `ssa-nomerge-smoke` and `remove-unused-brs-control`, with zero failures. Skip-clean outputs are smaller in every residual (`-5568` bytes aggregate: `-2500` SSA and `-3068` remove-unused-brs). Common Binaryen-v131 `-Oz --strip-debug` makes all `1250/1250` byte-identical. The former eleven one-byte downstream losses were caused by label-insensitive dead-tail cleanup after local `br_table`/nested block exits; label-depth-aware sentinel handling repairs the semantic hazard and closes the loss family.
- Official v131 lit replay `.tmp/audit-coalesce-locals-v131-lit-closeout-20260730` is `1972` bytes Starshine versus `1994` Binaryen and converges byte-for-byte after common `-Oz --strip-debug`. Safe loop-body wrapper flattening, backedge-copy preference, and same-source fanout coloring close the `_memcpy`, `$loop-backedge`, and `$inter-block-copy` gaps. Per-function body measurement finds exactly seven size differences, all Starshine wins totaling `-22` bytes from immutable-default dropped-read cleanup; the remaining textual differences are equal-size local numbering only.
- Final performance probe `.tmp/audit-coalesce-locals-perf-closeout-final-20260730` uses 1000 functions with 32-local exact copy chains. Outputs are byte-identical at `38027` bytes. Seven-run pass-local medians are `1.481ms` Starshine and `8.77995ms` Binaryen (`0.169x` Binaryen time), improving the previous `43.260ms` Starshine median by enabling the linear copy-chain path for terminal `local.get`, making alias assignment linear, and combining index rewrite with redundant-copy cleanup.
- Ordered `local-subtyping -> coalesce-locals -> local-cse` evidence remains exact at `.tmp/audit-coalesce-locals-ordered-suffix-10000-no-property-current-v131-20260729`: `10000/10000`, external validation, zero mismatches or failures. The earlier sequence-idempotence failure is not a Starshine fixpoint gap: `.tmp/audit-coalesce-locals-ordered-suffix-idempotence-oracle-20260730` proves Binaryen v131 and Starshine both narrow the sampled `local-subtyping-null-bottom` case only on the second sequence run and produce identical WAT after each run.

- 2026-07-21 orientation repair: rebuilt native SHA-256 `f5d84bb880d03780d21efdc939915bff94f6ae8e5e67d2002f9c1e0ebf2807e9`; explicit official `wasm-opt version 131 (version_131)` replay normalized all five original orientation failures (`000027`, `000034`, `000049`, `000054`, `000075`) with zero failures. `.tmp/audit-correctness-002-cl-random-300` then compared all 300 seed-`0x71c0` random-all-profile cases: `296` normalized, zero validation/property/generator/command failures, and four inspected raw mismatches outside the repaired family (three conservative loop copy/param reuse parity gaps and one structured block-flattening parity gap). Keep those four open under the existing broader coalesce shape backlog; they are not proven Starshine wins.
- Regular GenValid: `.tmp/pass-fuzz-coalesce-locals-genvalid-100000-structured-scalar-order-final-20260704` requested/compared `100000/100000`, normalized `100000`, zero mismatches/failures, Binaryen cache `100000` hits / `0` misses. This refresh supersedes the earlier green `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-genvalid-100000-20260704` lane.
- Dedicated GenValid profile: `.tmp/pass-fuzz-coalesce-locals-profile-10000-structured-scalar-order-final-20260704` requested/compared `10000/10000`, normalized `10000`, zero mismatches/failures, Binaryen cache `10000` hits / `0` misses. Selected leaves: `coalesce-locals-straight-line=4290`, `coalesce-locals-structured=2885`, `coalesce-locals-loop-copy-through=2825`.
- Explicit wasm-smith: raw `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-20260704` compared `9956/10000`, normalized `9955`, one raw no-local `drop(unreachable); unreachable` cleanup-debris mismatch, and 44 Binaryen/oracle command failures (`binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`). Cleanup-normalized `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-normalized-20260704` with `--normalize unreachable-control-debris` converts the debris case to one compare-normalized match and leaves zero mismatches with the same command failures. The raw debris case remains the documented narrow boundary, not a correctness blocker.
- Random all-profiles: the earlier `.tmp/pass-fuzz-coalesce-locals-nonadj-copy-random-all-profiles-10000-20260704` timed out before `result.json`, and the first diagnostics exposed `163` mismatches (`125` `ssa-nomerge-smoke`, `38` `heap2local-struct`). Concrete-ref direct-`struct.get` packing plus preferred-first GC-ref ordering closed the `heap2local-struct` subfamily; immediate tee/drop cleanup, nested block-escape liveness, label-aware branch/return liveness, tail param reuse, and structured-scalar coloring order then closed the sampled `ssa-nomerge-smoke` family. Replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-structured-scalar-order-final-20260704` normalized all previously active `125/125` residuals. The refreshed diagnostic `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-smoke-1000-structured-scalar-order-final-20260704` compared/normalized `1000/1000`; the required closeout lane `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704` requested/compared `10000/10000`, normalized `10000`, and had zero validation/property/generator/command failures. Selected profile counts in the 10k lane: `coverage-forced-portable=1250`, `ssa-nomerge-parity=1250`, `pass-fuzz-stress=1250`, `binaryen-oracle-portable=1250`, `ssa-nomerge-smoke=1250`, `local-subtyping-straight-line=821`, `heap2local-struct=538`, `coalesce-locals-straight-line=545`, `coalesce-locals-structured=355`, `coalesce-locals-loop-copy-through=350`, `heap2local-array=355`, `heap2local-ref=357`, and `local-subtyping-structured=429`.

Manifest triage: inspect `genValidSelectedProfileCounts` for composite selection and each failure directory's `genValidManifestEntry.selected_profile`. The dedicated profile is expected to exercise local-copy opportunities in every generated case; broad `random-all-profiles` may also select neighboring pass-owned profiles that reveal direct `coalesce-locals` local-declaration cleanup gaps.
