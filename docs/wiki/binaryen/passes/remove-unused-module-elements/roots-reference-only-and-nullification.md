---
kind: concept
status: supported
last_reviewed: 2026-10-13
sources:
  - ../../../../../src/rume/host_roots.mbt
  - ../../../../../src/rume/host_roots_wbtest.mbt
  - ../../../../../src/passes/host_roots_test.mbt
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_133/src/tools/wasm-metadce.cpp
  - ../../release-horizon-and-oracles.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-tables-init.wast
  - ./index.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# Roots, reference-only reachability, and nullification in Binaryen RUME

> **Comparison baseline — October 13, 2026:** new comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). Historical v131/v132 sources, commands, artifacts and results retain their original versions and do not establish v133 signoff.

## Explicit application export roots

`rume_run_host_roots_module_pass(module, roots: Array[String])` is available
in `rume` and through the `passes` forwarding API. The application supplies an
exact export allowlist; omitted exports are outside that application's interface.
It must come from the embedding application's contract, not sampled execution.
No manifest means ordinary optimization retains all exports.

For example, an LZ4 compression application can retain `memory`,
`lz4_input_ptr`, `lz4_output_ptr`, and `lz4_compress_run`. The independent
decoder export is outside this contract. This does not declare the general
library's decoder dead for all consumers. External JSON validation belongs to
the caller; missing or malformed data must not become an implicit empty list.

Every requested name must exist. Duplicate names have set semantics. The helper
preserves source export order, names, kinds and selected aliases. Explicit `[]`
removes exports while normal import/initialization/trap policies still apply.
An absent export section stays absent, so an already empty module remains eight
encoded bytes. Unknown names, invalid modules, unsupported metadata and scan limits return
`Err`; no partially pruned module is returned.

The helper preserves exposed function identity and numeric JavaScript
`Function.name` relative to its supplied input. It scans every source
`ref.func` and direct element target, including dead bodies/segments, then
strongly roots all function slots through the highest exposed index using the
existing RUME queue. Keeping predecessors makes dense remapping leave that
prefix unchanged. This may retain otherwise unused earlier bodies. Start,
callbacks, tables, imported memory effects and retained resource exports use
maintained RUME reachability. No extraction policy or function merge is used.

Use this helper as the final mutating transform. Later ordinary removal or
merging can invalidate the index guarantee. Ordinary RUME and aggressive
presets already compact retained indices: an unnamed exported function at
index 1 can become index 0 when an earlier function disappears, changing its
JavaScript name while still returning 42. This pre-existing host observation
gap is not repaired for ordinary callers by the new application API.

The single source-reference scan uses depth-bounded recursion, a scalar maximum
and one shared work counter. Limits are 100,000 total functions, 100,000 roots
and exports, 8,000,000 name characters, 8,000,000 function/root/local-run/
instruction/element entries, and nesting depth 256. The scan uses `run_count()`
without copying local declarations. These limits bound the added name and
reference analysis, not every cost in the existing validator or RUME. Both
input and output validate. Offset-sensitive or unsupported raw name metadata
refuses the operation. No new optimizer pass or production flag is required.

The source-backed compression/encoding/hash application checks demonstrate
actual code removal: LZ4 2,918 → 1,912 raw bytes (gzip9 1,639 → 1,156),
QOI 2,933 → 2,078 (1,660 → 1,255), and BLAKE3 13,174 → 12,653
(5,204 → 5,008). The full-export ordinary RUME control is used for these
comparisons. Exact output bytes and retained names match the declared host
checks, including 35 BLAKE3 length vectors. Stored gzip streams use Python
3.15.0 / zlib 1.3.2, level 9, mtime 0.

One warmup and 11 AB/BA measured pairs include the helper's input/output
validation and complete native invocation. Concurrent unrelated Moon activity
limits small timing estimates; no speed gain is claimed. The all-root yyjson
control has identical output but a paired median 6.386 ms added API cost and
2,096 KiB more median peak RSS. KissFFT is also byte-identical with an estimated
0.723 ms added cost. Positive modules show smaller, noisy time increases and
small peak-memory deltas. These are full explicit-API costs, not isolated
reference-scan timings or generated-code speed results. Ordinary callers do
not execute the new host analysis.

