---
kind: entity
status: supported
last_reviewed: 2026-07-10
sources:
  - ../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/lib/module.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ../../../binary/function-import-export-and-code-sections.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../remove-exports/index.md
  - ../minify-imports/index.md
  - ../tracker.md
  - ../../release-horizon-and-oracles.md
---

# Binaryen `remove-imports`

## Overview

`remove-imports` is a public Binaryen module-rewrite pass that removes a narrow class of **function imports**. It is not a normal dead-code-elimination pass and not a general import-section cleaner. Its reviewed source comment says it exists to make a module more inspectable by Binaryen's reference interpreter, which does not validate JavaScript-environment imports. The owner walker replaces direct calls to imported functions with `nop` when they return no value, or with a default `Literal(type)` when they do; it then removes imports absent from `ElementUtils::iterAllElementFunctionNames`. The source-backed contract is captured in [`../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md`](../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md).

For a beginner: an imported function normally represents a host capability. Replacing `(call $host ...)` removes the call's observable host effects. If the call produces a value, Binaryen supplies a default value only to keep the surrounding expression type-valid; it does not preserve the host result. Therefore this is only sensible when some earlier toolchain stage has established that the call and its result are disposable. It is **not** safe to treat it as a default optimization merely because the resulting module validates.

## Upstream And Starshine Status

| Surface | Current evidence |
| --- | --- |
| Binaryen identity | `RemoveImports.cpp` and `pass.cpp` register the public `remove-imports` name in reviewed `version_130` and current `main` sources. |
| Upstream transform | `RemoveImports.cpp` itself walks direct calls and module imports: it replaces an imported `none`-result call with `nop`, a resultful call with a default `Literal(type)`, then removes imported functions absent from `ElementUtils::iterAllElementFunctionNames`. Non-function imports are outside the reviewed walker scope. |
| Upstream tests | This source read did not identify a dedicated pass-named lit fixture. The current documented evidence is owner/element-helper/registration code, not an inferred fixture contract. |
| Starshine registry | No local `remove-imports` spelling exists in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); Starshine therefore must not claim direct-pass or compare-pass support. |
| Starshine substrate | [`ImportSec(Array[Import])`](../../../../../src/lib/types.mbt), imported-prefix index accounting in [`src/lib/module.mbt`](../../../../../src/lib/module.mbt), validation, and WAST lowering already model imports. Those are prerequisites, not a local port. |

The correct local classification is **upstream-only / local-unknown**. Do not relabel it `boundary-only` or `removed` unless Starshine intentionally adds a rejected registry spelling.

## Transformation Shape

A simplified function-import shape is:

```wat
(module
  (import "env" "trace" (func $trace (param i32)))
  (func $run
    i32.const 7
    call $trace)
)
```

Because `$trace` has no result, the reviewed Binaryen walker changes its direct calls to `nop` and may then remove `$trace` from the imported-function prefix if no element segment refers to it. For a resultful import it instead emits Binaryen's default literal for the call type. The exact post-pass binary shape depends on Binaryen's named module representation and later cleanup, but the semantic warning is fixed: **the host call is gone**.

The following distinctions prevent common mistakes:

| Similar-looking operation | Why it is different |
| --- | --- |
| `duplicate-import-elimination` | Repoints duplicate function-import uses to one representative; it does not discard calls. See [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md). |
| `remove-unused-module-elements` | Uses module reachability and repairs affected index spaces; it is not defined by replacing import calls with `nop` or default literals. See [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md). |
| `remove-exports` | Filters host-visible export entries; it leaves the target definitions and calls in place. See [`../remove-exports/index.md`](../remove-exports/index.md). |
| `minify-imports` | Renames ABI-visible import bases; it does not remove imported calls. See [`../minify-imports/index.md`](../minify-imports/index.md). |

## Correctness Constraints

A future local implementation must keep these constraints explicit:

1. **Do not widen the scope silently.** The reviewed Binaryen walker is about imported functions. Tables, memories, globals, and tags have different index spaces and host semantics.
2. **Preserve stack validity without mistaking it for equivalence.** Binaryen uses `nop` for a no-result call and a default `Literal(type)` for a resultful call. A future port must validate that replacement in context, while separately proving that discarding the real host result is permitted by its explicit policy.
3. **Respect element/table references.** The source retains imports whose names occur in `ElementUtils::iterAllElementFunctionNames`. Function-table content is an observable indirect-call surface, not dead metadata; do not generalize this source condition into a proof about every other reference carrier.
4. **Audit imported-prefix index repair.** Removing an imported function shifts absolute `FuncIdx` values for later imports and definitions. Starshine's shared-index model and rewrite checklist are documented in [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md).
5. **Keep host policy separate from validity.** A module can validate after a host call disappears while still being behaviorally wrong for its embedding. Any Starshine implementation needs an explicit caller/toolchain policy and must stay out of ordinary `optimize` / `shrink` presets until that policy is proven.

## Future Starshine Work

The safe first step is **not** mutation: add a registry-honesty decision and an analyzer that reports imported functions, direct call sites, result use, table references, exports, starts, and element references. A mutating slice would then need red-first tests for:

- a discarded unused `none`-returning import;
- a no-result direct call that becomes `nop` only under an explicit policy fixture;
- a result-producing direct call whose default replacement is type-valid but is still rejected unless the host-result policy permits it;
- effect-sensitive calls that remain unsupported until their semantics are defined;
- table-referenced imports that must remain declared;
- imported-prefix `FuncIdx` repairs across calls, `ref.func`, exports, starts, elements, names, and annotations; and
- binary/WAST roundtrip plus validation after rewrite.

Do not create a compare-pass smoke lane yet: the local dispatcher and harness do not admit this pass. Once a real local pass exists, use the pass-eligibility preflight in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md) before treating any green process as parity evidence.

## Sources

- Upstream owner/element-helper/registration source read: [`../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md`](../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md)
- Starshine import/index model: [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md), [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt), [`../../../../../src/lib/module.mbt`](../../../../../src/lib/module.mbt)
- Starshine validation and WAST lowering prerequisites: [`../../../../../src/validate/validate.mbt`](../../../../../src/validate/validate.mbt), [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- Related pass boundaries: [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md), [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md), [`../remove-exports/index.md`](../remove-exports/index.md), [`../minify-imports/index.md`](../minify-imports/index.md)
