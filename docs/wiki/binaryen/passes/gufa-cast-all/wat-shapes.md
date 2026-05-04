---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../raw/research/0432-2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md
  - ../../../raw/research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
---

# `gufa-cast-all` WAT and IR shapes

This page gives beginner-friendly before/after sketches for the main source-backed shapes in Binaryen `gufa-cast-all`. They are simplified teaching examples, not exact copied lit-file excerpts.

## How to read these examples

- “Before” means the kind of IR shape Binaryen can see before the pass.
- “After” means the important semantic direction of change, not byte-for-byte output.
- The real pass is whole-program and oracle-driven, so these examples are intentionally small teaching sketches.
- Every inserted cast should be read as trap-aware and validation-sensitive, not as a comment-only type annotation.

## Shape 1: plain GUFA still does the first rewrite work

Before:

```wat
(ref.eq
  (call $makeA)
  (ref.null none)
)
```

Possible conceptual after:

```wat
i32.const 0
```

Why:

- the family still includes plain GUFA's ordinary rewrites first,
- `gufa-cast-all` is not only about brand-new casts.

## Shape 2: a new cast is inserted on a value with a broader static type

Before:

```wat
(local.get $x) ;; static type: (ref null $Top)
```

After under `gufa-cast-all`, conceptually:

```wat
(ref.cast (ref null $Narrower)
  (local.get $x)
)
```

Why:

- the oracle can prove that the reachable contents are inside a narrower cone,
- plain `gufa` may know that fact without directly materializing it,
- `gufa-cast-all` makes the fact explicit.

## Shape 3: exact typed struct-local cast insertion

Before, conceptually:

```wat
(local.get $box) ;; declared as a broad nullable struct reference
```

After, conceptually:

```wat
(ref.cast (ref (exact $B))
  (local.get $box)
)
```

Why:

- the dedicated lit file proves an exact-struct cast-insertion family,
- the exact target is only valid when the feature/model can represent it.

## Shape 4: exact function-reference cast insertion

Before:

```wat
(local.get $f) ;; broad funcref-like static type
```

After, conceptually:

```wat
(ref.cast (ref (exact $specific_func_type))
  (local.get $f)
)
```

Why:

- the dedicated lit file also proves a function-reference cast family,
- `gufa-cast-all` is not limited to struct values.

## Shape 5: existing-cast refinement and new-cast insertion are different

Before:

```wat
(ref.cast (ref null $Mid)
  (local.get $x)
)
```

Possible after, conceptually:

```wat
(ref.cast (ref null $Narrower)
  (local.get $x)
)
```

Why:

- the shared GUFA family can sharpen an existing cast target,
- the sibling's extra value is that it can also add a cast where none existed before.

## Shape 6: exact replacement can make a new cast unnecessary

Before:

```wat
(local.get $x)
```

Possible after:

```wat
(global.get $known_value)
```

Why:

- if plain GUFA can replace the expression with a known value directly, the cast-all walk may have nothing useful left to wrap,
- this is why the sibling is not “always add a cast everywhere.”

## Shape 7: unreachable values stay unreachable

Before:

```wat
(local.get $x) ;; oracle proves no possible contents
```

Possible after:

```wat
(unreachable)
```

Why:

- impossible-content rewrites still belong to the shared GUFA phase,
- cast-all does not turn unreachable into a casted value.

## Shape 8: imported/exported tags and EH boundaries stay conservative

Before, conceptually:

```wat
(try
  (do ...)
  (catch $imported_or_exported_tag ...)
)
```

Possible after:

```wat
;; unchanged or only changed by shared safe GUFA rules
```

Why:

- the dedicated lit file keeps imported/exported tag cases conservative,
- that is a whole-program boundary fact, not a missing peephole.

## Shape 9: exactness is feature-sensitive

Before:

```wat
(local.get $x)
```

Possible conceptual after on a feature-rich target:

```wat
(ref.cast (ref (exact $B))
  (local.get $x)
)
```

Possible conceptual after on a stricter feature surface:

```wat
(ref.cast (ref $B)
  (local.get $x)
)
```

Why:

- the reviewed GUFA-family sources and lit surface show that exactness may need to be downgraded,
- the pass emits the narrowest valid cast, not always the narrowest imaginable cast.

## Shape 10: some candidate values stay unchanged

Before:

```wat
(local.get $x)
```

Possible after:

```wat
(local.get $x)
```

Why:

- the dedicated lit file includes preserved no-op cases too,
- the oracle knowing more is not by itself enough,
- castability, legality, feature, and subtype-improvement rules still filter the insertion step.

## Shape 11: this sibling does not own cleanup reruns

Before plain GUFA can produce wrappers that leave simplification debt. `gufa-optimizing` owns the nested cleanup for those cases. `gufa-cast-all` does not.

So conceptually, if the pass adds a cast but also leaves structure around it, you should **not** expect this sibling alone to run:

- `dce`,
- `vacuum`.

That absence is part of the contract.

## Short checklist for future ports

Keep these rules visible in tests and docs:

- plain GUFA rewrites happen first,
- the distinctive sibling step is new `ref.cast` insertion,
- refinalize or validate before inserting those casts,
- exactness is feature-sensitive,
- inserted casts can trap and must remain visible to effect/safety analysis,
- preserved no-op cases are part of the contract,
- nested cleanup belongs to `gufa-optimizing`, not here.
