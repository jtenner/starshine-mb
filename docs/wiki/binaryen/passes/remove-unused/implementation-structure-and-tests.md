---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./historical-lineage-and-modern-supersession.md
  - ./module-shapes.md
---

# `remove-unused`: implementation structure and tests

This dossier is unusual because the important file map is split across **historical** and **modern** upstream surfaces.

## Historical source map

| File | Why it matters | What it proves |
| --- | --- | --- |
| `5881b541.../src/passes/pass.cpp` | Historical pass registration | Upstream Binaryen publicly exposed `remove-unused-functions` |
| `5881b541.../src/passes/RemoveUnusedFunctions.cpp` | Historical implementation | The old pass was start/export/table-rooted direct-call reachability plus deletion of unreachable functions |
| `5881b541.../src/passes/passes.h` | Historical factory surface | The public factory was `createRemoveUnusedFunctionsPass()` |

## Supersession source map

| File | Why it matters | What it proves |
| --- | --- | --- |
| commit `98e9e604...` | Transition point | Binaryen replaced `remove-unused-functions` with `remove-unused-module-elements` |
| `98e9e604.../src/passes/pass.cpp` | New registration | Public registration changed to `remove-unused-module-elements` |
| `98e9e604.../src/passes/RemoveUnusedModuleElements.cpp` | New implementation family | The replacement pass became broader than function-only pruning |
| `98e9e604.../src/passes/passes.h` | New factory surface | The factory changed to `createRemoveUnusedModuleElementsPass()` |

## Modern source map

| File | Why it matters | What it proves |
| --- | --- | --- |
| `version_129/src/passes/pass.cpp` | Current public pass roster | There is no current `remove-unused` or `remove-unused-functions` registration |
| `version_129/src/passes/passes.h` | Current factory roster | There is no current `createRemoveUnusedFunctionsPass()` |
| `version_129/test/lit/help/wasm-opt.test` | Current CLI oracle | Help output lists the modern remove-unused family names, but not `remove-unused` |
| `version_129/test/lit/help/wasm-metadce.test` | Secondary help oracle | Same absence on another tool surface |
| `version_129/test/lit/help/wasm2js.test` | Third help oracle | Same absence again |

## Historical implementation in plain language

`RemoveUnusedFunctions.cpp` is small enough that its whole structure matters.

### Step 1: collect roots

The old pass collected function roots from:

- `module->start`
- exported functions
- function names in table segments

### Step 2: analyze reachability

It built `DirectCallGraphAnalyzer analyzer(module, root);`

So the reachability model was:

- follow direct calls only
- from the root set above

### Step 3: erase dead functions

It then removed functions not in `analyzer.reachable` and rebuilt the functions map.

That is the entire old public contract.

## Why there is no dedicated historical lit file in this dossier

The old pass lived in an older Binaryen period before today's more comprehensive `test/lit/passes/*` roster.
For this dossier, the key public evidence is therefore:

- historical registration and implementation files
- modern help-test absence
- the supersession commit

That source combination is enough to prove the lineage and replacement story.

## What the modern help tests are doing for us

The current help tests matter because they show the current public CLI surface explicitly.

They confirm the modern removal-family names are split out as:

- `--remove-unused-brs`
- `--remove-unused-module-elements`
- `--remove-unused-nonfunction-module-elements`
- `--remove-unused-names`
- `--remove-unused-types`

and do **not** include:

- `--remove-unused`
- `--remove-unused-functions`

That makes the local Starshine registry entry a documentation problem, not a missing-current-upstream-page problem.

## What this file map means for future work

If someone is deciding what to implement or rename locally:

- use the historical files to understand what the old short alias most likely meant
- use the modern files to understand what current upstream Binaryen actually exposes
- do not skip the supersession commit, because it is the proof that historical function-only removal was replaced, not merely hidden

## Practical conclusion

The implementation/test map says the local wiki should teach `remove-unused` as:

- a **historical Binaryen lineage dossier**
- centered on old `remove-unused-functions`
- explicitly superseded by modern `remove-unused-module-elements`

## Sources

- [`../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md`](../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-opt.test>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-metadce.test>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm2js.test>
