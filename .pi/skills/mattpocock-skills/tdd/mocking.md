# Mocking

Use mocks sparingly.

Prefer:
- in-memory substitutes
- real collaborators when cheap
- tests against observable behavior

Mock at the true boundary to external systems, not between tightly coupled internal pieces.
