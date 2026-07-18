---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# `local-subtyping` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `local-subtyping` pass.

## Read this page with the corrected mental model

Binaryen asks:

- which reference-typed body locals are assigned values narrower than their declarations?
- what is the best common type of those assignments?
- can all relevant gets safely use a non-null declaration?
- after changing the declaration, which gets and tees need retagging?
- does refinalization expose another refinement round?

The examples below are conceptual. They show the important local declaration and expression-type behavior, not exact pretty-printer output.

## Shape 1: assigned values narrow a wide local

Before:

```wat
(local $x anyref)
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

Why it rewrites:

- `$x` is reference-typed;
- assigned values prove a narrower common type;
- the declaration and safe get type can be retagged.

## Shape 2: sibling writes narrow only to a common parent

Before:

```wat
(local $x anyref)
(if
  (then (local.set $x (struct.new $Left ...)))
  (else (local.set $x (struct.new $Right ...))))
(drop (local.get $x))
```

After, conceptually:

```wat
(local $x (ref null $Parent))
```

Why it rewrites that way:

- Binaryen computes a LUB;
- it does not pick `$Left` or `$Right` arbitrarily;
- the best common parent can still be narrower than `anyref`.

## Shape 3: `local.tee` is an assignment and a typed expression

Before:

```wat
(local $x anyref)
(drop
  (local.tee $x
    (struct.new $A ...)))
```

After, conceptually:

```wat
(local $x (ref null $A))
(drop
  (local.tee $x
    (struct.new $A ...)))
```

Why it matters:

- the tee contributes assigned-value evidence;
- the tee expression type must also be repaired after declaration narrowing.

## Shape 3a: non-null `local.tee` assignments can validate as non-null

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(drop (local.tee $x (local.get $p)))
```

Possible after:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the `local.tee` is assignment evidence and also an expression use;
- local Binaryen v130 narrows this shape to a non-null child declaration;
- Starshine's emitted lib representation has no separate get/tee result-type field to retag; a focused tee-parent optimized module validates after the declaration change.

## Shape 3b: raw `unreachable` before a tee/get stays nullable today

Before:

```wat
(local $x (ref null $callee_t))
unreachable
(drop
  (block (result (ref null $callee_t))
    (local.tee $x (ref.func $callee))))
(drop (local.get $x))
```

Binaryen v130 after, conceptually:

```wat
(local $x (ref $callee_t))
```

Starshine after, today:

```wat
(local $x (ref null $callee_t)) ;; often exact after narrowing the heap
```

Why it stays nullable in Starshine:

- the source validates, and Binaryen v130 narrows the reduced shape to a non-null exact local;
- `wasm-tools validate --features all` rejects the Binaryen output with `uninitialized local: 1` at the later get;
- rebuilt Starshine keeps the local nullable exact and emits validating wasm;
- this is a precise validator/tooling boundary, not a measured Starshine win. Reopen only if the non-null output validates, Starshine adopts a spec-backed raw-unreachable tee proof, or LS can safely repair the later get.

## Shape 4: non-null narrowing needs dominated gets

Before:

```wat
(local $x (ref null $A))
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

Possible after, when all relevant gets are dominated:

```wat
(local $x (ref $A))
(local.set $x
  (struct.new $A ...))
(drop (local.get $x))
```

Why it rewrites:

- the assigned value is non-null;
- the relevant get cannot observe the original null/default state;
- Binaryen keeps the non-null declaration and retags the get; Starshine recomputes emitted get typing from the rewritten declaration unless the shape hits a validator/tooling boundary such as raw `unreachable` before the write.

## Shape 5: an undominated get keeps nullability

Before:

```wat
(local $x (ref null $A))
(drop (local.get $x)) ;; may happen before a non-null assignment
(local.set $x
  (struct.new $A ...))
```

After, conceptually:

```wat
(local $x (ref null $A))
```

Why it does not become non-null:

- some get can observe the older nullable state;
- structural dominance fails;
- Binaryen falls back to a nullable declaration and preserves nullable get typing.

## Shape 6: branch-free blocks can preserve domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(block
  (drop (local.get $x)))
```

