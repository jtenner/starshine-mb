---
kind: raw-source
status: current
last_reviewed: 2026-07-11
sources:
  - ../../tooling/pass-fuzz-compare.md
  - ../../binaryen/passes/type-merging/fuzzing.md
  - ../../binaryen/passes/inline-main/fuzzing.md
  - ../../binaryen/passes/monomorphize/fuzzing.md
  - ../../binaryen/passes/monomorphize-always/fuzzing.md
  - ../../binaryen/passes/souperify/fuzzing.md
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../src/passes/optimize.mbt
related:
  - ../../tooling/pass-fuzz-compare.md
  - ../../binaryen/passes/type-merging/index.md
  - ../../binaryen/passes/inline-main/index.md
  - ../../binaryen/passes/monomorphize/index.md
  - ../../binaryen/passes/souperify/index.md
---

# Pass-Fuzz Admission Boundary Audit (2026-07-11)

## Purpose

This local-source audit corrects a recurring documentation error: a public Binaryen pass can be real while a Starshine `compare-pass` command for it is not runnable. The executable admission contract belongs to Starshine's current harness and registry, not to upstream pass availability.

## Local executable evidence

Checked on 2026-07-11:

- `scripts/lib/pass-fuzz-compare-task.ts` keeps the harness allowlist in `SUPPORTED_PASS_FLAGS`. It admits `inlining`, but it does **not** admit `inline-main`, `monomorphize`, `type-merging`, or `souperify`.
- `src/passes/optimize.mbt` keeps `inline-main`, `monomorphize`, and `type-merging` in `pass_registry_boundary_only_names()`. An explicit request reaches the known-name guard and returns a boundary-only-not-implemented error instead of running a transform.
- The same registry contains no `souperify` or `souperify-single-use` spelling. A local request is an unknown-pass failure, not a boundary-only request.
- `docs/wiki/tooling/pass-fuzz-compare.md#pass-eligibility-preflight` requires four gates before a long lane: harness admission, active Starshine admission, valid Binaryen mapping, and an input surface with a meaningful comparison threshold.

Therefore, a rejected command, a command with zero comparisons, or a `--list-passes` result is **status evidence only**. It is not Binaryen parity evidence.

## Upstream primary-source check

The current official Binaryen pass registry still registers all four relevant public pass names:

- `inline-main`;
- `monomorphize` (and `monomorphize-always`);
- `souperify` (and `souperify-single-use`); and
- `type-merging`.

The reviewed current-main owner files remain the relevant implementation homes: `Inlining.cpp`, `Monomorphize.cpp`, and `Souperify.cpp`; type-merging remains registered as its own public pass. This confirms an important non-equivalence: upstream registration does not imply current Starshine registry or harness admission.

## Durable conclusions

1. **Publish a runnable `compare-pass` command only when all four preflight gates are satisfied.** A real upstream flag alone is insufficient.
2. **Boundary-only and unknown are distinct failures.** Boundary-only proves Starshine intentionally tracks a future name; unknown proves it does not currently admit the name at all. Neither executes a transform.
3. **`souperify` needs a different oracle shape.** It emits Souper text rather than a transformed wasm module, so normalized Starshine-vs-Binaryen wasm output is not automatically the right future oracle even after a local implementation exists.
4. **Feature-sensitive module passes need directed fixtures.** In particular, `type-merging` needs closed-world GC type-graph cases; `inline-main` needs the exact `main` / `__original_main` wrapper shape; and `monomorphize` needs call-context, clone, result-drop, and usefulness-gate cases. Generic valid-module generation does not establish those contracts.
5. **No external source is needed to decide present compare-pass admission.** The checked-in allowlist, registry, and harness preflight are executable local authority. The upstream source check is retained only to prevent “not runnable locally” from being misread as “not a Binaryen pass.”

## Primary sources

- Binaryen current pass registry: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Binaryen current inline-main/inlining owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Inlining.cpp>
- Binaryen current monomorphize owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Monomorphize.cpp>
- Binaryen current Souper trace-emission owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Souperify.cpp>
