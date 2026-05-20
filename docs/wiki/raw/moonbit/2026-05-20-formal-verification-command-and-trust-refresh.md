# MoonBit formal-verification command and trust refresh

_Capture date:_ 2026-05-20  
_Status:_ immutable primary-source bridge for [`docs/wiki/validation/moonbit-prove-strategy.md`](../../validation/moonbit-prove-strategy.md)

## Scope

This manifest refreshes the upstream MoonBit proof evidence behind Starshine's formal-proof policy. It supplements the earlier 2026-05-13 official-doc bridge, which remains useful for the initial `proof-enabled` / Why3 / solver setup story, and the separate 2026-05-20 Moon CLI manual refresh, which owns the broader `moon info` / `moon fmt` / `moon check` / `moon test` validation-gate command map.

## Official sources consulted

- MoonBit language manual, "Formal Verification" (`latest`, v0.9.2, checked 2026-05-20): <https://docs.moonbitlang.com/en/latest/language/verification.html>
- Moon manual GitHub Pages command reference (`moonbitlang.github.io/moon`, checked 2026-05-20): <https://moonbitlang.github.io/moon/commands.html>
- Moon manual source in the official `moonbitlang/moon` repository (`main`, checked 2026-05-20): <https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md>
- MoonBit blog, "MoonBit v0.9.1 Beta Preview: First-Class Formal Verification" (still relevant background, rechecked 2026-05-20): <https://www.moonbitlang.com/blog/first-class-formal-verification>

## Local repository evidence consulted

- [`../../../../src/validate_proof/moon.pkg`](../../../../src/validate_proof/moon.pkg): small proof-enabled helper package imported by the validator.
- [`../../../../src/validate/moon.pkg`](../../../../src/validate/moon.pkg): broader validator package is proof-enabled but remains outside the required proof gate.
- [`../../../../src/validate_proof/pkg.generated.mbti`](../../../../src/validate_proof/pkg.generated.mbti): current public helper roster, fifteen exported functions.
- [`../../../../src/validate/imports.mbt`](../../../../src/validate/imports.mbt): current live validator import map, nine proof helpers imported.
- [`../../../../src/validate_proof/bounds_index.mbt`](../../../../src/validate_proof/bounds_index.mbt) and [`../../../../src/validate_proof/bounds_index_proof.mbtp`](../../../../src/validate_proof/bounds_index_proof.mbtp): representative executable helper plus proof-only predicate split.
- [`../../../../src/validate_proof/stack_discipline.mbt`](../../../../src/validate_proof/stack_discipline.mbt) and [`../../../../src/validate_proof/stack_discipline_proof.mbtp`](../../../../src/validate_proof/stack_discipline_proof.mbtp): sidecar stack-length proof helpers that remain exported but not imported into `src/validate`.
- Repository search on 2026-05-20 found no committed `proof_axiomatized`, `#proof_pure`, `proof_decrease`, `proof_reasoning`, `proof_assert`, or `proof_invariant` usage under `src/`; current Starshine proof sources use `where` contracts plus `.mbtp` predicates only.

## Reviewed upstream proof surfaces

- The current formal-verification manual still treats verification as a package opt-in workflow: proof-enabled packages expose executable code with specifications and proof-only companion material.
- The syntax used by Starshine remains first-class in the current docs: executable functions can carry `where` specifications with preconditions and postconditions, while proof-only predicates can live in `.mbtp` files.
- The current docs and examples also describe richer proof-only or trusted surfaces beyond Starshine's current usage, including proof/reasoning constructs and trusted/axiomatized declarations. Starshine should treat those as a larger trust boundary, not as ordinary helper-code conveniences.
- The Moon command manual/source is the more current command-shape source for `moon prove` details than the generated docs page. The local gate should continue to cite `tooling/validation-gates.md` for repo policy and this manifest for proof-specific command/trust context.

## Durable observations for Starshine

- Keep the required proof gate narrow: `moon prove src/validate_proof` remains the only required proof target on hosts with Why3/solver setup.
- Keep the helper kernel boring: arithmetic, index, suffix, label-stack, and stack-length helpers with executable tests and proof postconditions are the right current shape.
- Do not promote proof-only/trusted annotations into validator-critical code without a wiki/log update. The current absence of `proof_axiomatized` and related proof-control annotations under `src/` is an intentional trust-surface invariant.
- Distinguish exported proof evidence from live validator use. `pkg.generated.mbti` exports fifteen helper functions, while `src/validate/imports.mbt` imports nine into the validator today.
- The broader `src/validate` package remains proof-enabled, but direct broad-validator proving is still a deferred audit surface because the earlier PRV006 local audit observed package/dependency-wide proof output for direct-validator targets.

## Consumability rule

Cite this manifest together with [`../../validation/moonbit-prove-strategy.md`](../../validation/moonbit-prove-strategy.md) for Starshine proof policy and [`../../tooling/validation-gates.md`](../../tooling/validation-gates.md) for repo validation-gate policy. Do not treat this manifest as a full copy of MoonBit verification documentation or as a replacement for local executable validator tests.
