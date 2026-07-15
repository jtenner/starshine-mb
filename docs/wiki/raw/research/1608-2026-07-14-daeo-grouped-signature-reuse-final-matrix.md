# DAEO grouped-signature reuse and ranked direct matrix

Date: 2026-07-14

## Scope

This iteration followed note `1607` in two bounded directions:

1. rank the remaining direct Starshine/Binaryen canonical difference by section and function-body contribution;
2. attribute and close the `+32`-byte raw pre-canonical regression without weakening effect preservation or changing the forwarding-component transaction.

The raw regression was not caused by the localized call operands themselves. The five rewritten bodies were already `33` raw bytes smaller than note `1606`; the enclosing module grew because DAE appended replacement function types for signatures whose old types lived inside recursive groups. The type payload grew by `65` bytes, producing the net `+32` module regression.

The retained implementation now rewrites a uniquely owned, unreferenced plain function subtype in place even when that subtype is a member of a recursive group. It remains fail-closed for shared or imported users, non-function subtypes, subtype metadata, recursive/type-section references, typed table/global/tag/element/local/body references, typed controls and selects, indirect/ref calls, GC instructions, and embedded `DefType` heap types. The existing append/reuse path remains the fallback.

This is type-section storage for an already-approved DAE signature change. It does not schedule optimizing cleanup in plain `dead-argument-elimination`, alter forwarding-component ownership, or change public preset order.

## Source contract

Binaryen v130 records every changed function in `worthOptimizing` and, for `dae-optimizing`, invokes `OptUtils::optimizeAfterInlining(worthOptimizing, ...)` after parameter/result localization and removal (`.tmp/DeadArgumentElimination-v130.cpp`, lines around `533-534`). `optimizeAfterInlining` runs `precompute-propagate` plus the default function optimization passes through a filtered runner (`.tmp/slns-v130-source/src/passes/opt-utils.h`).

That source contract matters for the ranked next owner below: the leading canonical body differences are changed DAE functions whose Starshine nested replay is currently skipped as one `touched=46` set. The grouped-signature storage change in this note is narrower: it only avoids leaving a dead replacement type encoding when exact reference evidence proves the existing grouped subtype has one function owner and no other use.

## Red-first coverage

`src/passes/dae_optimizing_test.mbt` adds two public-pipeline cases:

- an unreferenced grouped function type with one live non-constant parameter and one dead parameter must keep its existing flattened type index and type-section entry count after DAEO;
- the same grouped function type referenced by a typed table must remain immutable, use an appended replacement signature, and validate.

The positive test initially failed because the rewritten function moved from `Type 1` to an appended type. The two-caller fixture keeps the retained parameter non-constant so the test isolates signature storage rather than exact-literal elimination.

## Explicit native binary

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 052744e643849edf18f8987497d04922e41d972ba697789fa97250d25f3684fd
```

All authoritative compare lanes use Binaryen v130 through `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`, `--jobs auto`, the explicit native binary, and:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Direct artifact

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Retained output:

```text
.tmp/daeo-grouped-type-reuse-20260714/starshine-direct-final.wasm
SHA-256 c3dc4d99798b2224a9d45d10849200aa620953a8d232d6a97ba5768b538a69f4
```

A repeat invocation is byte-identical. The output validates under `wasm-tools validate --features all`.

| dimension | note 1606 | note 1607 | grouped-signature final | Binaryen v130 | final delta vs Binaryen |
|---|---:|---:|---:|---:|---:|
| raw wasm | `3197391` | `3197423` | `3197221` | `3177421` | `+19800` |
| canonical wasm | `3274829` | `3274791` | `3274791` | `3262456` | `+12335` |
| DAEO pass-local | `14299.444ms` | `14405.477ms` | `13003.761ms` | `8538.02ms` | `1.52x` |

The final raw type payload is `75391`, down from note `1607`'s `75593` (`-202`). The code payload is unchanged at `2909530`; canonical output is unchanged at `3274791`. Relative to note `1606`, the retained endpoint is now `170` raw bytes smaller and `38` canonical bytes smaller.

Agent judgment:

- the note-1607 `+32` raw residue is closed;
- in-place grouped signature reuse is a measured, source-backed Starshine representation win: `-202` raw bytes with identical canonical output, validation, semantics, scheduling, and no pass-local regression;
- the win is not inferred merely from validation or smaller output. It follows an exact ownership/reference proof and keeps the old type immutable whenever any typed reference remains;
- the direct canonical gap remains open at `+12335`.

## Ranked current canonical difference

Canonical section payloads:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75307` | `78167` | `-2860` |
| function | `25327` | `25369` | `-42` |
| code | `2987184` | `2971947` | `+15237` |
| net module | `3274791` | `3262456` | `+12335` |

The code-section loss is larger than the net module loss; Starshine's smaller type/function sections offset `2902` bytes.

