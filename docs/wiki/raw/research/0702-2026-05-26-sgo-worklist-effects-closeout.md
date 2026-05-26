# SGO worklist effects closeout

Date: 2026-05-26
Slice: `[SGO]005` full v0.1.0 self-optimization and 10k fuzzer signoff

## Question

The prior `[SGO]005` signoff attempt left `simplify-globals-optimizing` active because direct and late-tail debug-artifact replays were slightly beyond the repository pass-local speed floor (`Starshine <= 2x Binaryen`) and the full `--optimize` replay was blocked by the known whole-preset `[WALL]001` timeout.

This run asked whether the SGO-owned pass-local runtime gap could be fixed without changing optimizer semantics.

## Changes

- Added a per-function `global_ref_flags` cache in `src/passes/simplify_globals_optimizing.mbt` so same-init marking, read-only-to-write counting, and code rewriting reuse one global-reference scan instead of rescanning every function body separately.
- Replaced the transitive direct-call effect fixed-point loop with a reverse-call worklist. The old loop swept every function/callee edge until convergence; the new worklist propagates a callee's changed read/mutate summaries only to direct callers and requeues callers only when their summary changes.
- Added perf-trace coverage for the new `detail:sgo:collect-function-effects` timer.
- Added a focused transitive direct-callee candidate-read guardrail so the worklist propagation remains behaviorally pinned for a `run -> mid -> read_global` chain.

## Validation

Commands run serially:

- `moon fmt` — passed.
- `moon test src/passes` — passed: `1648/1648`; only existing DAE/pass-manager unused warnings appeared.
- `moon info` — passed; existing DAE unused warnings remained.
- `moon test` — passed: `3724/3724`.
- Direct SGO fuzz:
  - `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-worklist-effects-final-10000`
  - Result: `6759/10000` compared, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `20` Binaryen/tool command failures.
- Ordered late-tail fuzz:
  - `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --pass remove-unused-module-elements --pass string-gathering --pass reorder-globals --pass directize --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-latetail-worklist-effects-10000`
  - Result: `6597/10000` compared, `6597` normalized matches, `0` mismatches, `0` Starshine validation failures, `20` Binaryen/tool command failures.

## Artifact replay

Direct debug-artifact replay:

- Command: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --out-dir .tmp/sgo-worklist-effects-final-direct-artifact --starshine-bin _build/native/release/build/cmd/cmd.exe`
- Result: first diff remains `defined=55 abs=76`.
- Agent classification: representation-only default-local/carrier drift. This is the same previously inspected family, not a semantic mismatch or validation failure.
- Pass-local timing: `120.392ms` Starshine vs `111.796ms` Binaryen, now well inside the 2x floor.

Ordered late-tail replay:

- Command: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --remove-unused-module-elements --string-gathering --reorder-globals --directize --out-dir .tmp/sgo-worklist-effects-latetail-artifact --starshine-bin _build/native/release/build/cmd/cmd.exe`
- Result: first diff remains `defined=55 abs=76`.
- Agent classification: same representation-only default-local/carrier drift.
- Pass-local timing: `251.204ms` Starshine vs `178.442ms` Binaryen, inside the 2x floor.

A manual perf trace after the worklist change showed the SGO call-effect phase dropping to `detail:sgo:collect-function-effects elapsed_us=42109`, with total direct SGO pass time around `126ms` in repeated direct runs. Before this slice, the same phase was implicit and the overall direct pass time was around `248ms`.

## Conclusion

`[SGO]005` is accepted for the SGO-owned direct and late-tail surfaces:

- direct and late-tail 10k fuzz have zero mismatches and zero Starshine validation failures;
- direct and late-tail debug-artifact outputs validate;
- the remaining artifact diff is classified as representation-only default-local/carrier drift;
- direct and late-tail pass-local timings now meet the repository 2x Binaryen floor.

The full public `--optimize` self-compare still times out before artifacts because of the known whole-preset `[WALL]001` runtime/attribution problem. That is no longer an SGO pass-local blocker; rerunning the full preset belongs to `[WALL]001` once full-preset execution is viable.
