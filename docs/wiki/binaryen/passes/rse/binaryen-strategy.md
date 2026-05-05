---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md
  - ../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `rse` Strategy

## Upstream source rule

Use [`../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md) as the current provenance anchor.
It rechecked the reviewed Binaryen `main` source against the corrected `version_129` contract on 2026-05-05 and keeps the earlier 2026-04-26 CFG/value-flow correction in force rather than replacing it.

Primary source URLs:

- `RedundantSetElimination.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- current `main` `RedundantSetElimination.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `cfg-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/cfg-traversal.h>
- `rse_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- `rse-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>

## High-level intent

Binaryen uses `rse` to remove writes that assign a local the same value number it already holds and to retarget some local reads to more precise equivalent locals.
The 2026-05-05 current-main recheck stayed aligned with that corrected contract on the reviewed surfaces.
The strategy has three phases:

1. build a CFG-oriented list of local gets/sets per block;
2. compute per-local value-number facts at block starts and ends until the facts converge;
3. rescan each block from its computed start facts and rewrite same-value sets/tees plus subtype-safe refined local gets.

The implementation is small compared with a general dataflow optimizer, but it is not merely straight-line.
The basic-block merge phase is part of the real `version_129` contract.

## Phase 1: collect local expressions while building the CFG

`RedundantSetElimination.cpp` uses a `CFGWalker` instantiation with a visitor over `LocalGet` and `LocalSet`.
For each basic block, Binaryen records:

- `LocalGet*` sites;
- `LocalSet*` sites, including tee and non-tee forms;
- block `start` and `end` local-value arrays.

The pass-level value vocabulary has three important states:

- no known value;
- a local/value-number fact;
- a merge value produced for a block when incoming predecessor values differ.

## Phase 2: flow values through blocks

`flowValues(func)` initializes the entry block and runs a deferred work queue over the CFG.
For each block, Binaryen derives the block `start` local values from predecessors:

- with no predecessors, it uses the entry/default facts;
- with one predecessor, it copies that predecessor's `end` facts;
- with multiple predecessors, each local keeps the agreeing predecessor value, stays unknown if all real values are absent, or gets a block-specific merge value when real incoming values disagree.

Then Binaryen simulates the block's local sets to compute `end` values.
The RHS value number comes from the current value of a referenced local for `local.get` RHSes, or from `ValueNumbering` for other expressions after normalizing fallthrough-producing wrappers with `Properties::getFallthrough(...)`.

The merge values are intentionally conservative but sufficient: if later code sees the same merge value at a write, the write is redundant with the value all paths already delivered to that block.

## Phase 3: optimize gets and sets inside each block

`optimize(func)` starts each block with its computed `start` facts and scans the collected local sites in source order.

### Same-value `local.set` and `local.tee`

For a local write, Binaryen computes the RHS value number and compares it with the current value number for the target local.

If they match:

- a non-tee `local.set` is replaced with the RHS evaluation, preserving effects and traps through a drop-style replacement when needed;
- a `local.tee` is replaced with its value expression, and the pass may request refinalization if the replacement is more specifically typed than the tee.

If they differ, the target local's current value is updated.

### Refined `local.get` retargeting

For a local read, Binaryen looks up other locals currently known to hold the same value number.
It may change the get to read from a different local if that other local's declared type is a strict subtype of the original local's type.

This is why the GC/ref-type test surface matters: the pass can improve reference precision without copying arbitrary expressions.

## What clears or limits facts

The corrected 2026-04-26 reading replaces the earlier “forget at every branch” teaching.
Binaryen does not simply clear everything around branches; it computes block-entry facts through the CFG.

The limits are still conservative:

- different predecessor values become merge values, not speculative copies;
- no liveness proof deletes different-value overwritten writes;
- facts are per local and per value number, not heap/global/memory facts;
- type refinement is limited to local-get retargeting to an already-equivalent local.

## Scheduler placement

`rse` appears late in the no-DWARF function cleanup path, after many local and structural simplifications have already run.
Binaryen's scheduler then relies on `vacuum` to clean debris from removed plain sets.

That order is meaningful:

- earlier passes expose repeated or copied local values;
- `rse` removes redundant set/tee shells and retargets refined gets;
- `vacuum` removes pure `drop` debris that is now unused.

## What the pass explicitly is not

Future docs and ports should avoid these claims unless a newer upstream version or a Starshine-local extension changes scope:

- not global-set elimination;
- not memory-store elimination;
- not `struct.set` / `array.set` elimination;
- not Binaryen `LocalGraph` or liveness;
- not arbitrary overwritten-write deletion;
- not broad same-block expression substitution;
- not general value propagation outside local gets/sets.

## Validation surface

Use the official tests as source-backed examples:

- `test/passes/rse_all-features.wast` and expected output cover ordinary local-value positives, copied-local/branch cases, tees, and negatives.
- `test/lit/passes/rse-gc.wast` covers the reference-type retargeting side.

For Starshine parity, direct `--rse` comparisons should be followed by `--rse --vacuum` or the late no-DWARF tail because Binaryen expects final cleanup after this pass.
