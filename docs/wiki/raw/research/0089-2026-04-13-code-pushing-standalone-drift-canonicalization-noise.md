# 0089 - standalone `Func 1948` / `Func 1977` drift is now mostly canonicalization noise

## Context

- Follow-up to [`0087`](./0087-2026-04-13-code-pushing-standalone-func1977-hot-lower-recursive-fix.md) and [`0088`](./0088-2026-04-13-code-pushing-nonvoid-prefix-block-relaxation.md).
- `0088` reopened the intended pass-level motion families in current-source standalone `Func 1948` and `Func 1977`, but the exact final standalone Starshine-vs-Binaryen WAT still did not match byte-for-byte.
- The next question was whether those remaining exact diffs still represented real `code-pushing` misses or whether they were mostly inherited from no-pass reconstruction differences or from Starshine writeback canonicalization after the now-admitted move.

## Refresh Method

Using the same reconstructed standalone inputs from `standalone-scan-20260413d`:

- `moon run src/cmd --target native -- --out ... func1948.wat`
- `moon run src/cmd --target native -- --code-pushing --out ... func1948.wat`
- `moon run src/cmd --target native -- --out ... func1977.wat`
- `moon run src/cmd --target native -- --code-pushing --out ... func1977.wat`
- `wasm-opt --all-features` and `wasm-opt --all-features --code-pushing` on the same standalone inputs
- `wasm-opt --strip-debug -S` to canonicalize each generated Wasm back to WAT before diffing

That produced fresh same-tree comparison files under:

- `.tmp/codex-tmp/source-standalone-check-20260413f/func1948-{star-no,star,bin-no,bin}.wat`
- `.tmp/codex-tmp/source-standalone-check-20260413f/func1977-{star-no,star,bin-no,bin}.wat`

## Findings

### 1. `Func 1948` now matches Binaryen on the reopened motion families

The current tree now reorders the same repeated alias families that Binaryen does:

- `local.set $145` through `local.set $135` are moved after their later decref-style `if`s
- `local.set $153` through `local.set $163` are likewise moved into the later clustered tail position

Representative refreshed snippets:

- In `func1948-bin-no.wat`, `local.set $145` still appears **before** the later `if`
- In both `func1948-bin.wat` and `func1948-star.wat`, `local.set $145` appears **after** that later `if`
- In `func1948-star-no.wat`, `local.set $153` still appears before the later `local.set $188` / `if` ladder
- In both `func1948-bin.wat` and `func1948-star.wat`, `local.set $153` through `local.set $163` appear in the clustered tail position

So the old standalone `Func 1948` exact mismatch is no longer evidence of a missed `code-pushing` admission for those repeated ladder families.

### 2. Most of the remaining `Func 1948` exact diff already exists without `code-pushing`

Fresh line-level diff statistics make that split clear:

- `func1948-star-no.wat` vs `func1948-bin-no.wat`
  - similarity ratio: `0.7310`
  - changed lines: `1852`
- `func1948-star.wat` vs `func1948-bin.wat`
  - similarity ratio: `0.7220`
  - changed lines: `1918`
- `func1948-star-no.wat` vs `func1948-star.wat`
  - changed lines: `306`
- `func1948-bin-no.wat` vs `func1948-bin.wat`
  - changed lines: `132`

That means the overwhelming majority of the exact final standalone `Func 1948` WAT drift is already present in the no-pass reconstruction and writeback baseline. `code-pushing` adds some additional divergence, but the reopened moved-local family itself is no longer the sharp frontier.

### 3. `Func 1977` now matches Binaryen on the reopened moved locals too

The refreshed outputs show the same concrete move family on both sides:

- `local.set $38` is after the later `if` in both `func1977-bin.wat` and `func1977-star.wat`
- `local.set $33` is after its later `if` in both `func1977-bin.wat` and `func1977-star.wat`
- `local.set $45` is after the local-`50` / later `if` ladder in both `func1977-bin.wat` and `func1977-star.wat`

So the previously reported standalone `Func 1977` exact mismatch is no longer evidence that current `code-pushing` fails to make the old local-`38` / local-`33` / local-`45` moves.

### 4. The remaining `Func 1977` exact pass diff is mostly Starshine writeback canonicalization

`Func 1977` differs from `Func 1948` in one important way: the no-pass baseline is already very close.

Fresh line-level diff statistics:

- `func1977-star-no.wat` vs `func1977-bin-no.wat`
  - similarity ratio: `0.9844`
  - changed lines: `31`
- `func1977-star.wat` vs `func1977-bin.wat`
  - similarity ratio: `0.6358`
  - changed lines: `585`
- `func1977-star-no.wat` vs `func1977-star.wat`
  - changed lines: `466`
- `func1977-bin-no.wat` vs `func1977-bin.wat`
  - changed lines: `18`

So the remaining exact final standalone `Func 1977` drift is not a baseline no-pass mismatch like `Func 1948`. Instead, it is mostly the shape Starshine writes back **after** the now-correct pass-level move: Starshine rewrites the admitted motion through a much larger branch/block canonicalization than Binaryen does.

In other words:

- the pass-level moved locals now agree
- the final exact WAT still differs because Starshine lower/writeback chooses a different valid structural form for the same admitted motion

## Durable Conclusion

The old standalone `Func 1948` / `Func 1977` exact mismatches are no longer good direct evidence of missing `code-pushing` motion.

The sharper split is now:

- `Func 1948`: remaining exact standalone drift is **mostly inherited no-pass reconstruction / canonicalization noise**
- `Func 1977`: remaining exact standalone drift is **mostly writeback canonicalization after the correct admitted move**

So the next parity frontier should move back to fresh whole-artifact/runtime evidence rather than treating exact standalone `Func 1948` / `Func 1977` WAT mismatch as a direct pass-admission blocker.

## Follow-Up

- Refresh the real artifact/runtime picture again when budget permits.
- Only reopen standalone `Func 1948` / `Func 1977` lowering work if a fresh artifact diff or runtime delta shows a surviving problem beyond this standalone exact-WAT noise.
- If exact canonical matching still becomes necessary later, treat `Func 1977` first as a writeback-shape question rather than another `code-pushing` admission question.
