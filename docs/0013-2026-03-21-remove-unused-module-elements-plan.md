# RemoveUnusedModuleElements Plan

Status: researched rollout plan for Starshine's index-based IR.

## Scope
- Implement `OptimizePass::RemoveUnusedModuleElements` in `src/optimization/optimization.mbt`.
- Match default open-world behavior first, then add closed-world and GC precision where local infrastructure supports it.
- Keep the plan aligned with current `Module`, `ModuleTransformer`, `NameSec`, and generated pipeline behavior.

## Document Cross-Reference Map
- `ALG-00 Three-state model`: `0012` lines 1-16, 381-386, 469-495, 1460-1474.
  - `unreferenced` can be removed.
  - `referenced but not used` must remain valid.
  - defined functions in that middle state keep identity and drop to `unreachable`.
- `ALG-01 Tracked universe`: `0012` lines 27-40.
  - module elements are tracked by kind plus identity.
- `ALG-02 Analyzer fixed-point`: `0012` lines 43-69, 480-495, 782-792, 1435-1460.
  - alternating expression and module queues drive the analysis.
- `ALG-03 Expression noter`: `0012` lines 72-103, 530-533.
  - expression scanning records uses, references, call-ref types, ref.funcs, struct-field reads, and indirect calls.
- `ALG-04 Direct-call semantics`: `0012` lines 113-133, 573-603.
  - direct calls are strong uses.
  - intrinsic-style callable wrappers are special-case logic, currently deferred locally unless Starshine gains equivalents.
- `ALG-05 Indirect-call semantics`: `0012` lines 136-158, 616-620, 775, 936, 1445, 1472.
  - indirect calls reference tables, resolve table/type facts, and may promote callable signatures.
- `ALG-06 Function-reference handshake`: `0012` lines 169-201, 427, 646, 717-733, 889, 945-969, 1472.
  - `ref.func` alone is weak in closed world.
  - `call_ref` alone contributes only type facts.
  - executable use appears when those facts meet.
- `ALG-07 Struct-field laziness`: `0012` lines 214-250, 668, 749, 1130, 1474.
  - writes are deferred until field reads prove payload relevance.
- `ALG-08 Module expansion`: `0012` lines 260-307.
  - used module elements fan out into bodies, initializers, segments, and related operands.
- `ALG-09 Table precompute`: `0012` lines 309-320, 807-814.
  - precompute table-to-function and table-to-segment facts for indirect-call resolution.
- `ALG-10 Root discovery`: `0012` lines 324-360, 411-417, 439, 454, 469, 1230-1325.
  - roots include exports, non-empty start, optional root-all-functions mode, observable active segments, and maybe-trapping initializers.
- `ALG-11 Removal and shell rewrite`: `0012` lines 381-386, 1221, 1325-1360, 1460.
  - delete anything neither used nor referenced.
  - keep referenced-only functions and rewrite bodies to `unreachable`.
- `ALG-12 Disabled top-level prepare`: `0012` lines 394-404, 1371.
  - export-retarget trampoline optimization exists upstream but is disabled there and deferred here.
- `ALG-13 Trap-root helper`: `0012` lines 353-360, 1311-1315, 1396-1400.
  - maybe-trapping constant initializers are explicit roots when traps may happen.
- `ALG-14 Factory variants`: `0012` lines 1225, 1254, 1416-1426.
  - normal mode and root-all-functions variant have different root policy.

## Current Local State
- `OptimizePass::RemoveUnusedModuleElements` is already scheduled in:
  - global pre-passes,
  - closed-world GC pre-passes,
  - and global post-passes.
- Dispatch now routes to a real open-world function-only implementation.
- Module-wide pass execution now receives `PipelineFeatures` at runtime.
- Generated optimize runs now derive:
  - `has_gc` and `has_multivalue` from the decoded module,
  - `closed_world`, `low_memory_unused`, and `traps_never_happen` from `OptimizeOptions`,
  - and currently leave `has_strings` false because Starshine does not yet model string instructions in IR.
