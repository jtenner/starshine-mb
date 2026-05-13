# MoonBit formal-verification docs refresh

_Capture date:_ 2026-05-13  
_Status:_ immutable primary-source bridge for [`docs/wiki/validation/moonbit-prove-strategy.md`](../../validation/moonbit-prove-strategy.md)

## Scope

This file records the official MoonBit verification sources consulted while refreshing Starshine's formal-proof wiki page. It extends the older repo-authored investigations in [`../research/0077-2026-04-10-moonbit-prove-strategy.md`](../research/0077-2026-04-10-moonbit-prove-strategy.md) and [`../research/0515-2026-05-06-validate-proof-boundary-audit.md`](../research/0515-2026-05-06-validate-proof-boundary-audit.md); use the living wiki page for Starshine policy.

## Official sources consulted

- MoonBit language manual, "Formal Verification": <https://docs.moonbitlang.com/en/latest/language/verification.html>
- MoonBit blog, "MoonBit v0.9.1 Beta Preview: First-Class Formal Verification": <https://www.moonbitlang.com/blog/first-class-formal-verification>

## Reviewed source surfaces

The refresh focused on these official-doc claims because they affect local Starshine proof policy:

- `moon prove` is the documented package-level verification entrypoint.
- Packages opt in through `moon.pkg.json` / `moon.pkg` with `proof-enabled`.
- The verification workflow is Why3-backed and the official setup path mentions Z3, CVC5, and Alt-Ergo solver choices.
- MoonBit separates executable code from proof-only `.mbtp` files.
- The docs describe package dependencies as assumed when proving a target package, which matches Starshine's policy of isolating the required gate in `src/validate_proof` instead of widening broad dependency proof output prematurely.

## Durable observations

- The official docs are newer than Starshine's original April 2026 proof investigation and should be cited before the older raw note when explaining current `moon prove` setup.
- The docs strengthen the case for keeping `src/validate_proof` as a small proof-enabled package: it has pure arithmetic/index helpers, narrow dependencies, and `.mbtp` predicates beside executable MoonBit code.
- The docs do **not** remove Starshine's local PRV006 caveat: file-targeted direct-validator commands were observed locally to emit broad `src/validate` plus dependency proof artifacts, so broad `src/validate` proving remains optional until intentionally re-audited.

## Consumability rule

Cite this raw capture together with the living proof-strategy page. Do not treat this manifest as a full copy of upstream documentation; it records provenance and the specific doc surfaces relevant to Starshine's current proof boundary.
