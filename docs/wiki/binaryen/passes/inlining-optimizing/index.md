---
kind: entity
status: supported
last_reviewed: 2026-08-13
sources:
  - ../../release-horizon-and-oracles.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/opt-utils.h
  - ../inlining/index.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./deferred-inl005-inl006-work.md
  - ../inlining/index.md
  - ../dae-optimizing/index.md
  - ../precompute-propagate/index.md
---

# `inlining-optimizing`

## Status

`inlining-optimizing` is supported for Binaryen v131 behavior on the represented surface. The shared direct engine is closed with plain [`inlining`](../inlining/index.md), including toolchain policy, complete profitability classes, Pattern A/B splitting, multivalue/local repair, and EH-aware direct/indirect/ref tail handling.

The optimizing suffix now uses the v131 order:

1. inline chosen actions;
2. run touched-only `precompute-propagate`;
3. run the represented v131 default function optimization pipeline on touched functions only.

There is no open inlining-specific v131 transform gap. `[O4Z-NESTED]001` remains active only to route DAE, inlining, and SGO through one shared scheduler expansion API; it does not reopen this pass's current direct behavior or tested nested order.

## Role

This is the late optimizing sibling used by the O4z path. It is not merely “more aggressive inlining”: it uses the same profitability decisions as plain `inlining`, then immediately exposes and cleans constants, locals, dead control, and other debris created by body copying.

## Direct engine

See [`../inlining/index.md`](../inlining/index.md) for the full family matrix. In summary, the shared engine covers:

- v131 toolchain and no-inline policy channels;
- all public tuning controls;
- tiny, one-caller, shrinking-trivial, may-grow-trivial, flexible, loop, and combined-size policy;
- Pattern A/B splitting;
- direct `call` / `return_call` planning;
- local/type/control/metadata repair;
- EH-aware direct/indirect/ref tail-call localization and hoisting;
- root survival and private-helper deletion;
- stack-preserving substitution for ordered single-use parameter prefixes, wrapper omission when no function exit requires a synthetic return label, adjacent `local.set` / `local.get` folding to `local.tee`, and same-iteration scratch-local reuse across sequential callsites.

## Nested cleanup contract

The nested roster is represented by `inlining_nested_function_pipeline_passes(...)` and tested in exact order. Important invariants:

- `precompute-propagate` is prepended once;
- only touched callers are cleaned;
- untouched functions retain their bodies and valid debug maps;
- plain `inlining` never enters this path;
- large modules and modules with surviving tail calls no longer bypass the suffix wholesale;
- option-gated slots follow optimize/shrink policy;
- validation-or-fallback guards reject an invalid nested candidate rather than corrupting the module.

The local implementation still contains Starshine-specific cleanup and unreachable-cycle accounting used to match the oracle and preserve smaller validated outputs. Those are implementation details, not a reduced public contract.

Inline replacement also preserves Wasm's zero-initialized-local semantics without blindly materializing a default constant for every appended callee local. A conservative read-before-write scan keeps initialization whenever a reachable root, structured body, legacy catch, or `try_table` body can observe the incoming default. Initialization is omitted only when all observed reads follow a definite root-sequence write; structured-child writes are deliberately not promoted to definite assignment across their enclosing boundary.

On the BLAKE3 SIMD O4z artifact this removes the dominant copied `v128.const 0; local.set` footprint and reduces validated output from `63,927` to `45,654` bytes (`-18,273`, `-28.6%`). Verified Binaryen v131 remains smaller at `39,484` bytes, leaving `6,170` bytes / `15.6%`; the residual remains a P1 local simplification and coalescing gap.

## Evidence

Current tests:

- focused inlining behavior: `133/133`;
- inlining white-box: `19/19`;
- command: `107/107`;
- full repository: `10385/10385`.

Official v131 aggregate closeout:

```text
.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
profile: inlining-optimizing-all
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation failures
0 property failures
0 generator failures
0 command failures
```

The plain sibling independently reached `10000/10000` in `.tmp/pass-fuzz-inlining-v131-closeout-10000`. After the 2026-08-13 implicit-function-label repair, rebuilt native SHA-256 `659a002fec66e17d76cae02a24bb854a77ae844a970acef767527daf5ca209fe` refreshed `inlining-optimizing-all` at `10000/10000` exact normalized matches with zero mismatches or failures; the matching `pass-inlining` lane is also `10000/10000` exact.

The accepted pass-local performance fixture remains the inline-heavy helper-chain matrix documented in [`fuzzing.md`](./fuzzing.md); reopen on a repeated median regression above Binaryen or a new nested-cleanup scaling cliff.

## 2026-08-09 production O4z boundary

The exact `json-as` report-protocol lane exposed generated call/bulk-memory modules at `286` and `293` defined functions where broad module-level optimizing inlining changed the call graph and corrupted execution. The broad optimizing lane remains closed from `286` definitions upward. On 2026-08-12 the guard was narrowed to a shrinking-trivial plain-inlining fallback: the default two-instruction always-inline ceiling is retained, one-caller helpers are admitted through four instructions, the flexible threshold is zero, partial inlining and loop admission are disabled, and larger helpers require the existing `trivial_shrinks` proof. A red-first public-dispatch boundary in `src/passes/inlining_test.mbt` requires both the fallback trace and actual call removal.