- The currently landed behavior is still intentionally conservative, but no longer function-only:
  - roots exported and start functions,
  - keeps active elem/data segments only when their target table or memory is imported or otherwise live,
  - roots active elem/data segments whose offsets are unknown or whose constant writes exceed the defined target's initial bounds when traps may happen,
  - lets non-mutated indirect-call tables keep only matching active elem contributors instead of every active elem on the table,
  - no longer treats `table.size` and pure table writes as observing prior active elem contents,
  - only scans table initializer expressions when table contents are actually observable or when the table participates in indirect calls,
  - roots exported globals/tables/memories/tags and preserves functions/global/table/memory/tag operands named by surviving module elements and active segments that remain in the module,
  - walks only live function bodies,
  - removes unreachable defined functions, unused defined globals/tables/memories/tags, unused passive/declarative elem segments, and passive data segments,
  - in closed world, treats bare `ref.func` as reference-only until matching `call_ref` / `return_call_ref` evidence appears and rewrites referenced-only defined function bodies to `unreachable`,
  - rewrites function/local, global, table, memory, tag, elem, and data name maps plus `DataCntSec`,
  - and still lacks the mutated-indirect callable-signature model plus the later GC payload-precision slice.
- Test coverage now includes explicit edge regressions for:
  - idempotence,
  - dead global/table initializer non-roots,
  - dead active-segment target removal,
  - imported/exported active-segment observability,
  - unknown-offset and out-of-bounds active-segment trap roots,
  - non-mutated indirect-call segment filtering,
  - table metadata and pure writes no longer pin dead active elem contents,
  - non-observable live tables no longer pin table initializer helpers,
  - conservative fallback once the live code mutates the indirect-call table,
  - active segment mode remaps,
  - and mixed import+defined remaps for every currently landed index kind.
- Starshine IR is index-based, not name-based:
  - funcs, tables, memories, globals, and tags live in mixed import+defined index spaces,
  - elem and data segments live in section-local index spaces.
- `ModuleTransformer` already exposes rewrite hooks for:
  - `FuncIdx`,
  - `GlobalIdx`,
  - `TableIdx`,
  - `MemIdx`,
  - `TagIdx`,
  - `ElemIdx`,
  - `DataIdx`.

## Correctness Constraints
- Never delete semantically reachable entities.
- Exports and non-empty start functions are hard roots.
- Active segments with externally visible writes or possible traps must remain.
- Any compaction must rewrite:
  - instruction indices,
  - export and start sections,
  - elem/data/table/global initializers,
  - name-section maps,
  - and `DataCntSec`.
- Referenced-but-not-used defined functions must keep identity; only the body may become `unreachable`.
- In open world, `ref.func` must stay conservative until there is execution-time `closed_world` support.
- Do not claim export-pruning or wasm-metadce behavior.

## Slice Plan

### Slice 0 — Execution Plumbing and Red Tests
- References:
  - `ALG-10`, `ALG-11`, `ALG-14`.
- Status:
  - complete.
- Add `run_remove_unused_module_elements(mod, global)` and route `OptimizePass::RemoveUnusedModuleElements` to it.
- Add `src/optimization/remove_unused_module_elements_wbtest.mbt` with failing tests that prove the current noop is replaced.
- Decide execution config strategy:
  - MVP: open-world only, no new props.
  - Follow-up: complete generated optimize feature-source plumbing for module-derived `has_gc` / `has_multivalue` and option-driven `closed_world`.
- Exit when the pass has a real entrypoint and red tests exist before analysis logic lands.

### Slice 1 — Module-Element Index and Remap Foundation
- References:
  - `ALG-01`, `ALG-08`, `ALG-11`.
- Status:
  - partial.
  - landed subset: mixed-space `GlobalIdx`/`TableIdx`/`MemIdx`/`TagIdx` remap, section-local `ElemIdx`/`DataIdx` remap, exports plus `global.get`/`table.size`/`memory.size`/`throw`/`catch` and `table.init`/`elem.drop`/`memory.init`/`data.drop` rewrite coverage, `global`/`table`/`memory`/`tag`/`elem`/`data` name-map compaction, and `DataCntSec` normalization.
  - remaining work: more explicit generic remap utilities shared across future slices.
- Define local analysis keys for:
  - absolute function/table/memory/global/tag indices,
  - elem/data section indices.
