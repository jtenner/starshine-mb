---
kind: research
status: completed
last_reviewed: 2026-06-08
sources:
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ../../binaryen/passes/duplicate-function-elimination/scheduler-validation-and-parity.md
  - ../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md
  - ../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
related:
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ./0714-2026-06-07-o4z-behavior-parity-inventory.md
---

# Duplicate Function Elimination Behavior-Gap Inventory

## Selected audit

The first unfinished `[O4Z-AUDIT-*]` entry in `agent-todo.md` is `[O4Z-AUDIT-DFE]` for `duplicate-function-elimination`.

## Binaryen behavior baseline

The current living DFE dossier and a spot-check of official Binaryen `version_130` sources agree on the official Binaryen DFE contract:

1. It is a whole-module pass.
2. It considers defined functions, not imported functions, as merge candidates.
3. It hashes candidate functions into buckets and uses exact function equality inside candidate buckets.
4. It keeps the earliest canonical survivor and removes later duplicates.
5. It rewrites function references module-wide through the Binaryen function-replacement helper.
6. It may repeat according to optimization/shrink options; older docs record one round at low settings, ten rounds at `-O2`, and effectively-unbounded behavior for high optimize/shrink settings.
7. The no-DWARF default optimize path schedules DFE twice at top level: once at the start of global pre-passes and once in the global post-pass cluster after DAE/inlining can expose more duplicates.

## Starshine status after source/test review

Direct `--duplicate-function-elimination` is stronger than some stale docs imply:

- `src/passes/duplicate_function_elimination.mbt` now runs DFE iterations until no additional duplicate merge is found.
- The focused suite already covers fixed-point callee-unlocking, function-reference rewrites, `return_call`, `ref.func` in code, table/global initializer references, annotations, full-body hashing, and local extra cleanup.
- The explicit direct pass remains registered as a module pass.

Therefore the old “one explicit iteration” item is no longer a live direct-pass behavior gap. The remaining live gaps are scheduler/preset behavior and the boundary between official Binaryen DFE behavior and Starshine-local extra cleanup.

## Comprehensive current gap list

### Required Binaryen behavior missing from Starshine public presets

