---
name: improve-codebase-architecture
description: Explore a codebase to find opportunities for architectural improvement, focusing on making the codebase more testable by deepening shallow modules. Use when user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make a codebase more AI-navigable.
---

# Improve Codebase Architecture

Explore the codebase the way an AI would and look for friction that suggests shallow modules or awkward seams.

## Process
1. Explore organically.
2. Note places where understanding requires bouncing across too many files.
3. Identify tightly coupled clusters that could become a deeper module.
4. Present candidate opportunities, including dependency category and test impact.
5. For a chosen candidate, design multiple radically different interfaces.
6. Compare them and recommend one.
7. Turn the result into a refactor RFC / GitHub issue.

See `REFERENCE.md`.
