---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0777-2026-06-20-heap-store-optimization-hso-b-direct-baseline.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../agent-todo.md
---

# `heap-store-optimization` generated O4z slot evidence

Question: can HSO-B record fresh early/late generated `-O4z` slot evidence against the current local Binaryen `version_130` oracle and current generated `cmd.wasm` artifact?

## Answer

Yes. On the current generated `_build/wasm/debug/build/cmd/cmd.wasm` input, Binaryen `version_130` still places top-level `heap-store-optimization` at the same early/late no-DWARF neighborhoods observed by the older audit:

- early slot `17`: `remove-unused-brs -> remove-unused-names -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute-propagate -> code-pushing`
- late slot `45`: `merge-blocks -> precompute-propagate -> optimize-instructions -> heap-store-optimization -> rse -> vacuum -> dae-optimizing`

Starshine direct `--heap-store-optimization` replay on both Binaryen-produced predecessor artifacts was exact-equal to Binaryen:

| Slot input | Canonical wasm equal | Normalized WAT equal | Starshine raw skip | Starshine pass ms | Binaryen pass ms | Whole-command note |
|---|---:|---:|---:|---:|---:|---|
| slot 17 predecessor after prefix through `optimize-instructions` | yes | yes | yes | `0.000` | `49.4339` | Starshine whole command `419.415ms`, Binaryen `518.710ms` |
| slot 45 predecessor after prefix through late `optimize-instructions` | yes | yes | yes | `0.000` | `31.8073` | Starshine whole command `345.569ms`, Binaryen `307.067ms` |

Agent classification: this is generated-artifact O4z regression evidence, not final HSO behavior closeout. Both saved HSO slots are raw-fast-skip exact matches: useful for preserving the current O4z artifact state and cheap no-candidate behavior, but they do not replace the required focused source-backed tests or final 100000-case direct compare. The late slot's whole-command Starshine run was slower than Binaryen despite raw pass skip; that is command/runtime overhead rather than HSO pass-local work and should stay under the broader wall-time budget unless a future HSO candidate artifact shows pass-local cost.

## Commands

Build and validate the generated wasm input:

```sh
moon build --target wasm src/cmd
wasm-tools validate --features all _build/wasm/debug/build/cmd/cmd.wasm
```

Observe the local Binaryen O4z path:

```sh
mkdir -p .tmp/hso-o4z-slot-evidence-20260620
wasm-opt _build/wasm/debug/build/cmd/cmd.wasm \
  -O4 --shrink-level 4 --all-features --debug \
  -o .tmp/hso-o4z-slot-evidence-20260620/binaryen-o4z.wasm \
  > .tmp/hso-o4z-slot-evidence-20260620/wasm-opt-debug.log 2>&1
wasm-tools validate --features all .tmp/hso-o4z-slot-evidence-20260620/binaryen-o4z.wasm
```

Materialize Binaryen predecessor artifacts for the early and late top-level slots:

```sh
wasm-opt _build/wasm/debug/build/cmd/cmd.wasm --all-features \
  --duplicate-function-elimination --remove-unused-module-elements \
  --memory-packing --once-reduction --global-refining \
  --remove-unused-module-elements --gsi --ssa-nomerge --flatten \
  --simplify-locals-notee-nostructure --local-cse --dce \
  --remove-unused-names --remove-unused-brs --remove-unused-names \
  --optimize-instructions \
  -o .tmp/hso-o4z-slot-evidence-20260620/prefix16-before-hso.wasm

wasm-opt _build/wasm/debug/build/cmd/cmd.wasm --all-features \
  --duplicate-function-elimination --remove-unused-module-elements \
  --memory-packing --once-reduction --global-refining \
  --remove-unused-module-elements --gsi --ssa-nomerge --flatten \
  --simplify-locals-notee-nostructure --local-cse --dce \
  --remove-unused-names --remove-unused-brs --remove-unused-names \
  --optimize-instructions --heap-store-optimization --pick-load-signs \
  --precompute-propagate --code-pushing --tuple-optimization \
  --simplify-locals-nostructure --vacuum --reorder-locals \
  --remove-unused-brs --heap2local --merge-locals --optimize-casts \
  --local-subtyping --coalesce-locals --local-cse --simplify-locals \
  --vacuum --reorder-locals --coalesce-locals --reorder-locals \
  --vacuum --code-folding --merge-blocks --remove-unused-brs \
  --remove-unused-names --merge-blocks --precompute-propagate \
  --optimize-instructions \
  -o .tmp/hso-o4z-slot-evidence-20260620/prefix44-before-hso.wasm

wasm-tools validate --features all .tmp/hso-o4z-slot-evidence-20260620/prefix16-before-hso.wasm
wasm-tools validate --features all .tmp/hso-o4z-slot-evidence-20260620/prefix44-before-hso.wasm
```

Compare Starshine and Binaryen HSO at those predecessor points:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260620/prefix16-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260620/slot17-hso-compare \
  --heap-store-optimization

bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260620/prefix44-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260620/slot45-hso-compare \
  --heap-store-optimization
```

Result artifacts:

- `.tmp/hso-o4z-slot-evidence-20260620/wasm-opt-debug.log`
- `.tmp/hso-o4z-slot-evidence-20260620/prefix16-before-hso.wasm`
- `.tmp/hso-o4z-slot-evidence-20260620/prefix44-before-hso.wasm`
- `.tmp/hso-o4z-slot-evidence-20260620/slot17-hso-compare/result.json`
- `.tmp/hso-o4z-slot-evidence-20260620/slot45-hso-compare/result.json`

## Follow-up

This evidence advances `[O4Z-AUDIT-HSO-B]` but does not close the full HSO audit. Remaining work still includes the source-backed HSO-C/D/E/F/G/H behavior families, final non-goal wording, performance/raw-fast-skip review beyond this generated no-candidate artifact, and final closeout with focused/full Moon validation, native `src/cmd` build, a 100000-case direct compare, and docs/backlog cleanup.