Possible after, when the block has no direct branch/return/throw flow:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment is non-null and dominates entry to the block;
- the block body is branch-free in the current Starshine subset;
- a get inside the block cannot observe the original nullable default.

## Shape 6a: branch-free block writes can dominate later outer gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p)))
(drop (local.get $x))
```

Possible after, when the block has no direct branch/return/throw flow:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows this shape under `--local-subtyping`;
- a branch-free block runs its write before the following outer get;
- Starshine now propagates initialized state out of branch-free blocks, while still keeping direct branch/return, throw, and `try_table` body post-state flow conservative.

## Shape 6b: terminal branches can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (drop (local.get $x))
  (br 0))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows both terminal `br 0` and terminal `br_table 0 0` variants under `--local-subtyping`;
- the `local.get` appears before the branch and is dominated by the write;
- Starshine now treats `br` / `br_table` as a non-propagating control boundary instead of a whole-function non-null proof failure, so it admits the dominated get but does not use branch-carried writes to initialize the outer post-state.

## Shape 6c: branch flow blocks non-null block post-state propagation

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (br 0))
(drop (local.get $x))
```

After, from local Binaryen v130 evidence:

```wat
(local $x (ref null $A))
```

Why it stays nullable:

- the assigned heap type still narrows from `$Parent` to `$A`;
- local Binaryen v130 does not use this branch-flow block post-state to prove non-nullability;
- Starshine keeps the same nullable fallback by not propagating `br` / `br_table` block writes to the outer post-state, while still treating direct return/post-state, throw, and broader `try_table`/EH flow conservatively.

## Shape 6d: `br_if` paths that can skip a write stay nullable

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $exit
  (br_if $exit (i32.const 1))
  (local.set $x (local.get $p)))
(drop (local.get $x))
```

After, from local Binaryen v130 evidence:

```wat
(local $x (ref null $A))
```

Why it stays nullable:

- the true branch exits the block before the write, so the later outer get can still observe the default null;
- Starshine now treats `br_if` as a conditional-flow barrier for subsequent write initialization, rather than a full-function bailout, so earlier dominated gets can still narrow while branch-skipped writes do not prove non-null post-state.

## Shape 6d: conditional `return` paths can skip later dominance paths

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if (i32.const 0)
  (then (return)))
(local.set $x (local.get $p))
(drop (local.get $x))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the returning branch cannot reach the later write or get;
- every path that reaches the later get has executed the non-null write;
- Starshine now treats `return` inside copied `if` arms as a path skip for this dominance proof, while keeping direct return/post-state cases conservative.

## Shape 6d-return_call: direct tail calls in an `if` arm can skip a later write/get path

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if (i32.const 0)
  (then (return_call $callee)))
(local.set $x (local.get $p))
(drop (local.get $x))
```

The same narrow source-backed shape also applies to terminal `return_call_indirect` after its table index operands and `return_call_ref` after its function-reference operand.

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/if-return-call-skip-before-write-get.wat`, `.tmp/ls-probes/if-return-call-indirect-skip-before-write-get.wat`, and `.tmp/ls-probes/if-return-call-ref-skip-before-write-get.wat` under `--local-subtyping`;
- the tail-call arm cannot reach the later write or get;
- every path that reaches the later get has executed the non-null write;
- Starshine now treats direct `return_call`, `return_call_indirect`, and `return_call_ref` inside copied `if` arm scans like the conditional-`return` path-skip subset. This does not widen broad tail-call expression repair or post-state propagation.

## Shape 6d-throw: direct `throw` in an `if` arm can skip a later write/get path

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if (i32.const 1)
  (then (throw $e))
  (else (nop)))
(local.set $x (local.get $p))
(drop (local.get $x))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/if-arm-direct-throw-skips-later-write-get.wat` under `--local-subtyping`;
- the throwing arm cannot reach the later write or get;
- every path that reaches the later get has executed the non-null write;
- Starshine now treats direct `throw` and the source-backed direct `throw_ref` analog inside copied `if` arm scans as path skips, parallel to the conditional-`return` subset. This does not widen catch-ref/post-state EH flow or broad `try_table` handling beyond the separate source-backed try-body dominated-get tail subset.

