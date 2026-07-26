---
kind: concept
status: strong
last_reviewed: 2026-07-26
sources:
  - ./index.md
related:
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
---

# Binaryen v131 `local-subtyping` strategy

## Source baseline

The current oracle is official Binaryen `version_131`. The July 26, 2026 refresh read:

- `src/passes/LocalSubtyping.cpp`;
- `src/ir/local-structural-dominance.h`;
- `test/lit/passes/local-subtyping.wast`.

Hashes are recorded in [`index.md`](./index.md). The pass contract is unchanged in the behavior relevant to the prior v130 dossier, but the renewed Starshine audit found generator and implementation gaps that old evidence had missed.

## Algorithm

Binaryen:

1. skips functions when GC is disabled;
2. marks reference-typed locals as relevant;
3. records all local gets and sets/tees;
4. computes structurally non-dominated local indices;
5. repeatedly runs `ReFinalize`;
6. computes a `LUBFinder` result from every assignment to each body local;
7. removes non-nullability when a get is not dominated;
8. rejects other nondefaultable local candidates;
9. rewrites body-local declarations, get result types, and tee result types;
10. repeats until no declaration changes.

Parameters may be scanned but are not rewritten because the declaration loop begins at `getVarIndexBase()`.

## Official lit families

The v131 lit file covers:

- if/block refinalization;
- simple body-local but not parameter narrowing;
- zero-assignment preservation;
- multiple assignment LUBs;
- repeated local-get, select, and call-ref refinement;
- bottom call-ref handling;
- tuple/nondefaultable preservation;
- default-value nullable fallback;
- unreachable tee/get and incompatible unreachable assignments;
- nullable-to-non-null dominance;
- named versus unnamed blocks;
- try-table catch payload and catch-ref result boundaries.

Starshine's direct tests and seven family profiles now map to those released families. See [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) and [`fuzzing.md`](./fuzzing.md).
