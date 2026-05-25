---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ./0573-2026-05-19-sgo-v010-signoff.md
---

# SGO default-local compare normalization audit (`[SGO]005`)

## Scope

This docs/backlog slice audits `[SGO]005`, the tooling/cosmetic follow-up for the accepted direct SGO artifact diff where Binaryen preserves an explicit default-local initialization and Starshine relies on WebAssembly default local zero-initialization. It does not change optimizer behavior, compare tooling, tests, public API, or pass docs.

## Findings

No immediate tooling or emission change is warranted from the current evidence:

- The direct v0.1.0 SGO signoff classified the first canonical artifact diff (`defined=48 abs=69`) as representation-only local/default-init drift.
- The known shape is narrow: Binaryen preserves one explicit `local.set $0 (i32.const 0)`, while Starshine relies on the WebAssembly rule that locals are default-initialized to zero.
- The same signoff reported valid output, smaller Starshine direct-artifact size than Binaryen, pass-local runtime inside the accepted 2x floor, and direct 10k SGO fuzz with zero normalized mismatches or Starshine validation failures.
- There is no current release-QA requirement for quieter exact diffs and no semantic or validation issue attributable to the default-local representation.
- Changing Starshine emission to preserve the explicit set would risk adding representation-matching behavior to the optimizer, while changing compare tooling should be done only when exact artifact review noise becomes an active workflow blocker.

## Decision

Close `[SGO]005` as an evidence-gated tooling/cosmetic follow-up. Reopen only if exact artifact QA or compare-harness work needs to suppress this already-classified default-local diff, or if a future case shows the drift is not representation-only.

If reopened, prefer compare-helper normalization over optimizer emission changes unless a concrete downstream consumer needs the explicit default-local `local.set`. Any normalization must be narrow: it may ignore provably equivalent explicit default local initialization, but it must not hide arbitrary local/control-shape differences.

## Validation

No optimizer behavior, tests, public API, compare tooling, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This audit does not solve all exact-artifact diff noise. It only closes the one currently tracked SGO default-local normalization item until a release-QA or compare-tooling need makes it actionable.
