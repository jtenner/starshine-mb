---
kind: workflow
status: held
last_reviewed: 2026-10-28
sources:
  - ../../../src/validate/match.mbt
  - ../../../src/validate/review_r1_06_wbtest.mbt
  - ../../../src/validate/review_r1_20261025_validation_acceptance_wbtest.mbt
  - ../../../src/cmd/hunt_r1_tooling_boundaries_20261025_wbtest.mbt
---

# Starshine October 28 fix-wave integration

The integration branch is `landing/starshine-fixwave-26`, based on master
`1fa2c7699476726231382e23d5aa357fd1f2749e`. Each source head was checked
against Joshua's list before merging. Each branch has its own merge commit,
in the specified order, without rewriting its failing-first history.

## Owner decision and scope

Joshua waived measurement for all 26 fixes on 2026-10-28. BURN-001 measured
LOSS and BURN-002 measured GAIN in the separate measurement lane. Both ship
by owner decision. No performance measurement is authorized or performed in
this landing. This decision supersedes the fix branches' measurement-only
landing tasks; their original evidence and cost limits remain in their dossiers.
Other active correctness, generator, and parity work remains open.

## Merge checkpoints and conflicts

The conflict codes below identify every file that Git reported as unmerged.
Resolution rules follow the table. An empty cell means no conflict.

| Branch under `fix/` | Verified source head | Merge commit | Conflicts |
|---|---|---|---|
| `starshine-burn-001` | `85d2bc4dc06b14c0b05faac6f4e951d3a63a3cd7` | `c9011e95931faa95aa9f47b26cad7c103357e86a` |  |
| `starshine-burn-002` | `cfdfabe9633aae95bf3316c4ec3471094a18f32a` | `ee94c82c10fc027eed45c294c5dd0623c9b68843` | L, C |
| `starshine-burn-003` | `018c0ba14c9391b37fb76f719fc094fdf20d13b3` | `675ed719ee5c79f5dab24515f9ecaa45ff69943e` | L, C |
| `starshine-burn-004` | `fc64e25ad2c97a38545c8d57d11393a1ac79a4ed` | `40be7b2222828e8ec1fef1f800ca0d71cb90e95d` | L, C |
| `starshine-burn-005` | `fadf797458678f700342f75fe5170f963c79749d` | `581b29343c0a7c9bee7ae8361e1ed157a04b3657` | C |
| `starshine-burn-006` | `e4d6fa94cc90ac605ddd6dc47c71ad553b43939e` | `fde4de7b06e5245b058ca13509797f1e2cbeabe8` | L, C |
| `starshine-burn-007` | `e59854a2980c50a0acdaa64926b24bf615e84312` | `0b56305173b73737908af4b3d8ea1026c4e460e1` | L, C |
| `starshine-burn-008` | `b2bd2d8e7ae300ad4cd46342d9836980130daffd` | `d1dfe3ab17ea60d1af048844d5d728740a9fad12` | L, C |
| `starshine-burn-009` | `ef94bddbf24ca81064b27c432d6959ccc62f5e81` | `b2cae1995511d405b7a29d34df8486166cd1cf33` | A, L, C |
| `starshine-burn-010` | `c9205c698260e961d04c99b23a0e4ba49a1e106c` | `77b5ec316b60942d9bac934c55a99c87fb90bbb8` | L, C |
| `starshine-burn-011` | `d5b1f7e43a5f923f1fb1d327ecab8a57ece9efdf` | `78ae0bf063abf3cc9e2e60d1ba86162df0d01225` | A, L, C |
| `starshine-r1-01` | `2b22349815ee0b9c1b74f6ce711b6a41c812d689` | `c13c9eb9b6197bab05a7c93d9ba922924eedde7a` | A, L |
| `starshine-r1-02` | `a8c3491c8f71f7d5b16b94c2a0b9d09c818935a1` | `1681960264b6954455b1aaa56129c3f15a0cba3b` | L |
| `starshine-r1-03` | `25df55c381e5da5972922af67b573ba167c22599` | `d094a7d36ec99ed052f77b7f79a2b95168d87ff0` | L |
| `starshine-r1-04` | `ec813111af6a01559a821d40532deaacbf6695e2` | `c930fcfe3144582c8bd2f1483a10f9d2afadc4a4` | L |
| `starshine-r1-05` | `2d68e754803995895f7ecc148243119dbcb26546` | `be6493d7a29ad92bdb3ee503e2247bfbc3bad878` | L |
| `starshine-r1-06` | `e7b7341d6cd805d053c5e1590bd5751934146672` | `984ccf29f74b4b1fc01762746c45839e5f59c1f8` | A, L |
| `starshine-r1-07` | `000e865cbe121c8f069001e8da587a4a22694459` | `0556b323d7a70795a86abfd4dfeb7d1d9f054535` | A, L, M, V |
| `starshine-r1-08` | `0ac934e36b72e9612b2f402812b4b0488b8a3182` | `21b1fbae802b2bf94b6aac91827443a4013b5cf0` | A, L, C |
| `starshine-r1-09` | `134ed550dade00a8feb319fa712ecd09fc3db243` | `41c9152230126cb4d6651d746964065b64c4082c` | A, I, L |
| `starshine-r1-10` | `c459432a1d6c240bf7285fd36724738d52a91955` | `b4eeac1fd231d8732e6ee16baa9eda779b46a2e7` | A, L, D |
| `starshine-r1-11` | `a0a09171f58e30a41d40488d3491f543873df891` | `d75b32d83d01a8374a851272ab058b33ba9b7369` | I, L, D |
| `starshine-r1-12` | `a0c3ab283cd2fb77212f0967098f0cec7c01621e` | `b91f9b2d2ca7b6d358cc99e06bcda15197f021c8` | I, L, D |
| `starshine-r1-13` | `129ae0fd750e855f90e2dbb5cbf29b236bcf0090` | `e4a0f79f22e07a5ed136bd74229eb0fb3aaefe21` | L, D, T |
| `starshine-r1-14` | `1167f015fe2cc2f5bf8bc6205419a5b35ad0fb9e` | `903cfd6181eee362940c57276cb370d99ecc5afa` | I, L, D, T |
| `starshine-f1` | `567c995b608b56b32536600393a8a53524811e17` | `d1dd3d9c2cb744c84db828ae1de7ee173eea6f22` | A, L |

