---
kind: workflow
status: working
last_reviewed: 2026-09-23
sources:
  - ./engine-state-genvalid.md
  - ./semantic-optimizer-campaigns.md
  - ../binaryen/passes/flatten/fuzzing.md
  - ../binaryen/passes/optimize-instructions/fuzzing.md
  - ../wasm-compact-import-section-boundary.md
  - ../../../src/validate/gen_valid_engine_profiles_wbtest.mbt
  - ../../../scripts/pass-fuzz-compare.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - https://github.com/WebAssembly/binaryen/issues/8325
related:
  - ./engine-state-genvalid.md
  - ./semantic-optimizer-campaigns.md
  - ../binaryen/passes/flatten/fuzzing.md
  - ../binaryen/passes/optimize-instructions/fuzzing.md
  - ../wasm-compact-import-section-boundary.md
---

# Engine-profile optimizer deep dive

## Scope and toolchain

On 2026-09-23 the four engine-oriented GenValid aggregates were exercised
against every one of the 59 direct passes exposed by the comparison harness.
One exact weighted cycle per profile produced 155 deterministic modules:

| Profile | Cases per pass | Passes | Requested comparisons |
| --- | ---: | ---: | ---: |
| `engine-compile-shapes` | 48 | 59 | 2,832 |
| `engine-proposal-matrix` | 24 | 59 | 1,416 |
| `engine-state-core` | 64 | 59 | 3,776 |
| `engine-tiering-stress` | 19 | 59 | 1,121 |
| **Total** | **155** | **59** | **9,145** |

The root seed was `0x5eed`. The prebuilt Starshine command SHA-256 was
`9205e121302d8c32627a5cf6280fb73781b7c361c9d354fc1321d0654730c4cb`;
the native generator SHA-256 was
`ab32051966346fd888d4e26c9d282619c19c746b8ad939a82c629847ff5692f5`.
The oracle was `wasm-opt version 132 (version_132-100-gfbf2e5aa2)`, SHA-256
`500201b4d13ccc3a61fa5254073e75a138bc57be198bd6c18c5a9562c081ad18`.
Independent validation used `wasm-tools 1.251.0 --features all`; semantic
observation used `node-v2` with Node 24.21.0, trap-aware stateful comparison,
and a five second runtime timeout.

All 155 original artifacts passed independent validation and compiled in Node
24.21.0 and Wasmtime 49.0.0. The pass matrix then ran twice over identical
inputs: first for strict normalized structure plus determinism and codec
stability, and again with stateful Node semantic observation.

## Exact-cycle results

| Check | Result |
| --- | ---: |
| Requested / compared | 9,145 / 9,141 |
| Strict normalized matches | 7,157 |
| Strict structural mismatches | 1,984 |
| Binaryen command failures | 4 |
| Starshine validation failures | 0 |
| Generator failures | 0 |
| Determinism byte-stable | 9,145 / 9,145 |
| Codec idempotence stable | 9,145 / 9,145 |
| Original-vs-Starshine semantic matches | 9,086 |
| Original-runtime blocked | 59 |
| Original-vs-Starshine semantic mismatches | 0 |

The semantic classifications split into 2,831 `all-equal` cases, 6,255
`binaryen-discrepancy` cases, and 59 `original-runtime-blocked` cases. A
`binaryen-discrepancy` does not by itself prove a Binaryen defect: the dominant
inspected runtime boundary was Binaryen's proposal-enabled compact-import
encoding, which `wasm-tools` and Starshine accepted while Node 24 rejected.

Every one of the 236 pass/profile cells had at least one strict output-shape
difference. The largest pass totals were:

| Pass | Compared | Structural mismatches | Command failures |
| --- | ---: | ---: | ---: |
| `flatten` | 151 | 142 | 4 |
| `remove-unused-module-elements` | 155 | 108 | 0 |
| `remove-unused-nonfunction-module-elements` | 155 | 108 | 0 |
| `dae2-optimizing` | 155 | 73 | 0 |
| `precompute-propagate` | 155 | 70 | 0 |
| `precompute` | 155 | 65 | 0 |
| `simplify-locals` | 155 | 59 | 0 |
| `simplify-locals-no-structure` | 155 | 58 | 0 |
| `simplify-locals-nostructure` | 155 | 58 | 0 |

