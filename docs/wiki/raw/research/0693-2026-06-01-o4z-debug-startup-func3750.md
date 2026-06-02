# 0693 - O4z debug startup func3750 bucket-array trap investigation

Date: 2026-06-01

## Context

Continuation of the full self/debug `-O4z` recovery after commit `4ab7e1bc2` repaired the previous `func21` TLSF allocator initialization hang. The next blocker is a Node/WASI startup trap in the self-optimized debug command artifact:

- input: `tests/node/dist/starshine-debug-wasi.wasm`
- latest candidate inspected: `.tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm`
- startup path: `func4676 -> func473 -> func3748 -> func3750 -> func28`
- trap: `RuntimeError: unreachable` in range-check helper `func28`

The candidate externally validates with `wasm-tools validate --features all`, so the remaining failure is runtime semantics rather than wasm validation.

## Reproduction shape

The relevant run shape remains:

```sh
export MOONBIT_BIN_DIR=$PWD/.tmp/moonbit.backup-20260601T014334Z/bin
export PATH=$PWD/.tmp/moonbit.backup-20260601T014334Z/bin:$PATH
moon build --target native --release src/cmd
_build/native/release/build/cmd/cmd.exe -O4z \
  --out .tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
wasm-tools validate --features all .tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm
node - <<'NODE'
import { runWasmStart } from './scripts/lib/moonbit-wasi-runner.mjs';
const code = await runWasmStart({
  wasmPath: '.tmp/o4z-bench/dist-o4z-after-typeidx-skip.wasm',
  args: ['--help'],
  cwd: process.cwd(),
  preopens: { '.': process.cwd() },
});
console.log('exit', code);
NODE
```

## Instrumentation findings

Temporary WAT instrumentation was applied only under `.tmp/o4z-bench/` and was not committed. The instrumentation removed the module start wrapper when needed and exported `func4676` as `__init` so memory could be inspected after the trap.

### `func28` arguments

Instrumenting `func28` to store its arguments before trapping showed the failing range check is:

```text
idx   = 110
lower = 0
upper = -1
```

This means `func3750` is not failing because the hash index is directly outside the intended `0..511` mask. It is calling the helper with an upper bound derived from an array whose runtime length has become zero (`0 - 1 == -1`).

### Map and bucket-array state

Further instrumentation around the first range-check call in `func3750` and the map constructor `func3752` showed:

```text
map pointer                   = 181248
map capacity field offset=8   = 512
map mask field offset=12      = 511
map count field offset=16     = 2
bucket array pointer          = 179184
bucket array header in 3750   = 0
bucket array created in 3752  = 512
```

Interpretation: `func3752` correctly allocates the bucket array with length `512`, stores it in the map at offset `20`, and initializes the map capacity/mask as expected. By the failing call in `func3750`, the same bucket array pointer is still in the map, but its header has been overwritten/freed/zeroed, so `call 26` reports length `0`.

### Early insertion timing

Instrumentation of `func473` and `func3748` showed the failure occurs during very early startup global-map population. At the observed trap, the map count is `2`, so the failing insertion is around the third insert into the map initialized by `func473`.

The caller-side map retain pattern in `func473` is present before insertion calls. The `func3748` wrapper retains the key/value argument shape, but the broader evidence points to the bucket array lifetime/header becoming invalid after early insertion rather than to a bad initial capacity or bad hash mask.

## Temporary patch experiments

- Reintroducing/storing the second typed loop-carried value in `func3750` was not sufficient. One direct variant failed validation due stack arity at loop fallthrough; an adjusted variant validated but still trapped in `func28`.
- Removing `local.get 0; call 45` map releases inside `func3750` avoided the immediate `func28` trap but later failed with an allocator/memory out-of-bounds trap. This is not a fix, but it supports treating the issue as lifetime/refcount or ownership-adjacent rather than a pure hash-index arithmetic bug.

