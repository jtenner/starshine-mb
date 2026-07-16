---
kind: research
status: active
created: 2026-07-16
updated: 2026-07-16
sources:
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# DAEO unbounded convergence and batching checkpoint

## Question

Can Starshine remove the historical eight-rewrite convergence cap, preserve plain DAE separation, and complete direct Binaryen v130 `dae-optimizing` signoff on the current stripped wasm-gc artifact?

## Source-backed implementation retained

- Removed the productive core rewrite cap. The core now advances through complete forward waves and rebuilds call-boundary facts only between waves.
- Added an optimizing-only, large-module unread-parameter batch. It collects owned non-recursive direct boundaries, rewrites all verified callers transactionally, rewrites callee signatures/bodies, and reuses equivalent simple function types.
- Added an optimizing-only, large-module dropped-result batch. It includes mixed external/self-recursive boundaries when every active direct call is dropped, rewrites callers and callees together, and reuses equivalent resultless signatures.
- Added an optimizing-only, large-module direct GC refinement batch for `struct.new_default` argument evidence and single-result GC evidence.
- Preserved plain `dae` separation: the batches run only for optimizing DAEO, while plain DAE uses the shared convergent core without the optimizing-only batches or nested cleanup.
- Preserved forwarding-cycle ownership by leaving large mutual parameter cycles to the existing SCC/component transactions.
- Replaced recursive forwarded-constant analysis of every parameter with an exact active-parameter mask. Recursive forwarding now requests only the parameter slot being resolved.
- Replaced the old callee-index-sized self-call counting allocation with a targeted active direct-call traversal.
- Added a selected Func-236 fallback for the post-convergence constant/local carrier shape exposed after all four parameters are removed.

## Tests and generated evidence

- `moon info`: passed with pre-existing warnings.
- `moon fmt`: passed; `moon.mod` was restored to the repository's canonical spelling afterward.
- Focused DAEO suite: `331/331` passed.
- Full Moon suite: `8875/8875` passed.
- Dedicated GenValid, Binaryen v130, explicit native binary, seed `0x5eed`, DAE normalizers: `10000/10000` normalized, zero mismatches or failures.
- Regular GenValid, Binaryen v130, explicit native binary, seed `0x5eed`, DAE normalizers: `10000/10000` normalized, zero mismatches or failures.
- Public `optimize`, `shrink`, and `--optimize -O4z` each execute DAEO exactly once immediately before `inlining-optimizing`; all three dedicated-profile outputs validate and are `38` bytes.

Artifacts:

- `.tmp/pass-fuzz-daeo-final-dedicated-10000-20260716`
- `.tmp/pass-fuzz-daeo-final-regular-10000-20260716`
- `.tmp/daeo-final-schedule-20260716`

## Direct artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Starshine output:

- raw: `3212867` bytes;
- Binaryen-v130 no-pass canonical roundtrip: `3275059` bytes;
- validates with `wasm-tools --features all`;
- direct wall time: about `29.4s` untraced and `30.0s` traced.

Binaryen v130 `--all-features --dae-optimizing`:

- raw: `3177421` bytes;
- canonical: `3262456` bytes;
- wall time: about `1.9s` on the same host.

Section attribution after canonical roundtrip:

- Starshine type section: `77039` bytes / `7214` types;
- Binaryen type section: `78167` bytes / `7288` types;
- Starshine code section: `2985671` bytes;
- Binaryen code section: `2971947` bytes.

The net canonical gap is therefore `+12603` bytes, primarily a `+13724` code-section gap partly offset by a `-1128` type-section win. The result regresses the prior note-1627 endpoint (`+9737` canonical and controlled `16.6–16.8s`) even though the pass now converges and no longer times out.

## Classification and decision

This checkpoint is **not a DAEO signoff**.

- Validation and the two fresh 10000-case generated lanes are green.
- Registry, plain-DAE separation, and public optimize/shrink/O4z placement are green.
- The direct artifact is a size-losing parity gap and exceeds the established `17076.04ms` ceiling.
- The remaining code-section delta is not accepted as safe merely because both outputs validate or Starshine's type section is smaller.
- The self-compare pretty-function diagnostic still encounters the previously observed Starshine diagnostic stack-underflow on Binaryen-canonical input; `wasm-tools validate` remains green, so this is a diagnostic discrepancy, not semantic proof.

The audit remains active. Next work must reduce the code-section gap and restore performance below the established ceiling without reinstating the eight-rewrite cap, weakening cycle safety, or merging optimizing-only behavior into plain DAE.
