---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md
  - ../../../raw/research/0429-2026-04-27-strip-target-features-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/research/0390-2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/validate.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../strip-toolchain-annotations/index.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# Starshine strategy for `strip-target-features`

## Current local status

Starshine currently has **no `strip-target-features` implementation**. This page is therefore a status and future-port map, not a description of a shipped transform.

The exact local status is:

- `src/passes/optimize.mbt` has no `strip-target-features` or `emit-target-features` entry in the boundary-only or removed registry-name arrays.
- `src/passes/optimize.mbt` has no active `HotPass` or `ModulePass` entry for either name in `pass_registry_entries()`.
- `run_hot_pipeline_expand_passes(...)` reports unknown names as `unknown pass flag ...`, so explicit `strip-target-features` and `emit-target-features` requests currently fail as unknown rather than boundary-only or removed.
- `agent-todo.md` has no dedicated backlog slice for the pass.

That means Starshine's present strategy is **non-adoption plus documentation**. The wiki tracks the upstream pass because Binaryen exposes it publicly and because the late-pass chronology had already mentioned it without a canonical dossier.

## Exact local code locations to read first

- `src/passes/optimize.mbt:127-139`
  - boundary-only registry names; `strip-target-features` and `emit-target-features` are absent.
- `src/passes/optimize.mbt:143-152`
  - removed registry names; both names are absent.
- `src/passes/optimize.mbt:153-292`
  - active hot/module/preset registry construction; no target-feature metadata entry exists.
- `src/passes/optimize.mbt:474-490`
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
  - module encoding writes `custom_secs` before ordinary sections and later emits the name section specially; there is no Binaryen-like `hasFeaturesSection` flag in this path.
- `src/validate/validate.mbt:2284-2291`
  - validation rejects raw `name` custom sections in `custom_secs`, but has no target-features semantics.

## Why there is no straightforward Binaryen-style port today

Binaryen's shared strip/emit owner toggles module metadata from its mode bit:

```text
module->hasFeaturesSection = !isStripped
```

For `strip-target-features`, `isStripped` is true, so this clears `hasFeaturesSection`.

Starshine's visible local model is different:

- arbitrary custom sections are stored after decode as `Module.custom_secs`;
- the binary encoder writes those stored custom sections back out;
- there is no first-class target-feature section model;
- there is no `hasFeaturesSection` flag or pass-runner output option matching Binaryen's representation;
- there is no current registry status for the pass.

So a Starshine port has an architecture decision before any code change:

1. add first-class target-feature metadata and clear that metadata in a module pass;
2. implement a module pass that deletes opaque `CustomSec(Name::new("target_features"), ...)` entries from decoded modules;
3. add only a boundary-only or removed registry compatibility entry;
4. continue treating the pass as unknown and leave this as documented upstream-only behavior; and
5. decide whether sibling `emit-target-features` gets parallel status or remains explicitly unsupported.

Option 2 may be useful, but it is not exactly Binaryen's implementation strategy. See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) for the validation ladder and safe first slices.

## If Starshine ever ports it

A faithful local port should be a **module/output metadata pass**, not a HOT peephole.

Minimum acceptance criteria:

- choose a public status deliberately: active module pass, boundary-only compatibility entry, removed compatibility entry, or continued unknown-name rejection;
- document the sibling `emit-target-features` status at the same time;
- define whether the pass owns first-class target-feature metadata, decoded opaque custom sections, or both;
- remove or suppress only target-features metadata;
- preserve arbitrary other custom sections, including `name` / producers-like metadata if present in the chosen representation;
- leave all executable module sections unchanged;
- keep the pass out of optimize/shrink presets unless a separate user-facing policy wants metadata stripping;
- add tests for absent section, preserved non-target custom sections, and no executable IR mutation.

## Non-goals today

- Do not mark the pass as implemented just because Starshine can round-trip opaque custom sections.
- Do not conflate this pass with [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md), which operates on Binaryen annotation metadata.
- Do not use this pass name for generic custom-section deletion.
- Do not imply that stripping feature metadata lowers or validates unsupported feature use.
- Do not add it to the optimize or shrink preset without a product decision; Binaryen frames it as output metadata cleanup, not an ordinary optimizer.
