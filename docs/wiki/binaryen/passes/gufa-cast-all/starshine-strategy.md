---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../raw/research/0432-2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md
  - ../../../raw/research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_flags.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
  - ../heap2local/index.md
  - ../tracker.md
---

# Starshine `gufa-cast-all` strategy

## Current status

Starshine does **not** implement `gufa-cast-all` today.

The exact local status is:

- `src/passes/optimize.mbt` lists `gufa-cast-all` in `pass_registry_boundary_only_names()` beside `gufa` and `gufa-optimizing`.
- `src/cmd/cmd.mbt` only accepts active hot/module/preset names as explicit command pipeline steps, so `--gufa-cast-all` is rejected as an unknown CLI pass flag today.
- `run_hot_pipeline_expand_passes` in `src/passes/optimize.mbt` has a second guard that rejects boundary-only entries as not implemented if a lower-level caller tries to expand them.
- `src/passes/pass_manager.mbt` has no `gufa-cast-all` dispatch case.
- No dedicated `src/passes/gufa*.mbt` owner file exists.
- `agent-todo.md` has no active `gufa`, `gufa-optimizing`, or `gufa-cast-all` implementation slice.

So the current Starshine strategy is a **boundary-status and future-port map**, not a claim of parity with Binaryen.

## Why Starshine cannot treat this as a cast peephole

Binaryen's pass is whole-program:

1. build a module-wide `ContentOracle`,
2. run the shared GUFA visitor and first-phase rewrites,
3. refinalize changed functions,
4. run the cast-all-only `addNewCasts` walk,
5. refinalize again if casts were inserted,
6. repair EH nested pops,
7. stop without the `gufa-optimizing` cleanup rerun.

That means a faithful Starshine port needs module-level value/type evidence before it can insert casts. A local HOT peephole that merely adds `RefCast` around a known operand would miss the defining oracle proof and could introduce traps or invalid exact targets.

## Exact Starshine code map

| Local surface | Current role for this pass |
| --- | --- |
| `src/passes/optimize.mbt#L127-L137`, `#L488-L497` | Boundary-only registry entry for `gufa-cast-all`; lower-level expansion rejects boundary-only names with an honest not-implemented message. |
| `src/cmd/cmd.mbt#L616-L618` | Command pass parsing admits only hot/module/preset names, so explicit CLI requests are rejected before dispatch. |
| `src/passes/pass_manager.mbt` | Active HOT dispatcher; contains no GUFA-family case and no post-refinalize cast-all phase. |
| `src/lib/types.mbt` | Defines `Instruction::RefCast`, `Instruction::RefCastDescEq`, and constructor helpers; future code can represent inserted casts here. |
| `src/ir/hot_core.mbt` | Defines HOT `RefCast` / `RefCastDescEq` opcodes, so the HOT IR can carry cast nodes. |
| `src/ir/hot_lift.mbt` and `src/ir/hot_lower.mbt` | Lift and lower cast opcodes through HOT; useful future plumbing but not an oracle or insertion pass. |
| `src/ir/hot_flags.mbt` | Marks `RefCast` and `RefCastDescEq` as value-producing and trapping, which is the key safety reminder for any future insertion. |
| `src/validate/typecheck.mbt` | Enforces `ref.cast` / `ref.cast_desc_eq` target compatibility and stack effects; future tests must validate all inserted casts through this surface. |
| `src/binary/encode.mbt` and `src/binary/decode.mbt` | Encode/decode ordinary and descriptor cast opcodes, including the `0xFB` GC opcode family. |
| `src/wast/parser.mbt` and `src/wast/lower_to_lib.mbt` | Parse/lower descriptor cast text forms; ordinary cast text support flows through the existing reference-typed instruction model. |
| `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` | Archived registry map that classifies `gufa-cast-all` with whole-module or layout transforms. |
| `agent-todo.md` | No active implementation slice found, so there is no current owner for the port. |

## Future port shape

A future faithful port should probably be a module pass or a module-plus-HOT hybrid:

1. add a real shared `gufa` module analysis owner before exposing `gufa-cast-all` as active;
2. build a Starshine equivalent of Binaryen's `ContentOracle` over functions, globals, calls, reference-typed locals, tags, and reachable module boundaries;
3. share the first-phase rewrite engine with plain `gufa`;
4. track per-function mutation and run the local equivalent of refinalization / validation before cast insertion;
5. add a separate cast-all walk, not opportunistic casts inside the first visitor;
6. only consider castable reference-typed values;
7. preserve feature-sensitive exactness downgrade behavior before emitting exact casts;
8. mark and validate each inserted cast as trapping;
9. repair any EH / stack-switching structure needed by Starshine's IR after rewrites;
10. keep nested `dead-code-elimination` + `vacuum` cleanup out of this sibling and leave it to `gufa-optimizing`.

## What a future port must not do

Do **not** implement `gufa-cast-all` as:

- ordinary `ref.cast` canonicalization,
- a blanket cast inserter for every subtype-looking operand,
- a `heap2local` cleanup variant,
- a GC-only type-refining pass without whole-program contents evidence,
- a replacement for `optimize-casts`,
- or `gufa-optimizing` plus casts.

Those would erase the source-backed split between the GUFA proof engine, the cast-materializing sibling, and the cleanup-owning sibling.

## Validation plan for a future port

A useful first validation ladder would be:

1. accept the public pass name only after it has a real owner and dispatch case;
2. add reduced tests mirroring Binaryen's `gufa-cast-all.wast` cast-insertion examples for struct references and function references;
3. prove exact-cast emission only when the local feature/model can represent it safely;
4. prove no cast is added for uncastable or non-reference values;
5. prove inserted casts validate and keep their trapping behavior visible;
6. prove imported/exported tag and EH cases remain conservative;
7. prove `gufa-cast-all` does not run the nested `dce` + `vacuum` cleanup expected only from `gufa-optimizing`;
8. run pass-targeted Binaryen parity fuzzing once the family has enough oracle coverage.

## Current local conclusion

Starshine should keep `gufa-cast-all` as boundary-only until the whole-program GUFA oracle exists. The local IR, WAT, validator, and binary layers can already carry many ordinary and descriptor cast shapes, but those lower-level surfaces are only prerequisites. They are not a cast-all implementation by themselves.

The 2026-05-04 recheck only refreshed the provenance and exact local line anchors; it did not change the boundary-only conclusion.