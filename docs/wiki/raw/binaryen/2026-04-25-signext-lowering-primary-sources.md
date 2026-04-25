# Binaryen `signext-lowering` Primary Sources

- **Captured:** 2026-04-25
- **Pass:** `signext-lowering`
- **Scope:** upstream Binaryen feature-lowering pass that rewrites WebAssembly sign-extension opcodes into older shift idioms and clears the sign-extension feature bit.
- **Status:** immutable raw-source manifest plus source-reading notes. Treat this as source material; keep living conclusions in `docs/wiki/binaryen/passes/signext-lowering/`.

## Primary upstream sources

### Binaryen `version_129`

- Release tag: <https://github.com/WebAssembly/binaryen/tree/version_129>
- Pass implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignExtLowering.cpp>
- Pass registration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Pass factory declaration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signext-lowering.wast>

### Current-main spot check

- Pass implementation on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp>
- Dedicated lit test on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast>

The 2026-04-25 spot check found no teaching-relevant drift from the reviewed `version_129` contract: the pass is still a compact `PostWalker` over the five sign-extension opcodes with the same shift-pair rewrites and the same feature-disable side effect. This is only a focused source check, not a full upstream-history audit.

## Source-backed contract

`SignExtLowering.cpp` implements a function-parallel post-walk pass over unary expressions. Each WebAssembly sign-extension opcode is replaced with a pair of shifts that preserves the original child expression and width:

| Source opcode | Source type | Lowered idiom | Result type |
| --- | --- | --- | --- |
| `i32.extend8_s x` | `i32 -> i32` | `i32.shr_s (i32.shl x 24) 24` | `i32` |
| `i32.extend16_s x` | `i32 -> i32` | `i32.shr_s (i32.shl x 16) 16` | `i32` |
| `i64.extend8_s x` | `i64 -> i64` | `i64.shr_s (i64.shl x 56) 56` | `i64` |
| `i64.extend16_s x` | `i64 -> i64` | `i64.shr_s (i64.shl x 48) 48` | `i64` |
| `i64.extend32_s x` | `i64 -> i64` | `i64.shr_s (i64.shl x 32) 32` | `i64` |

The pass then disables Binaryen's `FeatureSet::SignExt` feature on the module. That means the public contract is not only instruction rewriting; it is also a feature-lowering pass that should make the emitted module no longer require the sign-extension feature.

## Dedicated test surface

`test/lit/passes/signext-lowering.wast` exercises all five opcodes and checks the shift-pair output shape. The test is intentionally small: it proves opcode lowering and feature removal, not broader sign-extension cleanup. Neighboring Binaryen passes such as `optimize-instructions` and `pick-load-signs` may optimize or infer sign-extension patterns, but those are different pass contracts.

## Starshine relevance

Starshine already has sign-extension instruction surfaces in parser, library IR, validation, binary encoding, HOT lifting, and neighboring `pick-load-signs` logic, but no public `signext-lowering` registry entry or owner file as of 2026-04-25. A future local port would therefore be a small feature-lowering transformation over existing unary instruction surfaces, plus a design decision about whether and how Starshine models target-feature metadata after rewriting.

## Uncertainties and caveats

- This capture does not establish when `signext-lowering` entered Binaryen; it only establishes the reviewed `version_129` and focused 2026-04-25 current-main behavior.
- Starshine does not currently expose Binaryen-style module feature toggles for sign-extension in the same way Binaryen does. A faithful local port must decide whether feature metadata removal is observable in this repository's custom-section model or only in emitted instruction shape.
- Do not fold this pass into `optimize-instructions` or `pick-load-signs` documentation. Those passes reason about sign-extension for optimization; `signext-lowering` exists to remove feature-opcode dependencies.