## Shape 6e: root terminal `return` can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(drop (local.get $x))
(return)
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the final `return` is at the root instruction tail;
- the only observed get appears before the return and is dominated by the non-null write;
- Starshine now treats this as a non-propagating terminal control boundary, while still refusing direct return/post-state cases that require unreachable later-get validation proof.

## Shape 6e-return_call: root/block terminal direct tail calls can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(drop (local.get $x))
(return_call $callee)
```

The same narrow source-backed terminal shape also applies to `return_call_indirect` after its table index operands and `return_call_ref` after its function-reference operand.

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/return-call-after-dominated-get.wat`, `.tmp/ls-probes/block-terminal-return-call-after-dominated-get.wat`, `.tmp/ls-probes/return-call-indirect-after-dominated-get.wat`, `.tmp/ls-probes/block-terminal-return-call-indirect-after-dominated-get.wat`, `.tmp/ls-probes/return-call-ref-after-dominated-get.wat`, and `.tmp/ls-probes/block-terminal-return-call-ref-after-dominated-get.wat` under `--local-subtyping`;
- the observed get appears before the terminal tail call and is dominated by the non-null write;
- Starshine now treats direct `return_call`, `return_call_indirect`, and `return_call_ref` as non-propagating terminal return boundaries for the source-backed root/block, copied-if-arm path-skip, and copied `try_table` body tail subsets.

## Shape 6d-a: adjacent `call_ref` can refinalize after target-local narrowing

Before:

```wat
(type $ret-any (sub (func (result anyref))))
(type $ret-i31 (sub $ret-any (func (result i31ref))))
(local $f (ref null $ret-any))
(local $x anyref)
(local.set $f (ref.func $ret-i31))
(local.set $x (call_ref $ret-any (local.get $f)))
```

Possible after, from Binaryen v130 and Starshine focused coverage:

```wat
(local $f (ref (exact $ret-i31)))
(local $x i31ref)
(local.set $x (call_ref $ret-i31 (local.get $f)))
```

Bottom-target variant:

```wat
(local.set $f (ref.null nofunc))
(local.set $x (call_ref $ret-any (local.get $f)))
```

narrows `$f` to `nullfuncref`, narrows `$x` to `(ref none)`, and replaces the unemittable bottom `call_ref` with an unreachable value block that drops the target. Starshine currently implements this for represented zero-param adjacent-local-get targets; reopen for non-adjacent targets, parameterized bottom calls, argument side effects, or non-identical function params.

## Shape 6e-a: block terminal `return` can preserve already-dominated gets inside the block

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (drop (local.get $x))
  (return))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/block-terminal-return-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` is before the terminal block `return` and is dominated by the non-null write;
- Starshine now threads the terminal-return permission into `block` scans reached from the root scan, treating the block return as a non-propagating dominance boundary without propagating block-carried writes to an outer post-state. Direct block-return post-state cases with later unreachable gets remain nullable until validator/tooling support can prove or repair those gets.

## Shape 6e-b: if-arm block terminal `return` can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if
  (then
    (block
      (local.set $x (local.get $p))
      (drop (local.get $x))
      (return)))
  (else
    (nop)))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/if-arm-block-terminal-return-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` is inside the returning `if` arm's nested block and is dominated by the non-null write before the terminal block `return`;
- Starshine now treats that nested block return as a non-propagating terminal boundary when it is reached from a copied return-skipped `if` arm scan. This does not propagate writes out of the arm or widen direct block-return post-state/unreachable-get handling.

