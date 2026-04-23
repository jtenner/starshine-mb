---
name: migrate-to-shoehorn
description: Migrate existing type-test suites to ShoeHORN-style assertions and fixtures. Use when user wants to move from older TypeScript type-test tools to ShoeHORN, replace brittle type assertions, or standardize type-level tests.
---

# Migrate to Shoehorn

Help migrate existing type tests to Shoehorn.

## Workflow
1. Find current type-test patterns (for example `tsd`, `expectTypeOf`, or handwritten compile-time assertion helpers).
2. Explain the target Shoehorn pattern that will replace them.
3. Migrate a small representative slice first.
4. Preserve existing intent while simplifying fixtures and assertions.
5. Update docs and examples to the new style.
6. Finish the rest of the suite once the approach is validated.
