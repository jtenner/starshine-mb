---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-gufa-current-main-recheck.md
  - ../../../raw/research/0471-2026-05-05-gufa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-gufa-primary-sources.md
  - ../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_flags.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./content-oracle-variants-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../gufa-optimizing/index.md
  - ../gufa-cast-all/index.md
  - ../type-refining/index.md
  - ../tracker.md
---

# Starshine `gufa` strategy

## Current status

Starshine does **not** implement plain `gufa` today.

The exact local status is:

- `src/passes/optimize.mbt` lists `gufa` in `pass_registry_boundary_only_names()` beside `gufa-optimizing` and `gufa-cast-all`.
- `src/cmd/cmd.mbt` only accepts active hot/module/preset names as explicit command pipeline steps, so `--gufa` is rejected as an unknown CLI pass flag today.
- `run_hot_pipeline_expand_passes` in `src/passes/optimize.mbt` has a second guard that rejects boundary-only entries as not implemented if a lower-level caller tries to expand them.
- `src/passes/pass_manager.mbt` has no `gufa` dispatch case and no GUFA-family nested runner.
- No dedicated `src/passes/gufa*.mbt` owner file exists.
- The `optimize` / `shrink` preset arrays in `src/passes/optimize.mbt` do not include `gufa`.
- `agent-todo.md` has no active `gufa`, `gufa-optimizing`, or `gufa-cast-all` implementation slice.

So the current Starshine strategy is a **boundary-status and future-port map**, not a claim of Binaryen parity.

## Why Starshine cannot treat this as constant propagation

Binaryen plain `gufa` is a whole-program contents-oracle pass:

1. build a module-wide `ContentOracle`,
2. query possible contents for expression/data locations,
3. rewrite only the locations whose oracle answers are safely materializable or provably impossible,
4. specialize `ref.eq`, `ref.test`, and existing `ref.cast`,
5. refinalize and repair EH nested pops after function rewrites.

That means a faithful Starshine port must be module-level analysis plus local rewrite work. A HOT-only constant folder would miss the defining proof step and would overclaim parity even if it happened to fold a few of the same constants.

## Exact Starshine code map

| Local surface | Current role for this pass |
| --- | --- |
| `src/passes/optimize.mbt` | Boundary-only registry entry for `gufa`; lower-level expansion rejects boundary-only names with an honest not-implemented message; active presets omit the pass. |
| `src/cmd/cmd.mbt` | Command pass parsing admits only hot/module/preset names, so explicit CLI requests are rejected before dispatch. |
| `src/passes/pass_manager.mbt` | Active HOT dispatcher; contains no GUFA-family case and no module-wide oracle phase. |
| `src/lib/types.mbt` | Defines the instruction vocabulary a future port would rewrite or emit, including `Unreachable`, `GlobalGet`, `RefFunc`, `RefEq`, `RefTest`, and `RefCast`. |
| `src/ir/hot_core.mbt` | Defines HOT op tags for the same core rewrite families, including `Unreachable`, `GlobalGet`, `RefFunc`, `RefTest`, `RefCast`, and tuple ops. |
| `src/ir/hot_lift.mbt` | Lifts supported instructions into HOT nodes; useful for a function-local rewrite phase but not a whole-program oracle. |
| `src/ir/hot_lower.mbt` | Lowers HOT nodes back to library instructions and already contains unreachable-stack repair helpers that future proof-preserving rewrites would need to respect. |
| `src/ir/hot_flags.mbt` | Records local value/trap/side-effect flags; useful for preserving effects, but not a substitute for Binaryen's closed-world `ContentOracle`. |
| `src/ir/effects.mbt` | Existing function-local effect-mask model; useful for side-effect barriers and dropped-child preservation, but not whole-program value contents. |
| `src/validate/typecheck.mbt` | Validator/typechecker surface a future port must keep green after replacing expressions or inserting/refining casts. |
| `src/binary/encode.mbt` / `src/binary/decode.mbt` | Binary roundtrip surfaces for the GC/ref instructions that a future port would touch. |
| `src/wast/parser.mbt` / `src/wast/lower_to_lib.mbt` | Text-fixture and lowering surfaces for reduced GUFA tests involving refs, globals, and casts. |
| `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` | Older pass-port map that classifies the GUFA family with whole-module or layout transforms. |
| `agent-todo.md` | No active implementation slice found, so there is no current owner for the port. |

## Future port shape

A faithful local port should probably be a module pass or a module-plus-HOT hybrid:

1. add a real `gufa` owner file and dispatch surface before accepting the pass flag;
2. build a Starshine equivalent of Binaryen's `ContentOracle` over functions, globals, call edges, reference-typed flows, and closed-world roots;
3. represent at least the source-backed result families: no contents, one literal, one global/function identity, one reference type cone, and many/unknown;
4. make the rewrite engine conservative about materialization and static type validity, especially for `global.get` and `ref.func` identities;
5. preserve child side effects when replacing an expression by `unreachable` or a known value;
6. implement `ref.eq` intersection folding, `ref.test` cone-subset/intersection folding, and existing-`ref.cast` result-type refinement;
7. refinalize or otherwise revalidate changed functions/modules before writeback;
8. keep the sibling behaviors separate: no nested `dce` / `vacuum` cleanup here, and no fresh cast insertion here.

## What a future port must not do

Do **not** implement plain `gufa` as:

- ordinary constant propagation,
- a global version of `precompute`,
- a generic `ref.cast` insertion pass,
- a `dce` / `vacuum` cleanup preset,
- an open-world local-flow pass that ignores the closed-world proof boundary,
- a pass that rewrites every oracle-known value even when the emitted node would fail static validation.

Those would all erase source-backed distinctions that the current Binaryen dossier now keeps explicit.

## Validation plan for a future port

A useful first validation ladder would be:

1. accept `--gufa` only after the pass has a real owner and dispatch case;
2. add reduced tests for the plain `gufa.wast` families: unreachable parameters, one known call/global result, impossible `ref.eq`, guaranteed/impossible `ref.test`, and existing-`ref.cast` narrowing;
3. add negative tests for tuple-typed results, ordered memory/synchronization, open-world/export boundaries, and known-but-not-materializable `global.get` / `ref.func` type mismatches;
4. prove side-effect preservation when replacing a value-producing subtree;
5. prove plain `gufa` leaves cleanup residue that `gufa-optimizing` would clean, and does not insert the new casts owned by `gufa-cast-all`;
6. run pass-targeted Binaryen parity fuzzing once the oracle is broad enough to compare against upstream.

## Current local conclusion

Starshine should keep plain `gufa` as boundary-only until a whole-program contents oracle exists. The existing instruction, HOT, validation, binary, and WAT surfaces are useful future building blocks, but the missing oracle is the pass.

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the concrete validation ladder and prerequisite surfaces.
