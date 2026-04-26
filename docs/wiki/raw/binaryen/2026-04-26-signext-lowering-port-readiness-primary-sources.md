# Binaryen `signext-lowering` Port-Readiness Primary Sources

- **Captured:** 2026-04-26
- **Pass:** `signext-lowering`
- **Scope:** focused current-main and `version_129` source recheck for a future Starshine port-readiness bridge.
- **Status:** immutable raw-source manifest plus source-reading notes. Keep living conclusions in `docs/wiki/binaryen/passes/signext-lowering/`.

## Primary upstream sources

### Binaryen `version_129`

- Release tag: <https://github.com/WebAssembly/binaryen/tree/version_129>
- Pass implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignExtLowering.cpp>
- Pass registration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Pass factory declaration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signext-lowering.wast>

### Current-main recheck

- Pass implementation on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp>
- Pass registration on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Pass factory declaration on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Dedicated lit test on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast>

The 2026-04-26 focused recheck found no teaching-relevant drift from the 2026-04-25 source dossier: the owner remains a compact function-parallel postwalk over the five sign-extension unary opcodes, the rewrites still use same-width `shl` + signed `shr_s` pairs, and the pass still disables Binaryen's sign-extension feature after rewriting.

## Port-readiness contract

A faithful Starshine port can start small because Binaryen's transform is local per matched instruction:

1. Match only `i32.extend8_s`, `i32.extend16_s`, `i64.extend8_s`, `i64.extend16_s`, and `i64.extend32_s`.
2. Replace each opcode with its exact same-width shift pair.
3. Move the original child expression under the new left shift exactly once; do not clone it.
4. Preserve lane width: i32 inputs produce i32 shifts and i64 inputs produce i64 shifts.
5. Leave `i64.extend_i32_s` / `i64.extend_i32_u`, load-sign selection, and sign-extension cleanup to other passes.
6. Decide explicitly whether Starshine's first slice is instruction-only lowering or also edits target-feature metadata.

## Suggested first Starshine slice

The safest first local slice is an explicitly registered instruction-lowering pass that rewrites the five direct opcodes and validates the result, while documenting target-feature metadata as unsupported or unchanged. That would make behavior testable without requiring a Binaryen-identical `FeatureSet::SignExt` model first.

A second slice can decide feature metadata behavior once Starshine has a durable model for target-feature custom sections. If the pass is advertised as full Binaryen parity before that decision, the divergence should be visible in the wiki and tests.

## Validation evidence to carry forward

- Binaryen's dedicated lit test proves direct instruction-shape output for all five opcodes.
- Binaryen's owner source proves feature-bit clearing; the dedicated lit fixture is not sufficient by itself as feature-section evidence.
- Starshine currently has parser, lib IR, binary encoder/decoder, validator, HOT lifting, and neighboring `pick-load-signs` support for these opcodes, so the main local implementation gap is the rewrite plus public-pass plumbing.

## Uncertainties and caveats

- This is a focused current-main recheck, not a full upstream-history audit.
- The first Starshine port should not silently claim feature-section parity unless it actually removes or rewrites local target-feature metadata.
- `src/lib/show.mbt` currently prints no-underscore sign-extension mnemonics such as `i32.extend8s`; WAT golden tests for the future pass should either fix that hygiene issue first or compare through a normalized binary/WAT path.