Largest positive canonical function-body deltas by defined function index:

| rank | defined func | Starshine body | Binaryen body | delta |
|---:|---:|---:|---:|---:|
| 1 | `7008` | `6096` | `4332` | `+1764` |
| 2 | `8429` | `27190` | `25742` | `+1448` |
| 3 | `7007` | `5327` | `3884` | `+1443` |
| 4 | `41` | `6703` | `5417` | `+1286` |
| 5 | `9347` | `16685` | `15405` | `+1280` |
| 6 | `8187` | `2217` | `961` | `+1256` |
| 7 | `7556` | `6158` | `5025` | `+1133` |
| 8 | `6377` | `4185` | `3153` | `+1032` |
| 9 | `8185` | `3413` | `2429` | `+984` |
| 10 | `7919` | `3085` | `2101` | `+984` |
| 11 | `1247` | `4190` | `3268` | `+922` |
| 12 | `7943` | `1347` | `438` | `+909` |
| 13 | `5648` | `3431` | `2615` | `+816` |
| 14 | `9460` | `4283` | `3484` | `+799` |
| 15 | `5323` | `4265` | `3558` | `+707` |

The first remaining DAE-owned cleanup owner is therefore the post-signature body replay for defined Funcs `7008` and `7007`, not another forwarding-component parameter proof. Their named parameter component is closed, but Binaryen's retained bodies are much more compact after `optimizeAfterInlining`; Starshine records `nested-cleanup touched=46` and skips the whole replay as `large-touched-set`. The next slice should reduce this owner with a post-component, function-filtered cleanup proof. It must preserve the existing oversized/nondefaultable-local correctness boundaries and must not enable blanket cleanup across all 46 touched functions.

The other ranked bodies (`8429`, `41`, `9347`, and later owners) remain open parity gaps unless a separate measured Starshine win is established.

## Required direct matrix

### Dedicated DAEO profile

```text
.tmp/pass-fuzz-daeo-grouped-type-reuse-v130-dedicated-10000-20260714
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-grouped-type-reuse-v130-regular-100000-20260714
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-grouped-type-reuse-v130-wasm-smith-10000-20260714
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, unchanged Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, and `binaryen-bad-section-size=3`;
- wasm-smith cache `10000/0`, Binaryen success cache `9956/0`, Binaryen failure cache `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-grouped-type-reuse-v130-random-all-10000-20260714
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache hits/misses `10000/0`.

The failure-directory set is identical to note `1607`. Of the `2936` saved semantic `.wasm`/`.wat` files, exactly one changes: `coverage-forced-portable` case `002853` reduces `starshine.raw.wasm` from `2015` to `2010` bytes while its canonical wasm and WAT remain byte-identical. All other saved semantic files are byte-identical.

The established agent classification remains measured/source-backed Starshine cleanup wins: `coverage-forced-portable=243` and `dae-effectful-args=124`. Aggregate deltas become `-110224` raw / `-797486` canonical / `-5465849` WAT bytes, with no canonical/WAT-positive case. There are no unknown/risky, size-losing generated, Starshine validation, or true-semantic residuals.

## Exact-once public scheduling

The first retained dedicated input, `gen-valid-000001.wasm`, was replayed through public `--optimize`, public `--shrink`, and public `--optimize -O4z`. Each mode emits a valid `38`-byte module, contains exactly one DAEO start/done pair, and places DAEO immediately before `inlining-optimizing`.

DAEO timers:

- optimize: `671us`;
- shrink: `629us`;
- O4z: `534us`.

The large stripped-artifact pre-slot blockers remain owned by `[WALL]001`: optimize stalls in `vacuum`; shrink and O4z stall in early `ssa-nomerge`.

## Validation

Green final validation:

- `moon info` with existing warnings;
- `moon fmt` with the unrelated `moon.mod` rewrite restored;
- focused grouped-function tests `3/3`;
- focused forwarding-component tests `4/4`;
- full `dae_optimizing_test.mbt` `329/329`;
- full `moon test` `8824/8824`;
- native release build;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`;
- no `.mbti` diff;
- direct output validation and repeat hash comparison;
- complete four-lane explicit-native matrix;
- exact-once public scheduling checks;
- `git diff --check`.

## Judgment and continuation

The raw grouped-signature residue is closed as a measured Starshine win. DAEO remains active because the canonical direct artifact still differs by `+12335` bytes. The ranked next owner is post-component cleanup in defined Funcs `7008` and `7007`, where Binaryen's source-mandated filtered optimization replay is materially smaller and Starshine currently skips all nested cleanup at `touched=46`.

Next iteration: reduce a source-backed post-component cleanup fixture red-first, prove a bounded function-filtered replay that remains valid on oversized/nondefaultable-local functions, and retain it only if it closes canonical bytes without raw or pass-local regression. Keep plain DAE separate and preserve exact-once late public scheduling.
