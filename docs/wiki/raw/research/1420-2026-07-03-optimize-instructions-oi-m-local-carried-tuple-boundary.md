# Optimize-instructions OI-M local-carried tuple producer boundary

_Date:_ 2026-07-03

_Status:_ OI-M-SB003 narrowed by source-backed Binaryen probes; OI-M remains active/P0 for generalized tuple-scratch reconstruction and control/EH siblings.

## Question

Does Binaryen `version_130` `--optimize-instructions` rewrite `tuple.extract` through tuple-valued locals or shared tuple producers, or are those shapes outside the direct one-use `tuple.extract(tuple.make(...))` localizer that Starshine has been implementing?

## Probe evidence

Three local probes cover the tuple-valued producer surface:

- `.tmp/oi-m-local-carried-oneuse-sb003-20260703.wat`: a tuple value is stored to a tuple-typed local, loaded once, and extracted.
- `.tmp/oi-m-localtee-tuple-producer-sb003-20260703.wat`: a `local.tee` writes the tuple value before extraction.
- `.tmp/oi-m-tuple-multiuse-probe.wat`: a tuple-typed local is read by two `tuple.extract` users.

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-local-carried-oneuse-sb003-20260703.wat -o .tmp/oi-m-local-carried-oneuse-sb003-20260703.binaryen.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-localtee-tuple-producer-sb003-20260703.wat -o .tmp/oi-m-localtee-tuple-producer-sb003-20260703.binaryen.wat
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiuse-probe.wat -o .tmp/oi-m-tuple-multiuse-probe-sb003-20260703.binaryen.wat
```

Binaryen preserved the `tuple.extract` through the tuple local in all three outputs. The one-use local-carried output kept `local.set $t`, `local.get $t`, and `tuple.extract 2 1`; the `local.tee` output kept `tuple.extract 2 1 (local.tee $t (tuple.make ...))`; the multi-use output kept both tuple extractions through the shared local.

## Classification

This evidence narrows `OI-M-SB003`: tuple-valued local-carried and multi-use tuple producers are source-backed no-rewrite/boundary shapes for `--optimize-instructions` alone. Starshine should not implement speculative tuple-value dataflow scalarization for this surface as an OI-M parity requirement unless new Binaryen source/lit/probe evidence shows that the pass intentionally rewrites a sub-shape.

The grouped `pass-oi-tuple` labels named `local-carried-selected-lane`, `localtee-produced-selected-lane`, `call-produced-selected-lane`, `select-produced-selected-lane`, and randomized existing/effect/trap labels are still active OI-M evidence, but they are better owned by `OI-M-SB005` generalized tuple-scratch reconstruction/localization when the residual is Binaryen's scalarized-local spelling for multivalue block lanes. Runtime-green raw mismatches remain supporting evidence only.

## Starshine notes

`src/passes/optimize_instructions_test.mbt` keeps the direct-HOT multi-use tuple boundary and its comment now cites the one-use local-carried, local.tee, and multi-use Binaryen probes. A public WAT pass test for tuple-typed local fixtures is not currently used here because the Starshine WAT test helper does not accept the tuple-typed local syntax used by the Binaryen probes; the durable pass-level guard remains the existing direct-HOT multi-use boundary.

No behavior implementation landed in this slice, so red-first positive pass coverage is not applicable. The focused boundary command passed:

```sh
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*multi-use tuple.make boundary*'
```

Result: `1/1` passed.

## OI-M effect

- `OI-M-SB003` can be treated as an intentional/source-backed tuple-valued local/multi-use boundary rather than a P0 implementation blocker.
- `OI-M-SB004` remains blocked/fail-closed for control/branch/EH/nested-region siblings.
- `OI-M-SB005` remains the main active P0 implementation blocker for generalized tuple-scratch reconstruction/localization and the remaining selected-lane raw mismatch labels.
- OI-M stays active/P0; do not infer OI-G or OI-I/OI-J/OI-K closure from this evidence.

## Reopening criteria

Reopen `OI-M-SB003` if Binaryen source, lit tests, or local probes show `--optimize-instructions` rewriting a tuple-valued local-carried, `local.tee`, or shared/multi-use tuple producer; if Starshine drops or duplicates a shared tuple producer/effect/trap; if future HOT/WAT support exposes a safe source-backed sub-shape that Binaryen actually optimizes; or if a runtime/validation failure appears in a case previously classified as a tuple-valued local/multi-use boundary.
