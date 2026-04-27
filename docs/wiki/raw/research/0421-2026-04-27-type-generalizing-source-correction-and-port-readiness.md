# `type-generalizing` source correction and port readiness

- Date: 2026-04-27
- Pass: local `type-generalizing` / upstream hidden test pass `experimental-type-generalizing`
- Status: corrective research note and Starshine future-port bridge
- Supersedes for mechanics: `0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md` and `0191-2026-04-21-type-generalizing-binaryen-research.md`

## Question

Does the 2026-04-24 corrected dossier still match official Binaryen `version_129` and current `main`, and what should Starshine readers use as the implementation-readiness model?

## Short answer

No. The 2026-04-24 dossier overcorrected the older 0191 note. It removed the real `ContentOracle` / GC / `call_ref` strategy and replaced it with an unsupported tiny local-set/local-tee retagging story. The official source shows `experimental-type-generalizing` is a hidden, explicitly "not yet sound" test pass built from a function CFG, a backward monotone analysis, local/value-stack type requirements, `ContentOracle`, nested `dce`, local-declaration rewriting, local-get/tee retagging, and post-change refinalization.

Starshine still has no implementation: it only preserves the local `type-generalizing` spelling as a boundary-only registry name.

## Sources consulted

- Corrective raw manifest: `docs/wiki/raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md`
- Official Binaryen `version_129` `TypeGeneralizing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeGeneralizing.cpp>
- Official Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Official Binaryen `version_129` `type-generalizing.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-generalizing.wast>
- Official Binaryen current `main` `TypeGeneralizing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp>
- Starshine registry and dispatcher: `src/passes/optimize.mbt`
- Starshine registry tests: `src/passes/registry_test.mbt`
- Starshine reusable type/WAT/HOT/validation/binary surfaces: `src/lib/types.mbt`, `src/wast/lower_to_lib.mbt`, `src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`

## What changed from the 2026-04-24 model

| 2026-04-24 claim | 2026-04-27 source correction |
| --- | --- |
| No `ContentOracle` surface | Owner file instantiates and uses `ContentOracle` for call/global/table/ref/GC reasoning |
| No `call_ref` visitor/surface | `call_ref` has explicit requirement propagation through signature supertypes |
| No `struct.get` / `struct.set` surface | Struct and array operations are important transfer-function families |
| Local-set/local-tee evidence map is the core | The core is a backward CFG analysis over local requirements plus value-stack requirements |
| `local.get` becomes drop-plus-zero | Source retags `local.get` / `local.tee` after local declaration generalization |
| No nested cleanup | The pass runs nested `dce` before analysis |
| No refinalization | The pass runs `ReFinalize` if local get/tee expression types changed |
| Compact but sound local-flow pass | Upstream registration explicitly says "not yet sound" and source has many TODO/unreachable unsupported families |

## Correct Binaryen strategy

The pass is easiest to understand in four phases:

1. **Prepare each function.** Run nested `dce`, build a function CFG, and skip functions whose CFG cannot be built.
2. **Analyze requirements backward.** Use a monotone solver over basic blocks. Each state records required types for locals and the value stack. Transfers impose original types where necessary and otherwise choose more general reference types when users permit them.
3. **Use oracle and instruction semantics.** Direct calls, `call_ref`, globals, tables, `select`, `drop`, ref operations, and GC struct/array operations all feed type requirements. Unsupported shapes are explicit hazards, not implied positives.
4. **Rewrite locals and refinalize.** Non-param locals can be declared with generalized types. `local.get` and `local.tee` expression types are updated to match. If those expression types changed, `ReFinalize` repairs the function.

## Starshine port-readiness conclusion

Do **not** port this as a small HOT peephole. A faithful Starshine port should remain blocked until the project wants a developer/experimental pass and can support:

- a function CFG suitable for backward dataflow over expression stack/local requirements;
- top/bottom/reference subtype operations rich enough for GC heap types;
- a Starshine analogue of Binaryen's `ContentOracle` or an explicitly narrower first slice;
- nested pre-cleanup sequencing or equivalent unreachable-code handling;
- local declaration rewriting and repair of every numeric local index use;
- post-rewrite validation and type repair for local gets/tees;
- explicit unsupported-family negatives matching Binaryen's current TODO surfaces.

A safe first local slice, if this ever becomes active, should probably be **analysis-only**: compute proposed generalized local declarations for a tiny reference-local subset, compare them to Binaryen on the dedicated lit shapes, but do not write changes until the validator and local-use repair ladder is in place.

## Validation ladder for a future port

1. Registry honesty: `type-generalizing` remains boundary-only until an owner file and explicit tests land.
2. Analyzer-only tests: prove CFG requirement propagation for params, locals, direct call, call_ref, globals, tables, and GC struct/array primitives without rewriting.
3. Narrow mutating slice: rewrite only non-param local declarations plus local get/tee result metadata for validated reference locals.
4. Negative tests: unsupported EH, tuple, string, continuation, atomic, and `pop` families must be rejected or skipped explicitly.
5. Binaryen oracle lanes: compare against `wasm-opt --experimental-type-generalizing` when the local tooling can invoke hidden test passes; otherwise preserve hand-transcribed WAT fixtures from `type-generalizing.wast`.
6. Standard repo signoff: `moon info`, `moon fmt`, `moon test`, then pass-targeted fuzz only after the pass is invocable.

## Durable conclusion

The living `type-generalizing` pages should now teach a hidden, not-yet-sound Binaryen CFG/type-requirement pass, not either of the previous extremes: the stale 0191 whole-program cast story without nuance or the 2026-04-24 tiny retagging-only story. Starshine remains boundary-only and unimplemented.
