---
name: tdd
description: Practice strict test-driven development with tiny loops, clear interfaces, and refactoring only after green tests. Use when user asks for TDD or wants work done test-first.
---

# TDD

Follow strict red-green-refactor.

## Core loop
1. Write the smallest failing test.
2. Make it pass with the smallest sensible change.
3. Refactor only while tests stay green.
4. Repeat in tiny steps.

## Rules
- prefer testing public behavior
- avoid speculative abstractions
- keep interfaces simple
- use mocks sparingly
- refactor once behavior is protected by tests

See `deep-modules.md`, `interface-design.md`, `mocking.md`, `refactoring.md`, and `tests.md`.
