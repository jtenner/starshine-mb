# Code-pushing br_on_non_null prefix local-cleanup normalizer

Date: 2026-06-25

## Scope

Follow-up for `[O4Z-AUDIT-CP]` after [`0837`](0837-2026-06-25-code-pushing-br-on-non-null-prefix-exact-hot.md) narrowed the generated `br_on_non_null` prefix-payload movement gap but left the targeted GenValid leaf blocked by output-shape drift.

## Finding

Representative post-fix mismatch: `.tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-exact-20-20260625/failures/case-000001-gen-valid`.

After the exact-HOT movement fix, both Binaryen and Starshine sink the generated user-local sets after `br_on_non_null`. The remaining representative diff was local cleanup / allocation debris around already-materialized values:

- Starshine emitted the prefix-payload drop through a single-use copy local, `local.set tmp (local.get prefix)` followed later by `drop (local.get tmp)`.
- Binaryen emitted the direct `drop (local.get prefix)` at that point.
- Binaryen also used extra single-use local copy / `local.tee` copy carriers near the outer top-level drops, while Starshine dropped the already-available locals directly.
- Tuple-typed local declarations were not being canonicalized by the existing `local-cleanup-debris` normalizer, so equivalent tuple carrier local names still mismatched after scalar local renaming.

Agent classification: narrow compare-normalization blocker, not a missing code-pushing movement proof. The normalized patterns are single-use temp copies whose only use is the later dropped value, with no intervening source-local write before the drop. Removing those copy/drop carriers does not hide branch/control/effect drift; it exposes the already-equal movement shape.

## TDD and implementation

Added red-first tests in `scripts/lib/pass-fuzz-compare-task.test.ts` for `local-cleanup-debris`:

- `local-cleanup-debris erases single-use local copy drops`
- `local-cleanup-debris erases single-use local tee copy drops`

The focused copy-drop test failed before implementation because the normalizer kept the extra local declaration, `local.set`, and `drop (local.get tmp)`.

Implemented a narrow harness normalizer change in `scripts/lib/pass-fuzz-compare-task.ts`:

- erase `local.set tmp (local.get source)` when `tmp` is only set and later dropped, and `source` is not written between the copy and the drop;
- erase `local.set tmp (local.tee teeTmp (local.get source))` under the same single-use conditions when the tee local is otherwise unused;
- allow tuple-valued local declarations such as `(local $11 (tuple i32 externref))` to participate in unused-local deletion and canonical local renaming.

Focused validation:

```sh
bun test scripts/lib/pass-fuzz-compare-task.test.ts -t 'single-use local copy drops'
# failed before implementation

bun test scripts/lib/pass-fuzz-compare-task.test.ts
# passed 34/34
```

## Targeted profile refresh

The targeted prefix-payload lane is now clean under the documented `local-cleanup-debris` normalizer at 200 requested cases:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-on-non-null-prefix --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-copydrop-normalized2-200-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
# compared 200/200; normalized 0; cleanup-normalized 200; raw mismatches 0; validation/generator/property/command failures 0
# cache: wasm-smith 0 hits/0 misses; Binaryen 200 hits/0 misses; Binaryen failures 0 hits/0 misses
```

This is not final pass closeout. It is targeted evidence that the remaining generated prefix-payload mismatch family is representational local-cleanup debris after the code-pushing movement fix.

## Next work

Before adding `code-pushing-br-on-non-null-prefix` to `code-pushing-all`, run a larger targeted lane, preferably `1000` requested cases with the same normalizer. If green, add the leaf to the aggregate, update generator tests and docs, then run a bounded aggregate smoke. Keep `code-pushing-br-if-value` targeted-only because its value-`br_if` temporary-local family is still open.
