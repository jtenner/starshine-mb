# MoonBit formal-verification v0.9.3 source refresh

_Capture date:_ 2026-06-04  
_Status:_ immutable primary-source bridge for [`docs/wiki/validation/moonbit-prove-strategy.md`](../../validation/moonbit-prove-strategy.md), superseding only the current-upstream wording in the 2026-05-20 command/trust refresh while preserving that file as historical provenance.

## Scope

This refresh rechecks MoonBit's current formal-verification documentation after the older Starshine proof page still cited the `latest` docs as v0.9.2. The goal is not to copy the MoonBit manual into the repo; it is to keep Starshine's proof-gate, trust-boundary, and helper-kernel policy aligned with current primary sources.

## Official sources consulted

- MoonBit language manual, "Formal Verification" (`latest`, v0.9.3, checked 2026-06-04): <https://docs.moonbitlang.com/en/latest/language/verification.html>
- Moon command manual (`moonbitlang.github.io/moon`, checked 2026-06-04): <https://moonbitlang.github.io/moon/commands.html>
- Moon command-manual source in the official `moonbitlang/moon` repository (`main`, checked 2026-06-04): <https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md>
- MoonBit blog, "MoonBit 0.9: Introducing First-Class Formal Verification" (background only, checked 2026-06-04): <https://www.moonbitlang.com/blog/moonbit-0-9-release>

## Local repository evidence consulted

- [`../../../../src/validate_proof/moon.pkg`](../../../../src/validate_proof/moon.pkg): the required proof-gate package remains `proof-enabled` and imports only `moonbitlang/core/debug`.
- [`../../../../src/validate/moon.pkg`](../../../../src/validate/moon.pkg): the broader validator package remains `proof-enabled` but policy-sensitive and not part of the required proof gate.
- [`../../../../src/validate_proof/pkg.generated.mbti`](../../../../src/validate_proof/pkg.generated.mbti): still exports fifteen executable proof helpers.
- [`../../../../src/validate/imports.mbt`](../../../../src/validate/imports.mbt): still imports nine proof helpers into the live validator.
- Repository search on 2026-06-04 found no committed source under `src/` using `proof_axiomatized`, `#proof_pure`, `proof_decrease`, `proof_reasoning`, `proof_assert`, `proof_invariant`, or `proof_yield`; current committed proof code continues to use `where` contracts plus `.mbtp` predicates.

## Current upstream proof facts relevant to Starshine

- The current MoonBit documentation still frames formal verification as a package/file-targeted workflow that requires `proof-enabled` in package configuration and is run by `moon prove`.
- The docs still route proof obligations through Why3 and external solvers. The command reference now exposes proof-specific command controls such as a Why3 configuration path and parallel job count; those are host/tooling knobs, not Starshine semantic evidence.
- The current docs explicitly describe file targets as a way to prove one file while assuming dependencies. That supports Starshine's existing split: direct `src/validate` file proving can be an investigative local tool, but it is not the same kind of assurance as proving a small, dependency-light helper package and then importing its checked functions.
- The executable `where` contract plus `.mbtp` predicate split used by `src/validate_proof` remains aligned with the official examples.
- The richer proof-only/trusted surface is broader than Starshine's current usage. Constructs such as proof assertions, invariants, reasoning blocks, explicit recursion/loop proof controls, purity/trust declarations, and axiomatized declarations should remain policy-visible trust-boundary changes if introduced locally.
- The official background blog remains useful for understanding why MoonBit added first-class verification, but the current language manual and command manual are the live command/syntax sources.

## Durable observations for Starshine

- Keep `moon prove src/validate_proof` as the only required proof lane on configured hosts; do not silently add broad `moon prove src/validate` or root-level proving to `bun validate full`.
- Treat file-targeted proving under `src/validate` as local investigation unless a fresh audit proves the target has a small, clear dependency/trust surface.
- Keep proof helper APIs executable and boring: arithmetic/index/stack helper functions with `where` contracts, `.mbtp` predicates, executable tests, and explicit import into `src/validate` when adopted.
- Treat solver options, `--why3-config`, and parallel proof jobs as reproducibility/tooling settings. Record them in run notes if they matter, but do not encode host-specific prover setup as a semantic repo invariant.
- Any future introduction of `proof_axiomatized`, `#proof_pure`, proof assertions/invariants/reasoning blocks, or explicit termination/decrease controls in validator-critical code must update the living proof strategy, trust ledger, and relevant validation-gate notes in the same change.

## Consumability rule

Cite this file together with [`../../validation/moonbit-prove-strategy.md`](../../validation/moonbit-prove-strategy.md) for proof policy, [`../../tooling/validation-gates.md`](../../tooling/validation-gates.md) for repo gate policy, and the 2026-05-20 refresh for historical command/trust context. This file is a source bridge, not a replacement for local executable tests, fuzzing, binary roundtrips, or pass oracle comparison.
