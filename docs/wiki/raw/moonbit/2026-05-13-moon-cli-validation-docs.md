# Moon CLI validation command docs refresh

_Capture date:_ 2026-05-13  
_Status:_ immutable primary-source bridge for [`docs/wiki/tooling/validation-gates.md`](../../tooling/validation-gates.md)

## Scope

This file records the official MoonBit command documentation consulted while documenting Starshine's repository validation gates. Use the living wiki page for local Starshine policy; this raw manifest only records the upstream command surfaces that make the local wrapper design easier to interpret.

## Official sources consulted

- MoonBit documentation, "The MoonBit Build System Tutorial": <https://docs.moonbitlang.com/en/latest/tutorial/build-system-tutorial.html>
- MoonBit documentation, "MoonBit's Build System Tutorial": <https://docs.moonbitlang.com/en/stable/tutorial/build-system-tutorial.html>
- MoonBit documentation, "MoonBit's Build System Tutorial" source in `moonbit-docs`: <https://github.com/moonbitlang/moonbit-docs/blob/main/tutorial/build-system-tutorial.md>
- MoonBit language manual, "Formal Verification": <https://docs.moonbitlang.com/en/latest/language/verification.html>

## Reviewed source surfaces

The refresh focused on upstream command semantics that intersect the Starshine gates:

- `moon check` type-checks packages without producing final artifacts and accepts a backend/target selection.
- `moon test` runs the project's tests and accepts backend/target selection.
- `moon fmt` is the documented formatting command for MoonBit sources.
- `moon info` refreshes package interface metadata such as `.mbti` surfaces, which matters in Starshine because public API changes can show up as generated-interface diffs.
- `moon coverage analyze` is the upstream coverage-reporting surface that Starshine wraps in `bun validate coverage`.
- `moon prove` remains a separate formal-verification entrypoint; Starshine's required proof gate stays narrower than ordinary test validation.

## Durable observations

- Starshine's `bun validate full` sequence (`moon info`, `moon fmt`, `moon check --target <target>`, `moon test --target <target>`, then fuzz) is a local orchestration policy, not a generic MoonBit command from upstream.
- The official docs explain why these commands are reasonable building blocks, but the exact order, default `wasm-gc` target, default `ci` fuzz profile, and target whitelist are owned by Starshine's scripts.
- The upstream docs do not replace repo evidence. For exact local defaults and failure behavior, prefer `scripts/lib/validate-task.ts`, `scripts/lib/task-runtime.ts`, and `scripts/test/task-family-commands.ts`.
- Formal proving should not be folded into the ordinary validation gate accidentally; official `moon prove` docs and Starshine's proof page both treat it as a distinct workflow.

## Consumability rule

Cite this raw capture together with the living validation-gates page and local script sources. Do not treat this manifest as a full copy of upstream documentation; it records provenance and the command facts relevant to Starshine's current validation workflow.
