---
kind: entity
status: working
last_reviewed: 2026-09-10
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# Binaryen 132 DAE2 strategy

The release expands DAE2 from parameter forwarding to **parameter and result
usage together** (#8903). This supersedes this dossier's version-129 result
exclusion. Normal `DeadArgumentElimination.cpp` only changes result statistics
in this release; its algorithm is a different comparison target.

Usage is a backward dependency problem. Values consumed only by unused
parameters or unused results do not become observable merely because they
participate in a cycle. Observable uses seed liveness, which propagates until
no location changes. An entire multiple-result tuple is one location.

Private direct-only functions can change independently. Referenced functions
share constraints with their function-type family and indirect call sites.
Open-world entry points retain externally meaningful signatures. Continuation
signatures and effect-free-call intrinsics have additional restrictions.
Removing values preserves their side effects and traps; signature rewriting
updates all affected call/return/type sites before finalization.

The released algorithm needs the later #8994 companion: if an open-world indirect
tail callee's result signature cannot change, its caller's results cannot be
removed either. That correction is outside the v132 tag and must stay identified
as a backport.

Constant-argument propagation and general parameter/result type refinement are
not the reason to replace ordinary DAE with DAE2. Keep ordinary DAE for A/B
comparison. Do not map a new public name onto the old implementation.

Binaryen 132 exposes `dae2`, without a `dae2-optimizing` registry entry. A cleanup
experiment is an explicit sequence and must be measured as such.
