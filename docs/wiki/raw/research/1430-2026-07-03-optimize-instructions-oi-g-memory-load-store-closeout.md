# Optimize-instructions OI-G memory/load-store closeout refresh

Date: 2026-07-03

## Question

After OI-M closeout restored the full-parity policy for the remaining optimize-instructions families, can OI-G move out of active full-parity gap, or at least be narrowed to concrete unsupported/runtime surfaces?

## Inventory

I refreshed the OI-G row in `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`, the active `[O4Z-AUDIT-OI]` backlog entry in `agent-todo.md`, and the OI-G notes listed from `docs/wiki/binaryen/passes/optimize-instructions/index.md`.

Current classification before this slice:

- OI-G row: `OI-G-memory-bulk-load-store`, priority `P0`, `closeoutState: parity-gap`.
- Already closed finite residuals: count120 residual closure, count245 memory64+multi-memory localtee fill, and count490 default-memory memory.copy localtee.
- Implemented/source-backed positives include tiny exact `memory.copy` / `memory.fill` lowerings, constant-address scalar load/store offset folding for memory32/memory64, atomic load/store constant-offset folding, and the exact raw-gate escapes documented in prior OI-G notes.
- Explicit boundaries remain for zero-size bulk-memory cleanup without trap-mode support, nonconstant-size bulk memory, nonconstant pointer load/call offset folding, broad mixed load/call or stack-carried-effect raw-gate escapes, and atomic RMW/cmpxchg offset folding where Binaryen preserves the sampled offsets.

I also wrote a local scratch inventory at `.tmp/oi-g-closeout-inventory-20260703.md` before running fresh evidence.

## Fresh grouped evidence

Command:

```sh
moon build --target native --release src/cmd
rm -rf .tmp/oi-g-closeout-count980-20260703
bun scripts/oi-parity-sweep.ts --family OI-G --count 980 --out-dir .tmp/oi-g-closeout-count980-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --execute -- --runtime-execution node --max-failures 2000 --keep-going-after-command-failures
bun scripts/oi-parity-sweep.ts --family OI-G --out-dir .tmp/oi-g-closeout-count980-20260703 --summarize-existing
```

Result for `OI-G-memory-bulk-load-store`:

- requested/compared: `980/980`
- normalized matches: `980`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- cache: Binaryen `980/0`, Binaryen failures `0/0`, wasm-smith `0/0`
- runtime execution: checked `565`, unsupported `415`, failed `0`
- runtime matrix: total `893`, equal results `478`, equal traps `0`, unsupported runtimes `415`, nondeterministic imports `0`, semantic mismatches `0`
- all `49` `pass-oi-memory-bulk` profile labels were sampled; every case-label status was `match`.

Representative sampled labels included shared atomic random/select/localtee RMW/cmpxchg/add/sub/xor/or/and/xchg, shared wait/notify, runtime copy/fill/store8 restore labels, direct tiny bulk, dynamic i32 bulk, multi-memory, memory64, memory64+multi-memory, and cross-memory restore/read labels.

## Representative validation and opcode/size evidence

Because the count980 lane had no failure dirs, I created representative artifacts from successful inputs under `.tmp/oi-g-closeout-count980-20260703/representatives`:

```sh
REP_DIR=.tmp/oi-g-closeout-count980-20260703/representatives
BASE=.tmp/oi-g-closeout-count980-20260703/oi-g/OI-G-memory-bulk-load-store/inputs/gen-valid
for idx in 000010 000022 000035 000042 000044; do
  wasm-opt --all-features --optimize-instructions "$BASE/gen-valid-$idx.wasm" -o "$REP_DIR/case-$idx.binaryen.raw.wasm"
  target/native/release/build/cmd/cmd.exe --optimize-instructions "$BASE/gen-valid-$idx.wasm" -o "$REP_DIR/case-$idx.starshine.raw.wasm"
  wasm-tools validate --features all "$BASE/gen-valid-$idx.wasm"
  wasm-tools validate --features all "$REP_DIR/case-$idx.binaryen.raw.wasm"
  wasm-tools validate --features all "$REP_DIR/case-$idx.starshine.raw.wasm"
  wasm-tools print "$REP_DIR/case-$idx.binaryen.raw.wasm" > "$REP_DIR/case-$idx.binaryen.wat"
  wasm-tools print "$REP_DIR/case-$idx.starshine.raw.wasm" > "$REP_DIR/case-$idx.starshine.wat"
  wasm-opt --all-features "$REP_DIR/case-$idx.binaryen.raw.wasm" -o "$REP_DIR/case-$idx.binaryen.canonical.wasm"
  wasm-opt --all-features "$REP_DIR/case-$idx.starshine.raw.wasm" -o "$REP_DIR/case-$idx.starshine.canonical.wasm"
  wasm-tools validate --features all "$REP_DIR/case-$idx.binaryen.canonical.wasm"
  wasm-tools validate --features all "$REP_DIR/case-$idx.starshine.canonical.wasm"
done
```

