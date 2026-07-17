---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ./1645-2026-07-17-daeo-final-direct-closeout-matrix.md
  - ./1584-2026-07-13-daeo-scheduled-mode-specific-blockers.md
  - ./1587-2026-07-13-daeo-post-payoff-matrix-and-scheduled-refresh.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/ssa_nomerge_test.mbt
---

# SSA no-merge batch writeback unblocks public DAEO prefixes

## Fresh owner attribution

Input:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- `3204405` bytes.

Fresh pre-change direct replays used the explicit note-`1645` native binary at SHA-256 `3180bb10194a19fff1c939beee4d6d2b20f1f830aee0be34fa7e37e1097f55fa`.

Direct `--ssa-nomerge --tracing pass` timed out after `600.008s` at absolute Func `2499`. It had completed `2479` per-function raw timers whose sum was only `3.291147s`; the largest raw function was Func `521` at `137571us`. The trace contained only `31` actual `structured-local-writes-mutated` results through Func `2434`.

That split identified the source owner: `run_hot_pipeline_apply_hot_pass(...)` validated every changed SSA no-merge function separately against the same unchanged original module. On this 13162-defined-function artifact, each validation reconstructed module validation state even though SSA no-merge changes function bodies and locals but not cross-function signatures or the type section. The old 600-second run spent almost all CPU outside the raw pass timers in repeated writeback validation.

This is a whole-command/preset runtime owner, not a DAEO semantic or pass-local regression.

## Red-first repair

The new white-box test first referenced `run_hot_pipeline_ssa_nomerge_repair_batch_writeback(...)` and failed to compile because the helper did not exist.

The retained implementation:

1. keeps the existing per-candidate nonvalidation safety guards:
   - invalid escape carriers reject immediately;
   - narrow suspicious escape carriers reject immediately;
2. defers only the expensive `validate_defined_func_against_module(...)` calls;
3. builds the final SSA no-merge candidate module exactly as before, including local grouping/name cleanup/type canonicalization;
4. collects every function whose final candidate body differs from the original;
5. validates that changed-function batch once against the original module context with `validate_defined_funcs_against_module(...)`;
6. restores each invalid candidate function independently and emits the same `skip-invalid-lower` class;
7. falls back to the original per-function validation path if the batch validator itself cannot return a result.

The original module is the validation context intentionally. SSA no-merge does not alter function signatures or the type section in this path, so each changed function sees the same cross-function/type environment as the prior per-function validation. Batch validation changes accounting, not the admitted transform or validation contract.

Vacuum's existing candidate-module batch repair remains separate and unchanged.

## Direct artifact result

Fresh post-change native executable:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `34a21a0bfba0c86520635429047ef8fb4cc0d32f50b0ff060b5d10327d04d680`.

Artifacts: `.tmp/daeo-public-blockers-20260717/direct-ssa-nomerge-after-batch/`.

The direct current-artifact replay now completes:

- traced wall: `43.846s`;
- traced pipeline: `42.935959s`;
- one batch writeback guard: `457957us`;
- untraced repeat wall: `44.954s`;
- output size: `3243378` bytes;
- output SHA-256: `d117e44702d77a563cb20453725cea13b68f191eaa5b77750e7987806645cca6`;
- first and second outputs: byte-identical;
- first and second outputs: valid under `wasm-tools validate --features all`.

The repair therefore replaces a reproducible `>600s` partial run with a deterministic valid complete run. No transform/output win is claimed from timing alone; generated parity evidence below protects the unchanged behavior contract.

## Generated and Moon validation

Authoritative dedicated aggregate:

