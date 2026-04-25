---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
  - ../../../raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../strip-toolchain-annotations/index.md
  - ../tracker.md
---

# Starshine strategy for `strip-target-features`

## Current local status

Starshine currently has **no `strip-target-features` implementation**.
This page is therefore a status and future-port map, not a description of a shipped transform.

The exact local status is:

- `src/passes/optimize.mbt` has no `strip-target-features` entry in `pass_registry_boundary_only_names()` or `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` has no active `HotPass` or `ModulePass` entry for it in `pass_registry_entries()`.
- `run_hot_pipeline_expand_passes(...)` reports unknown names as `unknown pass flag ...`, so an explicit `strip-target-features` request currently fails as unknown rather than boundary-only or removed.
- `agent-todo.md` has no dedicated backlog slice for the pass.

That means Starshine's present strategy is **non-adoption plus documentation**.
The wiki tracks the upstream pass because Binaryen exposes it publicly and because the late-pass chronology had already mentioned it without a canonical dossier.

## Exact local code locations to read first

- `src/passes/optimize.mbt:96-126`
  - boundary-only registry names; `strip-target-features` is absent.
- `src/passes/optimize.mbt:129-141`
  - removed registry names; `strip-target-features` is absent.
- `src/passes/optimize.mbt:144-267`
  - active hot/module/preset registry construction; no `strip-target-features` entry exists.
- `src/passes/optimize.mbt:446-489`
  - request expansion and rejection behavior; unknown names fail before the boundary-only / removed guards.
- `src/lib/types.mbt:350-424`
  - `Module.custom_secs` and opaque `CustomSec` storage; this is the closest current representation for decoded custom sections.
- `src/lib/types.mbt:8079-8081`
  - `CustomSec::new(...)` constructor.
- `src/binary/decode.mbt:1153-1195`
  - custom-section decoding; non-`name` custom sections are preserved as opaque `CustomSec` records.
- `src/binary/encode.mbt:1134-1143`
  - `CustomSec` encoding writes a section-0 payload with the stored name and bytes.
- `src/binary/encode.mbt:1653-1743`
  - module encoding writes `custom_secs` before ordinary sections and later emits the name section specially; there is no Binaryen-like `emitTargetFeatures` option in this path.

## Why there is no straightforward Binaryen-style port today

Binaryen's pass toggles output option state:

```text
runner->options.emitTargetFeatures = false
```

Starshine's visible local model is different:

- arbitrary custom sections are stored after decode as `Module.custom_secs`;
- the binary encoder writes those stored custom sections back out;
- there is no first-class target-feature section model;
- there is no pass-runner output option matching Binaryen's `emitTargetFeatures`;
- there is no current registry status for the pass.

So a Starshine port has an architecture decision before any code change:

1. add a Binaryen-like output option that suppresses generated target-feature metadata; or
2. implement a module pass that deletes opaque `CustomSec(Name::new("target_features"), ...)` entries from decoded modules; or
3. continue treating the pass as unknown and leave this as documented upstream-only behavior.

Option 2 may be useful, but it is not exactly Binaryen's implementation strategy.

## If Starshine ever ports it

A faithful local port should probably start as a **module/output pass**, not a HOT peephole.

Minimum acceptance criteria:

- choose a public status deliberately: active module pass, boundary-only compatibility entry, removed compatibility entry, or continued unknown-name rejection;
- define whether the pass owns output-option state, decoded opaque custom sections, or both;
- remove or suppress only the target-features custom section;
- preserve arbitrary other custom sections, including `name` / producers-like metadata if present in the chosen representation;
- leave all executable module sections unchanged;
- keep the pass out of optimize/shrink presets unless a separate user-facing policy wants metadata stripping;
- add tests for absent section, preserved non-target custom sections, and no IR mutation.

## Non-goals today

- Do not mark the pass as implemented just because Starshine can round-trip opaque custom sections.
- Do not conflate this pass with [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md), which operates on Binaryen annotation metadata.
- Do not use this pass name for generic custom-section deletion.
- Do not imply that stripping feature metadata lowers or validates unsupported feature use.
- Do not add it to the optimize or shrink preset without a product decision; Binaryen frames it as output metadata cleanup, not an ordinary optimizer.
