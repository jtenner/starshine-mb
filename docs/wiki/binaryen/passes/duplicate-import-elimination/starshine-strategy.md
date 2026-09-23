---
kind: concept
status: strong
last_reviewed: 2026-09-22
sources:
  - https://webassembly.github.io/spec/js-api/#read-the-imports
  - ../../../raw/binaryen/2026-07-28-duplicate-import-elimination-v131-refresh.md
  - ./index.md
  - ./fuzzing.md
  - ../../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../../src/passes/duplicate_import_elimination_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../tests/optimizer/regressions/host-identity.test.ts
  - ../../../../../src/passes/legacy_eh_audit_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_wbtest.mbt
  - ../../../../../src/fuzz/main.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine strategy for `duplicate-import-elimination`

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Status

`duplicate-import-elimination` is an active compatibility pass with a host-safety guard. Direct invocation preserves repeated function imports because each declaration is an independent host lookup and may resolve to a distinct function. This intentionally supersedes the older direct Binaryen-v131 parity contract.

`duplicate-import-elimination-assume-stable-bindings` is the explicit capability-preserving variant. Its caller guarantees that repeated module/component resolution has no observable side effects and resolves, after embedding conversion, to the same WebAssembly function identity. The ordinary `--closed-world` option describes module-graph reasoning and does not satisfy this host binding contract.

Historical merge-parity evidence remains useful for understanding Binaryen:

- Binaryen v131's owner, `OptUtils::replaceFunctions` helper, and dedicated input fixture are byte-identical to the retained v130 versions.
- Starshine's refreshed five-leaf GenValid aggregate covers every released detection, rewrite, removal, EH, module-code, metadata, and non-function boundary family.
- The required v131 matrix completed regular `100000`, dedicated `10000`, random-all `10000`, and wasm-smith `10000` requests.
- Every dedicated family normalized exactly to Binaryen.

## Local code map

- transform owner: [`src/passes/duplicate_import_elimination.mbt`](../../../../../src/passes/duplicate_import_elimination.mbt)
- focused and generated-family tests: [`src/passes/duplicate_import_elimination_test.mbt`](../../../../../src/passes/duplicate_import_elimination_test.mbt)
- decoded legacy-EH recursive rewrite test: [`src/passes/legacy_eh_audit_wbtest.mbt`](../../../../../src/passes/legacy_eh_audit_wbtest.mbt)
- registry and public preset references: [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- module-pass dispatch: [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- family generators and aggregate: [`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt)
- generator assertions: [`src/validate/gen_valid_wbtest.mbt`](../../../../../src/validate/gen_valid_wbtest.mbt)
- manifest family labels: [`src/fuzz/main.mbt`](../../../../../src/fuzz/main.mbt)
- manifest coverage test: [`src/fuzz/main_wbtest.mbt`](../../../../../src/fuzz/main_wbtest.mbt)

## Transform-family analysis

| Family | Binaryen v131 contract | Starshine implementation and evidence | Verdict |
| --- | --- | --- | --- |
| imported-function scope | iterate `ImportInfo.importedFunctions` only | default returns the original module for a repeated lookup; explicit stable-binding mode reaches the function-only planner | safe default plus explicit contract |
| identity bucket | exact `(module, base)` strings | pair-valued keys preserve embedded-NUL identity; the first repeated key activates the default guard regardless of type | conservative and source-order preserving |
| exact type gate | compare current representative `Function::type` | default never reaches it for a repeated lookup; explicit stable-binding mode retains the historical gate | host-safety divergence with retained capability |
| users and module code | retarget function references to the representative | default preserves every `FuncIdx`; explicit mode rewrites the full historical surface | policy dependent |
| names and annotations | update owners after removal | default preserves all metadata; explicit mode remaps structured owners and clears stale raw names | policy dependent |
| duplicate removal | remove every later duplicate after retargeting | default preserves every import; explicit mode removes type-compatible later entries | policy dependent |
| idempotence | second run finds no later duplicate | both policies are fixed points | exact fixed point |

Default Starshine intentionally keeps the input shape. The explicit variant retains the old size transform only when its stronger embedding contract is true.

## Correctness invariants

The pass must preserve:

- every import declaration, lookup count, and source order;
- distinct imported function indices even for equal names and signatures;
- every body, module-code, start, export, and element `FuncIdx`;
- structured names, raw name bytes, and function-annotation ownership;
- exact module equality on the guarded path.

## Historical profile and matrix result

The refreshed aggregate has leaves for body references, identity, module code, legacy EH, and non-function negatives. Before the safety divergence, the 10,000-case dedicated lane selected every leaf and every case label and normalized `10000/10000` with zero failures. Current focused tests reuse those generated shapes and require exact input preservation.

The complete matrix is in [`fuzzing.md`](./fuzzing.md). Its only raw residuals are pass-independent:

- 625 random-all `remove-unused-brs-control` modules with no imports and an already-owned one-byte local-run canonicalization loss;
- one wasm-smith module with no function imports and unreachable-control debris, confirmed by the existing normalizer;
- 44 Binaryen/tool command failures, with zero Starshine command or validation failures.

These results are retained as provenance for the historical planner and do not establish the current direct contract.

## Performance

These retained timings measure the historical merge implementation:

- import-heavy: `0.447 ms` Starshine versus `2.00646 ms` Binaryen (`0.223x`)
- user-heavy: `0.2835 ms` Starshine versus `0.946297 ms` Binaryen (`0.300x`)

Re-run timing before making performance claims for the explicit stable-binding variant.

## Scheduler boundary

The canonical neighborhood remains:

`duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`

The slot remains queued, and preset-origin DIE still skips modules with function
imports. Direct `--duplicate-import-elimination` now enforces the same semantic
contract locally by preserving every repeated lookup slot. The [Node host regression](../../../../../tests/optimizer/regressions/host-identity.test.ts)
asserts two getter reads and result `3` for direct, preset, and mixed explicit
requests. The preset gate remains useful defense in depth and keeps automatic
candidate selection from relying on the historical planner.
The CLI's pure O4z size portfolio also omits DIE from automatic candidate
rosters when the original module has imports or exports. Explicit requests now
reach the active pass and preserve the module through the local guard.
The stable-binding spelling is never preset-scheduled and is not enabled by
`--closed-world`; callers must name it explicitly at each trusted boundary.

Do not reopen direct DIE merely because a broader neighborhood has an independently owned shape difference.

## Reopening criteria

Reopen direct DIE if:

- a repeated import is removed, reordered, or retargeted;
- direct, command-adapter, or Node getter evidence changes;
- the unchanged path mutates bytes or metadata;
- the stable-binding variant is selected without both documented host guarantees;
- a preset or `--closed-world` begins selecting the stable-binding variant.
