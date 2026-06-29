# RemoveUnusedBrs dedicated mismatch classification

Date: 2026-06-29

## Scope

Continuation of `[O4Z-AUDIT-RUB-Q]` after note `1389`. The previous validation blocker is still superseded for current source; this slice reruns the dedicated aggregate with a current binary path and classifies the representative output-shape mismatches.

## Current-binary dedicated 1000 probe

Command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass remove-unused-brs \
  --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-max100 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile remove-unused-brs-all \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --normalize local-cleanup-debris \
  --max-failures 100
```

Result:

- requested: `1000`
- compared before mismatch cap: `115`
- selected leaves: `remove-unused-brs-control=50`, `remove-unused-brs-switch=48`, `remove-unused-brs-cleanup=17`
- normalized matches: `0`
- cleanup-normalized matches: `0`
- mismatches: `115`
- Starshine validation failures: `0`
- generator/property/command failures: `0`
- cache: Binaryen `115` hits / `0` misses

This is not full `1000/1000` closeout evidence because the run intentionally used `--max-failures 100` and stopped early at the mismatch cap. It is enough to confirm the old all-validation-failure mode did not recur in a larger current-binary probe.

## Source-backed safety envelope for the sampled profile

The compared `remove-unused-brs-all` aggregate samples only the `control`, `switch`, and `cleanup` leaves. In `src/validate/gen_valid.mbt`, `gen_valid_remove_unused_brs_profile_config(...)` disables imports, tables, memories, tags, element segments, data segments, calls, indirect calls, and tail calls, while enabling branch-heavy typed-body generation. The current sample metadata confirms all 115 compared inputs have no calls, memory/table/global mutation, exceptions, or atomics. The mismatches therefore come from pure constants, locals/local.tee materialization, structured control, branches, `br_table`, and dead `unreachable` tails, not from hidden side effects.

The profile still sets `max_globals: 1`, but this 115-case sample reports no mutable-global effects in `inputEffectTrapFacts`. If future accepted drift relies on this envelope, rerun samples must keep checking the effect facts rather than assuming all future generated cases are side-effect-free.

## Representative reduction: constant `br_if` exit cleanup

Reduced input saved at `.tmp/rub-shape-reduce-brif.wat`:

```wat
(module
  (func (export "main")
    (block
      (i32.const 1)
      (br_if 0))))
```

Binaryen `--remove-unused-brs` keeps a structured trap shell:

```wat
(block $block
  (block
    (br $block))
  (unreachable))
```

Starshine's normalized output erases the empty observable body. The rewrite is semantic-preserving for this reduced input because the condition is a constant true value, the branch exits the immediately enclosing block, and there are no side effects or result values. It is a Starshine size win in raw output for the reduced case (`37` bytes vs Binaryen `43` bytes).

## Representative reduction: same-target `br_table` cleanup

Reduced input saved at `.tmp/rub-shape-reduce-control.wat`:

```wat
(module
  (func (export "main")
    (block (result i32)
      (i32.const 295)
      (i32.const 1)
      (br_table 0 0)
      (unreachable))
    drop))
```

Binaryen lowers the table to a branch but preserves an inner `block` plus dead `unreachable` fallthrough. Starshine lowers the same selector to `drop` plus `br` and removes the dead tail shell:

```wat
(drop
  (block $block (result i32)
    (drop
      (i32.const 1))
    (br $block
      (i32.const 295))))
```

This is semantic-preserving for the same reason: all table arms target the same block, the selector is pure and explicitly dropped, the payload is produced before the branch, and the post-branch `unreachable` is unreachable. The normalized Starshine shape is smaller than Binaryen by deleting debris Binaryen leaves behind.

## Size evidence over the 115 mismatch sample

Measured over `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-1000-max100/failures`:

| Group | Cases | Raw Starshine <= Binaryen | Normalized Starshine <= Binaryen | Raw byte delta | Normalized byte delta |
| --- | ---: | ---: | ---: | ---: | ---: |
| all | 115 | 44 | 115 | `+951` | `-12527` |
| control | 50 | 22 | 50 | `+355` | `-5217` |
| switch | 48 | 16 | 48 | `+447` | `-5072` |
| cleanup | 17 | 6 | 17 | `+149` | `-2238` |

Largest raw regressions remain small in the sampled set (`+73` bytes max), while every normalized artifact is smaller than its Binaryen oracle (`-78` to `-167` bytes per case). The raw growth appears tied to local/materialization and encoder-shape differences, while Binaryen-normalized canonical size consistently favors Starshine after the extra dead-shell cleanup.

## Agent classification

Current sampled mismatch family classification: **accepted Starshine-win candidate, not a true semantic mismatch and not a validation blocker**, under the exact side-effect-free profile envelope above.

Rationale:

1. Starshine and Binaryen outputs validate for the current sample; no Starshine validation failures remain.
2. The sample's effect facts exclude calls, memory/table/global mutation, exceptions, and atomics.
3. The inspected reductions are pure branch/control debris cleanups where Starshine deletes dead structured shells that Binaryen leaves after its own `remove-unused-brs` rewrite.
4. The previous runtime smoke in note `1389` checked `20/20` mismatches as all-equal (`16` equal results, `4` equal traps, `0` semantic mismatches).
5. Canonical/normalized size favors Starshine in `115/115` sampled mismatches, with a total normalized delta of `-12527` bytes.

This is still not enough to close `[O4Z-AUDIT-RUB-Q]`: full dedicated current-binary evidence must either finish at `1000` and then `10000`, or the project/user must explicitly accept a substitute that combines bounded mismatch cap runs, runtime samples, side-effect/effect-fact checks, reduced representatives, and size evidence.

## Next closeout path

Recommended next steps:

1. Run a current-binary dedicated lane with a larger mismatch cap or no cap only if runtime permits; otherwise propose an approved substitute made of:
   - the capped `1000` probe above for validation-failure absence until mismatch cap,
   - a `1000` lane with runtime execution at a smaller `--max-failures` if it can finish,
   - a deterministic sample-size script over failure dirs for raw/normalized size and effect facts,
   - the reduced `br_if` and `br_table` representatives above.
2. If the user accepts the substitute, document the accepted-drift decision in the pass fuzzing page/backlog and run the final `10000` dedicated lane with a practical mismatch cap to confirm zero validation failures across more current-binary cases.
3. If the user does not accept a substitute, the blocker is precise: the full `remove-unused-brs-all` dedicated profile does not normalize green and uncapped runtime evidence is too slow in the current harness, even though sampled mismatches are currently classified as side-effect-free Starshine-win cleanup.
