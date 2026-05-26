# DAE003 wrapper-chain closure

Date: 2026-05-26

## Question

Can `[DAE003-D]` be closed without a new behavior change, or is there still an active localized forwarding-chain gap for constant/unread parameter materialization?

## Evidence

- `src/passes/dae_optimizing_test.mbt` already contains the focused regression `dae-optimizing can chase a later exact-literal forwarding-wrapper chain`.
- That fixture builds a localized `A -> B -> C`-style forwarding chain (`run* -> wrap1 -> wrap2 -> check`) where every caller passes the same exact literal for the middle parameter after eight earlier productive rewrites consume the initial core budget.
- The assertion pins the reverse exact-literal trace to three productive rewrites in dependency order: `primary_def=10`, then `primary_def=9`, then `primary_def=8`.
- The same test asserts the signatures of all three participating functions shrink from three parameters to two, proving the chain is not only discovered but applied across the wrappers.
- The implementation evidence is the guarded recursive `local.get` resolution in `src/passes/dead_argument_elimination.mbt`: `dae_resolve_uniform_const_candidate(...)` delegates parameter-local `local.get` operands to `dae_resolve_forwarded_uniform_const_local_get(...)`, which recursively calls `dae_collect_uniform_const_actuals_visited(...)` through direct callers while rejecting escaped functions, tail calls, self-call bodies, written locals, and visited cycles.
- Earlier research notes `0566`, `0567`, `0568`, and `0569` recorded the original Func42 / high-wrapper chain investigation and the later low-prefix / reverse exact-literal repairs that made the focused wrapper-chain test pass.

## Classification

`[DAE003-D]` is closed for the current v0.1.0 surface as an already-tested behavior slice. The covered safe subset is direct, private, non-tail wrapper chains where forwarding operands are parameter-local `local.get`s, the parameter is not written in the wrapper, the functions are not escaped, and cycle/self-call guards hold.

This does **not** close broader `[DAE003-C]`, `[DAE003-E]`, or `[DAE003-F]` work: non-adjacent forwarding through temporary locals, recursive/self-recursive cycles, and structured nontrivial carriers still need their own positive and negative tests before being accepted.

## Validation

- Attempted focused command `moon test src/passes -p 'dae-optimizing can chase a later exact-literal forwarding-wrapper chain'` was invalid for Moon's CLI (`[PATH]` cannot be combined with `--package`).
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed after filing this note.