## Shape 6f: root terminal `throw` can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(drop (local.get $x))
(throw $e)
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows this shape under `--local-subtyping`;
- the final `throw` exits the root body, so the observed get before it is the only relevant read and is dominated by the non-null write;
- Starshine now treats root-tail `throw` and the source-backed root-tail `throw_ref` analog as non-propagating terminal control boundaries, while still refusing other nested/non-final throw/EH flow and broader `try_table` behavior until those shapes have separate dominance and validator evidence.

## Shape 6g: block terminal `throw` can preserve already-dominated gets inside the block

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (drop (local.get $x))
  (throw $e))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/block-terminal-throw-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` is before the terminal block `throw` and is dominated by the non-null write;
- Starshine now threads the terminal-throw permission into `block` scans reached from the root scan, treating block `throw` and the source-backed block-tail `throw_ref` analog as non-propagating dominance boundaries without propagating block-carried writes to an outer post-state. Nested/non-final throw beyond the covered `try_table` body tail subset and broader `try_table`/EH flow remain conservative blockers until separately source-backed.

## Shape 6g-b: if-arm block terminal `throw` can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if
  (then
    (block
      (local.set $x (local.get $p))
      (drop (local.get $x))
      (throw $e)))
  (else
    (nop)))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/if-arm-block-terminal-throw-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` is inside the throwing `if` arm's nested block and is dominated by the non-null write before the terminal block `throw`;
- Starshine now treats that nested block throw as a non-propagating terminal boundary when it is reached from a copied return/throw-skipped `if` arm scan. This does not propagate writes out of the arm or widen non-final throw, catch-ref/post-state EH flow, or broader `try_table` handling.

## Shape 6g-c: `throw_ref` mirrors covered terminal/direct-throw dominance subsets

Before:

```wat
(param $p (ref $A))
(param $e (ref exn))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(drop (local.get $x))
(local.get $e)
(throw_ref)
```

The same source-backed subset applies to block-tail `throw_ref`, an `if` arm where `throw_ref` skips a later dominating write/get path, and `try_table` body terminal or non-final `throw_ref` tails whose later syntactic tail gets are already dominated.

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/throw-ref-terminal-after-dominated-get.wat`, `.tmp/ls-probes/throw-ref-block-terminal-after-dominated-get.wat`, `.tmp/ls-probes/throw-ref-if-skip-before-dominated-write.wat`, `.tmp/ls-probes/throw-ref-try-table-terminal-after-dominated-get.wat`, and `.tmp/ls-probes/throw-ref-try-table-before-unreachable-tail-get.wat` under `--local-subtyping`;
- the exception reference operand is separate from the narrowed local in the covered tests, and every raw get of `$x` is dominated by the non-null write;
- Starshine now handles `ThrowRef` through the same non-propagating terminal/skip scanner branch as `Throw`, while still refusing catch-ref/catch-all-ref post-state propagation and broader EH flow without separate evidence.

## Shape 6h: `try_table` bodies can preserve body-local domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $h
  (try_table (catch $e $h)
    (local.set $x (local.get $p))
    (drop (local.get $x))))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/try-table-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` is inside the `try_table` body and is dominated by the body-local non-null write on every path that reaches it;
- Starshine scans the `try_table` body with copied state and does not propagate that body's writes to the outer post-state; a companion probe keeps a `try_table` body write before a later outside get nullable child.

## Shape 6h-a: terminal `throw` in a `try_table` body can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $h
  (try_table (catch $e $h)
    (local.set $x (local.get $p))
    (drop (local.get $x))
    (throw $e)))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/try-table-terminal-throw-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` appears before the terminal body `throw` and is dominated by the non-null write;
- Starshine allows final `throw` and the source-backed final `throw_ref` analog inside the copied `try_table` body scan for this subset, still refuses catch-ref/post-state EH flow, and never propagates try-body writes outward.

## Shape 6h-a2: non-final `throw` in a `try_table` body can preserve already-dominated tail gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $h
  (try_table (catch $e $h)
    (local.set $x (local.get $p))
    (drop (local.get $x))
    (throw $e)
    (drop (local.get $x)))) ;; syntactically after throw, so unreachable
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/try-table-throw-before-unreachable-get-after-dominated-get.wat` under `--local-subtyping`, and also narrows the trailing-`unreachable` variant in `.tmp/ls-probes/try-table-throw-before-unreachable-after-dominated-get.wat`;
- the pre-`throw` get and the syntactic tail get are both dominated by the non-null write;
- Starshine now treats direct `throw` and the source-backed direct `throw_ref` analog inside a copied `try_table` body as non-propagating terminal points but continues scanning the syntactic tail to catch any not-yet-dominated local gets. This does not propagate try-body writes outward and does not widen catch-ref/catch-all-ref post-state or broader EH flow.

