# SGO remaining official lit inventory

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

After the 0577/0578 source-alignment guardrails covered the remaining obvious items in `simplify-globals-read_only_to_write.wast` and `simplify-globals-non-init.wast`, inspect the rest of the official Binaryen v129 `simplify-globals*` lit family before choosing another `[SGO]003` behavior slice. The goal is to rank exact next candidates, not to infer broad `SimplifyGlobals.cpp` parity.

## Sources and commands

Fetched the remaining official v129 lit files into `.tmp/sgo-lit/` with Python `urllib`:

```sh
python3 - <<'PY'
import urllib.request, pathlib
base='https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/'
names=[
 'simplify-globals-dominance.wast',
 'simplify-globals-gc.wast',
 'simplify-globals-single_use.wast',
 'simplify-globals_func-effects.wast',
 'simplify-globals-nested.wast',
 'simplify-globals-offsets.wast',
 'simplify-globals-prefer_earlier.wast',
 'propagate-globals-globally.wast',
]
for name in names:
  p=pathlib.Path('.tmp/sgo-lit')/name
  if not p.exists():
    with urllib.request.urlopen(base+name, timeout=30) as r:
      p.write_bytes(r.read())
  print(name, p.stat().st_size)
PY
wc -l .tmp/sgo-lit/*.wast
```

Line counts after this fetch:

- `simplify-globals-dominance.wast`: 61 lines.
- `simplify-globals-gc.wast`: 88 lines.
- `simplify-globals-single_use.wast`: 332 lines.
- `simplify-globals_func-effects.wast`: 416 lines.
- `simplify-globals-nested.wast`: 32 lines.
- `simplify-globals-offsets.wast`: 85 lines.
- `simplify-globals-prefer_earlier.wast`: 53 lines.
- `propagate-globals-globally.wast`: 106 lines.

Local anchors inspected:

