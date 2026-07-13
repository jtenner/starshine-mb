---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-remove-imports-current-main-recheck.md
  - ../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/lib/module.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./direct-call-stubbing-and-element-retention.md
  - ../../../binary/function-import-export-and-code-sections.md
  - ../../../validation/moonbit-prove-strategy.md
---

# `remove-imports`: Implementation Structure and Test Map

## Upstream Owner Map

The reviewed Binaryen implementation is intentionally compact. Its durable
source map is refreshed by the [2026-07-11 current-main recheck](../../../raw/binaryen/2026-07-11-remove-imports-current-main-recheck.md) and recorded in detail by the [2026-07-10 source read](../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md):

| Upstream location | Responsibility | What it does **not** prove |
| --- | --- | --- |
| `src/passes/RemoveImports.cpp` | Owns the transform. Its direct-call visitor stubs calls to imported functions; its module visitor decides which imported functions to delete. | A general import-section filter, host-effect equivalence, or a default optimization policy. |
| `src/ir/element-utils.h` | Supplies `ElementUtils::iterAllElementFunctionNames`, the retention source for imported function declarations referenced by element lists. | Whole-module liveness for every possible `FuncIdx` carrier. |
| `src/passes/pass.cpp` | Registers the public `remove-imports` spelling with no reviewed user argument; the reviewed default optimization builders do not schedule it. | Starshine registry support, ordinary default-optimization use, or compare-harness admission. |
| `src/ir/module-utils.h` | Was checked specifically because an earlier description hypothesized a helper-based removal API. The reviewed source has no `ModuleUtils::removeImports(...)` delegation. | Ownership of the pass rewrite. |

The source read did not identify a dedicated `remove-imports` lit fixture.
That is an evidence limit, not permission to invent expected behavior from the
pass name. Until an authoritative fixture is found, source-level behavior
claims should cite the owner plus element helper and stay narrow.

## Local Representation Map

Starshine has the pieces a future module rewrite would need, but no local
`remove-imports` pass. The relevant code is distributed because the rewrite
would cross several module layers:

| Local location | Existing responsibility | Future-port implication |
| --- | --- | --- |
| [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) | Defines `Import`, `ImportSec`, `ExternType`, `ExternIdx`, `FuncIdx`, `Instruction::RefFunc`, `ExportSec`, and `FuncAnnotationSec`. | Filtering one imported function is a cross-section index rewrite, not an edit to one array alone. |
| [`src/lib/module.mbt`](../../../../../src/lib/module.mbt) | Splits imports by external kind for module debug context and computes the imported-function prefix used to render absolute function indices. | Deleting an imported function shifts the absolute indices of later imports and every defined function. |
| [`src/validate/validate.mbt`](../../../../../src/validate/validate.mbt) | Extends function index space while validating `ImportSec`, records the imported-function count before code validation, validates element values, start/export references, `ref.func` declarations, and name-section function keys. | Validation is the post-rewrite safety net; it does not decide whether deleting host effects is policy-correct. |
| [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt) | Allocates import and definition function indices in one source-order namespace, lowers element `ref.func` payloads, and writes function annotations. | WAST roundtrips can expose index-repair bugs across imports, elements, exports, and annotations. |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | Owns the active pass registry. It has no `remove-imports` entry. | A local feature needs an explicit registry/preset policy; representation alone is not pass support. |
| [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) | Owns the comparison-harness pass allowlist. It has no `remove-imports` admission. | Do not run or report a `compare-pass` command until a supported transform and a host-stubbing-aware generator exist. |

The cross-section carrier inventory is maintained in
[`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md#pass-rewrite-checklist).
It is the starting checklist for a Starshine port; the upstream element helper
is not a substitute for it.

## A Safe Porting Decomposition

A future implementation should make each proof boundary observable:

```text
collect imported functions and direct call sites
        │
        ├── policy says calls/results are disposable? ── no ──> leave unchanged
        │ yes
        ▼
rewrite authorized direct calls to nop/default literal
        │
        ▼
collect every local FuncIdx carrier and element-table retention fact
        │
        ▼
remove only authorized function imports and remap all shifted indices
        │
        ▼
encode + validate + roundtrip + focused host-policy tests
```

This ordering is deliberately more explicit than “walk calls, remove imports.”
It separates the non-semantic stack repair (`nop` or default literal), the
embedding-specific permission to erase a host interaction, and the mechanical
index rewrite.

## Test Evidence Map

Because upstream currently supplies no identified dedicated lit fixture and
Starshine supplies no pass, tests should be designed from the owner contract
rather than copied from a nonexistent `remove-imports.wast` file.

| Test layer | Minimum case | Property being proved |
| --- | --- | --- |
| Unit: call rewrite | Imported no-result direct call; imported value-result direct call | Stack/type repair shape under an explicit stubbing policy. |
| Unit: element retention | An imported function named in an active or declarative element list | Declaration retention is independent from direct-call stubbing. |
| Unit: non-function scope | Imported memory/table/global/tag | The pass never broadens from function imports without a new contract. |
| Module rewrite | Multiple imported functions followed by definitions | Every absolute function-index carrier is remapped after prefix deletion. |
| Metadata/references | `ref.func`, start, export, name, and function-annotation carriers | Each carrier is preserved, rewritten, or deliberately rejected—never silently stale. |
| WAST/binary/validator | Lower, encode, decode, and validate before/after | Local source syntax and binary representation agree after the index change. |
| Host-policy negative | Effectful or result-observed import without authorization | Validation alone cannot enable a semantic host-call deletion. |
| Differential lane | Dedicated generated/stubbed corpus after registry admission | Binaryen comparison is meaningful only for inputs whose host behavior is intentionally abstracted. |

When implementation begins, run the repository's validation/proof workflow in
addition to focused tests; [`../../../validation/moonbit-prove-strategy.md`](../../../validation/moonbit-prove-strategy.md)
explains how to separate property proofs from ordinary test success.

## Current Boundary

As of 2026-07-11, neither a Starshine pass name nor a harness flag exists.
The appropriate near-term deliverable is therefore a policy and test design,
not a hidden implementation in `optimize` or `shrink`. The existing
[`fuzzing.md`](fuzzing.md) remains planned-only and should be updated with a
real command only after the registry, generator, host-stubbing policy, and
meaningful compared-case threshold all exist.

## Sources

- Current-main owner/helper/registration/scheduler recheck:
  [`../../../raw/binaryen/2026-07-11-remove-imports-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-remove-imports-current-main-recheck.md)
- Earlier detailed owner/helper/registration read:
  [`../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md`](../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md)
- Local representations and lowerer:
  [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt),
  [`../../../../../src/lib/module.mbt`](../../../../../src/lib/module.mbt),
  [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- Local validation and rewrite checklist:
  [`../../../../../src/validate/validate.mbt`](../../../../../src/validate/validate.mbt),
  [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md)
- Related owner and behavior guide: [`index.md`](index.md),
  [`direct-call-stubbing-and-element-retention.md`](direct-call-stubbing-and-element-retention.md)