## Shape 6h-b: terminal `return` in a `try_table` body can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $h
  (try_table (catch $e $h)
    (local.set $x (local.get $p))
    (drop (local.get $x))
    (return)))
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/try-table-terminal-return-after-dominated-get.wat` under `--local-subtyping`;
- the `local.get` appears before the terminal body `return` and is dominated by the non-null write;
- Starshine allows final `return` inside the copied `try_table` body scan for this subset, still refuses catch-ref/post-state EH flow, and never propagates try-body writes outward.

## Shape 6h-b2: non-final `return` in a `try_table` body can preserve already-dominated tail gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $h
  (try_table (catch $e $h)
    (local.set $x (local.get $p))
    (drop (local.get $x))
    (return)
    (drop (local.get $x)))) ;; syntactically after return, so unreachable
```

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/try-table-return-before-unreachable-get-after-dominated-get.wat` under `--local-subtyping`, and also narrows the trailing-`unreachable` variant in `.tmp/ls-probes/try-table-return-before-unreachable-after-dominated-get.wat`;
- `wasm-tools validate --features all .tmp/ls-probes/try-table-return-before-unreachable-get-after-dominated-get.nonnulllocal.wat` accepts the corresponding non-null local form, unlike the direct block-return validator-boundary family;
- the pre-`return` get and the syntactic tail get are both dominated by the non-null write;
- Starshine now treats direct `return` inside a copied `try_table` body as a non-propagating terminal point but continues scanning the syntactic tail to catch any not-yet-dominated local gets. This does not propagate try-body writes outward and does not widen catch-ref/catch-all-ref post-state or broader EH flow.

## Shape 6h-c: tail calls in a `try_table` body can preserve already-dominated gets

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block $h
  (try_table (catch $e $h)
    (local.set $x (local.get $p))
    (drop (local.get $x))
    (return_call $callee)))
```

The same narrow source-backed body-tail shape also applies to `return_call_indirect` after its table index operand and `return_call_ref` after its function-reference operand. A non-final syntactic tail with already-dominated `local.get`s after the tail call is also accepted, mirroring the try-body `return` tail subset.

Possible after, from local Binaryen v130 evidence:

```wat
(local $x (ref $A))
```

Why it rewrites:

- local Binaryen v130 narrows `.tmp/ls-probes/try-table-terminal-return-call-after-dominated-get.wat`, `.tmp/ls-probes/try-table-terminal-return-call-indirect-after-dominated-get.wat`, `.tmp/ls-probes/try-table-terminal-return-call-ref-after-dominated-get.wat`, `.tmp/ls-probes/try-table-return-call-before-unreachable-tail-get.wat`, `.tmp/ls-probes/try-table-return-call-indirect-before-unreachable-tail-get.wat`, and `.tmp/ls-probes/try-table-return-call-ref-before-unreachable-tail-get.wat` under `--local-subtyping`;
- the observed gets before the tail call, and any syntactic tail gets after that tail call in the non-final probes, are dominated by the non-null write;
- Starshine's scanner already treats `return_call`, `return_call_indirect`, and `return_call_ref` as return-like non-propagating terminal points inside the copied `try_table` body scan. This still does not propagate try-body writes outward and does not widen catch-ref/catch-all-ref post-state or broader EH flow.

## Shape 6h-d: `catch_ref` / `catch_all_ref` skipped writes narrow through raw assignment

Before:

