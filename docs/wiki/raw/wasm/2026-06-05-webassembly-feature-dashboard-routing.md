# WebAssembly Feature Dashboard Routing

- Capture date: 2026-06-05
- Source family: official WebAssembly feature-status dashboard plus standards/proposal routing pages
- Reason for capture: keep wiki wording from treating implementation support dashboards as standards authority, Starshine support evidence, or external-validator command evidence.

## Primary sources checked

1. WebAssembly feature status dashboard, checked 2026-06-05: <https://webassembly.org/features/>
2. WebAssembly proposals repository README / active proposals tracker, checked 2026-06-05: <https://github.com/WebAssembly/proposals>
3. WebAssembly finished proposals table, checked 2026-06-05: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>
4. WebAssembly Core Specification introduction, checked 2026-06-05: <https://webassembly.github.io/spec/core/intro/introduction.html>

## Durable takeaways

- The `webassembly.org/features/` page is an implementation-support dashboard. It is useful for quickly seeing browser/runtime support and for deciding which engines may be worth trying in a runtime repro. Older local raw notes sometimes used that page as a finished-proposals shorthand; living pages should now treat this note as the evidence-tier correction and cite the GitHub finished-proposals table for finished/Core claims.
- The dashboard is not the standards-status authority. Stable/Core claims should still cite the Core spec or finished-proposals table, and active proposal phase claims should still cite the proposals tracker plus the proposal repository.
- Browser/runtime support is not Starshine implementation evidence. A feature can be supported in major engines while Starshine still lacks a WAST parser arm, binary codec, validator rule, generator gate, optimizer handling, or CLI surface.
- Browser/runtime support is also not external-validator command evidence. `wasm-tools`, WABT, and Binaryen adapters have their own installed versions, command-line flags, and feature defaults; cite the exact adapter command surface when classifying fuzz or validation outcomes.
- Conversely, a feature being absent or partial in a browser dashboard does not prove Starshine should reject it. Use the Starshine source/tests plus official spec/proposal sources to decide the local contract.

## Starshine interpretation rules

1. Use the feature dashboard as an **implementation availability hint**, not as a normative source for Core/proposal status.
2. For standards wording, keep routing through [`2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](2026-06-04-webassembly-active-proposal-routing-current-refresh.md), focused proposal bridges, Core pages, and the finished-proposals table.
3. For local support wording, cite Starshine source, tests, generator ledgers, focused WAST/validator pages, or pass dossiers.
4. For external-validator disagreements, cite the installed tool and command line. A browser support row can motivate an engine smoke test, but it cannot replace `wasm-tools`, WABT, or Binaryen adapter evidence.

## Follow-ups

- If a future wiki page needs browser/engine-specific runtime guidance, create a focused tooling/runtime note instead of expanding the feature-status page into a browser-compatibility matrix.
- If Starshine adds runtime execution engines to compare-pass or fuzz workflows, record exact engine versions and flags separately from this dashboard-routing note.
