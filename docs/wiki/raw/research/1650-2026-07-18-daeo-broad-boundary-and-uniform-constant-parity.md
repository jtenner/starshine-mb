---
kind: research
status: superseded
last_reviewed: 2026-07-19
superseded_by:
  - ./1651-2026-07-19-daeo-block-fallthrough-validation-and-local-cleanup.md
sources:
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../binaryen/passes/dae-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/precompute_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../src/fuzz/main_wbtest.mbt
  - ./1645-2026-07-17-daeo-final-direct-closeout-matrix.md
  - ./1649-2026-07-18-vacuum-shared-dag-admission-and-public-hso-attribution.md
---

# DAEO broad boundary cleanup and uniform-constant parity

> Superseded for current-source artifact evidence by note [`1651`](./1651-2026-07-19-daeo-block-fallthrough-validation-and-local-cleanup.md). This note remains the historical admission-repair, generated-profile, and pre-fallthrough-fix ledger.

## Scope

This slice reopens direct `dae-optimizing` output parity after the generated semantic matrix had gone green but the fixed self-host artifact retained thousands of gross-positive function-body deltas. It expands GenValid with focused guard, structured-local, immutable-field, computed-effect, table, GC-constructor, tail, and type-reuse ownership families; closes the targeted 1,024-case Binaryen-v131 matrix at parity-or-better; repairs the post-rebase broad-cleanup admission collapse; and renews the current Binaryen-v131 fixed-artifact ledger. It does not claim complete output parity or final semantic signoff. Every remaining Starshine-positive fixed-artifact function-body delta stays open, and the full four-lane post-change matrix remains due.

