# Binaryen `inlining` current-main port-readiness primary sources

Date captured: 2026-04-26

## Scope

Focused current-main recheck for the plain Binaryen `inlining` pass after the existing tagged `version_129` dossier in `docs/wiki/raw/binaryen/2026-04-23-inlining-primary-sources.md`.

This manifest is intentionally narrow: it does not replace the tagged source manifest. It records the current upstream files and the Starshine-facing implementation-readiness conclusions needed for the living `inlining` wiki pages.

## Primary online sources checked

Official Binaryen repository sources:

- `src/passes/Inlining.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
- `src/passes/Inlining.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- `src/passes/pass.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/pass.h` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `src/passes/NoInline.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>
- `src/ir/module-utils.cpp` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
- `test/lit/passes/inlining_optimize-level=3.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_optimize-level=3.wast>
- `test/lit/passes/inlining_splitting.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_splitting.wast>
- `test/lit/passes/inlining_splitting_basics.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_splitting_basics.wast>
- `test/lit/passes/inlining-trivial-instructions.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-trivial-instructions.wast>
- `test/lit/passes/inlining-trivial-calls-1.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-trivial-calls-1.wast>
- `test/lit/passes/inlining-unreachable.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-unreachable.wast>
- `test/lit/passes/inlining-gc.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-gc.wast>
- `test/lit/passes/no-inline.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline.wast>
- `test/lit/passes/no-inline-monomorphize-inlining.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline-monomorphize-inlining.wast>
- `test/lit/passes/inline-main.wast` on current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inline-main.wast>

## Source locations that matter

- `src/passes/Inlining.cpp` owns the `Inlining` pass class, `FunctionInfoScanner`, function classification, full/partial inline planning, callsite action collection, action application, and helper removal.
- `src/passes/pass.cpp` publishes both `inlining` and `inlining-optimizing` through the same pass class; the boolean mode controls whether the nested useful-pass rerun happens after inline rewriting.
- `src/pass.h` owns default inlining heuristic knobs such as small-size and flexible-size thresholds.
- `src/passes/NoInline.cpp` owns the separate `no-inline`, `no-full-inline`, and `no-partial-inline` passes that set function-level inliner-blocking flags.
- `src/ir/module-utils.cpp` is relevant because copied functions preserve the function-level no-inline flags through clone/copy paths used by neighboring transforms.

## Current-main drift result

No teaching-relevant drift was found from the existing `version_129` plain-`inlining` contract:

- `inlining` remains the shared inliner engine with the optimizing suffix disabled.
- The core planning surface remains direct-call / `return_call` inlining, not indirect-call or table-call rewriting.
- The source still distinguishes function reference/root survival from callsite replacement: exported, start, table/ref-used, or otherwise rooted functions may still survive after callsites inline.
- The no-inline policy surface remains function flags set by the no-inline pass family, not the preserved `@metadata.code.inline` bytes.
- The split-inlining families remain narrow top-of-function conditional patterns rather than a general outlining engine.

## Starshine-facing port-readiness conclusions

A faithful Starshine port needs a boundary/module pass, not a HOT peephole:

1. collect module-wide function summaries and roots;
2. classify callees before mutating callsites;
3. plan deterministic direct-call / `return_call` actions;
4. copy callee bodies into caller bodies with local, label, return, tail-call, type, and nondefaultable-local repair;
5. remove private helpers only after surviving roots and uses are rechecked;
6. keep plain `inlining` from accidentally running the optimizing sibling's post-inline cleanup suffix.

## Uncertainty and caveats

- This manifest is a source-location and drift recheck, not a line-by-line proof transcript.
- Starshine has no owner file for `inlining` today, so all local implementation sequencing below the registry/request-guard layer is a future-port plan.
- Current-main Binaryen can continue to drift after 2026-04-26; refresh this manifest before implementing the pass.