## Current hypothesis

The blocker is corruption of the startup map's bucket-array object header after early insertions in `func3750`. The June 1 evidence showed the corruption follows a map release/destruction path rather than bad initial capacity or hash masking.

June 2 follow-up narrowed the owner further: the trap is **latent before the current `-O4z` pass sequence**. A raw-input binary patch that only stubs the externally invalid huge-local `func535` validates and still traps on the same startup path (`func4686 -> func473 -> func3749 -> func3751 -> func28` in that unoptimized/stubbed numbering). Coalesce-locals is therefore the first pass that makes the committed input externally runnable, but it is not the pass that introduces the startup map trap.

The June 2 allocator-owner evidence below resolves these owner families more narrowly: the committed debug-WASI input contains a stale/bad `$moonbit.malloc`-equivalent body that passes `0` to TLSF `removeBlock`. Current freshly generated debug/release artifacts carry the TLSF root correctly, so the remaining owner is the committed artifact generation/regeneration path, not the current `-O4z` pass sequence or the current map/refcount source semantics.

## June 2 continuation evidence

Current direct `-O4z` was rebuilt with the backup MoonBit toolchain and matched an explicit 39-pass shrink-list run byte-for-byte (`.tmp/o4z-bench/current-direct-o4z.wasm` and `.tmp/o4z-bench/current-prefix-dumps/final.wasm`, both `3,172,802` bytes). The output validates and traps under Node/WASI on the same map startup path.

Prefix dumps from the explicit pass list showed:

- prefixes `00` through `24` remain externally invalid only because `func535` exceeds the local-count limit;
- prefix `25` (`coalesce-locals`) is the first validating prefix;
- prefix `25` and every later prefix trap in the startup map path;
- `coalesce-locals` alone is enough to make the input validate and reproduce the startup trap.

Function print snapshots before and after coalesce-only showed `func473`, `func3748`, `func3749`, `func3750`, `func3751`, `func3752`, and `func3753` are unchanged by coalesce-only. Full-pipeline snapshots showed the relevant map bodies only change textually under tuple/reorder-local reshaping, and ablation runs still trap when `tuple-optimization`, `reorder-locals`, both together, `simplify-locals-nostructure`, or `ssa-nomerge` are omitted.

A scratch binary patch replaced only absolute `func535` (code index `518`, after `17` imported functions) with a tiny `unreachable` body. The resulting `.tmp/o4z-bench/raw-stub-f535.wasm` validates without applying any optimizer pass and still traps:

```text
RuntimeError: unreachable
    at wasm-function[28]
    at wasm-function[3751]
    at wasm-function[3749]
    at wasm-function[473]
    at wasm-function[4686]
```

That proves the startup trap is not introduced by the current self/debug `-O4z` recovery passes. It is present as soon as the committed input's unrelated huge-local validation blocker is removed.

Additional scratch instrumentation on the reduced fixture refined the June 1 release hypothesis. In the extracted numbering (`func20 -> func25 -> func27 -> func11`, with retain/release as `func15`/`func17`):

```text
tracked map pointer = 181248
retain1 before/after = 1 -> 2
func27 first empty-branch start map header = 0
first empty-branch new entry pointer = 181328
release2 before = 1
third entry map header = 0
third entry bucket header = 0
```

This means the first caller-side retain does happen, but the map header is already zero by the time the first empty insert branch starts in `func27`, before the branch's final tracked `release`. That refined the earlier inference: the final release/free path is still where the stale object becomes visible, but the earliest observed map-header clobber in the reduced fixture is before the first empty-branch insertion body, between the caller retain and the insert branch. The allocator-owner evidence below resolves the then-unknown exact write.

## June 2 allocator-owner evidence

Further reduced-fixture instrumentation identified the exact write that zeroes the startup map header. The clobber is not in the map insertion body itself; it is in the TLSF free-list unlink path reached while hashing the first startup-map key.

