# Binaryen `experimental-type-generalizing` v130/current-main source recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source correction and freshness capture for `docs/wiki/binaryen/passes/type-generalizing/`

## Scope

This capture rechecks Binaryen `version_130` and current `main` after a wiki health audit found a repeated unsupported claim: that `experimental-type-generalizing` uses `ContentOracle` or other interprocedural content facts.

It supersedes the `ContentOracle` portions of these older captures, which remain useful for their historical audit trail and for the correctly described CFG/local-rewrite parts:

- `2026-04-27-type-generalizing-primary-source-correction.md`
- `2026-05-05-type-generalizing-current-main-recheck.md`
- `2026-05-06-type-generalizing-current-main-recheck.md`

## Official primary sources reviewed

- Binaryen `version_130` owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/TypeGeneralizing.cpp>
- Binaryen `version_130` raw owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/TypeGeneralizing.cpp>
- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp>
- Binaryen current-main raw owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeGeneralizing.cpp>
- Binaryen current-main registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current-main dedicated fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-generalizing.wast>

## Verified contract

### What remains true

`TypeGeneralizing.cpp` is still a hidden, function-parallel experimental pass that:

1. runs nested `dce` before building a function CFG;
2. runs a backward `MonotoneCFGAnalyzer` over shared local and value-stack type-requirement lattices;
3. keeps parameters and non-reference locals fixed, while reference locals begin at their heap-top type;
4. transfers requirements through locals, direct calls, `call_indirect`, `call_ref`, globals, tables, references, struct operations, and array operations;
5. rewrites non-parameter local declaration types, repairs `local.get` / `local.tee` result types, and conditionally runs `ReFinalize`;
6. retains explicit `TODO`/unreachable handling for several control, EH, tuple, string, continuation, and atomic-GC families.

The official test registration remains `experimental-type-generalizing` under `registerTestPass(...)`, with the description `generalize types (not yet sound)`. It is not a normal public optimization pass. The dedicated lit file invokes that hidden spelling.

### Correction: no `ContentOracle`

Neither the reviewed `version_130` nor current-main owner file includes, constructs, or refers to `ContentOracle`. The pass does **not** perform an interprocedural content analysis.

Its constraints are derived directly from typed IR and module declarations:

- a direct call reads the callee parameter signature;
- global and table operations use declared global/table types while explicitly noting that those declarations are not generalized yet;
- `call_ref` walks declared signature supertypes and preserves result/parameter requirements;
- struct and array operations walk declared heap-type supertypes and field/element types.

So the durable mental model is **intra-function backward type-requirement analysis over typed IR**, not `ContentOracle`-assisted optimization. `call_ref`, struct, and array are still real transfer surfaces; only the oracle claim was wrong.

## Current Starshine admission recheck

- `src/passes/optimize.mbt` keeps `type-generalizing` in `pass_registry_boundary_only_names()`.
- No local owner file implements it.
- `scripts/lib/pass-fuzz-compare-task.ts` has no `type-generalizing` entry in its `SUPPORTED_PASS_FLAGS` allowlist.

Therefore a normal `bun fuzz compare-pass --pass type-generalizing ...` lane is not runnable today. It would test neither the hidden upstream spelling nor a Starshine implementation. Keep fuzzing documentation planned-only until registry, implementation, harness, and hidden-oracle invocation choices are all explicitly admitted.

## Caveats

- This is a source-contract recheck, not a claim that an experimental pass is sound.
- The `version_130`/current-main review found no behavior-bearing divergence in the inspected owner, registration, or fixture surfaces.
- The older captures remain historical evidence; their `ContentOracle` statements are specifically superseded, not silently erased.
