# OptimizeInstructions OI-J finite roadmap

Date: 2026-07-03

## Scope

This note splits OI-J into source-backed, independently testable slices before broad descriptor/exactness/TNH/IIT implementation. It is not a closure claim for OI-J. It deliberately excludes the already broader OI-I/OI-K/OI-L evidence and uses only focused OI-J source/lit/probe evidence gathered for this roadmap.

Primary sources checked locally:

- `.tmp/oi-j-source/OptimizeInstructions.cpp` (Binaryen version_130 `skipCast`, `skipNonNullCast`, `trapOnNull`, descriptor-cast visitor logic, TNH/IIT gates).
- `.tmp/oi-j-source/optimize-instructions-desc.wast`.
- `.tmp/oi-j-source/optimize-instructions-exact.wast`.
- `.tmp/oi-j-source/optimize-instructions-gc-tnh.wast`.
- `.tmp/oi-j-source/optimize-instructions-gc-iit.wast`.
- `.tmp/oi-j-source/optimize-instructions-all-casts*.wast`.
- Starshine surface and existing tests: `src/passes/optimize_instructions.mbt`, `src/passes/optimize_instructions_test.mbt`, `docs/wiki/binaryen/passes/optimize-instructions/gc-casts-call_ref-and-trap-sensitive-rewrites.md`, `docs/wiki/raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`.

## OI-J split

| Slice | Candidate behavior | Binaryen source/lit anchor | Starshine status after this note |
|---|---|---|---|
| OI-J.1 standalone descriptor child null check | `ref.get_desc(ref.as_non_null(local.get nullable))` can become `ref.get_desc(local.get nullable)` because `ref.get_desc` preserves the same null trap for the direct local child. Branch-free block children with ordered zero-result effect/trap roots and a final nullable `local.get` are covered by the follow-up block slice. | `skipNonNullCast` / `trapOnNull` behavior, descriptor lit coverage, probes 03-05 plus the focused block-child pack. | Implemented for direct `LocalGet` and the finite branch-free block child subset, default mode, not TNH. |
| OI-J.2 descriptor-cast descriptor operands | Same child-null-check movement when `ref.get_desc` is the descriptor operand of `ref.cast_desc_eq`; broader block/select/if/control surfaces exist. | Existing Starshine descriptor-operand tests plus probes 01-09. | Existing implementation remains; not broadened by this slice. |
| OI-J.3 descriptor equality cast success/failure | Default mode preserves explicit descriptor checks unless known-null/trap facts justify a fold; TNH can assume descriptor success. | `optimize-instructions-desc.wast`, `skipCast`, TNH gates. | Partially implemented historically; no broad new claim. |
| OI-J.4 exact casts/tests | Exact source/target compatibility, already-exact casts, failed exact tests. | `optimize-instructions-exact.wast`, `all-casts-exact`. | Existing tests plus probes 10-11; not expanded here. |
| OI-J.5 TNH-specific cast skipping | `--traps-never-happen` can erase casts/null checks otherwise required for traps. | `optimize-instructions-gc-tnh.wast`, `skipCast`, `skipNonNullCast`. | Quarantined here. The new standalone rewrite explicitly does not run under TNH so existing TNH descriptor erasure remains in charge. |
| OI-J.6 IIT-specific trap movement | `--ignore-implicit-traps` can allow movement/removal that default mode must reject. | `optimize-instructions-gc-iit.wast`, `trapOnNull`. | Quarantined here. |

## Probe pack

Focused probes live under `.tmp/oi-j-roadmap-probes-20260703/`:

- Inputs: `.tmp/oi-j-roadmap-probes-20260703/inputs/*.wat`.
- Runner: `.tmp/oi-j-roadmap-probes-20260703/run-probes.py`.
- Full JSON: `.tmp/oi-j-roadmap-probes-20260703/probe-results.json`.
- Compact table: `.tmp/oi-j-roadmap-probes-20260703/probe-results.md`.

The runner validates every probe input with `wasm-opt --all-features` and `wasm-tools validate --features all`, then runs Binaryen default, TNH, IIT, `-O4 -Oz`, and Starshine default `--optimize-instructions`.

