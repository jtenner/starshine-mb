import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "../runtime.js";

const wasm = await getWasmGcExports();

export function defaultFunctionOptimizationPasses(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_29_new","push":"__js_array_29_push","length":"__js_array_29_length","get":"__js_array_29_get"}, item: { kind: "named", brand: "passes.ModulePass", showExport: "__js_show_passes_ModulePass" } }, wasm["passes__default_function_optimization_passes"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, arg1, wasm)), wasm);
}

export function defaultGlobalOptimizationPostPasses(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_29_new","push":"__js_array_29_push","length":"__js_array_29_length","get":"__js_array_29_get"}, item: { kind: "named", brand: "passes.ModulePass", showExport: "__js_show_passes_ModulePass" } }, wasm["passes__default_global_optimization_post_passes"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, arg1, wasm)), wasm);
}

export function defaultGlobalOptimizationPrePasses(arg0, arg1, closedWorld) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 2:
      return liftValue({ kind: "array", helper: {"new":"__js_array_29_new","push":"__js_array_29_push","length":"__js_array_29_length","get":"__js_array_29_get"}, item: { kind: "named", brand: "passes.ModulePass", showExport: "__js_show_passes_ModulePass" } }, wasm["passes__default_global_optimization_pre_passes__arity_2"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, arg1, wasm)), wasm);
    case 3:
      return liftValue({ kind: "array", helper: {"new":"__js_array_29_new","push":"__js_array_29_push","length":"__js_array_29_length","get":"__js_array_29_get"}, item: { kind: "named", brand: "passes.ModulePass", showExport: "__js_show_passes_ModulePass" } }, wasm["passes__default_global_optimization_pre_passes"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, arg1, wasm), lowerValue({ kind: "bool" }, closedWorld, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for passes.defaultGlobalOptimizationPrePasses.");
  }
}

export function optimizeModule(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_13_is_ok","unwrapOk":"__js_result_13_unwrap_ok","unwrapErr":"__js_result_13_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string" } }, wasm["passes__optimize_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_29_new","push":"__js_array_29_push","length":"__js_array_29_length","get":"__js_array_29_get"}, item: { kind: "named", brand: "passes.ModulePass", showExport: "__js_show_passes_ModulePass" } }, arg1, wasm)), wasm);
}

export function optimizeModuleWithOptions(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_13_is_ok","unwrapOk":"__js_result_13_unwrap_ok","unwrapErr":"__js_result_13_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string" } }, wasm["passes__optimize_module_with_options"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_29_new","push":"__js_array_29_push","length":"__js_array_29_length","get":"__js_array_29_get"}, item: { kind: "named", brand: "passes.ModulePass", showExport: "__js_show_passes_ModulePass" } }, arg1, wasm), lowerValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, arg2, wasm)), wasm);
}

export const optimizeModuleWithOptionsTrace = unsupportedExport("passes.optimizeModuleWithOptionsTrace", "Higher-order function parameters are not available through the wasm-gc adapter.");

export const AbstractTypeRefiningPassProps = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_AbstractTypeRefiningPassProps"](value);
  },
});

export const AsyncifyPassProps = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_AsyncifyPassProps"](value);
  },
});

export const BlockLiveness = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_BlockLiveness"](value);
  },
});

export const CFPState = Object.freeze({
});

export const CallSite = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_CallSite"](value);
  },
});

export const ConstHoistingState = Object.freeze({
});

export const ConstKey = Object.freeze({
});

export const EquivalentClass = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_EquivalentClass"](value);
  },
});

export const FieldValue = Object.freeze({
});

export const ILCallKind = Object.freeze({
});

export const ILTrivialKind = Object.freeze({
});

