# 0071 - RemoveUnusedBrs HOT Lift Shapes

## Scope

- Record the lifted HOT shape for the remaining `RemoveUnusedBrs` returned-ladder families.
- Compare that lifted shape with the current `RemoveUnusedBrs` matcher entry points.
- Separate pass-shape problems from lift-shape problems before the next correctness slice lands.

## Why This Exists

Recent `RemoveUnusedBrs` probes kept missing or overfiring on the remaining oracle families even when the normalized WAT looked simple. The repeated failure mode was the same:

- the normalized WAT suggested a direct typed-`if` or block-local branch ladder
- the HOT pass was actually visiting a different structural shape after lift
- broadening the matcher to "all return-context tails" regressed performance or broke existing returned-scalar tests

That means the next slice needs a source-backed HOT shape, not another guess from printed WAT.

## Lifted HOT Shape

I lifted an existing valid returned-ladder regression fixture and dumped the live HOT nodes directly. The key shape was:

- root region:
  - one root, a `Block` with `result_arity=1`
- block body:
  - one root, a `Return`
- return child:
  - a typed `If`
- `then` region:
  - a zero-result holder `Block`
  - body roots are `LocalSet`, then `Return`
- `else` region:
  - a zero-result holder `Block`
  - body root is `Return`
- nested returned value block:
  - another typed `Block`
  - whose body root is a typed `If`
  - whose `then` and `else` arms are again wrapped in zero-result holder blocks

The important point is that simple WAT arms are not entering the pass as bare region roots. Lift introduces holder blocks and explicit `Return` nodes much earlier than the normalized WAT suggests.

## Comparison To Current Pass Shape

Current `RemoveUnusedBrs` logic is strongest in three entry-point families:

1. region-tail cleanup where the region already has a removable tail target
2. payload-context rewrites where a value arm directly feeds a `br` payload
3. block-local void `if ... else br $label` flattening

The remaining returned-ladder families do not line up cleanly with those entry points after lift:

- a function-root typed control often becomes `Block(result) -> Return -> If`
- returned arm bodies are wrapped in zero-result blocks
- inner typed `if`s that look block-local in WAT may sit behind those wrapper blocks and explicit `Return` nodes in HOT

So the pass currently sees many of these families only after it has already committed to either:

- return-context stripping
- tail `if` cleanup
- one-sided stack-tail `select` formation

That explains why the recent "just enable tail value-if branch-exit rewrites in return-context" experiments were too coarse.

## Correctness Constraints

Any next rewrite for these families must preserve the existing returned-scalar regressions, especially:

- `preserves scalar root return ifs with returned block arms`
- `preserves scalar root return ifs with nested returned block ladders`
- `lowers nested scalar returned ladders with side-effect arms`
- `rewrites one-sided stack-style tail branch ifs into select`

Those tests prove that some returned-ladder shapes must stay typed until later `select` formation or return stripping runs. A rewrite that voidifies them too early is wrong, even if it helps one oracle family.

## Performance Impact

Two rejected probes confirm that broadening by context alone is too expensive:

- enabling the existing tail branch-exit rewrite for all return-context regions regressed the real oracle run from the stable `527.048ms` pass band to `671.116ms`
- narrowing that to returned block bodies still broke existing returned-scalar tests

So the next implementation cannot be "widen the existing helper to every returned region". The discriminator has to be structural and cheap.

## Practical Conclusion

The remaining work is partly an IR-shape problem and partly a pass-shape problem:

- HOT lift is not wrong, but it does canonicalize returned ladders into wrapper-block and explicit-return shapes that the current pass does not target directly
- `RemoveUnusedBrs` still assumes too many Binaryen-looking opportunities will appear as direct region tails

The next plausible route is a dedicated matcher for:

- typed `If` under an explicit `Return`
- inside a zero-result holder block
- where one arm is itself a block-wrapped direct `Return`
- and the competing path exits an enclosing zero-result block with a plain `br`

That is much narrower than "all return-context tails", and it matches the actual lifted structure instead of the printed WAT approximation.

## Validation

This research used:

- existing valid `RemoveUnusedBrs` returned-ladder fixtures
- a temporary HOT structural dump during local development
- `moon test src/passes/remove_unused_brs_test.mbt`

The temporary dump code was removed after inspection. No production behavior was kept from that probe.

## Open Questions

- Is the best fix a new `RemoveUnusedBrs` matcher over the lifted `Return -> If -> Block` shape, or should lift expose a cheaper helper for "returned region root" discovery?
- Should these returned-ladder families stay in `RemoveUnusedBrs`, or do they really belong in a later final-shape phase closer to Binaryen's `restructureIf`?
- Can the HOT API expose a canonical "arm body roots ignoring holder blocks" query cheaply enough to avoid more ad hoc holder peeling in the pass?
