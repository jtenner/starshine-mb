# IR2 Local SSA Source Bridge

_Status:_ immutable primary-source bridge for [`docs/wiki/ir2/local-ssa-policy.md`](../../ir2/local-ssa-policy.md)
_Captured:_ 2026-05-20

## External primary / bibliographic source

1. Ron Cytron, Jeanne Ferrante, Barry K. Rosen, Mark N. Wegman, and F. Kenneth Zadeck, “Efficiently Computing Static Single Assignment Form and the Control Dependence Graph,” *ACM Transactions on Programming Languages and Systems* 13(4), 451–490, 1991. DOI: <https://doi.org/10.1145/115372.115320>.
   - Verified bibliographic metadata through Washington University Research Profiles: <https://profiles.wustl.edu/en/publications/efficiently-computing-static-single-assignment-form-and-the-contr/>.
   - Cross-checked DOI, journal, volume/issue, pages, publisher, and author affiliations through CiNii Research / Crossref metadata: <https://cir.nii.ac.jp/crid/1361981470639999744>.

## Durable takeaways for Starshine

- The external source is used only as the algorithmic lineage for “Cytron-style” SSA placement: dominance frontiers, def/use facts, and variable renaming are the classic basis for compiler SSA construction.
- Starshine deliberately implements a narrower local contract than a general whole-program SSA IR: `HotLocalSsa` is an analysis overlay over `HotFunc`, not a replacement body representation.
- Starshine also uses pruned placement rather than raw dominance-frontier placement: `src/ir/ssa_policy.mbt` filters candidate frontier blocks by local live-in facts from `src/ir/liveness.mbt`.
- The local overlay excludes exceptional-edge SSA and non-local expression values. Those exclusions are Starshine decisions, not claims about the external paper.
- Out-of-SSA is documented from Starshine code and tests, not from this bridge: `src/ir/ssa_destroy.mbt` lowers phis with predecessor copies, schedules copy cycles through temporary locals, rewrites local operands back to ordinary HOT nodes, and trims unused temps.

## Repository evidence paired with this source

- Normative historical policy: [`../../../0061-2026-03-24-local-ssa-policy.md`](../../../0061-2026-03-24-local-ssa-policy.md)
- Policy and query surface: [`../../../../src/ir/ssa_policy.mbt`](../../../../src/ir/ssa_policy.mbt)
- Local SSA builder: [`../../../../src/ir/ssa_local.mbt`](../../../../src/ir/ssa_local.mbt)
- SSA destruction/lowering: [`../../../../src/ir/ssa_destroy.mbt`](../../../../src/ir/ssa_destroy.mbt)
- Coverage: [`../../../../src/ir/ssa_policy_test.mbt`](../../../../src/ir/ssa_policy_test.mbt), [`../../../../src/ir/ssa_local_test.mbt`](../../../../src/ir/ssa_local_test.mbt), [`../../../../src/ir/ssa_destroy_test.mbt`](../../../../src/ir/ssa_destroy_test.mbt)

## Open interpretation boundaries

- This bridge does not certify performance or optimality of Starshine’s SSA implementation. It only anchors the dominance-frontier / renaming vocabulary.
- This bridge does not justify widening Starshine SSA to stack values, heap values, globals, memory, tables, or exceptional edges. Those would require a new IR2 contract update and test plan.