- **A**, `agent-todo.md`: retain existing sections and insert each incoming
  section at its original anchor. BURN-009's first resolution accidentally
  truncated the backlog. BURN-011 restored the complete BURN-008 file and
  applied both BURN-009 and BURN-011 additions. The final landing checkpoint
  removes only measurement tasks superseded by the owner waiver.
- **L**, `docs/wiki/log.md`: retain the complete current log and prepend or
  append each incoming entry in its original location. The entire master log
  is retained byte for byte as one contiguous sequence.
- **C**, `src/cmd/cmd.mbt`: retain the complete current file and append the
  incoming tests. Each conflicting branch changes only the file's suffix.
- **I**, `docs/wiki/index.md`: retain all links and descriptions. R1-09 adds
  its entry at the original anchor. R1-11 and R1-12 add their topics to the
  existing command description while retaining R1-10's separate entry.
  R1-14 adds a separate link without replacing that combined description.
- **D**, `docs/wiki/tooling/cli-command-and-dispatcher.md`: retain the corrected
  historical-source references and every prior fix section. Append each new
  fix section, keep the October 28 review date, and add R1-12's test source.
- **M**, `src/validate/match.mbt`: preserve R1-06's removal of the incomplete
  helper-depth limit and its active visited-pair checks. Preserve R1-07's
  relative binder positions, complete group comparison, external type identity,
  and metadata checks. Carry R1-06's helper names and fuel removal through
  R1-07's new optional-index helper. The separate subtype-walk fuel stays intact.
- **V**, `src/validate/review_r1_20261025_validation_acceptance_wbtest.mbt`:
  concatenate the complete R1-05 and R1-07 files. Remove three byte-identical
  fixture helper definitions from `review_r1_06_wbtest.mbt` and share the
  R1-07 definitions. Every R1-05, R1-06, and R1-07 test remains.
- **T**, `src/cmd/hunt_r1_tooling_boundaries_20261025_wbtest.mbt`: concatenate
  the complete R1-09, R1-13, and R1-14 files, preserving all 11 tests.

## Preservation checks

All 26 verified source heads are second parents of their respective merge
commits and ancestors of the final integration. Every named test from all 64
incoming source-file versions remains. Thirty-eight source files match their
sole fix branch exactly. Combined files are the command dispatcher, matcher,
two validator test files, tooling boundary test file, and optimizer reports.
No public `.mbti` file changes.

Every added or corrected line from the 47-page master documentation stack
remains present. Only four stack pages change: the wiki log, command contract,
OI index, and data/element guide. The F1 guide updates the function-index
segment rule from nullable `funcref` to non-null `(ref func)`; its new tests
cover active validation and all three segment consumers.

The source was frozen at checkpoint `88a05776247bfcb66f6f2f109c7b42808bdc96e0`,
source tree `0288da0bdc5bf7d3ef3185b1d2de9caaaf1a6480`. That checkpoint only
formats the combined matcher calls. Later landing records do not change source.

## Test runner setup

Unmodified master was tested from its clean worktree at the exact baseline
head with Moon `0.1.20261023` and core `0.10.17+d971670cd`. The first full
`moon test -j 2` compiled the workspace but exited 255 when the passes
whitebox command exceeded Linux's per-argument limit. This is a runner setup
failure, not a code assertion or a merge defect.

The selected-test JSON was 178,233 bytes. Removing only empty file selections
produced 38,830 bytes and retained exactly the same 3,557 passes whitebox test
indices. Moon's default `moon test --outline --output-json` independently
matched that complete selection. A local Python runner assigns each outlined
test to exactly one freshly compiled driver, merges adjacent index ranges,
and invokes the same `moonrun --test-args` entry point. It checks process exit,
unique result keys, the complete expected result set, and every result message.
A zero driver exit alone is not a pass. No skipped test or benchmark is selected.
The baseline outline contains 15,501 tests in 34 compiled drivers.

