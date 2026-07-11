# Binaryen `ssa`: current-main and Starshine admission recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness and local-admission manifest for `docs/wiki/binaryen/passes/ssa/`

## Scope

This compact recheck corrects two stale kinds of claim in the full-`ssa` dossier:

1. whether current Binaryen still has the shared full-SSA / no-merge algorithm and schedules only the no-merge sibling in its default function pipeline; and
2. whether a current Starshine `ssa` request is merely documented, actively executable, or eligible for the repository's Binaryen compare-pass harness.

It is provenance, not the teaching destination. Use the maintained `ssa` pages for the algorithm, local scope, and future-port plan.

## Primary sources reread

### Binaryen current `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
- Registration and default function scheduler: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Direct lit surface: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/ssa.wast>

### Current Starshine evidence

- Active partial owner: `src/passes/ssa.mbt`
- Focused tests: `src/passes/ssa_test.mbt`
- Registry/preset classification: `src/passes/optimize.mbt`, `src/passes/registry_test.mbt`
- CLI request coverage: `src/cmd/cmd_wbtest.mbt`
- Compare-pass admission allowlist: `scripts/lib/pass-fuzz-compare-task.ts`

## Current-main result

The reviewed upstream contract remains the one the dossier teaches:

- `SSAify(bool allowMerges)` owns both public variants. `SSAify(true)` is `ssa`; `SSAify(false)` is `ssa-nomerge`.
- Both build `LocalGraph`, create fresh local indexes, retarget single-source reads, materialize legal default values, add parameter-entry prepends where required, and run narrow refinalization after refining reference defaults.
- Only full `ssa` handles a multi-source read: it allocates a merge local, wraps explicit incoming values in `local.tee`, prepends a parameter copy for an implicit parameter source, and relies on the fresh local's default for an ordinary defaultable-local source.
- `pass.cpp` still registers both public names, but its default function optimization path schedules only `ssa-nomerge` when `optimizeLevel >= 3 || shrinkLevel >= 1`, subject to DWARF gating.

This is a dated source reading, not a byte-for-byte current-main versus `version_130` comparison. Keep the older `version_129` / `version_130` manifests as the tagged-oracle provenance.

## Current Starshine reconciliation

Starshine's public status is **active partial**, not boundary-only and not full Binaryen parity:

- `ssa_full_descriptor()` registers `ssa` as a hot pass whose summary explicitly limits execution to non-merge local traffic.
- `ssa_full_run(...)` builds the local graph and returns unchanged whenever it finds a merge read. Otherwise it delegates to the non-merge runner after conservative exceptional/typed-loop/branch-heavy/nested-CFG gates.
- `ssa_test.mbt`, registry tests, and CLI adapter tests cover active direct requests for repeated parameter writes and default exact-reference reads, while a diamond merge fixture asserts the present fail-closed behavior.
- `optimize` and `shrink` continue to use `ssa-nomerge`, not full `ssa`.

## Compare-pass admission boundary

The current comparison harness does **not** include `--ssa` in `SUPPORTED_PASS_FLAGS`; it includes `--ssa-nomerge` but not its full sibling. Therefore a generic `bun fuzz compare-pass --pass ssa ...` command is not a parity run today: it is rejected before generation or either optimizer executes.

A future runnable full-`ssa` lane requires all four gates:

1. active local execution (already true for the limited non-merge subset),
2. an explicit canonical Binaryen alias/flag mapping,
3. harness allowlist admission, and
4. a `ssa`-owned generator profile plus merge-local fixtures once mutation exists.

## Supersession and limits

- This capture supersedes stale living-page wording that said Starshine did not expose full `ssa`, and stale catalog wording that called the dossier upstream-only/no-local-registry.
- It does **not** supersede the older tagged source manifests or claim current Binaryen has no unreviewed drift.
- It does **not** claim Starshine implements Binaryen full-`ssa` merge-local, incoming-tee, parameter-prepend, loop, branch, EH, or typed-control behavior.
