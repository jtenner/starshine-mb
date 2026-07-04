---
kind: research
status: current
last_reviewed: 2026-07-04
sources:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/coalesce_locals.mbt
  - ../../../../src/passes/coalesce_locals_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-strategy.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
---

# `coalesce-locals` direct refresh: structured param reuse and loop unused locals

## Question

Does the current Starshine `coalesce-locals` direct pass still match local Binaryen `version_130` on the current GenValid lane, and if not, what finite mismatch family appears first?

## Source/oracle refresh

- Local oracle: `wasm-opt --version` reports `wasm-opt version 130 (version_130)`.
- The active source files inspected for this slice were `src/passes/coalesce_locals.mbt`, `src/passes/coalesce_locals_test.mbt`, `src/passes/pass_manager.mbt`, `src/passes/optimize.mbt`, `src/passes/optimize_test.mbt`, `src/passes/reorder_locals.mbt`, `src/passes/local_subtyping.mbt`, `src/passes/local_cse.mbt`, and `src/passes/simplify_locals.mbt`; no separate `src/passes/vacuum*.mbt` files exist in this repo, so the vacuum neighbor was inspected through `src/passes/pass_manager.mbt` and `src/passes/optimize_test.mbt`.

## Red direct-refresh result

After rebuilding the native CLI with:

```sh
moon build --target native --release src/cmd
```

this direct compare was intentionally run first against the current implementation:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass coalesce-locals \
  --count 10000 \
  --seed 0x5eed \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-coalesce-locals-refresh-10000-20260704
```

It stopped at the mismatch cap:

- compared: `37 / 10000`
- normalized matches: `3`
- mismatches: `34`
- validation failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile: `binaryen-oracle-portable=37`

The first sampled mismatch was a local-declaration parity/size gap, not a validation failure: Binaryen coalesced unused same-typed body locals in structured/loop-heavy generated functions down to one slot per exact local type, while Starshine retained the old declarations because the loop guard returned the whole function unchanged and the structured conservative path forced every body local to interfere with every param.

## Fix

Two safe subsets were added:

1. **Structured param-slot reuse.** The structured conservative path no longer adds blanket body-local/param interferences. It still uses the conservative plain-liveness interference overlay, but it now allows Binaryen-compatible reuse of a parameter slot after the parameter is dead. Parameters are not reordered or removed; only compatible body locals can map to the fixed param index.
2. **Loop functions with syntactically unused locals.** The loop guard remains conservative for accessed loop locals, but it now coalesces body locals that have no syntactic `local.get`, `local.set`, or `local.tee` use anywhere in the function. The implementation keeps one surviving body declaration per exact type when no compatible param/body slot already exists, matching Binaryen's coalescing behavior rather than deleting all unused local types.

Focused tests now cover:

- structured param-slot reuse after a condition is dead;
- preserving a live body local when a structured dead set could otherwise clobber it;
- reusing a dead structured param slot without moving params;
- keeping accessed loop locals conservative;
- coalescing syntactically unused locals in loop functions.

## Green direct evidence

A 50-case smoke after the fix was fully normalized-green:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass coalesce-locals \
  --count 50 \
  --seed 0x5eed \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-coalesce-locals-loop-unused-50b-20260704 \
  --max-failures 100 \
  --keep-going-after-command-failures
```

Results:

- compared: `50 / 50`
- normalized matches: `50`
- mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- command failures: `0`
- Binaryen cache: `50` hits / `0` misses

The full 10k direct lane after the fix is also normalized-green:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass coalesce-locals \
  --count 10000 \
  --seed 0x5eed \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-coalesce-locals-loop-unused-10000-20260704 \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- compared: `10000 / 10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile: `binaryen-oracle-portable=10000`
- Binaryen cache: `55` hits / `9945` misses

## Validation

Post-fix validation run:

```sh
moon fmt
moon info
moon test --package jtenner/starshine/passes --file coalesce_locals_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
git diff --check
```

Results:

- `moon fmt`: passed
- `moon info`: passed with pre-existing warnings
- focused `coalesce_locals_test.mbt`: `15/15`
- `moon test src/passes`: `3997/3997`
- full `moon test`: `7420/7420`
- native `src/cmd` build: passed with pre-existing warnings
- `git diff --check`: passed

## Remaining work

This slice restores the current direct regular GenValid lane to zero mismatches. It does **not** close the whole `[O4Z-AUDIT-CL]` audit.

Remaining audit work:

- rerun the ordered O4z GC/local neighborhood where the earlier OC audit localized size drift to `+ coalesce-locals` / `+ local-cse`;
- run explicit wasm-smith, dedicated/pass-specific if added, and random-all-profiles lanes for closeout-level evidence;
- audit large-function coloring/runtime behavior, especially the dense interference matrix and the O4z oversized-function path;
- finish the TypeIdx/RecIdx invariant documentation item `[AUDIT006-D]` near the `coalesce-locals` function-type cache abort;
- update final docs/backlog only after those lanes are classified.

## Reopening criteria

Reopen this specific structured/loop unused-local subset if a reduced case shows:

- a parameter index is moved or removed rather than reused in place;
- an accessed loop local is merged with another live/local-carried value by this conservative loop path;
- a syntactically referenced local is dropped, leaving a stale local index;
- direct `--coalesce-locals` produces a validation failure or a non-normalized mismatch in this family;
- Binaryen changes the contract for unused locals in loop/structured functions beyond one surviving slot per exact type when no compatible prior slot exists.
