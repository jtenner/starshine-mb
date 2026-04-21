# 0212 - 2026-04-21 - global-struct-inference-desc-cast source-confirmation follow-up

## Scope

This follow-up revisits the existing `global-struct-inference-desc-cast` / upstream `gsi-desc-cast` dossier against official Binaryen `version_129` sources.

The immediate reason for spending another thread on an already-dossiered upstream-only pass is that the current tracker no longer has obvious `none` targets, while the existing `gsi-desc-cast` folder still had a real correctness gap:

- it described the desc-cast sibling as if the cast rewrite reused a trusted-origin analysis on the **cast input value**
- it claimed the reviewed test surface was only the broad shared `gsi.wast` family and that there was no dedicated variant file

The source sweep shows both points needed correction.

## Candidate choice and tracker justification

Chosen pass:

- local registry name: `global-struct-inference-desc-cast`
- upstream public name: `gsi-desc-cast`

Why this pass was eligible:

- it is **not** one of the excluded passes from the thread prompt
- it is already named in the local boundary-only registry in `src/passes/optimize.mbt`
- it was still only a working dossier, not a recently source-confirmed compact page set
- the old dossier still had a meaningful major gap in the exact desc-cast contract and test map

## Agent-todo status

`agent-todo.md` still has **no dedicated `global-struct-inference-desc-cast` / `gsi-desc-cast` slice**.

## Sources reviewed

Primary Binaryen `version_129` sources:

- `src/passes/GlobalStructInference.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/gsi-desc.wast`
- `test/lit/passes/gsi-to-desc-cast.wast`
- `test/lit/passes/gsi.wast`

Freshness-check sources on current `main`:

- `src/passes/GlobalStructInference.cpp`
- `test/lit/passes/gsi-desc.wast`
- `test/lit/passes/gsi-to-desc-cast.wast`
- `test/lit/passes/gsi.wast`

Local repo surfaces reviewed:

- `docs/wiki/binaryen/passes/global-struct-inference-desc-cast/*`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `src/passes/optimize.mbt`
- `agent-todo.md`

## Main corrections

### 1. The desc-cast rewrite does **not** inspect cast-input origin candidates

The existing dossier over-explained `gsi-desc-cast` as if it reused plain GSI's trusted-global candidate analysis on the value being cast.

The actual `visitRefCast(RefCast* curr)` logic in `GlobalStructInference.cpp` is much narrower.

It checks:

1. the pass instance was created with `optimizeToDescCasts = true`
2. the cast result type is not `unreachable`
3. the target heap type has a descriptor type
4. either the target type is exact, or the target heap type has **no strict subtypes**
5. the descriptor heap type appears in `typeGlobals`
6. that descriptor heap type maps to **exactly one** immutable non-imported top-level global

If those gates pass, the rewrite is simply:

- build `global.get $descriptorGlobal`
- replace the original cast with `builder.makeRefCast(curr->ref, getGlobal, curr->type)`

That means the desc-cast-specific proof is driven by a **singleton descriptor global for the target descriptor type**, not by a per-cast-site analysis of the origin of `curr->ref`.

### 2. Closed-world analysis is practically required for desc-cast wins

The pass as a whole still runs in open world and still shares the ordinary plain-`gsi` direct-global fast path.

But the desc-cast-specific rewrite uses only `typeGlobals[descriptorType]`, and `typeGlobals` is populated only in `analyzeClosedWorld(module)`.

So for the desc-cast sibling specifically:

- the pass can be invoked without `--closed-world`
- but the dedicated `ref.cast` -> `ref.cast_desc_eq` rewrite surface does not become available unless closed-world analysis has populated the descriptor-type map

This is narrower than the earlier dossier implied.

### 3. There really are dedicated upstream lit files for the descriptor variant

The earlier dossier claimed the visible reviewed lit surface was only the general `gsi.wast` family and that no dedicated `gsi-desc-cast.wast`-style file had been found.

The source-confirmed `version_129` test tree shows the important dedicated files are actually:

- `test/lit/passes/gsi-desc.wast`
- `test/lit/passes/gsi-to-desc-cast.wast`

What they prove:

- `gsi-desc.wast` is a descriptor-oriented sibling file for ordinary GSI descriptor reads and descriptor un-nesting
- `gsi-to-desc-cast.wast` is the dedicated public lit proof for the **difference between `--gsi` and `--gsi-desc-cast`**

So the earlier “shared `gsi.wast` only” story was incomplete.

### 4. The dedicated desc-cast test surface is richer than the earlier dossier said

`gsi-to-desc-cast.wast` directly proves these concrete families:

