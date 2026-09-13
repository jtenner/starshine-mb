---
kind: workflow
status: working
last_reviewed: 2026-09-13
sources:
  - ../../../ir2/architecture-rules.md
  - ../../../../../src/validate/gen_valid_constraint.mbt
  - ../../../../../src/validate/gen_valid_constraint_wbtest.mbt
  - ../../../../../src/passes/constraint_analysis_wbtest.mbt
  - ../../../../../src/passes/constraint_domain_wbtest.mbt
  - ../../../tooling/pass-fuzz-compare.md
  - ../../version-132-upgrade.md
---

# Constraint analysis GenValid coverage

Use the **`constraint-analysis`** aggregate. Twelve equally weighted families
cover integer predicates, joins, bounded loops, tees, wrapping increments, i64
operand width, Boolean AND/OR and double negation, references, unreachable
predecessors, relations between locals, effects, and the floating-point boundary.
Constants include zero, sign boundaries, all-ones patterns and values above i32
width. The default suite uses four fixed seeds per member; broad campaigns run
outside `moon test`.

```sh
moon build --target native --release src/cmd
moon build --target native --release src/fuzz
bun fuzz compare-pass --count 10000 --min-compared 10000 --seed 0x5eed   --pass constraint-analysis --gen-valid-profile constraint-analysis   --require-binaryen-version 132   --wasm-opt-bin .tmp/binaryen-version_132/bin/wasm-opt   --starshine-bin _build/native/release/build/cmd/cmd.exe   --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe   --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20   --out-dir .tmp/constraint-v132
```

For complete mismatch intake, `--max-failures 10001` permits all requested cases
to run. It does not classify differences or waive validation failures. Add
`--semantic-oracle node-v2` for independent execution of the original and both
optimized modules. Record blocked runtime capabilities separately.

The integer domain has bounded exhaustive small-width checks for relation
swapping/negation and modular transfer, plus i64 boundary fixtures. Regressions
also exercise stack-held local values, effectful tees and dropped reference
branches. Floating-point constraints stay disabled: post-tag NaN and signed-zero
fixes are correctness requirements, not an invitation to reproduce unsafe v132
rewrites. Keep the pass opt-in until fixed-corpus size and cost measurements
justify preset changes.

See [the upgrade evidence](../../version-132-upgrade.md) for executed campaigns
and outstanding differences. The profile's existence is not a signoff claim.

The effects member includes a handler that bypasses a later assignment and a
result-producing call held across conditional clobbers. These guard control-flow
fact lifetime and evaluation order independently of whether the rewritten module
validates. Compiler-scale tuple/control tests also require merging reachability
across repeated CFG occurrences of one physical region.

The effects member also varies a copied block result containing a one-arm `if`.
Its absent else is an internal sentinel, not a value node; relevance discovery
must ignore it while retaining the conditional global write. This reduced case
guards the native compiler abort found after compacting local fact storage.

The loop member now varies ordinary local counters, tuple-producing nested
control, and stack-carried loop parameters. The latter guards the compiler
regression where treating the initial zero as every iteration's value removed
the exit condition. Backedges enter the body; initial argument evaluation stays
in the preheader. Loop parameters participate in the same bounded join/widening
solver as local values.

### Aggregate seed audit

The `renew10` 10,000-case result is valid for its generated inputs, but does not
cover every named family's variants. The shared aggregate selector correlated
its low bits with `case_seed`: logical cases selected OR only, effects selected
copied-control only, and loops missed parameter-backedge forms. The selector now avalanches the selection bits independently of body selection,
while retaining exact case seeds for singleton replay. Bounded tests assert
variant coverage, including parameter loops and throwing-stack effects. The
renew18 aggregate below uses the corrected generator.

The effects member now includes an older throwing call followed by a pending
local read and a conflicting write. Its handler observes the pre-write local
when the call throws. Both normal and exceptional executions matter; signature
elimination also has an unused callee parameter to remove. The shared HOT test
checks source access ordinals and both capture modes.

### Renew18 aggregate — September 11

Fresh CLI `c447149a…` and GenValid `9cd6bbe2…` complete 10,000 cases against
Binaryen 132. All 10,000 original-primary runtime comparisons, deterministic
reruns and codec checks pass, with zero validation/generator/command/property
failures. There are 4,254 canonical matches, 5,578 smaller outputs and 168 larger
outputs. The larger families are 107 throwing-stack effect cases (+1 byte) and
61 parameter-loop cases (+2 bytes after oracle canonicalization). The 107
capture cases exposed redundant stack capture locals and received a focused
regression and balanced-stack cleanup. The renewed capture results below
supersede this checkpoint.

The 61 typed-loop cases are a measured Starshine win: Starshine preserves the
76-byte input while Binaryen emits 88 bytes, with an additional local and
backedge copies. All 61 pairs become byte-identical after either Binaryen
`--vacuum` or `-Oz`. The two-byte canonical difference comes from the oracle's
no-pass normalization of loop parameters, not an extra Starshine wrapper.
Evidence: `.tmp/binaryen132-renew18-ca-quality/loop-family/result.json` and
`loop-cleanup.json`; aggregate runtime comparisons match the original.
Smaller output is not automatically semantic proof: inspect each transform
family alongside the runtime evidence. Exact counters and tool hashes are in
the [validation ledger](../../../raw/binaryen/2026-09-10-v132-validation.json);
artifacts are `.tmp/binaryen132-renew18-campaigns/constraint-analysis`.

### September 11 renewed capture evidence

Native `7738a54f…` completes the 10,000-case aggregate with 10,000 independent
Bun/JavaScriptCore observation matches, deterministic outputs and codec
roundtrips, and no validity, generator, command or property failures. All 107
previous capture-related canonical size losses are now smaller than Binaryen.
The 61 remaining canonical `+2` loop cases retain the measured raw-size and
local-operation win described above. Reports record the actual runtime host and
a 10-second worker budget; see the [upgrade ledger](../../../raw/binaryen/2026-09-10-v132-validation.json).

### September 13 parity cleanup

The [parity follow-up](../../../ir2/architecture-rules.md#september-13-parity-follow-up)
removes redundant terminating-loop closure, function-exit local roundtrips,
and zero-parameter branch-free block shells. Preserved-byte regressions cover
single, stacked, and touched dispatch; explicit guards retain branch targets,
block parameters, and nested observable local writes. This supersedes the
61-case canonical loop-size exception above: the compact parameter loops now
also have smaller canonical output. The follow-up ledger records the fresh
10,000-case aggregate, exact binaries, runtime evidence, and size judgments.
