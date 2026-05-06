# 0510 — `signext-lowering` current-main line-anchor refresh

Date: 2026-05-06

## Why this note exists

The `signext-lowering` dossier was already complete, but the maintained pages still benefited from a tighter current-main source map and a clearer local roundtrip caveat for binary decode and pretty-print output.

## What was checked

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/signext-lowering/` folder
- `docs/wiki/raw/research/`
- official Binaryen `main` source pages for `SignExtLowering.cpp`, `pass.cpp`, and `signext-lowering.wast`

## Durable takeaways

- Binaryen `signext-lowering` still has the same five-opcode, shift-pair, feature-disable contract.
- The exact current-main source anchors are now explicit in the raw source bridge.
- Local Starshine can already parse, validate, encode, decode, HOT-lift, and pretty-print sign-extension opcodes, so the future port note should keep the pretty-printer underscore caveat visible.
- No teaching-relevant contract drift was found.

## Pages updated in response

- `docs/wiki/binaryen/passes/signext-lowering/index.md`
- `docs/wiki/binaryen/passes/signext-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signext-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-port-readiness-and-validation.md`
