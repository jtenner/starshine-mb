# Custom Descriptor Static Text Coverage

Status: landed validator and harness follow-up for higher-level custom-descriptor static fixtures.

## Scope

Document the first post-`rec` follow-up for GC custom descriptors: moving the full static `descriptors.wast` spec fixture into native text-backed harness coverage and recording the validator fixes that this surfaced.

## Current Behavior

- The native WAST spec harness now runs `tests/spec/proposals/custom-descriptors/descriptors.wast` as a dedicated static-fixture check.
- Focused `src/wast/lower_to_lib.mbt` regressions now cover valid higher-level text-authored descriptor cases for:
  - final descriptor subtype pairs,
  - nested descriptor chains,
  - cross-`rec` descriptor subtype chains.
- Descriptor-group validation now computes sibling absolute indices against the start of the current recursive group instead of the already-extended post-group environment.
- The shared recursive-group environment helper in `src/validate` now extends both `rec_stack` and `global_types`, so absolute type indices stay resolvable while validating the current group.
- Heap-type matching now keeps declared supertypes reachable for `final` types.
- Struct subtype matching now accepts trailing-field extensions while still requiring prefix field compatibility.

## Why This Slice Matters

Before this slice, the higher-level WAST surface could author the descriptor-heavy spec fixtures, but the first full static fixture lifted from `tests/spec/proposals/custom-descriptors/descriptors.wast` still failed in validation. The failures were not text-surface gaps; they exposed validator bugs in recursive-group indexing, final-type matching, and struct width subtyping.

Landing the fixture in the harness closes that gap and gives the GC text surface a higher-level spec-backed guardrail instead of relying on only binary-oriented coverage.

## Correctness Constraints

- Descriptor metadata checks must compare sibling type indices against the current group's original absolute base, not the already-extended post-group count.
- Validating a rectype must keep current-group absolute `TypeIdx` references resolvable during both subtype matching and descriptor metadata checks.
- `final` must prevent future subtypes, not erase the current type's declared supertypes.
- Struct subtyping must allow a subtype to extend its supertype with compatible trailing fields.

## Validation

- Added matcher regression coverage for final-type supertype matching and struct trailing-field subtyping.
- Added higher-level lowering-plus-validation regressions for valid descriptor subtype shapes authored as WAST text.
- Added a dedicated native spec-harness test for `tests/spec/proposals/custom-descriptors/descriptors.wast`.

## Performance Impact

- No meaningful runtime impact outside validation and native test coverage.
- Validator changes stay linear in recursive-group size and subtype-chain depth.

## Remaining Work

- Decide how much mixed-runtime custom-descriptor coverage should move into dedicated native harness tests now that the full static `descriptors.wast` fixture runs cleanly.
- Next candidate is `tests/spec/proposals/custom-descriptors/ref_get_desc.wast`, which mixes static validation with runtime-only assertions that the harness can skip command-by-command.

## Open Questions

- Whether the next fixture lift should stay at the file level in `src/wast/spec_harness.mbt` or split out a few more focused `src/wast/lower_to_lib.mbt` regressions first for easier failure localization.
