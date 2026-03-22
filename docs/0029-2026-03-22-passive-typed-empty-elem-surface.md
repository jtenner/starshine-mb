Status: landed higher-level WAST support for passive typed empty `elem` declarations such as `(elem (ref null $func))`.

## Scope

Document the next custom-descriptor text-surface gap exposed while probing `tests/spec/proposals/custom-descriptors/exact.wast`: the higher-level parser treated any parenthesized form after `elem` as an offset expression, so passive typed empty element declarations failed before the fixture reached later exact-reference validation.

## Current Behavior

Before this slice:

- `parse_elem` assumed the first parenthesized form after `elem` was always an offset expression.
- Bare passive typed declarations like `(elem (ref null $func))` therefore failed with a parse error.
- `module_to_wast` also always printed a table index for `elem` fields, which produced the wrong text shape for passive typed segments.

After this slice:

- `parse_elem` first tries to parse a parenthesized value type before falling back to offset-expression parsing.
- `module_to_wast` omits the synthetic table index when rendering passive element segments.
- `wast_to_binary_module` lowers passive typed empty `elem` declarations into passive typed element segments with empty payload lists.

## Correctness Constraints

- Active element segments must still keep their table index and offset.
- Passive typed declarations must preserve their explicit reference type hint even when the payload list is empty.
- Existing typed-item and func-index element abbreviations must continue lowering unchanged.

## Validation Plan

- `moon test src/wast -F '*passive typed empty elem*'`

## Performance Impact

- No meaningful runtime impact expected.
- The parser adds one small speculative value-type parse when a parenthesized form appears after `elem`.

## Open Questions

- `tests/spec/proposals/custom-descriptors/exact.wast` now parses past the passive typed `elem` declaration and advances to a later exact-reference validation mismatch.
