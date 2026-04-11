# MoonBit `moon prove` Strategy For Starshine

Status: archived investigation with follow-on implementation updates through 2026-04-11.

## Scope

- Investigate the current MoonBit formal-verification workflow around `moon prove`.
- Map that workflow onto Starshine's package layout and current correctness risks.
- Recommend a staged rollout that adds real proofs without destabilizing the existing validator, codec, parser, fuzz, and pass workflows.

## Investigation Summary

- Local toolchain on 2026-04-10:
  - `moon 0.1.20260409 (a87440e 2026-04-09)`
  - `moonc v0.9.0+8a8d0e4df (2026-04-10)`
- The current official MoonBit docs describe `moon prove` as an experimental Why3-backed verification flow for `.mbt` and `.mbtp` packages.
- Proof enablement is package-local via `moon.pkg`:

```moonbit
options(
  "proof-enabled": true,
)
```

- The current `moon prove --help` surface is intentionally small:
  - `moon prove [PATH]`
  - optional `--why3-config <PATH>`
- The current `moonc prove --help` surface exposes the compiler-level debugging hooks:
  - `-emit-only`
  - `-whyml-output-path`
  - `-proof-report-output-path`
  - `-why3-loadpath`
  - `-dep-proof`
- A local dry run against this repo confirms package-local gating and file-path targeting:
  - `moon prove src/validate --dry-run`
  - `moon prove src/validate/match.mbt --dry-run`
  - both report: package `jtenner/starshine/validate` is not proof-enabled, so `moon prove` skips it
- The local workstation currently does not have the external prover stack installed:
  - `why3`: missing
  - `z3`: missing
  - `cvc5`: missing
  - `alt-ergo`: missing

## Current MoonBit Proof Model

### What The Official Docs Confirm

- Verified packages split responsibilities across:
  - `.mbt` for executable code plus contracts, local `proof_assert`, and loop annotations
  - `.mbtp` for predicates, abstract models, invariants, and lemmas
- The primary proof annotations are:
  - `proof_require`
  - `proof_ensure`
  - `proof_assert`
  - `proof_invariant`
  - `proof_yield`
  - `proof_reasoning`
  - `proof_decrease`
  - `proof_axiomatized`
  - `#proof_pure`
- Official setup requirements today are:
  - Why3, with pinned version `1.7.2` recommended
  - at least one external solver from `z3`, `cvc5`, or `alt-ergo`
- Official semantic constraints that matter for Starshine:
  - the proof model reasons over mathematical integers, not machine integers
  - formal verification remains experimental
  - functional and model-based proof styles are preferred
  - local mutation and in-place `FixedArray` updates are supported, but escaping `FixedArray` uses are currently not
- Official command behavior that matters for rollout:
  - `moon prove` at module root proves proof-enabled packages
  - targeted mode assumes dependencies instead of reproving them in the same command

### What The Compiler Help Adds

- `moonc prove` can emit generated WhyML and structured proof reports without invoking Why3:
  - this is the right debugging path when a proof failure is opaque
  - it should be treated as an advanced workflow, not the repo's first-line interface

### Community Findings Worth Treating As Working Hypotheses

