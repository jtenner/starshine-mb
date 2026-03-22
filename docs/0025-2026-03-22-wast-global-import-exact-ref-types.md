# WAST Global Import Exact Ref Types

Status: landed higher-level WAST support for parenthesized exact typed refs on imported globals.

## Scope

Document the next mixed-runtime custom-descriptor fixture slice: imported globals now accept the same parenthesized ref-type forms as defined globals, including exact typed refs such as `(ref null (exact $b))`.

## Current Behavior

- Imported globals no longer assume every parenthesized global type is `(mut ...)`.
- The import parser now reuses the shared global-type parser path already used by defined globals.
- Higher-level WAST now accepts imported globals like:
  - `(import "A" "b" (global $g (ref null (exact $b))))`
- The printed module surface preserves the same exact typed ref spelling.
- Lowering preserves the exact typed global import as an exact nullable `@lib.RefType`.

## Why This Slice Matters

After the `struct.get*` slice, `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` advanced to the next front-end failure: an imported global descriptor binding written as `(global $b (ref null (exact $b)))` was rejected with `expected 'mut'`.

The lower layers already model exact typed refs, so the missing behavior was only the import parser’s global-type special case.

## Correctness Constraints

- Imported globals must parse mutable and non-mutable parenthesized forms through one shared path.
- Exact typed refs on imports must lower the same way as exact typed refs in function signatures and defined globals.
- This change must not relax the syntax into accepting malformed parenthesized global descriptors.

## Validation

- Added end-to-end parse, print, and lowering coverage in `src/wast/global_import_ref_type_test.mbt`.
- Targeted red-to-green gate during landing:
  - `moon test src/wast -F '*imported globals with exact typed ref types*'`
- Follow-up confirmation after the slice:
  - `moon test src/wast/spec_harness.mbt --target native -F '*mixed-runtime custom descriptor fixtures*'`
  - the fixture advanced past the imported-global parse failure and exposed the next grouped type-index issue.

## Performance Impact

- No meaningful runtime impact.
- Parser work only shifts imported globals onto the existing shared global-type code path.

## Remaining Work

- `ref_get_desc.wast` next exposed implicit function-type index assignment after grouped `rec` entries.
- The mixed-runtime fixture still needs later semantic descriptor work beyond this parse fix.

## Open Questions

- Whether other import-only parser forks should be collapsed onto shared field parsers now that this one already drifted from defined-global behavior.
