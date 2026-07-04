# Optimize-instructions OI-L atomic closeout

Date: 2026-07-03

## Scope

This note closes or sharply bounds OI-L, the `optimize-instructions` GC aggregate atomics / RMW / cmpxchg surface.

Inputs reviewed:

- `agent-todo.md`
- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- OI-K closeout notes `1435`, `1436`, and `1437`
- existing shared-GC atomic boundary notes, especially `docs/wiki/raw/wasm/2026-06-05-shared-everything-threads-boundary-refresh.md` and `docs/wiki/raw/research/0708-2026-06-04-struct-atomic-get-pass-opportunity-audit.md`
- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`
- `src/validate/gen_valid.mbt`
- `src/validate/gen_valid_tests.mbt`

OI-J descriptor/exactness/TNH/IIT remains quarantined. OI-K aggregate constructor/get/set evidence is not used as OI-L closure evidence.

## Pre-start worktree check

Before OI-L work, the worktree was clean:

```sh
git status --short
# no output
```

Recent commits also showed the final OI-K implementation/docs/test/profile changes already committed on `master`, led by `275e61a4c fix: close OI-K aggregate residuals` after `200453801 docs: record OI-K effect localization evidence` and `77f559f8e fix: localize OI-K array effects`.

## Matrix row before closeout

The row was already not an active implementation row:

- row id: `OI-L-gc-atomics-rmw-cmpxchg`
- family: `OI-L`
- status: `blocked-surface`
- priority: `P2`
- closeout state: `blocked-surface`
- blocker text: Starshine exposes some `struct.atomic.get` syntax, but aggregate RMW/cmpxchg text/core constructors and unshared-lowering coverage are incomplete.
- listed profile: `pass-oi-ref-gc`, but that profile is non-descriptor reference smoke and does not exercise OI-L atomics.
- sweep: disabled (`enabled: false`, count `100`, seed `0x5eed` before this update)
- reopening criteria: Starshine gains aggregate atomic RMW/cmpxchg representation/parser/lowerer support or v0.1 scope requires the surface.

This slice updates the row to keep it blocked, but no longer vague: Binaryen has a small direct struct-RMW/cmpxchg rewrite family, array RMW/cmpxchg is a no-rewrite sampled boundary, and Starshine is blocked before optimization by missing representation/binary/tooling support.

## Probe setup

Probe directory: `.tmp/oi-l-gc-atomics-probes-20260703/`.

Valid probes were built for:

- `struct-atomic-get.wat`
- `struct-rmw-add.wat`
- `struct-rmw-add-zero.wat`
- `struct-rmw-or-zero.wat`
- `struct-rmw-and-allones.wat`
- `struct-rmw-xchg.wat`
- `struct-cmpxchg-same.wat`
- `struct-cmpxchg-different.wat`
- `array-rmw-add.wat`
- `array-rmw-add-zero.wat`
- `array-cmpxchg-same.wat`

All inputs were accepted by local Binaryen `wasm-opt version 130` with `--all-features`, emitted to wasm, printed back to WAT, and validated with `wasm-tools validate --features all`. The generated `probe-summary.json` records per-output opcode counts and sizes.

For each probe, the slice ran:

```sh
wasm-opt <probe>.wat --all-features -o <probe>.input.wasm
wasm-opt <probe>.input.wasm --all-features -S -o <probe>.input.print.wat
wasm-tools validate --features all <probe>.input.wasm
wasm-opt <probe>.input.wasm --all-features --optimize-instructions -o <probe>.binaryen-direct.wasm
wasm-opt <probe>.binaryen-direct.wasm --all-features -S -o <probe>.binaryen-direct.wat
wasm-tools validate --features all <probe>.binaryen-direct.wasm
wasm-opt <probe>.input.wasm --all-features -O4 -Oz -o <probe>.binaryen-O4z.wasm
wasm-opt <probe>.binaryen-O4z.wasm --all-features -S -o <probe>.binaryen-O4z.wat
wasm-tools validate --features all <probe>.binaryen-O4z.wasm
target/native/release/build/cmd/cmd.exe --optimize-instructions -o <probe>.starshine.wasm <probe>.input.wasm
```

## Binaryen direct behavior

Binaryen direct `--optimize-instructions` does rewrite the unshared struct aggregate RMW/cmpxchg surface.

| Probe | Direct Binaryen behavior | O4z behavior |
|---|---|---|
| `struct-atomic-get` | Preserves `struct.atomic.get` | Preserves `struct.atomic.get`; exactifies the global type |
| `struct-rmw-add` | Lowers `struct.atomic.rmw.add` to `struct.get` + `struct.set` with locals, returning the old value | Same semantic lowering, fewer locals / `local.tee`, exact global type |
| `struct-rmw-xchg` | Lowers to `struct.get` + `struct.set` | Same semantic lowering with O4z cleanup |
| `struct-cmpxchg-different` | Lowers to `struct.get` + conditional/selected `struct.set` shape | Same semantic lowering with O4z cleanup |
| `struct-rmw-add-zero` | Rewrites to `drop(i32.const 0)` plus `struct.atomic.get` | Drops the dead constant and keeps only `struct.atomic.get` |
| `struct-rmw-or-zero` | Rewrites to `drop(i32.const 0)` plus `struct.atomic.get` | Drops the dead constant and keeps only `struct.atomic.get` |
| `struct-rmw-and-allones` | Rewrites to `drop(i32.const -1)` plus `struct.atomic.get` | Drops the dead constant and keeps only `struct.atomic.get` |
| `struct-cmpxchg-same` | Rewrites to two dropped expected/replacement operands plus `struct.atomic.get` | Drops the dead constants and keeps only `struct.atomic.get` |
| `array-rmw-add` | Preserves `array.atomic.rmw.add` | Preserves `array.atomic.rmw.add`; exactifies the global type |
| `array-rmw-add-zero` | Preserves `array.atomic.rmw.add` | Preserves `array.atomic.rmw.add`; exactifies the global type |
| `array-cmpxchg-same` | Preserves `array.atomic.rmw.cmpxchg` | Preserves `array.atomic.rmw.cmpxchg`; exactifies the global type |

So the answer to question 1 is **yes** for struct aggregate RMW/cmpxchg, including both unshared lowering and identity-RMW-to-atomic-get simplifications. The answer is **no in the sampled array cases**: direct Binaryen preserved array RMW/cmpxchg.

The answer to question 2 is **yes, but mostly as cleanup around the same struct semantics**: `-O4 -Oz` removes dead dropped constants, tightens exact global types, and uses smaller local/tee shapes, but it does not add array RMW/cmpxchg rewrites in these probes.

## Starshine behavior

Starshine does not currently reach an OI-L optimizer decision for these current Binaryen-compatible probes.

- Aggregate RMW/cmpxchg probes fail during decode with `DecodeAt(InvalidAtomicInstruction, ...)`:
  - struct RMW/cmpxchg examples fail around opcode/subcode positions `46,15` or `46,17`;
  - array RMW/cmpxchg examples fail around `44,16` or `44,18`.
- The `struct-atomic-get` binary emitted by current Binaryen aborts the current Starshine native binary before a valid Starshine output is produced. This is consistent with the known split: Starshine has an older focused `struct.atomic.get*` slice with explicit order syntax, while Binaryen/wasm-tools accepted and emitted orderless current-proposal aggregate atomic-get syntax.
- Existing local Starshine tests still prove the Starshine-owned ordered `struct.atomic.get*` text/core slice is intentionally conservative for passes. For example, `src/passes/atomic_pass_support_test.mbt` has `optimize-instructions treats struct atomic gets as load-call barriers`.

Thus the answer to question 3 is:

- Starshine partially parses/prints/lifts `struct.atomic.get*` in its current local ordered syntax and preserves it conservatively in pass tests.
- Starshine does **not** correctly parse/decode/lower/print the current Binaryen-compatible OI-L RMW/cmpxchg surface.
- Starshine cannot compare direct OI-L optimizer behavior yet because the inputs fail before optimization.

## Classification

OI-L is a **blocked-surface**, not an accepted no-rewrite boundary and not an implementable optimizer slice today.

Why not accepted no-rewrite:

- Binaryen direct `--optimize-instructions` demonstrably rewrites unshared struct aggregate RMW/cmpxchg shapes.

Why not implement now:

- The required Starshine instruction surface is missing: no `StructRMW`, `StructCmpxchg`, `ArrayRMW`, or `ArrayCmpxchg` WAST/core/binary/validator/HOT/generator support is visible in the reviewed source.
- Even the represented `struct.atomic.get*` slice has syntax/binary drift relative to current Binaryen/wasm-tools orderless aggregate atomic-get syntax.
- Implementing the optimizer rewrite before the representation substrate would require faking or bypassing parser/lowering semantics, which would violate the slice rule not to speculatively implement broad atomics/RMW/cmpxchg behavior.

Runtime execution is also a boundary. These probes only prove static parse/validate/transform behavior. Ordinary single-thread runtime equality would not prove true shared/concurrent semantics, memory ordering, or atomicity, so no runtime-green claim is made for OI-L.

## Reopening criteria

Reopen OI-L only when at least one of these happens:

1. Starshine gains current Binaryen/wasm-tools-compatible aggregate atomic syntax and binary support for `struct.atomic.get*`.
2. Starshine gains WAST/core/binary/validator/HOT/lowerer/printer support for aggregate RMW/cmpxchg:
   - `struct.atomic.rmw.*`
   - `struct.atomic.rmw.cmpxchg`
   - `array.atomic.rmw.*`
   - `array.atomic.rmw.cmpxchg`
3. A tiny `pass-oi-gc-atomics` GenValid trigger-smoke profile can generate only validating, supported OI-L shapes with explicit labels.
4. A valid OI-L probe reaches Starshine `--optimize-instructions` and shows a mismatch against Binaryen direct behavior.
5. v0.1 release scope explicitly requires the Shared-Everything aggregate atomic proposal surface.
6. True shared/concurrent runtime tooling becomes available and can test atomicity/order without using single-thread equality as a substitute.

A reopened implementation must start red-first from the 1438 struct probes, preserve memory ordering, atomicity, null traps, bounds traps, operand effects, and shared-vs-unshared validation constraints, and must not pull in OI-J descriptor/exactness/TNH/IIT or reopen closed OI-K aggregate constructor/get/set behavior unless their own criteria fire.

## Matrix/docs changes

This slice updates:

- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
  - keeps OI-L as `blocked-surface`, but changes `closeoutState` to `blocked-surface-finite`;
  - removes the misleading `pass-oi-ref-gc` OI-L profile claim;
  - disables OI-L sweep planning until a future `pass-oi-gc-atomics` profile and representation substrate exist;
  - records the exact Binaryen direct/O4z probe behavior and reopening criteria.
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/log.md`
- `agent-todo.md`

