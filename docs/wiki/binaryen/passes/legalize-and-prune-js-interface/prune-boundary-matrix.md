---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md
  - ../../../raw/research/0292-2026-04-24-legalize-and-prune-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0224-2026-04-21-legalize-and-prune-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Prune boundary matrix

Use this page with the 2026-04-24 raw primary-source capture in [`../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md). The matrix is sourced from Binaryen's shared `LegalizeJSInterface.cpp` owner file and the dedicated `legalize-and-prune-js-interface.wast` fixture.

## Why this page exists

The easy part to remember is “the sibling prunes things.”
The hard part is remembering **exactly what kind of thing gets what kind of fallback**.

This page is the compact answer.

## Illegality predicate

After plain `i64` legalization finishes, the sibling still considers a boundary item illegal when its visible type surface includes features from:

- SIMD
- multivalue
- exception handling
- stack switching

Special note for functions:

- multivalue results are illegal
- multivalue params are tolerated

## Function matrix

| Boundary situation | What Binaryen does | Why it matters |
| --- | --- | --- |
| Imported function, result `none`, still illegal | Remove import status and emit `nop` body | Smallest no-result stub |
| Imported function, defaultable result, still illegal | Remove import status and emit zero/default literal body | Keeps module valid without host import |
| Imported function, nondefaultable result, still illegal | Remove import status and emit `unreachable` | Binaryen has no valid zero/default to return |
| Exported function, still illegal | Remove the export | Hide JS-illegal surface rather than rewrite it further |
| Imported **and** exported function, still illegal | Do both: stub body and remove export | Import replacement and export removal are independent |
| Boundary function no longer illegal after plain `i64` legalization | Leave it alone | The sibling is additive, not a blanket rewrite |

## Global matrix

| Boundary situation | What Binaryen does | What it does **not** do |
| --- | --- | --- |
| Exported global with legal JS-visible type | Keep export | No change |
| Exported global with illegal JS-visible type | Remove export | Does not rewrite or delete the global |
| Non-exported global with illegal type | Ignore it | Pass is boundary-scoped |

## Result-defaultability rule

The imported-function stub rule is easiest to remember as:

- no result -> `nop`
- has result and result is defaultable -> zeros/defaults
- has result and result is nondefaultable -> trap

The lit file makes each branch concrete:

- `imported-v128-param-noresult` -> `nop`
- `imported-v128`, `imported-mv`, `imported-v128-defaultable` -> zero/default values
- `imported-v128-nondefaultable` -> `unreachable`

## Refinalization boundary

The matrix above happens before the pass finishes.
After function pruning, Binaryen runs `ReFinalize()` because changing an import into a normal internal function can affect exact function-reference typing.

So the real sequence is:

1. prune functions
2. refinalize
3. prune illegal global exports

## Beginner memory aid

A good short mnemonic is:

- **imports get bodies**
- **exports lose visibility**
- **globals only lose visibility**
- **nondefaultable results trap**

Current Starshine does none of these prune rewrites yet; see [`./starshine-strategy.md`](./starshine-strategy.md) for the exact unknown-pass status and future module-pass landing map.
