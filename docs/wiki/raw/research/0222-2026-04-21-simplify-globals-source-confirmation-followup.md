# Binaryen `simplify-globals` source-confirmation follow-up (`version_129`)

- Date: 2026-04-21
- Pass: `simplify-globals`
- Upstream tag: `version_129`
- Scope: close the remaining compact source-confirmation gap in the existing plain-`simplify-globals` dossier by mapping the real owner files, the public registration split, the pass-runner boundary, and the shipped proof surface.

## Why this pass was chosen

The updated tracker no longer has obvious `none` targets in the main parity queue or the first upstream-only expansion wave.
That made this a justified major-gap follow-up rather than a brand-new dossier.

`simplify-globals` was the best eligible target because:

- it is **not** one of the excluded passes for this thread,
- it already matters to nearby late-global docs (`simplify-globals-optimizing`, `propagate-globals-globally`, `reorder-globals`, `duplicate-import-elimination`, `string-gathering`),
- the current living folder was already good on behavior but still lacked one compact **source-confirmed implementation/test-map page**, and
- the shared `SimplifyGlobals.cpp` family is easy to mis-teach without an explicit owner/test breakdown.

## Required repo context re-read first

I re-read these local orientation docs before doing the follow-up:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

## Backlog slice status

`agent-todo.md` still has **no dedicated plain `simplify-globals` slice**.
It still mentions the optimizing sibling (`simplify-globals-optimizing`) as part of the main no-DWARF and `-O4z` implementation queue, but there is no separate active unreleased slice for the plain public pass.
That absence is worth keeping explicit in the living docs.

## Main source-confirmed findings

## 1. The real implementation lives in one shared file

The real Binaryen `version_129` implementation for the plain pass lives in:

- `src/passes/SimplifyGlobals.cpp`

That file owns the visible plain-pass algorithm:

- `GlobalInfo` collection
- whole-module scanning through both function bodies and module code
- single-use later-global folding
- dead / same-as-init / read-only-to-write write cleanup
- immutable-copy-chain canonicalization
- startup propagation into later globals and active segment offsets
- cheap runtime current-trace propagation in function bodies
- selective `ReFinalize()` after type-refining substitutions

The important corrective point is that the plain pass is **not** a separate small wrapper file.
It is the same large engine family as `simplify-globals-optimizing` and `propagate-globals-globally`, with behavior selected by flags and constructor choice.

## 2. `pass.cpp` proves the public identity split

`src/passes/pass.cpp` is where Binaryen exposes the public pass names.
For this family, `version_129` source confirms three distinct registrations:

- `simplify-globals`
- `simplify-globals-optimizing`
- `propagate-globals-globally`

That matters because the file map proves these are not merely informal aliases.
They are real public pass identities wired to different constructors / modes of the same family.

For the plain pass, the durable beginner correction is:

- `simplify-globals` is a public pass in its own right,
- but its implementation ownership is still the shared `SimplifyGlobals.cpp` family, not a separate `SimplifyGlobalsPlain.cpp`-style file.

## 3. `pass.h` / `PassRunner` confirms the main plain-vs-optimizing boundary

The most important public-contract split is not “different algorithm file,” but “same algorithm family with different runner behavior after rewrites.”

The reviewed sources confirm:

- plain `simplify-globals` runs the global engine and stops,
- `simplify-globals-optimizing` runs the same engine and then invokes a nested default-function optimization rerun on changed functions,
- the pass-runner boundary for that rerun is owned through the normal pass interfaces in `pass.h`, not by some invisible preset-only magic.

This is the key reason the plain dossier still deserved a compact owner/test page even though a sibling dossier already existed.

## 4. Helper ownership is visible and important

The source review reconfirmed the main helper dependencies already described in the behavioral pages:

- `src/ir/effects.h`
  - for `EffectAnalyzer` legality checks, especially `read-only-to-write` body legality and runtime invalidation logic
- `src/ir/find_all.h`
  - for locating owned `GlobalGet` / `GlobalSet` syntax and nested startup rewrite sites
- `src/ir/linear-execution.h`
  - for the cheap runtime current-trace propagation model
- `src/ir/properties.h`
  - for constant-expression and literal-comparison checks
- `src/ir/utils.h`
  - for shared expression / module utility helpers used by the family

The practical teaching consequence is:

- `simplify-globals` is not a dominator-tree pass,
- not a whole-program alias-analysis pass,
- and not a tiny peephole.

