# RemoveUnusedBrs dedicated drift accepted

Date: 2026-06-29

## Scope

Final acceptance note for `[O4Z-AUDIT-RUB-Q]` dedicated `remove-unused-brs-all` closeout. This note records explicit user/project approval of the substitute closeout package documented in notes `1390` and `1391`.

## Accepted Starshine-win family

The accepted mismatch family is the side-effect-free dead structured trap/control shell cleanup exposed by the dedicated `remove-unused-brs-all` GenValid aggregate. Binaryen `version_130` often performs the local branch/table cleanup but leaves a structured shell such as:

```wat
block
  block
    br outer
  end
  unreachable
end
```

or a result-block variant where a pure selector is dropped and a branch payload is forwarded through an inner block followed by dead `unreachable`. Starshine performs the same observable branch/table cleanup and deletes the now-dead shell.

Reduced representatives live at:

- `.tmp/rub-shape-reduce-brif.wat` — constant-true `br_if` exits an empty block; Binaryen keeps a trap shell, Starshine erases the empty observable body. Raw size: Binaryen `43` bytes, Starshine `37` bytes.
- `.tmp/rub-shape-reduce-control.wat` — same-target `br_table`; Binaryen lowers to a branch but preserves an inner block plus dead `unreachable`, while Starshine drops the selector, branches with the payload, and removes the dead shell. Raw size: Binaryen `50` bytes, Starshine `46` bytes.

## Evidence package accepted as substitute closeout

The user explicitly accepted this as a Starshine win on 2026-06-29 after reviewing the reduced wasm shapes. This approval is the project-approved substitute for requiring the dedicated profile to become normalized-green or for forcing Starshine to preserve Binaryen's dead shells.

Accepted evidence:

- Current-binary `remove-unused-brs-all` capped `1000` probe at `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-max100`:
  - compared `115/1000` before mismatch cap
  - selected leaves: `control=50`, `switch=48`, `cleanup=17`
  - `115` output-shape mismatches
  - `0` Starshine validation failures
  - `0` generator/property/command failures
  - all sampled effect facts exclude calls and memory/table/global/exception/atomic effects
  - normalized Starshine size <= Binaryen in `115/115`, total normalized delta `-12527` bytes
  - raw size mixed, total raw delta `+951` bytes
- Current-binary runtime probe at `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-runtime-max20`:
  - compared `35/1000` before mismatch cap
  - selected leaves: `control=14`, `switch=16`, `cleanup=5`
  - `35` output-shape mismatches
  - `0` Starshine validation failures
  - `0` generator/property/command failures
  - Node runtime all-equal: `27` equal results, `8` equal traps, `0` semantic mismatches
  - all sampled effect facts exclude calls and memory/table/global/exception/atomic effects
  - normalized Starshine size <= Binaryen in `35/35`, total normalized delta `-3832` bytes
  - raw size mixed, total raw delta `+428` bytes
- Prior runtime smoke from note `1389` checked `20/20` mismatches as all-equal (`16` equal results, `4` equal traps, `0` semantic mismatches).
- Source/effect envelope: `src/validate/gen_valid.mbt`'s RUB profile disables imports, tables, memories, tags, element segments, data segments, calls, indirect calls, and tail calls for the accepted aggregate leaves; future replays must still inspect effect facts rather than assuming the envelope.

## Acceptance decision

Classification is now: **accepted Starshine win / intentional drift** for the documented side-effect-free dead-shell cleanup family.

This is not a harness-provided classification. It is a project/user-approved judgment based on source-backed effect constraints, reduced representatives, runtime checks, validation results, and size evidence.

Do not implement Binaryen-shaped preservation of these dead shells merely to make the dedicated profile normalized-green. Do not add a normalizer that erases broader control differences without preserving the same side-effect-free proof obligation.

## Reopening criteria

Reopen `[O4Z-AUDIT-RUB-Q]` or file a focused follow-up if any future dedicated replay shows:

- a Starshine validation failure attributable to `remove-unused-brs` under the current binary,
- a runtime semantic mismatch,
- effect facts involving calls, memory/table/global mutation, exceptions, atomics, imports, tables, memories, tags, element segments, data segments, indirect calls, or tail calls in a mismatch claimed under this accepted family,
- a mismatch outside the reduced dead structured shell / pure selector-drop / branch-payload forwarding family,
- a size-losing family without the documented normalized/canonical win or without an explicit project acceptance,
- Binaryen source drift that changes the `RemoveUnusedBrs` contract for this family,
- or changes to Starshine lowering/encoding that invalidate the reduced representatives or effect envelope.

## Closeout status

`[O4Z-AUDIT-RUB-Q]` can be closed under the approved-substitute clause: the dedicated aggregate is not normalized-green, but the remaining mismatch family is accepted intentional Starshine-win drift with documented source/effect/runtime/size evidence. The stale validation-failure blocker remains superseded by current-binary evidence from notes `1389` through `1391`.
