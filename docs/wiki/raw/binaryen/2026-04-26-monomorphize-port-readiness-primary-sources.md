# Binaryen `monomorphize` port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/monomorphize/starshine-port-readiness-and-validation.md` bridge

## Scope

This file captures the primary sources rechecked while adding the Starshine implementation-readiness bridge for `monomorphize`.
It is intentionally provenance-heavy; use the living wiki pages for the beginner-to-advanced explanation:

- `docs/wiki/binaryen/passes/monomorphize/index.md`
- `docs/wiki/binaryen/passes/monomorphize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize/wat-shapes.md`
- `docs/wiki/binaryen/passes/monomorphize/starshine-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/monomorphize-always/index.md`

## Official Binaryen sources rechecked

- `Monomorphize.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Monomorphize.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- representative lit proof files:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-benefit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-consts.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-limits.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-mvp.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/monomorphize-types.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline-monomorphize-inlining.wast>

## Source-backed observations from the 2026-04-26 recheck

- Current `main` still registers both public names in `pass.cpp`: `monomorphize` and `monomorphize-always`.
- Current `main` still exposes the `--pass-arg=monomorphize-min-benefit@N` argument in `Monomorphize.cpp` and documents it as a percentage threshold where larger values are more careful.
- Current `main` still defaults the internal minimum-percent benefit to `95` and keeps the hard `MaxParams = 20` cap with a Web-limit static assertion.
- Current `main` still models specialization through `CallContext`, where operands are executable IR placed at the start of the specialized function and the `dropped` flag represents the caller-side dropped-result context.
- Current `main` still scans the original defined-function snapshot before adding clones, skips unreachable calls, skips recursive self-calls, rejects imported targets, weakens dropped-result specialization when the target has return-call behavior, memoizes `(target, context)` outcomes, and builds clones with `makeMonoFunctionWithContext(...)`.
- Current `main` still splits the sibling only at policy construction: `createMonomorphizePass()` uses helpfulness gating while `createMonomorphizeAlwaysPass()` keeps the same legality machinery without that helpfulness rejection.
- No teaching-relevant drift from the 2026-04-24 `version_129` dossier was found. The new durable gap was not upstream strategy correction; it was Starshine first-slice and validation sequencing.

## Local Starshine surfaces rechecked

- `src/passes/optimize.mbt`
  - boundary-only name registry includes `monomorphize` and `monomorphize-always`
  - explicit active requests still reject boundary-only passes instead of running a transform
- `src/cli/cli.mbt`
  - parses `--monomorphize-min-benefit`
- `src/cmd/cmd.mbt`
  - parses config aliases `monomorphizeMinBenefit` and `monomorphize-min-benefit`
  - merges CLI/env/config values
  - defaults the local stored option to `5`
  - forwards the option into `OptimizeOptions`
  - prints the nondefault value in reproduction notes
- `src/cli/cli_test.mbt` and `src/cmd/cmd_wbtest.mbt`
  - prove CLI and command-summary roundtrips for the option

## Uncertainties and non-goals

- Starshine's local default value `5` is option plumbing only today; it should not be interpreted as a locally implemented pass threshold until an actual `monomorphize` pass consumes it.
- The best future local implementation layer is still a design question: it needs whole-module mutation, call collection, function cloning, call retargeting, and nested optimization/cost comparison. This capture does not decide whether that lands as a new module-pass subsystem or as a narrow first implementation behind the current optimizer dispatcher.
- This recheck did not attempt to prove full line-for-line equivalence between current `main` and `version_129`; it checked the strategy surfaces relevant to the port-readiness bridge and found no teaching-relevant drift.
