---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1572-2026-07-18-pick-load-signs-version-131-behavior-audit.md
  - ../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-strategy.md
  - ./fuzzing.md
---

# Starshine `pick-load-signs` HOT-IR strategy

## Descriptor and placement

Starshine exposes `pick-load-signs` as an active hot pass requiring `use_def`. It invalidates CFG, dominance, liveness, use-def, effects, loop info, and SSA after mutation. The public optimize/shrink ordering places it immediately before `precompute`.

## Raw pass-manager layer

`src/passes/pass_manager.mbt` handles three pre-HOT cases:

1. modules with no defined or imported memory skip the pass;
2. functions without a candidate producer, local read, and extension surface return unchanged without lift;
3. exact straight-line evidence shapes are rewritten directly.

The exact rewrite layer covers:

- upstream-common i32 direct signed extensions and signed shift pairs;
- upstream-common right-hand i32 masks;
- commuted i32 masks;
- i32 unsigned shift pairs;
- i64 direct signed extensions;
- i64 masks;
- i64 signed and unsigned shift pairs.

For upstream-common forms, the raw path preserves Binaryen's direct-pass extension shape. For retained Starshine-only forms, it also removes the redundant evidence expression. `src/passes/perf_test.mbt` requires zero HOT node allocations and no lift/use-def timer for representative exact forms.

## HOT candidate discovery

`pls_scan_candidate_loads(...)` iterates use-def local writes and admits only:

- live `HotOp::LocalSet` nodes;
- whose value is a live `HotOp::Load`;
- whose exact opcode is a supported i32/i64 narrow signed or unsigned load.

`local.tee`, atomic loads, and unrelated writes are not candidate producers.

## Use evidence

`pls_analyze_candidates(...)` visits every read and every read use site for candidate locals. `pls_extension_from_parent(...)` and the shift grandparent helpers classify:

- i32 direct signed extensions;
- i32/i64 low masks;
- i32/i64 signed and unsigned shift pairs;
- i64 direct signed extensions.

Unknown uses invalidate the local. Conflicting evidence widths poison the corresponding usage record. Final choice follows the upstream weighting rule: signed wins when `signed_usages * 2 >= unsigned_usages`.

## Redundant-evidence deletion

The final implementation records evidence roots that are broader than Binaryen v131:

- commuted i32 masks;
- i32 unsigned shifts;
- all recognized i64 direct/mask/shift forms.

After target signedness is known, `pls_local_all_writes_become_matching_loads(...)` allows deletion only when:

- the local is not a parameter;
- every explicit write maps to a PLS candidate;
- every candidate has the evidence width;
- every candidate reaches the required final signedness;
- at least one candidate changes from the opposite signedness.

If any condition fails, the evidence expression remains. This protects parameter-entry values, arbitrary writes, mixed producer widths, and partial signedness conversion.

Eligible evidence roots are replaced with their `local.get`, removing direct extension, mask, or shift-pair instructions after the load opcode changes.

## Focused safety surface

`src/passes/pick_load_signs_test.mbt` includes:

- i32 unsigned shift cleanup at widths 8 and 16;
- i64 unsigned shift cleanup at widths 8, 16, and 32;
- i64 signed shift cleanup at widths 8, 16, and 32;
- i64 direct and mask cleanup;
- commuted i32 mask cleanup;
- preservation when another write is not a matching load;
- preservation when a parameter value can reach the read;
- upstream unknown-use, mixed-width, width-mismatch, tee, no-memory, and imported-memory behavior.

## Performance and parity

Exact winning shapes avoid HOT lift entirely. Native-release 2,000-function medians are `6.21-7.36 ms` for Starshine versus `6.94-8.18 ms` for Binaryen v131 across mask, unsigned-shift, and i64 direct/signed-shift workloads.

The final dedicated profile intentionally reports retained-win mismatches; all other leaves and the broad/random lanes match Binaryen. See [`./parity.md`](./parity.md).
