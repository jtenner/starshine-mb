# Deep Modules

Prefer modules with small interfaces that hide substantial implementation detail.

Why:
- easier to understand
- easier to test at the boundary
- less internal churn exposed to callers

When doing TDD, resist extracting many shallow helpers just to unit test them. Prefer tests at the deeper module boundary.
