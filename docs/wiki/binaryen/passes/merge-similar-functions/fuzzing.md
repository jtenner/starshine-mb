---
kind: workflow
status: supported
last_reviewed: 2026-10-10
sources:
  - ../../../../../src/validate/gen_valid_merge_similar_functions.mbt
  - ../../../../../src/validate/gen_valid_merge_similar_functions_wbtest.mbt
  - ../../../../../src/passes/merge_similar_functions_test.mbt
  - ../../../../../src/passes/gc_record_copy_outlining.mbt
  - ../../../../../src/passes/gc_record_copy_outlining_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ../../../tooling/pass-fuzz-compare.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `merge-similar-functions` fuzzing

> **Historical comparison baseline — September 10, 2026:** comparisons then used [Binaryen 132](../../release-horizon-and-oracles.md). The October 10 qualification below uses verified Binaryen 133. Recorded v131/v132 sources, commands, artifacts and results retain their historical versions and do not establish v133 signoff.

## October 10, 2026 record-copy profile

`merge-similar-functions-record-copy` is a separate targeted profile. Every
input contains 8–12 real immutable record-copy sites with 12–32 fields,
seed-varied initial/replacement values, ordered host calls and an exported
mutable event counter. Numeric `run` and nullable `trap` exports execute the
copies in the generic stateful runtime observer. Typed `make`, `update`,
`same` and every field getter expose old aliases, fresh identity and nullable
trap boundaries to independent expected-value observers.

The existing eight-leaf `merge-similar-functions-all` aggregate is unchanged.
It has no record-copy family and its historical counts do not establish
coverage of the new owner. Run both the actual triggering profile and the
ordinary aggregate with fresh native executables and retain structural
Binaryen discrepancies and normal failing exit codes separately from
executed values/effects/state/traps. The new local qualification uses verified
Binaryen 133; the older 131/132 commands and results below remain historical
and do not establish this slice's signoff. No external-generator audit or
exhaustive GC/MSF closeout is claimed.

Focused source tests cover unsupported definitions and expressions, exact
references, whole-module compressed local excess, flattened recursive type
and import append indices, bounded excluded bodies/initializers, unchanged
source bytes, undersampling and full-validation rollback. The 65,536/65,537
zero-count compressed-run boundary is skipped in ordinary runs and must be
explicitly executed with `--include-skipped`.

### Compiled direct-pass comparison and runtime evidence

The October 10 qualification used clean source `d5097be3e`, a freshly built
native CLI (SHA `420c4de9177cae6b6f56f56d4518f7bfb530e2eb3f710e53a309ab834e1b462e`)
and generator (SHA `5fe1a94c5540a95b43678f7c39d497a0d4f2bca333c0d547b913c481f6bbbf4c`).
Both lanes used seed `0x5eed`, direct `merge-similar-functions`, verified
Binaryen 133, independent wasm-tools validation and actual default Node 26
stateful original/Starshine/Binaryen observation. Fresh-process workers used
explicit prebuilt paths; no external-generator lane was run.

The triggering record-copy lane completed 10,000/10,000 comparisons. It
retained normal exit 1 for 10,000 structural mismatches, with zero validation,
property, generator or command failures. All 10,000 journal runtime outcomes
were `all-equal`; Starshine raw/canonical bytes totaled 14,094,624 versus
Binaryen's 23,128,050, and each case was smaller. The manifest contained
10,000 distinct seeds and generator-recorded `fnv1a64` identifiers, covering
all 105 width/arm combinations (12–32 fields, 8–12 copies). This is sampled
coverage, not exhaustive coverage or a cryptographic uniqueness proof.

The retained 20 mismatch bundles include complete actual observations.
Across those 20 reports, each original/Starshine/Binaryen mode totals 954
exported calls and 420 import events, with no blocked or zero-call report. The other 9,980 cases retain their
journal classification but not full step reports because the mismatch artifact
cap was 20. An independent 52-input custom observer executes every selected
arm, all fields, old/fresh aliases, fallback identity, ordered host state,
selected-null traps, callback throws and reentry across original, direct MSF,
selective preset and Binaryen. Default Node 25 and 26 each completed 208
variants, 153,704 export calls, 624 traps and 140,216 field checks. A separate
linear WAT census counted 531 actual copies, 8–12 in every input. The generic
harness's stub imports do not substitute for this expected-event contract.

The retained discrepancy is an agent judgment of a measured Starshine size
win: the reviewed private-helper contract, inspected copy-bearing differences
and actual independent observations support the decision. Tiny 12-field
callback-free execution slowed in the reduced benchmark, while the 403-field,
64-arm batch improved; those tradeoffs and concurrent timing limits are
recorded in [the strategy page](./starshine-strategy.md). No universal speed,
runtime-memory or whole-GC/MSF audit claim follows from byte savings.

