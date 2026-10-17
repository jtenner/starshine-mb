---
kind: workflow
status: supported
last_reviewed: 2026-10-09
sources:
  - ../../../raw/tooling/2026-10-09-output-differences-v133.json
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_merge_blocks_wbtest.mbt

---

# `merge-blocks` Fuzzing Profile

## October 9, 2026 final native comparison renewal

The final native CLI, SHA-256 `42f386573da7ccab4ae923122b17e29e9069a5686fb91921f89f439fd2de85a3`,
completed 10,000 new `merge-blocks-all` comparisons with seed `0x5eed`,
eight workers, at most eight subprocesses, and verified Binaryen 133.
The complete result is `.tmp/output-difference-final-merge-v133-10000-renewed/result.json`;
the [durable evidence record](../../../raw/tooling/2026-10-09-output-differences-v133.json)
retains its counts and toolchain identity. There are 7,007 normalized matches,
0 cleanup-normalized matches and 2,993 residual output differences.
Raw totals are 535,356/541,342 bytes
(Starshine/Binaryen); canonical totals are
535,356/541,342 bytes.
No output is larger under either size measure. Validation, generator, property
and command failures are zero. Independent `wasm-tools` validation was required.
Runtime observation was off in this aggregate; the family evidence below
provides the scoped semantic judgments. The final bounded wasm-gc suite passes
14,001/14,001 tests. Earlier measurements retain their original binary scope.

## October 9, 2026: raw output gaps repaired

