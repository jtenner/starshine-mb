---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md
  - ../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./import-and-call-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../string-lowering/index.md
---

# Binaryen `string-lifting` strategy

## Upstream source rule

Use Binaryen `version_129` as the tagged oracle for this folder, anchored by the raw primary-source manifest.
On 2026-04-24 the official GitHub release page for `version_129` showed publish date **2026-04-01 14:31**.

Primary sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>

## High-level intent

`string-lifting` lifts JavaScript-string imports back into wasm strings.
It exists so Binaryen can optimize with the richer wasm string semantics, then usually run [`string-lowering`](../string-lowering/index.md) later if the target still needs the import/`externref` representation.

Shortest accurate summary:

1. discover imported string constants,
2. discover known `wasm:js-string` helper imports,
3. rewrite matching global gets and calls to wasm string instructions,
4. refinalize changed functions,
5. walk module code too,
6. enable the Strings feature.

## Public family split

`pass.cpp` exposes this string family as separate public pass names:

- `string-gathering`
- `string-lifting`
- `string-lowering`
- `string-lowering-magic-imports`
- `string-lowering-magic-imports-assert`

The split matters:

- [`string-gathering`](../string-gathering/index.md) canonicalizes `string.const` into globals.
- `string-lowering` lowers wasm strings to imports and `externref`-shaped operations.
- `string-lifting` raises those known imports back to wasm string instructions.

## Phase 1: choose the string-constants module

`StringLifting` accepts the same `string-constants-module` pass argument that `StringLowering` uses.
If no argument is provided, the pass uses the default string constants module from `string-utils.h`.

That means magic-import lifting is configurable, not hard-coded solely to one module string.

## Phase 2: collect imported string globals

Binaryen collects imported globals into a map from global name to literal bytes.
There are two source-backed paths.

### Magic-import path

If an imported global comes from the configured string constants module, Binaryen treats the import base as the string payload and records it.

This is the direct path most visible in `string-lifting.wast`.

### JSON custom-section path

If an imported global comes from module `string.const`, Binaryen expects the import base to be an index into the `string.consts` custom section.
The pass:

- finds the `string.consts` section,
- parses it as JSON,
- extracts string payloads,
- maps numbered imports to those payloads,
- then removes the custom section after the payloads have been consumed.

This is the source-confirmed companion to `string-lowering`'s default output path.
The dedicated lifting lit test is less direct for this path than for magic imports, so keep the evidence level explicit.

## Phase 3: collect exact helper imports

The pass scans imported functions under module `wasm:js-string`.
It only lifts helpers whose names and signatures match the expected roster.

Supported helpers:

- `fromCharCodeArray`
- `fromCodePoint`
- `concat`
- `intoCharCodeArray`
- `equals`
- `test`
- `compare`
- `length`
- `charCodeAt`
- `substring`

A recognized helper base with the wrong expected signature is a fatal Binaryen pass error.
A wrong module is ignored.
An unknown helper base under `wasm:js-string` is reported as a warning by Binaryen rather than transformed.
This distinction is easy to miss because the dedicated lit file directly shows wrong-module / wrong-name non-lifting, while the wrong-signature fatal behavior is source-confirmed from `StringLifting.cpp`.

## Phase 4: rewrite global gets

`StringApplier::visitGlobalGet(...)` handles imported string constants.

Input shape:

```wat
(global $s (import "'" "hello") externref)
(func (result externref)
  (global.get $s))
```

Lifted shape:

```wat
(func (result externref)
  (string.const "hello"))
```

The exact printed type depends on surrounding type repair and refinalization. The semantic payload is the literal bytes from the imported global, and the lifted expression is a string value even when an enclosing ABI type remains wider.

## Phase 5: rewrite helper calls

`StringApplier::visitCall(...)` maps known helper calls to wasm string operations.

Core families:

| Imported helper | Lifted operation family |
| --- | --- |
| `fromCharCodeArray` | `string.new_wtf16_array` |
| `fromCodePoint` | `string.from_code_point` |
| `concat` | `string.concat` |
| `intoCharCodeArray` | `string.encode_wtf16_array` |
| `equals` | `string.eq` equal |
| `test` | `string.test` |
| `compare` | `string.compare` |
| `length` | `string.measure_wtf16` |
| `charCodeAt` | `stringview_wtf16.get_codeunit` / string-view get |
| `substring` | `stringview_wtf16.slice` / string slice |

The exact textual printer names in Binaryen's WAT output can be proposal-era names such as `stringview_wtf16.get_codeunit` and `stringview_wtf16.slice`.
The important strategy point is that imported helpers become first-class wasm string instructions, not ordinary calls.

## Phase 6: refinalize changed functions

After rewriting a function, Binaryen refinalizes that function.
This is correctness-critical because lifted instructions and constants carry string types, while the imports and helpers that were replaced often used `externref`-shaped signatures.

Without refinalization, the AST type annotations can remain stale even if the printed WAT looks plausible.

## Phase 7: walk module code

The pass also calls the module-code walker after function-body processing.
That means module expressions such as global initializers are in scope when they contain liftable imports/calls.

Do not describe `string-lifting` as only a function-local call-replacement pass.

## Phase 8: enable Strings

At the end, Binaryen enables `FeatureSet::Strings`.
That is the final direction marker: the output module now contains wasm string instructions and must advertise the feature.

## Important open TODO: missing casts

`StringLifting.cpp` includes an explicit TODO around inserting casts on generated string inputs.
The source explains the practical issue: helpers operated on external references, while the lifted wasm string operations want string references.

The durable rule for readers and future ports is:

- do not claim that `string-lifting` already performs complete cast repair;
- do expect normal pipelines to pair it with later lowering or other string-aware work;
- keep validation behavior under scrutiny if a future Starshine port lifts calls without immediately lowering them again.

## Current-main drift check

A 2026-05-05 focused spot check against current `main` for `StringLifting.cpp`, `string-lifting.wast`, and pass registration did not reveal teaching-relevant drift from the `version_129` source contract described here, including the recognized-helper wrong-signature fatal behavior, module-code walk, `string.consts` custom-section removal, Strings feature enablement, and cast-repair TODO.
Treat that as a narrow freshness check, not a proof that every helper edge case is unchanged forever.
See [`../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md) for the source manifest and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the local implementation ladder.

## What this pass is not

It is not:

- `string-gathering`;
- `string-lowering`;
- a no-DWARF optimize-tail pass in Starshine;
- a generic JavaScript interop optimizer;
- a local peephole pass;
- a complete string type/cast repair framework.

## Sources

- [`../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md)
- [`../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md)
- [`../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md`](../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md)
- [`../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`](../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
