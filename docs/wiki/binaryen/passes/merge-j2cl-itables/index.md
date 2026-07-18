---
kind: entity
status: supported
starshine_status: upstream-only
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/J2CLItableMerging.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/j2cl-merge-itables.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/j2cl-merge-itables-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/j2cl-merge-itables-public.wast
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - ../../../../../src/passes/optimize.mbt
related:
  - ../tracker.md
  - ../index.md
  - ../reorder-globals-always/index.md
  - ../global-type-optimization/index.md
  - ../../release-horizon-and-oracles.md
---

# `merge-j2cl-itables`

## Status

`merge-j2cl-itables` is a public, J2CL-specific Binaryen GC module pass. It embeds interface dispatch-table fields into virtual dispatch tables to reduce per-class dispatch metadata.

Binaryen registers the exact CLI spelling `merge-j2cl-itables`, but does not add it to the generic optimize/shrink scheduler. It is intended to run explicitly and early on recognizable J2CL output.

Starshine has no registry spelling or implementation. Treat this as **upstream-only specialized tooling**, not an O4z blocker.

## Recognized input contract

The pass relies on J2CL type-name metadata and layout conventions rather than trying to discover arbitrary equivalent object models.

For each Java class struct it expects either:

- ordinary fields named `vtable` and `itable`; or
- a custom descriptor used as the vtable plus a class field named `itable`.

It also expects consistent itable widths and recognizable vtable/itable global initializers. Several malformed or already-transformed shapes terminate with a diagnostic saying the pass needs to be the first pass on J2CL output.

The pass is GC-gated and requires `--closed-world`.

## Transformation shape

The released implementation runs four ordered phases:

1. **Collect J2CL class/vtable/itable families.** Type-name field metadata identifies the class layout, dispatch-table heap types, and corresponding globals.
2. **Expand vtables.** Itable field initializers are prepended to each vtable construction, and existing vtable field indices are shifted. Descriptor-backed vtables preserve the first descriptor field for a possible JS prototype.
3. **Reroute itable reads.** Class-to-itable and itable-field `struct.get` paths become reads through the expanded vtable or descriptor.
4. **Rewrite types.** A `GlobalTypeRewriter` subclass inserts itable fields into vtable structs, removes the separate class itable field, preserves names, and remaps module-wide type uses.

Because expanded vtables may now initialize fields using itable globals, the pass ends with a nested `reorder-globals-always` run to restore valid global initialization order.

## Released v131 public-type safety rule

V131 adds a fail-closed public-type check before mutation. For every recognized class family, the pass computes Binaryen's mode-selected public heap types and rejects the transform if any of these are public:

- the Java class struct;
- its vtable type;
- its itable type.

The dedicated `j2cl-merge-itables-public.wast` fixture covers all three cases. This is required because merging fields changes structural type identity and dispatch-table layout; doing so to a host-visible type would violate the external type contract even in a closed-world compilation pipeline.

This safety check is distinct from the existing `--closed-world` gate. Closed world permits whole-program reasoning, but it does not make imported/exported or otherwise public types private.

## Important boundaries

- This is not a general struct-field merge pass.
- Type-name metadata is part of input recognition.
- Vtable fields are assumed immutable; the implementation adjusts `struct.get` and `struct.new` shapes rather than supporting arbitrary later `struct.set` mutation.
- Descriptor-backed layouts reserve one leading field.
- Missing classes, inconsistent itable sizes, unrecognized initializers, or unrecognized getter shapes are fatal input-contract failures.
- The nested global reorder is part of correctness, not optional cleanup.

## Future Starshine rule

A future port should not begin with expression rewrites. Required preparation includes:

1. an exact J2CL metadata/layout recognizer with no mutation;
2. closed-world and public-type classification;
3. fail-closed tests for all v131 public class/vtable/itable cases;
4. atomic type/layout planning before any `struct.get` or `struct.new` rewrite;
5. module-wide heap-type, field-name, global, and instruction repair;
6. descriptor-backed fixtures;
7. global initializer dependency repair equivalent to `reorder-globals-always`;
8. direct v131 oracle and validation evidence.

Do not schedule the pass in generic presets merely because it is public. It is source-language-specific and should require an explicit J2CL pipeline decision.