Focused tests assert actual trailing-body removal, unknown-name rejection,
retained indices/aliases, callbacks and start/data effects, Unicode names,
metadata refusal, all current reference carriers, and bounded scan refusal.
The implementation reuses module-element removal rather than building another
reachability graph.

The renewed ordinary RUME `rume-all` aggregate uses fresh native CLI
`0ada995d6b6f7af45485685b4682513305dfbc3082503992b9a2e8dd1858bac8`,
frozen native generator `86fa651a62128028bbaa047083e2fd78fa99aa07fe68c0d60995fc99a2be27eb`,
verified Binaryen 133, eight workers/subprocesses, independent wasm-tools
validation and `local-cleanup-debris` normalization. All 10,000 compare:
4,106 ordinary matches, 5,894 cleanup-normalized matches, zero residuals or
validation/generator/command/property failures. Node-v2 observes 8,868 all-equal
cases; all 1,132 continuation/descriptor cases are original-runtime-blocked
and remain unverified by that engine. There are no observed semantic mismatches.

This renews the unchanged ordinary RUME path after its internal prefix-aware
refactor. It is **not** 10,000 host-root subsets or a general host-contract proof.
The explicit application API has the separate targeted, real-module and host
observation evidence above. GC effect-scanner counters still have the recorded
`0xfb` decoding defect; they do not establish complete trap coverage.

## Why this page exists

This is the easiest part of `remove-unused-module-elements` to misunderstand.
The pass does **not** treat every surviving mention of an element the same way.

The central source idea is:

- some elements are **used**
- some are only **referenced**
- and those two states can lead to different final actions

That is why the pass sometimes keeps a declaration, sometimes deletes it, and sometimes weakens it.

## The shortest honest summary

Use this mental model:

- **used** = the original declaration still has to stay semantically live
- **usedReferenced** = the declaration still matters somehow, but Binaryen may be able to replace it with a weaker inert form or otherwise treat it more conservatively than a strong use

If you flatten those two states into one “live” bit, you lose one of the pass's main ideas.

## Strong roots

These are the easiest to understand.
They make an element strongly used.

Examples from the official source include:

- exports
- the start function
- direct `call`
- strong table operations like `table.get`, `table.set`, `table.init`, `table.copy`, `table.fill`, `call_indirect`
- strong memory operations like loads, stores, atomics, `memory.init`, `memory.copy`, `memory.fill`
- tag operations like `throw`, legacy/typed catch surfaces, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, `stack.switch`, and resume handlers
- elem/data operations like `elem.drop`, `data.drop`, `array.new_elem`, `array.init_elem`, `array.new_data`, `array.init_data`
- active parent tables or memories when the active segment is semantically meaningful

These are the “must keep the real thing” roots.

## Reference-style roots

The pass also tracks weaker mention styles.
These are still important, but they are not all the same as a direct execution root.

Examples include:

- `ref.func`
- `call_ref` heap-type reachability
- functions discovered from `FlatTable`
- functions named inside live elem segments
- heap types discovered from `struct.get` field types
- type-carried references to globals, tables, memories, or tags

This is where `usedReferenced` starts to matter.
The pass is careful not to overclaim that every such mention forces the original declaration to stay unchanged forever.

## Why active parent retention is not automatic

A table or memory named by an active segment is not always kept alive just because the syntax mentions it.
The pass first asks whether the segment is meaningfully doing anything.

### Active elem parent retention

A parent table can be kept alive by an active elem segment when the elem payload still matters.
A null-only active elem payload can become a no-op only when removing its write cannot expose a callable table default or earlier overlapping value and eliminate a trap. V131 keeps the write conservatively when those table semantics are possible.

### Active data parent retention

A parent memory stays alive when an active data segment may trap at startup
(non-constant offset or out-of-bounds range) or writes to an imported memory.
Nonempty in-bounds active data on an otherwise-unused defined memory does not
keep that memory by itself. Once the memory is live for another reason, nonempty
active data on it is retained.

That is why the pass is more precise than “active segment mentions parent, so parent is live.”

## `call_indirect` can retain table writes to preserve a trap

V131 treats a table-level `ref.func` initializer as a possible callee. An active element that overwrites that compatible default with null or a wrong-type function may be needed solely because deleting the write would expose the default and make a previously trapping `call_indirect` succeed. Possibly overlapping segments get the same conservative treatment because a later write may trample an earlier callable value.

