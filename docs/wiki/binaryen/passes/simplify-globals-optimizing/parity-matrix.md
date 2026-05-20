---
kind: concept
status: working
last_reviewed: 2026-05-20
sources:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../../../raw/research/0573-2026-05-19-sgo-v010-signoff.md
  - ../../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../../../../src/passes/simplify_globals_optimizing_test.mbt
related:
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
---

# `simplify-globals-optimizing` parity matrix

This page separates two claims that must not be conflated:

- **v0.1.0 supported-surface signoff:** [`0573`](../../../raw/research/0573-2026-05-19-sgo-v010-signoff.md) remains valid for the accepted direct-pass / nested-runtime / late-tail scheduling surface.
- **Full Binaryen `SimplifyGlobals.cpp` breadth:** still incomplete. `[SGO]003` is active again because the product goal changed toward broad Binaryen coverage, not because the earlier signoff was wrong.

Status labels:

- **implemented**: Starshine has focused tests and code for the family.
- **partially implemented**: Starshine covers useful subfamilies but not the complete Binaryen behavior.
- **missing**: source-backed Binaryen family has no local implementation yet.
- **intentionally conservative**: Starshine preserves shape for safety/type/performance reasons pending a later proof.
- **unknown / needs fixture**: source suggests breadth, but Starshine needs a local reduced fixture or Binaryen probe before coding.

## Matrix

| Binaryen SGO family | Current Starshine status | Evidence / next action |
| --- | --- | --- |
| Module-wide global traffic facts | **partially implemented** | `sgo_collect_global_infos(...)` tracks imports, exports, reads, writes, table/global/elem/data/code references. Binaryen's `nonInitWritten` and `readOnlyToWrite` are modeled by separate local flag passes rather than a single faithful fact table. |
| Practical immutability / private never-written globals | **implemented** | Private mutable globals with no writes, or removable writes, become immutable; covered by focused SGO tests. |
| Single-use global initializer folding | **implemented for global-initializer uses** | Multi-instruction initializer folding into later globals is covered; function-use, multi-use, import/export boundaries stay conservative. |
| Same-as-init write removal | **partially implemented** | Direct literal, `ref.null`, `ref.func`, and several canonicalized alias/init cases are covered, including one-run/two-run guardrails. Broader `Properties::getLiterals` expression-equivalence remains open. |
| Dead or redundant `global.set` rewrite to `drop(value)` | **implemented for current facts** | Never-read, same-as-init, and supported read-only-to-write writes are rewritten as `drop`, preserving operand evaluation. Broader Binaryen fact breadth can expose more cases. |
| `read-only-to-write` | **partially implemented** | Starshine covers direct, `eqz`, compare-const, many pure-condition, pure `select` self-guards with the global in any select operand, block-yielded, transparent, nested, and exact `if return; set` forms. As of 2026-05-20 it also has a conservative stack/value-flow scanner for source-backed side-effecting safe conditions where independent `local.tee` / `i32.load` operands are preserved and the actual `global.get` flows through non-trapping pure ops, `select`, and `i32.eqz` to the final branch, plus a narrow nested-`if (result i32)` arm-flow positive with an independent zero-operand call condition. Full Binaryen `FlowScanner` behavior remains incomplete. |
| Side-effecting-but-safe condition value-flow cases | **partially implemented** | First slices landed for official-style `local.tee` / `i32.load` / `global.get + const` / `select` / `i32.eqz` positives plus extra pure-op chains between the global-derived value and final branch, and the lit-style nested-if arm-flow case where the global is not the nested condition. Guardrails keep trapping loads whose address is global-derived, tainted `local.tee` / `drop`, multiple same-global reads in one condition, and nested conditions steered by the global. Remaining side-effecting lit families need separate fixtures and broader value-flow accounting. |
| Immutable copy-chain canonicalization | **implemented for exact type** | Exact-type immutable ancestor rewrites are covered in globals and function bodies. Subtyping/refinalization-sensitive copy-chain widening is intentionally not implemented. |
| Startup propagation into later globals / element offsets / data offsets / table initializers | **partially implemented** | Supported constants are propagated into later global initializers, table initializers, active elem offsets, and data offsets. Reference-typed element item expressions are intentionally preserved until exact type/refinalization safety is proven. |
| Runtime linear-trace propagation | **partially implemented** | Straight-line, top-level noise, adjacent/nested plain blocks, no-else and then-body shapes, imported/exported same-trace writes, and reference/null facts are covered with call/control/write barriers. Broader `ConstantGlobalApplier` adjacency remains open. |
| Call/control/write barriers | **implemented for current runtime model** | Calls, loops, branches, returns, throws, `try_table`, else joins, post-if joins, and non-constant writes to the same tracked global clear or block facts in tests. Needs comparison against every Binaryen `LinearExecutionWalker` corner before full parity. |
| Reference typed replacements | **partially implemented** | Function-body `ref.null`, externref-null, and `ref.func` replacements are covered; element item expressions remain conservative. |
| GC/refinalization-sensitive replacements | **intentionally conservative / partial** | Some function-body replacements validate through the normal pipeline. Broader type-changing replacement/refinalization surfaces, especially around typed elements or more precise refs, remain open. |
| Typed element item-expression preservation | **intentionally conservative** | Starshine keeps reference `global.get`s in typed element item expressions to avoid invalid type/refinalization drift; this is a known difference from broader Binaryen replacement surfaces. |
| Optimizing wrapper touched-function tracking | **implemented for current scheduler** | Code rewrites mark touched functions; startup-only rewrites do not. Nested cleanup is function-filtered. |
| Nested default cleanup sequence | **partially implemented / artifact-tuned** | Starshine uses an accepted pruned nested list without `precompute-propagate`; Binaryen runs the full default function optimization pipeline per changed function. Exact scheduler parity remains `[SGO]004`, not `[SGO]003`. |
| Plain `simplify-globals` / `propagate-globals-globally` shared-engine relationship | **missing as a shared local engine** | `simplify-globals-optimizing` owns the current active implementation. Plain `simplify-globals` and `propagate-globals-globally` remain boundary-only; a future shared substrate should expose the same core with variant-specific wrappers. |

