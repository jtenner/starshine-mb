---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md
  - ../../../raw/research/0292-2026-04-24-legalize-and-prune-js-interface-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/tests.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/module_wast.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../agent-todo.md
  - ../legalize-js-interface/starshine-strategy.md
  - ../i64-to-i32-lowering/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./prune-boundary-matrix.md
  - ./wat-shapes.md
  - ../legalize-js-interface/index.md
  - ../legalize-js-interface/starshine-strategy.md
  - ../i64-to-i32-lowering/index.md
---

# Starshine Strategy For `legalize-and-prune-js-interface`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md).
The goal here is not to re-explain upstream Binaryen; it is to make the exact current Starshine status and future port surface easy to follow.

## The honest current status

`legalize-and-prune-js-interface` is currently **upstream-only** for Starshine.
There is no `src/passes/legalize_and_prune_js_interface.mbt`, no shared JS-interface owner file, and no module pass that stubs illegal JS-boundary imports or removes illegal JS-boundary exports.

The status is stronger than ordinary “not implemented”:

- `src/passes/optimize.mbt` does **not** list `legalize-and-prune-js-interface` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt` does **not** list `legalize-and-prune-js-interface` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` also does not list the plain `legalize-js-interface` spelling.
- A requested `--pass legalize-and-prune-js-interface` therefore follows the unknown-pass path rather than the boundary-only or removed-pass rejection path.
- `agent-todo.md` has no dedicated `legalize-and-prune-js-interface` slice.

So this page is a **status-and-port-planning** bridge, not an implementation page.

## Exact local code map today

The fastest read-along path through the current local status is:

- pass registry omission and request behavior
  - [`src/passes/optimize.mbt#L111-L141`](../../../../../src/passes/optimize.mbt#L111-L141)
    - boundary-only names include nearby ABI/layout passes such as `i64-to-i32-lowering`, but omit both `legalize-js-interface` and `legalize-and-prune-js-interface`
  - [`src/passes/optimize.mbt#L144-L154`](../../../../../src/passes/optimize.mbt#L144-L154)
    - removed names also omit both JS-interface pass names
  - [`src/passes/optimize.mbt#L445-L455`](../../../../../src/passes/optimize.mbt#L445-L455)
    - unknown names produce `unknown pass flag ...`
  - [`src/passes/optimize.mbt#L456-L465`](../../../../../src/passes/optimize.mbt#L456-L465)
    - boundary-only and removed names have distinct explicit rejection paths, which this pass does not reach today
  - [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
    - registry classification tests cover active, module, boundary-only, and removed examples, but not this pass family yet
- module boundary representation that a future prune pass would mutate
  - [`src/lib/types.mbt#L139-L153`](../../../../../src/lib/types.mbt#L139-L153)
    - `FuncCompType` / `FuncType` model params and results, including the multivalue-result surface Binaryen prunes
  - [`src/lib/types.mbt#L168-L185`](../../../../../src/lib/types.mbt#L168-L185)
    - `TagType`, `GlobalType`, and `ExternType` include the tag/global/function boundary kinds relevant to JS-hostility checks
  - [`src/lib/types.mbt#L218-L227`](../../../../../src/lib/types.mbt#L218-L227)
    - `Import`, `Global`, and `Export` are the exact module records the prune pass would convert or delete from visibility
  - [`src/lib/types.mbt#L351-L369`](../../../../../src/lib/types.mbt#L351-L369)
    - `Module` owns `type_sec`, `import_sec`, `tag_sec`, `global_sec`, `export_sec`, and `code_sec`, so a future module pass can edit all prune surfaces together
  - [`src/lib/types.mbt#L416-L463`](../../../../../src/lib/types.mbt#L416-L463)
    - `FuncType`, `TypeSec`, `ImportSec`, `FuncSec`, and `ExportSec` are the section-level pieces needed for wrapper/stub generation
- unsupported-boundary feature vocabulary already represented elsewhere in the repo
  - [`src/wast/types.mbt#L167-L168`](../../../../../src/wast/types.mbt#L167-L168)
    - textual WAST type support includes `V128`
  - [`src/wast/types.mbt#L223-L226`](../../../../../src/wast/types.mbt#L223-L226)
    - WAST instruction tags include EH-ish `Throw`, `ThrowRef`, and `TryTable` terms
  - [`src/lib/types.mbt#L531-L1045`](../../../../../src/lib/types.mbt#L531-L1045)
    - the library IR contains broad SIMD instruction tags, but no JS-boundary pruning pass consumes them today
- binary encode/decode support for the module sections a future pass would repair
  - [`src/binary/encode.mbt#L1138-L1178`](../../../../../src/binary/encode.mbt#L1138-L1178)
    - encodes import sections and function extern types
  - [`src/binary/encode.mbt#L1338-L1340`](../../../../../src/binary/encode.mbt#L1338-L1340)
    - encodes export sections
  - [`src/binary/decode.mbt#L2132-L2137`](../../../../../src/binary/decode.mbt#L2132-L2137)
    - decodes import sections
  - [`src/binary/decode.mbt#L2303-L2308`](../../../../../src/binary/decode.mbt#L2303-L2308)
    - decodes export sections
  - [`src/binary/tests.mbt#L586-L608`](../../../../../src/binary/tests.mbt#L586-L608)
    - fuzz-roundtrips import and export sections
- WAT import/export and `ref.func` surfaces inherited from the plain sibling's future-port map
  - [`src/wast/keywords.mbt#L30-L31`](../../../../../src/wast/keywords.mbt#L30-L31)
    - recognizes textual `import` and `export`
  - [`src/wast/keywords.mbt#L98`](../../../../../src/wast/keywords.mbt#L98)
    - recognizes textual `ref.func`
  - [`src/wast/module_wast.mbt#L424`](../../../../../src/wast/module_wast.mbt#L424)
    - prints `ref.func` with the current function index/name
  - [`src/wast/module_wast.mbt#L857-L934`](../../../../../src/wast/module_wast.mbt#L857-L934)
    - prints import and export fields
  - [`src/wast/lower_to_lib.mbt#L172-L176`](../../../../../src/wast/lower_to_lib.mbt#L172-L176)
    - recognizes element items that are `ref.func`, one of the reference-repair surfaces the inherited plain pass would update
  - [`src/wast/module_wast_tests.mbt#L119-L136`](../../../../../src/wast/module_wast_tests.mbt#L119-L136)
    - roundtrips a table element with `ref.func`, showing the textual path exists even though no JS-interface rewrite uses it today
- neighboring docs
  - [`../legalize-js-interface/starshine-strategy.md`](../legalize-js-interface/starshine-strategy.md)
    - maps the plain sibling's missing wrapper / temp-ret / `ref.func` repair surface
  - [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)
    - whole-module internal `i64` pair lowering; this is deliberately not the same phase as JS-boundary legalization or prune-mode boundary sanitization

That map is the durable local truth today: Starshine has module, section, WAT, and binary data structures that a future implementation would mutate, but no pass-level owner, registry promise, or prune-specific algorithm.

## What Starshine currently does not do

Current Starshine does not yet:

- preserve the public pass spelling `legalize-and-prune-js-interface` in the registry
- preserve the plain public spelling `legalize-js-interface`
- run ordinary JS-boundary `i64` legalization before pruning
- classify JS-hostile boundary types by SIMD, multivalue result, exception handling, or stack switching feature use
- convert illegal imports into internal defined functions
- synthesize `nop` bodies for illegal imports with no result
- synthesize zero/default literal bodies for illegal imports with defaultable results
- synthesize `unreachable` bodies for illegal imports with nondefaultable results
- remove illegal function exports while keeping the function body
- handle the imported-and-exported combined case by doing both actions
- refinalize or run an equivalent type/reference repair after changing imports into defined functions
- remove illegal global exports while keeping the global
- compare against Binaryen's dedicated `legalize-and-prune-js-interface.wast` fixture

Those are the differences from [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./prune-boundary-matrix.md`](./prune-boundary-matrix.md), and [`./wat-shapes.md`](./wat-shapes.md).

## Why this is not plain `legalize-js-interface`

The sibling split must stay explicit:

- [`../legalize-js-interface/index.md`](../legalize-js-interface/index.md) teaches **adaptation**: wrap `i64` JS-boundary imports and exports.
- `legalize-and-prune-js-interface` teaches **adapt where possible, then sanitize**: run the plain pass, then stub imports or hide exports that still expose JS-hostile features.

A future Starshine implementation should therefore not add only one registry name and silently fold the other into it unless the docs, tests, and CLI behavior intentionally describe that local divergence.

## Why this is not `i64-to-i32-lowering`

See [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md).

The important split is:

- `legalize-js-interface` = JS-boundary adapter wrappers around imports and exports
- `legalize-and-prune-js-interface` = those wrappers plus boundary stubbing/export hiding for still-hostile JS surfaces
- `i64-to-i32-lowering` = whole-module internal `i64` pair lowering after other prerequisites such as flattening

A future implementation should not hide the prune sibling inside `i64-to-i32-lowering` unless the registry, docs, and validation tests explicitly say the local pass has intentionally merged those Binaryen phases.

## Likely future landing shape

A faithful Starshine port would be a **module/boundary pass**, not a HOT peephole.
The pass must update imports, function definitions, exports, globals, types, and function-reference users together.

A safe implementation ladder would be:

1. choose the registry policy first:
   - keep the names unknown until implemented, or
   - add boundary-only entries plus tests that reject them honestly
2. implement or import the plain `legalize-js-interface` behavior before enabling prune mode
3. add focused fixtures for the prune matrix:
   - no-result import -> `nop`
   - defaultable result import -> zero/default
   - nondefaultable result import -> `unreachable`
   - exported illegal function -> export removal only
   - imported-and-exported illegal function -> stub plus export removal
   - illegal global export -> export removal only
4. implement the feature classifier separately from the `i64` classifier
5. add the import-to-definition rewrite and export deletion as separate phases so the combined case stays easy to inspect
6. implement validation/refinalization or an equivalent type/reference repair after function pruning
7. compare the dedicated Binaryen fixture before any broad fuzzing

## Validation plan for an eventual port

A future port should validate in layers:

1. registry behavior
   - prove whether the names are unknown, boundary-only, removed, or implemented
   - keep the prune sibling separate from plain legalization
2. inherited plain legalization
   - prove wrapper/temp-ret/reference-repair behavior via the plain sibling's fixture set
3. feature classifier
   - prove SIMD, multivalue result, EH, and stack-switching boundary classification
   - prove multivalue params do not accidentally trigger the result-only bailout
4. import stubs
   - prove `nop`, zero/default, and `unreachable` cases separately
5. export removal
   - prove function export and global export removal without deleting the underlying item
6. combined boundary case
   - prove an imported-and-exported illegal function is both stubbed and unexported
7. repair and validation
   - prove no stale function indices, type indices, or `ref.func` users remain after import-to-definition conversion

## Bottom line

Current Starshine `legalize-and-prune-js-interface` strategy is honest non-adoption plus a precise future bridge:

- no local pass registry entry today
- no owner file today
- no active backlog slice today
- existing module/import/export/global/type/ref.func data structures are the natural substrate for a future module pass
- the pass must remain separate from both plain JS-boundary `i64` legalization and whole-module `i64-to-i32-lowering` unless a future design intentionally merges those phases
- a faithful future port must preserve Binaryen's asymmetric prune matrix and post-function-prune repair boundary

For upstream behavior, read [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./prune-boundary-matrix.md`](./prune-boundary-matrix.md), and [`./wat-shapes.md`](./wat-shapes.md).
