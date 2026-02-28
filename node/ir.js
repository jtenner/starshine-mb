import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function compatIsF32Nan(arg0) {
  return liftValue({ kind: "bool" }, wasm["ir__compat_is_f32_nan"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function compatIsF64Nan(arg0) {
  return liftValue({ kind: "bool" }, wasm["ir__compat_is_f64_nan"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function compatIsF64NonFinite(arg0) {
  return liftValue({ kind: "bool" }, wasm["ir__compat_is_f64_non_finite"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function compatTruncF64ToI64S(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "bigint" } }, wasm["ir__compat_trunc_f64_to_i64_s"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function compatTruncF64ToI64U(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "bigint" } }, wasm["ir__compat_trunc_f64_to_i64_u"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function inferSsaTypes(arg0, arg1) {
  return liftValue({ kind: "named", brand: "ir.SSATypeInfo", showExport: null }, wasm["ir__infer_ssa_types"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.TypeContext", showExport: null }, arg1, wasm)), wasm);
}

export function runGvn(arg0, arg1) {
  return liftValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, wasm["ir__run_gvn"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm), lowerValue({ kind: "opaque", brand: "Map[BlockId, BlockId]" }, arg1, wasm)), wasm);
}

export const BasicBlock = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_BasicBlock"](value);
  },
});

export const BlockId = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["ir__BlockId__inner"](lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_ir_BlockId"](value);
  },
});

export const CFG = Object.freeze({
  block(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_8_none","some":"__js_option_8_some","isSome":"__js_option_8_is_some","unwrap":"__js_option_8_unwrap"}, item: { kind: "named", brand: "ir.BasicBlock", showExport: "__js_show_ir_BasicBlock" } }, wasm["ir__CFG__block"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm)), wasm);
  },
  build(arg0) {
    return liftValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, wasm["ir__CFG__build"](lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg0, wasm)), wasm);
  },
  dominanceFrontier(arg0) {
    return liftValue({ kind: "opaque", brand: "Map[BlockId, @set.Set[BlockId]]" }, wasm["ir__CFG__dominance_frontier"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm)), wasm);
  },
  dominates(arg0, arg1, arg2) {
    return liftValue({ kind: "bool" }, wasm["ir__CFG__dominates"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg2, wasm)), wasm);
  },
  dominators(arg0) {
    return liftValue({ kind: "opaque", brand: "Map[BlockId, BlockId]" }, wasm["ir__CFG__dominators"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm)), wasm);
  },
  entry(arg0) {
    return liftValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, wasm["ir__CFG__entry"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm)), wasm);
  },
  predecessors(arg0, arg1) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_5_new","push":"__js_array_5_push","length":"__js_array_5_length","get":"__js_array_5_get"}, item: { kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" } }, wasm["ir__CFG__predecessors"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm)), wasm);
  },
  strictDominates(arg0, arg1, arg2) {
    return liftValue({ kind: "bool" }, wasm["ir__CFG__strict_dominates"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg2, wasm)), wasm);
  },
  successors(arg0, arg1) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_5_new","push":"__js_array_5_push","length":"__js_array_5_length","get":"__js_array_5_get"}, item: { kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" } }, wasm["ir__CFG__successors"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm)), wasm);
  },
  toSsa(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, wasm["ir__CFG__to_ssa"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm), lowerValue({ kind: "opaque", brand: "Map[BlockId, BlockId]" }, arg1, wasm), lowerValue({ kind: "opaque", brand: "Map[BlockId, @set.Set[BlockId]]" }, arg2, wasm), lowerValue({ kind: "number" }, arg3, wasm)), wasm);
  },
  validate(arg0) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["ir__CFG__validate"](lowerValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_ir_CFG"](value);
  },
});

export const GVNKey = Object.freeze({
});

export const GVNState = Object.freeze({
});