```wat
(local $x (ref null $Parent))
(drop
  (block $catch (result exnref)
    (try_table (catch_ref $e $catch) ;; or catch_all_ref
      (throw $e))
    (local.set $x (struct.new_default $A))
    (ref.null noexn)))
(drop (local.get $x))
```

Binaryen v130 output narrows the local heap type but keeps nullability:

```wat
(local $x (ref null (exact $A)))
```

Current Starshine behavior:

- local Binaryen v130 narrows `.tmp/ls-ref-catch-impl-20260704/catch-ref-skipped-struct-write.wat` and `.tmp/ls-ref-catch-impl-20260704/catch-all-ref-skipped-struct-write.wat` to nullable exact-child locals;
- the catch path can skip the write and still reach the outside get through the block result, so non-null narrowing remains invalid;
- Starshine now matches this concrete nullable exact-child rewrite without HOT lifting the ref-catch result-flow function. The raw ref-catch path collects only directly provable assignment producer types, falls back to the declared local type for unknown producers, and disables non-null dominance through ref-catch flow. Focused tests require the `catch_ref` and `catch_all_ref` skipped-write shapes to narrow to `(ref null (exact $A))` and validate. Reopen ref-catch under LS only for reduced cases outside this raw-assignment subset, such as catch-payload result joins that must stay broad.

## Shape 6i: direct block `return` flow is a Starshine validator boundary

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(block
  (local.set $x (local.get $p))
  (return))
(drop (local.get $x))
```

Binaryen v130 narrows this direct-return shape to non-null child, but a 2026-07-04 refresh showed the reduced Binaryen output is rejected by `wasm-tools validate --features all` with `uninitialized local: 1`. Current Starshine keeps the local nullable and emits a validating module:

```wat
(local $x (ref null $A))
```

Why Starshine stays nullable for now:

- the later get is syntactically after a direct `return`, so Binaryen performs unreachable-path narrowing that current validators reject for non-defaultable locals;
- Starshine validation now has focused boundary coverage for the reduced non-null output shape in `validate_module rejects direct block-return non-defaultable unreachable-tail local get`;
- this is a precise representation/tooling blocker, not an accepted semantic win: reopen when the reduced non-null output validates, when Starshine validation intentionally adopts a spec-backed proof for this shape, or when LS can safely repair/avoid the unreachable get.

## Shape 7: loop bodies can preserve entry domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(loop
  (drop (local.get $x)))
```

Possible after, when the loop body has no direct branch/return/throw flow or only a tail `br_if` backedge after the dominated get:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment is non-null and dominates the first loop entry;
- local Binaryen v130 narrows a loop whose body reads the local and then reaches a tail `br_if 0` backedge;
- Starshine admits that narrow backedge subset by preserving entry initialization for gets before the `br_if`, while refusing to let writes after a `br_if` prove non-null post-state;
- writes inside the loop are not propagated to later outer gets; a local Binaryen v130 probe for a branch-free loop write followed by an outside get kept the declaration nullable child, so Starshine keeps that source-backed fallback.

## Shape 8: branch-free `if` arms can preserve entry domination

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(if (i32.const 1)
  (then (drop (local.get $x)))
  (else (drop (local.get $x))))
```

Possible after, when the `if` arms have no direct branch/throw flow except the conditional-return, direct-return_call, and direct-throw skip subsets:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment is non-null and dominates entry to the `if`;
- each arm is scanned with a copy of the pre-`if` initialized state;
- current Starshine does not propagate writes inside either arm to later outer gets.

## Shape 8a: all-arm `if` writes do not currently prove non-null post-state

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(if (i32.const 1)
  (then (local.set $x (local.get $p)))
  (else (local.set $x (local.get $p))))
(drop (local.get $x))
```

After, from local Binaryen v130 evidence:

```wat
(local $x (ref null $A))
```

Why it stays nullable:

- the write-site LUB still narrows the heap from `$Parent` to `$A`;
- local Binaryen v130 keeps nullability for this post-`if` outside get even when both arms write;
- Starshine intentionally scans each arm with copied entry state and does not merge arm writes outward.

