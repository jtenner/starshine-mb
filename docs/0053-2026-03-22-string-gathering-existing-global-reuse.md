# `StringGathering` Existing-Global Reuse

Status: landed first slice.

## Scope
- turn `StringGathering` into a live module-wide pass instead of a no-op
- pre-scan defined globals for reusable immutable `stringref` literals
- rewrite matching raw and typed function-body `string.const` sites to `global.get`
- keep imported globals and non-eligible globals out of the reuse set

## Current Behavior
- `StringGathering` now scans defined globals for the first canonical initializer of each literal where the global is:
  - defined in the module,
  - immutable,
  - exactly `stringref`,
  - initialized by direct `string.const`.
- Matching `string.const` instructions in defined raw and typed function bodies now rewrite to `global.get` of that canonical global.
- Imported globals are ignored even if their type is immutable `stringref`.
- The default optimization pipeline now routes `StringGathering` through the live runner when `has_strings` is true.

## Correctness Constraints
- The pass must not rewrite defining global initializers to `global.get` of themselves.
- First eligible global per literal stays canonical so reuse is deterministic.
- Imported globals are not reusable, since they do not provide a safe local defining initializer.
- Non-matching literals remain untouched until later slices synthesize missing defining globals.

## Validation
- typed function-body reuse coverage
- raw function-body reuse coverage
- imported-global rejection coverage
- pipeline dispatch coverage proving `StringGathering` no longer uses the module-wide no-op path

## Open Questions
- This slice intentionally does not synthesize missing defining globals yet.
- This slice also intentionally does not rewrite module-level patchpoints like dependent global initializers, so the later reorder/self-reference work remains open.
- The next slice should add missing global synthesis with deterministic naming, then follow with module-level rewrite and global-order repair.
