---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0845-2026-06-20-heap-store-optimization-br-table-swap-wrappers.md
  - ./0846-2026-06-20-heap-store-optimization-br-table-table-side-stores.md
  - ./0862-2026-06-20-heap-store-optimization-br-table-local-escape.md
  - ./0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO `br_table` branch/wrapper micro-audit

## Question

Can one still-open HSO-F/G branch/control family be closed narrowly by mapping the source-backed `br_table` evidence to focused Starshine tests, without hiding broader branch/catch or `trySwap(...)` drift?

## Scope audited

This note covers only explicit `br_table` shapes already probed against local Binaryen `version_130`:

1. `br_table` branch-valued stores inside a block that can escape the constructor `local.set`.
2. The disappearing-local-read sibling where Starshine applies the one-bad-get reasoning but Binaryen keeps the stores.
3. `br_table`-ending wrappers around cross-family ordinary stores that Binaryen crosses.
4. `br_table`-ending wrappers around same-effect-family bulk roots or side-effecting growth operands that Binaryen does not cross.

This does **not** close arbitrary in-function branch/catch control, descriptor branch/control expressions, exact descriptor `ref.cast`, general `try_table` catchability, or non-`br_table` wrapper/effect families.

## Source-backed behavior map

| Family | Binaryen `version_130` evidence | Starshine focused tests | Status |
| --- | --- | --- | --- |
| Escaping `br_table` branch value with later target-local observation | `0862` observed Binaryen preserving both `struct.set` roots. | `heap-store-optimization keeps br_table branch values inside escaping local blocks` | Parity covered: Starshine preserves `struct.set`. |
| `br_table` branch value when the later target-local read disappears | `0862` observed Binaryen preserving both `struct.set` roots, but also proved Starshine's fold as a narrow one-bad-get extension. | `heap-store-optimization folds br_table branch values when later local reads disappear` | Narrow documented Starshine win, not broad drift. Reopen if a later target-local read, non-local side effect reordering, or validation issue appears. |
| `memory.size` constructor operand crossing `br_table`-wrapped cross-family `table.set` | `0845` observed Binaryen preserving `table.set`/`br_table` and folding the later field into `struct.new`. | `heap-store-optimization folds memory.size constructors across br_table-wrapped table stores` | Parity covered. |
| `memory.size` constructor operand crossing `br_table`-wrapped same-resource `memory.fill` | `0845` observed Binaryen preserving `memory.fill`, `br_table`, and `struct.set`. | `heap-store-optimization keeps memory.size constructors before br_table-wrapped memory.fill` | Parity covered. |
| `table.size` constructor operand crossing `br_table`-wrapped cross-family `i32.store` | `0846` observed Binaryen preserving `i32.store`/`br_table` and folding the later field into `struct.new`. | `heap-store-optimization folds table.size constructors across br_table-wrapped memory stores` | Parity covered. |
| `table.grow` constructor operand crossing `br_table`-wrapped cross-family `i32.store` | `0846` observed Binaryen preserving `table.grow`, `i32.store`, `br_table`, and `struct.set`. | `heap-store-optimization keeps table-growing constructors before br_table-wrapped memory stores` | Parity covered. |

## Classification

The explicit `br_table` branch/wrapper slice is narrow-closed for HSO-F/G:

- parity positives and negatives are backed by Binaryen `version_130` probes from `0845`, `0846`, and `0862`;
- Starshine has focused tests for each listed family;
- the only Binaryen-vs-Starshine output-shape/transform difference in this slice is the `0862` disappearing-local-read `br_table` fold, already documented with semantic reasoning and reopening criteria;
- no broad descriptor/control, catchability, `try_table`, or arbitrary wrapper claim is made.

This reduces the HSO-F/G open surface by one audited branch/wrapper family, but HSO-F/G remain open for broader in-function branch/catch negatives, descriptor branch/control shapes, result-wrapper/tail-call families not already source-mapped, and any unreviewed `trySwap(...)` operand/effect families.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `416/416` tests passed.
