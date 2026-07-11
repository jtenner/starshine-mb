# Binaryen `remove-unused-module-elements` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for `docs/wiki/binaryen/passes/remove-unused-module-elements/`

## Scope

This narrow reread refreshes the living RUME dossier against Binaryen current `main`. The older 2026-04-22 source capture remains the `version_129` release-anchor evidence; this document does **not** silently claim that every current-main detail is new relative to that tag.

The review focused on one under-documented correctness rule: preserving possible `call_indirect` wrong-type traps while removing otherwise-unused table initializers. It also reread the public registration and focused all-features/reference fixtures, then reconciled that rule with Starshine's active module-pass implementation.

## Primary sources reread

### Upstream Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp>
- Public registration and default scheduling: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Broad fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-module-elements_all-features.wast>
- Reference fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-module-elements-refs.wast>
- Non-function sibling fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast>

### Current Starshine evidence

- Active owner: `src/passes/remove_unused_module_elements.mbt`
- Focused tests: `src/passes/remove_unused_module_elements_test.mbt`
- Registry/presets: `src/passes/optimize.mbt`
- Harness admission: `scripts/lib/pass-fuzz-compare-task.ts`

## Current upstream result

Binaryen still exposes the full `remove-unused-module-elements` pass and the `remove-unused-nonfunction-module-elements` sibling. The owner still uses separate `used` and `usedReferenced` sets and a queue-driven whole-module analysis.

The source makes a subtle table rule explicit. When an indirect-call site uses a table, RUME records the table as strongly used and reasons about the table's possible initialized entries. Unless the pass runs with `trapsNeverHappen`, a mutable table's active element segments must be retained when needed to preserve a possible wrong-signature `call_indirect` trap. Removing an entry with the wrong function type could otherwise turn that observable type-mismatch trap into a different null-entry trap.

This is a correctness rule, not a generic preference to retain tables:

- it is tied to indirect-call trap behavior and the table's possible modification;
- the source permits the more aggressive result only under `trapsNeverHappen`, where trap changes are an accepted optimizer assumption;
- it is separate from ordinary direct-call reachability and from no-op active-element cleanup.

The reviewed source also continues to collect the indirect-call heap type and table use through the normal analysis path. The reread found no evidence that the public names or the core strong-versus-reference-only model have changed on these inspected surfaces.

## Starshine reconciliation

Starshine's `rume_scan_instruction(...)` marks the table used for both `CallIndirect` and `ReturnCallIndirect`. Later, `rume_process_table(...)` marks every active element segment recorded for that table. Therefore its current default behavior is conservative in the same direction: it keeps active initializer segments for a live indirect-call table instead of deleting an entry that might affect a later indirect-call trap.

The local implementation is coarser than Binaryen's source-level policy:

- it applies active-segment retention to every used table, not only to the indirect-call/trap case;
- it has no local `trapsNeverHappen` policy that permits the more aggressive alternative; and
- the focused local RUME test file has no dedicated wrong-type indirect-call trap fixture as of this capture.

That is a documented coverage and output-shape boundary, **not** evidence of a semantic mismatch. The conservative default preserves the trap-sensitive table state; a future optimization that removes more segments must demonstrate that it does not alter the null-versus-wrong-type trap distinction.

## Consumability rule

Use this capture for current-main freshness and the `call_indirect` trap-preservation rule. Use the 2026-04-22 capture for the tagged `version_129` source baseline and older research notes for historical port decisions. A future source diff may establish when a specific detail changed upstream; this narrow reread does not make that historical claim.
