---
kind: workflow
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ./starshine-port-readiness-and-validation.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `remove-unused-nonfunction-module-elements` Fuzzing

## Current runnable contract

This is an **active Starshine module pass** and an admitted Binaryen
`compare-pass` target. Use the exact public spelling everywhere:

```text
remove-unused-nonfunction-module-elements
```

The historical dashed dossier name, `remove-unused-non-function-elements`, is
**not** a harness or CLI alias. `SUPPORTED_PASS_FLAGS` admits only
`--remove-unused-nonfunction-module-elements`, matching the active registry and
module dispatcher. A command using the historical spelling fails before it can
produce parity evidence.

## Standard direct-pass lane

Build a fresh native CLI first, then run the default GenValid lane. The command
uses the project wrapper so its current harness defaults stay centralized.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass remove-unused-nonfunction-module-elements \
  --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-remove-unused-nonfunction-module-elements \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The default generator is GenValid. No dedicated profile is currently documented;
use ordinary GenValid unless a focused reproduction requires a named profile.
The 2026-05-06 direct evidence cited by
[`starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
used this same canonical pass spelling.

## What this lane must prove

The shared RUME engine makes raw text differences insufficient. Inspect
mismatches against these contract boundaries:

- defined function bodies remain rooted;
- unused imported functions may disappear;
- dead non-function declarations still prune;
- active segments and startup traps retain observable parents;
- a live `call_indirect` cannot lose an active wrong-type table initializer and silently become a null-entry trap; and
- index/type/start-section rewrites remain valid after pruning.

The focused local regressions are in
[`src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt); the suite still needs a direct wrong-type-versus-null `call_indirect` active-element fixture before table cleanup becomes more aggressive. The current implementation route is
[`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
through the registry and dispatcher named above. See
[`module-shapes.md`](./module-shapes.md) for concrete before/after modules.

## Signoff and failure classification

For ordinary parity signoff, follow the repository requirement of 10,000 cases
with the freshly built `_build/native/.../cmd.exe` and parallel workers. Validate
both optimizer outputs and classify a remaining mismatch from inspected evidence:
Starshine win, parity gap, size-losing, unknown/risky, validation failure,
tool/Binaryen failure, or semantic mismatch. Do not call a mismatch safe merely
because both modules validate.

An external `--wasm-smith` lane is separate and opt-in. It can exercise unusual
module shapes, but it does not replace the GenValid signoff lane. Record its
command failures separately from comparable optimizer results.

## Maintenance boundary

No new raw capture was needed for this runnable-lane refresh: the active spelling is settled by the current local registry, dispatcher, harness allowlist, and focused pass tests. The shared-engine [current-main source](https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp) is the primary-source evidence for the inherited indirect-call trap boundary; older sibling manifests remain the source evidence for the root-all-defined-functions policy.
