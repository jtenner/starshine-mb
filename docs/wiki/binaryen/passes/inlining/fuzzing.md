---
kind: workflow
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ./index.md
  - ./starshine-port-readiness-and-validation.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `inlining` fuzzing and signoff boundary

## Current status: admitted targeted smoke, not full parity closeout

`inlining` passes the four compare-pass admission gates today:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) registers it as an active module pass, not a boundary-only name;
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) dispatches the plain mode with `optimize=false`;
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) accepts `--inlining`; and
- [`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) exposes the checked-in `pass-inlining` recipe.

Use the project wrapper, a fresh native executable, and the targeted recipe for the ordinary reproducible smoke lane:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass inlining --count 10000 --seed 0x5eed \
  --gen-valid-profile pass-inlining \
  --out-dir .tmp/pass-fuzz-inlining-pass-inlining-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

`bun scripts/pass-fuzz-compare.ts ...` reaches the same implementation, but [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md) makes `bun fuzz compare-pass` the documented interface. Do not substitute an old `target/native/...` artifact for the freshly built `_build/native/...` binary.

## What `pass-inlining` deliberately covers

The recipe is a **scalar direct-call smoke**, not a complete inliner generator. Its source-backed bounds are:

- permits calls and tail calls;
- rejects `call_indirect`;
- rejects reference types and constant-expression variants so generated modules remain compatible with the harness's external-validator path; and
- permits at least eight defined functions, giving the generator enough call-graph room for ordinary direct-call cases.

See the stable-profile assertions in [`src/validate/gen_valid_tests.mbt`](../../../../../src/validate/gen_valid_tests.mbt). Inspect the emitted `inputs/gen-valid/manifest.json` and `result.json` after every run: an admitted profile can still produce no useful inline candidate in a small sample. A nonzero compared count proves only that the tools ran; it does not prove a direct call was selected or a helper was removed.

## Evidence boundary

This lane is useful for current registry, dispatcher, encoder, validator, Binaryen-flag, and scalar direct/tail-call compatibility checks. It is **not** enough to claim full Binaryen `inlining` parity:

- the plain pass still has explicitly documented local representation drift in some historical broad lanes;
- `pass-inlining` excludes reference-root survival, indirect-call, and broad GC/nondefaultable-local surfaces;
- a normalized match does not prove the copied-body repair families: returns, labels, multivalue typing, `try`/EH, or every tail-call form; and
- the optimizing sibling's `inlining-optimizing-all` aggregate is not a replacement. It intentionally exercises inline-then-cleanup behavior for a different public stop point; plain `inlining` must not inherit its cleanup evidence.

Keep direct WAT/core fixtures from [`./starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) beside this lane. In particular, inspect exported/start/`ref.func`/element-root helper survival, call-operand evaluation order, `return_call` repair, function-index remapping after helper deletion, and plain-versus-optimizing cleanup separation.

## Future plain-pass closeout requirements

Before upgrading this page from an admitted smoke to a plain-pass parity signoff, add a dedicated plain-inlining aggregate whose manifest records a guaranteed inline opportunity and its selected shape. It must keep the public plain stop point: no optimizing-only cleanup payoff may be used to hide a missed plain-inlining behavior.

A credible closeout needs all of the following:

1. focused direct-wrapper, parameter-spill, return/tail-call, rooted-helper-survival, and helper-deletion fixtures;
2. a profile or fixture manifest that demonstrates actual eligible direct-call candidates, not just valid modules with calls allowed;
3. replayed mismatch classification under the taxonomy in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md), with unexplained drift left as a parity gap;
4. the standard native 10,000-case lane with explicit `--jobs auto` and `_build/native/...` binary; and
5. separate regression evidence that `inlining` does **not** run the `inlining-optimizing` nested cleanup suffix.

No new external source ingest is needed for this correction: it reconciles a stale local command/profile claim using the current harness, registry, dispatcher, and checked-in generator profile. The upstream inlining contract remains in the existing source-backed dossier.