By profile, `engine-compile-shapes` produced 472 differences,
`engine-proposal-matrix` 338 differences plus the four oracle failures,
`engine-state-core` 934 differences, and `engine-tiering-stress` 240
differences. Mismatch artifacts were deliberately suppressed in this broad
inventory. The 1,984 rows therefore remain unclassified parity gaps; semantic
agreement and valid output are not enough to classify them as safe or as
Starshine wins.

## Incident classification

| ID | Owner | Status | Finding | Required disposition |
| --- | --- | --- | --- | --- |
| `EPD-STAR-001` | Starshine OptimizeInstructions | Fixed in focused tests; aggregate rerun open | The original campaign found one-invocation structural-idempotence failures for three compile-shape leaves. Commits `7fe999fcc`, `204114e05`, and `373c4fbc7` added pass/dispatcher tests and repaired their fixed points. | Rerun the scaled aggregate on the repaired build and retain any remaining failures. |
| `EPD-PARITY-001` | Starshine pass parity | Open inventory | The exact matrix has 1,984 strict normalized differences across all 236 pass/profile cells; the scaled OptimizeInstructions seed adds 657 strict differences. Neither run retained broad mismatch artifacts, and overlap between their families is unknown. | Rerun targeted pass/profile cells with a nonzero artifact cap, group and reduce fingerprints, then fix or prove a measured Starshine benefit family by family. |
| `EPD-BIN-001` | Binaryen 132 | External open issue | `--all-features --flatten` aborts on four valid result-typed `try_table` inputs with `unexpected expr type` at `Flatten.cpp:231`. Starshine Flatten succeeds and its outputs validate. | Keep as an oracle/tool failure, retain the minimal repro below, and track upstream [Binaryen issue #8325](https://github.com/WebAssembly/binaryen/issues/8325). Do not count these rows as Starshine mismatches. |
| `EPD-RUNTIME-001` | Node capability | Expected external boundary | Node 24 rejects compact-import marker byte `0x7f` in representative Binaryen `--all-features` outputs although `wasm-tools` accepts them. | Use a proposal-capable runtime or project compact imports to ordinary imports before Node comparison; do not label this a Binaryen miscompile. |
| `EPD-OBS-001` | Node semantic worker / local load | Open diagnostic | One scaled `ssa-fresh-set` Starshine observation timed out at the one-second subprocess limit while the original and byte-identical Binaryen output completed. | Replay case 234 with a larger timeout before treating it as a pass defect; the harness correctly records it as tool-resource uncertainty rather than a mismatch. |
| `EPD-GEN-001` | GenValid execution contract | Expected workload boundary | The `ssa-loop` leaf intentionally sets its loop condition true forever. It accounts for one original-runtime timeout in each of the 59 pass campaigns. | Filter this leaf from bounded runtime lanes or treat its timeout as an expected blocked original; keep it for compiler/control-shape coverage. |
| `EPD-OPS-001` | Local environment | Resolved operationally | The 32 GiB `/tmp` tmpfs was full and initially prevented the native release build. | Point `TMPDIR` at a repository-local ignored directory for long campaigns and check free space before interpreting compiler failures. |
| `EPD-OPS-002` | Native batch runner | Documented contract | The emitter requires an existing parent and a nonexistent leaf output directory. A leaf left by an interrupted run causes an opaque release-mode abort; debug mode reports `File exists`. | Allocate a fresh leaf per run. Preserve or rename partial evidence before resuming; never reuse a populated leaf as if it were resumable. |

## `EPD-STAR-001`: OptimizeInstructions fixed-point gap

The scaled `optimize-instructions` property lane uses seed `0xdecafbad`, 16
exact aggregate cycles per profile, independent validation, stateful Node v2,
determinism, codec idempotence, structural idempotence, semantic idempotence,
and convergence with a maximum of eight applications.

| Profile | Requested | Compared | Strict mismatches | Property failures |
| --- | ---: | ---: | ---: | ---: |
| `engine-compile-shapes` | 768 | 720 | 80 | 48 |
| `engine-proposal-matrix` | 384 | 384 | 96 | 0 |
| `engine-state-core` | 1,024 | 1,024 | 273 | 0 |
| `engine-tiering-stress` | 304 | 304 | 208 | 0 |
| **Total** | **2,480** | **2,432** | **657** | **48** |

The 48 property failures stop before ordinary Binaryen structural comparison,
which explains the requested/compared difference. All 2,480 determinism and
codec checks are stable. Structural idempotence passes 2,432 and fails 48.
Semantic idempotence and convergence check all 2,480 cases: 2,464 pass and the
16 intentional `ssa-loop` cases are blocked. There are no generator,
validation, or command failures.

The failures repeat at the same three positions in every
`engine-compile-shapes` cycle:

- `flatten-ifs` / `flatten:if-results`;
- `flatten-loops`;
- `ssa-merge-explicit`.

For each retained failure, `M1 = pass(input)` and `M2 = pass(M1)` have distinct
canonical hashes. All generated versions validate; `M0`, `M1`, and `M2` are
semantically equal; and convergence reaches the fixed point at generation 3
because `M3 == M2`. Determinism and codec idempotence are stable. This is a
Starshine pass-completeness/property defect, not evidence of wrong-code.

Representative `flatten-ifs` input computes a constant signed comparison and
branches to `10 + 11` or `12 - 13`. The first invocation rewrites the condition
to unsigned form and folds both arms to `21` and `-1`; the second invocation
selects the constant `21` and drops the condition. That missed second-stage
cleanup was the behavior targeted by the later focused tests and repair.

Subsequent commits `7fe999fcc`, `204114e05`, and `373c4fbc7` cover all three
profile cases in pass and dispatcher tests and repair one-invocation
idempotence. The 48 failures above remain the historical campaign result;
the scaled aggregate has not yet been rerun on those commits.

The normal comparison portion has 657 further strict Starshine/Binaryen
differences. As in the broad matrix, mismatch retention was capped at zero;
these new-seed rows remain unclassified parity evidence rather than being
called safe based on validation or semantic observation.

## `EPD-BIN-001`: Binaryen Flatten abort

The four failing `engine-proposal-matrix` cases select
`engine-state-exceptions` at index 1,
`engine-state-exception-unwind` at indices 5 and 6, and
`campaign-eh-control` at index 19. All reach the same Binaryen assertion. The
following independently valid 83-byte module retains the failure:

```wat
(module
  (tag $exception (param i32))
  (func
    (block $result (result i32)
      (try_table (catch $exception $result)
        (i32.const 0)
        (throw $exception))
      (unreachable))
    (drop)))
```

Reproduction:

```text
wasm-tools parse binaryen-flatten-minimal.wat \
  -o binaryen-flatten-minimal.wasm
wasm-tools validate --features all binaryen-flatten-minimal.wasm
wasm-opt --all-features --flatten binaryen-flatten-minimal.wasm \
  -o /dev/null
```

The last command aborts with status 134 and `unexpected expr type`; the first
two commands succeed. Upstream issue #8325 reports the same Flatten/EH family
on older Binaryen versions, and this campaign confirms it remains present in
the pinned v132 executable.

## `EPD-RUNTIME-001`: compact-import runtime boundary

Binaryen 132 may preserve or emit Compact Import Section groups under
`--all-features`. In the inspected representative, the import section uses the
proposal's `0x7f` shared-module marker. Starshine and `wasm-tools` accept the
module; Node 24.21.0 reports `unknown import kind 0x7f`. This accounts for the
dominant inspected `binaryen-discrepancy` pattern, but the campaign did not
classify every one of the 6,255 rows individually. That full population must
not be collapsed into this explanation without targeted evidence.

## `EPD-OBS-001`: isolated Starshine observation timeout

Scaled compile-shapes case 234 selects `ssa-fresh-set` with label
`ssa:fresh-set-and-retarget`. The original observation completed in about
554 ms and the Binaryen observation in about 507 ms. The Starshine observation
worker crossed the configured one-second limit at about 1,017 ms before it
reported compilation, so the harness classified the comparison as
`blocked-starshine-runtime` / `starshine-tool-resource-uncertainty`.

The Starshine and Binaryen outputs are each 56 bytes in raw and canonical form
and are a strict normalized match. Structural idempotence, semantic
idempotence, convergence, determinism, and codec idempotence all pass for this
case. This is one isolated timeout under concurrent campaign load; it is not
semantic-mismatch evidence. Retain it as an open diagnostic until an isolated
replay with a larger runtime budget succeeds or reproduces a Starshine-specific
runtime stall.

## `EPD-GEN-001`: intentional nontermination

The only original-runtime blocked input is the same `ssa-loop` leaf repeated
once for each direct pass. Its loop sets local 1 to `1`, tests that local, and
branches back while true. The timeout is intentional generated behavior, not a
compiler hang or optimizer regression. Compiler-only lanes should retain the
case; runtime campaigns need either a leaf filter or an expected-timeout rule.

## Operational record

The first release build failed because `/tmp` was full. Rebuilding with
`TMPDIR=.tmp/engine-profile-deep-dive/compiler-tmp` succeeded. No campaign
evidence was deleted to make space.

The native batch emitter creates its leaf directory rather than treating it as
a resumable destination. During semantic-matrix orchestration, an interrupted
`code-folding__engine-tiering-stress` run left a partial leaf. The first retry
failed on that pre-existing directory; the partial tree and log were renamed
with an `.interrupted` suffix and a fresh run completed. This was a campaign
setup failure, not a generated case or pass failure.

## Green evidence and limits

No Starshine validation failure, generator failure, determinism failure, codec
idempotence failure, or observed original-vs-Starshine semantic mismatch was
found in the exact-cycle matrix. Starshine also processed all four modules that
abort Binaryen Flatten. These are useful negative findings, not global pass
signoff: the matrix is one exact cycle per profile, the 1,984 strict differences
remain open, Node cannot execute every proposal encoding, and the scaled
property lane covers OptimizeInstructions rather than all 59 passes.

## Local artifact map

The evidence is retained in ignored local storage and is reproducible rather
than repository-normative:

- `.tmp/engine-profile-deep-dive/exact/`: the four exact generated cycles;
- `.tmp/engine-profile-deep-dive/compare/`: structural/determinism/codec matrix;
- `.tmp/engine-profile-deep-dive/compare-semantic/`: stateful semantic matrix;
- `.tmp/engine-profile-deep-dive/scaled/`: scaled OptimizeInstructions property lane;
- `.tmp/engine-profile-deep-dive/triage/`: aggregate TSV, minimal Flatten repro,
  and retained oracle stderr.

One exact comparison cell can be reproduced with a freshly built native
command and generator:

```text
TMPDIR=.tmp/engine-profile-deep-dive/compiler-tmp \
bun fuzz compare-pass \
  --pass <pass> \
  --count <profile-cycle-size> \
  --seed 0x5eed \
  --gen-valid-profile <engine-profile> \
  --out-dir <fresh-output-directory> \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe \
  --wasm-opt-bin <verified-v132-wasm-opt> \
  --require-binaryen-version 132 \
  --primary-validator wasm-tools \
  --require-independent-validator \
  --semantic-oracle node-v2 \
  --semantic-policy trap-aware \
  --observation-mode stateful \
  --determinism --codec-idempotence \
  --jobs 4 --max-subprocesses 4 \
  --max-mismatch-artifacts 20 \
  --keep-going-after-command-failures \
  --no-reduce-mismatches --report-only
```

Use a nonzero mismatch-artifact cap for follow-up classification. The broad
inventory used zero to keep the 236-cell run bounded, which is why its strict
differences cannot yet be judged family by family.

The scaled property lane used the same base command with these substitutions;
choose the count from the scaled-results table and keep the output leaf fresh:

```text
--pass optimize-instructions \
--count <16-times-profile-cycle-size> \
--seed 0xdecafbad \
--gen-valid-profile <engine-profile> \
--runtime-timeout-ms 1000 \
--property idempotence \
--property semantic-idempotence \
--property convergence \
--convergence-max 8
```
