---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/research/0445-2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./state-machine-memory-and-eh-boundaries.md
  - ./starshine-strategy.md
---

# `asyncify` transformed module and instruction shapes

This page teaches the important shapes `asyncify` transforms.
The snippets are schematic WAT, not byte-for-byte Binaryen output.
Use the official `test/lit/passes/asyncify.wast` file for exact expected text.

## Shape 1: direct async import root

### Before

```wat
(module
  (import "env" "sleep" (func $sleep))
  (func $main
    (call $sleep)
    (call $after)))
```

### After, conceptually

```wat
(module
  (global $__asyncify_state (mut i32) (i32.const 0))
  (global $__asyncify_data (mut i32) (i32.const 0))
  (memory ...)
  (export "asyncify_start_unwind" (func $asyncify_start_unwind))
  (export "asyncify_stop_unwind" (func $asyncify_stop_unwind))
  (export "asyncify_start_rewind" (func $asyncify_start_rewind))
  (export "asyncify_stop_rewind" (func $asyncify_stop_rewind))
  (export "asyncify_get_state" (func $asyncify_get_state))

  (func $main
    ;; normal path calls $sleep
    ;; unwind path breaks out after $sleep starts unwinding
    ;; rewind path skips until this call frame is reached
    ...))
```

The exact emitted WAT is more verbose, but the invariant is stable: the call site becomes state-machine-aware and the module gains the runtime API surface.

## Shape 2: transitive callers

### Before

```wat
(func $leaf
  (call $sleep))

(func $mid
  (call $leaf))

(func $top
  (call $mid))
```

### After

`$leaf`, `$mid`, and `$top` are all candidates for instrumentation because each can be on the stack when `$sleep` starts unwinding.
A caller that cannot reach an async root should not be instrumented.

The caveat is user configuration:

- an add list can force extra functions into the set;
- a remove list can prune functions;
- an only list can restrict the final set.

## Shape 3: function outside the async closure

### Before

```wat
(func $pure_math (param $x i32) (result i32)
  (i32.add (local.get $x) (i32.const 1)))
```

### After

```wat
(func $pure_math (param $x i32) (result i32)
  (i32.add (local.get $x) (i32.const 1)))
```

If no async-capable import, indirect-call edge, or forced-list entry reaches this function, it should not gain Asyncify state checks.
This no-op family is important because Asyncify overhead is one of the pass's main user-visible costs.

## Shape 4: local live across an async call

### Before

```wat
(func $f (param $x i32) (result i32)
  (local $tmp i32)
  (local.set $tmp (i32.add (local.get $x) (i32.const 1)))
  (call $sleep)
  (i32.add (local.get $tmp) (i32.const 10)))
```

### After, conceptually

```wat
(func $f (param $x i32) (result i32)
  (local $tmp i32)
  (local.set $tmp (i32.add (local.get $x) (i32.const 1)))
  ;; before/while unwinding: store $tmp into the Asyncify data area
  ;; during rewind: load $tmp back from the Asyncify data area
  ;; normal path: preserve ordinary call ordering
  (call $sleep)
  (i32.add (local.get $tmp) (i32.const 10)))
```

The key transformed shape is memory traffic around the relevant call, not a change to the user's source-level variable.
Only locals live across the call need save/restore traffic.

## Shape 5: indirect call

### Before

```wat
(table funcref (elem $maybe_async))
(type $sig (func))
(func $caller (param $idx i32)
  (call_indirect (type $sig) (local.get $idx)))
```

### After

Binaryen must assume the indirect call may reach an async-capable target unless configuration proves otherwise.
That can add call-index bookkeeping plus state checks around the `call_indirect`.

If indirect calls are ignored by configuration, this shape becomes a deliberate user-responsibility boundary: the pass can be smaller, but correctness depends on the user's proof that ignored indirect calls cannot unwind.

## Shape 6: module without memory

### Before

```wat
(module
  (import "env" "sleep" (func $sleep))
  (func $main (call $sleep)))
```

### After

The transformed module needs memory-backed storage for Asyncify data.
Binaryen can add an Asyncify memory when the module lacks one or when configured for a secondary memory.

This is why a future Starshine port is a module pass, not only a function-body pass.
It may need to update memory declarations, imports/exports, and validation environments.

## Shape 7: memory64 pointer width

### Before

```wat
(memory i64 1)
(func $main (call $sleep))
```

### After

Asyncify stack/data pointer traffic must use `i64` addresses.
For memory32, the same conceptual traffic uses `i32` addresses.
A port must not hard-code `i32` just because most older examples use memory32.

## Shape 8: tail-call boundary

### Before

```wat
(func $f
  (return_call $sleep))
```

### After

The reviewed Binaryen source rejects tail calls in the Asyncify path.
A future Starshine implementation should make that unsupported family explicit rather than silently lowering it as if it were an ordinary call.

## Shape 9: exception/catch unwind option boundary

### Before

```wat
(func $f
  (try
    (do
      (call $may_unwind))
    (catch_all
      ;; cleanup or fallback path
      ...)))
```

### After, conceptually

Exception/catch paths are not just generic EH syntax to validate after the pass.
The reviewed Binaryen source and lit surface expose option-sensitive Asyncify behavior for unwinding from catch-like paths.

A future Starshine implementation has two honest choices for an initial subset:

- support and test the same catch-unwind behavior; or
- reject EH/catch input under `asyncify` with a clear diagnostic until that family is ported.

It should not silently instrument only ordinary calls and leave catch paths half-modeled.

## Shape 10: runtime API exports

The final module must expose runtime-control functions.
These are not arbitrary helper names; they are the host/runtime contract:

- `asyncify_start_unwind`
- `asyncify_stop_unwind`
- `asyncify_start_rewind`
- `asyncify_stop_rewind`
- `asyncify_get_state`

A compiler-only fixture can verify the exports and helper bodies exist, but a complete validation story should also run a host-level pause/resume test.

## Caveats

- These shapes intentionally omit many helper locals, blocks, labels, and stack-pointer updates that Binaryen emits.
- `mod-asyncify-*` helper passes can simplify known state checks after Asyncify, but they are not the main transform covered here.
- The detailed state-machine, memory, indirect-call, EH, and tail-call boundaries are collected in [`state-machine-memory-and-eh-boundaries.md`](state-machine-memory-and-eh-boundaries.md).
- Emscripten driver settings and JavaScript runtime glue are part of the user-facing feature, but this page only describes the Binaryen pass shape.

## Sources

- [`../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md`](../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md)
- Binaryen `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Asyncify.cpp>
- Binaryen current `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
- Binaryen `asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/asyncify.wast>
- Binaryen current `asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
- Emscripten Asyncify docs: <https://emscripten.org/docs/porting/asyncify.html>