No code or optimizer behavior is implemented in this slice.

## Validation status

Probe validation completed before this note was finalized:

- All Binaryen input/direct/O4z probe wasm outputs validate with `wasm-tools validate --features all`.
- Starshine probe attempts fail before optimization for the unsupported current OI-L surface, as classified above.

Repository validation completed after the docs/matrix updates:

```sh
moon fmt
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity-matrix.json.check
moon info
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*atomic*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*rmw*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*cmpxchg*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*optimize-instructions*'
moon test
moon build --target native --release src/cmd
git diff --check
git diff --cached --check
```

Results:

- `moon fmt` passed (`no work to do`).
- JSON validation passed.
- `moon info` passed with pre-existing warnings in `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/ir/hot_verify.mbt`, `src/validate/gen_valid.mbt`, and `src/validate/gen_valid_ssa.mbt`.
- Focused `*atomic*` tests passed `4/4`.
- Focused `*rmw*` and `*cmpxchg*` filters found no test entries (`0/0`), which matches the blocked OI-L representation state.
- Focused `*optimize-instructions*` tests passed `656/656`.
- Full `moon test` passed `7329/7329`.
- Native `src/cmd` release build passed (`no work to do`).
- `git diff --check` and `git diff --cached --check` passed.

No GenValid profile or sweep profile was added, so the optional `pass-oi-gc-atomics` validation and smoke-sweep commands were intentionally not run.

