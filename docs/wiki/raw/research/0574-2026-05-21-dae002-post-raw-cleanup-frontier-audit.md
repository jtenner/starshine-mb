---
kind: research
status: supported
last_reviewed: 2026-05-21
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../../agent-todo.md
---

# DAE002 post raw-cleanup frontier audit

## Context

After the useful raw-cleanup slices that stripped double-`eqz` from live `if` conditions and folded pure local copy chains, the current artifact replay is `.tmp/dae-local-copy-chain-cleanup-artifact`.

Current first diff remains `defined=16 abs=33`, but the remaining inspected diff is not a correctness or size blocker:

- Starshine branches directly on `local.get` in the outer live `if` condition.
- Binaryen materializes `local.get; i32.const 0; i32.ne` for the same condition.
- In WebAssembly `if`, any nonzero `i32` is true, so Starshine's direct condition is smaller and semantically equivalent. Reintroducing Binaryen's comparison would be cosmetic size regression.

Current artifact sizes from the latest committed replay:

- Starshine raw wasm: `3,508,038` bytes.
- Starshine accepted/canonical wasm: `3,515,031` bytes.

## Bounded audit results

A bounded follow-up audit looked for another narrow raw cleanup with a simple transform contract and artifact usefulness.

### `br_if` double-`eqz` cleanup candidate

Candidate considered: extend the live-condition double-`eqz` cleanup from `if` conditions to `br_if` conditions.

Semantic contract:

- `br_if` consumes an `i32` condition and branches on WebAssembly truthiness, like `if`.
- `x; i32.eqz; i32.eqz; br_if L` can become `x; br_if L` while preserving producer evaluation, traps, effects, branch payload values below the condition, and branch target behavior.
- The rewrite is not valid for non-`i32` producers such as `i64.eqz; i32.eqz`, because `br_if` cannot consume the original `i64` directly.

Focused TDD probe:

- A temporary whitebox test covering `br_if` failed before implementation and passed after adding the narrow `BrIf` hook.
- Artifact replay with the temporary hook wrote `.tmp/dae-br-if-bool-cleanup-artifact` and validated with `wasm-opt --all-features`.
- The replay did **not** change the debug artifact bytes relative to `.tmp/dae-local-copy-chain-cleanup-artifact`:
  - raw wasm stayed `3,508,038` bytes;
  - accepted/canonical wasm stayed `3,515,031` bytes;
  - first diff stayed `defined=16 abs=33`;
  - pass-local timing was within target (`900.819ms` Starshine vs `892.188ms` Binaryen).

Decision: do not commit this as a standalone slice now. It is semantically safe, but it is a tiny cleanup crumb with no current artifact/frontier effect, and the user explicitly asked not to force tiny cleanup crumbs.

### Remaining visible double-`eqz` forms

The current artifact still has a few value-position nested double-`eqz` shapes, for example:

- `local.set` of `i32.eqz(i32.eqz(...))`;
- `return i32.eqz(i32.eqz(i32.rem_s ...))`;
- call arguments using `i32.eqz(i32.eqz(local.get ...))`.

Decision: defer. Outside truthiness-only consumers (`if` / `br_if`), `i32.eqz; i32.eqz` booleanizes to canonical `0` or `1`; replacing it with the raw producer would change value results for nonzero values other than `1`. These are not safe raw cleanups without a downstream consumer proof.

### Effect-fed local copy chains

The current committed pure local-copy chain fold intentionally stays behind `dae_out_ends_with_droppable_pure_stack(...)` and runs only for DAE-touched functions.

A broader `value; local.set x; local.get x -> value; local.tee x` transform is likely semantically equivalent for immediate same-local reads even when the value producer is effectful, because `local.tee` preserves one producer evaluation and the local write. However, this would deliberately broaden the current raw cleanup beyond the pure-producer contract and the handoff warned not to implement effectful-copy rewrites while chasing crumbs.

Decision: defer unless a future artifact/frontier diff clearly justifies a focused effect-order proof and focused validation.

## Conclusion

No safe coherent raw-cleanup slice with current artifact impact emerged from this bounded audit. The next DAE002 work should pivot away from tiny raw-cleanup crumbs and back toward artifact/runtime/frontier work:

1. re-audit the current first-diff family only for changes that are objectively smaller/safer than Binaryen's shape;
2. otherwise work on DAE002 scheduler/runtime/frontier items with measurable artifact or fuzz-frontier impact;
3. keep exact Binaryen byte/shape parity out of scope when Starshine's output is smaller and covered by a simple semantic contract.