```sh
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt \
bun scripts/pass-fuzz-compare.ts \
  --count 100000 --seed 0x551a --pass ssa-nomerge \
  --gen-valid-profile ssa-nomerge-all \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-batch-writeback-100000-20260717 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Result:

- requested/compared `100000/100000`;
- normalized `100000`;
- cleanup-normalized `0`;
- mismatches `0`;
- validation/generator/property/command failures `0`;
- selected aggregate distribution remains deterministic;
- Binaryen cache `21055/78945`.

Moon/signoff results:

- red-first compile failure: unbound batch repair helper;
- focused batch repair: `1/1`;
- pass-manager white-box: `286/286`;
- `ssa_nomerge_test.mbt`: `488/488`;
- `moon info`: passed with existing warnings;
- `moon fmt`: passed;
- `moon test src/passes`: `5445/5445`;
- full `moon test`: `8902/8902`;
- native release build: passed with existing warnings;
- no public API or `.mbti` change.

## Exact DAEO scheduling remains locked

The first current note-`1645` dedicated-profile input was rerun through public `--optimize`, `--shrink`, and `--optimize -O4z` with the post-change binary.

Each mode:

- emits the same valid `38`-byte output;
- emits SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- executes exactly one DAEO start/done pair;
- places the late `heap-store-optimization` skip immediately before DAEO;
- places `inlining-optimizing` immediately after DAEO completion.

Trace positions:

| mode | DAEO start | DAEO done | inlining start |
|---|---:|---:|---:|
| optimize | `269` | `494` | `495` |
| shrink | `269` | `494` | `495` |
| O4z | `236` | `428` | `429` |

Plain DAE remains separate; this slice changes only shared hot-pass writeback accounting for direct/public SSA no-merge execution.

## Refreshed public current-artifact owners

The old early SSA no-merge owner from notes `1584` and `1587` is resolved. Fresh `1800s` public traces advance to later independent owners and still do not reach DAEO:

### Public shrink

Artifacts: `.tmp/daeo-public-blockers-20260717/public-shrink-after-ssa-batch/`.

- timeout: `1800.011s`;
- passed the early SSA no-merge slot;
- remained in `remove-unused-brs` at absolute Func `4194`;
- `4174` function events and `2458` mutations were observed;
- actual `pass:remove-unused-brs` timer sum was only `215806us`, with maximum per-function pass work `17638us`.

Agent attribution: the next shrink owner is repeated per-function `remove-unused-brs` writeback validation, the same accounting class just repaired for SSA no-merge. It is a source-backed safe candidate for batch validation because the pass changes function bodies without changing cross-function signatures/types; it still needs its own red-first repair and direct/generated proof.

### Public O4z

Artifacts: `.tmp/daeo-public-blockers-20260717/public-o4z-after-ssa-batch/`.

- timeout: `1800.012s`;
- passed the early SSA no-merge and remove-unused-brs work;
- remained in `heap-store-optimization` at absolute Func `1866`;
- cumulative actual HSO pass time was `623684040us` by that point;
- leading direct HSO owners were Func `1004` `162.447s`, Func `445` `155.182s`, Func `1513` `102.488s`, and Func `60` `85.945s`.

Agent attribution: O4z now has a true pass-local HSO runtime owner, not another validation-only SSA no-merge stall. It requires HSO-specific source/performance attribution; skipping the slot or calling validation/size evidence safe would not be acceptable.

### Public optimize

Fresh direct `--vacuum` remains independently blocked:

- artifacts: `.tmp/daeo-public-blockers-20260717/direct-vacuum/`;
- timeout: `600.007s`;
- user CPU: `598.629s`;
- trace remains in repeated `raw-vacuum-guarded-hazard` preclean classifications;
- no output.

The optimize owner is therefore unchanged and separate from the repaired SSA no-merge accounting path.

## Decision and remaining work

The early SSA no-merge pre-slot blocker is resolved without changing pass semantics, public schedule order, or plain-DAE separation. The DAEO release audit remains incomplete because all large public modes still stop before DAEO:

1. optimize: direct vacuum raw-preclean runtime;
2. shrink: remove-unused-brs per-function writeback validation;
3. O4z: heap-store-optimization pass-local hotspots.

The next bounded safe slice should batch remove-unused-brs writeback validation with the same red-first, original-module-context, invalid-function rollback, fallback, generated-parity, and current-artifact requirements. O4z HSO and optimize vacuum remain separate owners after that slice.
