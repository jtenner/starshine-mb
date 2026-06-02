# Binaryen `inlining` current-main recheck

_Date captured:_ 2026-06-02
_Status:_ immutable current-main drift check for the `docs/wiki/binaryen/passes/inlining/` dossier

## Scope

This note records a narrow current-main recheck after the earlier tagged `version_129` primary-source capture and the 2026-05-23 bridge.
The public Binaryen release horizon now reaches `version_130`, but this recheck still found no teaching-relevant drift on the inlining surfaces.
It focuses on the exact surfaces that support the living no-inline / clone-survival explanation:

- `src/passes/Inlining.cpp`
- `src/passes/NoInline.cpp`
- `src/passes/pass.cpp`
- `src/ir/module-utils.cpp`
- the dedicated `inline-hints*`, `no-inline*`, and `no-inline-monomorphize-inlining` lit tests

## Official source URLs checked

- `Inlining.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
- `NoInline.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>
- `pass.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `module-utils.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
- `inline-hints.wast` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/inline-hints.wast>
- `inline-hints-func.wast` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/inline-hints-func.wast>
- `no-inline.wast` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline.wast>
- `no-inline-monomorphize-inlining.wast` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline-monomorphize-inlining.wast>

## Durable observations

- `main` still stores `@metadata.code.inline` as preserved annotation metadata rather than using it as the practical plain-`inlining` suppression switch.
- `Inlining.cpp` still gates full and partial inlining on the function booleans `noFullInline` and `noPartialInline`.
- `NoInline.cpp` still owns the `no-inline`, `no-full-inline`, and `no-partial-inline` wildcard policy passes that set those booleans.
- `module-utils.cpp` still copies the no-inline flags when cloning functions, which explains the `no-inline-monomorphize-inlining.wast` clone-survival behavior.
- The dedicated inline-hints and no-inline lit files still prove the same split between annotation bytes, policy flags, and clone survival; no teaching-relevant drift was found from the existing dossier.

## Consumability rule

Use this note together with the living inlining dossier pages when restating the current upstream split.
It is a recheck, not a replacement for the tagged `version_129` manifest.
