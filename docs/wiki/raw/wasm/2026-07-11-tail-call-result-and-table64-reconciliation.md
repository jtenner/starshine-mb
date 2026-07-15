# Tail-Call Result-Matching and Table64 Reconciliation

- Capture date: 2026-07-11
- Source family: current official WebAssembly 3.0 release/editorial specification plus Starshine validator source
- Status: immutable primary-source bridge for [`../../wast/tail-call-authoring.md`](../../wast/tail-call-authoring.md), [`../../validate/local-spec-divergence-ledger.md`](../../validate/local-spec-divergence-ledger.md), and [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md)

## Primary sources checked

1. WebAssembly Specification, [Release 3.0 PDF](https://webassembly.github.io/spec/core/_download/WebAssembly.pdf), retrieved 2026-07-11 — release date `2026-04-09`. Its tail-call validation rules use result-type matching (`t2* <= t2'*`), its `return_call_indirect` rule consumes the selected table address type `at`, and its binary table records `0x12`, `0x13`, and `0x15` with the type immediate before the table immediate for `return_call_indirect`.
2. WebAssembly Core Specification, [editor's draft](https://webassembly.github.io/spec/core/bikeshed/), retrieved 2026-07-11 — independently exposes the same three tail-call rules, result matching, selected-table address type, and stack-polymorphic continuation.
3. WebAssembly Core Specification, [text instructions](https://webassembly.github.io/spec/core/text/instructions.html), retrieved 2026-07-11 — confirms the omitted-table abbreviation for `return_call_indirect` means table `0`.
4. Starshine [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt), reviewed 2026-07-11 — `require_return_results(...)` uses `equals(results, rt)` and `typecheck_return_call_indirect(...)` pops `i32` regardless of the selected table address type.

## Reconciled contract

- The portable tail-call result rule is **matching**, not exact equality: the callee result sequence must be a subtype of the enclosing function's result sequence. This matters for reference-result nullability and heap-type subtyping.
- `return_call_indirect` consumes the selected table's address type. It is `i32` for ordinary tables and `i64` for table64; table64 is not a special tail-call exception.
- All three forms remain stack-polymorphic after their checks. Binary immediate order remains type index then table index for `return_call_indirect`.

### Concrete portable-versus-local fixture shape

A non-null result can match a nullable enclosing result:

```wasm
(type $s (struct))
(func $callee (result (ref $s))
  (struct.new $s))
(func (result (ref null $s))
  (return_call $callee))
```

The current Core rule admits this result-subtyping direction. Current Starshine rejects it at `require_return_results(...)` because the two `ValType` arrays are not equal. This is a validator-widening gap, not a reason to teach exact equality as portable Wasm.

A table64 `return_call_indirect` likewise needs an `i64` table-element index under the Core rule. Current high-level Starshine WAST cannot establish that positive by itself because table64 text support is narrower, and current typechecking still pops `i32`; use a direct core/binary validator fixture for a future widening slice.

## Supersession and limits

- This capture supersedes the **incomplete result-matching and table64 wording** in the removed `2026-07-10-tail-call-core3-component-date-recheck.md` capture. That earlier capture remains useful historical provenance for its local WAST/core/binary/HOT inventory and component-date review.
- The current sources agree on the result/table rules, so this is not an upstream contradiction. The discrepancy was in the living wiki's lack of a validator-divergence ledger row and insufficiently explicit portable-versus-local wording.
- This note does not implement the widening, establish high-level table64 WAST support, or prove any optimizer transform correct. A future behavior change needs focused validator, WAST/core/binary, generator, and pass-remap tests as applicable.
