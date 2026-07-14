---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp
  - ../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md
  - ../../../binary/function-import-export-and-code-sections.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/validate.mbt
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../../../binary/function-import-export-and-code-sections.md
---

# `remove-imports`: Direct-Call Stubbing and Element Retention

## The Narrow Contract

Binaryen `remove-imports` has two separate actions that are easy to confuse:

1. it replaces a **direct call** whose callee is an imported function; then
2. it removes an imported-function declaration only when that function name is
   absent from every element-segment function list.

The upstream owner implements those actions in `visitCall` and `visitModule`,
respectively. The `visitCall` rule is not conditioned on whether the import
will later remain in an element segment. Consequently, keeping a declaration
for a table reference does **not** keep its direct calls. The current owner
and `ElementUtils::iterAllElementFunctionNames` helper remain current in the
[current-main `RemoveImports.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp).

This is a specialized reference-interpreter preparation tool, not a
behavior-preserving optimization. Replacing a host call with a `nop` or a
manufactured default result removes host effects and possibly a host-provided
value even if the output module remains valid.

## Before and After Shapes

### No-result direct call

```wat
(module
  (import "env" "trace" (func $trace (param i32)))
  (func $run
    i32.const 7
    call $trace))
```

At the reviewed source level, `visitCall` replaces the direct call with `nop`.
If no element segment names `$trace`, `visitModule` also removes its imported
function declaration. The exact printed post-pass WAT can include later
Binaryen cleanup, but the two semantic facts are stable: the direct host call
is gone, and its import becomes eligible for removal.

### Value-producing direct call

```wat
(module
  (import "env" "read_flag" (func $read_flag (result i32)))
  (func (export "run") (result i32)
    call $read_flag))
```

The owner substitutes Binaryen's default `Literal(type)` rather than a `nop`,
because the expression position still requires an `i32`. This preserves stack
typing; it does **not** preserve the original host result. A local port must
never cite successful validation as permission to make this rewrite.

### Element-retained import still has direct calls stubbed

```wat
(module
  (type $t (func))
  (table 1 funcref)
  (import "env" "callback" (func $callback (type $t)))
  (elem (i32.const 0) func $callback)
  (func $run
    call $callback))
```

The element segment makes `$callback` visible to the reviewed retention scan,
so the declaration must remain. But the direct `call $callback` is still an
imported direct call and is independently rewritten. The pass therefore does
not mean “remove imports that are unused”; it means “stub direct imported
calls, then retain the imported declarations needed by element lists.”

### Out of scope: non-function imports

```wat
(module
  (import "env" "memory" (memory 1))
  (import "env" "flag" (global i32))
  (func (result i32) global.get 0))
```

The reviewed owner enumerates imported **functions** and visits direct calls.
It does not establish a removal rule for imported tables, memories, globals,
or tags. A future Starshine feature must not turn the pass name into a license
to delete every `ImportSec` entry.

## Why Element Names Are a Deliberately Small Retention Proof

`ElementUtils::iterAllElementFunctionNames` visits function references in
function-typed element-segment templates. This directly protects table content
from being invalidated by deleting its referenced import. It is not a general
whole-module liveness analysis.

In particular, the reviewed owner does not itself prove a policy for every
other function-index carrier. A Starshine implementation must separately
inventory and decide how to preserve or reject references in:

- `ref.func` expressions and their declaration requirements;
- direct and tail-call instructions;
- start and export sections;
- legacy and expression-form element payloads;
- name and function-annotation sections; and
- any future function-index-carrying custom metadata.

The canonical local inventory is the [function/import/export/code section
rewrite checklist](../../../binary/function-import-export-and-code-sections.md#pass-rewrite-checklist).
That checklist is broader than the upstream `ElementUtils` guard because
Starshine stores numeric `FuncIdx` values across its core module model.

## Porting Rules

A future local port should separate three questions instead of treating them
as one deletion pass:

| Question | Required answer before mutation |
| --- | --- |
| May this direct call be replaced? | An explicit embedding/stubbing policy must say its host effects and result are disposable. |
| Must this imported declaration stay? | Check all local function-index carriers, beginning with element/table references; do not assume Binaryen's narrow helper settles every local representation. |
| How are indices repaired? | Rebuild every shifted absolute `FuncIdx` carrier and validate the rewritten module. |

That separation prevents a common but dangerous inference: “the import was
kept for a table, therefore its direct call should be retained.” Binaryen's
reviewed source does the opposite—declaration retention and direct-call
stubbing are independent actions.

## Test Matrix for a Future Starshine Slice

Before a mutating local pass can be trusted, write focused tests for:

1. no-result imported direct calls under an explicit stubbing mode;
2. value-result calls, proving both default-value typing and policy approval;
3. an element-retained function import whose direct call is still stubbed;
4. a function import with no element reference, including all imported-prefix
   `FuncIdx` repairs after removal;
5. non-function imports, which must remain untouched by this pass contract;
6. `ref.func`, start, export, names, and annotation carriers—either preserved
   correctly or rejected by a documented fail-closed boundary; and
7. encoded-Wasm validation plus WAST/binary roundtrip after every accepted
   rewrite.

Generic `compare-pass` generation is not sufficient for these cases because
it cannot establish that arbitrary host imports are safe to erase. See the
planned-only [fuzzing guidance](fuzzing.md).

## Sources

- Upstream current-main owner, element-helper, and registration/scheduler: [`RemoveImports.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp), [`element-utils.h`](https://github.com/WebAssembly/binaryen/blob/main/src/ir/element-utils.h), and [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
- Earlier detailed owner/element-helper source read:
  [`../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md`](../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md)
- Local function-index repair inventory:
  [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md)
- Core import representation and validator:
  [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt),
  [`../../../../../src/validate/validate.mbt`](../../../../../src/validate/validate.mbt)
- Owner overview and planned validation policy: [`index.md`](index.md),
  [`fuzzing.md`](fuzzing.md)
