# DAE002 bounded reverse exact-literal rewrites still miss Func 4558 in the real artifact

Date: 2026-05-14

## Question

Would a bounded reverse exact-literal follow-up lane be enough to reach the `4558 -> 4559 -> 42` wrapper chain on the original debug artifact?

## Result

Not with the current small bound.

On the original artifact, the first `20` productive reverse exact-literal rewrites are:

- `4593, 4592, 4591, 4589, 4588, 4587, 4586, 4584, 4582, 4562, 4580, 4561, 4579, 4560, 4559, 4558, 4577, 4557, 4556, 4555`

So the wrapper-chain pair only appears at:

- `4559` at reverse iteration `14`
- `4558` at reverse iteration `15`

A small bounded reverse lane such as `8` iterations therefore does **not** reach the artifact chain root soon enough.

## Supporting evidence

Added whitebox characterization in `src/passes/pass_manager_wbtest.mbt`:

- `dae reverse exact-literal artifact frontier reaches 4559 and 4558 only after many later candidates`

This sits alongside the earlier artifact-chain tests proving:

- Func 4558 is directly exact-literal rewritable when targeted.
- Func 4559 becomes directly rewritable after 4558 rewrites.
- Func 42 becomes directly rewritable after 4558 and 4559 rewrite.

## Interpretation

This rules out a cheap bounded reverse exact-literal sweep as a sufficient artifact fix by itself.

The artifact problem is now more precisely:

- not just low-to-high core starvation,
- not just a missing reverse lane,
- but a prioritization problem inside a larger reverse-exact-literal frontier.

## Consequence

A real fix likely needs one of:

1. a more targeted prioritization rule that can prefer the relevant forwarding-wrapper chain over unrelated higher-index reverse candidates, or
2. a more direct exact-literal forwarding analysis that can see through wrapper-local `local.get` forwarding without requiring the wrappers to rewrite first.

Do **not** overclaim that “reverse exact-literal” alone fixes the artifact.