export const IRContext = Object.freeze({
  applyGvn(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__apply_gvn"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  applySsaOptimize(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__apply_ssa_optimize"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  cfgDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__cfg_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getCfg(arg0) {
    return liftValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, wasm["ir__IRContext__get_cfg"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getGvn(arg0) {
    return liftValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, wasm["ir__IRContext__get_gvn"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getLiveness(arg0) {
    return liftValue({ kind: "named", brand: "ir.LivenessInfo", showExport: null }, wasm["ir__IRContext__get_liveness"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getLocalGraph(arg0) {
    return liftValue({ kind: "named", brand: "ir.LocalGraph", showExport: null }, wasm["ir__IRContext__get_local_graph"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getMod(arg0) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_9_none","some":"__js_option_9_some","isSome":"__js_option_9_is_some","unwrap":"__js_option_9_unwrap"}, item: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" } }, wasm["ir__IRContext__get_mod"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getSsa(arg0) {
    return liftValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, wasm["ir__IRContext__get_ssa"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getTypeCtx(arg0) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_10_is_ok","unwrapOk":"__js_result_10_unwrap_ok","unwrapErr":"__js_result_10_unwrap_err"}, ok: { kind: "named", brand: "ir.TypeContext", showExport: null }, err: { kind: "string" } }, wasm["ir__IRContext__get_type_ctx"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getTypes(arg0) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_10_none","some":"__js_option_10_some","isSome":"__js_option_10_is_some","unwrap":"__js_option_10_unwrap"}, item: { kind: "named", brand: "ir.SSATypeInfo", showExport: null } }, wasm["ir__IRContext__get_types"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  getUsedef(arg0) {
    return liftValue({ kind: "named", brand: "ir.UseDefInfo", showExport: null }, wasm["ir__IRContext__get_usedef"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  gvnDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__gvn_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  livenessDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__liveness_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  localGraphDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__local_graph_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  lowerToCfg(arg0) {
    return liftValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, wasm["ir__IRContext__lower_to_cfg"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  new() {
    return liftValue({ kind: "named", brand: "ir.IRContext", showExport: null }, wasm["ir__IRContext__new"](), wasm);
  },
  optimizeBodyWithSsa(arg0) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_11_none","some":"__js_option_11_some","isSome":"__js_option_11_is_some","unwrap":"__js_option_11_unwrap"}, item: { kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" } }, wasm["ir__IRContext__optimize_body_with_ssa"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  optimizeBodyWithSsaTrace: unsupportedExport("ir.IRContext.optimizeBodyWithSsaTrace", "Higher-order function parameters are not available through the wasm-gc adapter."),
  setBody(arg0, arg1) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__set_body"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg1, wasm)), wasm);
  },
  setLocals(arg0, arg1) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__set_locals"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  setMod(arg0, arg1) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__set_mod"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg1, wasm)), wasm);
  },
  ssaDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__ssa_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  typesDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__types_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  usedefDirty(arg0) {
    return liftValue({ kind: "unit" }, wasm["ir__IRContext__usedef_dirty"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
  validate(arg0) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["ir__IRContext__validate"](lowerValue({ kind: "named", brand: "ir.IRContext", showExport: null }, arg0, wasm)), wasm);
  },
});

export const LivenessInfo = Object.freeze({
  getLiveIn(arg0, arg1) {
    return liftValue({ kind: "opaque", brand: "@set.Set[SSAValue]" }, wasm["ir__LivenessInfo__get_live_in"](lowerValue({ kind: "named", brand: "ir.LivenessInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm)), wasm);
  },
  getLiveOut(arg0, arg1) {
    return liftValue({ kind: "opaque", brand: "@set.Set[SSAValue]" }, wasm["ir__LivenessInfo__get_live_out"](lowerValue({ kind: "named", brand: "ir.LivenessInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm)), wasm);
  },
  isLiveIn(arg0, arg1, arg2) {
    return liftValue({ kind: "bool" }, wasm["ir__LivenessInfo__is_live_in"](lowerValue({ kind: "named", brand: "ir.LivenessInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm), lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg2, wasm)), wasm);
  },
  isLiveOut(arg0, arg1, arg2) {
    return liftValue({ kind: "bool" }, wasm["ir__LivenessInfo__is_live_out"](lowerValue({ kind: "named", brand: "ir.LivenessInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, arg1, wasm), lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg2, wasm)), wasm);
  },
});

export const LocalGraph = Object.freeze({
  getSets(arg0, arg1) {
    return liftValue({ kind: "opaque", brand: "@set.Set[LocalSet]" }, wasm["ir__LocalGraph__get_sets"](lowerValue({ kind: "named", brand: "ir.LocalGraph", showExport: null }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "ir.LocalGraph", showExport: null }, wasm["ir__LocalGraph__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg0, wasm)), wasm);
  },
});

export const LocalSet = Object.freeze({
});

export const PhiNode = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_PhiNode"](value);
  },
});

export const SSABlock = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_SSABlock"](value);
  },
});

export const SSACFG = Object.freeze({
  buildUseDef(arg0) {
    return liftValue({ kind: "named", brand: "ir.UseDefInfo", showExport: null }, wasm["ir__SSACFG__build_use_def"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm)), wasm);
  },
  computeLiveness(arg0) {
    return liftValue({ kind: "named", brand: "ir.LivenessInfo", showExport: null }, wasm["ir__SSACFG__compute_liveness"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm)), wasm);
  },
  optimize(arg0) {
    return liftValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, wasm["ir__SSACFG__optimize"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm)), wasm);
  },
  splitCriticalEdges(arg0) {
    return liftValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, wasm["ir__SSACFG__split_critical_edges"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm)), wasm);
  },
  toCfg(arg0, arg1) {
    return liftValue({ kind: "named", brand: "ir.CFG", showExport: "__js_show_ir_CFG" }, wasm["ir__SSACFG__to_cfg"](lowerValue({ kind: "named", brand: "ir.SSACFG", showExport: "__js_show_ir_SSACFG" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_ir_SSACFG"](value);
  },
});

export const SSADef = Object.freeze({
});

export const SSADestructor = Object.freeze({
});

export const SSAInstr = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_SSAInstr"](value);
  },
});

export const SSALiteral = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_SSALiteral"](value);
  },
});

export const SSAOp = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_SSAOp"](value);
  },
});

export const SSATerminator = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_SSATerminator"](value);
  },
});

export const SSATypeInfo = Object.freeze({
  get(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_12_none","some":"__js_option_12_some","isSome":"__js_option_12_is_some","unwrap":"__js_option_12_unwrap"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, wasm["ir__SSATypeInfo__get"](lowerValue({ kind: "named", brand: "ir.SSATypeInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg1, wasm)), wasm);
  },
});

export const SSAUse = Object.freeze({
});

export const SSAValue = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["ir__SSAValue__inner"](lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_ir_SSAValue"](value);
  },
});

export const SplatOp = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_SplatOp"](value);
  },
});

export const Terminator = Object.freeze({
  show(value) {
    return wasm["__js_show_ir_Terminator"](value);
  },
});

export const TypeContext = Object.freeze({
  empty() {
    return liftValue({ kind: "named", brand: "ir.TypeContext", showExport: null }, wasm["ir__TypeContext__empty"](), wasm);
  },
  fromModule(arg0, arg1) {
    return liftValue({ kind: "named", brand: "ir.TypeContext", showExport: null }, wasm["ir__TypeContext__from_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
});

export const UseDefInfo = Object.freeze({
  getDef(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "tuple", helper: {"make":"__js_tuple_5_new","getters":["__js_tuple_5_get_0","__js_tuple_5_get_1"]}, items: [{ kind: "named", brand: "ir.BlockId", showExport: "__js_show_ir_BlockId" }, { kind: "named", brand: "ir.SSADef", showExport: null }] } }, wasm["ir__UseDefInfo__get_def"](lowerValue({ kind: "named", brand: "ir.UseDefInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg1, wasm)), wasm);
  },
  getUses(arg0, arg1) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_8_new","push":"__js_array_8_push","length":"__js_array_8_length","get":"__js_array_8_get"}, item: { kind: "named", brand: "ir.SSAUse", showExport: null } }, wasm["ir__UseDefInfo__get_uses"](lowerValue({ kind: "named", brand: "ir.UseDefInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg1, wasm)), wasm);
  },
  isDead(arg0, arg1) {
    return liftValue({ kind: "bool" }, wasm["ir__UseDefInfo__is_dead"](lowerValue({ kind: "named", brand: "ir.UseDefInfo", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "ir.SSAValue", showExport: "__js_show_ir_SSAValue" }, arg1, wasm)), wasm);
  },
});