| case | label / transform | raw bytes Binaryen / Starshine | canonical bytes Binaryen / Starshine | WAT bytes Binaryen / Starshine | traffic check |
| --- | --- | ---: | ---: | ---: | --- |
| `000010` | `memory64-multi-memory-localtee-fill-restore-read` / `oi-live-nonzero-memory-end-copy-boundary` | `139 / 136` | `139 / 139` | `869 / 869` | `i32.load 2/2`, `i64.load 2/2`, `i32.store 2/2`, `i64.store 1/1`, `local.tee 3/3` |
| `000022` | `shared-atomic-localtee-cmpxchg-restore` / `oi-memory-size-boundary` | `316 / 315` | `316 / 316` | `1948 / 1948` | `memory.copy 3/3`, `memory.fill 3/3`, `atomic 4/4`, `local.tee 4/4` |
| `000035` | `shared-wait-notify` / `oi-live-nonzero-memory-cross-copy-boundary` | `192 / 192` | `192 / 192` | `1147 / 1147` | `memory.atomic.wait 2/2`, `memory.atomic.notify 1/1`, atomic total `3/3` |
| `000042` | `runtime-store8-mask-restore-read` / `oi-live-nonzero-memory-end-fill-restore-boundary` | `193 / 190` | `193 / 193` | `1111 / 1111` | load/store traffic matched: `i32.load 4/4`, `i64.load 2/2`, `i32.store 3/3`, `i64.store 2/2` |
| `000044` | `runtime-call-restore-copy-read` / `oi-local-carried` | `164 / 163` | `164 / 164` | `989 / 989` | `memory.copy 1/1`, `i32.load 2/2`, `i32.store 1/1`, `call 6/6` |

All representative input/raw/canonical artifacts validated with `wasm-tools validate --features all`. Starshine raw size was equal or smaller in every sample, canonical sizes matched after no-pass `wasm-opt --all-features`, WAT sizes matched, and inspected opcode/traffic counts matched.

## Classification

This materially narrows OI-G but does **not** close it.

Closed for the current generated/grouped surface:

- There are no sampled raw mismatches in the count980 grouped OI-G lane.
- The previously closed count120, count245, and count490 residual families stayed closed; this run should not be re-triaged as if those finite residual dirs were still active blockers.
- The representative validation/opcode/size review found no validation failure, opcode-count drift, raw/canonical size loss, or runtime semantic mismatch in the sampled artifacts.

Still active:

- Runtime matrix remains blocked by `415` unsupported runtime adapters. These are evidence gaps, not semantic failures, and they prevent full closeout.
- Broader shared-memory ordering/concurrency and blocking wait/notify semantics are not proven by private/nonblocking smoke evidence.
- Exact memory64/multi-memory runtime behavior is still only partially executable under the current Node runtime adapter.
- Live trap/effect ordering beyond the existing restore/smoke surfaces remains a full-parity blocker if new source-backed shapes appear.
- Zero-size `memory.copy` / `memory.fill` cleanup remains blocked by trap-mode policy and must not be implemented without explicit local ignore-traps/TNH/IIT-equivalent support.

## Reopening / next-work criteria

Reopen or keep OI-G active for any of:

- validation failure, command failure, runtime semantic mismatch, unequal trap, or nondeterministic runtime import affecting OI-G memory/load/store/bulk/atomic cases;
- new raw mismatch after count980 that is not already closed by count120/count245/count490/count980 evidence;
- Starshine raw/canonical/WAT size loss without a measured Starshine win;
- memory index drift, memory64 address-width drift, load/store width or signedness drift, atomic opcode-count drift, source-visible memory mutation drift, or helper-call/local.tee/select operand-order drift;
- new runtime-supported counterevidence for memory64/multi-memory or shared-memory cases;
- source-backed Binaryen behavior for blocking wait/notify, true shared-memory ordering/concurrency, or broader live trap/effect ordering that Starshine does not yet implement;
- any attempt to treat this OI-G evidence as closing OI-I, OI-J, OI-K, or OI-M.

Next high-leverage OI-G work should target unsupported runtime buckets or a newly exposed source-backed residual outside the normalized-green count980 surface, not the already-closed finite residual dirs.