Function mapping for this slice:

- reduced `func6` = raw-stub/full `func22`, the `$moonbit.malloc`-equivalent allocator entry;
- reduced `func2` = raw-stub/full `func18`, the `$tlsf/removeBlock`-equivalent free-list unlink helper;
- reduced `func3` = raw-stub/full `func19`, the `$tlsf/insertBlock`-equivalent free-list insert helper;
- reduced `func20`/`func25`/`func27` remain the startup map population/set/insert path already mapped to raw-stub/full `func473`/`func3749`/`func3751`.

The bad sequence is:

1. `func20` constructs the startup map at pointer `181248`; the object header is `1` immediately after construction and `2` after the caller retain.
2. During the map-object allocation, `func6` calls `func2` with `0` as the allocator/control-root argument. Instrumentation showed the free-list unlink uses a zero-based head slot (`532`) instead of the real TLSF root-relative slot. The actual root-relative remainder slot (`177780`) still contains the allocated block header pointer `181244`.
3. The map allocation then inserts remainder block `181276` through `func3` using the real TLSF root. That insertion records `old_head = 181244`, so `181276.next` becomes `181244` even though `181244` is now the allocated map object's block header.
4. The first hash-object allocation later unlinks free block `181276`. `func2` sees `next = 181244` and executes its normal `next.prev = prev` store with `prev = 0`. The exact clobber is reduced `func2` / raw-stub `func18` at the `local.get 15; local.get 16; i32.store offset=4` unlink instruction, writing `0` to `181244 + 4 == 181248`, which is the startup map object's refcount/header word.
5. `func25` therefore observes the map header change from `2` before hashing to `0` after hashing, before `func27` starts the empty-insert branch. The later bucket-array length trap is downstream use-after-free/free-list corruption fallout.

Key scratch values from `.tmp/o4z-bench/instrument_reduced_fixture_allocator_owner.py`:

```text
__map_alloc_ptr 181248
__map_alloc_after_call8_map_h 1
__map_pre_call8_remainder_slot_value 181244
__map_f2_block 181244
__map_f2_head_slot 532
__map_f2_head_before 0
__map_f3_block 181276
__map_f3_old_head 181244
__map_f3_head_slot 177780
__func20_after_ctor_map_h 1
__func20_after_ctor_free_next 181244
__first_hash_f2_entry_map_h 2
__first_hash_f2_block_h 15325
__first_hash_f2_prev 0
__first_hash_f2_next 181244
__first_hash_f2_before_nextprev_map_h 2
__first_hash_f2_after_nextprev_map_h 0
```

A scratch one-instruction WAT patch on the reduced fixture replaced the suspicious `func6` prefix:

```wat
nop
i32.const 0
global.get 0
local.tee 5
```

with:

```wat
nop
global.get 0
global.get 0
local.tee 5
```

The patched reduced module validates and `wasi.start` exits `0`. This confirms the reduced startup trap is owned by the bad allocator-root value feeding `removeBlock`, not by map/set/hash semantics.

Current freshly printed debug/release artifacts also narrow the owner to the committed debug-WASI artifact generation rather than the current MoonBit runtime source shape. `.tmp/o4z-bench/fresh-debug.wat` names the corresponding function `$moonbit.malloc` and carries `global.get $tlsf/ROOT` through to `call $tlsf/removeBlock`; the bad `i32.const 0; global.get 0; local.tee ...; ... call removeBlock` shape is absent in both `.tmp/o4z-bench/fresh-debug.wat` and `.tmp/o4z-bench/fresh-release.wat`, but present in `.tmp/o4z-bench/raw-stub-f535.wat` / the committed debug-WASI input. A direct print of the current local `_build/wasm/debug/build/cmd/cmd.wasm` also validates and has the named correct `$tlsf/ROOT`/`$tlsf/removeBlock` shape. `scripts/lib/self-optimized-artifacts.mjs` copies that `_build/wasm/debug/build/cmd/cmd.wasm` path into `tests/node/dist/starshine-debug-wasi.wasm`, so the remaining production task is to fix or regenerate the committed debug-WASI artifact and reduced fixture from the current correct allocator shape, then re-run the full self/debug `-O4z` path.

