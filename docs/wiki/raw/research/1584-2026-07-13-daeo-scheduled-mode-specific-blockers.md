# DAEO scheduled mode-specific blocker attribution

Date: 2026-07-13

## Scope

This investigation refines note `1582`'s large-artifact scheduling blocker. It inspects the retained public `--optimize` trace, directly replays `vacuum` on the same input, and separately probes public `-O4z`. No behavior or schedule changed.

Fresh explicit native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812`.

Input:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- `3204405` bytes.

## Public `--optimize`

The retained `7200s` trace from note `1582` is more precise than the earlier summary implied.

Before the stall, Starshine completed the active `remove-unused-names` candidate lane through absolute Func `10636` and emitted:

```text
pass[remove-unused-names]:skip-raw reason=no-remove-unused-names-candidates count=7869
```

It then entered `vacuum`. The final trace region contains repeated:

```text
pass[vacuum]:skip-raw reason=raw-vacuum-guarded-hazard
```

and never reaches `pass[dae-optimizing]:start`. The earlier no-trace `--optimize` attempt also timed out after `3600s`.

A fresh direct `--vacuum` replay on the original stripped artifact timed out after `120s` without output:

```sh
_build/native/release/build/cmd/cmd.exe --vacuum \
  --out .tmp/daeo-iteration-20260713/direct-vacuum-input.wasm \
  .tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

This confirms that the public optimize blocker is independently reproducible in `vacuum`; it is not caused by DAEO, `remove-unused-names` trace volume, or the preset wrapper alone.

## Public `-O4z`

Note `1582` did not rerun the large `-O4z` mode because it assumed the optimize/shrink pre-DAEO blocker was shared. That assumption is now disproved.

The raw vacuum adapter explicitly returns `o4z-vacuum-noop` when optimize level is at least `4` and shrink level is at least `1`, so the public `-O4z` path does not own the same vacuum scan.

Fresh evidence:

- no-trace `-O4z` timed out after `600s` without output;
- traced `-O4z` timed out after `300s`;
- trace path `.tmp/daeo-iteration-20260713/scheduled-o4z/traced.trace`;
- trace size `3844` lines / `563888` bytes;
- it never reached `pass[dae-optimizing]:start`;
- it was still in the early `ssa-nomerge` slot, with the last completed raw timer at absolute Func `1862`.

The final lines are ordinary guarded/no-op SSA classifications such as `structured-local-writes`, `no-local-writes`, `straight-line-local-writes-localgraph-plan`, and `structured-already-ssa-tee-noop`. There is no Starshine validation failure or DAEO execution.

Agent judgment: public `-O4z` has a distinct early `ssa-nomerge` whole-command blocker on this artifact. The prior claim that optimize, shrink, and O4z necessarily share one pre-DAEO vacuum neighborhood is superseded.

## Current scheduled status

- Dedicated-profile `--optimize`, `--shrink`, and `-O4z` exact-once order/output evidence from note `1582` remains valid.
- Large public `--optimize` remains blocked in direct/reproducible `vacuum` work before DAEO.
- Large public `-O4z` remains blocked earlier in `ssa-nomerge`, not vacuum.
- Large public `--shrink` has not been rerun in this slice and must not be assigned to either owner without evidence.
- No large scheduled mode currently reaches DAEO, so scheduled current-artifact DAEO output and performance remain unavailable.

These are `[WALL]001` preset/whole-command owners. They do not weaken the direct DAEO pass-local evidence, but final scheduled current-artifact signoff remains blocked until each relevant public mode has a bounded prefix or performance repair that reaches the locked DAEO slot.