## 2026-07-03 follow-up: partial implementation state

A follow-up slice moved OI-L from a pure representation blocker to **partial implementation with a finite receiver/HOT blocker**.

Implemented and tested:

- Core/shared-GC aggregate atomic RMW/cmpxchg representation is present enough for current Binaryen-compatible probe binaries to decode, encode, validate, lift, and lower.
- `optimize-instructions` rewrites local-receiver unshared struct RMW/cmpxchg in the focused pass test:
  - `struct.atomic.rmw.add` and `struct.atomic.rmw.xchg` lower to `struct.get`/`struct.set` with temporaries and return the old value;
  - identity RMW (`add/or/xor 0`, `and -1`) lowers to `struct.atomic.get` plus operand drops;
  - equal expected/replacement cmpxchg lowers to `struct.atomic.get` plus operand drops;
  - different expected/replacement cmpxchg lowers to `struct.get`/`struct.set`/`select`;
  - array aggregate atomics intentionally remain a no-rewrite boundary.
- Native Starshine probe smoke over `.tmp/oi-l-gc-atomics-probes-20260703/*.input.wasm` with `--optimize-instructions --validate` now exits 0 and `wasm-tools validate --features all` accepts every output.

Current blocker:

- The native Binaryen-shaped struct probes use a global receiver. HOT lift/lower currently represents these aggregate atomic result bodies with a trailing `unreachable` sentinel; if `optimize-instructions` mutates such functions, lowering can collapse the body to `unreachable`. To keep the command semantically fail-closed, the pass now returns `unchanged` for aggregate atomic functions whose struct receiver is not `local.get` and for array aggregate atomics. The next OI-L slice must fix HOT lift/root result handling for aggregate atomic result bodies or add a safe raw rewrite before widening the receiver gate to `global.get`.

Validation for this follow-up:

```sh
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*OI-L*'
moon build --target native --release src/cmd
for f in .tmp/oi-l-gc-atomics-probes-20260703/*.input.wasm; do target/native/release/build/cmd/cmd.exe --optimize-instructions --validate -o .tmp/oi-l-starshine-opt-20260703/$(basename "$f" .input.wasm).starshine.wasm "$f"; wasm-tools validate --features all .tmp/oi-l-starshine-opt-20260703/$(basename "$f" .input.wasm).starshine.wasm; done
moon fmt
moon test
```

Results: focused OI-L test passed, native probe smoke passed, `moon fmt` passed, and full `moon test` passed (`7333/7333`) with pre-existing warnings.
