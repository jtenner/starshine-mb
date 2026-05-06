# Binaryen `alignment-lowering` Current-Main Recheck

- **Captured:** 2026-05-06
- **Pass:** `alignment-lowering`
- **Scope:** current-main freshness recheck and exact source map for the living `docs/wiki/binaryen/passes/alignment-lowering/` dossier.
- **Status:** immutable raw-source manifest. Keep durable conclusions in the living dossier pages.

## Primary upstream sources

### Binaryen `version_129`

- Release tag: <https://github.com/WebAssembly/binaryen/tree/version_129>
- Pass implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
- Pass registration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Pass factory declaration: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Pass base / local-fixup context: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- Bit helper dependency: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast>

### Current-main recheck

- Pass implementation on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AlignmentLowering.cpp#L1495-L1716>
- Pass registration on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L2373-L2377>
- Pass factory declaration on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h#L693-L694>
- Dedicated lit coverage on `main`:
  - integer / signed-load / offset / no-op families: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/alignment-lowering.wast#L2784-L2818>
  - 64-bit and float families: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/alignment-lowering.wast#L3236-L3256>
  - unreachable and extra load/store families: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/alignment-lowering.wast#L3406-L3418>

## Recheck result

The 2026-05-06 current-main recheck found no teaching-relevant drift from the already captured `version_129` contract.
The reviewed owner file still presents `alignment-lowering` as a narrow scalar `Load` / `Store` chunk-lowering pass with:

- natural-alignment no-op behavior;
- fresh-local single-evaluation staging for pointer and value expressions;
- `i32`-centered chunk rebuilding and splitting;
- signed narrow-load repair through `Bits::makeSignExt(...)`;
- float reinterpret staging instead of numeric conversion;
- 64-bit split/rebuild through two 32-bit halves;
- operand-preserving unreachable handling;
- no reviewed atomics, SIMD, or bulk-memory rewrite surface.

## Source-backed implementation map

The implementation surface remains small and centered in `AlignmentLowering.cpp`:

- public pass construction is exposed through `pass.cpp` and `passes.h`;
- the walker visits ordinary scalar loads and stores;
- natural alignments are left unchanged;
- weaker alignments are rebuilt from smaller naturally aligned chunks;
- pointer and store-value expressions are spilled so address/value side effects run once;
- signed narrow loads use the bit helper instead of hand-rolled sign extension;
- float loads/stores go through integer bits and reinterpretation, not numeric conversion;
- 64-bit accesses split through 32-bit halves;
- unreachable loads/stores preserve operand evaluation shape rather than inventing chunked traffic;
- the dedicated lit file remains the strongest compact proof for integer, float, 64-bit, offset, natural-alignment, and unreachable families.

## Starshine local source map checked

The local recheck focused on whether the previous Starshine strategy page had enough concrete follow-along surfaces for a future port. The useful code map is:

- registry and request honesty:
  - `src/passes/optimize.mbt:127-140` keeps `alignment-lowering` in `pass_registry_boundary_only_names()`;
  - `src/passes/optimize.mbt:446-461` rejects boundary-only pass requests from the active hot pipeline.
- WAT and lib instruction surface:
  - `src/wast/parser.mbt:255-257` defines WAT-side `MemArg`;
  - `src/wast/parser.mbt:1323-1348` parses `offset=` / `align=` memargs;
  - `src/wast/parser.mbt:1980-1995` maps scalar memory opcodes to WAT `Load` / `Store` nodes;
  - `src/wast/lower_to_lib.mbt:224-229` converts WAT memargs to `@lib.MemArg`;
  - `src/wast/lower_to_lib.mbt:1528-1555` lowers scalar WAT loads/stores to lib instructions;
  - `src/lib/types.mbt:475` defines `MemArg`;
  - `src/lib/types.mbt:543-565` defines ordinary scalar load/store instruction constructors;
  - `src/lib/types.mbt:3077-3168` exposes constructor methods for the scalar load/store families.
- Binary and validation support:
  - `src/binary/encode.mbt:1819-1840` encodes `MemArg` with optional memory index plus align/offset immediates;
  - `src/validate/typecheck.mbt` owns the current load/store typing and memory-index validation surfaces that a port would need to preserve.
- HOT-side potential landing surfaces:
  - `src/ir/hot_core.mbt:47-48` defines `HotOp::Load` / `HotOp::Store`;
  - `src/ir/hot_core.mbt:230-232` defines `HotMemArg`;
  - `src/ir/hot_side_tables.mbt:111-119` allocates and reads HOT memarg side-table entries;
  - `src/ir/hot_builders.mbt:535-557` builds HOT load/store nodes with memarg side-table IDs;
  - `src/ir/hot_lift.mbt:741-760` groups scalar lib loads/stores into HOT `Load` / `Store` families;
  - `src/ir/hot_lower.mbt:1077-1086` lowers exact HOT memory nodes back through `hot_lower_impl_exact_instr(...)`.
- Planning context:
  - `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:57-61` keeps the pass only in the broad whole-module/layout planning bucket;
  - `agent-todo.md` still has no dedicated `alignment-lowering` slice;
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` still omits the pass from the canonical no-DWARF path.

## Port-readiness finding

The previous living dossier already taught the transformed shapes and upstream strategy well. The missing reader aid was a fresh current-main source map that confirmed the contract still held and gave later readers exact anchor lines to follow.

The recheck supports this minimum viable port sequence:

1. Keep registry honesty unchanged until transform code exists.
2. Add reduced tests before implementation for natural-alignment no-ops, `align=1` / `align=2` chunking, signed narrow-load repair, float reinterpret staging, 64-bit split/rebuild, offset preservation, and unreachable operand preservation.
3. Choose the local landing zone explicitly: HOT-side rewrite if the implementation can preserve opcode families and memarg immediates through HOT, or a later boundary/post-writeback legalization pass if exact instruction-family preservation is easier outside HOT.
4. Implement scalar ordinary load/store coverage first; do not pull atomics, SIMD, bulk memory, or memory64-only expansion into the first slice without a separate source-backed scope decision.
5. Compare against Binaryen `--alignment-lowering` directly, not via the no-DWARF default path, because this pass is not currently part of that canonical Starshine parity route.

## Uncertainties and caveats

- This recheck did not establish the historical introduction release for `alignment-lowering`.
- Starshine still has no committed landing zone. The main open local question is architectural, not semantic: HOT rewrite versus post-writeback/boundary legalization.
- The reviewed upstream lit surface still does not provide a dedicated memory64-only proof section. Treat pointer-width details as a future Starshine test requirement if the eventual port touches memory64 modules.
- A faithful first port should not infer SIMD, atomics, or bulk-memory behavior from neighboring memory/lowering passes; those remain out of reviewed Binaryen owner-file scope for `alignment-lowering`.
