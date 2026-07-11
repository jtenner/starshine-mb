# Binaryen `remove-imports` Current-Source Read

Capture date: 2026-07-10

Purpose: record the source-backed contract for the public Binaryen `remove-imports` pass, which appeared in upstream registration but had no living Starshine wiki dossier. This is an owner/registration read, not a claim that Starshine implements or should schedule the pass.

## Primary URLs Checked

- Binaryen `version_130` owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveImports.cpp>
- Binaryen current `main` owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp>
- Binaryen `version_130` registration: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Binaryen current `main` registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current element-reference helper API: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/element-utils.h>
- Binaryen current imported-function iteration helper API: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>

## Durable Findings

- Both reviewed owner copies expose the public pass as `remove-imports` / `RemoveImports`. Their file comment states the intended use: make a module more inspectable by Binaryen's reference interpreter, which does not validate imports for a JavaScript environment. The owner itself is a walker: `visitCall` rewrites direct calls whose targets are imported, and `visitModule` performs the removal scan. It does **not** delegate to a `ModuleUtils::removeImports(...)` helper; no such API appears in the reviewed `module-utils.h`.
- The source contract is function-import-specific. `visitCall` replaces a direct imported call with `nop` when the callee result type is `none`, or with Binaryen's default `Literal(type)` when it has a result. Separately, `visitModule` collects imported-function names and retains only names found by `ElementUtils::iterAllElementFunctionNames`; every other imported function is removed. An imported function retained for an element/table reference can still have its direct calls rewritten.
- This is **not** a generic import-section deletion pass. The reviewed walker does not remove table, memory, global, or tag imports. Its retention check is specifically element/table function references; it does not establish a general host-ABI or behavioral-equivalence proof for rewriting imported calls.
- The pass has no user argument in the reviewed registration. This differs from parameterized ABI-shaping passes such as `remove-exports`.
- The capture does not identify a dedicated pass-named lit fixture. Treat the owner/element-helper/registration source as the evidence boundary until a future source read identifies an authoritative test surface; do not invent a `remove-imports.wast` contract from the name alone.
- Focused local searches on 2026-07-10 found no `remove-imports` / `RemoveImports` spelling in `src/passes/optimize.mbt` or elsewhere in `src/`. Starshine has only the prerequisite import model today: `ImportSec(Array[Import])` and shared imported-prefix index spaces.

## Wiki Consequence

Track `remove-imports` as an **upstream-only** pass. Keep it separate from:

- `duplicate-import-elimination`, which aliases equivalent function imports while preserving calls;
- `remove-unused-module-elements`, which performs reachability-based module cleanup and index repair;
- `remove-exports`, which removes public export entries rather than imported calls; and
- a hypothetical general import-section filter, which would have to address all external kinds and host ABI policy.

A future Starshine port needs an explicit semantics policy before implementation. A behavior-preserving optimizer cannot replace an arbitrary imported call with `nop` or a default result literal without a proof that the call's effects and result are irrelevant; Binaryen's pass is a specialized module-rewrite tool, not an ordinary default optimization candidate.
