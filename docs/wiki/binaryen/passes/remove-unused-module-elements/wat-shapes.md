---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-eh-old.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./roots-reference-only-and-nullification.md
  - ./retention-and-index-rewrites.md
  - ./parity.md
---

# `remove-unused-module-elements` WAT and module shapes

## Main idea

This pass is not driven by one local expression pattern.
It is driven by **module layouts** and by the different ways declarations can stay strongly used, weakly referenced, or fully dead.

For RUME, “shape” usually means things like:

- where exports and start point
- which segments are active or passive
- whether an active segment is actually a semantic no-op
- whether a function is called directly, only named by `ref.func`, or only reachable through `call_ref` type information
- whether tables, memories, globals, or tags are strongly used or only still referenced
- which surviving indices must be rewritten after compaction

## Positive shapes: Binaryen will often remove or simplify these

## 1. Truly dead defined module elements

If a defined function, global, table, memory, or tag has no remaining path from exports, start, code, segments, or type/reference edges, it is a normal removal candidate.

```wat
(module
  (func $dead)
  (func $main)
  (export "main" (func $main))
)
```

Beginner takeaway:

- `$dead` is not kept just because it exists in the section

## 2. Dead imported elements too, when nothing meaningful still points at them

Imported items are not magically sticky.
If the pass can prove they are unneeded, they can disappear too.
That includes the imported-function and no-op-start cleanup families already recorded in the repo's focused RUME notes.

```wat
(module
  (import "env" "dead_mem" (memory 1))
  (func $main)
  (export "main" (func $main))
)
```

Beginner takeaway:

- imports are still module elements, not sacred roots

## 3. Zero-byte active data does not keep a memory alive by itself

```wat
(module
  (memory $m 1)
  (data (memory $m) (i32.const 0) "")
)
```

Binaryen treats this as a no-op active segment shape.
So the active data does **not** automatically keep `$m` alive.

## 4. Null-only active elem does not keep a table alive by itself

```wat
(module
  (table $t 1 (ref null any))
  (elem (table $t) (i32.const 0)
    (ref.null none)
  )
)
```

If the elem payload is semantically a no-op, the table does not stay live just because the syntax mentions it.

## 5. Passive segment user ops are real roots

The pass strongly cares about segment-user instructions.

```wat
(module
  (memory $m 1)
  (data $d "abc")
  (func $main
    (memory.init $d (i32.const 0) (i32.const 0) (i32.const 3))
    (data.drop $d)
  )
  (export "main" (func $main))
)
```

Beginner takeaway:

- passive data/elem are not dead just because they are not active parents
- `memory.init`, `table.init`, `data.drop`, `elem.drop`, `array.new_data`, `array.init_data`, `array.new_elem`, and `array.init_elem` are part of the real root surface

## 6. `call_ref` and type-driven function reachability are real shapes here

```wat
(module
  (type $sig (func (result i32)))
  (func $f (type $sig) (i32.const 0))
  (table 1 funcref)
  (func $main
    (ref.func $f)
    (call_ref (type $sig))
    drop
  )
)
```

Beginner takeaway:

- a function can matter even when there is no direct textual `call $f`
- RUME is one of the passes that teaches why `ref.func` and `call_ref` matter for whole-module liveness
- the surviving module must still contain an elem declaration for any live `ref.func` target after function-index compaction

## 7. GC heap-type references are also part of the shape story

If a function/table/memory/tag remains referenced through heap-type structure collected from GC-typed surfaces, that reference can matter.
The pass is therefore not limited to obvious MVP-style index instructions.

## 8. Live elem contents can keep functions relevant

```wat
(module
  (table $t 1 funcref)
  (func $f)
  (elem (table $t) (i32.const 0) func $f)
)
```

If the elem segment stays live, the function named inside it can stay relevant too.

## Declaration-only active elems can become declarative

A live `ref.func` can require an elem segment only as a declaration source. If that elem was active on a table that is otherwise dead, Binaryen can drop the table and keep the declaration by weakening the segment to declarative.

```wat
(module
  (type $t (func (result i32)))
  (table 1 funcref)
  (func $target (type $t) i32.const 42)
  (func $main (result (ref null $t)) ref.func $target)
  (elem (i32.const 0) func $target)
  (export "main" (func $main))
)
```

Beginner takeaway:

- a `ref.func` declaration edge is not the same as a strong table-initialization edge
- keeping the function declaration should not force an otherwise-dead active parent table to survive

## Reference-only / weakening shapes: Binaryen often keeps the idea, not the original declaration

These are the easiest shapes to misunderstand.

## 9. Reference-only non-function elements are not the same as strong users

A table, memory, global, or tag can be:

- strongly used
- fully dead
- or only still referenced

That third state is important.
The official source can replace a reference-only non-function declaration with a weaker inert declaration instead of keeping the original one intact.

Beginner takeaway:

- surviving mention does not always mean surviving original declaration

## 10. The sibling non-function pass keeps functions but still applies the same graph idea

```wat
(module
  (func $keep_me_even_if_dead)
  (global $dead i32 (i32.const 0))
)
```

Under `remove-unused-nonfunction-module-elements`:

- the function is preserved by mode choice
- the global can still be removed

That is a real public shape boundary, not just an implementation detail.

## Negative / bailout shapes: Binaryen keeps these alive or keeps them stronger than a naive pass would

## 11. Exported and start-rooted items stay strongly live

```wat
(module
  (func $main)
  (export "main" (func $main))
  (start $main)
)
```

Beginner takeaway:

- export and start are not weak references here

## 12. Meaningful active parents stay alive

```wat
(module
  (memory $m 1)
  (data (memory $m) (i32.const 0) "abc")
)
```

Unlike the zero-byte case, this active data is meaningful.
So the memory can stay live because the segment really initializes it.

## 13. Live surviving code must be fully remapped

```wat
(module
  (memory $dead 1)
  (memory $live 1)
  (func $main
    (i32.const 0)
    (i32.load (memory $live))
    drop
  )
)
```

If `$dead` is removed, every surviving user of `$live` has to be rewritten to the new memory index.

That same rewrite rule applies across:

- calls and `ref.func`
- globals
- table ops
- memory ops and memargs
- tag ops and catches
- elem/data ops
- exports
- start
- name and annotation metadata

## 14. Flat-table and elem-content edges can block “obvious” function removal

A function that looks unused in direct code can still stay relevant if:

- a live elem segment names it
- a flat table still contains it
- a `call_ref`-compatible heap-type path still reaches it

That is why naive “no direct calls means dead function” logic will drift from Binaryen.

## Practical reading rules

- Prefer reading RUME shapes as **module graphs**, not as isolated instructions.
- When a surprising keep/remove decision appears, ask these in order:
  1. is the item exported or the start target?
  2. is it strongly used by code or segment-user ops?
  3. is it only still referenced through `ref.func`, `call_ref`, flat tables, elem contents, or heap types?
  4. is an active segment actually meaningful, or a semantic no-op?
  5. after removal, which surviving indices still need rewriting?

## Bottom line

For RUME, the most important shapes are not “small peepholes.”
They are module-level reachability patterns:

- strong roots
- reference-only roots
- segment-parent retention versus no-op active segments
- GC/table/type edges
- and full surviving-index rewrite honesty

That is the shape surface a future Starshine parity port must preserve.