| Probe | Binaryen default | Binaryen TNH | Binaryen IIT | Binaryen O4/Oz | Starshine default before implementation | Use in roadmap |
|---|---|---|---|---|---|---|
| 01 direct descriptor cast simplifies | keep | rewrite | keep | rewrite | failed final validation | Descriptor-cast/HOT lowering boundary; not selected. |
| 02 direct descriptor cast preserves | keep | rewrite | keep | rewrite | keep | Descriptor equality preservation. |
| 03 standalone `ref.get_desc(ref.as_non_null(local))` | rewrite | rewrite | rewrite | rewrite | keep | Selected smallest candidate. |
| 04 effectful standalone `ref.get_desc` child | rewrite | rewrite | rewrite | rewrite | keep | Future effectful slice; fail-closed here. |
| 05 trapping standalone `ref.get_desc` child | rewrite | rewrite | rewrite | rewrite | keep | Future trapping/effect classification; fail-closed here. |
| 06-09 escaping/control descriptor children | mixed | mixed | mixed | rewrite | keep/rewrite | Future control-localization slice. |
| 10-11 exact success/failure | rewrite | rewrite | rewrite | rewrite | failed/rewrote | Exactness slice, not selected. |
| 12 TNH-only cast skip | keep | rewrite | rewrite | rewrite | keep | TNH/IIT quarantine. |
| 13 IIT/non-null facts | keep | rewrite | rewrite | rewrite | keep | TNH/IIT quarantine. |

Two Starshine tooling observations are preserved as blockers rather than folded into the selected implementation:

- Probe 01 failed Starshine final validation with `ref.cast_desc_eq target does not match operand type`; this is a descriptor-cast lowering/validation boundary, not evidence for standalone `ref.get_desc`.
- Probe 10 failed Starshine decode with `InvalidS33Range`; this is an exact-cast binary decode surface, not part of the direct-local standalone `ref.get_desc` slice.

## Selected implementation candidate

Chosen candidate: **OI-J.1 direct-local standalone descriptor child null-check movement**.

Rationale:

1. It is the smallest probe-backed Binaryen default rewrite in the pack.
2. It does not require broad descriptor equality success reasoning, exact cast reasoning, TNH, IIT, or escaping-label localization.
3. The semantics are local: original code traps on null at `ref.as_non_null`; rewritten code traps on the same null at `ref.get_desc`, with no intervening effect or control for a direct `local.get` child.
4. Existing descriptor-operand logic already has broader movement helpers; this slice adds only a standalone/default direct-local hook and leaves non-local children guarded.

Implemented guardrails:

- Original roadmap slice: match only `RefGetDesc(RefAsNonNull(LocalGet))`.
- Follow-up `1441` slice: also match branch-free `Block` children with one nullable reference result, ordered zero-result effect/trap roots, and a final nullable `LocalGet`; do not rebuild or move the block.
- Do not run under `traps_never_happen`; TNH-specific descriptor erasure remains separate.
- Do not rewrite select/if/loop/try_table/branch/control children in the standalone helper; block children containing control/EH/multivalue remain fail-closed.
- Do not rewrite ordinary non-descriptor `ref.as_non_null` forms; OI-I remains quarantined.

## Red-first tests and validation

New test: `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc local null checks`.

Red result before implementation:

```text
moon test src/passes
[jtenner/starshine] test passes/optimize_instructions_test.mbt:9485 ("optimize-instructions moves standalone ref.get_desc local null checks") failed ... body_raw: (local.get (Local 0))ref.as_non_null(ref.get_desc (Type 0))(end)
```

Green result after implementation:

```text
moon test src/passes
Total tests: 3925, passed: 3925, failed: 0.
```

The test includes:

- Original test coverage: positive pure direct-local standalone rewrite, fail-closed effectful/trapping/control block children, and OI-I quarantine for ordinary non-descriptor `ref.as_non_null(local)`.
- Follow-up `1441` coverage: direct-local remains positive; branch-free effectful `global.set`, trapping `i32.div_u`, and ordered double-`global.set` block children now remove `ref.as_non_null` while preserving order; `br`, `br_if`, `if`, `loop`, `try_table`, non-descriptor `ref.as_non_null`, and TNH remain fail-closed.

## Remaining roadmap

1. Probe 01 descriptor-cast validation and probe 10 exact `ref.test` binary support were reduced by `1440-2026-07-03-optimize-instructions-oi-j-representation-blockers.md`; further descriptor-cast optimizer behavior and exactness reasoning remain separate follow-ups.
2. `ref.test_desc` text/binary/tooling remains a separate OI-J blocker.
3. The dedicated source-backed branch-free standalone `ref.get_desc` block-child slice is recorded in `1441-2026-07-03-optimize-instructions-oi-j-standalone-refgetdesc-block-child.md`: direct `LocalGet`, ordered `global.set` roots, and ordered trapping `i32.div_u` roots are covered without rebuilding or moving the block; control/EH/multivalue children remain fail-closed.
4. Add a dedicated escaping-control/localizer slice for descriptor children; do not infer safety from validation alone.
5. Keep TNH and IIT in explicit mode-specific slices with tests that prove mode gating, not default-mode behavior.
6. Only after the above, broaden `pass-oi-descriptor-gc` or add a new OI-J profile for exactness/TNH/IIT.
