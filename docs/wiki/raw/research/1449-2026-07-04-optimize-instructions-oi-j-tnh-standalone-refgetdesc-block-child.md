# OI-J TNH standalone `ref.get_desc` branch-free block-child slice

Date: 2026-07-04

## Scope

This slice extends the standalone OI-J `ref.get_desc` null-check cleanup from note `1448` beyond direct locals under `--traps-never-happen` (TNH), but only for the branch-free block-child subset already implemented for default/IIT behavior by note `1441`:

```wat
(ref.get_desc $A
  (ref.as_non_null
    (block (result (ref null $A))
      ;; zero or more ordered zero-result effect/trap roots
      ...
      (local.get $x))))
```

The rewrite becomes:

```wat
(ref.get_desc $A
  (block (result (ref null $A))
    ;; same ordered effect/trap roots
    ...
    (local.get $x)))
```

The implementation remains deliberately narrow:

- the `ref.get_desc` node must be a standalone function root in TNH mode;
- the nullable child must pass the existing direct-local or branch-free block-child proof;
- descriptor-cast descriptor operands are not widened by this slice;
- branch/control/EH/multivalue block children remain fail-closed;
- `ref.test_desc`, broader descriptor casts, exactness breadth, useful-type-info breadth, and generalized descriptor effect/control localization remain outside scope.

## Binaryen evidence

Roadmap probes from `.tmp/oi-j-roadmap-probes-20260703/inputs/` remain the source-backed anchors:

- `04-get-desc-effectful-child.wat`: Binaryen `version_130` removes the explicit `ref.as_non_null` from a standalone `ref.get_desc` child block containing ordered `global.set` effects under default, IIT, TNH, and `-O4 -Oz`.
- `05-get-desc-trapping-child.wat`: Binaryen removes the explicit `ref.as_non_null` from a standalone `ref.get_desc` child block containing an ordered integer trap before the final nullable local under the same modes.

The same local containment proof from note `1441` applies in TNH: the block is not rebuilt, moved, duplicated, or sunk. Its ordered effects/traps still execute before the final nullable value reaches `ref.get_desc`. Removing `ref.as_non_null` changes only which instruction performs the null trap; under TNH, Binaryen also accepts this trap movement/removal assumption.

## Implementation

`src/passes/optimize_instructions.mbt` now lets `optimize_instructions_try_move_standalone_ref_get_desc_null_check` use the existing nullable-child eligibility helper after it has proven that a TNH rewrite is rooted at the standalone `ref.get_desc`. The earlier `1448` direct-local-only TNH guard is removed, so the already-audited branch-free block proof applies to TNH roots too.

Because descriptor operands are not standalone roots, the existing root guard keeps descriptor-cast TNH behavior in its separate descriptor-operand helpers.

## Tests and validation

Updated red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc branch-free block null checks`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc branch-free block null checks'
... failed: expected TNH branch-free block child, got Heap
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc branch-free block null checks'
Total tests: 1, passed: 1, failed: 0.
```

The focused test now checks TNH direct-local, effectful branch-free block, trapping branch-free block, and ordered-effect branch-free block children. It also preserves the existing fail-closed expectations for `br`, `br_if`, `if`, `loop`, `try_table`, ordinary non-descriptor `ref.as_non_null`, and descriptor-operand coverage outside this standalone-root slice.

Additional validation after implementation:

```text
moon info
moon fmt
moon test
moon build --target native --release src/cmd
```

`moon info`, `moon fmt`, full `moon test` (`7424/7424`), and the native `src/cmd` build passed with the repository's pre-existing warnings where emitted. Manual TNH Starshine replays for roadmap probes 04 and 05 validated with `wasm-tools --features all`; each printed one `ref.get_desc` and zero residual `ref.as_non_null` instructions.

Focused descriptor-profile TNH smoke:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-standalone-refgetdesc-block-child --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface`. Remaining blockers include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, TNH/IIT control and escaping descriptor surfaces, broader exactness/useful-type-info coverage, and generalized descriptor effect/control localization.
