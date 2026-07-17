# 1569 - `flatten` public parity closeout

_Date:_ 2026-07-17

_Status:_ current behavior-parity and fuzz-signoff record

_Scope:_ Starshine's public Binaryen-compatible `flatten` pass, its HOT lowering bridge, compare normalization, GenValid coverage, validation failures found by wasm-smith, and current signoff evidence.

## Question

Does the public Starshine `flatten` implementation match Binaryen v130 semantics across generated control, local, reference, multivalue, and exceptional-flow families, and are any remaining compare differences proven cleanup representation rather than unresolved behavior gaps?

## Sources reviewed

- Binaryen v130 `src/passes/Flatten.cpp` at `.tmp/binaryen-v130/Flatten.cpp`
- `src/passes/flatten.mbt`
- `src/passes/flatten_test.mbt`
- `src/passes/flatten_wbtest.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/ir/hot_lower.mbt`
- `src/validate/gen_valid.mbt`
- `scripts/lib/pass-fuzz-compare-task.ts`
- `scripts/test/pass-fuzz-normalization-fixtures.ts`
- compare artifacts under `.tmp/pass-fuzz-flatten-*`

## Binaryen approach retained

Binaryen flattens in postorder. Rich child expressions become ordered preludes, value-carrying control writes through typed temporaries, carried branch values use target-local vectors, and function results become explicit local traffic plus `return`. Starshine follows that semantic organization in HOT rather than attempting byte-identical output.

The compare investigation rejected a generic "spill every value position" rewrite: red-first experiments caused broad structured-control regressions and were reverted. The retained implementation continues to use owner-specific block, if, loop, try, branch, table, tee, EH, and terminal-transfer routing, matching Binaryen's specialized approach.

## Discrepancy families discovered

Raw GenValid and random-profile comparisons exposed recurring output-shape families:

1. Binaryen local-copy and forwarding preludes.
2. Adjacent one-use scalar producer temporaries.
3. Rich reference producer temporaries.
4. Untargeted void block shells.
5. Local and label numbering differences.
6. Pure dropped constants and unreachable/control cleanup debris.

These are normalized only after structural fixtures prove the exact local-copy, producer, reference, shell, naming, and dead-pure-expression forms. The closeout compare command uses:

```text
--normalize drop-consts \
--normalize unreachable-control-debris \
--normalize local-cleanup-debris
```

The two wasm-smith cases that require `drop-consts` retain only pure constants before guaranteed `unreachable` in Binaryen. Starshine removes that dead pure work. Matched downstream `--vacuum --dce` is nonregressing: case 9332 is 71 Starshine bytes versus 72 Binaryen bytes, and case 9956 is 62 bytes on both sides. This is the measured downstream-cleanup reason to keep the shape difference.

## Validation failures found and fixed test-first

The first 10,000-case wasm-smith lane found two Starshine validation failures that the earlier comparable-case summary had hidden among command failures:

- case 9332: a declared `i32` function result followed a polymorphic unreachable `i64` block whose transformed tail was `f64`;
- case 9956: a declared `i64` function result followed a polymorphic unreachable tail whose transformed tail was `f32`.

Red-first focused tests reproduced function, block, if, and loop forms. A further red-first nullable-reference fixture reproduced `externref` dead-tail materialization into a `funcref` result.

The fix distinguishes a value that can flow to the declared result from a stack-polymorphic dead tail:

- equal and validator-proven subtype results still flow through the typed result local;
- incompatible dead tails become `drop` roots;
- the declared defaultable result uses its own uninitialized typed temporary, matching Binaryen's unreachable-path strategy;
- reference compatibility uses the validator subtype relation and the pass module context instead of treating every reference pair as compatible.

Both original wasm-smith cases now lower, encode, and pass `wasm-tools validate --features all`.

## Generator coverage

A dedicated `flatten-all` GenValid aggregate now samples:

- portable scalar and structured control;
- pass-fuzz stress;
- SSA no-merge shapes;
- local coalescing and copy-through shapes;
- local subtyping;
- GC struct/reference families;
- DAE call and convergence families.

The profile and aliases are covered in `src/validate/gen_valid_tests.mbt` and exposed through the generated `GenValidProfile` API snapshot.

## Current final fuzz matrix

All runs used the release native CLI built immediately before comparison:

```text
moon build --target native --release src/cmd
```

| Lane | Requested | Compared | Command failures | Validation failures | Mismatches |
| --- | ---: | ---: | ---: | ---: | ---: |
| default GenValid | 10,000 | 10,000 | 0 | 0 | 0 |
| `flatten-all` | 10,000 | 10,000 | 0 | 0 | 0 |
| random all profiles | 10,000 | 8,596 | 1,404 Binaryen command failures | 0 | 0 |
| wasm-smith | 10,000 | 6,719 | 3,281 Binaryen parse/validation failures | 0 | 0 |
| idempotence | 1,000 | 1,000 | 0 | 0 | 0 property failures |

The final artifact directories are:

- `.tmp/pass-fuzz-flatten-final2-default-10000`
- `.tmp/pass-fuzz-flatten-final2-all-10000`
- `.tmp/pass-fuzz-flatten-final2-random-10000`
- `.tmp/pass-fuzz-flatten-final2-wasm-smith-10000`
- `.tmp/pass-fuzz-flatten-final2-idempotence-1000`

The idempotence lane checked and matched all 1,000 cases. The random-profile failures are all `binaryen-command-failed`. The wasm-smith failures contain no Starshine failures: 2,967 generic Binaryen failures, 226 bad section sizes, 39 zero-sized rec groups, 48 table-index failures, and one invalid type index.

A prior default GenValid run also compared 100,000/100,000 cases with zero mismatches before the polymorphic-tail validation repair. The final current-binary 10,000-case matrix above is the normative closeout evidence.

## Focused and repository validation

Final current-tree validation:

- `src/passes/flatten_test.mbt`: 270/270 after the follow-up legacy-WAST scaffold regression
- `src/passes/flatten_wbtest.mbt`: 228/228 after the follow-up scaffold-detector lookalike boundary
- `src/validate/gen_valid_tests.mbt`: 149/149
- normalization fixture script: green
- `moon info`: green with existing warnings
- `moon fmt`: green
- full `moon test`: 9,299/9,299
- `bun validate full --profile ci --target wasm-gc`: green, including roundtrip, valid/invalid validation, binary-roundtrip, and command-harness CI suites

## Public/API consequences

- `flatten` is an active HOT pass and public CLI/registry entry rather than a removed placeholder.
- HOT lowering has a public `preserve_flat_ir_spills` option used by the flatten bridge.
- `GenValidProfile` publicly includes `FlattenAllProfile`.
- Generated `.mbti` changes are intentional and must remain synchronized.

## Remaining non-behavior work

This record closes the discovered behavior and validation discrepancy families under the documented normalization contract. Follow-up top-level scheduling and current performance qualification are recorded in [`1570-2026-07-17-flatten-preset-scheduling-and-performance.md`](./1570-2026-07-17-flatten-preset-scheduling-and-performance.md). The current representative remains outside the performance target; that is not evidence of a semantic gap.
