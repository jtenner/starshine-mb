---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/GlobalStructInference.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalStructInference.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/gsi.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi.wast
related:
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/global-struct-inference/binaryen-strategy.md
  - ../../binaryen/passes/global-struct-inference/implementation-structure-and-tests.md
  - ../../binaryen/passes/global-struct-inference/parity.md
  - 2026-05-06-global-struct-inference-current-main-recheck.md
  - 2026-04-25-global-struct-inference-primary-sources.md
---

# Binaryen `global-struct-inference` `version_130` / Current-Main Recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for the living `global-struct-inference` dossier.

## Scope and method

This refresh compares the released `version_130` and current-`main` owner, registration, and dedicated plain-pass fixture surfaces. It supersedes the **freshness claim** of the 2026-05-06 bridge; that older capture remains useful provenance for the earlier `version_129` correction.

Reviewed sources:

- `src/passes/GlobalStructInference.cpp` — algorithm, open/closed-world split, rewrites, and factories.
- `src/passes/pass.cpp` — public registration and default-pipeline placement.
- `test/lit/passes/gsi.wast` — dedicated plain-pass behavioral fixtures.

This is a focused source reconciliation, not a broad behavioral test run or a substitute for Starshine's recorded compare-pass evidence.

## Confirmed upstream contract

The released and current owner source retain the same teaching-important contract:

1. **GC gate, then optional closed-world facts, then optimization.** `run(Module*)` returns without GC, calls `analyzeClosedWorld(...)` only in `WorldMode::Closed`, and always calls `optimize(...)` afterward. Plain `gsi` is therefore not closed-world-only.
2. **Open-world direct immutable-global reads remain valid targets.** The function walker recognizes immutable, defined global initializers that are `struct.new*` and can optimize a direct read even with an empty `typeGlobals` map.
3. **Closed-world analysis remains a conservative type-to-global map.** Function-local or nested-global allocations poison a type; poison propagates to supertypes; trusted immutable top-level constructors propagate candidate globals upward; candidate vectors are sorted for deterministic output.
4. **Replacement size/proof stays intentionally bounded.** The pass emits a known-global rewrite for one candidate, a direct known value for one value group, or one `ref.eq`-guarded `select` when exactly two value groups exist and one group has one global. More than two value groups or two non-singleton groups bail out.
5. **Correctness repair remains part of the transform.** The owner preserves null trapping with `ref.as_non_null`, rebuilds packed-field reads, can un-nest a nonconstant field operand into a fresh immutable global, reorders globals after such additions, and refinalizes changed functions when replacement types become more precise.
6. **The sibling remains distinct.** The constructor flag and separate factories retain plain `gsi` versus `gsi-desc-cast`; the latter alone visits `ref.cast` for descriptor-cast replacement.

The reviewed `gsi.wast` fixture and registration surfaces remain consistent with that owner contract. No behavior-bearing `version_130` to current-`main` drift was found in this narrow surface.

## What this does not prove

- It does not make a raw-output difference automatic semantic parity.
- It does not prove Starshine implements every upstream GSI feature; local claims require the local owner, tests, dispatcher/registry, and compare evidence.
- It does not cover the sibling `gsi-desc-cast` behavior beyond confirming that Binaryen still exposes it separately.

## Source links

- Released owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/GlobalStructInference.cpp>
- Current owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalStructInference.cpp>
- Released registration: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
- Current registration: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Released fixture: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/gsi.wast>
- Current fixture: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi.wast>
- Earlier current-main bridge: [`2026-05-06-global-struct-inference-current-main-recheck.md`](2026-05-06-global-struct-inference-current-main-recheck.md)
- Released baseline manifest: [`2026-04-25-global-struct-inference-primary-sources.md`](2026-04-25-global-struct-inference-primary-sources.md)