It is a whole-module rewrite family that leans on Binaryen’s existing effect, startup-expression, and linear-trace helpers.

## 5. The pass-runner boundary is deliberately lightweight

The source-confirmed owner split also shows that the plain pass does **not** ask for a special generic local-fixup lifecycle in the way some GC- or local-shape passes do.
The family instead handles its own targeted `ReFinalize()` when substitutions refine types.

That is a useful porting clue:

- future Starshine work should keep `simplify-globals` module-shaped and family-shaped,
- and should not silently broaden it into an ordinary hot locals pass just because some rewrites happen inside functions.

## Official shipped test map

The reviewed `version_129` tests show that Binaryen proves the pass through a **cluster** of dedicated late-global files, not one tiny single-pass proof file.

### Dedicated plain-family lit files reviewed

- `test/lit/passes/simplify-globals-single_use.wast`
  - startup-only one-use folding into later global initializers
- `test/lit/passes/simplify-globals-non-init.wast`
  - same-as-init vs truly-non-init write distinctions and dead-write cleanup
- `test/lit/passes/simplify-globals-read_only_to_write.wast`
  - the exact self-guard matcher and its bailout surface
- `test/lit/passes/simplify-globals-dominance.wast`
  - cheap adjacent-block runtime propagation rather than full CFG dominance
- `test/lit/passes/simplify-globals-offsets.wast`
  - startup rewriting of active data / elem offsets
- `test/lit/passes/simplify-globals-nested.wast`
  - nested later-startup-expression rewriting
- `test/lit/passes/simplify-globals-prefer_earlier.wast`
  - immutable-copy-chain canonicalization toward the earliest compatible source
- `test/lit/passes/simplify-globals_func-effects.wast`
  - the difference between actual owned `global.get` / `global.set` syntax and mere effect-summary knowledge
- `test/lit/passes/simplify-globals-gc.wast`
  - GC/reference typing boundaries, including cases that require or block more refined replacement

### Important sibling lit file also reviewed

- `test/lit/passes/propagate-globals-globally.wast`
  - useful because it isolates the startup-only sibling and keeps the shared-family split honest

## What the tests prove together

The lit roster is easiest to teach as four proof buckets:

### A. startup-only proofs

- single-use later-global folding
- nested startup expression rewriting
- active data / elem offset propagation

### B. fake-state cleanup proofs

- dead writes
- same-as-init writes
- read-only-to-write self-guards

### C. runtime cheap-trace proofs

- adjacent-block positives
- call / nonlinear-control barriers

### D. GC / typing proofs

- exact-type compatibility limits on immutable-copy-chain rewrites
- replacements that require refinalization

## What the tests do **not** prove in isolation

The tests are good, but the owner split still matters because no single lit file alone teaches the whole public contract.
Two especially important cross-file lessons still come mainly from the combined source review:

1. the plain pass, optimizing sibling, and startup-only sibling are one **shared implementation family** rather than three unrelated pass files;
2. the main semantic split between plain and optimizing is the nested rerun contract, not a different rewrite engine.

That is why this follow-up page was still needed.

## Beginner-facing corrections this follow-up closes

This follow-up closes four durable teaching gaps in the existing plain `simplify-globals` dossier:

1. **owner-file gap**
   - the real owner file is confirmed as shared `SimplifyGlobals.cpp`, not a standalone plain-pass implementation file.
2. **public-identity gap**
   - `pass.cpp` confirms `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally` are separate public registrations over that same family.
3. **test-map gap**
   - the shipped proof surface is a broad lit cluster with distinct subtopics, not one dedicated “this file proves everything” artifact.
4. **port-shape gap**
   - even though function bodies are rewritten, the real pass remains a whole-module late-global pass with targeted type repair, not a hot-pass locals rewrite.

## Recommended living-doc updates from this note

- Add `docs/wiki/binaryen/passes/simplify-globals/implementation-structure-and-tests.md`.
- Refresh `docs/wiki/binaryen/passes/simplify-globals/index.md` so the new page becomes part of the canonical reading order.
- Refresh the tracker, pass-folder map, wiki index, and log so future threads can see that the plain `simplify-globals` folder no longer has this particular source-confirmation gap.

## Source list

Primary official sources reviewed:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>

Local repo sources reviewed:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/simplify-globals/index.md`
- `docs/wiki/binaryen/passes/simplify-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals/plain-vs-optimizing-and-safety.md`
- `docs/wiki/binaryen/passes/simplify-globals/wat-shapes.md`