## Shape 9: dominated branch-free blocks can contain branch-free `if` arms

Before:

```wat
(param $p (ref $A))
(local $x (ref null $Parent))
(local.set $x (local.get $p))
(block
  (if (i32.const 1)
    (then (drop (local.get $x)))
    (else (drop (local.get $x)))))
```

Possible after, when no direct branch/return/throw flow is present:

```wat
(local $x (ref $A))
```

Why it rewrites:

- the assignment dominates entry to both the block and the nested `if`;
- each nested `if` arm is scanned with a copy of the block-entry state;
- writes inside the nested `if` still do not propagate to later outer gets in the current Starshine subset;
- plain branch-free block writes do propagate to later outer gets as in Shape 6a.

## Shape 10: gets matter, but they do not choose the LUB

Before and after may stay the same in the important part:

```wat
(local $x anyref)
(call $needs_a
  (local.get $x))
```

Why this alone does not narrow:

- a consumer that wants `$A` does not prove `$x` always contains `$A`;
- assigned values drive the LUB;
- gets are used for dominance and repair once a candidate exists.

## Shape 11: repeated refinement after refinalization

Before, conceptually:

```wat
(local $a anyref)
(local $b anyref)
(local.set $a (struct.new $A ...))
(local.set $b (local.get $a))
(drop (local.get $b))
```

After, conceptually:

```wat
(local $a (ref null $A))
(local $b (ref null $A))
```

Why iteration matters:

- narrowing `$a` can make the type assigned to `$b` more precise;
- Binaryen refinalizes and reruns until stable;
- a single declaration-only pass may miss this family.

## Shape 12: parameters are preserved

Before and after stay unchanged in the signature:

```wat
(func $f (param $p (ref null $Parent))
  (local.set $p
    (ref.as_non_null (ref.null $A)))
  (drop (local.get $p)))
```

After, from local Binaryen v130 evidence:

```wat
(func $f (param $p (ref null $Parent))
  ...)
```

Why:

- local Binaryen v130 keeps the parameter at its declared signature type even after a non-null child write;
- Starshine only rewrites body-local declarations;
- preserving params avoids changing the function ABI and matches the source-backed boundary.

## Shape 13: non-reference and tuple/nondefaultable locals are preserved

Before and after stay unchanged in the important part:

```wat
(local $pair (tuple i32 i64))
```

Why:

- the pass is about reference local declarations;
- nondefaultable or tuple-like shapes are not forced through the rewrite;
- the official lit surface includes preservation coverage for this boundary.

## Shape 14: neighborhood shapes matter

`local-subtyping` is not an isolated cleanup.

Useful combined shapes include:

```wat
;; optimize-casts may expose a cleaner assignment first
(local.set $x (ref.cast (ref null $A) ...))

;; coalesce-locals benefits after local-subtyping creates exact-equal local types
(local.set $y (local.get $x))

;; local-cse and simplify-locals later consume cleaner local traffic
(drop (local.get $y))
```

The important scheduler lesson:

`optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`

## What the current Starshine slice still needs

Starshine currently covers the basic write-site narrowing shapes, but it does not yet cover the full Binaryen contract. If the active slice grows toward parity, the reduced shape tests should cover:

1. body-local reference narrowing from assigned values;
2. sibling assignments that choose a common parent LUB;
3. `local.tee` assignment plus tee-parent validation after declaration narrowing;
4. dominated non-null positives, including the current branch-free `block`, branch-free `loop`, loop tail-`br_if`, nested branch-free block-`if`, and root-`if` subsets;
5. undominated nullable fallbacks;
6. gets not acting as standalone LUB evidence;
7. repeated refinement after refinalization;
8. parameter preservation;
9. non-reference and tuple/nondefaultable preservation;
10. interaction tests with `optimize-casts`, `coalesce-locals`, and `local-cse`.

## Sources

- [research note 0447](./index.md)
- [research note 0362](./index.md)
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
- Binaryen current-main lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>
