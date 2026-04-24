# `type-generalizing` source correction and Starshine follow-up

- Date: 2026-04-24
- Pass: local `type-generalizing` / upstream hidden test pass `experimental-type-generalizing`
- Status: corrective research note; supersedes the algorithmic interpretation in `0191-2026-04-21-type-generalizing-binaryen-research.md`

## Question

Does the existing `type-generalizing` dossier still match the official Binaryen `version_129` source, and what exact Starshine status should future readers follow?

## Short answer

No. The previous living dossier and 0191 research note misidentified the upstream pass as a closed-world `ContentOracle` consumer over `struct.get`, `struct.set`, `call_ref`, and `ref.cast`, and also described a second `experimental-type-generalizing-with-optimizing-casts` sibling.

The reviewed `version_129` source instead shows a tiny hidden/test pass named `experimental-type-generalizing` whose implementation is `src/passes/TypeGeneralizing.cpp`. It is a function-local type-flow cleanup pass: it observes local-set/tee value types, computes subtype/LUB relationships, and retags defaultable expressions to a compatible local-flow type; `local.get` needs a special drop-plus-zero replacement when it would otherwise need an incompatible direct type mutation.

## Sources consulted

- Raw manifest: `docs/wiki/raw/binaryen/2026-04-24-type-generalizing-primary-sources.md`
- Official Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Official Binaryen `TypeGeneralizing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeGeneralizing.cpp>
- Official Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Official Binaryen `type-generalizing.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-generalizing.wast>
- Starshine local registry: `src/passes/optimize.mbt`
- Starshine registry tests: `src/passes/registry_test.mbt`
- Starshine type and instruction surfaces: `src/lib/types.mbt`, `src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`, `src/wast/lower_to_lib.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`

## Correction details

### What was wrong

The old pages claimed:

- two upstream public names: `experimental-type-generalizing` and `experimental-type-generalizing-with-optimizing-casts`
- a `ContentOracle` dependency
- visitors for `struct.get`, `struct.set`, `call_ref`, and `ref.cast`
- impossible `call_ref` targets rewriting to `unreachable`
- post-change `ReFinalize`
- a dedicated optimizing-casts lit file

The reviewed sources do not support those claims for `version_129`.

### What the source actually shows

The corrected source-backed contract is:

- `pass.cpp` registers one hidden/test pass name, `experimental-type-generalizing`.
- `TypeGeneralizing.cpp` owns one function pass and one exported constructor, `createTypeGeneralizingPass()`.
- The pass uses Binaryen `Type` subtype and least-upper-bound operations, not a module-wide possible-contents oracle.
- The pass accumulates local value-type evidence from `local.set` and `local.tee` shapes.
- It only rewrites defaultable expressions whose type can be retagged to the computed compatible type.
- If that expression is a `local.get`, Binaryen cannot simply mutate the get's result type, so it replaces the expression with a sequence that drops the original local get and emits a default/zero value of the chosen type.
- It treats concrete typed expressions and unreachable/nondefaultable cases as barriers or no-ops.
- The dedicated `type-generalizing.wast` file is the proof surface; no `type-generalizing-with-optimizing-casts.wast` surface was found.

## Starshine status

Current Starshine status is narrower than the old dossier implied:

- `src/passes/optimize.mbt` includes `type-generalizing` in `pass_registry_boundary_only_names()`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only names before execution with the standard boundary-only error.
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `type-generalizing`.
- `src/passes/registry_test.mbt` proves the active preset list stays limited to implemented hot/module pass names and separately exercises removed-name rejection; it does not prove a hidden partial `type-generalizing` implementation.
- No `src/passes/type_generalizing.mbt` or equivalent owner file exists today.
- `agent-todo.md` has no dedicated `type-generalizing` backlog slice.

## Future-port notes

A faithful Starshine port should now be planned as a local-flow/type-retagging pass, not as a closed-world GC oracle pass.

Likely reusable local surfaces include:

- `src/lib/types.mbt` for `ValType`, `RefType`, `HeapType`, `SubType`, `CompType`, and instruction constructors.
- `src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`, and `src/ir/hot_lower.mbt` for a HOT landing zone if the rewrite stays function-local.
- `src/wast/lower_to_lib.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, and `src/binary/decode.mbt` for parsing, validation, and binary roundtrip support of the instruction/type shapes the pass would retag.
- Existing local/type-sensitive pass code such as `src/passes/simplify_locals.mbt`, `src/passes/heap2local.mbt`, and `src/passes/duplicate_function_elimination.mbt` for examples of type-index and heap-type rewrites, but not as hidden implementations of this pass.

## Durable conclusion

Treat `docs/wiki/raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md` as a historical stale interpretation for the pass mechanics. The living dossier now supersedes it with the corrected official-source story: upstream `experimental-type-generalizing` is a hidden/test, function-local type-flow cleanup pass, while Starshine currently has only a boundary-only alias and no active implementation.
