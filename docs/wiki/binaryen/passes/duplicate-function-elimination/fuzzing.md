---
kind: workflow
status: working
last_reviewed: 2026-10-10
sources:
  - ../../../tooling/tracing-playbook.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `duplicate-function-elimination` Fuzzing Profile

## October 10 bounded GC canonicalization renewal

The [npm discrepancy follow-up](../../../tooling/npm-optimizer-discrepancy.md#qualified-bounded-gc-follow-up)
records fresh native2364a2c553c27c949f0406d25808c32a42258547dc9484f9db8c2b796ea06c55,
verified Binaryen 133, explicit unchanged generator, seed 0x5eed and eight workers.
The 10,000-case owned trigger profile yields 5,000 matches and5,000 source-backed
six-byte private-caller wins, with zero validation/generator/command failures.
All 20 retained residual outputs match the prior reviewed checkpoint. This is an
agent/reviewer classification; runtime/property modes are off and no GC alias
coverage is implied by that aggregate.

A separate 256-case `campaign-gc-ref-subtypes` lane with `--semantic-oracle node-v2`
passes 256 normalized and 256 primary original/Starshine/Binaryen runtime cases,
zero blocked/failing cases. The initial sandboxed runtime blocks are preserved;
local subprocess approval resolved them with the identical input manifest.
Reduced positive public/whitebox fixtures supply alias, shifted-group, import,
global/local and protected identity coverage. Exact commands, hashes, size/RSS
tradeoffs, remaining gap and observation limits are in the linked checkpoint.

## September 27 follow-up allocation campaign renewal

The [final follow-up report](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
uses native CLI `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`,
verified Binaryen 133, seed `0x5eed`, eight subprocesses and 10,000 cases
per listed aggregate. It supersedes pending renewal for the follow-up
allocation changes and earlier current-baseline wording. New evidence
requires verified v133; older dated results retain their original scope.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | --- | ---: | ---: | ---: | ---: |
| `duplicate-function-elimination` | `duplicate-function-elimination` | 5,000 / 0 | 5,000 | 0 | 10,000 / 0 |

Validation, generator, property-counter, command and observed Starshine/
original semantic failures are zero. Blocked runtime cases remain unverified.
The report owns exact commands, normalizers, cache use, size-loss and retained
baseline replays, downstream evidence and agent classifications. Residual
parity/size gaps are not closed by validation or smaller output alone.

The profile exports no functions, so its runtime-match counter does not
establish body execution. All 5,000 fixed-point caller residuals are identical
to the starting compiler, save six canonical bytes and converge to identical
bytes after common v133 `-Oz`; the report documents the inspected private-call
contract supporting this scoped win.

Local results: `.tmp/pass-perf-next-20260927/final-fuzz-duplicate-function-elimination/result.json`.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

Recommended smoke lane: run the dedicated GenValid profile for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --gen-valid-profile duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The bounded `duplicate-function-elimination` profile alternates between an exact
duplicate function pair and a fixed-point family where merging duplicate leaf
callees makes their callers identical. Every generated case contains an owned
DFE trigger. Manifests record either
`duplicate-function-elimination:exact-pair` or
`duplicate-function-elimination:fixed-point-callers` in `profile_case_label`,
and the profile participates in `random-all-profiles`.

This initial trigger profile does not cover transitive indexed type/reference
remapping, annotations, exported identity boundaries, or proposal features. No
fuzz campaign was run when it was added.

## 2026-08-21 final16 transitive type-remap development lane

After repairing recursive indexed references inside retained compacted function types, the authoritative pinned-v131 command was:

```sh
bun fuzz compare-pass --pass duplicate-function-elimination --count 10000 --seed 0x5eed --max-failures 2000 --keep-going-after-command-failures --jobs auto --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/dfe-transitive-type-remap-v131-10000-20260821
```

Results:

- requested / compared: 10,000 / 10,000
- normalized matches: 9,942
- raw mismatches: 58
- validation failures: 0
- property failures: 0
- generator failures: 0
- command failures: 0
- Binaryen cache: 2 hits / 9,998 misses

All 58 raw mismatch inputs replay as raw mismatches with the exact final14-era baseline binary in `.tmp/dfe-transitive-type-remap-final14-mismatch-replay-20260821/`. They therefore predate the transitive kept-type repair. This replay classifies only introduction provenance; the current raw residual families remain open until inspected and must not be called semantically safe merely because both outputs validate.

The lane is development evidence, not a fresh full four-lane DFE closeout. The
current pass-owned trigger profile still does not cover transitive
duplicate-type/reference chains.

## 2026-08-26 fixed-partition performance checkpoint

The accepted serial DFE checkpoint renewed the pinned-v131 ordinary lane with bounded host pressure:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-dfe-fixed-partition-regular-10000 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Results:

- requested / compared: 10,000 / 10,000
- normalized matches: 9,942
- raw mismatches: 58
- validation, property, generator, and command failures: 0
- canonical sizes: 42,076,533 Starshine bytes versus 42,076,677 Binaryen bytes
- canonical smaller / equal / larger: 58 / 9,942 / 0
- mismatch artifacts: 20 persisted and 38 suppressed under the explicit cap

The counts and canonical-smaller-only residual family match the documented August 21 baseline, so this performance slice introduces no new parity or size-loss family.

The runtime-callable self-semantic lane used the same seed and explicit subprocess/artifact caps under `.tmp/pass-fuzz-dfe-fixed-partition-runtime-100`:

- checked / matched: 100 / 100
- blocked / mismatching: 0 / 0
- validation, property, generator, and command failures: 0
- canonical sizes: exactly equal on all 100 cases

The later pass-owned profile covers exact pairs and one fixed-point caller
family. The ordinary lane remains the broader evidence for type compaction and
other shapes until dedicated leaves are added.

## September 13 legacy exception type traversal

RSE's use of shared signature interning exposed missing legacy `try` traversal.
A failing-first structural regression in
[`rse_legacy_type_parity_wbtest.mbt`](../../../../../src/passes/rse_legacy_type_parity_wbtest.mbt)
checks the enclosing block type and nested body/catch block types through
direct and public RSE dispatch. The shared type-reference scanner and rewrite
entrypoints now traverse all these regions, preserving tags, catch order and
delegate labels, with explicit mutation flags. The
[follow-up ledger](../../../ir2/architecture-rules.md#september-13-parity-follow-up)
records final source validation and renewed Binaryen 132 comparisons.

## September 13 numeric local declaration grouping

The broader ordinary lane also exposed 7,022 raw-size losses from fragmented
numeric local declaration runs at checkpoint `68824e869`, despite canonical
agreement or nop savings. A direct/public failing-first fixture now groups
`[i64,i64,i32,i64]` into `[i64,i64,i64,i32]` and remaps reads and writes, saving
two bytes. DFE reuses the established numeric grouping helper after name
stripping and type canonicalization. Its existing legacy-`try` entry boundary
remains unchanged. Declaration-only change detection avoids NaN equality;
acceptance requires whole-module validation and a strict encoded byte saving.
A bounded 127/128 local-index regression declines grouping when wider operand
encodings outweigh the declaration savings. Changed modules pay an additional
encoding/validation cost; unchanged declaration layouts skip that work.

That grouping checkpoint reduced raw-size losses to 877; the remaining sampled
case retained an unused plain function signature. A further failing-first
fixture now removes an unused prefix signature while preserving and remapping
both function and tag roots, saving five encoded bytes. After grouping, DFE
prunes types only when all definitions are independent unshared singleton
function signatures without indexed references, descriptors or supertype links.
It reuses the shared liveness/remapping helper and accepts only fewer types,
strict encoded-size savings and whole-module validation. Unchanged type counts
skip additional encoding/validation. The existing legacy-exception module
boundary remains unchanged.

The subsequent 10,000-case checkpoint reduced raw-size losses to 57. All 57
retained duplicate live plain signatures on the unchanged-function fast path;
read-only type-section inspection accounts for the entire encoding overhead.
A further direct/public failing-first regression keeps two distinct function
bodies while interning their equivalent signatures. The guarded encoding
cleanup now interns before pruning, still requiring validation and a strict
whole-module byte saving. This does not widen the supported type or legacy
exception boundaries. Final renewed evidence is in the follow-up ledger.
