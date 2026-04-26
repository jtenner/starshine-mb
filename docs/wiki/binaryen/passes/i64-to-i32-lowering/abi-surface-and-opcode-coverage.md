---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md
  - ../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-helpers-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `i64-to-i32-lowering`: ABI surface and opcode coverage

This page exists because the pass is easy to mis-teach.

A reader can look at the name and assume any of these:

- it lowers **all** remaining `i64` code
- it is mostly about arithmetic
- it is mostly about memory
- it is a normal function-local optimizer

The reviewed Binaryen `version_129` source says something more precise:

- the pass rewrites **module ABI surface plus many expression families**
- some families are handled by explicit low/high-half wasm code
- some families are handled through wasm2js helper imports
- some families are only valid if earlier pipeline steps already simplified the harder cases away
- some families are still explicitly unsupported

So this page is the compact ledger for what the pass really covers.
For the current Starshine implementation status and future local landing map, see [`./starshine-strategy.md`](./starshine-strategy.md). For the staged implementation and validation ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## 1. ABI surface matrix

## 1.1 Defined globals

| Surface | What Binaryen does | Important boundary |
| --- | --- | --- |
| defined mutable/immutable `i64` global | rewrites original global to `i32`, adds sibling `<name>$hi` global, splits initializer | only handles constant or `global.get` initializers in the reviewed file |
| imported `i64` global | aborts with `TODO: imported i64 globals` | this is still unsupported in `version_129` |

## 1.2 Function params and locals

| Surface | What Binaryen does | Important boundary |
| --- | --- | --- |
| `i64` param | splits into adjacent low/high `i32` params | high slot is always `mappedIndex + 1` |
| `i64` local | splits into adjacent low/high `i32` locals | high slot gets a `$hi` suffix after `Names::ensureNames(oldFunc)` |
| non-`i64` local/param | remapped but not widened | still participates in the rebuilt local-index map |

## 1.3 Function results

| Surface | What Binaryen does | Important boundary |
| --- | --- | --- |
| direct function returning `i64` | rewrites visible result type to `i32`; stores high half to `INT64_TO_32_HIGH_BITS` | Binaryen does **not** use multivalue here |
| `return_call` / `return_call_indirect` producing `i64` | aborts | reviewed file still says this path is not implemented |

## 1.4 Call boundaries and heap-visible signatures

| Surface | What Binaryen does | Important boundary |
| --- | --- | --- |
| direct `call` with `i64` params/results | doubles `i64` args into low/high `i32` args; fetches result high half from helper global | imported direct callees are retargeted to `legalfunc$...`, assuming JS-interface legalization already ran |
| `call_indirect` with `i64` in signature | rewrites heap signature to split params and `i32` result | same `return_call` `i64`-result fatal boundary applies |
| `ref.func` whose heap signature mentions `i64` | rewrites visible heap signature to split params and `i32` result | this is part of ABI rewriting, not just callsite lowering |

## 1.5 Synthetic side channels

| Side channel | Why it exists |
| --- | --- |
| hidden temp-local out-param map | most lowered expressions visibly produce only the low half; high half is stored in a temp-local side channel |
| mutable global `INT64_TO_32_HIGH_BITS` | former `i64` function results need somewhere to put their high half |
| helper imports from `abi/js.h` | reinterpret and some atomic families cannot be expressed as pure pairwise wasm in the reviewed strategy |

## 2. Expression-family coverage matrix

## 2.1 Directly lowered ordinary expression families

These are families the pass rewrites directly in the AST using explicit low/high-half logic.

| Family | Reviewed status | Main rule |
| --- | --- | --- |
| `Const i64` | supported | low half becomes visible `i32.const`, high half becomes temp |
| `LocalGet` | supported | visible low local plus fetched high sibling |
| `LocalSet` / `LocalTee` | supported | visible low write plus explicit high write to adjacent slot |
| `GlobalGet` / `GlobalSet` on rewritten defined globals | supported | original name carries low half; `<name>$hi` carries high half |
| non-atomic `i64.load` | supported | visible low `i32.load`; high half from second load or sign/zero synthesis |
| non-atomic `i64.store` | supported when value has high-half out param | visible low `i32.store`; high half becomes second store for 8-byte width |
| `select` over lowered `i64` values | supported | one `select` for low half, one for high half, condition evaluated once |
| `drop` of lowered value | supported | consumes and frees hidden high-half temp |
| `return` of lowered value | supported | stores high half to helper global, returns low half |

## 2.2 Call-related families

| Family | Reviewed status | Main rule |
| --- | --- | --- |
| direct `call` | supported | widen args, narrow result type to `i32`, fetch high result from helper global |
| imported direct `call` | supported with prerequisite | retargets to `legalfunc$<target>` after ordinary call lowering |
| `call_indirect` | supported | rewrites signature and widened operand list |
| `ref.func` | supported | rewrites heap signature if params/results mention `i64` |

## 2.3 Unary opcode coverage

### Directly lowered unary families