The command whitebox tests also reopen `/dev/stdout` with truncation. Direct
regular-file capture lost earlier test records. Pipe capture retained them;
only the two command whitebox drivers were repeated. The final result set
requires one start and one completed result per selected test. All 34 drivers
on each revision satisfy that check, with no missing, duplicate, or skipped
results. Benchmarks and the default skipped lanes were never selected.

## Final validation of the integration checkpoint

| Check | Result |
|---|---|
| `moon build --target native --release src/cmd` | Pass, 46 tasks, zero errors |
| `moon test --build-only -j 2` | Pass, all default package test drivers built |
| Full default suite, unmodified master `1fa2c7699` | 15,501 tests, 15,474 passed, 27 failed |
| Full default suite, integration source `88a057762` | 15,616 tests, 15,587 passed, 29 failed |
| Native R1-11 filename tests | 4 passed, zero failed |
| R1-14 consumer using the native release binary | 34 export names round-trip |

The full suites ran through the same compiled Moon drivers with compact,
outline-verified selections because the ordinary full runner exceeded the
argument limit. The final runner and raw per-driver stdout, stderr, exit status,
selection, SHA-256, expected result keys, and summary records are retained in
`/tmp/starshine-fixwave-26-j5wrtdk7/`. The native binary's source revision,
source tree, and SHA-256 are in `native-binary-provenance.json` there.
No performance measurement was run.

All 27 baseline failures recur on the integration with the same assertion or
stack reason. Comparison removes only generated Wasm frame addresses,
compiler wrapper stamps/UUIDs, and temporary artifact paths. The failures are:

| Package | File and test indices | Failure reason |
|---|---|---|
| `passes` | `dae_type_update_index_wbtest.mbt`: 5, 6, 7, 8, 9, 10 | Abort in signature value-type absolutization |
| `passes` | `dae2_cleanup_context_wbtest.mbt`: 3, 4, 5 | Abort resolving function types |
| `passes` | `coalesce_reader_row_wbtest.mbt`: 1, 2 | Boolean-array bounds failure in source/write interference |
| `validate` | `validate.mbt`: 31 | Natural descriptor/string/exn/cast coverage assertion |
| `validate` | `gen_valid_wbtest.mbt`: 10, 12, 24, 88, 92, 112, 119, 135 | Memory64, descriptor, topology, profile, and seed coverage assertions |
| `validate` | `gen_valid_constraint_wbtest.mbt`: 1, 7 | Handler and logical-OR coverage assertions |
| `cmd` | `fuzz_harness_wbtest.mbt`: 28 | Expected minimized pass list differs |
| `fuzz` | `metamorphic_wbtest.mbt`: 241 | Expected 488, actual 484 |
| `fuzz` | `main_wbtest.mbt`: 33 | Coverage assertion |
| `fuzz` | `main_wbtest.mbt`: 97 | Invalid element-name index after cleanup/idempotence, seed -42, attempt 40 |
| `fuzz` | `main_wbtest.mbt`: 98 | Expected minimized pass list differs |

## Landing hold: two additional failures

Both checks were repeated in fresh runners against unmodified master and the
integration. Each passes on master and fails on the integration. No existing
assertion or accepted fix was changed to make the suite pass.

1. [`constraint_analysis_wbtest.mbt:50`](../../../src/passes/constraint_analysis_wbtest.mbt#L50),
   test index 0, `shared lowering keeps throwing call values on the stack across
   balanced captures`: expected zero `i32.eq` operations, actual one.
   The test runs both CA and OI on a written local after a throwing try/catch.
   The native command validates both outputs; CA removes the equality and OI
   retains it. BURN-003's new same-local guard requires a matching singleton
   reaching source for written locals. This is the relevant source contract;
   widening that proof or changing the existing shape expectation requires a
   coordinator decision. The repeated command keeps the correct source guards.
2. [`optimize_instructions_test.mbt:35828`](../../../src/passes/optimize_instructions_test.mbt#L35828),
   test index 666, `optimize-instructions documents descriptor ref.test_desc miss
   validation boundary`: the test expects rejection of its descriptor target,
   but the integration validator accepts it. Its two described/descriptor
   groups have identical empty struct shapes. R1-07 changes structural group
   matching, including descriptor metadata. Whether this rejection fixture must
   use structurally distinct groups needs review; neither matcher fix was
   removed and the rejection assertion was not weakened.

The owner's instruction is to stop when preserving both sides is insufficient
and a judgment is required. All 26 branch merges remain on the integration
branch. Master remains `1fa2c7699476726231382e23d5aa357fd1f2749e` and no push
was attempted. The hold is correctness/test integration, not measurement.
The final `git ls-remote origin refs/heads/master` output is:

```text
1fa2c7699476726231382e23d5aa357fd1f2749e	refs/heads/master
```
