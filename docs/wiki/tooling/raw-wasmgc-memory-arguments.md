---
kind: tooling
status: supported
last_reviewed: 2026-09-05
---

# Raw WasmGC FFI memory arguments

[`ffi_bridge::memory_argument(align, offset)`](../../../src/ffi_bridge/memory_builtins.mbt)
constructs a [`MemArg`](../../../src/lib/types.mbt) for the default memory. The
alignment is an unsigned exponent and the byte offset retains all 64 bits.
The provider constructs the optional memory field itself; an FFI consumer must
not guess the numeric representation of MoonBit's `None` value.

This is an IR metadata constructor, not a runtime load/store or a compiler
intrinsic. It returns the provider's exact `MemArg` carrier. Consumers can pass
that value to scalar or SIMD instruction constructors. Opcode-specific alignment
and memory rules remain the responsibility of instruction validation.

The focused test compares complete arguments for alignment/offset pairs
`(0, 0)` and `(3, 4294967297)`, including the absent explicit memory index. The
second offset detects accidental 32-bit truncation. The private zero-offset
helper delegates to this constructor, preserving existing runtime builders.

The public interface in [`ffi_bridge/pkg.generated.mbti`](../../../src/ffi_bridge/pkg.generated.mbti)
feeds [`FFI generation`](../../../scripts/lib/ffi-task.ts). `bun ffi build` refreshes
the raw export package and provider artifact; consumers must regenerate their
typed declarations and ABI fingerprints from that artifact.