Exact replay must use the authoritative generator manifest and case index,
or retained input bytes. Existing failure-metadata JSON reserialization
rounded UInt64 `case_seed` in 19/20 retained bundles: case 2's manifest seed
is `11698534113733384926`, while its metadata says `11698534113733384000`.
The original rounded metadata is preserved, and independently recomputed
retained-input generator `fnv1a64` hashes agree with the exact manifest. Deriving a fixture
shape from the rounded metadata alone is incorrect. The independent 52-input
Python observer preserves exact integer seeds as strings.

Legacy `try` and `try_table` fixture variants separately execute on default
Node 25/26. Their outputs retain all 26 constructors, demonstrating new-owner
fallback while preserving fields, public identities, host exceptions/reentry
and nullable traps. Other existing cleanup still changes encoded bytes, so
these are compatibility controls, not outlining wins. Initial fixture syntax,
feature-flag and mistaken constructor-count authoring failures remain retained;
they do not count as semantic runs.

Local evidence lives in task9 `gc-cleanup-evidence`: `record-targeted10000/`,
its command/exit/execution-audit files, `record-profile-runtime52/`,
`record-profile-all-arms-node25.json` / `node26`,
`record-profile-runtime52-input-shape-audit.json` and
`record-exception-fallback-qualification.json` / runtime-exit reports.
The default/source/package gates and ordinary aggregate remain distinct.

The ordinary eight-leaf aggregate separately completed 10,000/10,000 exact
normalized matches and equal runtime journal observations, normal exit 0,
with zero failures. Canonical byte totals were 1,747,794 for both tools. Raw
Starshine bytes totaled 1,776,123: 5,558 cases were larger before comparison
canonicalization, a retained 28,329-byte raw serialization gap rather than a
raw size win. Successful detailed reports were cleaned by the existing harness;
the manifest and all 10,000 journal classifications remain. This aggregate
provides ordinary MSF compatibility, not record-copy transform coverage.
Evidence: `msf-ordinary10000.log`, command/exit/execution-audit files and
`msf-ordinary10000/cases.jsonl` under the same local evidence directory.

## Dedicated aggregate

Use:

```text
--gen-valid-profile merge-similar-functions-all
```

Aliases include `merge-similar-functions`, `merge-similar-functions-closeout`, and `msf`.

The aggregate deterministically samples eight leaves and records each selected leaf in `manifest.json`:

- `merge-similar-functions-literals`
- `merge-similar-functions-repeated-diff`
- `merge-similar-functions-exact-duplicates`
- `merge-similar-functions-duplicate-types`
- `merge-similar-functions-locals`
- `merge-similar-functions-nested`
- `merge-similar-functions-call-targets`
- `merge-similar-functions-tail-calls`

Every leaf emits at least one profitable near-duplicate class. Seeds vary class size, filler length, differing literal vectors, local counts, nested control shape, and direct call targets.

## Normalizers

Ordinary broad lanes use:

```text
--normalize local-cleanup-debris
--normalize unreachable-control-debris
```

These are not MSF parity normalizers. They cover pre-existing command-level differences:

- Starshine strips standalone `nop` debris during final encoding
- Starshine and Binaryen can encode equivalent `drop(unreachable); unreachable` tails differently

The dedicated aggregate needs neither normalizer and is exact.

## Historical v131 final commands

The commands and results in this section are the recorded v131 closeout. New
comparison runs use verified Binaryen 133 as documented in the October 10
section above and the shared [compare-pass guide](../../../tooling/pass-fuzz-compare.md).

Build once:

```sh
moon build --target native --release src/cmd
moon build --target native --release src/fuzz
```

Regular:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed \
  --pass merge-similar-functions \
  --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe \
  --normalize local-cleanup-debris \
  --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-merge-similar-functions-regular-final-100000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/toolchains/binaryen-version_131/bin/wasm-opt \
  --require-binaryen-version 131
```

Dedicated:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass merge-similar-functions \
  --gen-valid-profile merge-similar-functions-all \
  --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe \
  --out-dir .tmp/pass-fuzz-merge-similar-functions-dedicated-10000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/toolchains/binaryen-version_131/bin/wasm-opt \
  --require-binaryen-version 131
```

Use the same pinned tool flags for the 10,000-case `--wasm-smith` lane and the 10,000-case `random-all-profiles` lane at seed `0x5555`.

## Historical v131 final results