export const InliningOptions = Object.freeze({
  new(alwaysInlineMaxSize, oneCallerInlineMaxSize, flexibleInlineMaxSize, maxCombinedBinarySize, allowFunctionsWithLoops, partialInliningIfs) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new__arity_1"](lowerValue({ kind: "number" }, alwaysInlineMaxSize, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new__arity_2"](lowerValue({ kind: "number" }, alwaysInlineMaxSize, wasm), lowerValue({ kind: "number" }, oneCallerInlineMaxSize, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new__arity_3"](lowerValue({ kind: "number" }, alwaysInlineMaxSize, wasm), lowerValue({ kind: "number" }, oneCallerInlineMaxSize, wasm), lowerValue({ kind: "number" }, flexibleInlineMaxSize, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new__arity_4"](lowerValue({ kind: "number" }, alwaysInlineMaxSize, wasm), lowerValue({ kind: "number" }, oneCallerInlineMaxSize, wasm), lowerValue({ kind: "number" }, flexibleInlineMaxSize, wasm), lowerValue({ kind: "number" }, maxCombinedBinarySize, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new__arity_5"](lowerValue({ kind: "number" }, alwaysInlineMaxSize, wasm), lowerValue({ kind: "number" }, oneCallerInlineMaxSize, wasm), lowerValue({ kind: "number" }, flexibleInlineMaxSize, wasm), lowerValue({ kind: "number" }, maxCombinedBinarySize, wasm), lowerValue({ kind: "bool" }, allowFunctionsWithLoops, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, wasm["passes__InliningOptions__new"](lowerValue({ kind: "number" }, alwaysInlineMaxSize, wasm), lowerValue({ kind: "number" }, oneCallerInlineMaxSize, wasm), lowerValue({ kind: "number" }, flexibleInlineMaxSize, wasm), lowerValue({ kind: "number" }, maxCombinedBinarySize, wasm), lowerValue({ kind: "bool" }, allowFunctionsWithLoops, wasm), lowerValue({ kind: "number" }, partialInliningIfs, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for passes.InliningOptions.new.");
    }
  },
});

export const Literal = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_Literal"](value);
  },
});

export const LiteralKind = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_LiteralKind"](value);
  },
});

export const MSFCallSite = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_MSFCallSite"](value);
  },
});

export const MSFDefinedFunc = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_MSFDefinedFunc"](value);
  },
});

export const MSFHashBucketKey = Object.freeze({
});

export const MSFHashState = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_MSFHashState"](value);
  },
});

export const MSFParamKey = Object.freeze({
});

export const MSFParamKind = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_MSFParamKind"](value);
  },
});

export const MSFSiteValue = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_MSFSiteValue"](value);
  },
});

export const MemoryPackingPassProps = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_MemoryPackingPassProps"](value);
  },
});

export const ModulePass = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_ModulePass"](value);
  },
});

export const OptimizeOptions = Object.freeze({
  new(optimizeLevel, shrinkLevel, inlining, monomorphizeMinBenefit, lowMemoryUnused, lowMemoryBound, trapsNeverHappen) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_1"](lowerValue({ kind: "number" }, optimizeLevel, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_2"](lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_3"](lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, inlining, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_4"](lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, inlining, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_5"](lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, inlining, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "bool" }, lowMemoryUnused, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new__arity_6"](lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, inlining, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "bool" }, lowMemoryUnused, wasm), lowerValue({ kind: "bigint" }, lowMemoryBound, wasm)), wasm);
      case 7:
        return liftValue({ kind: "named", brand: "passes.OptimizeOptions", showExport: null }, wasm["passes__OptimizeOptions__new"](lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "named", brand: "passes.InliningOptions", showExport: null }, inlining, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "bool" }, lowMemoryUnused, wasm), lowerValue({ kind: "bigint" }, lowMemoryBound, wasm), lowerValue({ kind: "bool" }, trapsNeverHappen, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for passes.OptimizeOptions.new.");
    }
  },
});

export const ParamInfo = Object.freeze({
  show(value) {
    return wasm["__js_show_passes_ParamInfo"](value);
  },
});

export const SquareMatrix = Object.freeze({
});

export const Tail = Object.freeze({
});
