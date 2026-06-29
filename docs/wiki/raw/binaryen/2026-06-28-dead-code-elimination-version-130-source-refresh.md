# Binaryen `dead-code-elimination` `version_130` source/lit refresh

_Capture date:_ 2026-06-28
_Status:_ immutable source/lit refresh and audit matrix seed for `[O4Z-AUDIT-DCE]`

## Scope

This note refreshes the DCE audit baseline from the older `version_129` dossier to Binaryen `version_130`, the repo's current release-oracle baseline for new pass research. It is a source/docs inventory only: no Starshine, Moon, Binaryen, or compare-pass validation was run for this source-refresh slice.

## Official primary sources opened

Core owner and registration:

- `src/passes/DeadCodeElimination.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadCodeElimination.cpp>
- raw owner source opened during this slice: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/DeadCodeElimination.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `src/passes/passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/passes.h>

Helper surfaces semantically referenced by `DeadCodeElimination.cpp`:

- `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/properties.h>
- `src/ir/type-updating.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/type-updating.h>
- `src/ir/eh-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/eh-utils.h>

Dedicated lit roster re-anchored at `version_130`:

- `test/lit/passes/dce_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce_all-features.wast>
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce_vacuum_remove-unused-names.wast>
- `test/lit/passes/dce-eh.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh.wast>
- `test/lit/passes/dce-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh-legacy.wast>
- `test/lit/passes/dce-stack-switching.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-stack-switching.wast>

A temporary local copy of those files was written under `.tmp/dce-v130/` only to inspect line counts and search the source; it is not durable evidence and should not be committed.

## Version_130 source-shape observations

Binaryen `version_130` keeps the same small public DCE shape documented in the earlier Starshine wiki pages:

- the pass remains a function-parallel postwalk;
- the contract is still centered on `TypeUpdater`, not an effect-driven general dead-result optimizer;
- non-control expressions with an unreachable child preserve already-executed prefix children as `drop`s, keep the first unreachable child, and remove later children;
- `block` trims suffix children after the first unreachable child, may collapse a lone literal `unreachable`, and may change the block type to `unreachable` when no breaks target it;
- `if` with unreachable condition becomes the condition, and resultful `if` with both arms unreachable changes type to `unreachable`;
- `loop` with a literal `unreachable` body is replaced by that body;
- legacy `try` changes type to `unreachable` when the body and all catches are unreachable;
- modern `try_table` changes type to `unreachable` when its body is unreachable;
- the only explicit EH repair hook remains the conservative end-of-function `EHUtils::handleBlockNestedPops(...)` call when a function contains `pop` and this DCE run added a block.

The source has not grown into the broad local Starshine rewrite family. Therefore `[O4Z-AUDIT-DCE]` must audit both directions:

1. **Binaryen target coverage**: every small upstream DCE family above is covered by Starshine tests and compare evidence.
2. **Starshine extra rewrites**: local HOT-only DCE rewrites such as payload-forwarder cleanup, split local.set wrapper rewriting, nonfallthrough tail repair, raw-skip decisions, and writeback guards are classified as semantic-safe, Starshine-win, size-losing, parity gap, validation hazard, or explicit non-goal.

## Source visitor / helper matrix

| Binaryen `version_130` source family | Required Starshine audit classification |
| --- | --- |
| Registration and direct pass spelling (`dce` upstream, `dead-code-elimination` Starshine) | Confirm compare harness maps direct pass to Binaryen `--dce`; registry and CLI tests remain current. |
| Function-parallel postwalk and `TypeUpdater` bookkeeping | Confirm Starshine's HOT pass and pass-manager invalidation/verification give equivalent valid output; document any intentional shape divergence. |
| Non-control expression with first unreachable child | Add/refresh fixtures for prefix drop preservation, first-unreachable retention, later-child deletion, and multi-preserved-child block materialization. |
| `block` suffix trim after first unreachable child | Add/refresh fixtures for suffix deletion, single literal `unreachable` collapse, targeted-block no-type-change boundary, and no-target type-to-unreachable behavior. |
| `if` unreachable condition | Add/refresh fixture proving arms are removed and condition/effects/trap are preserved. |
| `if` both arms unreachable | Add/refresh typed result fixture proving type-to-unreachable behavior without losing branch/throw effects. |
| `loop` literal unreachable body | Add/refresh positive fixture and loop-backedge / branch-to-loop boundary negatives. |
| Legacy `try` all arms unreachable | Classify local text/HOT support. If legacy `try` lowers away locally, document this as a text-surface boundary and cover equivalent core if possible. |
| Modern `try_table` unreachable body | Add/refresh positive and reachable-catch boundary fixtures; preserve `catch_ref` / `catch_all_ref` payload semantics. |
| `Pop` detection plus `EHUtils::handleBlockNestedPops` when DCE added a block | Classify as unsupported/local-surface boundary unless Starshine has an equivalent `pop` representation; use EH lit expectations and validator behavior to choose tests. |
| Stack-switching `resume` / `resume_throw` label-liveness cases | Starshine likely lacks stack-switching core support; classify as proposal/tool boundary rather than silently ignoring. Reopen when stack-switching enters local representation. |

## Lit-family matrix

| Lit file | Upstream proof role | Starshine audit owner |
| --- | --- | --- |
| `dce_all-features.wast` | Broad ordinary expression/control unreachable cleanup, prefix drops, block/if/loop behavior, and type changes. | `[O4Z-AUDIT-DCE-A/B/C]` source matrix, tests, and direct compare classification. |
| `dce_vacuum_remove-unused-names.wast` | Confirms intended neighborhood with `vacuum` and `remove-unused-names`. | `[O4Z-AUDIT-DCE-D]` ordered-neighborhood replay/classification. |
| `dce-eh.wast` | Modern `try_table`, `throw`, and `throw_ref` cleanup and preservation. | `[O4Z-AUDIT-DCE-C]` EH/try_table surface. |
| `dce-eh-legacy.wast` | Legacy `try`, `rethrow`, `pop`/nested-pop repair, and legacy EH behavior. | `[O4Z-AUDIT-DCE-C]` with local text/HOT boundary classification. |
| `dce-stack-switching.wast` | Stack-switching `resume`/`resume_throw` label-liveness; do not erase block result type when handler can branch there. | `[O4Z-AUDIT-DCE-C]` as likely unsupported proposal/local-representation boundary unless local support exists. |

## Immediate audit implications

- The direct DCE target is small enough for a full source-backed matrix, but Starshine's local owner file is larger than upstream; the audit must classify Starshine-only transformations explicitly instead of assuming they are Binaryen parity.
- A dedicated GenValid profile is required. The profile should produce reachable modules with at least one DCE trigger and record `selected_profile` / `profile_case_label` metadata for non-control-unreachable, block-suffix, if-condition, if-both-arms, loop-body, EH/try_table, neighborhood-cleanup, raw-gate, and Starshine-extra-wrapper families.
- Final closeout should use Binaryen `version_130` oracle via `wasm-opt --version`, the full four-lane pass signoff matrix from `.pi/skills/starshine-pass-implementation/SKILL.md`, and a DCE-specific dedicated profile such as `dead-code-elimination-all` once implemented.
