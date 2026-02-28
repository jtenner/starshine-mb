import { getWasmGcExports } from './internal/runtime.js';

export * from './internal/generated/passes.generated.js';

const wasm = await getWasmGcExports();

function resolveModulePass(name) {
  if (!wasm.__node_passes_can_resolve_module_pass(name)) {
    throw new RangeError(wasm.__node_passes_resolve_module_pass_error(name));
  }
  return wasm.__node_passes_resolve_module_pass(name);
}

export function modulePass(name) {
  return resolveModulePass(name);
}

export function alignmentLowering() {
  return resolveModulePass("alignment-lowering");
}

export function avoidReinterprets() {
  return resolveModulePass("avoid-reinterprets");
}

export function coalesceLocals() {
  return resolveModulePass("coalesce-locals");
}

export function codeFolding() {
  return resolveModulePass("code-folding");
}

export function codePushing() {
  return resolveModulePass("code-pushing");
}

export function constHoisting() {
  return resolveModulePass("const-hoisting");
}

export function constantFieldPropagation() {
  return resolveModulePass("constant-field-propagation");
}

export function dataflowOptimization() {
  return resolveModulePass("dataflow-optimization");
}

export function deadCodeElimination() {
  return resolveModulePass("dead-code-elimination");
}

export function deadArgumentElimination() {
  return resolveModulePass("dead-argument-elimination");
}

export function deadArgumentEliminationOptimizing() {
  return resolveModulePass("dead-argument-elimination-optimizing");
}

export function signaturePruning() {
  return resolveModulePass("signature-pruning");
}

export function signatureRefining() {
  return resolveModulePass("signature-refining");
}

export function duplicateImportElimination() {
  return resolveModulePass("duplicate-import-elimination");
}

export function globalRefining() {
  return resolveModulePass("global-refining");
}

export function globalStructInference() {
  return resolveModulePass("global-struct-inference");
}

export function globalStructInferenceDescCast() {
  return resolveModulePass("global-struct-inference-desc-cast");
}

export function globalTypeOptimization() {
  return resolveModulePass("global-type-optimization");
}

export function simplifyGlobals() {
  return resolveModulePass("simplify-globals");
}

export function simplifyGlobalsOptimizing() {
  return resolveModulePass("simplify-globals-optimizing");
}

export function globalEffects() {
  return resolveModulePass("global-effects");
}

export function propagateGlobalsGlobally() {
  return resolveModulePass("propagate-globals-globally");
}

export function typeRefining() {
  return resolveModulePass("type-refining");
}

export function typeGeneralizing() {
  return resolveModulePass("type-generalizing");
}

export function typeFinalizing() {
  return resolveModulePass("type-finalizing");
}

export function typeUnFinalizing() {
  return resolveModulePass("type-un-finalizing");
}

export function unsubtyping() {
  return resolveModulePass("unsubtyping");
}

export function heap2local() {
  return resolveModulePass("heap2local");
}

export function heapStoreOptimization() {
  return resolveModulePass("heap-store-optimization");
}

export function inlining() {
  return resolveModulePass("inlining");
}

export function inliningOptimizing() {
  return resolveModulePass("inlining-optimizing");
}

export function inlineMain() {
  return resolveModulePass("inline-main");
}

export function localCse() {
  return resolveModulePass("local-cse");
}

export function localSubtyping() {
  return resolveModulePass("local-subtyping");
}

export function loopInvariantCodeMotion() {
  return resolveModulePass("loop-invariant-code-motion");
}

export function mergeLocals() {
  return resolveModulePass("merge-locals");
}

export function mergeSimilarFunctions() {
  return resolveModulePass("merge-similar-functions");
}

export function mergeBlocks() {
  return resolveModulePass("merge-blocks");
}

export function flatten() {
  return resolveModulePass("flatten");
}

export function reReloop() {
  return resolveModulePass("re-reloop");
}

export function tupleOptimization() {
  return resolveModulePass("tuple-optimization");
}

export function onceReduction() {
  return resolveModulePass("once-reduction");
}

export function minimizeRecGroups() {
  return resolveModulePass("minimize-rec-groups");
}

export function typeMerging() {
  return resolveModulePass("type-merging");
}

export function monomorphize() {
  return resolveModulePass("monomorphize");
}

export function monomorphizeAlways() {
  return resolveModulePass("monomorphize-always");
}

export function optimizeAddedConstants() {
  return resolveModulePass("optimize-added-constants");
}

export function optimizeAddedConstantsPropagate() {
  return resolveModulePass("optimize-added-constants-propagate");
}

export function optimizeInstructions() {
  return resolveModulePass("optimize-instructions");
}

export function precompute() {
  return resolveModulePass("precompute");
}

export function precomputePropagate() {
  return resolveModulePass("precompute-propagate");
}

export function redundantSetElimination() {
  return resolveModulePass("redundant-set-elimination");
}

export function pickLoadSigns() {
  return resolveModulePass("pick-load-signs");
}

export function gufa() {
  return resolveModulePass("gufa");
}

export function gufaOptimizing() {
  return resolveModulePass("gufa-optimizing");
}

export function gufaCastAll() {
  return resolveModulePass("gufa-cast-all");
}

export function i64ToI32Lowering() {
  return resolveModulePass("i64-to-i32-lowering");
}

export function duplicateFunctionElimination() {
  return resolveModulePass("duplicate-function-elimination");
}

export function optimizeCasts() {
  return resolveModulePass("optimize-casts");
}

export function deNan() {
  return resolveModulePass("de-nan");
}

export function removeUnusedBrs() {
  return resolveModulePass("remove-unused-brs");
}

export function removeUnusedNames() {
  return resolveModulePass("remove-unused-names");
}

export function simplifyLocals() {
  return resolveModulePass("simplify-locals");
}

export function simplifyLocalsNoTee() {
  return resolveModulePass("simplify-locals-no-tee");
}

export function simplifyLocalsNoStructure() {
  return resolveModulePass("simplify-locals-no-structure");
}

export function simplifyLocalsNoTeeNoStructure() {
  return resolveModulePass("simplify-locals-no-tee-no-structure");
}

export function simplifyLocalsNoNesting() {
  return resolveModulePass("simplify-locals-no-nesting");
}

export function untee() {
  return resolveModulePass("untee");
}

export function vacuum() {
  return resolveModulePass("vacuum");
}

export function reorderLocals() {
  return resolveModulePass("reorder-locals");
}

export function reorderTypes() {
  return resolveModulePass("reorder-types");
}

export function reorderGlobals() {
  return resolveModulePass("reorder-globals");
}

export function reorderGlobalsAlways() {
  return resolveModulePass("reorder-globals-always");
}

export function reorderFunctions() {
  return resolveModulePass("reorder-functions");
}

export function reorderFunctionsByName() {
  return resolveModulePass("reorder-functions-by-name");
}

export function removeUnusedTypes() {
  return resolveModulePass("remove-unused-types");
}

export function removeUnused() {
  return resolveModulePass("remove-unused");
}

export function removeUnusedModuleElements() {
  return resolveModulePass("remove-unused-module-elements");
}

export function removeUnusedNonFunctionElements() {
  return resolveModulePass("remove-unused-non-function-elements");
}

export function directize(always = false) {
  return wasm.__node_passes_directize(Boolean(always));
}