- Add helpers to count imported vs defined items per extern kind.
- Add generic retain/remap helpers using `ModuleTransformer` index events.
- Rewrite `NameSec` maps and normalize `DataCntSec` after compaction.
- Add focused tests for remapping:
  - exports,
  - start,
  - `ref.func`,
  - `table.init`,
  - `memory.init`,
  - `elem.drop`,
  - `data.drop`.
- Exit when Starshine can compact any supported section without stale indices.

### Slice 2 — Open-World MVP Roots and Conservative Liveness
- References:
  - `ALG-00`, `ALG-02`, `ALG-03`, `ALG-08`, `ALG-10`, `ALG-11`.
- Status:
  - partial.
  - landed subset: open-world liveness for exports, start, exported globals/tables/memories/tags, live table initializer roots, active-segment retention for imported/live targets, conservative active-segment trap roots for unknown/out-of-bounds offsets, live direct calls, live `GlobalIdx`/`TableIdx`/`MemIdx`/`TagIdx`/`ElemIdx`/`DataIdx` users, function retention from kept globals/tables/elem segments, function/global/table/memory/tag/name-map compaction, and elem/data/global/table/memory/tag removal with remapped indices.
  - remaining work: fuller indirect-call/table precision, the still-narrow local constant-initializer trap model, and any path that needs referenced-only shell preservation.
- Root exports and non-empty start.
- Scan globals, function bodies, table initializers, elem expressions, and active segment offsets for direct references.
- Treat direct calls/returns, global/table/memory/tag ops, `memory.init`, `data.drop`, `table.init`, `elem.drop`, `array.new_data`, and `array.new_elem` as strong uses.
- Treat `ref.func`, `call_ref`, `return_call_ref`, `call_indirect`, `return_call_indirect`, and table mutation as conservative strong uses in open world.
- Keep imported entities whenever a live reference could still observe them.
- Delete only unreferenced items; rewrite referenced-only defined functions to `unreachable`.
- Exit when sound DCE works in the default non-closed-world pipeline.

### Slice 3 — Segment Observability and Trap Roots
- References:
  - `ALG-10`, `ALG-13`.
- Distinguish active vs passive/declarative elem/data segments.
- Preserve active data/elem segments that write to imported memory/table.
- Preserve active segments whose offset/size may trap when `traps_never_happen` is false.
- Preserve maybe-trapping constant initializers in globals and elem expressions.
- Status:
  - partial.
  - landed subset: imported-target observability, live-target active-segment retention, conservative rooting for unknown or definitely out-of-bounds active segment offsets on defined targets when traps may happen, and execution-time `traps_never_happen` plumbing for generated optimize execution.
  - current local boundary: Starshine now has an explicit initializer-trap hook, but it is a no-op because the local constant-expression subset does not yet model Binaryen's descriptor-bearing `struct.new_desc` form.
  - remaining work: add descriptor-bearing constant initializer support first (`struct.new_desc` IR/parser/binary/validator coverage), then teach the helper to root nullable-descriptor globals and elem expressions when traps may happen.
- Add regressions for:
  - imported memory/table visibility,
  - out-of-bounds instantiation traps.
- Exit when instantiation-time observable behavior is preserved, not just runtime reachability.

### Slice 4 — Indirect Call and Table Precision
- References:
  - `ALG-05`, `ALG-09`.
- Precompute initial table contents by `(table, heap type)` from elem segments.
- On `call_indirect` and `return_call_indirect`, reference the table and resolve matching functions and contributing segments.
- Detect mutable tables; if a table may be modified, fall back to callable-signature liveness.
- Keep open-world behavior conservative whenever feature/config evidence is missing.
- Status:
  - complete for the current non-GC/function-reference scope.
  - landed subset: non-mutated `call_indirect` and `return_call_indirect` now retain only matching active elem contributors for the target table; exports, `table.get`, and `table.copy` sources still root observable active contents; pure metadata/write operations like `table.size`, `table.set`, `table.fill`, `table.grow`, and `table.init` no longer pin prior active contents on their own; table initializer expressions are only scanned when table contents are observable or the table participates in indirect calls; and mutated indirect tables now feed their callable signatures into the closed-world `ref.func` / `call_ref` liveness machinery so later matching writes become used even when they were not present in the initial active segments.
- Exit when indirect-call retention is more precise than keeping every function reachable from every table.