## Focused TDD slice

A reduced startup-root fixture was extracted from the raw-stub module and patched to export memory plus the extracted start function as `_start`:

- fixture: `tests/repros/o4z-debug-startup-map-init-repro.wasm`
- guard: `scripts/lib/o4z-debug-startup-map.test.ts`
- confirmation command: `bun test scripts/lib/o4z-debug-startup-map.test.ts`
- current result: passing as of 2026-06-02 after regenerating the debug-WASI artifact and reduced fixture from the current `$moonbit.malloc` shape.

The guard still matters because it protects both the structural allocator-root assertion and a runtime startup assertion. It should remain active even though the stale-artifact owner is repaired.

## June 2 full self/debug `-O4z` pass-owner follow-up

After the stale debug-WASI artifact and reduced fixture were repaired, the full self/debug `-O4z` candidate became valid but exposed real optimizer runtime owners that had been hidden by the stale startup trap. Prefix probing used the explicit 39-pass shrink list and Node/WASI replays of both `--help` and `spec tests/spec/address.wast`.

### `ssa-nomerge`

The first fresh `--help` trap after artifact repair was `null function or function signature mismatch` in `append_help_line` / `Iter::next`. Prefix probing identified prefix `5` (`ssa-nomerge`) as the owner. The bad lowering dropped the iterator-producing call and left a later loop reading the old local:

```text
call $iter
drop
loop ... local.get 3 ...
```

The reduced regression is `ssa-nomerge keeps call result assigned when a later loop reads the local`. The production fix is a conservative nested-control/CFG-sensitive guard in `src/passes/ssa_nomerge.mbt` so the pass does not rewrite structured regions whose nested local reads are not modeled safely by the current local-liveness view.

### `optimize-instructions`

After the SSA guard, prefix `12` (`optimize-instructions`) trapped in `moonbit.check_range` through `StringBuilder`. Diffing prefix `11` vs `12` showed commutative canonicalization reordering address operands and shifted/local terms across dependent pure-looking expressions. Temporarily disabling commutative canonicalization made prefix `12` run.

The production fix is conservative: `optimize_instructions_try_canonicalize_commutative` now declines the rewrite, and adjacent tests assert operand order is preserved for TLSF/address-like and trapping-load shapes.

### `simplify-locals-nostructure`

After the optimize-instructions fix, prefix `18` (`simplify-locals-nostructure`) trapped through `Buffer.to_bytes` / `Bytes.from_array`. A minimal scratch repro showed the pass moving `local.get 5; i32.load` above the defining `local.tee 5`. The adjacent regression is `simplify-locals-nostructure keeps tee before dependent loads`.

The production fix has two layers:

- one-use movement no longer treats `Load` as a freely cloneable value;
- `simplify-locals-nostructure` skips functions containing `LocalTee` until the sinking model can prove local-write barriers precisely.

### `coalesce-locals`

With `simplify-locals-nostructure` guarded, prefix `25` (`coalesce-locals`) first trapped during startup in `pass_registry_entries`, then after loop guarding trapped on a table index in command startup. The root cause was the conservative structured-control coalescer flattening action streams through loops/local.tee-bearing structured regions and merging locals whose values were live across paths or carried by `local.tee`.

The production fix keeps flat coalescing behavior but skips:

- functions containing loops, covered by `coalesce-locals skips loop functions to preserve cross-iteration liveness`;
- structured-control functions containing `local.tee`, covered by `coalesce-locals skips local-tee functions to preserve tee-carried values`.

Flat local-tee cases remain available so existing DAE/local-cse integration still removes temporary locals where it is known safe.