- regular: 100,000/100,000; 96,352 ordinary plus 3,648 cleanup-normalized; zero residuals/failures
- dedicated: 10,000/10,000 exact normalized; zero failures
- wasm-smith optimization rerun: 9,949 comparable exact canonical matches; zero residuals; 51 Binaryen/tool failures
- random-all: 10,000/10,000; 9,854 ordinary plus 46 cleanup-normalized; 100 inspected 8-12-byte canonical Starshine wins from unrelated pre-existing local/block encoding; zero Starshine failures
- semantic v2: 100/100 all-equal on the final dedicated aggregate
- determinism/codec/idempotence: 100/100 each

## Performance rewrite

The retained optimization was measured on the same 5,261,119-byte pre-MSF Starshine artifact used for initial signoff. One warmup plus five alternating direct runs produced:

- Starshine before: 1.226 seconds median
- Starshine after: 0.945 seconds median
- pinned Binaryen 131: 0.603 seconds median
- improvement: 0.282 seconds / 22.96%
- final Starshine/Binaryen ratio: 1.567x

The exact 5,113,549-byte output and SHA-256 `ba3d9af87f5293b498601d277768e22a0be0b41144d7be8d59d9ddfb5f54cfab` are unchanged.

A final traced run attributes:

- fused function analysis: 68.333ms
- exact class splitting: 5.032ms
- parameter planning and rewrite: 6.176ms
- append-only candidate validation: 44.482ms

The replaced full candidate scan took 333.195ms on the same artifact. The incremental proof checks untouched section identity, type/function/element append-only prefixes, the complete candidate environment, and every changed or new function before accepting output.

Full O4z remains host-noisy near wall parity. Across seven alternating pairs, independent medians are 25.508s for Starshine and 24.984s for Binaryen (`1.021x`), but the median paired difference is 0.010s in Starshine's favor. Starshine uses 33.402s median user CPU versus Binaryen's 194.593s and remains 30,513 bytes smaller.

## Post-rewrite corruption-safety lanes

The incremental candidate validator received additional signoff beyond parity comparison:

- `.tmp/pass-fuzz-msf-corruption-dedicated-25000`: 25,000/25,000 dedicated MSF-triggering modules passed `wasm-tools validate --features all`, byte determinism, codec idempotence, pass idempotence, and exact canonical Binaryen parity.
- `.tmp/pass-fuzz-msf-corruption-semantic-stateful-1000`: 1,000/1,000 stateful original/Starshine/Binaryen observations were all equal; semantic idempotence and bounded convergence were 1,000/1,000; deterministic bytes, codec stability, and external validation were also green.
- `.tmp/pass-fuzz-msf-corruption-semantic-independent-5000`: 5,000/5,000 independent original-primary observations were all equal with external validation and exact canonical parity.
- `.tmp/pass-fuzz-msf-corruption-random-all-5000`: all 5,000 broad GenValid outputs externally validated and were deterministic, codec-idempotent, and pass-idempotent. The 49 residual structural diffs were 31 eight-byte and 18 twelve-byte canonical Starshine wins in the already documented local/block representation family; no output was canonically larger.
- `.tmp/pass-fuzz-msf-corruption-wasm-smith-10000`: all 10,000 Starshine outputs passed external validation, byte determinism, and codec idempotence; 9,949 completed the Binaryen-normalized idempotence check. The other 51 were Binaryen-131 parser/tool failures on valid Starshine outputs. Direct replay in `direct-replay/summary.json` validated all 51 before and after a second Starshine pass and found all 51 byte-identical.
- `.tmp/pass-fuzz-msf-corruption-random-all-semantic-1000`: the five-second lane produced 473 observable Starshine/original matches, 420 original-runtime-blocked cases, and 107 timeout-only Starshine observations. Replaying all 107 at 30 seconds in `.tmp/pass-fuzz-msf-corruption-random-all-semantic-replay-30s` resolved every case as a Starshine/original match. Combined observable evidence is therefore 580/580, with no semantic mismatch; 420 cases remain correctly blocked because the original could not be observed.
- `.tmp/pass-fuzz-msf-corruption-custom-section-metamorphic-1000`: 1,000/1,000 base/transformed pairs were semantically equal and externally valid after adding non-name custom sections. A separate 2,000-module binary-section audit in `section-preservation/summary.json` found every untouched section payload byte-identical; all 1,000 transformed outputs retained their non-name custom section.
- `.tmp/msf-corruption-production-soak-25`: 25 repeated MSF generations of the 5,113,549-byte production artifact externally validated and remained byte-identical at SHA-256 `ba3d9af87f5293b498601d277768e22a0be0b41144d7be8d59d9ddfb5f54cfab`.

These lanes found no malformed module, section drift, deterministic instability, codec instability, pass instability, or original-primary semantic mismatch from the optimized validator path.