The fixed input is:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`
- `3,204,405` bytes
- `13,162` defined functions
- `21` imported functions

The prior retained endpoint from notes `1643`-`1645` was:

- raw Starshine `3,203,060`
- canonical Starshine `3,263,950`
- canonical Binaryen v130 `3,262,456`
- canonical module delta `+1,494`
- canonical code-section delta `+2,751`
- `3,344` Starshine-larger function bodies totaling `+89,342` bytes
- `2,419` Starshine-smaller function bodies totaling `-86,591` bytes

Those gross positive bytes were an open parity loss even though unrelated type-section and function-body wins partially masked them.

## Source-backed owners

Binaryen's optimizing DAE contract performs boundary rewrites, then reruns `precompute-propagate` and the filtered default function optimization pipeline on functions worth optimizing. Starshine had three broad-module gaps:

1. broad changed-boundary local cleanup ranked and retained only one removed-parameter definition;
2. modules above the generic nested-cleanup guards could leave equally proved changed siblings without post-boundary cleanup;
3. the bounded `defined <= 4096` constant/global revisit skipped large-module callees even when a direct call ended in an immediately materializable constant.

The retained implementation strengthens existing proof and cleanup owners instead of copying final Binaryen output shapes.

## Retained implementation

### Every changed boundary, not one ranked winner

The broad cleanup now compares original and current function signatures and records every touched definition whose parameter or result boundary changed. It applies direct/fallback unused-local compaction to every such definition, including zero-local and zero-removal definitions so later fact cleanup can still see the changed boundary.

The previous arbitrary single-winner choice is removed.

### Batched nested cleanup with per-function profitability

Material changed functions are replayed in one batch through the source-ordered local/dataflow subset:

- `precompute-propagate-prefix`
- `dead-code-elimination`
- `optimize-instructions`
- `simplify-locals`
- `code-folding`
- `precompute`
- `merge-blocks`
- `remove-unused-brs`
- `merge-blocks`
- `coalesce-locals`
- `reorder-locals`
- `vacuum`

Direct compaction applies to every proved changed boundary. The heavier replay is limited to definitions that remove at least `16` locals or still encode to at least `2,048` bytes after compaction. Binaryen's changed-function contract also includes callers whose own signature is unchanged but whose callsite was rewritten by DAE. Starshine now admits those touched callers only when their current encoded body is at least `2,048` bytes; the same per-function non-larger retention and module validation remain authoritative. The fixed artifact admits `45` such material callers.

Each batch candidate is merged per function only when that function is changed and not larger. The merged module is validated before retention. This prevents unrelated wins from paying for a larger selected function.

A cheap per-function tail repair (`merge-blocks`, `remove-unused-brs`, `merge-blocks`, `coalesce-locals`, `vacuum`) handles structured functions where batched adapters skip an equal-size enabling rewrite. This repair was required to avoid the externally detected invalid Func `6727` block/return shape. Final output is externally valid.

`heap-store-optimization` remains outside this fallback. It has its own candidate-gated owner and previously consumed about `69s` on selected Func `41` without shrinking that function.

A final source-ordered `remove-unused-brs` batch now covers every proved changed boundary, including small functions below the material-body threshold. The batch clones only changed definitions, retains each changed non-larger body independently, validates the combined writeback, and leaves the heavier replay gated. The fixed artifact retains RUB changes for `80` definitions on the first broad wave, including Func `9639`; later convergence waves retain only their own new changes. A separate whole-module post-DAEO probe had shown `1,073` RUB-changed bodies and a `-16,471` body-byte delta, while the old changed-boundary replay missed the small-owner subset entirely.

### Large-module uniform constants

Large modules now discover direct call targets when the final immediate actual is:

- an immutable `global.get`, regardless of callee size; or
- a materializable numeric, float, null, or string constant when the callee has at least `64` recursive instruction nodes.

Candidate discovery is only a prefilter. The existing exact call-slice, ownership, escape, write, direct-call-count, caller-repair, callee-repair, and validation transaction remains authoritative. Plain `dead-argument-elimination` remains separate; this revisit is optimizing-only.

The size/node guard was required to avoid stealing small specialized neighborhoods. A broad unfiltered immediate-literal revisit regressed established exact-param, high-literal, and forwarded-cycle tests and was rejected. When successful materialization exposes an immediate literal in a direct callee, that newly visible callee is admitted to the same exact transaction. For a final `i32` suffix separated from older stack-carried arguments by a void effect or complex producer, the pre-existing verified suffix transaction now serves as the large-module fallback: it proves the immediate suffix across the already owned caller set, preserves all preceding evaluation, and revalidates the signature/body/call rewrite. The lane retains a `512`-rewrite bound; the fixed artifact needs `311` retained rewrites and is idempotent in one direct invocation.

### Immutable global field folding and one-wave callee follow-up

Constant materialization can inject immutable global reads into the callee. All changed boundaries are therefore offered the existing immutable-global struct-field fold before heavier replay.

When that fold exposes a materializable literal/default argument in a direct callee, DAEO reuses the existing exact-literal transaction on only direct callees of the folded definitions, then recursively runs changed-boundary cleanup once on the new boundary changes. This closes the observed `global.get -> struct.get -> constant condition -> ref.null -> forwarded callee` family without speculative expression movement.

## Red-first regressions

The focused large-module tests now prove:

- every broad changed-boundary sibling is cleaned, including a removed result with a retained effectful parameter;
- small changed-boundary control flow receives the source-ordered `remove-unused-brs` replay even when it does not qualify for the heavier material-body pipeline;
- a material caller whose own signature is unchanged still receives nested cleanup after DAE removes an argument at its callsite;
- local declarations and dead local traffic are removed for both large and smaller changed functions;
- large-module immutable reference globals can be materialized while preserving an imported effectful call;
- immutable struct fields fold after materialization;
- the folded caller exposes a `ref.null` argument that removes a downstream callee parameter;
- a large immediate literal callee is admitted by the bounded large-module uniform-constant revisit;
- a materialized boundary can expose and specialize a downstream forwarded-literal callee;
- an immediate final `i32` suffix remains removable when a void effect or complex first-argument producer prevents complete call-slice reconstruction;
- plain DAE keeps its separate scheduler behavior.

The focused DAEO file was green at `338/338` at this checkpoint. A separate direct `coalesce-locals` regression, reduced from the Func-`41` audit, proves that a void block ending in `unreachable` can be flattened only when no branch targets its label; the dead local write becomes `drop`, the dead tail is truncated, and branch-targeted or non-`unreachable` terminal blocks remain guarded.

## Expanded generic behavior after the fixed-artifact checkpoint

### Fifteen-leaf GenValid ownership matrix

The `dae-optimizing` aggregate now samples 15 stable leaves:

1. core cleanup;
2. many touched functions;
3. medium modules;
4. large local sets;
5. materially touched callers;
6. forwarded constant suffixes;
7. result/control cleanup;
8. structured locals;
9. return cleanup;
10. immutable fields;
11. computed effects;
12. table effects;
13. GC-computed actuals;
14. tail boundaries;
15. type reuse.

The structured-local leaf deterministically covers seven labels: copy, sequential color, loop copy, branch result, `if` result, tee chain, and nested block. The GC-computed leaf covers `struct.new`, `array.new`, `array.new_default`, and `array.new_fixed`. Both subcase selectors use `gen_valid_derive_stream_seed(...)` rather than raw seed modulo, preventing aggregate member selection from accidentally starving a subcase. Manifest tests require every selected profile and every subcase label over a bounded aggregate sample.

### Optimizing-only computed-actual retry

After the ordinary strict fixed loop converges, `dae-optimizing` modules with fewer than `1024` original definitions retry current fact-proven unread parameters. The retry:

- uses exact current direct-call facts;
- enables stack-carried void-effect slicing only for this optimizing-only lane;
- is bounded by `original_defined * 2 + 1`;
- reuses the existing localization, direct-call-count, signature, callee-local, and full-module validation transaction;
- does not change plain `dae` behavior.

The large-module unread-parameter batch uses the same stack-carried void-effect proof. Pure computed values such as `i32.add` disappear. Effectful or trapping values such as `global.set`, `memory.grow`, `i32.load`, `table.grow`, and `table.get` remain in their original evaluation order, with only their now-unused results dropped.

Exact stack-effect metadata now covers:

- `memory.grow`: one input, one output;
- `table.get`: one input, one output;
- `table.grow`: two inputs, one output;
- `struct.new`: one input per declared field, one output;
- `array.new`: two inputs, one output;
- `array.new_default`: one input, one output;
- `array.new_fixed`: the immediate element count as inputs, one output.

`struct.new`, `struct.new_default`, `array.new`, `array.new_default`, and `array.new_fixed` are removable only after that exact slice proof. Focused tests prove constructor removal, preservation of effects/traps, and dead GC type pruning.

### Conservative mixed type-section pruning

`dae_prune_unused_simple_func_types(...)` now supports flat mixed GC/function type sections when all safety conditions hold. Indexed reference types are remapped across signatures and module references, but pruning fails closed when it sees:

- a recursive group;
- a `DefType`/descriptor-style reference;
- a retained type definition with indexed internals;
- a retained non-function definition that would shift to a different index.

This allows the immutable-field fixture to retain its necessary struct type while compacting dead function signatures. It does not claim recursive/shared type repair.

### Shared exact-null precompute fold

The immutable-field chain exposed `ref.is_null(ref.null ...)` but Starshine left it unfurled. The fix belongs to shared precompute rather than a DAEO-specific final-shape matcher:

- `precompute_raw_try_fold_unary(...)` folds the raw stack form;
- `precompute_try_fold_ref_is_null(...)` folds direct HOT `RefIsNull` over HOT `RefNull`;
- focused tests cover untyped raw, typed post-compaction, and direct HOT execution.

The resulting `i32.const 1` removes the dead conditional, lets DAEO follow the exposed null callee, and allows the conservative type compactor to remove the now-unused function type.

## Binaryen-v131 generated parity-or-better checkpoint

The authoritative targeted run is:

- `.tmp/pass-fuzz-daeo-expanded-genvalid-final2-1024-20260718`;
- explicit Binaryen v131;
- seed `0x5eed`;
- profile `dae-optimizing`;
- both DAE cleanup normalizers;
- `--jobs auto` with the explicit native Starshine binary;
- requested/compared `1024/1024`;
- exact normalized matches `695`;
- cleanup-normalized matches `0`;
- normalized differences `329`;
- validation/generator/property/command failures `0/0/0/0`;
- Binaryen cache hits/misses `1022/2`.

All 15 leaves, all seven structured-local labels, and all four GC-constructor labels appear. The harness reports differences; it does not classify them. Raw output measurement gives this agent classification:

| family | cases | per-case Starshine raw delta | aggregate raw delta | classification |
|---|---:|---:|---:|---|
| computed effects | `83` | `-20` | `-1,660` | Starshine win; pure computation removed while effects/traps replay |
| forwarded suffix | `57` | `-7` | `-399` | Starshine win; verified suffix transaction removes more debris |
| immutable field | `71` | `-11` | `-781` | Starshine win; exact null fold and dead control/type cleanup |
| table effects | `58` | `-6` | `-348` | Starshine win; effect/trap retained with smaller dead-argument repair |
| touched caller | `60` | `-13..-14` | `-830` | Starshine win; caller cleanup is strictly smaller |
| **total** | **`329`** |  | **`-4,018`** | **all inspected raw differences favor Starshine** |

Core, many-touched, medium-module, large-locals, result-control, every structured-local label, return cleanup, every GC-computed label, tail boundary, and type reuse match exactly. No generated Starshine-positive family remains in this matrix.

This result renews the targeted `dae-optimizing` aggregate against Binaryen v131. It does not renew plain `dae` / `dae2`, does not replace the required four-lane matrix, and does not close the fixed-artifact gross-positive ledger.

## Current-source fixed-artifact refresh (2026-07-19)

The first post-rebase current-source refresh exposed an admission regression rather than a true alias or scheduler difference. The self-compare wrapper translated `--dae-optimizing` to the descriptive Starshine compatibility flag `--dead-argument-elimination-optimizing`, but both names enter the same `run_hot_pipeline_apply_dae_optimizing_module_pass(...)` dispatcher branch. The real failure was the all-or-nothing validation around broad changed-boundary local compaction: one invalid compacted body rolled back the complete boundary set, collapsing broad trace events from the historical `7758` to `32` and leaving the module raw/canonical `3203184` / `3264701`, or `+26679` / `+3305` versus Binaryen v131.

Candidate-context batch validation now checks all changed compacted functions with one shared module context and restores only invalid definitions. The first fixed-artifact wave rejects `362` compactions, all sampled as definite-initialization failures such as `uninitialized local: 4`, `65`, `7`, and `16`; later waves reject two and one definitions. Valid sibling compactions and the complete proved changed-boundary set continue through the filtered cleanup. Focused white-box coverage proves that one invalid sibling no longer discards a valid selected definition, and that non-fold body cleanup reports a real broad change. The final trace restores `7860` broad changed-boundary events, `3832` local-cleanup definitions, `117` all-changed `remove-unused-brs` markers, `589` nested-total timers, and `322` large uniform-constant revisits.

The finalized local order, type pruning, and immutable-field delay can expose one last profitable fact boundary after the earlier post-cleanup core wave. DAEO therefore performs at most one complete final optimizing retry when broad cleanup changed code or signatures. Recursive final convergence is disabled in that retry, and the candidate is retained only when it validates and is **strictly smaller**. The fixed artifact accepts `3134836 -> 3134699`; equal-size alternate cycle shapes are not accepted merely for being different. The computed-cycle regression demonstrates the retained smaller case's concrete benefit by eliminating a dead helper parameter/result boundary and its stack traffic.

Artifact-driving native binary:

- `_build/native/release/build/cmd/cmd.exe`
- run-time SHA-256 `1248170eb49b45f8ee7090baa978211e2be5555912f1e19c61ef675e4bb1dd6d`
- a post-format rebuild has SHA-256 `09c7f849ddf6d689b756f60c2e1c020c147a90cad96532358f116008e631692a` and reproduces the final artifact's byte-identical fixed point

Current direct output:

- `.tmp/daeo-current-final-converged-v131-20260718/starshine.raw.wasm`
- raw SHA-256 `c6d1b1bcc9e2b6ae6abc0910f868468474b9a5552d14b26c5a0a5364e08ae6da`
- canonical SHA-256 `ecb3ab22703c2112fb400b990783d8de6475fc3ee44787b6f91aa939b40abdbf`
- raw size `3134699`
- canonical size `3194547`
- wall time `1197s`
- pass timer `1195418500us`

Binaryen v131 reference retained from `.tmp/daeo-current-refresh-v131-20260718`:

- raw SHA-256 `b480c6db68326353022553ee3753869aed19ebcd8b1075f742818319f5475ade`
- canonical SHA-256 `98283f73d69e4bcab17df75f9370b6c0d3720a196d4e0b7f6bfa44d0e0ca7566`
- raw size `3176505`
- canonical size `3261396`

Current deltas:

| measure | Starshine delta |
|---|---:|
| raw module | `-41806` |
| canonical module | `-66849` |
| canonical type section | `-703` |
| canonical function section | `-1` |
| canonical element section | `-2` |
| canonical code section | `-66143` |

Canonical function-body ledger against Binaryen v131:

- `2927` Starshine-larger bodies totaling `+65036` bytes;
- `2553` Starshine-smaller bodies totaling `-131182` bytes;
- `7682` equal bodies;
- net body-payload delta `-66146` bytes;
- the code-section delta differs by `+3` because body-size LEB encodings also change.

The module is therefore substantially smaller overall, but direct output parity is **not closed**. Every `+65036` gross-positive byte remains an open parity loss. The current top canonical body deltas are:

1. Func `41` `+1540`
2. Func `7919` `+688`
3. Func `7007` `+664`
4. Func `6377` `+663`
5. Func `7556` `+656`
6. Func `2385` `+590`
7. Func `9639` `+492`
8. Func `1247` `+485`
9. Func `1111` `+435`
10. Func `8187` `+375`
11. Func `7957` `+349`
12. Func `5582` `+347`
13. Func `1622` `+313`
14. Func `122` `+306`
15. Func `8185` `+305`
16. Func `5525` `+299`
17. Func `1458` `+286`
18. Func `6122` `+285`
19. Func `1815` `+271`
20. Func `4921` `+268`

Canonical remapping remains a separate ledger. Compared with raw Starshine-vs-Binaryen body deltas, canonicalization worsens `705` function deltas by a combined `+5002` bytes; `78` functions cross from raw parity-or-better to canonical-positive, totaling `+363` canonical bytes. The largest crossings are Func `6450` `-1 -> +56`, Func `3222` `-2 -> +31`, Func `6133` `-13 -> +24`, Func `5336` `0 -> +16`, and Func `6493` `-2 -> +13`. These are output-parity losses until their type-index/remap owner is reduced or a measured Starshine benefit is proved.

All raw/canonical Starshine and Binaryen outputs validate with `wasm-tools validate --features all`. A second direct DAEO invocation completes in `13s` and is byte-identical at SHA-256 `c6d1b1bcc9e2b6ae6abc0910f868468474b9a5552d14b26c5a0a5364e08ae6da`.

The renewed targeted generated lane is `.tmp/pass-fuzz-daeo-current-postfmt-1024-20260719`. It remains exactly `1024/1024` compared, `695` normalized matches, `329` differences, and zero validation/generator/property/command failures. Every difference remains raw-smaller for Starshine, with the same family ledger and byte-identical Starshine mismatch outputs as the prior run: computed-effects `83 * -20 = -1660`, forwarded-suffix `57 * -7 = -399`, immutable-field `71 * -11 = -781`, table-effects `58 * -6 = -348`, and touched-caller `60` totaling `-830`; aggregate `-4018` raw bytes. Final convergence does not introduce a generated Starshine-positive family.

Performance remains open independently of output. The restored broad replay and bounded final convergence produce the intended smaller valid fixed artifact, but `1195.419s` pass-local is not an acceptable closeout runtime and is materially slower than the historical pre-expansion `722.234s` endpoint. The dominant current timer remains `detail:dae:nested-total` at `937639721us`; scheduler batching and pass selection remain required.

## Historical pre-expansion fixed-artifact endpoint

The following endpoint predates the computed/table/GC/type-pruning widening and final rebase. It is superseded by the July 19 current-source ledger above and remains only as historical comparison evidence.

Fresh native binary:

- `_build/native/release/build/cmd/cmd.exe`
- SHA-256 `5ef83a3867783a59c7b59dfbdce0ae0e809261fec3d770371b247b1caff173ca`

Latest retained direct output:

- `.tmp/daeo-parity-losses-20260718/material-2048-coalesce-terminal-artifact/starshine.raw.wasm`
- raw SHA-256 `ee6be57ee50003c093469740287ad7c3309e2df673cefd7c786feb15d01751b0`
- canonical SHA-256 `579a3a1e67436e432b7a479ce381643861abb690cfd2db3bc21e1f8652c6e16a`
- raw size `3,130,556`
- canonical size `3,188,457`
- pass wall time `722.234s`

Material touched-caller replay improves the all-changed-RUB endpoint by `24,746` raw bytes and `25,774` canonical bytes. It raises pass-local wall time from `534.223s` to `722.234s` (`+188.011s`), so batching and pass selection remain open performance owners. The `2,048`-byte gate preserves all six observed canonical-positive-gap improvements from the broader `1,024` experiment while reducing admitted callers from `151` to `45` and improving measured wall time from `897.485s` to about `700–722s`.

Binaryen v130 reference:

- raw size `3,177,421`
- canonical size `3,262,456`

Historical deltas:

| measure | Starshine delta |
|---|---:|
| raw module | `-46,865` |
| canonical module | `-73,999` |
| canonical type section | `-685` |
| canonical function section | `-1` |
| canonical element section | `-2` |
| canonical code section | `-73,311` |

Canonical function-body ledger:

- `3,007` Starshine-larger bodies totaling `+65,549` bytes;
- `2,594` Starshine-smaller bodies totaling `-138,885` bytes;
- net code-section delta `-73,311` bytes.

Compared with the original endpoint, gross positive bytes fall by `23,793`, from `+89,342` to `+65,549`. Material touched callers close another `820` gross-positive bytes relative to the all-changed-RUB endpoint. This is real progress, not closure: all `+65,549` remaining positive bytes are still open parity gaps.

The material-caller widening also exposes `19` canonical body deltas that increase by a combined `27` bytes relative to the prior endpoint, despite every retained raw function being individually non-larger. They are tracked as type-index/canonical-remap parity losses, not hidden under the larger gains: Funcs `10915 +4`, `10805 +4`, `11311 +2`, `11201 +2`, and fifteen `+1` cases (`11862`, `11753`, `11722`, `11637`, `11466`, `11428`, `11392`, `11113`, `11003`, `10341`, `10299`, `10249`, `10187`, `10042`, `7003`).

The historical raw output was idempotent under a second direct DAEO execution:

- first SHA-256 `ee6be57ee50003c093469740287ad7c3309e2df673cefd7c786feb15d01751b0`
- second SHA-256 `ee6be57ee50003c093469740287ad7c3309e2df673cefd7c786feb15d01751b0`
- second wall time `15.989s`

## Historical pre-expansion material function improvements

| defined func | prior delta | current delta | attribution |
|---:|---:|---:|---|
| `7943` | `+909` | `+2` | immutable ref-global materialization, immutable field fold, precompute, local cleanup |
| `9460` | `+799` | `-3,463` | bounded large uniform literal materialization plus changed-boundary cleanup |
| `7919` | `+984` | `+393` | immediate final `i32.const 0` parameter materialization and cleanup |
| `1247` | `+922` | `+465` | immediate final `i32.const -1` parameter materialization and cleanup |
| `2385` | `+592` | `+271` | bounded uniform-constant materialization and cleanup |
| `7556` | `+1,126` | `+665` | immutable global fold in caller, exposed `ref.null`, folded-callee exact materialization, cleanup |
| `7007` | `+664` | `+580` | changed-boundary compaction plus profitable `vacuum` |
| `5323` | `+677` | `+208` | material touched-caller precompute, vacuum, and post-coalescing repair |
| `4921` | `+589` | `+268` | changed-boundary precompute/coalescing cleanup |
| `6377` | `+1,045` | `+430` | removed-result local compaction plus nested cleanup |
| `5648` | `+826` | `-2,563` | removed-result compaction and nested cleanup |
| `6727` | `+469` | `-2,434` | changed-boundary cleanup plus single-function structural repair |

## Historical pre-expansion largest positive bodies

The historical pre-expansion top open canonical body deltas were:

1. Func `41` `+1,075`
2. Func `7556` `+665`
3. Func `7007` `+580`
4. Func `9639` `+492`
5. Func `1247` `+465`
6. Func `5525` `+459`
7. Func `1111` `+435`
8. Func `6377` `+430`
9. Func `7919` `+393`
10. Func `7957` `+349`
11. Func `1458` `+286`
12. Func `6122` `+285`
13. Func `6734` `+284`
14. Func `7534` `+276`
15. Func `122` `+275`

Func `9639` is now accepted by the forwarded-constant proof: its wrapper loses the uniform final `i32.const 0` parameter through the verified suffix fallback, and the exposed direct callee is specialized in the same invocation. The all-changed RUB batch lowers the remaining body from `+543` to `+492`; local/control cleanup debris remains open. Func `41` remains the largest local/control cleanup residual.

## Validation

Current green local validation after the admission repair and bounded final convergence:

- `moon fmt` completed and the unrelated `moon.mod` formatter drift was restored;
- `moon info` passed with warnings only;
- focused `src/passes/dae_optimizing_test.mbt`: `348/348`;
- focused `src/passes/pass_manager_wbtest.mbt`: `293/293`;
- full `moon test`: `9492/9492`;
- current targeted generated compare: `1024/1024`, `695` normalized, `329` raw-smaller differences, zero failures;
- all current raw/canonical Starshine and Binaryen fixed-artifact outputs pass `wasm-tools validate --features all`;
- the current raw output is byte-identical under a second invocation;
- `git diff --check` is clean.

The earlier focused precompute `41/41`, validate GenValid `159/159`, and fuzz manifest/batch `101/101` checks remain the last direct checks for those unchanged surfaces. The Binaryen-v130 DAEO/coalesce 1000-case smokes remain historical endpoint evidence only.

The required regular `100000`, dedicated `10000`, wasm-smith `10000`, and random-all `10000` closeout matrix has not been rerun for the final widened behavior. Note `1645` remains prior semantic closeout evidence, not current post-change signoff.

## Remaining work

1. Keep the current `+65036` gross-positive canonical body ledger open; the net-smaller module is not direct output-parity closure.
2. Repair or further narrow the definite-initialization-sensitive local compactor. The current batch guard safely rejects `364` unique invalid candidates across three waves, but those rejected cleanups contribute to current Func `41`, `7919`, `6377`, `2385`, and `8185` regressions relative to the historical shape.
3. Continue the reduced Func-`41` coalesce/local-coloring audit. The first 625-byte reducer family is byte-identical to Binaryen, but the current full body is `+1540` canonical bytes.
4. Reduce and classify current Funcs `7919`, `7007`, `6377`, `7556`, `2385`, `9639`, `1247`, `1111`, and `8187` one source-backed family at a time.
5. Eliminate or narrowly classify the current canonical-remap ledger: `705` worsened differentials totaling `+5002`, including `78` raw-parity-or-better to canonical-positive crossings totaling `+363`.
6. Optimize the restored broad scheduler and bounded final convergence without dropping candidate-context batch validation, per-function rollback, strict final profitability, or measured output gains. Current pass-local is `1195.419s`, with `937.640s` in nested cleanup.
7. Run the complete post-change regular `100000`, dedicated `10000`, wasm-smith `10000`, and random-all `10000` matrix before semantic signoff.
8. Renew plain `dae` / `dae2` separately against Binaryen v131.
9. Generalize recursive dependency components, mixed/multivalue result reconstruction, richer typed control, GC result refinement, tail calls, escapes, and recursive/shared type repair without weakening fail-closed boundaries.
10. Resume the public optimize/shrink/O4z audit separately; late `heap-store-optimization` remains the pre-DAEO public blocker from note `1649`.