## 2026-05-20 implementation slices

Target: **safe `select`-mediated `read-only-to-write` value-flow**, narrowed to source/probe-backed Binaryen-shaped positives.

Safety rule for the landed subset:

- accept pure `select` self-guard stack shapes where two operands are constants and the `global.get $g` appears as the select condition, first selected value, or second selected value before an outer no-else same-global constant `global.set`,
- accept side-effecting stack shapes where independent `local.tee` / `i32.load` operands plus a single actual `global.get $g` flow through supported non-trapping pure ops, `select`, optional `i32.eqz`, and finally an outer no-else same-global constant `global.set`,
- support the global-derived value as the `select` condition input, the first selected value input, or the second selected value input, including extra pure operators such as `i32.xor` after `global.get $g; const; i32.add`,
- preserve independent `local.tee` and `i32.load` effects while removing only fake global state; later nested cleanup may simplify pure `select` / `i32.eqz` residue when the global replacement makes it constant,
- require the outer body to be the already-supported same-global constant `global.set`,
- preserve negatives where `global.get $g` feeds a trapping `i32.load`, escapes through `local.tee` / `drop`, appears multiple times in the same condition, or otherwise reaches a non-condition consumer.

Follow-up in the same slice also accepts the source-backed nested-if arm-flow positive:

- `call $foo; if (result i32) ... else (global.get $g) end; if (then global.set $g const)`, where the zero-operand call may have effects but the candidate global does not steer it,
- preserve the neighboring negative where `global.get $g` is the nested `if` condition and therefore can decide whether the call runs.

Remaining value-flow work should add one Binaryen lit shape at a time with guardrail negatives for broader nested effectful control, wrong target global, additional body effects, non-branch consumers, calls with operands, broader trapping/effectful operations, and the recursive nested-pattern carveout.
