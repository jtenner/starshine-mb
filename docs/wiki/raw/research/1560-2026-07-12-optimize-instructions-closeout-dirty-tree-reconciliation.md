# Optimize-instructions closeout dirty-tree reconciliation

Date: 2026-07-12

## Scope

This note reconciles the mixed optimize-instructions (OI) state seen in the local dirty index/worktree against the last coherent committed closeout. It does not reopen OI implementation scope by itself.

## Inputs reviewed

Canonical committed closeout state:

- `agent-todo.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/optimize-instructions/fuzzing.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`
- `src/validate/gen_valid.mbt`
- `src/validate/gen_valid_tests.mbt`
- `src/fuzz/main_wbtest.mbt`
- `docs/wiki/raw/research/1429-2026-07-03-optimize-instructions-oi-m-closeout.md`

Contradictory local dirty surfaces:

- staged/index and worktree edits in `agent-todo.md`, `docs/wiki/log.md`, `docs/wiki/binaryen/passes/optimize-instructions/fuzzing.md`, and `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`
- staged/index and worktree edits in `src/passes/pass_manager.mbt`, `src/passes/pass_manager_wbtest.mbt`, `src/passes/optimize_instructions.mbt`, and `src/passes/optimize_instructions_test.mbt`
- staged/index edits removing the aggregate OI validation surface from `src/validate/gen_valid.mbt`, `src/validate/gen_valid_tests.mbt`, and `src/fuzz/main_wbtest.mbt`

## Findings

1. The last coherent committed state is the documented closeout already present at `HEAD`:
   - `agent-todo.md` starts at the `OI-M closeout boundary` rather than an active OI implementation backlog.
   - `docs/wiki/log.md` records `[OI-INDEX]005` closed on 2026-07-12.
   - `docs/wiki/binaryen/passes/optimize-instructions/fuzzing.md` contains the final 2026-07-12 closeout matrix and reopen criteria.
   - `gen_valid` and its tests retain the `pass-oi-all` aggregate and its optimize-instructions aliases, matching the closeout docs.
2. The local dirty staged bundle is internally inconsistent with that closeout contract:
   - it reopens active OI backlog rows in `agent-todo.md` while leaving closeout wording in `docs/wiki/log.md`;
   - it regresses the fuzzing page to older rolling diary content;
   - it removes `PassOiAllProfile`, its aliases, and related tests while the docs still cite `pass-oi-all` as the required closeout lane.
3. The local dirty worktree goes further and mixes the already-closed docs/log state with older OI recursion notes and parity code paths. In particular, the current dirty `src/passes/optimize_instructions.mbt` reintroduces behavior that the committed closeout explicitly classifies as repaired, such as direct-null `ref.is_null` constant folding and purity-based `ref.test` operand erasure.
4. Because the dirty state mixes regressions, reopenings, and unrelated later notes, it is not a trustworthy newer target on its own. Without fresh source-backed evidence, the committed closeout remains the canonical target.

## Reconciliation decision

Treat the committed closeout state at `HEAD` as canonical for OI until one of the already-documented reopen criteria is met with fresh evidence:

- a validation or runtime failure;
- a true semantic mismatch;
- an unclassified or size-losing residual family;
- a scanner or shape-matrix regression;
- pass-local timing above the accepted threshold;
- new Binaryen source behavior outside the reviewed v130 contract.

Any future OI reopening must update the closeout docs, backlog, and validation contract coherently in the same direction. Partial removal of `pass-oi-all`, partial reopening of `[OI-INDEX]` rows, or partial rollback of accepted parity repairs is not a safe intermediate target.

## Validation status in this environment

The standard moon validation ladder is currently blocked before execution by unresolved registry dependency `moonbitlang/x`:

- `moon info` fails during dependency resolution.
- `moon test` fails during the same dependency-resolution step.

So this note records a state-reconciliation judgment, not new runtime evidence.

## Outcome

- Canonical OI closeout target: committed `HEAD` closeout contract.
- Dirty staged/worktree OI bundle: non-canonical until explicitly re-triaged or cleanly re-derived.
- Recommended next step if more OI work is required: either restore the dirty OI surfaces to the committed closeout or intentionally reopen OI with one coherent docs/code/validation plan.
