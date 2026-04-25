# Binaryen `const-hoisting` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable focused source recheck for the `docs/wiki/binaryen/passes/const-hoisting/` dossier

## Scope

This file captures the official upstream sources consulted during the 2026-04-25 `const-hoisting` wiki-health run. It supplements, rather than replaces, the earlier tagged-release manifest:

- `docs/wiki/raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`

Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/const-hoisting/index.md`
- `docs/wiki/binaryen/passes/const-hoisting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/const-hoisting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/const-hoisting/size-model-and-boundaries.md`
- `docs/wiki/binaryen/passes/const-hoisting/literal-bit-identity-zero-signs-and-nan-payloads.md`
- `docs/wiki/binaryen/passes/const-hoisting/wat-shapes.md`
- `docs/wiki/binaryen/passes/const-hoisting/starshine-strategy.md`

## Official current-`main` sources consulted

- `ConstHoisting.cpp`
  - Blob: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstHoisting.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstHoisting.cpp>
- `const-hoisting.wast`
  - Blob: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/const-hoisting.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/const-hoisting.wast>
- `pass.cpp`
  - Blob: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `literal.h`
  - Blob: <https://github.com/WebAssembly/binaryen/blob/main/src/literal.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/literal.h>
- `wasm-binary.h`
  - Blob: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-binary.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-binary.h>
- GitHub repository search result for Binaryen, used only as the public repository entry point:
  - <https://github.com/WebAssembly/binaryen>

## Durable observations

- The current-`main` `ConstHoisting.cpp` still teaches the same contract captured from `version_129`: a function-parallel postwalk groups `Const` nodes in first-seen order, uses signed-LEB byte-size measurement for integer literals, uses fixed byte widths for `f32` / `f64`, rejects `v128`, and rewrites profitable groups into one fresh local plus entry-prelude `local.set` and many `local.get`s.
- The current-`main` profitability formula remains `before = num * size`, `after = size + 2 + 2 * num`, with a strict `after < before` gate.
- The current-`main` source still contains the same zero-special-case TODO and raw-size-versus-gzip-size warning; neither should be taught as implemented behavior.
- The current-`main` dedicated lit file is still the relevant behavioral oracle for threshold, ordering, and prelude-block shape coverage.
- `literal.h` and `wasm-binary.h` remain the primary helper files for the two subtle parts of the pass: exact typed bit identity for literal grouping, and real serialized-size accounting for signed LEB integers.

## Drift result

No teaching-relevant drift was found between the existing `version_129` dossier contract and the current-`main` surfaces checked on 2026-04-25.

The useful wiki change from this recheck is therefore not a Binaryen strategy correction. It is a freshness bridge plus a sharper Starshine code map for local prerequisites: Starshine still lacks a real `const-hoisting` pass, but it already has reusable scalar-constant HOT payloads, local-get/local-set builders, fresh-local append support, and signed-LEB encoding helpers that a faithful future port should reuse.

## Caveats and uncertainty

- This is a focused source recheck, not a full upstream history audit. It does not identify the exact commit where any current-`main` mechanical formatting changes may have occurred.
- The recheck confirms the current teaching contract, but it does not prove Binaryen's future `main` will stay stable. Future wiki runs should add a new raw manifest rather than silently editing this one.
- The upstream lit file still does not directly isolate `+0.0` versus `-0.0` or distinct NaN payloads; that behavior remains source-confirmed through `Literal` equality and hashing rather than standalone WAT proof.
