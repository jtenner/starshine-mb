# SGO official lit breadth inventory

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

After the dominance and same-init guardrail slices, compare two remaining official Binaryen lit files against Starshine's current `simplify-globals-optimizing` tests before choosing another `[SGO]003` behavior slice:

- Binaryen `version_129` `test/lit/passes/simplify-globals-read_only_to_write.wast`
- Binaryen `version_129` `test/lit/passes/simplify-globals-non-init.wast`

The goal was to avoid inventing broad same-init or FlowScanner behavior from memory and to rank only source-shaped next work. This is a source-guided inventory, not an implementation slice.

## Sources and commands

Fetched the official lit sources into local scratch with Python's `urllib` because `curl` is not installed in this workspace:

```sh
python3 - <<'PY'
import urllib.request, pathlib
base = 'https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/'
for name in ['simplify-globals-read_only_to_write.wast', 'simplify-globals-non-init.wast']:
  p = pathlib.Path('.tmp/sgo-lit') / name
  p.parent.mkdir(parents=True, exist_ok=True)
  with urllib.request.urlopen(base + name, timeout=30) as r:
    p.write_bytes(r.read())
PY
wc -l .tmp/sgo-lit/*.wast
```

Line counts inspected:

- `simplify-globals-non-init.wast`: 138 lines.
- `simplify-globals-read_only_to_write.wast`: 929 lines.

Local anchors inspected:

- `src/passes/simplify_globals_optimizing_test.mbt`
- `docs/wiki/raw/research/0574-2026-05-23-sgo-next-breadth-probe-inventory.md`
- `docs/wiki/raw/research/0575-2026-05-23-sgo-dominance-lit-regression.md`
- `docs/wiki/raw/research/0576-2026-05-23-sgo-same-init-runtime-guardrails.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`

## `simplify-globals-read_only_to_write.wast` mapping

| Official lit family | Local Starshine status | Notes |
| --- | --- | --- |
| Simple no-else self guard: condition is `global.get`, body writes same global | Covered by `removes narrow read-only-to-write self guards`. | Source-shaped positive exists locally. |
| Pure `i32.eqz` condition and no-effect body wrapper | Covered by `removes eqz read-only-to-write self guards`, block-wrapped/body no-op tests, and later pure-condition variants. | Local coverage is broader than the lit. |
| Extra write to the global after all meaningful reads are only read-only-to-write guards | Behavior likely covered by the pass's removable-write facts and dead/same-init write tests, but no obvious exact source-shaped regression named after the lit's `$additional-set` was found in the quick grep. | Good tiny test/docs candidate if we want another lit alignment guardrail, but not clearly a missing implementation. |
| Additional real read after the self guard prevents optimization | Covered by multiple same-global read / real-read guardrails, including `keeps conditions with multiple same-global reads` and broad read-before/write guardrails. | Keep conservative. |
| If/else self guard is not optimized | Covered by `keeps self guards with else arms` and recursive nested-pattern else guardrails. | Confirmed negative. |
| Body side effects after the same-global set prevent the read-only-to-write optimization | Partially source-covered by wrong-target, non-constant, else, and tainted effect guardrails; no exact `$side-effects-in-body` lit-shaped test was obvious from the quick scan. | Useful guardrail candidate, but negative-only. |
| Nested three-global pattern in one pass | Covered by nested read-only-to-write tests and the recursive nested-pattern two-/three-layer lit regressions. | Already pinned. |
| Exact `if global.get; return; set` function-body shape | Covered by exact / eqz / compare / pure / block-wrapped if-return tests, including trailing-code negatives. | Local coverage is broader than the lit. |
| If-return failure because trailing `nop`, else arm, non-return body, or condition call consumes the global | Covered by trailing-code, else, and call/candidate-consumer guardrails. | Keep exact-body-size conservatism. |
| Candidate global controls whether a side-effecting call runs | Covered by nested condition / global-derived side-effect guardrails. | Negative. |
| Independent call condition with the candidate value flowing only through a result arm | Covered by nested-if arm value-flow tests with independent call condition. | Positive already implemented. |
| Candidate value flows into `local.tee` / observable side effect | Covered by `keeps condition values flowing into side effects` and `keeps global-derived local tees after pure flow`. | Negative. |
| Side-effecting but safe condition with independent `local.tee`, independent `i32.load`, candidate-derived pure chain, `select`, and `i32.eqz` | Covered by `removes side-effecting safe condition self guards` and sibling select-value tests. | Positive already implemented. |
| Recursive nested-pattern positives and near-miss negatives with else or extra dropped read | Covered by the recursive nested-pattern tests added before this handoff. | Already pinned. |

Conclusion: this lit file does not expose an obvious low-risk uncovered positive implementation slice. The most useful gaps are exact source-shaped guardrail tests for `$additional-set` and `$side-effects-in-body`, but those are either likely already behavior-covered or negative-only.

## `simplify-globals-non-init.wast` mapping

| Official lit family | Local Starshine status | Notes |
| --- | --- | --- |
| Multiple writes of each global's exact initial value, with later reads only to keep the globals alive | Covered in spirit by same-as-init write removal tests, including direct literal/ref/null/ref.func positives and void-block variants. | A split-function, multi-write source-shaped regression would improve traceability but is not clearly new behavior. |
| A later non-init write prevents same-init removal for that global | Covered by `does not remove non-init writes before reads` and non-init reference tests. | Local test is same-function and single-global, but pins the core boundary. |
| Imported global used as initializer means the mutable global lacks a locally known constant init; writing `i32.const 1` is preserved | Covered near this boundary by imported global-get init and imported alias-chain same-init guardrails, but the exact lit shape writes a different literal to a global initialized from an imported global. | Best negative guardrail candidate from this file if future same-init broadening resumes. |

Conclusion: this file mostly supports staying conservative around non-local initializer facts. It does not justify broad same-init expression equivalence. The exact imported-init/non-init-write negative is useful to pin before any future same-init broadening.

## Ranking for next `[SGO]003` work

1. **Best next small source-alignment slice: add exact official-lit guardrail tests without code changes.** The highest-value tests are:
   - `read_only_to_write` `$additional-set`: proves extra writes are removable when the only reads are fake read-only-to-write guards, or confirms current generic tests already cover it.
   - `read_only_to_write` `$side-effects-in-body`: pins that independent-looking body effects after the candidate set keep the guard conservative.
   - `non-init` imported-initializer/non-init-write negative: prevents future same-init broadening from treating imported initializer facts as local constants.
2. **If a behavior slice is required, first probe the `$additional-set` exact fixture under `--simplify-globals-optimizing` and run the current Starshine test form before coding.** It is the only item in these two lit files that looks like a positive and may not have an exact local regression name. If Starshine already passes, keep it as a regression/docs slice rather than forcing code.
3. **Do not resume broad same-init expression matching from `non-init`.** The lit plus 0574/0576 reinforce that initializer provenance matters; imported and alias init behavior is subtle.
4. **Do not broaden body-effect or control-flow handling from `read_only_to_write` without exact Binaryen positives and paired negatives.** The official lit is explicit that if-elses, extra real reads, global-derived side effects, and body side effects can block the optimization.
5. **If the next goal must be implementation rather than guardrails, leave these two lit files and pick a different Binaryen-positive family from primary source review.** Candidates still need fresh focused oracle probes and should avoid the high-risk surfaces already deferred in 0574.

## Non-claims

- This note does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This note did not run `wasm-opt` probes for every official module; it inspected the official lit expected outputs and mapped them to local test coverage.
- No Starshine implementation changed in this slice.
