---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1113-2026-06-25-heap-store-optimization-post-refcast-safety-audit.md
  - ./1112-2026-06-25-heap-store-optimization-reorder-mask-fast-path.md
  - ./1111-2026-06-25-heap-store-optimization-post-refcast-performance.md
  - ./1110-2026-06-25-heap-store-optimization-post-exact-refcast-compare.md
  - ./1081-2026-06-25-heap-store-optimization-o4z-slot-rerun.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO post-safety closeout probe

## Question

After the `1112` reorder-mask fast path and `1113` post-refcast safety audit, what HSO-J closeout evidence can be advanced without pretending final closeout is complete?

## Commands and results

### Moon metadata

```sh
moon info
```

Result: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

### Direct GenValid compare after `1112` / `1113`

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-post-safety-audit-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

| Metric | Result |
|---|---:|
| Compared | `10000/10000` |
| Normalized matches | `10000` |
| Compare-normalized matches | `0` |
| Mismatches | `0` |
| Validation failures | `0` |
| Property failures | `0` |
| Generator failures | `0` |
| Command failures | `0` |
| Binaryen cache | `10000` hits / `0` misses |

This is the current post-`1112` regular 10000-case direct GenValid smoke. It does not replace the final required closeout matrix.

### O4z slot replay after `1112` / `1113`

Inputs copied from the current generated O4z HSO predecessor artifacts:

- `.tmp/hso-o4z-slot-evidence-20260625-post-safety-audit/prefix16-before-hso.wasm`
- `.tmp/hso-o4z-slot-evidence-20260625-post-safety-audit/prefix44-before-hso.wasm`

Both validated with:

```sh
wasm-tools validate --features all <input>
```

Slot 17 command:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260625-post-safety-audit/prefix16-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260625-post-safety-audit/slot17-hso-compare \
  --heap-store-optimization
```

Slot 45 command:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260625-post-safety-audit/prefix44-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260625-post-safety-audit/slot45-hso-compare \
  --heap-store-optimization
```

Results:

| Slot | Canonical wasm equal | Normalized WAT equal | Starshine raw skip | Starshine pass ms | Binaryen pass ms | Whole-command note |
|---:|---|---|---|---:|---:|---|
| 17 | yes | yes | yes | `0.000` | `54.048` | Starshine whole command faster (`417.616ms` vs `478.729ms`). |
| 45 | yes | yes | yes | `0.000` | `29.722` | Starshine whole command slower (`334.730ms` vs `289.170ms`); pass-local HSO is still raw-skipped, so this remains outside HSO proper / `[WALL]001`. |

## Interpretation

This advances HSO-J but does not close it:

- The current post-safety direct 10000-case GenValid lane is normalized-green with no failures.
- The current generated O4z slot 17/45 predecessor replay remains exact/canonical and normalized-WAT equal, with Starshine raw-fast-skipping HSO at `0.000ms` pass-local time.
- Slot 45 still has whole-command overhead outside HSO proper.
- HSO-I remains unresolved because `1111`/`1112` still miss the allocation-heavy `<=2x Binaryen` target.

Final HSO-J still needs the agreed closeout decision: either run the full final matrix and validation after HSO-I is resolved/dispositioned, or explicitly document why final closeout is deferred.
