# Deferred INL005 / INL006 Work

Last updated: 2026-05-16.

This page records the inlining follow-up work that was **not** completed after `[INL]002` was accepted as representation/factoring drift. Use this as the durable handoff point before reopening accepted INL slices.

## Status summary

- `[INL]005 - Partial Inlining Splitter`: **not implemented**. Still active if future evidence shows partial splitting is worth the code-size/complexity tradeoff.
- `[INL]006 - Tail-Call, Multi-Result, and Name/Annotation Repair`: **mostly narrowed**. Tail-call and multi-result correctness surfaces now have focused coverage; the remaining unsupported surface is local/label name reconstruction after body rewrites.

## `[INL]005` deferred work

Starshine still lacks Binaryen's split/partial inlining pass for top-of-function conditional patterns.

### Pattern A not done

Binaryen Pattern A recognizes a function beginning with a cheap guard such as:

```wat
(func $maybe (param i32)
  (block
    (if (local.get 0)
      (then return))
    ;; heavy body
  ))
```

Binaryen can split this into an inlineable guard helper plus an outlined heavy helper, then inline the guard. Starshine does not currently create either helper, does not rewrite callers to the guard helper, and does not run splitter-specific helper cleanup.

### Pattern B not done

Binaryen Pattern B recognizes a small number of top-level cheap `if` guards with heavy bodies and an optional simple final item. Starshine does not currently split these into inlineable and outlined helper functions.

### Policy behavior not done

Binaryen has partial-inlining-specific policy knobs and no-partial-inline behavior. Starshine parses and preserves `no-partial-inline` policy markers, but there is no partial splitter for the marker to suppress. Official no-partial behavior remains deferred with `[INL]005`.

### Why deferred

Partial inlining can deliberately increase code size. No reduced Starshine correctness, validation, or clear pass-local performance/size win was established during this follow-up. Do not implement it merely for Binaryen WAT/byte-shape parity.

### Suggested future acceptance bar

Before implementing `[INL]005`, add reduced Pattern A/B fixtures that prove at least one of:

- a semantic or validation issue is fixed;
- a clear pass-local performance win exists;
- a measured downstream optimization win offsets size growth;
- a user-facing policy expectation requires the behavior.

Then compare direct `--pass inlining` and `--pass inlining-optimizing` on split-family repros.

## `[INL]006` completed or narrowed surfaces

The following `[INL]006` surfaces now have focused tests and commits in this follow-up:

- nested direct `return_call` callee inlined only at an outer direct `return_call` callsite;
- non-tail callsites for return-call-containing callees remain gated;
- nested `return_call_indirect` and `return_call_ref` are preserved when inlined through an outer direct tail callsite;
- direct `return_call` inlining inside a `try_table` callsite is covered;
- no-param multi-result callees inline through a type-indexed wrapper block;
- parameterized multi-result callees inline when a reusable zero-param result type exists;
- otherwise-inlineable parameterized multi-result callees get a synthesized zero-param result block type;
- function names compact correctly after helper removal;
- non-function name maps for types, tables, memories, and globals survive synthesized type appends;
- no-inline policy annotations continue to remap/deduplicate across compaction via the existing policy helper.

Key evidence recorded in `agent-todo.md`, `CHANGELOG.md`, and `docs/wiki/log.md` includes:

- `moon test src/passes` latest follow-up lane: `1080/1080`;
- full `moon test` latest follow-up lane: `3143/3143`;
- wasm-smith smoke `.tmp/pass-fuzz-inlining-optimizing-inl006-name-type-wasm-smith-1000`: `996/1000` compared, `996` normalized matches, `0` mismatches, `0` validation failures, `4` Binaryen/tool command failures;
- previous wasm-smith smokes for tail forms and multivalue synthesis also had `0` mismatches and `0` validation failures.

## `[INL]006` deferred work

### Local/label name reconstruction not done

Starshine still intentionally drops function-scoped local and label name maps after body rewrites. This is safer than preserving stale or collision-prone debug names.

Binaryen-like full repair would need to:

- copy callee local names into caller-local name maps after appended parameter/body locals;
- avoid collisions with existing caller local names;
- repair or synthesize label names for copied blocks/loops/if/try regions;
- handle nested inlining waves and later helper compaction;
- preserve determinism and avoid stale function-scoped maps after any body rewrite.

This was not implemented because it is debug-name fidelity, not semantic correctness. Existing behavior is documented and tested: function names and non-function names survive where safe; local/label names are dropped after inlining rewrites.

### Broader annotation collision repair not done

Function-level policy annotations are remapped and deduplicated, and `no_inline_copy_policy_annotations(...)` exists for clone/copy helpers. Broader Binaryen-like annotation collision/compaction behavior beyond the current internal no-inline policy markers remains unsupported unless a concrete Starshine annotation use case appears.

## Reopen criteria

Do not reopen accepted `[INL]001`, `[INL]002`, `[INL]003`, `[INL]004`, or `[INL]007` for these deferred items unless new evidence shows a semantic mismatch, wasm validation failure, exported/start/table/ref.func discrepancy, or a proven pass-local performance/code-size issue.

Use:

- `[INL]005` for partial-splitting implementation or explicit rejection;
- a new `[INL]006` follow-up only for local/label/name/annotation repair with a concrete user-facing or correctness reason;
- `[WALL]001` for aggregate whole-command runtime issues.
