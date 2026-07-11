# Binaryen `abstract-type-refining`: v130 source and local-admission recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source and local-interface refresh for `docs/wiki/binaryen/passes/abstract-type-refining/`

## Scope

This capture refreshes two claims that had aged independently:

1. the upstream algorithm should be grounded in the newest reviewed tagged Binaryen source, `version_130`, rather than only `version_129`; and
2. a `compare-pass` command is not evidence while Starshine and its harness reject the pass.

It does **not** replace the older `version_129` manifest or research notes. Those remain historical provenance for the detailed creation-evidence, TNH, exact-cast, and descriptor analysis.

## Primary sources reread

### Binaryen `version_130`

- Owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/AbstractTypeRefining.cpp>
- Registration / scheduler: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Main fixture: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/abstract-type-refining.wast>
- Descriptor fixture: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/abstract-type-refining-desc.wast>
- Exact-cast fixture: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/abstract-type-refining-exact.wast>
- TNH exact-cast fixture: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
- Continuation regression: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/abstract-type-refining-cont.wast>

### Binaryen `main` routes retained for a later direct checkout recheck

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AbstractTypeRefining.cpp>
- Registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Main fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/abstract-type-refining.wast>
- Private-type helper: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- Type-rewrite helper: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Starshine local admission evidence

- Boundary-only roster: `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()`
- No pass owner: no `src/passes/abstract_type_refining.mbt` exists under `src/passes/`
- Compare harness allowlist: `scripts/lib/pass-fuzz-compare-task.ts`, `SUPPORTED_PASS_FLAGS`

## Tagged-source result

The reviewed `version_130` owner preserves the already-documented semantic contract:

- GC is required and `closedWorld` is a hard pass precondition.
- Creation evidence comes from `struct.new*` scanning plus conservative public-type treatment.
- Fully never-created struct families can bottomize without TNH.
- Parent-to-unique-live-child refinement is TNH-only.
- Exact casts and descriptor-sensitive instructions are preoptimized before the global type rewrite.
- Declared subtype-edge cleanup remains outside this pass and belongs to `unsubtyping`.
- The public pass remains an explicit closed-world GC/type-cluster pass, not an ordinary default `-O` / `-Os` slot.

No behavior-bearing `version_129` to `version_130` change was established on those reviewed owner and fixture routes.

## Current-`main` certainty boundary

The web retrieval available for this review yielded an internally inconsistent `main` API snapshot: the fetched owner route showed an older-looking no-`worldMode` helper-call shape, while the fetched `main` helper declaration required `WorldMode`. That pair cannot compile together, so it is not safe evidence for either a Binaryen semantic regression or a current-main no-drift claim.

Accordingly:

- this capture **does not** claim byte or behavior equality between `version_130` and current `main`;
- living pages may use `version_130` as the reviewed tagged contract; and
- a future implementation/signoff investigation must recheck a single pinned current-main checkout (owner, `module-utils`, `type-updating`, registration, and the full fixture roster together) before asserting main-specific behavior.

This is an evidence-quality caveat, not a claim that the pass behavior changed upstream.

## Local fuzzing result

Starshine has no executable counterpart today:

- `abstract-type-refining` is boundary-only in `src/passes/optimize.mbt`;
- it is absent from `SUPPORTED_PASS_FLAGS`; and
- there is no local owner or dispatcher case.

Therefore `bun fuzz compare-pass --pass abstract-type-refining ...` fails before generation/comparison. It is useful only as a negative interface check, never as a smoke lane or parity evidence. A future lane needs all of: active registry/dispatcher implementation, harness admission, focused closed-world GC fixtures, and explicit comparable-case/failure policy.

## Consumability rule

Use this capture for the `version_130` source floor, current-main uncertainty boundary, and planned-only fuzzing status. Use the older raw manifest and research notes for the detailed algorithm. Do not silently convert the current-main evidence gap into a no-drift claim.