### Slice 5 — Closed-World Function-Reference Precision
- References:
  - `ALG-00`, `ALG-05`, `ALG-06`, `ALG-14`.
- Unblock feature-source config:
  - complete for generated optimize execution:
    - `closed_world` now comes from `OptimizeOptions`,
    - `has_gc` and `has_multivalue` now come from module-derived facts,
    - `has_strings` remains inert until string IR exists locally.
  - remaining product question: whether `closed_world` should become CLI/config visible before the closed-world analyzer slice ships.
- Implement `calledSignatures` and `uncalledRefFuncs`.
- In closed world, downgrade bare `ref.func` to reference until matching `call_ref`, mutable-table, or callable-signature evidence appears.
- Add tests for:
  - bare `ref.func` shell rewrite,
  - later `call_ref` promotion to used,
  - open-world fallback keeping the full body.
- Status:
  - partial.
  - landed subset: closed-world generated-pipeline feature sourcing, referenced-vs-used function tracking for bare `ref.func`, `call_ref` / `return_call_ref` promotion of matching referenced functions back to used, mutated-indirect-table callable-signature fallback into that same machinery, open-world fallback keeping `ref.func` conservative, and `unreachable` shell rewriting for referenced-only defined functions.
  - remaining work: decide whether `closed_world` should become CLI/config visible before the later slices, and revisit any per-item retention logic that wants referenced-only shells outside the current function-body rewrite.
- Exit when Starshine supports Binaryen’s central referenced-vs-used function distinction where local execution config can express it.

### Slice 6 — GC Struct and Array Precision
- References:
  - `ALG-02`, `ALG-03`, `ALG-07`.
- Add subtype flattening and query helpers for closed-world GC analysis.
- Implement `readStructFields` and deferred payload tracking for `struct.new`.
- Wire `struct.get`, `struct.get_s`, `struct.get_u`, `array.new_data`, `array.new_elem`, and related GC consumers.
- Keep this slice disabled unless GC is present and closed-world config is available.
- Exit when GC payload liveness is precise without risking open-world unsoundness.

### Slice 7 — Hardening, Docs, and Pipeline Signoff
- Add idempotence tests and repeated-pass stability checks.
- Update `docs/0011-2026-03-18-pass-audit.md` once implementation lands.
- Review `.mbti` diffs if pass APIs change.
- Run `moon info && moon fmt`, then `moon test`.
- Add `bun validate` coverage if the pass gains CLI-visible options.
- Exit when the pass is documented, tested, and safe to keep in the default pipeline.

## Validation Plan
- Use strict TDD for each slice with `*_wbtest.mbt` fixtures beside the pass implementation.
- Prefer table-driven fixtures that assert:
  - kept and removed section sizes,
  - rewritten absolute indices,
  - `unreachable` shelling for referenced-only functions,
  - preserved instantiation-time observability.
- Keep at least one idempotence fixture that runs the pass twice.
- Re-run validator-backed coverage on any fixture that depends on `ref.func` declaration sources after compaction.

## Performance Notes
- The pass runs multiple times in the default pipeline, so MVP needs a cheap no-op fast path when nothing can be removed.
- Prefer dense arrays and bitsets indexed by section ordinal over map-heavy name-style bookkeeping.
- Build remap tables once per kind and reuse them for both index rewriting and name-section rewriting.

## Deferred Parity
- Binaryen’s currently disabled `prepare()` export-retarget optimization.
  - Reference: `ALG-12`.
- `call.without.effects`, `configureAll`, and `jsCalled`-style metadata unless Starshine adds equivalent metadata or intrinsics.
  - Reference: `ALG-04`, `ALG-06`.
- Export-pruning and whole-program metadce behavior.
  - Reference: `ALG-10`.

## Open Questions
- Should unused imported funcs/tables/mems/globals/tags be removed in `v0.1.0`, or can MVP compact defined sections first and leave imports conservative?
- Should `closed_world` remain an internal `OptimizeOptions` source until the closed-world slices land, or should CLI/config surface it earlier for experimentation?
- Should the next slice jump directly to indirect-call/table precision, or first implement referenced-only function shells so the current open-world/remap foundation can expose Binaryen’s three-state model more explicitly?
- Is the local constant-expression trap model intentionally narrower, matching Binaryen’s nullable-`struct.new` approximation, or broader?