Binaryen does not require preservation of the *kind* of trap: if removing a wrong-type write only changes the failure to a null-entry trap, pruning can still be legal. The important invariant is that default-mode cleanup must not eliminate a trap. `trapsNeverHappen` is allowed to opt into the more aggressive outcome. Do not collapse this rule into either strong direct-call liveness or reference-only reachability; it is a trap-semantics constraint. See [`./indirect-call-trap-preservation.md`](./indirect-call-trap-preservation.md).

## Why `call_ref` and closed-world mode matter

`call_ref` is one of the easiest places to underestimate the pass. Binaryen does not only look at immediate local syntax: it collects callable types and finds referenced functions whose declared types are compatible with those roots.

In closed-world mode Starshine now preserves that distinction:

- a plain `ref.func` can keep a declaration while allowing an uncalled definition body to become `unreachable`
- a compatible `call_ref` upgrades matching referenced targets to callable/strongly used
- an unknown or runtime-modified indirect-call table can conservatively upgrade the relevant referenced target set
- a runtime-used composite elem expression recursively contributes every nested `ref.func`, so a later compatible `call_ref` can upgrade the embedded target to callable
- when one `ref.func` keeps an indivisible composite declaration expression, sibling `ref.func`s in that same expression remain reference-only instead of being remapped through deleted function indices

So `call_ref` can keep a function body live even when there is no direct named `call`; plain declaration reachability need not. Composite GC constructors do not weaken that rule merely because the `ref.func` is not the expression's sole instruction.

## Why GC field types matter here

GC field access, array operations, reference casts/tests, descriptor casts, continuation construction/binding, and GC atomic operations can trigger heap-type collection. RUME is therefore not only about executable module indices; it must also follow declaration/type structure when that structure still references callable types, descriptors, or continuation types.

This is one more reason the pass is bigger than the name suggests.

## Functions are not identical to non-function elements

The pass handles functions differently from globals/tables/memories/tags in an important way.

A safe beginner summary is:

- functions mainly participate in keep-versus-remove plus function-type cleanup
- non-function elements also participate in keep-versus-remove-versus-weaken decisions

That is why the source has special nullification support for non-function elements.

## What “nullification” means here

For some reference-only non-function elements, Binaryen can replace the original declaration with a weaker inert declaration instead of keeping the original live one.

The page does **not** try to restate every kind-specific legality rule in prose.
The durable rule is simpler:

- reference-only does not automatically mean delete
- and it does not automatically mean keep the original declaration either
- sometimes it means “replace with the weakest still-valid declaration”

That weakening goes through `NullifyRemovableElement` in the official source.

## The three-way decision table

| State | Beginner-safe reading | Typical outcome |
| --- | --- | --- |
| strongly used | the original declaration still matters semantically | keep it |
| not referenced at all | nothing still points at it in a meaningful way | remove it |
| referenced-only | some surface still names or types it, but not as a strong use | maybe keep, maybe weaken, depending on kind and removability |

This table is the main idea the old folder was missing.

## The sibling pass changes only the deletion boundary

`remove-unused-nonfunction-module-elements` still uses the same graph logic.
What changes is the final rule:

- do not delete functions
- still apply the rest of the non-function cleanup

So the root/reference-only model matters to both public pass names, not just to the full variant.

## Easy mistakes to avoid

### Mistake 1: treating `ref.func` like `call`

They both matter, but they do not teach the same thing about strength of use.

### Mistake 2: assuming all active segments keep parents alive forever

No-op active segments are one of the official precision points of the pass.

### Mistake 3: assuming the pass only follows explicit instruction indices

It also follows flat tables, elem contents, and heap-type structure.

### Mistake 4: assuming reference-only means delete later

For non-function elements, reference-only can instead mean nullify or otherwise weaken.

### Mistake 5: preserving trap kind instead of trap existence

Binaryen can replace a wrong-type trap with a null-entry trap when no successful call becomes reachable. The default-mode obligation is to avoid eliminating the trap by exposing a compatible table default or earlier overlapping write; `trapsNeverHappen` relaxes that obligation.

## Bottom line

If you remember only one thing from this page, remember this:

- Binaryen RUME is built around the difference between **strong use** and **mere reference**

That difference is what explains:

- why the pass needs helper-heavy graph building
- why some parents survive and others do not
- and why some declarations are weakened instead of simply removed
