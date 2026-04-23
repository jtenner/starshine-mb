---
name: qa
description: Perform a focused QA pass on recent changes by looking for regressions, edge cases, and user-visible rough edges. Use when user asks for QA, a review pass, or bug-hunting after implementation.
---

# QA

Perform a focused QA pass.

## Workflow
1. Identify the change surface.
2. Check the main success path.
3. Probe edge cases and failure cases.
4. Look for regressions, rough UX, missing validation, and confusing errors.
5. Report findings clearly, prioritized by severity and reproduction confidence.