- plain `--gsi` leaves ordinary `ref.cast` alone while `--gsi-desc-cast` can emit `ref.cast_desc_eq`
- non-exact casts with relevant strict subtypes stay unoptimized
- exact casts can still be optimized even when the inexact sibling cannot
- unrelated descriptor hierarchies can both optimize
- zero descriptor-instance globals bail out
- multiple descriptor-instance globals bail out
- casts to types without descriptors bail out
- nullable target casts can still optimize
- unreachable cast inputs are preserved as ordinary unreachable-based casts rather than forcing a desc-cast rewrite

The file also contains an explicit TODO-style note that exact `$A` is not optimized in one case because the pass propagates on `typeGlobals`.

## Source-confirmed implementation structure

## Owner file

The entire public sibling still lives in:

- `src/passes/GlobalStructInference.cpp`

Important owner facts:

- the sibling is implemented by `GlobalStructInference(true)`
- plain `gsi` is `GlobalStructInference(false)`
- `requiresNonNullableLocalFixups() == false`
- when `optimizeToDescCasts` is enabled, the pass constructs `SubTypes`
- the main module walk is still the shared `optimize(module)` path
- the desc-cast rewrite is isolated to `visitRefCast`

## Shared and variant-specific walkers

Shared walker work still handles:

- `StructGet`
- `RefGetDesc`
- the ordinary plain-GSI value-grouping / select / un-nesting logic

Variant-specific work adds:

- `visitRefCast`

That variant-specific method does **not** call the ordinary field-read grouping logic.
It only queries the target descriptor singleton map.

## Registration

`pass.cpp` confirms:

- public name `gsi`
- public sibling name `gsi-desc-cast`
- public summary: `globally optimize struct values, also emitting ref.cast_desc_eq`

A narrow `main` freshness check found the same registration surface.

## Dedicated test map

### `gsi-to-desc-cast.wast`

This is the most important dedicated test file for the sibling.
It directly checks the delta between:

- `wasm-opt --gsi`
- `wasm-opt --gsi-desc-cast`

### `gsi-desc.wast`

This file is still relevant, but for a different reason than the old dossier claimed.
It proves descriptor-oriented plain-GSI surfaces such as:

- `ref.get_desc` specialization
- descriptor-value selection
- descriptor un-nesting into fresh globals

That shared machinery matters because the desc-cast variant still reuses the same engine and `typeGlobals` population.

### `gsi.wast`

`gsi.wast` remains part of the broader family, but it is no longer the best way to describe the variant's dedicated proof surface.

## Current-main freshness result

The checked current-`main` sources still match `version_129` for the reviewed desc-cast surfaces.

Observed drift:

- only comment typo fixes in `GlobalStructInference.cpp`
- no reviewed logic change in `visitRefCast`
- no reviewed changes in `gsi-desc.wast`
- no reviewed changes in `gsi-to-desc-cast.wast`

## Durable conclusions for the wiki

1. `gsi-desc-cast` is a real public upstream pass, not just a hidden mode.
2. It shares the owning `GlobalStructInference.cpp` engine with plain `gsi`.
3. Its desc-cast-specific rewrite is **narrower** than the old dossier implied.
4. The decisive proof is a **singleton descriptor global for the target descriptor type**.
5. The desc-cast-specific rewrite surface is therefore effectively **closed-world dependent**.
6. The variant has dedicated lit evidence in `gsi-to-desc-cast.wast`, plus closely related descriptor-family evidence in `gsi-desc.wast`.
7. Current `main` still matches the reviewed `version_129` implementation and dedicated tests on the inspected surfaces.

## Wiki actions taken

This follow-up:

- refreshed the `global-struct-inference-desc-cast` landing page
- rewrote the strategy page to correct the cast-specific contract
- rewrote the implementation/test-map page with the real dedicated lit files
- rewrote the WAT-shapes page around target-descriptor-singleton gates instead of cast-input-origin stories
- added a dedicated living page for the singleton-descriptor gate and exact test surfaces
- updated the shared Binaryen pass tracker and indexes
- appended the wiki log

## Open questions left explicit

- The dedicated tests still show a TODO-like limitation around one exact-cast case because the pass propagates on `typeGlobals`; this follow-up records that as part of the upstream contract rather than smoothing it away.
- The pass comment itself notes a possible code-size tradeoff and asks whether the rewrite should only run at `shrinkLevel == 0`; the public implementation does not currently gate it that way.

## Source links

- Binaryen `version_129` `GlobalStructInference.cpp`:
  <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- Binaryen `version_129` `pass.cpp`:
  <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `gsi-desc.wast`:
  <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-desc.wast>
- Binaryen `version_129` `gsi-to-desc-cast.wast`:
  <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi-to-desc-cast.wast>
- Binaryen `version_129` `gsi.wast`:
  <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
- Binaryen current `main` `GlobalStructInference.cpp`:
  <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
- Binaryen current `main` `gsi-desc.wast`:
  <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-desc.wast>
- Binaryen current `main` `gsi-to-desc-cast.wast`:
  <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-to-desc-cast.wast>
- Local boundary-only registry surface:
  [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- Current tracker:
  [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md)