The official docs are intentionally high level. The current [`moonbit-community/verified`](https://github.com/moonbit-community/verified) examples and notes add practical constraints that are not yet spelled out in the official docs:

- `#proof_pure` helpers currently appear unable to carry ordinary verification contracts.
- Recursive logic helpers in `.mbtp` can still fail on termination unless the shape is especially simple.
- `.mbtp` logic functions may not accept `where { ... }` contracts in the current release.
- Large mixed `&&` / `||` formulas appear brittle; named helper predicates are more robust.
- Some loop/proof patterns are syntax-sensitive enough that simple algorithm shape matters.

These are community observations, not official guarantees. They are still useful for Starshine because they push the rollout toward:

- named predicates instead of giant inline formulas
- small proof kernels
- minimal reliance on `#proof_pure`
- local iteration on one file or one package at a time

## Current Repo Fit

### High-Fit First Targets

| Surface | Fit | Why it fits | Good first proof goals |
| --- | --- | --- | --- |
| `src/validate/env.mbt` | High | Mostly structural lookup/update helpers over `Env`, `LabelStack`, and type indices; existing tests already pin expected behavior tightly. | `LabelStack::get` stack-from-top indexing; `Env::with_rectype` / `resolve_subtype` behavior for `RecIdx`; `resolve_heaptype_subtype` abstract-vs-indexed behavior. |
| `src/validate/match.mbt` | High | Safety-critical subtype and exact-match logic with structural recursion over Starshine's type model, not over bytes or packed machine words. | `descriptor_compatible` symmetry; small reflexivity lemmas for selected `Match::matches` shapes; nullability/exact-helper lemmas. |

### Medium-Fit Second Targets

| Surface | Fit | Why it fits | Main risk |
| --- | --- | --- | --- |
| `src/validate/typecheck.mbt` | Medium | Core validator stack discipline is high value, and the file mostly uses local mutation rather than escaping `FixedArray`. | The file is large (`9660` LOC) and mixes local helpers with the whole instruction surface, so whole-file proofing may be too coarse at first. |
| `src/diff/myers.mbt` | Medium-low | Moderate size and existing tests, with algorithmic invariants that are expressible in principle. | Lower correctness leverage than the validator, and a real diff-minimality proof is broader than the first MoonBit pilot should be. |

### Low-Fit Deferred Targets

| Surface | Fit | Why to defer |
| --- | --- | --- |
| `src/binary/encode.mbt` / `src/binary/decode.mbt` | Low for the first rollout | Byte-level encodings, LEB widths, and machine-int boundaries are exactly where the current mathematical-integer proof model is least trustworthy as a full replacement for runtime validation. |
| `src/bitset/bitset.mbt` | Low for the first rollout | Small file, but it depends on `UInt64`, masking, and bitwise operations, which are not where the current MoonBit proof model gives the clearest ROI. |
| `src/passes/*`, `src/cmd/*`, `src/fuzz/*` | Defer | Large, mutation-heavy, and already covered by differential fuzz or command-level tests; these are not good first proving surfaces for an experimental toolchain. |

### Shared Vocabulary Layer

- `src/lib/types.mbt` should primarily act as proof vocabulary for the validator proofs, not as the first proof target.
- The existing validator tests are already the best executable oracle for the first proof slices:
  - `src/validate/env_tests.mbt`
  - `src/validate/typecheck_negative_tests.mbt`
  - inline tests in `src/validate/typecheck.mbt`

## Phase 0: Bootstrap The Toolchain And Workflow

1. Install Why3 `1.7.2` and start with `z3` as the first solver.
2. Keep local setup simple first:
   - use the generated default Why3 config locally
   - reserve `moon prove --why3-config <PATH>` for CI or hermetic debugging
   - do not check in a machine-specific Why3 config on day one
3. Keep proof iteration targeted:
   - use `moon prove src/validate/env.mbt`
   - then `moon prove src/validate/match.mbt`
   - only after that graduate to `moon prove src/validate`
4. Treat `moonc prove -emit-only` plus explicit output paths as the debugging escape hatch when Why3 output needs inspection.
5. Keep `moon` commands serialized because this repo already treats `_build/.moon-lock` as a real constraint.

## Phase 1: Pilot In `src/validate/env.mbt`

Recommended repo shape:

- enable proofs in `src/validate/moon.pkg`
- add one logic file, likely `src/validate/env_proof.mbtp`
- keep executable helper code in the existing `.mbt` file unless proof noise becomes too high

Recommended first proof goals:

- `LabelStack::new` and `LabelStack::push` preserve length/head consistency
- `LabelStack::get` matches stack-from-top indexing
- `Env::with_rectype` exposes current-group `RecIdx` lookups
- `Env::resolve_heaptype_subtype` returns `None` for abstract heap types and resolves indexed/def types correctly

Why start here:

- these properties are already pinned by executable tests
- they are important for the rest of the validator
- they avoid the weakest current areas of the proof model

## Phase 2: Extend To `src/validate/match.mbt`

Recommended logic file:

- `src/validate/match_proof.mbtp`

Recommended first proof goals:

- `descriptor_compatible(r0, r1, env)` is commutative
- equal non-bottom value types match themselves in a well-formed environment
- exact-match helpers preserve obvious equal-shape cases before tackling deeper recursive equivalence

Important guardrail:

- do not paper over recursive-proof difficulty with a permanent `proof_axiomatized` contract in validator subtype logic

If the exact recursive helpers are too brittle in current MoonBit:

- keep the first slice on local algebraic lemmas
- add well-formedness predicates for type graphs before attempting larger recursive proofs

## Phase 3: Move Into The Typechecker Helper Layer

Do not start with full instruction-by-instruction proofs. Start with the local helper layer that the instruction cases depend on:

- `TcState::push1`
- `TcState::pop1`
- `TcState::pop_expect`
- `TcState::push_types`
- `TcState::pop_types`
- `validate_end_stack`
- `normalize_untyped_if_branch_exit`
- `normalize_typed_if_branch_exit`

Desired proof shape:

- stack-shape preservation lemmas
- unreachable-state polymorphism lemmas around `BotValType`
- branch-normalization lemmas that turn existing negative tests into named proof obligations

Contingency:

- if proving `src/validate/typecheck.mbt` as one file is too noisy or slow, extract the stack/merge helpers into a smaller sibling file or package before continuing

## Phase 4: Keep Other Assurance Layers Intact

Formal proofs should complement, not replace:

- `moon test`
- `bun validate`
- validator fuzzing in `src/fuzz`
- binary roundtrip and malformed input tests
- spec and differential coverage

This is not optional because the official proof model still assumes mathematical integers. Runtime overflow, byte-precise encoding behavior, malformed binary/text behavior, and performance regressions still need executable coverage.

## Repo Conventions To Adopt Once Proofs Start

- One proof slice per logic file:
  - `env_proof.mbtp`
  - `match_proof.mbtp`
  - `typecheck_stack_proof.mbtp` if the helper layer gets extracted
- Prefer named predicates with stable suffixes:
  - `*_wf`
  - `*_inv`
  - `*_post`
- Keep inline `proof_assert` local and tactical; keep reusable facts in `.mbtp`.
- Treat `#proof_pure` as a small shared-helper tool, not as the main proof abstraction story.
- Treat any `proof_axiomatized` item as temporary trusted surface that must be explicitly tracked in docs and backlog.

## Validation Plan

For each slice:

1. Keep or strengthen the existing executable tests first.
2. Add named predicates and lemmas in `.mbtp`.
3. Add only the minimum contracts needed in `.mbt`.
4. Require a targeted `moon prove <file>` run for the slice.
5. Promote to a package-level `moon prove src/validate` gate only after the targeted slice is stable.

CI order should stay incremental:

- first gate a single proof slice
- then gate the proof-enabled package
- only later consider root-level `moon prove`

## Performance Impact

- Phase 0 and Phase 1 should be cheap enough to run regularly because they are small and targeted.
- Package-wide proving of `src/validate` is the first likely inflection point for solver cost and ergonomics.
- The large binary codec and pass packages are unlikely to justify first-wave proof cost under the current experimental toolchain.

## Open Questions

- Does file-targeted `moon prove path/to/file.mbt` remain a stable public workflow, or is it only a thin CLI affordance over package-level proving? The current help text says file paths are accepted, while the official docs only explain package-targeted mode.

## 2026-04-10 Implementation Update

- The first landed proof slice lives in `src/validate_proof`, not directly in `src/validate`.
- `src/validate_proof/label_index.mbt` now proves a small helper that maps top-of-stack label depth to the underlying declaration-order storage index, and `src/validate/env.mbt` calls that helper for `Env::get_label_types`.
- As of 2026-04-11, the active `src/validate_proof` kernel proves `9` helper goals:
  - `label_stack_storage_index`
  - `latest_stack_index`
  - `group_relative_absolute_index`
  - `group_member_relative_index`
  - `defined_func_body_index`
  - `defined_func_absolute_index`
  - `defined_body_func_index`
  - `bounded_index`
  - `suffix_start_index`
- Those helpers now cover more than the original `env` pilot:
  - `LabelStack::get`
  - `Env::get_label_types`
  - `Env::resolve_subtype`
  - `Env::resolve_typeidx_subtype`
  - `typecheck.mbt` branch-on-null / branch-on-cast label-tail index recovery
  - `typecheck.mbt` stack-top recovery in `check_pop_types_from_top` / `validate_end_stack`
  - descriptor-metadata group indexing in `validate.mbt`
  - name-section function, type, table, memory, global, elem, data, tag, local, label, and field-name bounds checks
  - code-body diagnostic function-index mapping
  - declared-function bounds checks in the `ref.func` declaration pass
- The current descriptor-metadata base rule is now explicit: if the current rectype is already appended to `env`, recover its suffix start; otherwise treat the current group as a virtual suffix immediately after the existing type space.
- `LabelStack::copy` also forced a more precise durable rule for the `env` slice: the stack is persistent and branchable because copied stacks share `values` / `parents` backing storage, so proved reverse-index helpers can replace arithmetic but cannot replace the parent-chain traversal in `LabelStack::get`.
- `src/validate/env_tests.mbt` now carries an explicit divergent-copy regression so proof-kernel reuse cannot silently collapse logical stack lookup into raw backing-array indexing.
- The direct `moon prove src/validate/env.mbt` path is currently blocked even after narrowing the local proof surface, because the proof-enabled `src/validate` package lowers `jtenner/starshine/lib` into WhyML that Why3 rejects with `unbound type symbol 'name'`.
- Current keepable workflow:
  - `moon test src/validate_proof`
  - `moon prove src/validate_proof`
  - `moon test src/validate`
- This changes the practical boundary for Phase 1: use a sidecar proof kernel package first, then return to package-enabling `src/validate` once the dependency-lowering failure is understood or worked around.
- Will `src/validate` package-wide proving be practical without first extracting smaller proof kernels from `typecheck.mbt`?
- How much recursive well-formedness vocabulary must be added before `Match::matches` becomes pleasant to prove?
- If MoonBit later gains stronger machine-integer proof support, should `src/binary` or `src/bitset` become the next formal target?

## Sources

### Official

- MoonBit formal verification docs: <https://docs.moonbitlang.com/en/latest/language/verification.html>
- MoonBit docs source for verification examples: <https://raw.githubusercontent.com/moonbitlang/moonbit-docs/main/next/language/verification.md>
- MoonBit verification example package:
  - <https://raw.githubusercontent.com/moonbitlang/moonbit-docs/main/next/sources/verification/src/moon.pkg>
  - <https://raw.githubusercontent.com/moonbitlang/moonbit-docs/main/next/sources/verification/src/top.mbt>
  - <https://raw.githubusercontent.com/moonbitlang/moonbit-docs/main/next/sources/verification/src/top.mbtp>

### Local Tooling Evidence

- `moon prove --help`
- `moonc prove --help`
- `moon version --all`
- `moon prove src/validate --dry-run`
- `moon prove src/validate/match.mbt --dry-run`

### Community Supporting Context

- `moonbit-community/verified` overview: <https://github.com/moonbit-community/verified>
- `moonbit-community/verified` proof-system findings: <https://raw.githubusercontent.com/moonbit-community/verified/main/PROOF_SYSTEM_FINDINGS.md>

### Starshine Source And Test Surfaces

- [`../../../../src/validate/env.mbt`](../../../../src/validate/env.mbt)
- [`../../../../src/validate/match.mbt`](../../../../src/validate/match.mbt)
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
- [`../../../../src/validate/env_tests.mbt`](../../../../src/validate/env_tests.mbt)
- [`../../../../src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt)
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
- [`../../../../src/bitset/bitset.mbt`](../../../../src/bitset/bitset.mbt)
- [`../../../../src/diff/myers.mbt`](../../../../src/diff/myers.mbt)