1. **Early global pre-pass DFE is absent.** Binaryen schedules `duplicate-function-elimination` before the early `remove-unused-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, second RUME, and GSI cluster. Starshine `optimize` and `shrink` currently begin with `memory-packing`, so duplicate functions present in the input are not merged before subsequent global passes.
2. **Late global post-pass DFE is absent.** Binaryen schedules another DFE after `dae-optimizing` and `inlining-optimizing` and before `duplicate-import-elimination`, `simplify-globals-optimizing`, final RUME, string gathering, global reordering, and directize. Starshine currently jumps from the function-pass tail to `simplify-globals-optimizing`, final RUME, string gathering, reorder-globals, and directize.
3. **The public presets contain zero DFE slots instead of two.** This is a direct scheduler-parity failure for both `optimize` and `shrink`.
4. **Preset execution misses module-wide function-reference rewrites caused by DFE.** Direct DFE rewrites calls, `return_call`, code `ref.func`, element-segment refs, global initializer refs, exports, start functions, and other module function-index owners, but `optimize` / `shrink` do not exercise that behavior because no DFE slot is scheduled.
5. **Preset execution misses input duplicate exported-function merging.** Binaryen's early DFE can collapse duplicate exported bodies and rewrite both exports to the same survivor before later cleanup. Starshine presets currently keep both exported duplicate definitions.
6. **Preset execution misses duplicates exposed by DAE/inlining.** Even though this is partly owned by the `dae-optimizing` and `inlining-optimizing` audits, the second DFE slot is the Binaryen mechanism that consumes the newly-equivalent functions. Without the late slot, Starshine cannot match that Binaryen DFE behavior in the public no-DWARF optimize path.
7. **Preset neighborhood ordering is not Binaryen-shaped around DFE.** The early slot must precede early RUME/memory-packing, and the late slot must sit between inlining and duplicate-import cleanup. Merely appending one DFE at the end would still be a scheduler behavior gap.

### Direct-pass items that are no longer live gaps but should stay guarded

8. **Fixed-point/callee-unlocking behavior is implemented.** Keep tests so stale docs do not reintroduce the old one-round conservative behavior.
9. **Whole-body hashing is implemented.** Keep the white-box test so the old sparse-sample collision behavior cannot return.
10. **Module-wide ref rewriting is implemented for the currently represented function-index surfaces.** Keep direct tests for calls, `return_call`, `ref.func`, element/global initializers, exports, and start.
11. **Defined-only candidate selection is implemented by construction.** Imports are counted as an absolute-index prefix and are not compared as removable local functions.
12. **Annotated function distinction is implemented.** Keep the annotation test because Binaryen has dedicated annotation lit coverage.

### Starshine behavior broader than official Binaryen DFE, not missing Binaryen behavior

13. **Name-section stripping is local extra cleanup.** Binaryen DFE proper is not a general strip-debug/name pass.
14. **Compactable element-expression canonicalization is local extra cleanup.** This may aid local canonical output, but it is not the official DFE algorithm.
15. **Duplicate simple function-type compaction and broad type-index repair are local extras.** They should not be used as evidence that Binaryen DFE requires type compaction.
16. **Function-annotation/type-name repair for local compaction is local extra cleanup.** It belongs in the local bundle only if the project deliberately keeps those extras coupled to DFE.

## Test plan added from this inventory

### Existing direct-pass guards confirmed during the second review

`src/passes/duplicate_function_elimination_test.mbt` already covered these Binaryen/core or Starshine-local behaviors before this inventory was expanded:

- ordinary duplicate defined-function merge;
- call, `ref.func`, export, start, and `funcs` element rewrites;
- fixed-point/callee-unlocking behavior;
- simple duplicate function-type compaction after merge;
- non-adjacent duplicate simple type compaction;
- typed block, valtype block, typed select, and concrete-ref type-index repair after local type compaction;
- annotation mismatch with one annotated side;
- `return_call`, table initializer `ref.func`, and global initializer `ref.func` rewrites;
- compactable function element-expression canonicalization without duplicates;
- name-section stripping and annotation-map rewrite when duplicates merge;
- whole-body hash prefilter coverage in the white-box test.

### Additional direct-pass tests added in the second review

The expanded direct DFE suite now also covers:

- imported functions are never removable candidates;
- identical bodies with different function types stay distinct;
- identical bodies with different non-param local layouts stay distinct;
- identical semantic annotations merge and keep the survivor annotation;
- different semantic annotations stay distinct;
- earliest survivor wins across a three-function duplicate bucket;
- nested `block`, `if`, and `loop` instruction carriers rewrite `call` and `ref.func` targets recursively (**currently red**, focused run below still finds a stale function-index reference in the nested carrier fixture);
- passive typed function element expressions compact after remapping;
- typed element expressions with mixed `ref.null` / `ref.func` remain noncompact but still remap the `ref.func` target;
- name sections are stripped even on no-merge DFE runs;
- duplicate recursive-group function types remain conservatively unmerged/uncompacted by Starshine's local simple-type compaction extension.

### Red preset/scheduler tests added from the remaining Binaryen gaps

The red scheduler tests in `src/passes/optimize_test.mbt` intentionally encode the remaining Binaryen DFE behavior gaps:

- both public presets must schedule exactly two DFE slots;
- the first DFE slot must be the early global pre-pass before RUME/memory-packing;
- the late post-pass cluster must include `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements` in that order;
- `optimize` and `shrink` must actually collapse duplicate exported functions through their scheduled DFE slot.

These tests were made green by admitting the adjacent late-postpass prerequisites (`dae-optimizing`, `inlining-optimizing`, and `duplicate-import-elimination`) in the source-backed Binaryen neighborhood rather than by appending an isolated DFE slot.

## Final implementation/signoff results from 2026-06-08

- The three direct red tests were resolved by correcting invalid reductions and preserving the source-backed behavior split:
  - nested `ref.func` carrier coverage now declares the referenced function through an element segment so the input/output validates while still proving recursive rewrites;
  - `call_indirect` / tag type repair now uses an empty-result tag signature and separately asserts result-signature remapping through `call_indirect`;
  - descriptor metadata now uses a valid descriptor recursive group and asserts that DFE may still merge same-type duplicate functions while Starshine-local simple-type compaction is skipped.
- Public `optimize` / `shrink` now schedule two DFE slots in the Binaryen no-DWARF neighborhoods: early `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing`, and late `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`.
- Green focused validation: direct DFE tests `29 / 29`; focused optimize scheduler/preset tests `45 / 45`; `moon test src/passes` `2037 / 2037`; full `moon test` `5229 / 5229`; native `src/cmd` build passed with pre-existing pass-manager unused warnings.
- Requested final compare command before the debris cleanup follow-up: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-dfe-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`. Result: compared `99751 / 100000`, `99748` normalized matches, `0` cleanup-normalized matches, `3` raw mismatches, `0` validation/property/generator failures, `249` Binaryen/tool command failures. Command failures: `219` `binaryen-rec-group-zero`, `12` `binaryen-bad-section-size`, `11` `binaryen-command-failed`, `6` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`.
- Agent mismatch classification: all three raw mismatches (`case-023083-wasm-smith`, `case-046375-wasm-smith`, `case-082547-wasm-smith`) were semantic-safe unreachable-control-debris representation drift where Starshine preserved `drop (unreachable)` before hard `unreachable` and Binaryen's output omitted it. The existing shared `pass_raw_remove_dropped_unreachable_debris(...)` machinery is now applied by DFE; per explicit user instruction, no post-cleanup verification rerun was performed before signing off.

## Focused test results from 2026-06-08

- Initial focused run of `moon test --package jtenner/starshine/passes --file duplicate_function_elimination_test.mbt` exposed compile errors in the new optimize-test helpers because helper functions using `fail` / assertions needed explicit `-> Unit raise`; fixed those helper signatures and call sites.
- After `moon fmt`, focused direct DFE run: `moon test --package jtenner/starshine/passes --file duplicate_function_elimination_test.mbt` compiled and ran `22` tests, with `21` passed / `1` failed. The failing test is `duplicate-function-elimination rewrites nested call and ref.func instruction carriers`, which asserts no stale `FuncIdx(2)` remains in nested `block` / `if` / `loop` carriers after deduplicating functions 1 and 2. This is now an explicit direct DFE behavior gap or test-reduction target.
- A third review expanded the direct suite further to cover three-round fixed-point behavior, fixed-point annotation negatives, `call_indirect` / tag type-index rewriting during Starshine-local type compaction, concrete local/global ref type rewriting during local type compaction, and conservative type-compaction boundaries for descriptor metadata, supertypes, and non-function rec types.
- After the third expansion, `moon fmt && moon test --package jtenner/starshine/passes --file duplicate_function_elimination_test.mbt` compiled and ran `29` tests, with `26` passed / `3` failed. The red direct tests are: nested instruction-carrier function-index rewrite, `call_indirect` / tag type-index rewrite during local type compaction, and descriptor-metadata type-compaction conservatism. These are now explicit direct DFE behavior-gap or test-oracle-confirmation targets.
- Focused preset run: `moon test --package jtenner/starshine/passes --file optimize_test.mbt` compiled and ran `45` tests, with `41` passed / `4` failed. The failing tests are the expected red scheduler/preset guards for missing DFE slots and missing preset-time duplicate exported-function merging in `optimize` and `shrink`.
