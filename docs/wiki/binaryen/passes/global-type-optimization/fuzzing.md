---
kind: workflow
status: working
last_reviewed: 2026-09-23
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/global_type_optimization.mbt
  - ../../../../../src/passes/binaryen133_gto_red_wbtest.mbt
related:
  - ./index.md
  - ../../version-133-upgrade.md
---

# `global-type-optimization` Fuzzing Status

## Active partial implementation

The former planned-only/boundary-only status on this page is superseded by the
Binaryen 133 corpus. The active closed-world module pass handles the v133 JS
descriptor placeholder cases and a narrow older GTO case: it removes all
unread fields from one isolated private struct type, rewrites its constructors,
and keeps the original operand effects. Both verified v132 and v133 oracles
remove the dead literal constructor operand in this shape. It refuses
open-world modules, imported boundaries, exposed reference signatures,
subtype graphs, multiple struct types, field traffic, named fields whose name
map cannot be repaired, and unsupported initializer/control shapes. See the
[pass owner](../../../../../src/passes/global_type_optimization.mbt) and
[red-first tests](../../../../../src/passes/binaryen133_gto_red_wbtest.mbt).

This is **not** full GTO parity. Binaryen also tightens mutable fields, removes
individual fields while keeping others, repairs field indices and writes, and
propagates facts across subtype graphs. The
[v133 investigation](../../version-133-upgrade.md#post-commit-fuzz-investigation)
records the original 10,000-case closed-world lane: 8,747 normalized matches,
1,253 mismatches, and 935 cases with larger Starshine output. The final native
CLI SHA-256 `ab5d4c2df4bb1e02ee76721d74bb9d5d2252e0b6aa500872cadb2c3fde976e48`
and GenValid SHA-256
`56e025413c18e5ce72941dd7390ff1b0a6706b667d115c39f887ed0b367c4905`
compared the same 10,000 deterministic random-all cases against the
checksum-verified official v132 oracle
(`1014958e6f20d412f1542320b43970214b0fb1ed780595e8f7c0d8761ed53725`)
and v133 oracle
(`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`).
Both lanes had **8,799 normalized matches, 1,201
mismatches, zero validation/command failures, and 864 canonical size losses**.
The new isolated-field rewrite fixed 52 prior mismatch indices and introduced
none in that corpus. V132 and v133 returned identical counts and sizes here.
An effectful-constructor fixture run through the final native CLI returned
`9` under Node both before and after GTO, confirming its global write survived
the removed field on that executable input.

A separate 10,000-case `campaign-gc-ref-subtypes` v132 lane had **zero
normalized matches, 10,000 mismatches, zero validation/command failures, and
6,250 canonical size losses**. Saved cases show hierarchy-aware field removal
and type remapping in Binaryen while Starshine retains fields. This is a
measured parity and size gap, not an accepted representation difference. The
remaining 3,750 cases with equal canonical size still need family-level
classification and semantic evidence.

Use the official v132 oracle for new baseline evidence. The verified v133
oracle is used only for this release-delta investigation. Neither a validated
module nor a smaller one is, by itself, a semantic equivalence proof.

## Signoff still required

- Build a dedicated private-struct GenValid aggregate; the existing
  `campaign-gc-ref-subtypes` lane demonstrates hierarchy gaps but does not
  cover every read/write, JS descriptor, or module-initializer shape.
- Run the regular 100,000-case and random-all 10,000-case lanes under the pass
  implementation workflow after the final fix; run the separate external
  generator lane when it is explicitly requested.
- Implement hierarchy-aware removal and immutability, then replay and classify
  every remaining mismatch family. Measure canonical size,
  downstream cleanup, and execution semantics before claiming a Starshine win.
- Keep v133 oracle failures separate from Starshine validation or behavior
  failures. Record exact oracle and native Starshine binary identities.

The earlier planned-only claims in other historical dossier pages describe the
state before the v133 corpus and should be read with this status update.