A focused replay with repaired native CLI SHA-256
`42f386573da7ccab4ae923122b17e29e9069a5686fb91921f89f439fd2de85a3`
and verified Binaryen 133 SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`
closes the two raw output gaps found outside the expression residual family.
This supersedes the raw aggregate deficit recorded in the earlier October 9
entry for the three replayed fixed fixtures; it does not claim a fresh aggregate
run. The original manifest has 1,998 effect-order records and 1,990 EH/atomic
records, each formerly three raw bytes larger despite canonical equality.
The final source and frozen CLI repeat all three raw/canonical/live/downstream
output records and all nine Node observations from both earlier repaired CLIs
`9d2f32298a86fe13ded4cd7ed3f97cf33a9f9ae03bd5f8d0c4a3b95e6289523b`
and `fce72edb42289901fefb4ae40f2febe7482f55f1dc3c425b89cf9b36c80983e1`
exactly, with zero record differences. This final renewal is a three-fixture
check, not a new aggregate or timing run.

| Fixed family | Repaired raw / canonical Starshine bytes | Raw / canonical Binaryen bytes | Live-export v133 `-O` / `-Oz`, both tools |
| --- | ---: | ---: | ---: |
| Expression children | 76 / 76 | 78 / 78 | 71 / 71 |
| Effect order | 51 / 51 | 51 / 51 | 73 / 73 |
| EH/atomic boundary | 58 / 58 | 58 / 58 | 53 / 53 |

Effect-order cleanup removes only a branch-free, zero-parameter result-block
wrapper in the already lowered instruction stream. The earlier `global.get`
remains before `global.set`, and the store still uses the old global value.
The HOT effect-order guard remains active. EH/atomic cleanup removes the
duplicate plain void function type and remaps the function type use; exception
control, tag type, fence, and atomic load remain unchanged. The repaired raw
outputs for those two families are byte-identical to Binaryen. The expression
output retains its two-byte size win from the effect-free arm nops; generic
cleanup does not remove additional instructions in this fixture. The
[encoding regressions](../../../../../src/passes/merge_blocks_encoding_wbtest.mbt),
[dispatcher tests](../../../../../src/cmd/merge_blocks_encoding_wbtest.mbt), and
[effect/trap tests](../../../../../src/passes/merge_blocks_test.mbt) check the
smaller raw bytes, type uses, and instruction order.

For each fixture, the input and both outputs were given live function and memory
exports; expression also exports its tag, and effect-order exports its global.
Node replay agrees three ways: expression stores `11` at offset zero then throws
the exported tag with payload `13`; effect-order stores `7` at offset zero and
sets its global to `1`; EH/atomic returns normally with zero at offset zero.
The common v133 `-O` and `-Oz --all-features --strip-debug` outputs are byte-identical
for each pair, with the live sizes in the table. Every raw, canonical, exported,
and downstream module passes `wasm-tools validate --features all`.

These are scoped **parity repairs** for effect-order and EH/atomic, and a retained
**Starshine size win** for expression children. The fixed-generator coverage
limit in the earlier entry still applies. No engine speed or pass wall-time gain
was measured. Exact replay hashes, bytes, and observations are local at
`/tmp/starshine-small-shape-review/final-merge-42f386-checkpoint/summary.json`;
`checkpoint-equality.json` beside it records zero differences against the
preserved `final-merge-9d2f-checkpoint/summary.json` and
`final-merge-fce72-checkpoint/summary.json`. Earlier results below
retain their recorded binary hashes and historical scope.

## October 9, 2026: v133 expression-family size win

The fresh `merge-blocks-all` lane in `.tmp/optimizer-ir-fix-merge-blocks-v133-10000/`
compared 10,000 cases at seed `0x5eed`: 7,007 normalized matches and 2,993
expression-family residuals, with zero validation, property, generator, or command
failures. It used native CLI SHA-256
`ef9d25da69bc5a1832d7c12a4f8f3f2ef33a5759fb58190f8fbd1dee55e07b30`
and verified Binaryen 133 SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
This is current v133 evidence; older entries below keep their historical scope.

| Scope | Starshine raw / canonical bytes | Binaryen raw / canonical bytes |
| --- | ---: | ---: |
| Full 10,000-case aggregate | 547,320 / 535,356 | 541,342 / 541,342 |
| 2,993 expression-family records | 227,468 / 227,468 | 233,454 / 233,454 |
| One expression fixture | 76 / 76 | 78 / 78 |

All 2,993 expression records have manifest `wasm_hash`
`fnv1a64-b0f261c877c0cb83`. All 20 retained inputs agree with that generator hash
and have SHA-256 `cbc3966f5709dac05064e28b702e4ab29c3de455a5c87c699132ccb966858ebe`.
The retained input/output triples are identical. The
[expression generator](../../../../../src/validate/gen_valid.mbt#L9490) is a fixed
fixture; these are repeated executions of one input, not 2,993 distinct programs.

The exact residual removes only two empty-arm `nop` instructions. It keeps the
condition, all dropped values, the store, and the throw in the same order.
Static executable instruction count falls from 23 to 21, excluding `else` and
`end` delimiters. A `nop` has no value, effect, or trap to preserve, so this exact
family is a **Starshine size win**. Exporting the function, memory, and tag for a
three-way Node replay gives the same result for input and both outputs: memory
at offset zero contains `11`, then the exported tag is thrown with payload `13`.
The original lane had runtime observation off.

With those exports retained, a common verified-v133 `-O` or
`-Oz --all-features --strip-debug` step produces byte-identical 71-byte modules
from both outputs. The live direct modules are 98 Starshine versus 100 Binaryen
bytes. All retained outputs and downstream outputs pass `wasm-tools validate
--features all`. This proves a direct size gain with no downstream size loss for
the fixed fixture. It does not measure engine speed or pass wall time and does
not classify other merge-blocks shapes. Exact measurement and replay records are
local at `/tmp/starshine-small-shape-review/{measurements,live-summary,aggregate-hash-summary}.json`.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

Durable baseline totals and tool identities are in the
[October 9 evidence ledger](../../../raw/tooling/2026-10-09-output-differences-v133.json).
Its classifications are review judgments for the stated generated families.

## 2026-08-28 shared-context performance renewal

Final native SHA-256 `fe5b224539b5bb7c31d3dd0e0efd92693cac6a162a9ac2979bea4624ee8201b1` completed the required matrix:

- regular GenValid, seed `0x5eed`: `100000/100000` normalized, zero mismatches or failures, and equal canonical totals of 422,113,416 bytes;
- `merge-blocks-all`, seed `0x5eed`: `10000/10000`, with `7007` normalized and `2993` current expression-profile residuals. Every residual is exactly two canonical bytes smaller because Starshine omits the two effect-free empty-arm `nop`s retained by Binaryen; aggregate canonical size is 535,356 versus 541,342 bytes. All four leaves are represented: structural `3019`, expression `2993`, effect order `1998`, and EH/atomic `1990`;
- explicit wasm-smith, seed `0x5eed`: all `9956` comparable cases normalized, zero Starshine failures, and the established 44 Binaryen/tool failures (`39` empty recursive groups, `3` bad section sizes, `1` invalid tag index, `1` table index out of range);
- random-all-profiles, seed `0x5555`: `8865` normalized plus `1135` canonically smaller pre-existing residuals, zero equal-size residuals, size losses, or failures;
- runtime-callable self semantics: exact `100/100`, zero failures.

Current and clean HEAD outputs are byte-identical on every input in the dedicated, random-all, and wasm-smith 10,000-case corpora. The performance change therefore introduces no output family. Evidence is under `.tmp/pass-fuzz-merge-blocks-context-final-regular-100000`, `.tmp/pass-fuzz-merge-blocks-context-final-dedicated-10000`, `.tmp/pass-fuzz-merge-blocks-context-final-wasm-smith-10000`, `.tmp/pass-fuzz-merge-blocks-context-final-random-all-10000`, `.tmp/pass-fuzz-merge-blocks-context-final-runtime-100`, and `.tmp/merge-blocks-perf-20260828/clean-head-corpus-compare`.

## Dedicated aggregate

`merge-blocks-all` is the stable pass-owned GenValid aggregate. It selects four weighted leaf profiles:

| Leaf profile | Weight | Covered surface |
| --- | ---: | --- |
| `merge-blocks-structural` | 3 | Nested block roots and branch-free loop/block wrappers. |
| `merge-blocks-expression` | 3 | Dropped values, `if` conditions, stores, throws, and ordinary expression-child prefixes. |
| `merge-blocks-effect-order` | 2 | Reorderable and conflicting global/memory effect boundaries; the review matrix also exercises represented trap/trap pairs. |
| `merge-blocks-eh-atomic` | 2 | `try_table`, dropped-reference, fence, and represented atomic barriers. |

Aliases `merge-blocks`, `merge-blocks-closeout`, and `merge-blocks-all-profiles` resolve to the aggregate. `random-all-profiles` also includes it.

The dedicated lane is:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-blocks --gen-valid-profile merge-blocks-all --out-dir .tmp/pass-fuzz-merge-blocks-genvalid-merge-blocks-all-10000-v131-release-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

## 2026-08-12 stack-carried-local guard refresh

Native SHA-256 `15804fd785eada79e95fcfc783cc026c5bab86f71fa80e24d1c176a923e7c86e` reran the dedicated aggregate against the explicit verified Binaryen-v131 binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-blocks --gen-valid-profile merge-blocks-all --out-dir .tmp/pass-fuzz-merge-blocks-stack-carried-fix-dedicated-10000-v131-20260812 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` normalized matches, zero cleanup-normalized residuals, mismatches, validation failures, property failures, generator failures, or command failures. Binaryen cache was `10000/0`. This refresh follows the direct stack-carried-overwritten-local regression discovered by SGO late-suffix runtime testing; the new guard is fail-closed and does not change the generated aggregate's Binaryen parity.

