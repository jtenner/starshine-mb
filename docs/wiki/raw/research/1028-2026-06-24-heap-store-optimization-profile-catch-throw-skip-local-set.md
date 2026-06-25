# Heap-store-optimization profile catch/throw skip-local-set coverage

Date: 2026-06-24

## Summary

This profile-only slice extends the dedicated `heap-store-optimization` GenValid profile so generated HSO artifacts include a catchable `try_table` / `throw` skip-local-set hazard, not just fold-positive constructor/store roots and non-throwing wrapped store barriers.

The new generated root places the fresh-struct `local.set` inside a `try_table` body with a catchable sibling `throw` path, then emits a later same-local `struct.set`. This covers the HSO-F LazyLocalGraph-style family where the constructor write may be skipped by exception control flow, so HSO must not assume the later local use is unconditionally tied to that constructor.

This does not change the HSO pass implementation. It makes the dedicated profile cover one generated catch/throw skip-local-set negative that was previously absent from HSO profile artifacts.

## Files changed

- `src/fuzz/main_wbtest.mbt`
  - Strengthened the HSO profile artifact test red-first to require tag facts and a `throw` opcode, in addition to the existing constructor/default/descriptor, `try_table`, `table.set`, `memory.fill`, and `br_if` feature checks.
- `src/validate/gen_valid.mbt`
  - Enabled one tag in the HSO profile so the body generator can emit catchable exception control.
  - Appended a deterministic `try_table` / `throw` skip-local-set hazard to the HSO profile body slice.

## TDD evidence

Red-first command:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
```

Result before implementation: failed in `emit gen-valid heap-store-optimization profile records GC store opportunities` because generated HSO profile artifacts had no tags / `throw` feature.

Green command after implementation:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
```

Result: `92/92` passed.

## Compare evidence

Native compare binary was refreshed with the workspace-specific command:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with existing `src/passes/pass_manager.mbt` unused-function warnings; refreshed `target/native/release/build/cmd/cmd.exe`.

Dedicated profile smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-catch-throw-v2-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation failures `0`; property failures `0`; generator failures `0`; command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.

Direct smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-catch-throw-profile-direct-v2-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Result: compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation failures `0`; property failures `0`; generator failures `0`; command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

Additional command:

```sh
moon fmt
```

Result: passed.

## Classification

The only intentional output-shape normalizer remains the existing `local-cleanup-debris` profile normalizer from research note `1023`: Binaryen retains HSO `nop` placeholders while Starshine emits smaller nop-free validated output. This slice did not add or classify any new pass output-shape difference.

## Remaining work

This is not an HSO-F/G/J closeout. The dedicated profile now covers one catchable `try_table` / `throw` skip-local-set hazard, but broader generated catchable descriptor wrappers, branch/throw descriptor skip-local-set families, function-external exit variants, broader descriptor barriers, performance, O4z neighborhood replay, and the final full signoff matrix remain open.