Native SHA-256 `04c07833321cb6b6013f3ae2cbba4dc692ea802ff6f5a04810b2640120768c10` shrinks all 105 `json-as` artifacts with no growth relative to the DAEO-only checkpoint: aggregate `20,699,654 -> 20,409,974` (`-289,680`), family totals naive `6,652,713`, SIMD `6,895,829`, SWAR `6,861,432`, and remaining verified-v131 gap `4,764,850` bytes / `30.46%`. Optimize/external validation and exact no-cache WIPC are `105/105` with zero failures/timeouts. Representative `fast-path-deserialize` is `460,488` bytes; pass-local fallback costs are about `724 ms` there and `459 ms` on `map`. The rebuilt `13,758,098`-byte debug artifact is optimized identically by native and self-optimized-Wasm to `5,009,594` bytes, SHA-256 `770b21daaff8821ced8be74e79957510e25777beb81d832c82e08d519f52c4b5`; this is `22,768` bytes smaller than the DAEO-only optimizer checkpoint. Full Moon is `10,354/10,354`, recursive spec is `284/64/220/0`, self-opt tests are `16/16`, and refreshed wasm-gc full validation plus native CI fuzz are green. The current dedicated `inlining-optimizing-all` refresh is exact at `10000/10000`, with zero mismatches or failures and Binaryen cache `9984/16`.

A retained 2026-08-12 suffix now reruns the existing bounded/defaultable/validated `coalesce-locals` policy after the guarded plain-inlining fallback, but only when helper deletion leaves fewer than 1,000 definitions. This deliberately excludes the self-optimized CLI's artifact-scale module while recovering local slots exposed by inlining in the 286..999-definition production class. A focused 286-definition public-pipeline regression fails without the suffix (`2` body locals remain) and requires all body-local declarations to disappear with it. The current 105-artifact corpus falls `20,409,974 -> 20,354,587` (`-55,387`): every artifact is smaller, none grow, family totals are naive `6,636,646`, SIMD `6,874,936`, and SWAR `6,843,005`, and the verified-v131 gap becomes `4,709,463` bytes / `30.10%`. Optimize/external validation and exact no-cache WIPC are both `105/105`; representative `fast-path-deserialize` is `459,627` bytes and `map` is `321,615` bytes. The self-optimized optimizer remains excluded from the suffix and grows only by the implementation cost relative to the preceding shared-preflight checkpoint; native/Wasm artifact optimization and runtime smoke remain separate required gates.

A five-instruction one-caller widening was rejected after full corpus measurement: it made 40 artifacts larger, improved only 2, left 63 unchanged, and grew aggregate output by 153 bytes. The four-instruction ceiling remains the measured profitability boundary. Broader large call/bulk-memory admission remains closed until profitability and cleanup are proved together, not from function-count reduction, validation, or direct-pass size alone.

## 2026-08-12 and 2026-08-13 implicit function-label repairs

The saved 285-definition broad-path fixtures with helper bodies containing `br`, nested `br`, or `return` previously aborted in the nested `precompute-propagate` prefix. Inlining itself had produced valid function-exit branches, represented in HOT as `HOT_IMPLICIT_FUNCTION_LABEL` (`-2`), but generic HOT control verification rejected that sentinel and CFG construction had no exit mapping for it. Verification now derives the implicit target arity from the function body result type. Normal branches resolve the sentinel to the normal exit; exceptional transfers such as delegate-to-caller and caller-targeting `try_table` catches resolve it to the distinct exceptional exit.

A 2026-08-13 runtime review found a separate direct-inliner wrong-code family: wrapper omission allowed copied implicit-function-label escapes to branch through caller control and skip caller-side effects. The shared depth-aware escape scan now covers returns, ordinary/table branches, all represented `br_on_*` and descriptor branch forms, plus `try_table` catch targets; single-instruction replacement unwrapping follows the same rule. The native CI runtime lane executes root/nested `br`, `br_if`, `br_table`, `br_on_null`, and `try_table catch_all` cases before and after plain inlining. These fixes do not widen the guarded medium-module profitability boundary.

This repair does not justify widening the 286-definition production guard. A fresh broad `fast-path-deserialize` probe validated structurally but grew `460,488 -> 475,735` bytes and aborted during exact WIPC execution. A touched-function-only `remove-unused-brs` suffix was also rejected: it changed none of the 105 corpus outputs and increased representative pass-local cost. The fallback thresholds remain unchanged; the later bounded post-fallback coalescing wave is independent cleanup and does not reopen broad optimizing inlining.

## 2026-08-25 runtime residual boundaries

InliningOptimizing was the final Winch owner after direct HOT guards: it inlined the two multivalue helpers in a function-exit `br_table` caller. It also moved a stack-carried local value across imported `wasmtime.gc` while inlining the bump-pointer equality helper, reducing 50 successful GC calls to one call plus `unreachable`. Caller-local admission now rejects multivalue function-exit `br_table`, caught `try_table`, and the exact `local.get; imported call; const/add/tee/get; defined call` carrier relation. Regressions are `remove-unused-brs-winch-issue-10613-multivalue.wasm` and `inlining-bump-ptr-stack-carried-call.wasm`. The current 10,000-case optimizing-inlining lane matches 10,000/10,000 with zero failures.

## Boundaries that do not reopen this pass

- legacy `try_delegate` representation;
- expression-level branch hints and code metadata;
- source-map offset repair;
- copied callee debug-name synthesis;
- speculative indirect/ref callee recovery;
- shared scheduler API consolidation under `[O4Z-NESTED]001`;
- raw output-shape differences without semantic, validation, size, or performance loss.

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md): upstream shared engine and suffix.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): code and test map.
- [`planning-partial-inlining-and-reruns.md`](./planning-partial-inlining-and-reruns.md): planner, roots, splitting, and reruns.
- [`wat-shapes.md`](./wat-shapes.md): representative shapes.
- [`starshine-strategy.md`](./starshine-strategy.md): local implementation summary.
- [`starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): signoff and reopening criteria.
- [`deferred-inl005-inl006-work.md`](./deferred-inl005-inl006-work.md): completed former deferrals and shared metadata boundaries.
