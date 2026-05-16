# DAE002 Func 42 shape cleanup plus low-callee prefix revisit moves the artifact frontier to Func 81

Date: 2026-05-15

## Question

After the forwarded-const + low-prefix exact-literal revisit reached Func 42 directly, what remaining safe slice moves the live `--dae-optimizing` artifact diff forward without reopening the earlier broad-sweep regressions?

## Result

Partially.

Two narrow follow-ups landed safely:

1. a tiny post-rewrite cleanup now removes `+ 0` address drift and normalizes the nearby `const ; local.get ; i32.add` shape that remained in the direct Func 42 rewrite; and
2. after the existing low-prefix exact-literal revisit, DAE now runs a **low-callee core revisit** over high callees that are directly called by the first `64` defined functions.

That moves the full artifact compare from:

- `defined=25 abs=42`

to:

- `defined=64 abs=81`

So the remaining red compare is no longer the original Func 42 family.

## What changed

### Func 42 post-rewrite shape cleanup

The direct Func 42 rewrite on the original artifact was already reaching the right 2-param signature, but Starshine still left two small body-shape drifts that Binaryen folded away:

- `i32.add(i32.const 0)` / `(i32.const 0) i32.add` around the rewritten `memory.copy` addresses; and
- a nearby `i32.const 8 ; local.get ; i32.add` ordering difference.

A tiny touched-only simplifier now:

- drops adjacent `i32.const 0 ; i32.add` / `i64.const 0 ; i64.add` pairs in rewritten bodies; and
- reorders adjacent `const ; local.get ; add` into `local.get ; const ; add` for the rewritten scalar address family.

This is intentionally local to the rewritten DAE body-shape cleanup lane.

### Low-callee core revisit

The next live compare blockers after Func 42 were not another exact-literal reach miss in the low prefix itself. They were higher-index direct callees such as the original artifact families behind low wrappers:

- Func 51 -> Func 1530
- Func 58 -> Func 1571

Those higher callees are already directly rewritable, but the normal `8`-iteration core never scans far enough to reach them.

The new follow-up reuses the existing full core safety lane, but only for defs selected from the direct callees of the first `64` defined callers.

This avoids a whole-module extra sweep while letting low wrappers pull a narrow set of higher callees into the core.

## Evidence

### New focused tests

`src/passes/dae_optimizing_test.mbt`

- adds a reduced regression proving DAE now removes add-zero address drift after rewriting a const `memory.copy` offset parameter.

`src/passes/pass_manager_wbtest.mbt`

- proves the direct original-artifact Func 42 rewrite no longer leaves add-zero / const-before-local address drift;
- proves `dae_run_core(...)` now rewrites the high original-artifact callees behind low wrappers at Func 51 / Func 58.

### End-to-end artifact compare

Validated compare:

- out dir: `.tmp/dae002-confirmed-artifact`
- first diff: `defined=64 abs=81`
- Starshine pass runtime: `120946.581ms`
- Binaryen pass runtime: `939.053ms`

So the landed slice improves artifact reach again, but DAE still remains far slower than Binaryen and still does not have full artifact parity.

## Important non-landed evidence

A local experiment widened the low-callee caller window to `128` defined functions.

That pushed the live compare farther again, to:

- `defined=128 abs=145`

but it also blew the pass-local runtime up to roughly:

- Starshine `211635.689ms`
- Binaryen `946.101ms`

That widening was **not kept**. The retained checkpoint keeps the caller-prefix window at `64` and records the `128` experiment only as evidence that naive boundary chasing is too expensive.

## Interpretation

The remaining blocker changed again:

- it is no longer the original Func 42 post-rewrite body shape;
- it is no longer just the first low-wrapper high-callee family behind Func 51 / Func 58;
- and a simple caller-prefix widening strategy is not acceptable because it scales runtime too aggressively.

So the next safe slice should be **more selective than widening the caller window**. The likely direction is another targeted selector for the remaining low-wrapper / high-callee family around the new boundary at `defined=64 abs=81`, not a broad prefix increase.

## Validation used

- `moon update`
- `moon fmt`
- `moon test src/fs/fs_test.mbt --no-parallelize`
- `moon test src/passes --no-parallelize`
- `moon build src/cmd --release`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-confirmed-artifact --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`
