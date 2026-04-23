---
name: domain-model
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project's language and documented decisions.
disable-model-invocation: true
---

Interview the user relentlessly about the plan until there is shared understanding. Walk each branch of the design tree one question at a time. If something can be learned from the codebase, inspect the codebase instead of asking.

## Domain awareness
- Look for `CONTEXT.md`, `CONTEXT-MAP.md`, and `docs/adr/`.
- In single-context repos, use root `CONTEXT.md`.
- In multi-context repos, use `CONTEXT-MAP.md` to find the relevant context.
- Create context docs lazily only when there is something real to write.

## During the session
- Challenge terms that conflict with the glossary.
- Sharpen fuzzy language into canonical terms.
- Stress-test concepts with concrete scenarios.
- Cross-check user claims against the code.
- Update `CONTEXT.md` inline as terms are resolved.
- Offer ADRs only for decisions that are hard to reverse, surprising without context, and the result of a real trade-off.

See `CONTEXT-FORMAT.md` and `ADR-FORMAT.md`.
