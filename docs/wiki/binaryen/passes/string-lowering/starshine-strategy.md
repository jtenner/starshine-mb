---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md
  - ../../../raw/research/0284-2026-04-24-string-lowering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/tests.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../agent-todo.md
  - ../../../strings/string-const-surface.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./json-and-magic-imports.md
  - ./wat-shapes.md
  - ../string-gathering/index.md
  - ../../../strings/string-const-surface.md
---

# Starshine Strategy For `string-lowering`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code surfaces that already handle wasm strings, and the main uncertainty a future parity port must resolve.

## The honest current status

`string-lowering` is currently **upstream-only** for Starshine.
There is no `src/passes/string_lowering.mbt`, no similarly named owner file, and no active Starshine pass that rewrites string types, globals, imports, custom sections, or helper calls the way Binaryen does.

The status is even weaker than an ordinary removed pass:

- `src/passes/optimize.mbt` does **not** list `string-lowering` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt` does **not** list `string-lowering` in `pass_registry_removed_names()`.
- the magic-import sibling names `string-lowering-magic-imports` and `string-lowering-magic-imports-assert` are also not registered locally.
- `agent-todo.md` has active `SG` work for `string-gathering`, not a dedicated `string-lowering` slice.

So this page is a **status-and-port-planning** bridge, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- pass registry omission
  - [`src/passes/optimize.mbt#L111-L130`](../../../../../src/passes/optimize.mbt#L111-L130)
    - boundary-only names do not include `string-lowering`
  - [`src/passes/optimize.mbt#L133-L153`](../../../../../src/passes/optimize.mbt#L133-L153)
    - removed names do not include `string-lowering`
- textual WAT support for the literal opcode
  - [`src/wast/keywords.mbt#L101`](../../../../../src/wast/keywords.mbt#L101)
    - recognizes `string.const`
  - [`src/wast/parser.mbt#L2181`](../../../../../src/wast/parser.mbt#L2181)
    - parses the `string.const` text literal
  - [`src/wast/lower_to_lib.mbt#L2389`](../../../../../src/wast/lower_to_lib.mbt#L2389)
    - lowers parsed `StringConst` to `@lib.Instruction::string_const(bytes)`
  - [`src/wast/lower_to_lib.mbt#L7238-L7261`](../../../../../src/wast/lower_to_lib.mbt#L7238-L7261)
    - tests WAST-to-binary-module lowering for global and function `string.const` sites
- binary stringref section / literal plumbing
  - [`src/binary/encode.mbt#L72-L82`](../../../../../src/binary/encode.mbt#L72-L82)
    - binds a module stringref pool while encoding
  - [`src/binary/encode.mbt#L87-L99`](../../../../../src/binary/encode.mbt#L87-L99)
    - resolves `string.const` literals to active stringref indices
  - [`src/binary/encode.mbt#L1580-L1604`](../../../../../src/binary/encode.mbt#L1580-L1604)
    - collects unique `string.const` payloads across module globals and nested code
  - [`src/binary/decode.mbt#L148-L158`](../../../../../src/binary/decode.mbt#L148-L158)
    - binds the decode-time stringref context
  - [`src/binary/decode.mbt#L160-L170`](../../../../../src/binary/decode.mbt#L160-L170)
    - maps string literal indices back to bytes
  - [`src/binary/tests.mbt#L1817-L1859`](../../../../../src/binary/tests.mbt#L1817-L1859)
    - roundtrips a module with `string.const` literals and a `stringrefs` section
- validation and HOT roundtrip support
  - [`src/validate/typecheck.mbt#L3063`](../../../../../src/validate/typecheck.mbt#L3063)
    - typechecks `string.const`
  - [`src/ir/hot_lift.mbt#L1292`](../../../../../src/ir/hot_lift.mbt#L1292)
    - lifts `StringConst` into a HOT string-constant payload
  - [`src/ir/hot_lower.mbt#L197`](../../../../../src/ir/hot_lower.mbt#L197)
    - lowers HOT string constants back to library IR
- planning context
  - [`agent-todo.md#L552-L560`](../../../../../agent-todo.md#L552-L560)
    - active string work is `SG - String Gathering`, not `string-lowering`
  - [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md)
    - durable local docs for the existing `string.const` binary/textual surface

That map is the durable local truth today: Starshine supports the literal surface, but not Binaryen's boundary-lowering pass.

## What Starshine currently does not do

Current Starshine does not yet:

- preserve the public pass spelling `string-lowering` in the pass registry
- preserve `string-lowering-magic-imports` or `string-lowering-magic-imports-assert`
- run inherited `string-gathering` as a prefix to a larger lowering pass
- rewrite `HeapType::string` to `HeapType::ext`
- rewrite public singleton function types that mention strings
- turn defining `string.const` globals into imports
- emit or parse the Binaryen `string.consts` JSON custom section as a pass output
- implement the magic-import mode or assert-mode invalid-string failure
- add `wasm:js-string` helper imports
- rewrite `string.concat`, `string.eq`, `string.measure`, `string.wtf16.get`, `string.slice_wtf`, or the supported creation/encoding op families into helper calls
- refinalize after those rewrites
- disable the Strings feature after lowering

Those are the key differences from [`./binaryen-strategy.md`](./binaryen-strategy.md).

## Why this is not just `string-gathering`

See [`../string-gathering/index.md`](../string-gathering/index.md).

Binaryen `string-lowering` inherits the `StringGathering` prefix, but then performs much broader ABI and module-boundary rewrites.
The local `SG` backlog is therefore a useful dependency, not evidence that this pass is already underway.

Keep the split this way:

- `string-gathering` = literal collection/canonicalization and global-order interaction before `reorder-globals`
- `string-lowering` = string ABI lowering to externrefs, imports, helper calls, metadata, refinalization, and feature disable

A future implementation should not hide these under one local name unless the docs and registry explicitly say that the broader pass includes the narrower one.

## Likely future landing shape

A faithful Starshine port would probably be a **module/boundary pass**, not a HOT peephole.
The Binaryen pass mutates enough module-wide metadata that a HOT-only owner would be misleading.

A safe implementation ladder would be:

1. decide whether to register all three public Binaryen lowering names locally:
   - `string-lowering`
   - `string-lowering-magic-imports`
   - `string-lowering-magic-imports-assert`
2. add request tests that first prove the current names are absent or intentionally rejected
3. add a module-pass owner file only when the transform exists
4. reuse the existing `string.const` parser / encoder / decoder / validation code instead of redoing literal plumbing
5. lower the inherited gathering prefix only after the dedicated `string-gathering` story is clear
6. implement type and import rewrites before helper-call opcode rewrites
7. keep unsupported upstream string-op families explicit instead of silently no-oping them
8. add custom-section tests for `string.consts` JSON and magic-import behavior
9. run focused Binaryen parity fixtures before wider fuzzing

## Validation plan for an eventual port

A future port should validate in layers:

1. registry behavior
   - prove whether the local pass names are registered, boundary-only, removed, or implemented
   - keep magic-import siblings explicit
2. literal and metadata behavior
   - preserve deterministic literal identity
   - emit numbered `string.const` imports in default mode
   - emit the `string.consts` JSON custom section
   - handle magic imports and assert-mode invalid strings distinctly
3. type behavior
   - rewrite `stringref` / `(ref null string)` to externref-shaped types
   - preserve nullability
   - cover public singleton function-type cases explicitly
4. operation lowering
   - lower only the supported Binaryen `version_129` opcode families
   - test unsupported `string.new*` and `string.encode*` families as explicit boundaries
5. post-rewrite validity
   - refinalize or use an equivalent validation repair
   - remove the Strings feature only when all remaining string uses are gone
6. parity checks
   - compare focused `--string-lowering` fixtures against Binaryen
   - test `string-lowering-magic-imports` and `string-lowering-magic-imports-assert` separately

## Bottom line

Current Starshine `string-lowering` strategy is honest non-adoption plus a precise future bridge:

- no local pass registry entry today
- no owner file today
- no active backlog slice today
- real `string.const` textual, binary, validation, and HOT roundtrip plumbing already exists
- `string-gathering` is the nearby active planning surface, but it is not the same pass
- a faithful future port must be module/boundary-owned because it rewrites ABI-visible types, imports, globals, custom sections, helper calls, and feature flags

For upstream behavior, read [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./json-and-magic-imports.md`](./json-and-magic-imports.md), and [`./wat-shapes.md`](./wat-shapes.md).
