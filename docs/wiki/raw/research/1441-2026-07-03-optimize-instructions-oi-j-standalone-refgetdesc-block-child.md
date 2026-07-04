# Optimize-instructions OI-J standalone ref.get_desc block-child slice

Date: 2026-07-03

## Scope

This note follows the OI-J roadmap in `1439-2026-07-03-optimize-instructions-oi-j-roadmap.md` and the representation/tooling blocker note in `1440-2026-07-03-optimize-instructions-oi-j-representation-blockers.md`.

Implemented behavior slice:

```wat
(ref.get_desc $A
  (ref.as_non_null
    (block (result (ref null $A))
      ;; zero or more ordered effect/trap roots
      ...
      (local.get $x))))
```

can become:

```wat
(ref.get_desc $A
  (block (result (ref null $A))
    ;; same ordered effect/trap roots
    ...
    (local.get $x)))
```

Only default mode is in scope. The standalone helper stays disabled when `traps_never_happen` is true. IIT, TNH-specific rewrites, `ref.test_desc`, descriptor-cast simplification, escaping control, and arbitrary control-shaped children remain out of scope.

## Local containment proof

The rewrite does not rebuild, move, duplicate, or sink the block. It only retargets the `RefGetDesc` child from the enclosing `RefAsNonNull` node to the exact nullable child node.

Eligibility is intentionally narrow:

- parent node is `RefGetDesc`;
- child is `RefAsNonNull` with exactly one child;
- context is not `traps_never_happen`;
- nullable child is either the previous direct `LocalGet` baseline or a `Block` with exactly one nullable reference result;
- eligible blocks have a non-empty body, a final direct `LocalGet` with one nullable reference result, and every earlier body root has zero results;
- earlier roots and their children may be effects/traps, but must not contain control/EH/multivalue constructs.

The removed `ref.as_non_null` and the remaining `ref.get_desc` trap on the same nullable value after the block has run. Since the block is kept in place and all prior roots remain inside it, ordered effects and traps stay before the null check.

## Tests

`src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc branch-free block null checks` covers:

- direct-local baseline still removes `ref.as_non_null`;
- branch-free `global.set` block removes `ref.as_non_null` and keeps `global.set` before `ref.get_desc`;
- branch-free `i32.div_u`/`drop` block removes `ref.as_non_null` and keeps the trap before `ref.get_desc`;
- two ordered `global.set` roots remain in order;
- `br`, `br_if`, `if`, `loop`, and `try_table` block children keep `ref.as_non_null`;
- ordinary non-descriptor `ref.as_non_null` remains quarantined from OI-J evidence;
- `traps_never_happen=true` keeps the standalone default-mode helper disabled.

## Probe pack

Focused probe inputs and a runner were refreshed under:

- `.tmp/oi-j-standalone-refgetdesc-block-child-20260703/inputs/*.wat`
- `.tmp/oi-j-standalone-refgetdesc-block-child-20260703/run-probes.py`
- `.tmp/oi-j-standalone-refgetdesc-block-child-20260703/probe-results.md`

Replay after building `target/native/release/build/cmd/cmd.exe` showed Starshine and Binaryen both rewrite the direct-local, effectful-block, trapping-block, and ordered-effects block probes with validating outputs. Starshine keeps the explicit null check for the focused `br` and `br_if` block-child probes while Binaryen rewrites them; classify that as an intentionally conservative control-boundary parity gap, not a semantic win. The combined `if`/`loop`/`try_table` WAT probe rewrites after other pipeline cleanup exposes the final nullable local outside the original block-child shape, so it is not used as the finite helper's proof; the in-repo HOT test remains the control/EH fail-closed contract for this slice.

## Validation

- `moon info` passed with existing warnings.
- `moon fmt` passed.
- `moon test` passed: 7344/7344.
- `moon build --target native --release src/cmd` passed with existing warnings.
- `.tmp/oi-j-standalone-refgetdesc-block-child-20260703/run-probes.py` replayed and produced validating Starshine outputs for successful modes.
- `bun fuzz compare-pass --pass optimize-instructions --count 10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared 10000/10000 with 10000 normalized matches, zero validation/property/generator/command failures, and zero mismatches.
- `git diff --check` passed.

## Remaining OI-J blockers

OI-J remains active for:

- `ref.test_desc` tooling;
- TNH/IIT behavior;
- descriptor-cast optimizer behavior beyond already covered cases;
- exactness behavior beyond current exact `ref.test` / `ref.cast` representation support;
- control/escaping branch descriptor children;
- broader descriptor generator/profile coverage.
