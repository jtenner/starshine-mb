---
kind: raw-source
status: current
last_reviewed: 2026-07-10
sources:
  - https://webassembly.github.io/spec/core/valid/instructions.html#constant-expressions
  - https://webassembly.github.io/spec/core/valid/modules.html
  - https://webassembly.github.io/spec/core/appendix/index-instructions.html
  - https://www.w3.org/TR/wasm-core-3/
  - ../../../../src/validate/validate.mbt
  - ../../../../src/validate/gen_valid.mbt
related:
  - ../../validate/constant-expressions.md
  - ../../wast/gc-aggregate-instruction-authoring.md
  - ../../wast/data-segment-authoring.md
  - ../../wasm-more-array-constructors-boundary.md
  - ../../validate/local-spec-divergence-ledger.md
  - ../../fuzzing/generator-coverage-ledger.md
---

# Constant-Expression Array-Constructor Reconciliation (2026-07-10)

## Why this note exists

The live validator code and the 2026-06-07 test/log record show that Starshine now accepts the three Core GC array constructors permitted in constant expressions: `array.new`, `array.new_default`, and `array.new_fixed`. Several living pages and older immutable raw captures still described the pre-2026-06-07 state, where those instructions were rejected by the local constant-instruction gate.

This capture reconciles that contradiction without rewriting historical raw material. The older 2026-05-20 and 2026-06-04 raw notes are accurate records of the code at their capture points; their claim about Starshine rejecting the three constructors is superseded by this later repository evidence.

## Primary-source recheck

Checked on 2026-07-10:

- The live official Core validation page still lists `array.new`, `array.new_default`, and `array.new_fixed` among the instructions allowed in constant expressions. It continues to require ordinary expression validation after the constant-instruction predicate and warns that the list can grow in later versions.
- The live official module-validation page still applies constant-expression validation to global initializers, table initializers, active data/element offsets, and element expression payloads. Its table-initializer context remains narrower for `global.get`: imported globals only.
- The published WebAssembly Core 3.0 Recommendation is a release snapshot rather than a replacement for the live specification source. No source evidence found here changes the Core status of the three array constructors.

## Starshine source reconciliation

`validate_const_instr(...)` in [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) now has a dedicated branch:

```text
ArrayNew(type_idx)
| ArrayNewDefault(type_idx)
| ArrayNewFixed(type_idx, _)
  => env.resolve_array_field(type_idx)
```

Thus the local instruction gate accepts exactly these three forms when their type index resolves to an array. `validate_const_expr(...)` then typechecks their operands in the normal empty-local/label/return constant-expression context, requires a reachable state with exactly one result, and matches that result against the owning initializer context's expected type.

The focused validator tests in the same file prove accepted core-AST shapes for:

- `array.new_fixed` in a table initializer;
- `array.new_default` in an element expression payload;
- `array.new` in an element expression payload; and
- a zero-length `v128` `array.new_fixed` table initializer.

`src/validate/gen_valid.mbt` and its coverage tests additionally place the array-constructor observations in the existing `GcConstructorConstExprOp` family. These are core-model/validator/generator facts, not evidence that Starshine's high-level WAST parser accepts `array.*` instruction text.

## Durable conclusions

1. **Starshine now matches the Core constant-expression subset for `array.new`, `array.new_default`, and `array.new_fixed`.** The previous live-page claim that all array constructors were a local initializer gap is stale.
2. **The change is narrow.** `array.new_data`, `array.new_elem`, `array.init_data`, and `array.init_elem` are not in the official constant-expression predicate and are not accepted by Starshine's local constant-instruction gate. Their data/element-index and data-count rules remain separate ordinary-instruction concerns.
3. **WAST text remains a separate gap.** The local core/binary/validator/generator support for the three constructors does not make `(array.new ...)` a currently supported high-level Starshine WAST fixture spelling.
4. **More Array Constructors remains unrelated.** Active-proposal `array.new_array`, `array.new_memory`, and `array.new_table` are different instructions and remain unsupported. The Core array-constructor correction must not be read as proposal support.
5. **Historical raw captures are preserved.** Link current readers to this note and the living pages rather than editing earlier source manifests; this is supersession, not a provenance rewrite.

## Links checked

- Official Core constant-expression validation: <https://webassembly.github.io/spec/core/valid/instructions.html#constant-expressions>
- Official Core module validation: <https://webassembly.github.io/spec/core/valid/modules.html>
- Official Core instruction index: <https://webassembly.github.io/spec/core/appendix/index-instructions.html>
- Published Core 3.0 Recommendation: <https://www.w3.org/TR/wasm-core-3/>
- Starshine gate/tests: [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt)
- Starshine generation/reporting: [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
- Historical implementation record: [`../../log.md`](../../log.md) (`2026-06-07`, `validate/gen-valid | GC array constructors in constant expressions`)
