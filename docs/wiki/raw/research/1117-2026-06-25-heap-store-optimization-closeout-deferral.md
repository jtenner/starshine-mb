---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1116-2026-06-25-heap-store-optimization-performance-disposition.md
  - ./1115-2026-06-25-heap-store-optimization-pure-default-chain-fast-path.md
  - ./1114-2026-06-25-heap-store-optimization-post-safety-closeout-probe.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO-J closeout deferral after pure-default performance slice

## Question

Can HSO-J final closeout be declared after the `1115` pure-default chain performance improvement and the `1116` HSO-I disposition note?

## Answer

No. HSO-J remains deliberately deferred because HSO-I is still unresolved. The latest code change improved the allocation-heavy fixture but did not meet the pass-local performance target, and `1116` explicitly keeps that blocker open unless the target is met, the synthetic fixture is superseded with stronger evidence, or the user accepts carrying the measured gap.

## Additional validation advanced in this slice

After commits through `1116`, the latest tree was validated with broader Moon tests:

```sh
moon test src/passes
moon test
```

Results:

- `moon test src/passes`: `3045/3045` passed.
- `moon test`: `6362/6362` passed.

This strengthens post-`1115` confidence but does not replace the final HSO-J closeout requirements. In particular, final HSO-J still needs the agreed full validation/compare matrix and O4z publication evidence after the HSO-I performance decision is resolved.

## Current final-closeout state

Already current:

- HSO-C through HSO-H safety families are closed/narrow-covered by `1113` after exact descriptor `ref.cast` closed in `1109`.
- HSO-B baseline/direct/O4z evidence is closed as current baseline by `1114`.
- Post-`1115` focused HSO tests, native build, 1000-case direct compare smoke, and allocation-heavy timing are recorded in `1115`.
- Post-`1116` broader Moon validation now has green `src/passes` and full workspace test results.

Still required before declaring Binaryen behavior parity complete:

- resolve HSO-I by target, supersession, or explicit user acceptance;
- rerun final closeout validation after that decision, including `moon info`, `moon fmt`, focused HSO tests, `moon test src/passes`, full `moon test`, native `src/cmd` build, and the required pass-fuzz matrix unless explicitly scoped down;
- refresh final O4z slot/neighborhood evidence after the final code-changing slice;
- update the pass dossier, wiki log, and backlog to remove or explicitly defer HSO.

## Validation note

This was a validation/status slice only. No executable files changed in this slice.