| Unary op family | Reviewed status | Lowering style |
| --- | --- | --- |
| `i64.eqz` | supported | `i32.eqz(low | high)` style check |
| `i64.extend_s/i32`, `i64.extend_u/i32` | supported | visible low half plus sign/zero-derived high half |
| `i32.wrap_i64` | supported | keep low half, drop high half |
| `i64.extend8_s`, `i64.extend16_s`, `i64.extend32_s` | supported | visible low half plus sign-derived high half |
| `i64.trunc_*_f32/f64` | supported | explicit arithmetic lowering in reviewed file |
| `f32.convert_*_i64`, `f64.convert_*_i64` | supported | explicit arithmetic/helper-assisted lowering in reviewed file |
| `i64.clz` | supported | explicit low/high-aware lowering in reviewed file |

### Helper-backed unary families

| Unary op family | Reviewed status | Helper path |
| --- | --- | --- |
| `f64.reinterpret_i64` | supported | scratch-memory helpers from `abi/js.h` |
| `i64.reinterpret_f64` | supported | scratch-memory helpers from `abi/js.h` |

### Explicit unsupported / assumed-gone unary families

| Unary op family | Reviewed status | Source-backed note |
| --- | --- | --- |
| `i64.popcnt` | expected removed already | `WASM_UNREACHABLE("i64.popcnt should already be removed")` |
| `i64.ctz` | expected removed already | reviewed switch still routes it through the “should already be removed” family rather than a finished lowering path |

## 2.4 Binary opcode coverage

### Directly lowered binary families

| Binary op family | Reviewed status | Lowering style |
| --- | --- | --- |
| `i64.add` | supported | two-limb add with carry fixup |
| `i64.sub` | supported | two-limb subtract with borrow fixup |
| `i64.and`, `i64.or`, `i64.xor` | supported | apply op independently to low and high halves |
| `i64.shl`, `i64.shr_u`, `i64.shr_s` | supported | split `< 32` versus `>= 32` shift cases |
| `i64.eq`, `i64.ne` | supported | compare both halves |
| signed/unsigned order comparisons | supported | compare high halves first, then low halves as tie-breakers |

### Explicit unsupported / assumed-gone binary families

| Binary op family | Reviewed status | Source-backed note |
| --- | --- | --- |
| `i64.mul` | expected removed already | `WASM_UNREACHABLE("should have been removed by now")` |
| `i64.div_s`, `i64.div_u` | expected removed already | same source-backed boundary |
| `i64.rem_s`, `i64.rem_u` | expected removed already | same source-backed boundary |
| `i64.rotl`, `i64.rotr` | expected removed already | same source-backed boundary |

## 2.5 Atomic and memory-specific families

| Family | Reviewed status | Main rule |
| --- | --- | --- |
| non-atomic `i64.load` / `i64.store` | supported | split into low/high `i32` traffic with single-evaluation pointer temp |
| atomic `i64.load` / `i64.store` through ordinary visitors | unsupported | ordinary visitors assert these are not implemented directly |
| `AtomicRMW` returning `i64` | supported via helpers | calls `ATOMIC_RMW_I64` and `GET_STASHED_BITS` |
| `AtomicWait` with `i64` timeout | supported via helper | calls `ATOMIC_WAIT_I32` with low/high timeout pieces |
| `AtomicCmpxchg` on `i64` | unsupported | explicit assert in reviewed file |

## 2.6 Structural fallback families

| Family | Reviewed status | Main rule |
| --- | --- | --- |
| unreachable subtrees whose children execute unconditionally | supported conservatively | `handleUnreachable(...)` keeps child evaluation and repairs low/high state |
| `if`-like shapes where children are not unconditionally executed | intentionally excluded from fallback | reviewed comment says the helper is not valid there |

## 3. Pipeline assumptions that are part of the contract

## 3.1 Flatness

The pass begins each function with:

- `Flat::verifyFlatness(func)`

So a faithful port must either:

- require equivalent flat input,
- or explicitly document a different local policy.

## 3.2 Earlier cleanup / legalization

The reviewed file itself makes these scheduler assumptions visible:

- imported direct-call retargeting assumes `legalize-js-interface` already ran
- several harder i64 ops are expected to be gone already
- helper-backed reinterpret and atomic families assume wasm2js helpers can be materialized

So this pass is not the whole legalization story by itself.

## 4. What the official lit file proves most clearly

`flatten_i64-to-i32-lowering.wast` is useful not only for before/after shapes, but also for identifying the pass’s real surface area.
It visibly proves:

- `$hi` locals are real emitted output
- `i64toi32_i32$HIGH_BITS` is a real emitted helper global
- low/high temporary locals are real emitted output
- successful rewrites are block-heavy and temp-heavy by design
- the pass is expected to run after `--flatten`

## 5. Beginner summary

If you need one compact sentence, use this:

> Binaryen `i64-to-i32-lowering` is a flat-input whole-module ABI-and-expression rewrite pass: it directly lowers many i64 families into paired i32 logic, lowers some others through wasm2js helpers, and still explicitly rejects or assumes-away several harder shapes.

For Starshine, this matrix should be consumed as a staged checklist, not a single-patch promise: the port-readiness bridge intentionally starts with classification and scalar type/local splitting before calls, globals, returns, memory, helpers, or atomics.

## Sources

- [`../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md)
- [`../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md`](../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
