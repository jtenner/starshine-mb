---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-minimize-rec-groups-current-main-world-mode-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./permutations-brands-and-public-conflicts.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `minimize-rec-groups` Fuzzing Status

## Current status: planned-only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `minimize-rec-groups` today.

- `--minimize-rec-groups` is absent from `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), so the comparison harness rejects it during argument parsing before generation or optimizer execution.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) tracks `minimize-rec-groups` as **BoundaryOnly**. The known name deliberately rejects active execution because Starshine has no module-pass implementation.
- A Binaryen result, a harness parser failure, a boundary-only rejection, or zero compared cases is not Starshine parity evidence.

The existing Binaryen dossier remains the source of truth for the GC-gated private-rec-group rewrite, public-shape conflicts, valid permutations, and brand-type fallback. This page corrects the stale local smoke-lane claim without claiming a new upstream behavior finding.

## Safe inspection now

```text
bun fuzz compare-pass --list-passes
```

This reports harness admission only; it does not exercise the Binaryen pass or a Starshine transform.

## Future runnable-lane template

Use this only after every gate below is true:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass minimize-rec-groups --count 10000 --seed 0x5eed \
  --gen-valid-profile <gc-rec-group-profile> --require-feature gc \
  --out-dir .tmp/pass-fuzz-minimize-rec-groups --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

### Admission gates

1. **Harness:** admit `--minimize-rec-groups` and test that it maps to Binaryen's public flag.
2. **Starshine:** replace the boundary-only entry with an active module pass, dispatcher route, owner, and focused tests.
3. **GC reachability:** add fixtures or a profile that creates private and public recursive groups, rather than ordinary scalar-only valid modules that never exercise type-graph rewriting.
4. **Semantic coverage:** require a meaningful compared-case threshold and cover private singleton splitting, public shape conflicts, valid permutation resolution, required brand insertion, descriptor/subtype constraints, feature-sensitive exactness, complete type-use/name/index remapping, and an explicit world/visibility-policy fixture matrix. The current-main owner uses one `WorldMode` for both candidate visibility and final rewriting; separate modes need evidence before they count as parity.

Until then, targeted Binaryen fixtures are upstream-oracle preparation only. Do not infer local support from Binaryen's public registration or from a boundary-only registry entry.
