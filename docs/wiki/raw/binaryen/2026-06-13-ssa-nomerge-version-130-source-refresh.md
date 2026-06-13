# Binaryen `ssa-nomerge` `version_130` source refresh

_Capture date:_ 2026-06-13  
_Status:_ immutable source-refresh manifest for `[SSANM-001a]`

## Scope

This refresh compares the current local Binaryen oracle reported by `wasm-opt --version` against the existing `version_129` `ssa-nomerge` dossier before Starshine's LocalGraph mutation slices consume the upstream contract.

Local oracle command:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Downloaded comparison workspace: `.tmp/ssanm001a/{version_129,version_130}`.

## Official online sources consulted

### `version_130` implementation and registration surfaces

- `src/passes/SSAify.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SSAify.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/SSAify.cpp>
- `src/ir/local-graph.h`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-graph.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/local-graph.h>
- `src/ir/LocalGraph.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/LocalGraph.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/LocalGraph.cpp>
- `src/ir/ReFinalize.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/ReFinalize.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/ReFinalize.cpp>
- `src/passes/pass.cpp`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
- `src/passes/passes.h`
  - GitHub UI: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/passes.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/passes.h>

### `version_130` test surfaces

- Dedicated no-merge test input:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/ssa-nomerge_enable-simd.wast>
- Dedicated no-merge golden output:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/ssa-nomerge_enable-simd.txt>
- Shared full-SSA lit surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/ssa.wast>
- LocalGraph gtest surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/gtest/local-graph.cpp>

The same paths were downloaded from `version_129` and compared with `diff -q`.

## Version-drift table

| Surface | `version_129` -> `version_130` result | SSANM relevance |
| --- | --- | --- |
| `src/passes/SSAify.cpp` | Identical | No drift in the shared `SSAify(bool allowMerges)` implementation, no-merge `createNewIndexes` gate, get/default rewrites, or `createSSAifyNoMergePass()`. |
| `src/ir/local-graph.h` | Identical | No public LocalGraph contract drift for reaching sets, set influences, `computeSSAIndexes`, or `nullptr` entry/default-source behavior. |
| `src/ir/LocalGraph.cpp` | Identical | No control-flow flower drift for the LocalGraph facts that no-merge planning consumes. |
| `src/ir/ReFinalize.cpp` | Changed | Only adds `visitWideIntAddSub` and `visitWideIntMul` finalizers. This widens ReFinalize coverage for new expression kinds but does not change the `ssa-nomerge` default-ref repair contract. |
| `src/passes/pass.cpp` | Changed | Registration adds unrelated passes (`mark-js-called`, `print-boundary`, `remove-exports`), fixes text typos, and changes GC closed-world checks to `worldMode == WorldMode::Closed`. The `ssa` / `ssa-nomerge` registration and early `addIfNoDWARFIssues("ssa-nomerge")` scheduling remain unchanged. |
| `src/passes/passes.h` | Changed | Adds declarations for unrelated passes (`createMarkJSCalledPass`, `createPrintBoundaryPass`, `createRemoveExportsPass`). `createSSAifyPass()` and `createSSAifyNoMergePass()` declarations remain unchanged. |
| `test/passes/ssa-nomerge_enable-simd.wast` | Identical | Dedicated no-merge fixture did not drift. |
| `test/passes/ssa-nomerge_enable-simd.txt` | Identical | Dedicated no-merge golden output did not drift. |
| `test/lit/passes/ssa.wast` | Identical | Shared full-SSA helper fixture did not drift. |
| `test/gtest/local-graph.cpp` | Identical | LocalGraph helper proof surface did not drift. |

## Source anchors in `version_130`

- `src/passes/SSAify.cpp` still constructs `SSAify(false)` for `createSSAifyNoMergePass()` and keeps the no-merge allocation gate at `!graph.isSSA(set->index) && (allowMerges || !hasMerges(set, graph))`.
- `src/passes/SSAify.cpp` still returns early from merge-local rewriting when `!allowMerges`, so full-`ssa` merge materialization remains outside `ssa-nomerge`.
- `src/passes/pass.cpp` still registers the public spelling `ssa-nomerge` with `createSSAifyNoMergePass` and still schedules it early when `optimizeLevel >= 3 || shrinkLevel >= 1`, subject to DWARF gating.
- `src/ir/local-graph.h` and `src/ir/LocalGraph.cpp` still expose and compute the LocalGraph facts that Starshine's LocalGraph bridge mirrors: set influences, already-SSA indexes, merge/multi-source detection, and obstacle-aware movement helpers.

## Durable conclusion

For `[SSANM-001a]`, the existing `version_129` upstream `ssa-nomerge` behavior dossier still applies to local Binaryen `version_130`. The owner algorithm (`SSAify.cpp`), LocalGraph helper contract/implementation, dedicated no-merge fixture/golden, shared `ssa.wast`, and LocalGraph gtest are byte-identical between the two tags. The observed diffs are outside the no-merge behavior contract, except that `ReFinalize.cpp` can now finalize new wide-int expression nodes if later passes introduce them before refinalization.

## File fingerprints

Short SHA-256 prefixes for the downloaded `version_130` raw files:

| Surface | SHA-256 prefix |
| --- | --- |
| `src/passes/SSAify.cpp` | `709956c464f5f63f` |
| `src/ir/local-graph.h` | `f26352f58cce7377` |
| `src/ir/LocalGraph.cpp` | `e6140facac9a8212` |
| `src/ir/ReFinalize.cpp` | `0ccf043028200108` |
| `src/passes/pass.cpp` | `d2206ef1753ebd8b` |
| `src/passes/passes.h` | `08c2e81b2e96eba7` |
| `test/passes/ssa-nomerge_enable-simd.wast` | `f990dc4e31f7a3f2` |
| `test/passes/ssa-nomerge_enable-simd.txt` | `6227410e9c144bd5` |
| `test/lit/passes/ssa.wast` | `b77f0cc382ba9453` |
| `test/gtest/local-graph.cpp` | `ff38cb274d090137` |

## Caveats

- This refresh is deliberately limited to the `ssa-nomerge` owner, LocalGraph, registration/scheduling, and fixture surfaces listed above.
- It does not claim that every Binaryen `version_130` optimizer pass is equivalent to `version_129`.
- It does not make a Starshine behavior-parity claim; it only confirms that the upstream source/test contract consumed by later SSANM implementation slices did not drift in a way that changes the planned no-merge policy.