## 2026-07-31 review reclose matrix

The repaired pass uses native SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174` and explicit official Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

| Lane | Result | Classification |
| --- | --- | --- |
| Regular GenValid, count `100000`, seed `0x5eed` | `100000/100000` normalized matches | Exact; zero failures. |
| `merge-blocks-all`, count `10000`, seed `0x5eed` | `10000/10000` normalized matches | Exact; every selected leaf sampled, zero failures. |
| Random all-profiles, count `10000`, seed `0x5555` | `9827` normalized matches plus `173` residuals | Same neighboring-profile Starshine wins as the historical closeout: every residual is smaller, range `-18..-1`, total `-1130` bytes, zero ties or losses. |
| wasm-smith, count `10000`, seed `0x5eed` | `9956/9956` comparable normalized matches | Zero Starshine failures; 44 Binaryen-only cached parser/tool failures. |

The random-all residuals split into `56` `local-subtyping-control-refinalize`, `24` multivalue-drop, `21` GC, and `18` each result-refinalize, switch, control, and cleanup cases. Focused runtime separately proves that preserving the earlier load trap is an intentional correctness win over both pre-review Starshine and Binaryen v131, which expose the later division trap on the reduced fixture. No compare normalizer is needed for this pass.

## Historical 2026-07-31 Binaryen-v131 closeout

This earlier matrix predates the post-closeout distinct-trap-order review. It remains provenance; the refreshed matrix above supersedes its direct closeout status.

The historical matrix used native Starshine SHA-256 `01fd7706f67cf5d2628a4339b6f78d02cadcb541e830d9c7219e6136703cfcf0` and explicit `wasm-opt version 131 (version_131)` SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

| Lane | Result | Residual classification |
| --- | --- | --- |
| Regular GenValid, count `100000`, seed `0x5eed` | `100000/100000` normalized matches | None. |
| `merge-blocks-all`, count `10000`, seed `0x5eed` | `10000/10000` normalized matches | None. |
| `random-all-profiles`, count `10000`, seed `0x5555` | `9827` exact plus `173` raw residuals | All 173 are strictly smaller Starshine outputs, `-1..-18` bytes each and `-1130` bytes total. Selected profiles are `local-subtyping-control-refinalize` (`56`) and six `remove-unused-brs-*` families (`117`); there are zero ties or size losses. |
| wasm-smith, count `10000`, seed `0x5eed` | `9956/9956` comparable normalized matches | No Starshine mismatch; 44 Binaryen-v131 tool/parser failures: 39 `rec-group-zero`, 3 bad section size, 1 invalid tag index, and 1 table index out of range. |

All lanes reported zero Starshine validation, property, and generator failures and zero Starshine command failures. No compare normalizer was needed. The regular and dedicated reruns reused the deterministic saved GenValid manifests through the harness's `--resume` mode and rebuilt every Starshine output; Starshine outputs are never cached.

The random-all residuals are representation wins, not unclassified semantic drift. Literal multivalue drops avoid Binaryen scratch shells, scalar stack values avoid unnecessary local spills, and all-null branch-result blocks are narrowed to the hierarchy bottom without retained casts. The final lowered cleanup removed the former 44 size losses; every residual is now no-larger and externally valid.

## Representation boundary

General regular memory-atomic and `atomic.fence` acquire/release order is still not preserved through Starshine's boundary IR. The represented surface remains conservative, while a narrow raw bridge handles the exact official v131 acquire/release fixture and produces byte-identical `93`-byte output. Broader atomic extraction should reopen only when decode, IR, encode, and HOT effects retain ordering generically.
