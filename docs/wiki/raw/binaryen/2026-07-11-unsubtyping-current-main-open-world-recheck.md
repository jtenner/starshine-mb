# Binaryen `unsubtyping` version_130 / current-main open-world recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for `docs/wiki/binaryen/passes/unsubtyping/`

## Scope

This capture supersedes the **current-main freshness claim** in [`2026-05-05-unsubtyping-current-main-recheck.md`](2026-05-05-unsubtyping-current-main-recheck.md). It does not replace the tagged `version_129` source dossier or the older 2026-05-05 capture; those remain useful historical provenance.

The reviewed change is material: Binaryen `version_130` rejected open-world invocation, while current `main` accepts it and uses the requested `WorldMode` to select the public heap-type boundary that must remain unchanged.

## Primary sources reread

### Binaryen `version_130`

- Owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Unsubtyping.cpp>
- Registration/default scheduler: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>

### Binaryen current `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Unsubtyping.cpp>
- Registration/default scheduler: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- New focused oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-open-world.wast>
- Public-type helper declaration: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- Global type-rewrite helper declaration: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Local Starshine status evidence

- `src/passes/optimize.mbt`: `unsubtyping` remains a boundary-only name.
- `scripts/lib/pass-fuzz-compare-task.ts`: `SUPPORTED_PASS_FLAGS` still has no `--unsubtyping` entry.

## Version boundary and current contract

In `version_130`, `Unsubtyping::run` returned for non-GC modules and then failed when `worldMode == WorldMode::Open`.

Current `main` still has the GC early return, but it no longer has the open-world fatal gate. Instead, `analyzePublicTypes(...)` calls:

```text
ModuleUtils::getPublicHeapTypes(wasm, getPassOptions().worldMode)
```

and preserves each selected public type's declared supertype and descriptor relation before the ordinary validation/cast/descriptor fixed point runs.

So the current invariant is **not** “open world means every type is mutable.” It is:

> Minimize only relations outside the public heap-type surface selected by the requested world mode, while preserving the existing validation, cast, descriptor, JS-boundary, and trap constraints.

The fixed-point algorithm, descriptor-allocation repair, private type rewrite, and final `ReFinalize()` reviewed in the earlier dossier remain present. The material drift is the admission and public-visibility policy around them.

## What the new focused fixture proves

`unsubtyping-open-world.wast` runs explicit `--unsubtyping` without `--closed-world` and records these policy cases:

1. With no public types, private struct relations can still be optimized.
2. A public function type freezes function relations, while unrelated private struct relations can still optimize.
3. A public `any` relation freezes struct/array families, while unrelated private function relations can still optimize.
4. A public `i31` relation does not by itself freeze unrelated struct relations.
5. A public `eq` relation freezes struct relations.
6. A publicly exposed defined type and its descendants stay unchanged, while unrelated private types can still optimize.

These are visibility-policy tests, not a replacement for the older cast, descriptor, JS-interop, or stack-switching test suites.

## Scheduler versus direct-pass distinction

The default GC/type pipeline may still schedule `unsubtyping` only in its closed-world cluster. That scheduler fact does **not** imply that an explicit current-main `--unsubtyping` request is rejected in open world.

Keep these claims separate:

- **default scheduling:** a pipeline policy;
- **explicit pass admission:** current main accepts open-world `unsubtyping`;
- **rewrite safety:** determined by the mode-aware public-type boundary plus the pass's existing relation constraints.

## Starshine reconciliation

Starshine has not adopted either upstream mode:

- it has no `unsubtyping` implementation owner;
- it retains the name as `BoundaryOnly`;
- its active dispatcher rejects the request; and
- the compare-pass harness rejects `--unsubtyping` before generation because the flag is not admitted.

A future port must therefore model an explicit world/visibility policy before it can claim current Binaryen parity. It must not preserve the obsolete upstream rule that every open-world request fails, and it must not infer that open-world support allows mutation of public type families.

## Supersession rule

Use this capture for post-`version_130` open-world admission and visibility-policy claims. Use the older manifests for the tagged `version_129` algorithm/source map and the pre-change May 2026 current-main observation.