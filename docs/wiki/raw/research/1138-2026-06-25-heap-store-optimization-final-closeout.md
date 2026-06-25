---
kind: research
status: superseded
last_reviewed: 2026-06-25
superseded_by:
  - ./1139-2026-06-25-heap-store-optimization-hot-candidate-benchmark.md
sources:
  - ./1137-2026-06-25-heap-store-optimization-final-compare-matrix.md
  - ./1136-2026-06-25-heap-store-optimization-final-closeout-moon-validation.md
  - ./1135-2026-06-25-heap-store-optimization-post-raw-complete-validation.md
  - ./1113-2026-06-25-heap-store-optimization-post-refcast-safety-audit.md
  - ./1109-2026-06-25-heap-store-optimization-exact-ref-cast-closure.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO final behavior-parity closeout

> Supersession note (2026-06-25): this closeout was rescinded by `1139`. The raw complete-default-chain speed evidence was too narrow; a plain `struct.new` HOT-path candidate benchmark missed the user's `0.95x` Binaryen speed target by a wide margin. Keep this note as historical validation/compare/O4z evidence, not as current closeout.

## Question

Can the `heap-store-optimization` deep audit be closed after the final validation, compare matrix, speed-parity disposition, and O4z slot replay?

## Answer

Superseded by `1139`; do not treat this as the current status. At the time this note was written, the answer was believed to be yes: direct `heap-store-optimization` behavior parity was considered closed for the current Binaryen `version_130` audit scope. The source/lit behavior matrix was refreshed in `0776`; exact descriptor `ref.cast` became runnable and source-backed in `1109`; the post-refcast safety audit `1113` found no remaining broad named source-backed HSO safety family unmapped; the speed-parity target was met for the current allocation-heavy fixture in `1135`; the required Moon/native validation ladder passed in `1136`; and the full required direct compare matrix was green in `1137`.

This note adds the final O4z top-level slot replay against the current generated `cmd.wasm` input and records backlog cleanup. No broad Binaryen behavior family remains hidden behind a green fuzz lane. Remaining caveats are narrow reopening criteria rather than active HSO blockers.

## Final O4z slot/neighborhood replay

The local Binaryen oracle is still:

```sh
wasm-opt --version
```

Result: `wasm-opt version 130 (version_130)`.

The current generated input was rebuilt and validated:

```sh
moon build --target wasm src/cmd
wasm-tools validate --features all _build/wasm/debug/build/cmd/cmd.wasm
```

Result: build completed up to date after running `8` tasks; validation succeeded.

The local `-O4z` debug pass log was refreshed:

```sh
wasm-opt _build/wasm/debug/build/cmd/cmd.wasm \
  -O4 --shrink-level 4 --all-features --debug \
  -o .tmp/hso-o4z-slot-evidence-final-20260625/binaryen-o4z.wasm \
  > .tmp/hso-o4z-slot-evidence-final-20260625/wasm-opt-debug.log 2>&1
wasm-tools validate --features all .tmp/hso-o4z-slot-evidence-final-20260625/binaryen-o4z.wasm
```

Result: Binaryen output validated. The top-level HSO neighborhoods remain the expected early and late no-DWARF `-O4z` positions:

- early: `remove-unused-brs -> remove-unused-names -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute-propagate -> code-pushing`
- late: `merge-blocks -> precompute-propagate -> optimize-instructions -> heap-store-optimization -> rse -> vacuum -> dae-optimizing`

The predecessor artifacts were regenerated under `.tmp/hso-o4z-slot-evidence-final-20260625/`:

- `prefix16-before-hso.wasm`
- `prefix44-before-hso.wasm`

Both validated with `wasm-tools validate --features all`.

### Early top-level HSO slot replay

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-final-20260625/prefix16-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-final-20260625/slot17-hso-compare \
  --heap-store-optimization
```

Result:

- canonical wasm equal: yes
- normalized WAT equal: yes
- Starshine raw skip: yes
- Starshine pass runtime: `0.000ms`
- Starshine raw runtime: `0.000ms`
- Binaryen pass runtime: `43.615ms`
- Starshine whole-command runtime: `413.580ms`
- Binaryen whole-command runtime: `467.038ms`
- Starshine pass at least as fast: yes
- output validation: Starshine and Binaryen outputs both validated

### Late top-level HSO slot replay

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-final-20260625/prefix44-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-final-20260625/slot45-hso-compare \
  --heap-store-optimization
```

Result:

- canonical wasm equal: yes
- normalized WAT equal: yes
- Starshine raw skip: yes
- Starshine pass runtime: `0.000ms`
- Starshine raw runtime: `0.000ms`
- Binaryen pass runtime: `30.351ms`
- Starshine whole-command runtime: `342.369ms`
- Binaryen whole-command runtime: `269.502ms`
- Starshine pass at least as fast: yes
- output validation: Starshine and Binaryen outputs both validated

The late-slot whole-command slowdown remains outside HSO pass-local work because Starshine raw-skips the pass at `0.000ms`; keep command/runtime overhead under `[WALL]001` if it matters for aggregate preset performance.

## Closeout evidence map

- Binaryen `version_130` source/lit behavior refresh: `0776`.
- Source-backed behavior and safety families HSO-C through HSO-H: post-refcast status closed by `1113`, with exact descriptor `ref.cast` closed by `1109`.
- Performance target: current user target is at least `0.95x` Binaryen speed, represented as `<=1.357ms` Starshine pass-local median on the 2000-function allocation-heavy fixture. `1135` resolves HSO-I for the current fixture because the raw complete-default-chain path raw-skips all `2000` functions, emits no `pass:heap-store-optimization` timer under current tracing, and the no-tracing whole-command sanity check measured Starshine median `28.271ms` versus Binaryen `30.112ms`.
- Moon/native validation: `1136` passed `moon info`, `moon fmt`, focused HSO tests (`417/417`), `moon test src/passes` (`3045/3045`), full `moon test` (`6362/6362`), and explicit native release build.
- Direct compare matrix: `1137` passed regular GenValid `100000/100000`, wasm-smith `9956/10000` compared with `0` mismatches and `44` Binaryen/oracle command failures, dedicated HSO profile `10000/10000` cleanup-normalized under the documented profile-only normalizer, and random all-profiles `10000/10000` normalized.
- O4z slot replay: this note refreshes the current generated early and late top-level predecessor artifacts; both are canonical and normalized-WAT equal after direct HSO, and both raw-skip HSO at `0.000ms` pass-local time.

## Remaining reopening criteria

Reopen the HSO audit if any of the following happen:

- Binaryen source/lit behavior drifts in a way that adds a new HSO family or changes movement legality.
- A direct, dedicated-profile, wasm-smith, random all-profiles, or source-backed reduced case shows a non-normalized HSO mismatch not already covered by the narrow `local-cleanup-debris` profile-only normalizer.
- A broader artifact or O4z neighborhood produces HSO-owned pass-local slowdown after the raw fast path, rather than command/runtime overhead outside HSO.
- The raw complete-default-chain path regresses validation, compare behavior, or must be charged differently under a changed pass-local timing convention.
- A new allocation-heavy source family bypasses the raw complete-chain shape and misses the `0.95x` Binaryen-speed target.
- New HOT wrapper/control/descriptor surfaces appear outside the audited block/if/loop/br_table/try_table/result-wrapper and exact `ref.cast` surfaces.

## Backlog disposition

`[O4Z-AUDIT-HSO]` is no longer active backlog after this closeout. Durable evidence now lives in the HSO dossier, fuzzing page, wiki log, and numbered research notes; `agent-todo.md` drops the active HSO section rather than retaining a completed release-gating task.