### `vacuum`

The candidate passed `--help` after the coalesce guard, but `spec tests/spec/address.wast` still trapped in `String.sub` while trimming spec arguments. A spec-args prefix probe found prefix `10` (`vacuum`) as the first owner for that path. The unsafe family was branchy structured functions with local writes: raw vacuum preclean/HOT cleanup removed no-op debris inside shapes where the current cleanup path does not preserve the surrounding lowered control semantics reliably.

The production fix skips vacuum cleanup for branchy structured functions with local writes in both the large raw preclean gate and the HOT vacuum runner. The raw gate is covered by `raw vacuum preclean skips large structured functions with writes`. Existing large non-branchy nested value-expression cleanup remains covered by `vacuum removes nested value-expression debris in large functions`.

### Current signoff evidence

The current repaired candidate path is:

```sh
moon fmt
moon test src/passes
moon build --target native --release src/cmd
node .tmp/o4z-bench/run_o4z_prefix_probe.mjs 25 30 35 39
node .tmp/o4z-bench/run_o4z_prefix_probe_spec.mjs 10 12 18 25 39
_build/native/release/build/cmd/cmd.exe -O4z \
  --out .tmp/o4z-bench/starshine-o4z-candidate.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
wasm-tools validate --features all .tmp/o4z-bench/starshine-o4z-candidate.wasm
node scripts/lib/run-self-optimized-spec-suite.mjs \
  --wasm .tmp/o4z-bench/starshine-o4z-candidate.wasm --limit 1
node scripts/lib/run-self-optimized-spec-suite.mjs \
  --wasm .tmp/o4z-bench/starshine-o4z-candidate.wasm \
  --file tests/spec/i32.wast --file tests/spec/call.wast --file tests/spec/ref.wast
bun test scripts/lib/o4z-debug-startup-map.test.ts
```

Observed result: all commands above passed on 2026-06-02. The full self/debug `-O4z` candidate validates and runs the `--help`, first-spec, and selected `i32`/`call`/`ref` spec smoke paths under Node/WASI.

The same repaired candidate then passed broader coverage:

```sh
node scripts/lib/run-self-optimized-spec-suite.mjs \
  --wasm .tmp/o4z-bench/starshine-o4z-candidate.wasm --limit 20
node scripts/lib/run-self-optimized-spec-suite.mjs \
  --wasm .tmp/o4z-bench/starshine-o4z-candidate.wasm
```

Observed result: both commands passed; the full run executed all `284` `tests/spec/**/*.wast` files.

## Recommended next slice

1. Keep `scripts/lib/o4z-debug-startup-map.test.ts` as a permanent artifact-staleness guard.
2. Treat the SSA, optimize-instructions, simplify-locals-nostructure, coalesce-locals, and vacuum changes as conservative correctness gates. Future optimization recovery should replace them with precise local-liveness/effect/path models one pass at a time, preserving the focused regressions above.
3. If size or speed regressions matter, profile the lost opportunities from disabled commutative canonicalization and skipped structured/tee/branchy cleanup before re-enabling any transform.

## Evidence status

The June 1 findings were observational and based on temporary `.tmp/o4z-bench/` WAT instrumentation plus Node/WASI replay. The June 2 follow-up adds a focused failing repo test and reduced fixture. Scratch generation helpers and large temporary artifacts remain under `.tmp/o4z-bench/` and should not be committed.

## Reference semantics

The `RuntimeError: unreachable` surface is consistent with the WebAssembly JavaScript interface, not a separate Node-only trap mode: MDN documents `WebAssembly.RuntimeError` as the error type WebAssembly throws for traps, and documents `unreachable` as an unconditional trap instruction that raises that runtime error when executed.

Primary references:

- <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/RuntimeError>
- <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Control_flow/unreachable>

This keeps the remaining failure classified as a real runtime trap while the reduced fixture stays the active TDD guard.