- `src/passes/simplify_globals_optimizing_test.mbt`
- [`0570`](./0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`0575`](./0575-2026-05-23-sgo-dominance-lit-regression.md)
- [`0578`](./0578-2026-05-23-sgo-official-lit-guardrails.md)
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`

## Mapping by official lit file

### `simplify-globals-dominance.wast`

Official shape: straight-line `global.set` followed by an `if`; a then-body pre-call read is replaced with the set constant, the post-call read is preserved, and the else-arm read is still a Binaryen TODO/negative.

Local status: covered by 0575 via `simplify-globals-optimizing rewrites dominated then reads before recursive call barriers`, plus broader runtime trace call/else/post-if guardrails.

Next action: no immediate behavior slice. If revisited, add only source-shaped guardrails for post-call and else-arm preservation, not else-join propagation.

### `simplify-globals-gc.wast`

Official shapes:

1. A mutable `funcref` global initialized with `ref.func` is replaced in function code under a `ref.cast`; Binaryen refinalizes the cast target after the replacement.
2. Less-refined typed global aliases are not substituted when doing so would require broader refinalization.
3. `struct.new_default` initializer aliasing is not duplicated when an export makes object identity observable.
4. Without that export, a single-use `struct.new_default` initializer can be folded into another global initializer.

Local status: Starshine already has narrow typed `ref.func` function-body replacement tests and typed element-item conservatism, but not an exact lit-shaped `ref.cast` refinalization test. The `struct.new_default` identity/export and single-use GC initializer cases are higher risk because they rely on GC object identity and initializer duplication semantics.

Next action: potential future exact guardrail/test slice, not a broad implementation slice. The only plausible small positive is the `ref.cast(ref.func-global)` function-body replacement if the WAT parser and verifier support the exact shape. Pair it with the less-refined alias negative. Do not batch with `struct.new_default` duplication.

### `simplify-globals-single_use.wast`

Official shapes: single-use global initializer folding into another global initializer, including nested initializer uses, multiple independent folds, multiple inputs into one initializer, and copy chains; negatives for second global use, function-code use, imported global, and function-code-only single use.

Local status: Starshine has `folds single-use multi-instruction global initializers without nested cleanup` and several alias/copy-chain tests, but not the full official GC `struct.new/ref.i31` family or exact multi-fold source shapes. Existing coverage proves the core startup-only fold boundary but not all GC initializer variants.

Next action: good future source-alignment test/docs candidate if kept to startup initializer folding. Prefer exact non-GC or parser-supported GC fixtures that pass immediately; do not turn this into broad function-code replacement or object-identity duplication work.

### `simplify-globals_func-effects.wast`

Official shapes: run `--generate-global-effects` before `--simplify-globals`, then preserve or clear facts based on function-effect summaries. The lit includes direct propagation before a call, preservation for unaffected globals after a call, and several negatives where calls hide gets/sets or target the relevant global.

Local status: Starshine SGO has a conservative runtime trace with call barriers and does not rely on a preceding generated global-effects summary in this direct pass. Many call-barrier and imported/exported runtime guardrails exist, but this specific cross-pass function-effects surface is not an SGO direct implementation target.

Next action: defer. Do not weaken call barriers in direct `simplify-globals-optimizing` from this file unless Starshine first implements or wires an equivalent function-effects analysis with exact oracle tests.

### `simplify-globals-nested.wast`

Official shape: propagate immutable defined globals into nested children of another global initializer, while preserving imported global references.

Local status: likely covered in spirit by startup propagation and single-use initializer folding tests, but no exact three-field `struct.new` source-shaped regression was found in the quick grep. This is a possible guardrail/regression candidate if the parser supports the exact GC fixture.

Next action: medium-risk source-alignment test. It is startup-only and probably safer than runtime/control broadening, but it uses GC initializer syntax; keep imported-middle preservation explicit.

### `simplify-globals-offsets.wast`

Official shape: propagate defined immutable globals into active data and elem offsets, keep imported offsets as `global.get`, tolerate passive data segments, and replace function-body reads of the defined alias with the constant.

Local status: Starshine already has `propagates startup globals into data offsets without cleaning untouched functions`, but that test only pins a data offset and nested-cleanup non-trigger. No exact lit-shaped active elem offset + imported offset + passive segment regression was obvious.

Next action: best immediate tiny source-alignment candidate. Add an exact-ish offsets regression that checks defined data/elem offsets become constants, imported offsets stay `global.get`, passive data remains accepted, and startup-only rewrites do not trigger nested cleanup. This should be a guardrail/regression slice unless it unexpectedly fails.

### `simplify-globals-prefer_earlier.wast`

Official shape: imported immutable `$global1` is copied through `$global2`, `$global3`, and `$global4`; all later initializer and function-body gets are retargeted to the earliest global.

Local status: covered in spirit by `simplify-globals-optimizing canonicalizes immutable global copy chains`, but not by the exact three-copy/four-read source shape.

Next action: good tiny guardrail/regression candidate, likely lower risk than GC. Add exact source-shaped coverage if we want traceability after offsets.

### `propagate-globals-globally.wast`

Official shape: belongs primarily to the separate `propagate-globals-globally` pass. It overlaps in global propagation concepts, but should not be used to infer direct SGO behavior without probing `--simplify-globals-optimizing` itself.

Local status: out of scope for immediate `[SGO]003` direct SGO breadth unless a specific shared-engine behavior is proven under SGO.

Next action: defer to a plain/shared global-propagation backlog slice.

## Ranking for next `[SGO]003` work

1. **Best next small slice: exact offsets source-alignment regression.** It is startup-only, already partly implemented locally, and can pin active elem offset/imported offset/passive data behavior without touching risky function/control broadening. If it passes immediately, document as a guardrail/test slice.
2. **Second-best tiny guardrail: exact prefer-earlier copy-chain regression.** It is likely already covered by existing copy-chain canonicalization, but exact official shape improves traceability.
3. **Medium-risk startup-only candidate: `simplify-globals-nested.wast` exact GC initializer propagation.** Useful, but only if the WAT/parser/verifier path supports the exact `struct.new` fixture cleanly.
4. **Higher-risk GC/refinalization candidate: exact `simplify-globals-gc.wast` `ref.cast` replacement plus less-refined negative.** Keep this separate and type-focused; do not batch with object-identity `struct.new_default` cases.
5. **Defer `simplify-globals_func-effects.wast`.** It requires generated function-effect facts; current direct SGO call barriers should remain conservative.
6. **Defer `propagate-globals-globally.wast`.** It is a sibling/shared-engine pass source, not direct evidence for new SGO behavior.

## Non-claims

- This note does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- It does not imply the remaining official lit files have all been locally covered exactly.
- It does not authorize broad same-init expression matching, loop FlowScanner reuse, function-effect call-barrier weakening, GC object-identity duplication, or refinalization-sensitive replacement without focused tests and oracle evidence.
