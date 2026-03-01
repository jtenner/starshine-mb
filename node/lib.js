import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function applyPrettyContext(arg0, arg1) {
  return liftValue({ kind: "string" }, wasm["lib__apply_pretty_context"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg1, wasm)), wasm);
}

export function arrayCompType(arg0) {
  return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__array_comp_type"](lowerValue({ kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, arg0, wasm)), wasm);
}

export const arrayOfArbitrary = unsupportedExport("lib.arrayOfArbitrary", "Generic exports are not available through the wasm-gc adapter.");

export function compTypeSubType(arg0) {
  return liftValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, wasm["lib__comp_type_sub_type"](lowerValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, arg0, wasm)), wasm);
}

export const equals = unsupportedExport("lib.equals", "Generic exports are not available through the wasm-gc adapter.");

export function expandLocals(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_11_is_ok","unwrapOk":"__js_result_11_unwrap_ok","unwrapErr":"__js_result_11_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, err: { kind: "string" } }, wasm["lib__expand_locals"](lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.Locals", showExport: "__js_show_lib_Locals" } }, arg0, wasm)), wasm);
}

export function funcCompType(arg0, arg1) {
  return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__func_comp_type"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function funcExternIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__func_extern_idx"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
}

export function funcExternType(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__func_extern_type"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
}

export function funcIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, wasm["lib__func_idx"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function getStructField(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_12_is_ok","unwrapOk":"__js_result_12_unwrap_ok","unwrapErr":"__js_result_12_unwrap_err"}, ok: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, err: { kind: "string" } }, wasm["lib__get_struct_field"](lowerValue({ kind: "array", helper: {"new":"__js_array_10_new","push":"__js_array_10_push","length":"__js_array_10_length","get":"__js_array_10_get"}, item: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" } }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm)), wasm);
}

export function globalExternIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__global_extern_idx"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm)), wasm);
}

export function globalExternType(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__global_extern_type"](lowerValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, arg0, wasm)), wasm);
}

export function globalIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, wasm["lib__global_idx"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function globalType(arg0, arg1) {
  return liftValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, wasm["lib__global_type"](lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm)), wasm);
}

export function groupRecType(arg0) {
  return liftValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, wasm["lib__group_rec_type"](lowerValue({ kind: "array", helper: {"new":"__js_array_11_new","push":"__js_array_11_push","length":"__js_array_11_length","get":"__js_array_11_get"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, arg0, wasm)), wasm);
}

export function hasDefault(arg0) {
  return liftValue({ kind: "bool" }, wasm["lib__has_default"](lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg0, wasm)), wasm);
}

export const inspectDebug = unsupportedExport("lib.inspectDebug", "Exports with `raise` effects are not available through the wasm-gc adapter.");

export const inspectPrettyPrint = unsupportedExport("lib.inspectPrettyPrint", "Generic exports are not available through the wasm-gc adapter.");

export function memExternIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__mem_extern_idx"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
}

export function memExternType(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__mem_extern_type"](lowerValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, arg0, wasm)), wasm);
}

export function memType(arg0) {
  return liftValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, wasm["lib__mem_type"](lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg0, wasm)), wasm);
}

export function minAddr(arg0, arg1) {
  return liftValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, wasm["lib__min_addr"](lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg1, wasm)), wasm);
}

export function minAddrValtype(arg0, arg1) {
  return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__min_addr_valtype"](lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg1, wasm)), wasm);
}

export function recIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, wasm["lib__rec_idx"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function resultType(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, wasm["lib__result_type"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm)), wasm);
}

export function singleRecType(arg0) {
  return liftValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, wasm["lib__single_rec_type"](lowerValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, arg0, wasm)), wasm);
}

export function structCompType(arg0) {
  return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__struct_comp_type"](lowerValue({ kind: "array", helper: {"new":"__js_array_10_new","push":"__js_array_10_push","length":"__js_array_10_length","get":"__js_array_10_get"}, item: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" } }, arg0, wasm)), wasm);
}

export function subType(arg0, arg1, arg2) {
  return liftValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, wasm["lib__sub_type"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, arg2, wasm)), wasm);
}

export function tableExternIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__table_extern_idx"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
}

export function tableExternType(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__table_extern_type"](lowerValue({ kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" }, arg0, wasm)), wasm);
}

export function tableIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, wasm["lib__table_idx"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
}

export function tagExternIdx(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__tag_extern_idx"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm)), wasm);
}

export function tagExternType(arg0) {
  return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__tag_extern_type"](lowerValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, arg0, wasm)), wasm);
}

export function tagType(arg0) {
  return liftValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, wasm["lib__tag_type"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
}

export function tlocalsToLocals(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.Locals", showExport: "__js_show_lib_Locals" } }, wasm["lib__tlocals_to_locals"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm)), wasm);
}

export const AbsHeapType = Object.freeze({
  any() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__any"](), wasm);
  },
  array() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__array"](), wasm);
  },
  eq() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__eq"](), wasm);
  },
  exn() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__exn"](), wasm);
  },
  extern() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__extern_"](), wasm);
  },
  func() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__func"](), wasm);
  },
  i31() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__i31"](), wasm);
  },
  noExn() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__no_exn"](), wasm);
  },
  noExtern() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__no_extern"](), wasm);
  },
  noFunc() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__no_func"](), wasm);
  },
  none() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__none"](), wasm);
  },
  struct() {
    return liftValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, wasm["lib__AbsHeapType__struct_"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_AbsHeapType"](value);
  },
});

export const AtomicCmpxchgOp = Object.freeze({
  i32() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i32"](), wasm);
  },
  i3216U() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i32_16_u"](), wasm);
  },
  i328U() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i32_8_u"](), wasm);
  },
  i64() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i64"](), wasm);
  },
  i6416U() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i64_16_u"](), wasm);
  },
  i6432U() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i64_32_u"](), wasm);
  },
  i648U() {
    return liftValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, wasm["lib__AtomicCmpxchgOp__i64_8_u"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_AtomicCmpxchgOp"](value);
  },
});

export const AtomicRmwOp = Object.freeze({
  i3216AddU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_16_add_u"](), wasm);
  },
  i3216AndU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_16_and_u"](), wasm);
  },
  i3216OrU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_16_or_u"](), wasm);
  },
  i3216SubU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_16_sub_u"](), wasm);
  },
  i3216XchgU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_16_xchg_u"](), wasm);
  },
  i3216XorU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_16_xor_u"](), wasm);
  },
  i328AddU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_8_add_u"](), wasm);
  },
  i328AndU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_8_and_u"](), wasm);
  },
  i328OrU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_8_or_u"](), wasm);
  },
  i328SubU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_8_sub_u"](), wasm);
  },
  i328XchgU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_8_xchg_u"](), wasm);
  },
  i328XorU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_8_xor_u"](), wasm);
  },
  i32Add() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_add"](), wasm);
  },
  i32And() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_and"](), wasm);
  },
  i32Or() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_or"](), wasm);
  },
  i32Sub() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_sub"](), wasm);
  },
  i32Xchg() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_xchg"](), wasm);
  },
  i32Xor() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i32_xor"](), wasm);
  },
  i6416AddU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_16_add_u"](), wasm);
  },
  i6416AndU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_16_and_u"](), wasm);
  },
  i6416OrU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_16_or_u"](), wasm);
  },
  i6416SubU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_16_sub_u"](), wasm);
  },
  i6416XchgU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_16_xchg_u"](), wasm);
  },
  i6416XorU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_16_xor_u"](), wasm);
  },
  i6432AddU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_32_add_u"](), wasm);
  },
  i6432AndU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_32_and_u"](), wasm);
  },
  i6432OrU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_32_or_u"](), wasm);
  },
  i6432SubU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_32_sub_u"](), wasm);
  },
  i6432XchgU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_32_xchg_u"](), wasm);
  },
  i6432XorU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_32_xor_u"](), wasm);
  },
  i648AddU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_8_add_u"](), wasm);
  },
  i648AndU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_8_and_u"](), wasm);
  },
  i648OrU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_8_or_u"](), wasm);
  },
  i648SubU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_8_sub_u"](), wasm);
  },
  i648XchgU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_8_xchg_u"](), wasm);
  },
  i648XorU() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_8_xor_u"](), wasm);
  },
  i64Add() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_add"](), wasm);
  },
  i64And() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_and"](), wasm);
  },
  i64Or() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_or"](), wasm);
  },
  i64Sub() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_sub"](), wasm);
  },
  i64Xchg() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_xchg"](), wasm);
  },
  i64Xor() {
    return liftValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, wasm["lib__AtomicRmwOp__i64_xor"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_AtomicRmwOp"](value);
  },
});

export const BinaryOp = Object.freeze({
  f32Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_add"](), wasm);
  },
  f32Copysign() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_copysign"](), wasm);
  },
  f32Div() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_div"](), wasm);
  },
  f32Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_eq"](), wasm);
  },
  f32Ge() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_ge"](), wasm);
  },
  f32Gt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_gt"](), wasm);
  },
  f32Le() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_le"](), wasm);
  },
  f32Lt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_lt"](), wasm);
  },
  f32Max() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_max"](), wasm);
  },
  f32Min() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_min"](), wasm);
  },
  f32Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_mul"](), wasm);
  },
  f32Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_ne"](), wasm);
  },
  f32Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32_sub"](), wasm);
  },
  f32x4Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_add"](), wasm);
  },
  f32x4Div() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_div"](), wasm);
  },
  f32x4Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_eq"](), wasm);
  },
  f32x4Ge() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_ge"](), wasm);
  },
  f32x4Gt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_gt"](), wasm);
  },
  f32x4Le() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_le"](), wasm);
  },
  f32x4Lt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_lt"](), wasm);
  },
  f32x4Max() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_max"](), wasm);
  },
  f32x4Min() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_min"](), wasm);
  },
  f32x4Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_mul"](), wasm);
  },
  f32x4Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_ne"](), wasm);
  },
  f32x4Pmax() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_pmax"](), wasm);
  },
  f32x4Pmin() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_pmin"](), wasm);
  },
  f32x4RelaxedMax() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_relaxed_max"](), wasm);
  },
  f32x4RelaxedMin() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_relaxed_min"](), wasm);
  },
  f32x4Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f32x4_sub"](), wasm);
  },
  f64Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_add"](), wasm);
  },
  f64Copysign() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_copysign"](), wasm);
  },
  f64Div() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_div"](), wasm);
  },
  f64Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_eq"](), wasm);
  },
  f64Ge() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_ge"](), wasm);
  },
  f64Gt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_gt"](), wasm);
  },
  f64Le() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_le"](), wasm);
  },
  f64Lt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_lt"](), wasm);
  },
  f64Max() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_max"](), wasm);
  },
  f64Min() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_min"](), wasm);
  },
  f64Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_mul"](), wasm);
  },
  f64Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_ne"](), wasm);
  },
  f64Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64_sub"](), wasm);
  },
  f64x2Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_add"](), wasm);
  },
  f64x2Div() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_div"](), wasm);
  },
  f64x2Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_eq"](), wasm);
  },
  f64x2Ge() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_ge"](), wasm);
  },
  f64x2Gt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_gt"](), wasm);
  },
  f64x2Le() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_le"](), wasm);
  },
  f64x2Lt() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_lt"](), wasm);
  },
  f64x2Max() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_max"](), wasm);
  },
  f64x2Min() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_min"](), wasm);
  },
  f64x2Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_mul"](), wasm);
  },
  f64x2Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_ne"](), wasm);
  },
  f64x2Pmax() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_pmax"](), wasm);
  },
  f64x2Pmin() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_pmin"](), wasm);
  },
  f64x2RelaxedMax() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_relaxed_max"](), wasm);
  },
  f64x2RelaxedMin() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_relaxed_min"](), wasm);
  },
  f64x2Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__f64x2_sub"](), wasm);
  },
  i16x8Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_add"](), wasm);
  },
  i16x8AddSatS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_add_sat_s"](), wasm);
  },
  i16x8AddSatU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_add_sat_u"](), wasm);
  },
  i16x8AvgrU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_avgr_u"](), wasm);
  },
  i16x8Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_eq"](), wasm);
  },
  i16x8ExtmulHighI8x16s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_extmul_high_i8x16s"](), wasm);
  },
  i16x8ExtmulHighI8x16u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_extmul_high_i8x16u"](), wasm);
  },
  i16x8ExtmulLowI8x16s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_extmul_low_i8x16s"](), wasm);
  },
  i16x8ExtmulLowI8x16u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_extmul_low_i8x16u"](), wasm);
  },
  i16x8GeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_ge_s"](), wasm);
  },
  i16x8GeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_ge_u"](), wasm);
  },
  i16x8GtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_gt_s"](), wasm);
  },
  i16x8GtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_gt_u"](), wasm);
  },
  i16x8LeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_le_s"](), wasm);
  },
  i16x8LeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_le_u"](), wasm);
  },
  i16x8LtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_lt_s"](), wasm);
  },
  i16x8LtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_lt_u"](), wasm);
  },
  i16x8MaxS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_max_s"](), wasm);
  },
  i16x8MaxU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_max_u"](), wasm);
  },
  i16x8MinS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_min_s"](), wasm);
  },
  i16x8MinU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_min_u"](), wasm);
  },
  i16x8Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_mul"](), wasm);
  },
  i16x8NarrowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_narrow_i32x4s"](), wasm);
  },
  i16x8NarrowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_narrow_i32x4u"](), wasm);
  },
  i16x8Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_ne"](), wasm);
  },
  i16x8RelaxedDotI8x16i7x16s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_relaxed_dot_i8x16i7x16s"](), wasm);
  },
  i16x8RelaxedQ15mulrS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_relaxed_q15mulr_s"](), wasm);
  },
  i16x8Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_sub"](), wasm);
  },
  i16x8SubSatS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_sub_sat_s"](), wasm);
  },
  i16x8SubSatU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8_sub_sat_u"](), wasm);
  },
  i16x8q15mulrSatS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i16x8q15mulr_sat_s"](), wasm);
  },
  i32Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_add"](), wasm);
  },
  i32And() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_and"](), wasm);
  },
  i32DivS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_div_s"](), wasm);
  },
  i32DivU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_div_u"](), wasm);
  },
  i32Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_eq"](), wasm);
  },
  i32GeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_ge_s"](), wasm);
  },
  i32GeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_ge_u"](), wasm);
  },
  i32GtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_gt_s"](), wasm);
  },
  i32GtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_gt_u"](), wasm);
  },
  i32LeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_le_s"](), wasm);
  },
  i32LeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_le_u"](), wasm);
  },
  i32LtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_lt_s"](), wasm);
  },
  i32LtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_lt_u"](), wasm);
  },
  i32Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_mul"](), wasm);
  },
  i32Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_ne"](), wasm);
  },
  i32Or() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_or"](), wasm);
  },
  i32RemS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_rem_s"](), wasm);
  },
  i32RemU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_rem_u"](), wasm);
  },
  i32Rotl() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_rotl"](), wasm);
  },
  i32Rotr() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_rotr"](), wasm);
  },
  i32Shl() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_shl"](), wasm);
  },
  i32ShrS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_shr_s"](), wasm);
  },
  i32ShrU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_shr_u"](), wasm);
  },
  i32Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_sub"](), wasm);
  },
  i32Xor() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32_xor"](), wasm);
  },
  i32x4Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_add"](), wasm);
  },
  i32x4DotI16x8s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_dot_i16x8s"](), wasm);
  },
  i32x4Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_eq"](), wasm);
  },
  i32x4ExtmulHighI16x8s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_extmul_high_i16x8s"](), wasm);
  },
  i32x4ExtmulHighI16x8u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_extmul_high_i16x8u"](), wasm);
  },
  i32x4ExtmulLowI16x8s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_extmul_low_i16x8s"](), wasm);
  },
  i32x4ExtmulLowI16x8u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_extmul_low_i16x8u"](), wasm);
  },
  i32x4GeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_ge_s"](), wasm);
  },
  i32x4GeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_ge_u"](), wasm);
  },
  i32x4GtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_gt_s"](), wasm);
  },
  i32x4GtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_gt_u"](), wasm);
  },
  i32x4LeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_le_s"](), wasm);
  },
  i32x4LeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_le_u"](), wasm);
  },
  i32x4LtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_lt_s"](), wasm);
  },
  i32x4LtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_lt_u"](), wasm);
  },
  i32x4MaxS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_max_s"](), wasm);
  },
  i32x4MaxU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_max_u"](), wasm);
  },
  i32x4MinS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_min_s"](), wasm);
  },
  i32x4MinU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_min_u"](), wasm);
  },
  i32x4Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_mul"](), wasm);
  },
  i32x4Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_ne"](), wasm);
  },
  i32x4Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i32x4_sub"](), wasm);
  },
  i64Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_add"](), wasm);
  },
  i64And() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_and"](), wasm);
  },
  i64DivS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_div_s"](), wasm);
  },
  i64DivU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_div_u"](), wasm);
  },
  i64Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_eq"](), wasm);
  },
  i64GeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_ge_s"](), wasm);
  },
  i64GeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_ge_u"](), wasm);
  },
  i64GtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_gt_s"](), wasm);
  },
  i64GtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_gt_u"](), wasm);
  },
  i64LeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_le_s"](), wasm);
  },
  i64LeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_le_u"](), wasm);
  },
  i64LtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_lt_s"](), wasm);
  },
  i64LtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_lt_u"](), wasm);
  },
  i64Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_mul"](), wasm);
  },
  i64Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_ne"](), wasm);
  },
  i64Or() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_or"](), wasm);
  },
  i64RemS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_rem_s"](), wasm);
  },
  i64RemU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_rem_u"](), wasm);
  },
  i64Rotl() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_rotl"](), wasm);
  },
  i64Rotr() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_rotr"](), wasm);
  },
  i64Shl() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_shl"](), wasm);
  },
  i64ShrS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_shr_s"](), wasm);
  },
  i64ShrU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_shr_u"](), wasm);
  },
  i64Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_sub"](), wasm);
  },
  i64Xor() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64_xor"](), wasm);
  },
  i64x2Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_add"](), wasm);
  },
  i64x2Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_eq"](), wasm);
  },
  i64x2ExtmulHighI32x4s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_extmul_high_i32x4s"](), wasm);
  },
  i64x2ExtmulHighI32x4u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_extmul_high_i32x4u"](), wasm);
  },
  i64x2ExtmulLowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_extmul_low_i32x4s"](), wasm);
  },
  i64x2ExtmulLowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_extmul_low_i32x4u"](), wasm);
  },
  i64x2GeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_ge_s"](), wasm);
  },
  i64x2GtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_gt_s"](), wasm);
  },
  i64x2LeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_le_s"](), wasm);
  },
  i64x2LtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_lt_s"](), wasm);
  },
  i64x2Mul() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_mul"](), wasm);
  },
  i64x2Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_ne"](), wasm);
  },
  i64x2Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i64x2_sub"](), wasm);
  },
  i8x16Add() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_add"](), wasm);
  },
  i8x16AddSatS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_add_sat_s"](), wasm);
  },
  i8x16AddSatU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_add_sat_u"](), wasm);
  },
  i8x16AvgrU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_avgr_u"](), wasm);
  },
  i8x16Eq() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_eq"](), wasm);
  },
  i8x16GeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_ge_s"](), wasm);
  },
  i8x16GeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_ge_u"](), wasm);
  },
  i8x16GtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_gt_s"](), wasm);
  },
  i8x16GtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_gt_u"](), wasm);
  },
  i8x16LeS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_le_s"](), wasm);
  },
  i8x16LeU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_le_u"](), wasm);
  },
  i8x16LtS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_lt_s"](), wasm);
  },
  i8x16LtU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_lt_u"](), wasm);
  },
  i8x16MaxS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_max_s"](), wasm);
  },
  i8x16MaxU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_max_u"](), wasm);
  },
  i8x16MinS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_min_s"](), wasm);
  },
  i8x16MinU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_min_u"](), wasm);
  },
  i8x16NarrowI16x8s() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_narrow_i16x8s"](), wasm);
  },
  i8x16NarrowI16x8u() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_narrow_i16x8u"](), wasm);
  },
  i8x16Ne() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_ne"](), wasm);
  },
  i8x16Sub() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_sub"](), wasm);
  },
  i8x16SubSatS() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_sub_sat_s"](), wasm);
  },
  i8x16SubSatU() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__i8x16_sub_sat_u"](), wasm);
  },
  v128And() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__v128_and"](), wasm);
  },
  v128Andnot() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__v128_andnot"](), wasm);
  },
  v128Or() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__v128_or"](), wasm);
  },
  v128Xor() {
    return liftValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, wasm["lib__BinaryOp__v128_xor"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_BinaryOp"](value);
  },
});

export const BlockType = Object.freeze({
  typeIdx(arg0) {
    return liftValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, wasm["lib__BlockType__type_idx"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  valType(arg0) {
    return liftValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, wasm["lib__BlockType__val_type"](lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg0, wasm)), wasm);
  },
  void() {
    return liftValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, wasm["lib__BlockType__void_"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_BlockType"](value);
  },
});

export const CastOp = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.CastOp", showExport: "__js_show_lib_CastOp" }, wasm["lib__CastOp__new"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm)), wasm);
  },
  sourceNullable(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__CastOp__source_nullable"](lowerValue({ kind: "named", brand: "lib.CastOp", showExport: "__js_show_lib_CastOp" }, arg0, wasm)), wasm);
  },
  targetNullable(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__CastOp__target_nullable"](lowerValue({ kind: "named", brand: "lib.CastOp", showExport: "__js_show_lib_CastOp" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_CastOp"](value);
  },
});

export const Catch = Object.freeze({
  all(arg0) {
    return liftValue({ kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" }, wasm["lib__Catch__all"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  allRef(arg0) {
    return liftValue({ kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" }, wasm["lib__Catch__all_ref"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" }, wasm["lib__Catch__new"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  ref(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" }, wasm["lib__Catch__ref_"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Catch"](value);
  },
});

export const CodeSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_13_new","push":"__js_array_13_push","length":"__js_array_13_length","get":"__js_array_13_get"}, item: { kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" } }, wasm["lib__CodeSec__inner"](lowerValue({ kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" }, wasm["lib__CodeSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_13_new","push":"__js_array_13_push","length":"__js_array_13_length","get":"__js_array_13_get"}, item: { kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_CodeSec"](value);
  },
});

export const CompType = Object.freeze({
  array(arg0) {
    return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__CompType__array"](lowerValue({ kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, arg0, wasm)), wasm);
  },
  func(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__CompType__func"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  struct(arg0) {
    return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__CompType__struct_"](lowerValue({ kind: "array", helper: {"new":"__js_array_10_new","push":"__js_array_10_push","length":"__js_array_10_length","get":"__js_array_10_get"}, item: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_CompType"](value);
  },
});

export const CustomSec = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" }, wasm["lib__CustomSec__new"](lowerValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, arg0, wasm), lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_CustomSec"](value);
  },
});

export const Data = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Data", showExport: "__js_show_lib_Data" }, wasm["lib__Data__new"](lowerValue({ kind: "named", brand: "lib.DataMode", showExport: "__js_show_lib_DataMode" }, arg0, wasm), lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Data"](value);
  },
});

export const DataCntSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, wasm["lib__DataCntSec__inner"](lowerValue({ kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" }, wasm["lib__DataCntSec__new"](lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_DataCntSec"](value);
  },
});

export const DataIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__DataIdx__inner"](lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, wasm["lib__DataIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_DataIdx"](value);
  },
});

export const DataMode = Object.freeze({
  active(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.DataMode", showExport: "__js_show_lib_DataMode" }, wasm["lib__DataMode__active"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg1, wasm)), wasm);
  },
  passive() {
    return liftValue({ kind: "named", brand: "lib.DataMode", showExport: "__js_show_lib_DataMode" }, wasm["lib__DataMode__passive"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_DataMode"](value);
  },
});

export const DataSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_14_new","push":"__js_array_14_push","length":"__js_array_14_length","get":"__js_array_14_get"}, item: { kind: "named", brand: "lib.Data", showExport: "__js_show_lib_Data" } }, wasm["lib__DataSec__inner"](lowerValue({ kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" }, wasm["lib__DataSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_14_new","push":"__js_array_14_push","length":"__js_array_14_length","get":"__js_array_14_get"}, item: { kind: "named", brand: "lib.Data", showExport: "__js_show_lib_Data" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_DataSec"](value);
  },
});

export const DefType = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.DefType", showExport: "__js_show_lib_DefType" }, wasm["lib__DefType__new"](lowerValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
  },
  project(arg0) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["lib__DefType__project"](lowerValue({ kind: "named", brand: "lib.DefType", showExport: "__js_show_lib_DefType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_DefType"](value);
  },
});

export const Elem = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" }, wasm["lib__Elem__new"](lowerValue({ kind: "named", brand: "lib.ElemMode", showExport: "__js_show_lib_ElemMode" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemKind", showExport: "__js_show_lib_ElemKind" }, arg1, wasm)), wasm);
  },
  reftype(arg0) {
    return liftValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, wasm["lib__Elem__reftype"](lowerValue({ kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Elem"](value);
  },
});

export const ElemIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__ElemIdx__inner"](lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, wasm["lib__ElemIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ElemIdx"](value);
  },
});

export const ElemKind = Object.freeze({
  funcExprs(arg0) {
    return liftValue({ kind: "named", brand: "lib.ElemKind", showExport: "__js_show_lib_ElemKind" }, wasm["lib__ElemKind__func_exprs"](lowerValue({ kind: "array", helper: {"new":"__js_array_15_new","push":"__js_array_15_push","length":"__js_array_15_length","get":"__js_array_15_get"}, item: { kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" } }, arg0, wasm)), wasm);
  },
  funcs(arg0) {
    return liftValue({ kind: "named", brand: "lib.ElemKind", showExport: "__js_show_lib_ElemKind" }, wasm["lib__ElemKind__funcs"](lowerValue({ kind: "array", helper: {"new":"__js_array_16_new","push":"__js_array_16_push","length":"__js_array_16_length","get":"__js_array_16_get"}, item: { kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" } }, arg0, wasm)), wasm);
  },
  typedExprs(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.ElemKind", showExport: "__js_show_lib_ElemKind" }, wasm["lib__ElemKind__typed_exprs"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_15_new","push":"__js_array_15_push","length":"__js_array_15_length","get":"__js_array_15_get"}, item: { kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" } }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ElemKind"](value);
  },
});

export const ElemMode = Object.freeze({
  active(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.ElemMode", showExport: "__js_show_lib_ElemMode" }, wasm["lib__ElemMode__active"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg1, wasm)), wasm);
  },
  declarative() {
    return liftValue({ kind: "named", brand: "lib.ElemMode", showExport: "__js_show_lib_ElemMode" }, wasm["lib__ElemMode__declarative"](), wasm);
  },
  passive() {
    return liftValue({ kind: "named", brand: "lib.ElemMode", showExport: "__js_show_lib_ElemMode" }, wasm["lib__ElemMode__passive"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ElemMode"](value);
  },
});

export const ElemSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_17_new","push":"__js_array_17_push","length":"__js_array_17_length","get":"__js_array_17_get"}, item: { kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" } }, wasm["lib__ElemSec__inner"](lowerValue({ kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" }, wasm["lib__ElemSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_17_new","push":"__js_array_17_push","length":"__js_array_17_length","get":"__js_array_17_get"}, item: { kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ElemSec"](value);
  },
});

export const Export = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Export", showExport: "__js_show_lib_Export" }, wasm["lib__Export__new"](lowerValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Export"](value);
  },
});

export const ExportSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_18_new","push":"__js_array_18_push","length":"__js_array_18_length","get":"__js_array_18_get"}, item: { kind: "named", brand: "lib.Export", showExport: "__js_show_lib_Export" } }, wasm["lib__ExportSec__inner"](lowerValue({ kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" }, wasm["lib__ExportSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_18_new","push":"__js_array_18_push","length":"__js_array_18_length","get":"__js_array_18_get"}, item: { kind: "named", brand: "lib.Export", showExport: "__js_show_lib_Export" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ExportSec"](value);
  },
});

export const Expr = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_19_new","push":"__js_array_19_push","length":"__js_array_19_length","get":"__js_array_19_get"}, item: { kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" } }, wasm["lib__Expr__inner"](lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, wasm["lib__Expr__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_19_new","push":"__js_array_19_push","length":"__js_array_19_length","get":"__js_array_19_get"}, item: { kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Expr"](value);
  },
});

export const ExternIdx = Object.freeze({
  func(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__ExternIdx__func"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  global(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__ExternIdx__global"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm)), wasm);
  },
  mem(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__ExternIdx__mem"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
  },
  table(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__ExternIdx__table"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  tag(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternIdx", showExport: "__js_show_lib_ExternIdx" }, wasm["lib__ExternIdx__tag"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ExternIdx"](value);
  },
});

export const ExternType = Object.freeze({
  func(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__ExternType__func"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  global(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__ExternType__global"](lowerValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, arg0, wasm)), wasm);
  },
  mem(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__ExternType__mem"](lowerValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, arg0, wasm)), wasm);
  },
  table(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__ExternType__table"](lowerValue({ kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" }, arg0, wasm)), wasm);
  },
  tag(arg0) {
    return liftValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, wasm["lib__ExternType__tag"](lowerValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ExternType"](value);
  },
});

export const ExtractLaneOp = Object.freeze({
  f32x4ExtractLane() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__f32x4_extract_lane"](), wasm);
  },
  f64x2ExtractLane() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__f64x2_extract_lane"](), wasm);
  },
  i16x8ExtractLaneS() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__i16x8_extract_lane_s"](), wasm);
  },
  i16x8ExtractLaneU() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__i16x8_extract_lane_u"](), wasm);
  },
  i32x4ExtractLane() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__i32x4_extract_lane"](), wasm);
  },
  i64x2ExtractLane() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__i64x2_extract_lane"](), wasm);
  },
  i8x16ExtractLaneS() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__i8x16_extract_lane_s"](), wasm);
  },
  i8x16ExtractLaneU() {
    return liftValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, wasm["lib__ExtractLaneOp__i8x16_extract_lane_u"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ExtractLaneOp"](value);
  },
});

export const F32 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__F32__inner"](lowerValue({ kind: "named", brand: "lib.F32", showExport: "__js_show_lib_F32" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.F32", showExport: "__js_show_lib_F32" }, wasm["lib__F32__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_F32"](value);
  },
});

export const F64 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__F64__inner"](lowerValue({ kind: "named", brand: "lib.F64", showExport: "__js_show_lib_F64" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.F64", showExport: "__js_show_lib_F64" }, wasm["lib__F64__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_F64"](value);
  },
});

export const FieldType = Object.freeze({
  getStorageType(arg0) {
    return liftValue({ kind: "named", brand: "lib.StorageType", showExport: "__js_show_lib_StorageType" }, wasm["lib__FieldType__get_storage_type"](lowerValue({ kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, arg0, wasm)), wasm);
  },
  isMutable(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__FieldType__is_mutable"](lowerValue({ kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, arg0, wasm)), wasm);
  },
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, wasm["lib__FieldType__new"](lowerValue({ kind: "named", brand: "lib.StorageType", showExport: "__js_show_lib_StorageType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Mut", showExport: "__js_show_lib_Mut" }, arg1, wasm)), wasm);
  },
  unpack(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__FieldType__unpack"](lowerValue({ kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_FieldType"](value);
  },
});

export const Func = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" }, wasm["lib__Func__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.Locals", showExport: "__js_show_lib_Locals" } }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg1, wasm)), wasm);
  },
  tFunc(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" }, wasm["lib__Func__t_func"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Func"](value);
  },
});

export const FuncIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__FuncIdx__inner"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, wasm["lib__FuncIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_FuncIdx"](value);
  },
});

export const FuncSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, wasm["lib__FuncSec__inner"](lowerValue({ kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" }, wasm["lib__FuncSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_FuncSec"](value);
  },
});

export const FuncType = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" }, wasm["lib__FuncType__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_FuncType"](value);
  },
});

export const Global = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Global", showExport: "__js_show_lib_Global" }, wasm["lib__Global__new"](lowerValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Global"](value);
  },
});

export const GlobalIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__GlobalIdx__inner"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, wasm["lib__GlobalIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_GlobalIdx"](value);
  },
});

export const GlobalSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_20_new","push":"__js_array_20_push","length":"__js_array_20_length","get":"__js_array_20_get"}, item: { kind: "named", brand: "lib.Global", showExport: "__js_show_lib_Global" } }, wasm["lib__GlobalSec__inner"](lowerValue({ kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" }, wasm["lib__GlobalSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_20_new","push":"__js_array_20_push","length":"__js_array_20_length","get":"__js_array_20_get"}, item: { kind: "named", brand: "lib.Global", showExport: "__js_show_lib_Global" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_GlobalSec"](value);
  },
});

export const GlobalType = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, wasm["lib__GlobalType__new"](lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_GlobalType"](value);
  },
});

export const HashResult = Object.freeze({
});

export const HeapType = Object.freeze({
  abs(arg0) {
    return liftValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, wasm["lib__HeapType__abs"](lowerValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, arg0, wasm)), wasm);
  },
  bottom() {
    return liftValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, wasm["lib__HeapType__bottom"](), wasm);
  },
  defType(arg0) {
    return liftValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, wasm["lib__HeapType__def_type"](lowerValue({ kind: "named", brand: "lib.DefType", showExport: "__js_show_lib_DefType" }, arg0, wasm)), wasm);
  },
  isArray(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__HeapType__is_array"](lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg0, wasm)), wasm);
  },
  isGcAggregate(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__HeapType__is_gc_aggregate"](lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg0, wasm)), wasm);
  },
  isStruct(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__HeapType__is_struct"](lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, wasm["lib__HeapType__new"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_HeapType"](value);
  },
});

export const I32 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__I32__inner"](lowerValue({ kind: "named", brand: "lib.I32", showExport: "__js_show_lib_I32" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.I32", showExport: "__js_show_lib_I32" }, wasm["lib__I32__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_I32"](value);
  },
});

export const I64 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "bigint" }, wasm["lib__I64__inner"](lowerValue({ kind: "named", brand: "lib.I64", showExport: "__js_show_lib_I64" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.I64", showExport: "__js_show_lib_I64" }, wasm["lib__I64__new"](lowerValue({ kind: "bigint" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_I64"](value);
  },
});

export const Import = Object.freeze({
  new(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.Import", showExport: "__js_show_lib_Import" }, wasm["lib__Import__new"](lowerValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.ExternType", showExport: "__js_show_lib_ExternType" }, arg2, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Import"](value);
  },
});

export const ImportSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_21_new","push":"__js_array_21_push","length":"__js_array_21_length","get":"__js_array_21_get"}, item: { kind: "named", brand: "lib.Import", showExport: "__js_show_lib_Import" } }, wasm["lib__ImportSec__inner"](lowerValue({ kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" }, wasm["lib__ImportSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_21_new","push":"__js_array_21_push","length":"__js_array_21_length","get":"__js_array_21_get"}, item: { kind: "named", brand: "lib.Import", showExport: "__js_show_lib_Import" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ImportSec"](value);
  },
});

export const Instruction = Object.freeze({
  anyConvertExtern() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__any_convert_extern"](), wasm);
  },
  arrayCopy(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_copy"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  arrayFill(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_fill"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  arrayGet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_get"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  arrayGetS(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_get_s"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  arrayGetU(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_get_u"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  arrayInitData(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_init_data"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg1, wasm)), wasm);
  },
  arrayInitElem(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_init_elem"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg1, wasm)), wasm);
  },
  arrayLen() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_len"](), wasm);
  },
  arrayNew(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_new"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  arrayNewData(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_new_data"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg1, wasm)), wasm);
  },
  arrayNewDefault(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_new_default"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  arrayNewElem(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_new_elem"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg1, wasm)), wasm);
  },
  arrayNewFixed(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_new_fixed"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm)), wasm);
  },
  arraySet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__array_set"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  atomicCmpxchg(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__atomic_cmpxchg"](lowerValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm)), wasm);
  },
  atomicFence() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__atomic_fence"](), wasm);
  },
  atomicRmw(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__atomic_rmw"](lowerValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm)), wasm);
  },
  block(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__block"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg1, wasm)), wasm);
  },
  br(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  brIf(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br_if"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  brOnCast(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br_on_cast"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg2, wasm), lowerValue({ kind: "bool" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg4, wasm)), wasm);
  },
  brOnCastFail(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br_on_cast_fail"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg2, wasm), lowerValue({ kind: "bool" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg4, wasm)), wasm);
  },
  brOnNonNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br_on_non_null"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  brOnNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br_on_null"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  brTable(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__br_table"](lowerValue({ kind: "array", helper: {"new":"__js_array_22_new","push":"__js_array_22_push","length":"__js_array_22_length","get":"__js_array_22_get"}, item: { kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" } }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  call(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__call"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  callIndirect(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__call_indirect"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm)), wasm);
  },
  callRef(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__call_ref"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  dataDrop(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__data_drop"](lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg0, wasm)), wasm);
  },
  drop() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__drop"](), wasm);
  },
  elemDrop(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__elem_drop"](lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg0, wasm)), wasm);
  },
  externConvertAny() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__extern_convert_any"](), wasm);
  },
  f32Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_abs"](), wasm);
  },
  f32Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_add"](), wasm);
  },
  f32Ceil() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_ceil"](), wasm);
  },
  f32Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_const"](lowerValue({ kind: "named", brand: "lib.F32", showExport: "__js_show_lib_F32" }, arg0, wasm)), wasm);
  },
  f32ConvertI32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_convert_i32s"](), wasm);
  },
  f32ConvertI32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_convert_i32u"](), wasm);
  },
  f32ConvertI64s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_convert_i64s"](), wasm);
  },
  f32ConvertI64u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_convert_i64u"](), wasm);
  },
  f32Copysign() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_copysign"](), wasm);
  },
  f32DemoteF64() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_demote_f64"](), wasm);
  },
  f32Div() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_div"](), wasm);
  },
  f32Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_eq"](), wasm);
  },
  f32Floor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_floor"](), wasm);
  },
  f32Ge() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_ge"](), wasm);
  },
  f32Gt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_gt"](), wasm);
  },
  f32Le() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_le"](), wasm);
  },
  f32Load(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  f32Lt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_lt"](), wasm);
  },
  f32Max() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_max"](), wasm);
  },
  f32Min() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_min"](), wasm);
  },
  f32Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_mul"](), wasm);
  },
  f32Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_ne"](), wasm);
  },
  f32Nearest() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_nearest"](), wasm);
  },
  f32Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_neg"](), wasm);
  },
  f32ReinterpretI32() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_reinterpret_i32"](), wasm);
  },
  f32Sqrt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_sqrt"](), wasm);
  },
  f32Store(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  f32Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_sub"](), wasm);
  },
  f32Trunc() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32_trunc"](), wasm);
  },
  f32x4Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_abs"](), wasm);
  },
  f32x4Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_add"](), wasm);
  },
  f32x4Ceil() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_ceil"](), wasm);
  },
  f32x4ConvertI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_convert_i32x4s"](), wasm);
  },
  f32x4ConvertI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_convert_i32x4u"](), wasm);
  },
  f32x4DemoteF64x2Zero() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_demote_f64x2_zero"](), wasm);
  },
  f32x4Div() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_div"](), wasm);
  },
  f32x4Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_eq"](), wasm);
  },
  f32x4ExtractLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_extract_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  f32x4Floor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_floor"](), wasm);
  },
  f32x4Ge() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_ge"](), wasm);
  },
  f32x4Gt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_gt"](), wasm);
  },
  f32x4Le() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_le"](), wasm);
  },
  f32x4Lt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_lt"](), wasm);
  },
  f32x4Max() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_max"](), wasm);
  },
  f32x4Min() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_min"](), wasm);
  },
  f32x4Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_mul"](), wasm);
  },
  f32x4Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_ne"](), wasm);
  },
  f32x4Nearest() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_nearest"](), wasm);
  },
  f32x4Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_neg"](), wasm);
  },
  f32x4Pmax() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_pmax"](), wasm);
  },
  f32x4Pmin() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_pmin"](), wasm);
  },
  f32x4RelaxedMadd() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_relaxed_madd"](), wasm);
  },
  f32x4RelaxedMax() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_relaxed_max"](), wasm);
  },
  f32x4RelaxedMin() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_relaxed_min"](), wasm);
  },
  f32x4RelaxedNmadd() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_relaxed_nmadd"](), wasm);
  },
  f32x4ReplaceLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_replace_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  f32x4Splat() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_splat"](), wasm);
  },
  f32x4Sqrt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_sqrt"](), wasm);
  },
  f32x4Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_sub"](), wasm);
  },
  f32x4Trunc() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f32x4_trunc"](), wasm);
  },
  f64Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_abs"](), wasm);
  },
  f64Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_add"](), wasm);
  },
  f64Ceil() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_ceil"](), wasm);
  },
  f64Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_const"](lowerValue({ kind: "named", brand: "lib.F64", showExport: "__js_show_lib_F64" }, arg0, wasm)), wasm);
  },
  f64ConvertI32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_convert_i32s"](), wasm);
  },
  f64ConvertI32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_convert_i32u"](), wasm);
  },
  f64ConvertI64s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_convert_i64s"](), wasm);
  },
  f64ConvertI64u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_convert_i64u"](), wasm);
  },
  f64Copysign() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_copysign"](), wasm);
  },
  f64Div() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_div"](), wasm);
  },
  f64Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_eq"](), wasm);
  },
  f64Floor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_floor"](), wasm);
  },
  f64Ge() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_ge"](), wasm);
  },
  f64Gt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_gt"](), wasm);
  },
  f64Le() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_le"](), wasm);
  },
  f64Load(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  f64Lt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_lt"](), wasm);
  },
  f64Max() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_max"](), wasm);
  },
  f64Min() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_min"](), wasm);
  },
  f64Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_mul"](), wasm);
  },
  f64Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_ne"](), wasm);
  },
  f64Nearest() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_nearest"](), wasm);
  },
  f64Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_neg"](), wasm);
  },
  f64PromoteF32() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_promote_f32"](), wasm);
  },
  f64ReinterpretI64() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_reinterpret_i64"](), wasm);
  },
  f64Sqrt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_sqrt"](), wasm);
  },
  f64Store(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  f64Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_sub"](), wasm);
  },
  f64Trunc() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64_trunc"](), wasm);
  },
  f64x2Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_abs"](), wasm);
  },
  f64x2Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_add"](), wasm);
  },
  f64x2Ceil() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_ceil"](), wasm);
  },
  f64x2ConvertLowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_convert_low_i32x4s"](), wasm);
  },
  f64x2ConvertLowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_convert_low_i32x4u"](), wasm);
  },
  f64x2Div() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_div"](), wasm);
  },
  f64x2Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_eq"](), wasm);
  },
  f64x2ExtractLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_extract_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  f64x2Floor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_floor"](), wasm);
  },
  f64x2Ge() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_ge"](), wasm);
  },
  f64x2Gt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_gt"](), wasm);
  },
  f64x2Le() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_le"](), wasm);
  },
  f64x2Lt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_lt"](), wasm);
  },
  f64x2Max() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_max"](), wasm);
  },
  f64x2Min() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_min"](), wasm);
  },
  f64x2Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_mul"](), wasm);
  },
  f64x2Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_ne"](), wasm);
  },
  f64x2Nearest() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_nearest"](), wasm);
  },
  f64x2Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_neg"](), wasm);
  },
  f64x2Pmax() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_pmax"](), wasm);
  },
  f64x2Pmin() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_pmin"](), wasm);
  },
  f64x2PromoteLowF32x4() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_promote_low_f32x4"](), wasm);
  },
  f64x2RelaxedMadd() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_relaxed_madd"](), wasm);
  },
  f64x2RelaxedMax() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_relaxed_max"](), wasm);
  },
  f64x2RelaxedMin() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_relaxed_min"](), wasm);
  },
  f64x2RelaxedNmadd() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_relaxed_nmadd"](), wasm);
  },
  f64x2ReplaceLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_replace_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  f64x2Splat() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_splat"](), wasm);
  },
  f64x2Sqrt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_sqrt"](), wasm);
  },
  f64x2Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_sub"](), wasm);
  },
  f64x2Trunc() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__f64x2_trunc"](), wasm);
  },
  globalGet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__global_get"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm)), wasm);
  },
  globalSet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__global_set"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm)), wasm);
  },
  i16x8Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_abs"](), wasm);
  },
  i16x8Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_add"](), wasm);
  },
  i16x8AddSatS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_add_sat_s"](), wasm);
  },
  i16x8AddSatU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_add_sat_u"](), wasm);
  },
  i16x8AllTrue() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_all_true"](), wasm);
  },
  i16x8AvgrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_avgr_u"](), wasm);
  },
  i16x8Bitmask() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_bitmask"](), wasm);
  },
  i16x8Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_eq"](), wasm);
  },
  i16x8ExtaddPairwiseI8x16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extadd_pairwise_i8x16s"](), wasm);
  },
  i16x8ExtaddPairwiseI8x16u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extadd_pairwise_i8x16u"](), wasm);
  },
  i16x8ExtendHighI8x16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extend_high_i8x16s"](), wasm);
  },
  i16x8ExtendHighI8x16u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extend_high_i8x16u"](), wasm);
  },
  i16x8ExtendLowI8x16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extend_low_i8x16s"](), wasm);
  },
  i16x8ExtendLowI8x16u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extend_low_i8x16u"](), wasm);
  },
  i16x8ExtmulHighI8x16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extmul_high_i8x16s"](), wasm);
  },
  i16x8ExtmulHighI8x16u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extmul_high_i8x16u"](), wasm);
  },
  i16x8ExtmulLowI8x16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extmul_low_i8x16s"](), wasm);
  },
  i16x8ExtmulLowI8x16u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extmul_low_i8x16u"](), wasm);
  },
  i16x8ExtractLaneS(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extract_lane_s"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i16x8ExtractLaneU(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_extract_lane_u"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i16x8GeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_ge_s"](), wasm);
  },
  i16x8GeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_ge_u"](), wasm);
  },
  i16x8GtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_gt_s"](), wasm);
  },
  i16x8GtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_gt_u"](), wasm);
  },
  i16x8LeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_le_s"](), wasm);
  },
  i16x8LeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_le_u"](), wasm);
  },
  i16x8LtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_lt_s"](), wasm);
  },
  i16x8LtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_lt_u"](), wasm);
  },
  i16x8MaxS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_max_s"](), wasm);
  },
  i16x8MaxU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_max_u"](), wasm);
  },
  i16x8MinS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_min_s"](), wasm);
  },
  i16x8MinU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_min_u"](), wasm);
  },
  i16x8Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_mul"](), wasm);
  },
  i16x8NarrowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_narrow_i32x4s"](), wasm);
  },
  i16x8NarrowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_narrow_i32x4u"](), wasm);
  },
  i16x8Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_ne"](), wasm);
  },
  i16x8Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_neg"](), wasm);
  },
  i16x8RelaxedDotI8x16i7x16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_relaxed_dot_i8x16i7x16s"](), wasm);
  },
  i16x8RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_relaxed_laneselect"](), wasm);
  },
  i16x8RelaxedQ15mulrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_relaxed_q15mulr_s"](), wasm);
  },
  i16x8ReplaceLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_replace_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i16x8Shl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_shl"](), wasm);
  },
  i16x8ShrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_shr_s"](), wasm);
  },
  i16x8ShrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_shr_u"](), wasm);
  },
  i16x8Splat() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_splat"](), wasm);
  },
  i16x8Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_sub"](), wasm);
  },
  i16x8SubSatS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_sub_sat_s"](), wasm);
  },
  i16x8SubSatU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8_sub_sat_u"](), wasm);
  },
  i16x8q15mulrSatS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i16x8q15mulr_sat_s"](), wasm);
  },
  i31GetS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i31_get_s"](), wasm);
  },
  i31GetU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i31_get_u"](), wasm);
  },
  i32Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_add"](), wasm);
  },
  i32And() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_and"](), wasm);
  },
  i32AtomicLoad(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_atomic_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32AtomicLoad16U(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_atomic_load16_u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32AtomicLoad8U(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_atomic_load8_u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32AtomicStore(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_atomic_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32AtomicStore16(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_atomic_store16"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32AtomicStore8(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_atomic_store8"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Clz() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_clz"](), wasm);
  },
  i32Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_const"](lowerValue({ kind: "named", brand: "lib.I32", showExport: "__js_show_lib_I32" }, arg0, wasm)), wasm);
  },
  i32Ctz() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_ctz"](), wasm);
  },
  i32DivS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_div_s"](), wasm);
  },
  i32DivU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_div_u"](), wasm);
  },
  i32Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_eq"](), wasm);
  },
  i32Eqz() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_eqz"](), wasm);
  },
  i32Extend16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_extend16s"](), wasm);
  },
  i32Extend8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_extend8s"](), wasm);
  },
  i32GeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_ge_s"](), wasm);
  },
  i32GeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_ge_u"](), wasm);
  },
  i32GtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_gt_s"](), wasm);
  },
  i32GtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_gt_u"](), wasm);
  },
  i32LeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_le_s"](), wasm);
  },
  i32LeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_le_u"](), wasm);
  },
  i32Load(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Load16s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_load16s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Load16u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_load16u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Load8s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_load8s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Load8u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_load8u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32LtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_lt_s"](), wasm);
  },
  i32LtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_lt_u"](), wasm);
  },
  i32Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_mul"](), wasm);
  },
  i32Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_ne"](), wasm);
  },
  i32Or() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_or"](), wasm);
  },
  i32Popcnt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_popcnt"](), wasm);
  },
  i32ReinterpretF32() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_reinterpret_f32"](), wasm);
  },
  i32RemS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_rem_s"](), wasm);
  },
  i32RemU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_rem_u"](), wasm);
  },
  i32Rotl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_rotl"](), wasm);
  },
  i32Rotr() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_rotr"](), wasm);
  },
  i32Shl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_shl"](), wasm);
  },
  i32ShrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_shr_s"](), wasm);
  },
  i32ShrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_shr_u"](), wasm);
  },
  i32Store(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Store16(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_store16"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Store8(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_store8"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i32Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_sub"](), wasm);
  },
  i32TruncF32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_f32s"](), wasm);
  },
  i32TruncF32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_f32u"](), wasm);
  },
  i32TruncF64s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_f64s"](), wasm);
  },
  i32TruncF64u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_f64u"](), wasm);
  },
  i32TruncSatF32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_sat_f32s"](), wasm);
  },
  i32TruncSatF32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_sat_f32u"](), wasm);
  },
  i32TruncSatF64s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_sat_f64s"](), wasm);
  },
  i32TruncSatF64u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_trunc_sat_f64u"](), wasm);
  },
  i32WrapI64() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_wrap_i64"](), wasm);
  },
  i32Xor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32_xor"](), wasm);
  },
  i32x4Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_abs"](), wasm);
  },
  i32x4Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_add"](), wasm);
  },
  i32x4AllTrue() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_all_true"](), wasm);
  },
  i32x4Bitmask() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_bitmask"](), wasm);
  },
  i32x4DotI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_dot_i16x8s"](), wasm);
  },
  i32x4Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_eq"](), wasm);
  },
  i32x4ExtaddPairwiseI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extadd_pairwise_i16x8s"](), wasm);
  },
  i32x4ExtaddPairwiseI16x8u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extadd_pairwise_i16x8u"](), wasm);
  },
  i32x4ExtendHighI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extend_high_i16x8s"](), wasm);
  },
  i32x4ExtendHighI16x8u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extend_high_i16x8u"](), wasm);
  },
  i32x4ExtendLowI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extend_low_i16x8s"](), wasm);
  },
  i32x4ExtendLowI16x8u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extend_low_i16x8u"](), wasm);
  },
  i32x4ExtmulHighI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extmul_high_i16x8s"](), wasm);
  },
  i32x4ExtmulHighI16x8u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extmul_high_i16x8u"](), wasm);
  },
  i32x4ExtmulLowI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extmul_low_i16x8s"](), wasm);
  },
  i32x4ExtmulLowI16x8u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extmul_low_i16x8u"](), wasm);
  },
  i32x4ExtractLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_extract_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i32x4GeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_ge_s"](), wasm);
  },
  i32x4GeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_ge_u"](), wasm);
  },
  i32x4GtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_gt_s"](), wasm);
  },
  i32x4GtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_gt_u"](), wasm);
  },
  i32x4LeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_le_s"](), wasm);
  },
  i32x4LeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_le_u"](), wasm);
  },
  i32x4LtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_lt_s"](), wasm);
  },
  i32x4LtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_lt_u"](), wasm);
  },
  i32x4MaxS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_max_s"](), wasm);
  },
  i32x4MaxU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_max_u"](), wasm);
  },
  i32x4MinS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_min_s"](), wasm);
  },
  i32x4MinU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_min_u"](), wasm);
  },
  i32x4Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_mul"](), wasm);
  },
  i32x4Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_ne"](), wasm);
  },
  i32x4Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_neg"](), wasm);
  },
  i32x4RelaxedDotI8x16i7x16AddS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_relaxed_dot_i8x16i7x16_add_s"](), wasm);
  },
  i32x4RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_relaxed_laneselect"](), wasm);
  },
  i32x4RelaxedTruncF32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_relaxed_trunc_f32x4s"](), wasm);
  },
  i32x4RelaxedTruncF32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_relaxed_trunc_f32x4u"](), wasm);
  },
  i32x4RelaxedTruncZeroF64x2s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_relaxed_trunc_zero_f64x2s"](), wasm);
  },
  i32x4RelaxedTruncZeroF64x2u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_relaxed_trunc_zero_f64x2u"](), wasm);
  },
  i32x4ReplaceLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_replace_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i32x4Shl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_shl"](), wasm);
  },
  i32x4ShrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_shr_s"](), wasm);
  },
  i32x4ShrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_shr_u"](), wasm);
  },
  i32x4Splat() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_splat"](), wasm);
  },
  i32x4Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_sub"](), wasm);
  },
  i32x4TruncSatF32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_trunc_sat_f32x4s"](), wasm);
  },
  i32x4TruncSatF32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_trunc_sat_f32x4u"](), wasm);
  },
  i32x4TruncSatF64x2sZero() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_trunc_sat_f64x2s_zero"](), wasm);
  },
  i32x4TruncSatF64x2uZero() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i32x4_trunc_sat_f64x2u_zero"](), wasm);
  },
  i64Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_add"](), wasm);
  },
  i64And() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_and"](), wasm);
  },
  i64AtomicLoad(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicLoad16U(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_load16_u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicLoad32U(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_load32_u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicLoad8U(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_load8_u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicStore(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicStore16(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_store16"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicStore32(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_store32"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64AtomicStore8(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_atomic_store8"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Clz() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_clz"](), wasm);
  },
  i64Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_const"](lowerValue({ kind: "named", brand: "lib.I64", showExport: "__js_show_lib_I64" }, arg0, wasm)), wasm);
  },
  i64Ctz() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_ctz"](), wasm);
  },
  i64DivS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_div_s"](), wasm);
  },
  i64DivU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_div_u"](), wasm);
  },
  i64Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_eq"](), wasm);
  },
  i64Eqz() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_eqz"](), wasm);
  },
  i64Extend16s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_extend16s"](), wasm);
  },
  i64Extend32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_extend32s"](), wasm);
  },
  i64Extend8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_extend8s"](), wasm);
  },
  i64ExtendI32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_extend_i32s"](), wasm);
  },
  i64ExtendI32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_extend_i32u"](), wasm);
  },
  i64GeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_ge_s"](), wasm);
  },
  i64GeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_ge_u"](), wasm);
  },
  i64GtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_gt_s"](), wasm);
  },
  i64GtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_gt_u"](), wasm);
  },
  i64LeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_le_s"](), wasm);
  },
  i64LeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_le_u"](), wasm);
  },
  i64Load(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Load16s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load16s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Load16u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load16u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Load32s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load32s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Load32u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load32u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Load8s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load8s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Load8u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_load8u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64LtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_lt_s"](), wasm);
  },
  i64LtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_lt_u"](), wasm);
  },
  i64Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_mul"](), wasm);
  },
  i64Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_ne"](), wasm);
  },
  i64Or() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_or"](), wasm);
  },
  i64Popcnt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_popcnt"](), wasm);
  },
  i64ReinterpretF64() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_reinterpret_f64"](), wasm);
  },
  i64RemS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_rem_s"](), wasm);
  },
  i64RemU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_rem_u"](), wasm);
  },
  i64Rotl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_rotl"](), wasm);
  },
  i64Rotr() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_rotr"](), wasm);
  },
  i64Shl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_shl"](), wasm);
  },
  i64ShrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_shr_s"](), wasm);
  },
  i64ShrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_shr_u"](), wasm);
  },
  i64Store(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Store16(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_store16"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Store32(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_store32"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Store8(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_store8"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  i64Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_sub"](), wasm);
  },
  i64TruncF32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_f32s"](), wasm);
  },
  i64TruncF32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_f32u"](), wasm);
  },
  i64TruncF64s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_f64s"](), wasm);
  },
  i64TruncF64u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_f64u"](), wasm);
  },
  i64TruncSatF32s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_sat_f32s"](), wasm);
  },
  i64TruncSatF32u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_sat_f32u"](), wasm);
  },
  i64TruncSatF64s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_sat_f64s"](), wasm);
  },
  i64TruncSatF64u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_trunc_sat_f64u"](), wasm);
  },
  i64Xor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64_xor"](), wasm);
  },
  i64x2Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_abs"](), wasm);
  },
  i64x2Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_add"](), wasm);
  },
  i64x2AllTrue() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_all_true"](), wasm);
  },
  i64x2Bitmask() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_bitmask"](), wasm);
  },
  i64x2Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_eq"](), wasm);
  },
  i64x2ExtendHighI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extend_high_i32x4s"](), wasm);
  },
  i64x2ExtendHighI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extend_high_i32x4u"](), wasm);
  },
  i64x2ExtendLowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extend_low_i32x4s"](), wasm);
  },
  i64x2ExtendLowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extend_low_i32x4u"](), wasm);
  },
  i64x2ExtmulHighI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extmul_high_i32x4s"](), wasm);
  },
  i64x2ExtmulHighI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extmul_high_i32x4u"](), wasm);
  },
  i64x2ExtmulLowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extmul_low_i32x4s"](), wasm);
  },
  i64x2ExtmulLowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extmul_low_i32x4u"](), wasm);
  },
  i64x2ExtractLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_extract_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i64x2GeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_ge_s"](), wasm);
  },
  i64x2GtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_gt_s"](), wasm);
  },
  i64x2LeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_le_s"](), wasm);
  },
  i64x2LtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_lt_s"](), wasm);
  },
  i64x2Mul() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_mul"](), wasm);
  },
  i64x2Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_ne"](), wasm);
  },
  i64x2Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_neg"](), wasm);
  },
  i64x2RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_relaxed_laneselect"](), wasm);
  },
  i64x2ReplaceLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_replace_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i64x2Shl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_shl"](), wasm);
  },
  i64x2ShrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_shr_s"](), wasm);
  },
  i64x2ShrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_shr_u"](), wasm);
  },
  i64x2Splat() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_splat"](), wasm);
  },
  i64x2Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i64x2_sub"](), wasm);
  },
  i8x16Abs() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_abs"](), wasm);
  },
  i8x16Add() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_add"](), wasm);
  },
  i8x16AddSatS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_add_sat_s"](), wasm);
  },
  i8x16AddSatU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_add_sat_u"](), wasm);
  },
  i8x16AllTrue() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_all_true"](), wasm);
  },
  i8x16AvgrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_avgr_u"](), wasm);
  },
  i8x16Bitmask() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_bitmask"](), wasm);
  },
  i8x16Eq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_eq"](), wasm);
  },
  i8x16ExtractLaneS(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_extract_lane_s"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i8x16ExtractLaneU(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_extract_lane_u"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i8x16GeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_ge_s"](), wasm);
  },
  i8x16GeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_ge_u"](), wasm);
  },
  i8x16GtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_gt_s"](), wasm);
  },
  i8x16GtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_gt_u"](), wasm);
  },
  i8x16LeS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_le_s"](), wasm);
  },
  i8x16LeU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_le_u"](), wasm);
  },
  i8x16LtS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_lt_s"](), wasm);
  },
  i8x16LtU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_lt_u"](), wasm);
  },
  i8x16MaxS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_max_s"](), wasm);
  },
  i8x16MaxU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_max_u"](), wasm);
  },
  i8x16MinS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_min_s"](), wasm);
  },
  i8x16MinU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_min_u"](), wasm);
  },
  i8x16NarrowI16x8s() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_narrow_i16x8s"](), wasm);
  },
  i8x16NarrowI16x8u() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_narrow_i16x8u"](), wasm);
  },
  i8x16Ne() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_ne"](), wasm);
  },
  i8x16Neg() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_neg"](), wasm);
  },
  i8x16Popcnt() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_popcnt"](), wasm);
  },
  i8x16RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_relaxed_laneselect"](), wasm);
  },
  i8x16RelaxedSwizzle() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_relaxed_swizzle"](), wasm);
  },
  i8x16ReplaceLane(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_replace_lane"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  i8x16Shl() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_shl"](), wasm);
  },
  i8x16ShrS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_shr_s"](), wasm);
  },
  i8x16ShrU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_shr_u"](), wasm);
  },
  i8x16Shuffle(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_shuffle"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg5, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg6, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg7, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg8, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg9, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg10, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg11, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg12, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg13, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg14, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg15, wasm)), wasm);
  },
  i8x16Splat() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_splat"](), wasm);
  },
  i8x16Sub() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_sub"](), wasm);
  },
  i8x16SubSatS() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_sub_sat_s"](), wasm);
  },
  i8x16SubSatU() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_sub_sat_u"](), wasm);
  },
  i8x16Swizzle() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__i8x16_swizzle"](), wasm);
  },
  if(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__if_"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_19_new","push":"__js_array_19_push","length":"__js_array_19_length","get":"__js_array_19_get"}, item: { kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" } }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_15_none","some":"__js_option_15_some","isSome":"__js_option_15_is_some","unwrap":"__js_option_15_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_19_new","push":"__js_array_19_push","length":"__js_array_19_length","get":"__js_array_19_get"}, item: { kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" } } }, arg2, wasm)), wasm);
  },
  localGet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__local_get"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm)), wasm);
  },
  localSet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__local_set"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm)), wasm);
  },
  localTee(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__local_tee"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm)), wasm);
  },
  loop(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__loop_"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg1, wasm)), wasm);
  },
  memoryAtomicNotify(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_atomic_notify"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  memoryAtomicWait32(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_atomic_wait32"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  memoryAtomicWait64(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_atomic_wait64"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  memoryCopy(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_copy"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg1, wasm)), wasm);
  },
  memoryFill(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_fill"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
  },
  memoryGrow(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_grow"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
  },
  memoryInit(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_init"](lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg1, wasm)), wasm);
  },
  memorySize(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__memory_size"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
  },
  nop() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__nop"](), wasm);
  },
  refAsNonNull() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_as_non_null"](), wasm);
  },
  refCast(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_cast"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  refCastDescEq(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_cast_desc_eq"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  refEq() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_eq"](), wasm);
  },
  refFunc(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_func"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  refGetDesc() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_get_desc"](), wasm);
  },
  refI31() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_i31"](), wasm);
  },
  refIsNull() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_is_null"](), wasm);
  },
  refNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_null"](lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg0, wasm)), wasm);
  },
  refTest(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_test"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  refTestDesc(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__ref_test_desc"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  return() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__return_"](), wasm);
  },
  returnCall(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__return_call"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  returnCallIndirect(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__return_call_indirect"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm)), wasm);
  },
  returnCallRef(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__return_call_ref"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  select(types) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__select__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__select"](lowerValue({ kind: "option", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, types, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for lib.Instruction.select.");
    }
  },
  structGet(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__struct_get"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm)), wasm);
  },
  structGetS(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__struct_get_s"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm)), wasm);
  },
  structGetU(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__struct_get_u"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm)), wasm);
  },
  structNew(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__struct_new"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  structNewDefault(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__struct_new_default"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  structSet(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__struct_set"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm)), wasm);
  },
  tableCopy(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_copy"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm)), wasm);
  },
  tableFill(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_fill"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  tableGet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_get"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  tableGrow(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_grow"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  tableInit(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_init"](lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm)), wasm);
  },
  tableSet(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_set"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  tableSize(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__table_size"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  throw(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__throw_"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm)), wasm);
  },
  throwRef() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__throw_ref"](), wasm);
  },
  tryTable(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__try_table"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_23_new","push":"__js_array_23_push","length":"__js_array_23_length","get":"__js_array_23_get"}, item: { kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg2, wasm)), wasm);
  },
  unreachable() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__unreachable_"](), wasm);
  },
  v128And() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_and"](), wasm);
  },
  v128Andnot() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_andnot"](), wasm);
  },
  v128AnyTrue() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_any_true"](), wasm);
  },
  v128Bitselect() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_bitselect"](), wasm);
  },
  v128Const(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_const"](lowerValue({ kind: "byte" }, arg0, wasm), lowerValue({ kind: "byte" }, arg1, wasm), lowerValue({ kind: "byte" }, arg2, wasm), lowerValue({ kind: "byte" }, arg3, wasm), lowerValue({ kind: "byte" }, arg4, wasm), lowerValue({ kind: "byte" }, arg5, wasm), lowerValue({ kind: "byte" }, arg6, wasm), lowerValue({ kind: "byte" }, arg7, wasm), lowerValue({ kind: "byte" }, arg8, wasm), lowerValue({ kind: "byte" }, arg9, wasm), lowerValue({ kind: "byte" }, arg10, wasm), lowerValue({ kind: "byte" }, arg11, wasm), lowerValue({ kind: "byte" }, arg12, wasm), lowerValue({ kind: "byte" }, arg13, wasm), lowerValue({ kind: "byte" }, arg14, wasm), lowerValue({ kind: "byte" }, arg15, wasm)), wasm);
  },
  v128Load(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load16Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load16_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Load16Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load16_splat"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load16x4s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load16x4s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load16x4u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load16x4u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load32Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load32_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Load32Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load32_splat"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load32Zero(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load32_zero"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load32x2s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load32x2s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load32x2u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load32x2u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load64Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load64_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Load64Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load64_splat"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load64Zero(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load64_zero"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load8Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load8_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Load8Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load8_splat"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load8x8s(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load8x8s"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Load8x8u(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_load8x8u"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Not() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_not"](), wasm);
  },
  v128Or() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_or"](), wasm);
  },
  v128Store(arg0) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_store"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm)), wasm);
  },
  v128Store16Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_store16_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Store32Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_store32_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Store64Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_store64_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Store8Lane(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_store8_lane"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm)), wasm);
  },
  v128Xor() {
    return liftValue({ kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }, wasm["lib__Instruction__v128_xor"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Instruction"](value);
  },
});

export const LabelIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__LabelIdx__inner"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, wasm["lib__LabelIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_LabelIdx"](value);
  },
});

export const LaneIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "byte" }, wasm["lib__LaneIdx__inner"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, wasm["lib__LaneIdx__new"](lowerValue({ kind: "byte" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_LaneIdx"](value);
  },
});

export const Limits = Object.freeze({
  addrValtype(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__Limits__addr_valtype"](lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg0, wasm)), wasm);
  },
  i32(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, wasm["lib__Limits__i32"](lowerValue({ kind: "number" }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_4_none","some":"__js_option_4_some","isSome":"__js_option_4_is_some","unwrap":"__js_option_4_unwrap"}, item: { kind: "number" } }, arg1, wasm)), wasm);
  },
  i64(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, wasm["lib__Limits__i64"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "bigint" } }, arg1, wasm)), wasm);
  },
  memAddrBits(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__Limits__mem_addr_bits"](lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Limits"](value);
  },
});

export const LoadOp = Object.freeze({
  f32Load() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__f32_load"](), wasm);
  },
  f64Load() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__f64_load"](), wasm);
  },
  i32AtomicLoad() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_atomic_load"](), wasm);
  },
  i32AtomicLoad16U() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_atomic_load16_u"](), wasm);
  },
  i32AtomicLoad8U() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_atomic_load8_u"](), wasm);
  },
  i32Load() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_load"](), wasm);
  },
  i32Load16s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_load16s"](), wasm);
  },
  i32Load16u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_load16u"](), wasm);
  },
  i32Load8s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_load8s"](), wasm);
  },
  i32Load8u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i32_load8u"](), wasm);
  },
  i64AtomicLoad() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_atomic_load"](), wasm);
  },
  i64AtomicLoad16U() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_atomic_load16_u"](), wasm);
  },
  i64AtomicLoad32U() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_atomic_load32_u"](), wasm);
  },
  i64AtomicLoad8U() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_atomic_load8_u"](), wasm);
  },
  i64Load() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load"](), wasm);
  },
  i64Load16s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load16s"](), wasm);
  },
  i64Load16u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load16u"](), wasm);
  },
  i64Load32s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load32s"](), wasm);
  },
  i64Load32u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load32u"](), wasm);
  },
  i64Load8s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load8s"](), wasm);
  },
  i64Load8u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__i64_load8u"](), wasm);
  },
  v128Load() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load"](), wasm);
  },
  v128Load16Splat() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load16_splat"](), wasm);
  },
  v128Load16x4s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load16x4s"](), wasm);
  },
  v128Load16x4u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load16x4u"](), wasm);
  },
  v128Load32Splat() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load32_splat"](), wasm);
  },
  v128Load32Zero() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load32_zero"](), wasm);
  },
  v128Load32x2s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load32x2s"](), wasm);
  },
  v128Load32x2u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load32x2u"](), wasm);
  },
  v128Load64Splat() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load64_splat"](), wasm);
  },
  v128Load64Zero() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load64_zero"](), wasm);
  },
  v128Load8Splat() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load8_splat"](), wasm);
  },
  v128Load8x8s() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load8x8s"](), wasm);
  },
  v128Load8x8u() {
    return liftValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, wasm["lib__LoadOp__v128_load8x8u"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_LoadOp"](value);
  },
});

export const LocalIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__LocalIdx__inner"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, wasm["lib__LocalIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_LocalIdx"](value);
  },
});

export const Locals = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Locals", showExport: "__js_show_lib_Locals" }, wasm["lib__Locals__new"](lowerValue({ kind: "number" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Locals"](value);
  },
});

export const MemArg = Object.freeze({
  new(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, wasm["lib__MemArg__new"](lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_17_none","some":"__js_option_17_some","isSome":"__js_option_17_is_some","unwrap":"__js_option_17_unwrap"}, item: { kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.U64", showExport: "__js_show_lib_U64" }, arg2, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_MemArg"](value);
  },
});

export const MemIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__MemIdx__inner"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, wasm["lib__MemIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_MemIdx"](value);
  },
});

export const MemSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_24_new","push":"__js_array_24_push","length":"__js_array_24_length","get":"__js_array_24_get"}, item: { kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" } }, wasm["lib__MemSec__inner"](lowerValue({ kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" }, wasm["lib__MemSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_24_new","push":"__js_array_24_push","length":"__js_array_24_length","get":"__js_array_24_get"}, item: { kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_MemSec"](value);
  },
});

export const MemType = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, wasm["lib__MemType__inner"](lowerValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, wasm["lib__MemType__new"](lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_MemType"](value);
  },
});

export const Module = Object.freeze({
  new(customSecs, typeSec, importSec, funcSec, tableSec, memSec, tagSec, globalSec, exportSec, startSec, elemSec, dataCntSec, codeSec, dataSec) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_1"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_2"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_3"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_4"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_5"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_6"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm)), wasm);
      case 7:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_7"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm)), wasm);
      case 8:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_8"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm)), wasm);
      case 9:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_9"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, exportSec, wasm)), wasm);
      case 10:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_10"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, exportSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, startSec, wasm)), wasm);
      case 11:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_11"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, exportSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, startSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_27_none","some":"__js_option_27_some","isSome":"__js_option_27_is_some","unwrap":"__js_option_27_unwrap"}, item: { kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" } }, elemSec, wasm)), wasm);
      case 12:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_12"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, exportSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, startSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_27_none","some":"__js_option_27_some","isSome":"__js_option_27_is_some","unwrap":"__js_option_27_unwrap"}, item: { kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" } }, elemSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_28_none","some":"__js_option_28_some","isSome":"__js_option_28_is_some","unwrap":"__js_option_28_unwrap"}, item: { kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" } }, dataCntSec, wasm)), wasm);
      case 13:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new__arity_13"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, exportSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, startSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_27_none","some":"__js_option_27_some","isSome":"__js_option_27_is_some","unwrap":"__js_option_27_unwrap"}, item: { kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" } }, elemSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_28_none","some":"__js_option_28_some","isSome":"__js_option_28_is_some","unwrap":"__js_option_28_unwrap"}, item: { kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" } }, dataCntSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_29_none","some":"__js_option_29_some","isSome":"__js_option_29_is_some","unwrap":"__js_option_29_unwrap"}, item: { kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" } }, codeSec, wasm)), wasm);
      case 14:
        return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, customSecs, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, typeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, importSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, funcSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, tableSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, memSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, tagSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, globalSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, exportSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, startSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_27_none","some":"__js_option_27_some","isSome":"__js_option_27_is_some","unwrap":"__js_option_27_unwrap"}, item: { kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" } }, elemSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_28_none","some":"__js_option_28_some","isSome":"__js_option_28_is_some","unwrap":"__js_option_28_unwrap"}, item: { kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" } }, dataCntSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_29_none","some":"__js_option_29_some","isSome":"__js_option_29_is_some","unwrap":"__js_option_29_unwrap"}, item: { kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" } }, codeSec, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_30_none","some":"__js_option_30_some","isSome":"__js_option_30_is_some","unwrap":"__js_option_30_unwrap"}, item: { kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" } }, dataSec, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for lib.Module.new.");
    }
  },
  withCodeSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_code_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" }, arg1, wasm)), wasm);
  },
  withCustomSecs(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_custom_secs"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_25_new","push":"__js_array_25_push","length":"__js_array_25_length","get":"__js_array_25_get"}, item: { kind: "named", brand: "lib.CustomSec", showExport: "__js_show_lib_CustomSec" } }, arg1, wasm)), wasm);
  },
  withDataCntSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_data_cnt_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" }, arg1, wasm)), wasm);
  },
  withDataSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_data_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" }, arg1, wasm)), wasm);
  },
  withElemSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_elem_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" }, arg1, wasm)), wasm);
  },
  withExportSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_export_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" }, arg1, wasm)), wasm);
  },
  withFuncSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_func_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" }, arg1, wasm)), wasm);
  },
  withGlobalSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_global_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" }, arg1, wasm)), wasm);
  },
  withImportSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_import_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" }, arg1, wasm)), wasm);
  },
  withMemSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_mem_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" }, arg1, wasm)), wasm);
  },
  withStartSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_start_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" }, arg1, wasm)), wasm);
  },
  withTableSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_table_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" }, arg1, wasm)), wasm);
  },
  withTagSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_tag_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" }, arg1, wasm)), wasm);
  },
  withTypeSec(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["lib__Module__with_type_sec"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Module"](value);
  },
});

export const Mut = Object.freeze({
  const() {
    return liftValue({ kind: "named", brand: "lib.Mut", showExport: "__js_show_lib_Mut" }, wasm["lib__Mut__const_"](), wasm);
  },
  var() {
    return liftValue({ kind: "named", brand: "lib.Mut", showExport: "__js_show_lib_Mut" }, wasm["lib__Mut__var_"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Mut"](value);
  },
});

export const Name = Object.freeze({
  fromString(arg0) {
    return liftValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, wasm["lib__Name__from_string"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  inner(arg0) {
    return liftValue({ kind: "opaque", brand: "StringView" }, wasm["lib__Name__inner"](lowerValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.Name", showExport: "__js_show_lib_Name" }, wasm["lib__Name__new"](lowerValue({ kind: "opaque", brand: "StringView" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Name"](value);
  },
});

export const NumType = Object.freeze({
  f32() {
    return liftValue({ kind: "named", brand: "lib.NumType", showExport: "__js_show_lib_NumType" }, wasm["lib__NumType__f32"](), wasm);
  },
  f64() {
    return liftValue({ kind: "named", brand: "lib.NumType", showExport: "__js_show_lib_NumType" }, wasm["lib__NumType__f64"](), wasm);
  },
  i32() {
    return liftValue({ kind: "named", brand: "lib.NumType", showExport: "__js_show_lib_NumType" }, wasm["lib__NumType__i32"](), wasm);
  },
  i64() {
    return liftValue({ kind: "named", brand: "lib.NumType", showExport: "__js_show_lib_NumType" }, wasm["lib__NumType__i64"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_NumType"](value);
  },
});

export const PackType = Object.freeze({
  i16() {
    return liftValue({ kind: "named", brand: "lib.PackType", showExport: "__js_show_lib_PackType" }, wasm["lib__PackType__i16"](), wasm);
  },
  i8() {
    return liftValue({ kind: "named", brand: "lib.PackType", showExport: "__js_show_lib_PackType" }, wasm["lib__PackType__i8"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_PackType"](value);
  },
});

export const PrettyPrintContext = Object.freeze({
  indent(arg0, arg1) {
    return liftValue({ kind: "string" }, wasm["lib__PrettyPrintContext__indent"](lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
  },
  indentUnit(arg0) {
    return liftValue({ kind: "string" }, wasm["lib__PrettyPrintContext__indent_unit"](lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg0, wasm)), wasm);
  },
  new(maxLineWidth, tabsOrSpaces, tabWidth, continuationIndent, sourceIndentWidth) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, wasm["lib__PrettyPrintContext__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, wasm["lib__PrettyPrintContext__new__arity_1"](lowerValue({ kind: "number" }, maxLineWidth, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, wasm["lib__PrettyPrintContext__new__arity_2"](lowerValue({ kind: "number" }, maxLineWidth, wasm), lowerValue({ kind: "named", brand: "lib.TabsOrSpaces", showExport: "__js_show_lib_TabsOrSpaces" }, tabsOrSpaces, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, wasm["lib__PrettyPrintContext__new__arity_3"](lowerValue({ kind: "number" }, maxLineWidth, wasm), lowerValue({ kind: "named", brand: "lib.TabsOrSpaces", showExport: "__js_show_lib_TabsOrSpaces" }, tabsOrSpaces, wasm), lowerValue({ kind: "number" }, tabWidth, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, wasm["lib__PrettyPrintContext__new__arity_4"](lowerValue({ kind: "number" }, maxLineWidth, wasm), lowerValue({ kind: "named", brand: "lib.TabsOrSpaces", showExport: "__js_show_lib_TabsOrSpaces" }, tabsOrSpaces, wasm), lowerValue({ kind: "number" }, tabWidth, wasm), lowerValue({ kind: "number" }, continuationIndent, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, wasm["lib__PrettyPrintContext__new"](lowerValue({ kind: "number" }, maxLineWidth, wasm), lowerValue({ kind: "named", brand: "lib.TabsOrSpaces", showExport: "__js_show_lib_TabsOrSpaces" }, tabsOrSpaces, wasm), lowerValue({ kind: "number" }, tabWidth, wasm), lowerValue({ kind: "number" }, continuationIndent, wasm), lowerValue({ kind: "number" }, sourceIndentWidth, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for lib.PrettyPrintContext.new.");
    }
  },
  show(value) {
    return wasm["__js_show_lib_PrettyPrintContext"](value);
  },
});

export const RecType = Object.freeze({
  getSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["lib__RecType__get_subtype"](lowerValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
  },
  group(arg0) {
    return liftValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, wasm["lib__RecType__group"](lowerValue({ kind: "array", helper: {"new":"__js_array_11_new","push":"__js_array_11_push","length":"__js_array_11_length","get":"__js_array_11_get"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, wasm["lib__RecType__new"](lowerValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_RecType"](value);
  },
});

export const RefType = Object.freeze({
  abs(arg0) {
    return liftValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, wasm["lib__RefType__abs"](lowerValue({ kind: "named", brand: "lib.AbsHeapType", showExport: "__js_show_lib_AbsHeapType" }, arg0, wasm)), wasm);
  },
  getHeapType(arg0) {
    return liftValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, wasm["lib__RefType__get_heap_type"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm)), wasm);
  },
  isDefaultable(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__RefType__is_defaultable"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm)), wasm);
  },
  isNonNullable(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__RefType__is_non_nullable"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm)), wasm);
  },
  isNullable(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__RefType__is_nullable"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm)), wasm);
  },
  makeNullable(arg0) {
    return liftValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, wasm["lib__RefType__make_nullable"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm)), wasm);
  },
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, wasm["lib__RefType__new"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_RefType"](value);
  },
});

export const ReplaceLaneOp = Object.freeze({
  f32x4ReplaceLane() {
    return liftValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, wasm["lib__ReplaceLaneOp__f32x4_replace_lane"](), wasm);
  },
  f64x2ReplaceLane() {
    return liftValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, wasm["lib__ReplaceLaneOp__f64x2_replace_lane"](), wasm);
  },
  i16x8ReplaceLane() {
    return liftValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, wasm["lib__ReplaceLaneOp__i16x8_replace_lane"](), wasm);
  },
  i32x4ReplaceLane() {
    return liftValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, wasm["lib__ReplaceLaneOp__i32x4_replace_lane"](), wasm);
  },
  i64x2ReplaceLane() {
    return liftValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, wasm["lib__ReplaceLaneOp__i64x2_replace_lane"](), wasm);
  },
  i8x16ReplaceLane() {
    return liftValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, wasm["lib__ReplaceLaneOp__i8x16_replace_lane"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ReplaceLaneOp"](value);
  },
});

export const ResultType = Object.freeze({
});

export const S33 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__S33__inner"](lowerValue({ kind: "named", brand: "lib.S33", showExport: "__js_show_lib_S33" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.S33", showExport: "__js_show_lib_S33" }, wasm["lib__S33__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_S33"](value);
  },
});

export const StartSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, wasm["lib__StartSec__inner"](lowerValue({ kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" }, wasm["lib__StartSec__new"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_StartSec"](value);
  },
});

export const StorageType = Object.freeze({
  isPacked(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__StorageType__is_packed"](lowerValue({ kind: "named", brand: "lib.StorageType", showExport: "__js_show_lib_StorageType" }, arg0, wasm)), wasm);
  },
  packType(arg0) {
    return liftValue({ kind: "named", brand: "lib.StorageType", showExport: "__js_show_lib_StorageType" }, wasm["lib__StorageType__pack_type"](lowerValue({ kind: "named", brand: "lib.PackType", showExport: "__js_show_lib_PackType" }, arg0, wasm)), wasm);
  },
  unpack(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__StorageType__unpack"](lowerValue({ kind: "named", brand: "lib.StorageType", showExport: "__js_show_lib_StorageType" }, arg0, wasm)), wasm);
  },
  valType(arg0) {
    return liftValue({ kind: "named", brand: "lib.StorageType", showExport: "__js_show_lib_StorageType" }, wasm["lib__StorageType__val_type"](lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_StorageType"](value);
  },
});

export const StoreOp = Object.freeze({
  f32Store() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__f32_store"](), wasm);
  },
  f64Store() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__f64_store"](), wasm);
  },
  i32AtomicStore() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i32_atomic_store"](), wasm);
  },
  i32AtomicStore16() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i32_atomic_store16"](), wasm);
  },
  i32AtomicStore8() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i32_atomic_store8"](), wasm);
  },
  i32Store() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i32_store"](), wasm);
  },
  i32Store16() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i32_store16"](), wasm);
  },
  i32Store8() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i32_store8"](), wasm);
  },
  i64AtomicStore() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_atomic_store"](), wasm);
  },
  i64AtomicStore16() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_atomic_store16"](), wasm);
  },
  i64AtomicStore32() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_atomic_store32"](), wasm);
  },
  i64AtomicStore8() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_atomic_store8"](), wasm);
  },
  i64Store() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_store"](), wasm);
  },
  i64Store16() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_store16"](), wasm);
  },
  i64Store32() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_store32"](), wasm);
  },
  i64Store8() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__i64_store8"](), wasm);
  },
  v128Store() {
    return liftValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, wasm["lib__StoreOp__v128_store"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_StoreOp"](value);
  },
});

export const SubType = Object.freeze({
  compType(arg0) {
    return liftValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, wasm["lib__SubType__comp_type"](lowerValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, arg0, wasm)), wasm);
  },
  getComptype(arg0) {
    return liftValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, wasm["lib__SubType__get_comptype"](lowerValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, arg0, wasm)), wasm);
  },
  new(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, wasm["lib__SubType__new"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" }, arg2, wasm)), wasm);
  },
  superTypes(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, wasm["lib__SubType__super_types"](lowerValue({ kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_SubType"](value);
  },
});

export const TExpr = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, wasm["lib__TExpr__inner"](lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, wasm["lib__TExpr__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg0, wasm)), wasm);
  },
  toExpr(arg0) {
    return liftValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, wasm["lib__TExpr__to_expr"](lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TExpr"](value);
  },
});

export const TInstr = Object.freeze({
  anyConvertExtern(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__any_convert_extern"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  arrayCopy(arg0, arg1, arg2, arg3, arg4, arg5, arg6) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_copy"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg5, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg6, wasm)), wasm);
  },
  arrayFill(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_fill"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  arrayGet(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_get"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  arrayGetS(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_get_s"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  arrayGetU(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_get_u"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  arrayInitData(arg0, arg1, arg2, arg3, arg4, arg5) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_init_data"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg5, wasm)), wasm);
  },
  arrayInitElem(arg0, arg1, arg2, arg3, arg4, arg5) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_init_elem"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg5, wasm)), wasm);
  },
  arrayLen(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_len"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  arrayNew(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_new"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  arrayNewData(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_new_data"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  arrayNewDefault(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_new_default"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  arrayNewElem(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_new_elem"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  arrayNewFixed(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_new_fixed"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm)), wasm);
  },
  arraySet(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__array_set"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  atomicCmpxchg(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__atomic_cmpxchg"](lowerValue({ kind: "named", brand: "lib.AtomicCmpxchgOp", showExport: "__js_show_lib_AtomicCmpxchgOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  atomicFence() {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__atomic_fence"](), wasm);
  },
  atomicRmw(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__atomic_rmw"](lowerValue({ kind: "named", brand: "lib.AtomicRmwOp", showExport: "__js_show_lib_AtomicRmwOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  binary(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__binary"](lowerValue({ kind: "named", brand: "lib.BinaryOp", showExport: "__js_show_lib_BinaryOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  block(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__block"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg1, wasm)), wasm);
  },
  br(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm)), wasm);
  },
  brIf(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br_if"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg2, wasm)), wasm);
  },
  brOnCast(arg0, arg1, arg2, arg3, arg4, arg5, arg6) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br_on_cast"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg2, wasm), lowerValue({ kind: "bool" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg5, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg6, wasm)), wasm);
  },
  brOnCastFail(arg0, arg1, arg2, arg3, arg4, arg5, arg6) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br_on_cast_fail"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg2, wasm), lowerValue({ kind: "bool" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg5, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg6, wasm)), wasm);
  },
  brOnNonNull(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br_on_non_null"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg2, wasm)), wasm);
  },
  brOnNull(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br_on_null"](lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg2, wasm)), wasm);
  },
  brTable(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__br_table"](lowerValue({ kind: "array", helper: {"new":"__js_array_22_new","push":"__js_array_22_push","length":"__js_array_22_length","get":"__js_array_22_get"}, item: { kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" } }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg3, wasm)), wasm);
  },
  call(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__call"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm)), wasm);
  },
  callIndirect(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__call_indirect"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  callRef(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__call_ref"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  dataDrop(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__data_drop"](lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg0, wasm)), wasm);
  },
  drop(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__drop"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  elemDrop(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__elem_drop"](lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg0, wasm)), wasm);
  },
  externConvertAny(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__extern_convert_any"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  extractLane(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__extract_lane"](lowerValue({ kind: "named", brand: "lib.ExtractLaneOp", showExport: "__js_show_lib_ExtractLaneOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  f32Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__f32_const"](lowerValue({ kind: "named", brand: "lib.F32", showExport: "__js_show_lib_F32" }, arg0, wasm)), wasm);
  },
  f32x4Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__f32x4_splat"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  f64Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__f64_const"](lowerValue({ kind: "named", brand: "lib.F64", showExport: "__js_show_lib_F64" }, arg0, wasm)), wasm);
  },
  f64x2Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__f64x2_splat"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  globalGet(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__global_get"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm)), wasm);
  },
  globalSet(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__global_set"](lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  i16x8Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i16x8_splat"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  i31GetS(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i31_get_s"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  i31GetU(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i31_get_u"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  i32Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i32_const"](lowerValue({ kind: "named", brand: "lib.I32", showExport: "__js_show_lib_I32" }, arg0, wasm)), wasm);
  },
  i32x4Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i32x4_splat"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  i64Const(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i64_const"](lowerValue({ kind: "named", brand: "lib.I64", showExport: "__js_show_lib_I64" }, arg0, wasm)), wasm);
  },
  i64x2Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i64x2_splat"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  i8x16RelaxedSwizzle(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i8x16_relaxed_swizzle"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  i8x16Shuffle(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i8x16_shuffle"](lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg4, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg5, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg6, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg7, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg8, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg9, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg10, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg11, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg12, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg13, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg14, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg15, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg16, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg17, wasm)), wasm);
  },
  i8x16Splat(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i8x16_splat"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  i8x16Swizzle(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__i8x16_swizzle"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  if(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__if_"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg2, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_11_none","some":"__js_option_11_some","isSome":"__js_option_11_is_some","unwrap":"__js_option_11_unwrap"}, item: { kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" } }, arg3, wasm)), wasm);
  },
  load(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__load"](lowerValue({ kind: "named", brand: "lib.LoadOp", showExport: "__js_show_lib_LoadOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  localGet(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__local_get"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm)), wasm);
  },
  localSet(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__local_set"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  localTee(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__local_tee"](lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  loop(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__loop_"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg1, wasm)), wasm);
  },
  memoryAtomicNotify(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_atomic_notify"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  memoryAtomicWait32(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_atomic_wait32"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  memoryAtomicWait64(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_atomic_wait64"](lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  memoryCopy(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_copy"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  memoryFill(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_fill"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  memoryGrow(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_grow"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  memoryInit(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_init"](lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  memorySize(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__memory_size"](lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg0, wasm)), wasm);
  },
  nop() {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__nop"](), wasm);
  },
  refAsNonNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_as_non_null"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  refCast(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_cast"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  refCastDescEq(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_cast_desc_eq"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  refEq(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_eq"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  refFunc(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_func"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm)), wasm);
  },
  refGetDesc(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_get_desc"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  refI31(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_i31"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  refIsNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_is_null"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  refNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_null"](lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg0, wasm)), wasm);
  },
  refTest(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_test"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  refTestDesc(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__ref_test_desc"](lowerValue({ kind: "bool" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  replaceLane(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__replace_lane"](lowerValue({ kind: "named", brand: "lib.ReplaceLaneOp", showExport: "__js_show_lib_ReplaceLaneOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  return(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__return_"](lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg0, wasm)), wasm);
  },
  returnCall(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__return_call"](lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm)), wasm);
  },
  returnCallIndirect(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__return_call_indirect"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  returnCallRef(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__return_call_ref"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  select(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__select"](lowerValue({ kind: "option", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  store(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__store"](lowerValue({ kind: "named", brand: "lib.StoreOp", showExport: "__js_show_lib_StoreOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  structGet(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__struct_get"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  structGetS(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__struct_get_s"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  structGetU(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__struct_get_u"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  structNew(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__struct_new"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm)), wasm);
  },
  structNewDefault(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__struct_new_default"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  structSet(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__struct_set"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  tableCopy(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_copy"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  tableFill(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_fill"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  tableGet(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_get"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  tableGrow(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_grow"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  tableInit(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_init"](lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  tableSet(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_set"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  tableSize(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__table_size"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  throw(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__throw_"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" } }, arg1, wasm)), wasm);
  },
  throwRef(arg0) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__throw_ref"](lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg0, wasm)), wasm);
  },
  tryTable(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__try_table"](lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_23_new","push":"__js_array_23_push","length":"__js_array_23_length","get":"__js_array_23_get"}, item: { kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" } }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, arg2, wasm)), wasm);
  },
  unary(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__unary"](lowerValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm)), wasm);
  },
  unreachable() {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__unreachable_"](), wasm);
  },
  v128Const(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__v128_const"](lowerValue({ kind: "byte" }, arg0, wasm), lowerValue({ kind: "byte" }, arg1, wasm), lowerValue({ kind: "byte" }, arg2, wasm), lowerValue({ kind: "byte" }, arg3, wasm), lowerValue({ kind: "byte" }, arg4, wasm), lowerValue({ kind: "byte" }, arg5, wasm), lowerValue({ kind: "byte" }, arg6, wasm), lowerValue({ kind: "byte" }, arg7, wasm), lowerValue({ kind: "byte" }, arg8, wasm), lowerValue({ kind: "byte" }, arg9, wasm), lowerValue({ kind: "byte" }, arg10, wasm), lowerValue({ kind: "byte" }, arg11, wasm), lowerValue({ kind: "byte" }, arg12, wasm), lowerValue({ kind: "byte" }, arg13, wasm), lowerValue({ kind: "byte" }, arg14, wasm), lowerValue({ kind: "byte" }, arg15, wasm)), wasm);
  },
  v128LoadLane(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__v128_load_lane"](lowerValue({ kind: "named", brand: "lib.V128LoadLaneOp", showExport: "__js_show_lib_V128LoadLaneOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  v128Shift(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__v128_shift"](lowerValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm)), wasm);
  },
  v128StoreLane(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__v128_store_lane"](lowerValue({ kind: "named", brand: "lib.V128StoreLaneOp", showExport: "__js_show_lib_V128StoreLaneOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemArg", showExport: "__js_show_lib_MemArg" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.LaneIdx", showExport: "__js_show_lib_LaneIdx" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg4, wasm)), wasm);
  },
  v128Ternary(arg0, arg1, arg2, arg3) {
    return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["lib__TInstr__v128_ternary"](lowerValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg2, wasm), lowerValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, arg3, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TInstr"](value);
  },
});

export const TInstrKind = Object.freeze({
  show(value) {
    return wasm["__js_show_lib_TInstrKind"](value);
  },
});

export const Table = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.Table", showExport: "__js_show_lib_Table" }, wasm["lib__Table__new"](lowerValue({ kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_31_none","some":"__js_option_31_some","isSome":"__js_option_31_is_some","unwrap":"__js_option_31_unwrap"}, item: { kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" } }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_Table"](value);
  },
});

export const TableIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__TableIdx__inner"](lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, wasm["lib__TableIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TableIdx"](value);
  },
});

export const TableSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_26_new","push":"__js_array_26_push","length":"__js_array_26_length","get":"__js_array_26_get"}, item: { kind: "named", brand: "lib.Table", showExport: "__js_show_lib_Table" } }, wasm["lib__TableSec__inner"](lowerValue({ kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" }, wasm["lib__TableSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_26_new","push":"__js_array_26_push","length":"__js_array_26_length","get":"__js_array_26_get"}, item: { kind: "named", brand: "lib.Table", showExport: "__js_show_lib_Table" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TableSec"](value);
  },
});

export const TableType = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" }, wasm["lib__TableType__new"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Limits", showExport: "__js_show_lib_Limits" }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TableType"](value);
  },
});

export const TabsOrSpaces = Object.freeze({
  spaces() {
    return liftValue({ kind: "named", brand: "lib.TabsOrSpaces", showExport: "__js_show_lib_TabsOrSpaces" }, wasm["lib__TabsOrSpaces__spaces"](), wasm);
  },
  tabs() {
    return liftValue({ kind: "named", brand: "lib.TabsOrSpaces", showExport: "__js_show_lib_TabsOrSpaces" }, wasm["lib__TabsOrSpaces__tabs"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TabsOrSpaces"](value);
  },
});

export const TagIdx = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__TagIdx__inner"](lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, wasm["lib__TagIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TagIdx"](value);
  },
});

export const TagSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_27_new","push":"__js_array_27_push","length":"__js_array_27_length","get":"__js_array_27_get"}, item: { kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" } }, wasm["lib__TagSec__inner"](lowerValue({ kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" }, wasm["lib__TagSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_27_new","push":"__js_array_27_push","length":"__js_array_27_length","get":"__js_array_27_get"}, item: { kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TagSec"](value);
  },
});

export const TagType = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, wasm["lib__TagType__inner"](lowerValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, wasm["lib__TagType__new"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TagType"](value);
  },
});

export const TypeIdx = Object.freeze({
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, wasm["lib__TypeIdx__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  rec(arg0) {
    return liftValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, wasm["lib__TypeIdx__rec"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TypeIdx"](value);
  },
});

export const TypeSec = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_28_new","push":"__js_array_28_push","length":"__js_array_28_length","get":"__js_array_28_get"}, item: { kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" } }, wasm["lib__TypeSec__inner"](lowerValue({ kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" }, wasm["lib__TypeSec__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_28_new","push":"__js_array_28_push","length":"__js_array_28_length","get":"__js_array_28_get"}, item: { kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" } }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_TypeSec"](value);
  },
});

export const U32 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "number" }, wasm["lib__U32__inner"](lowerValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.U32", showExport: "__js_show_lib_U32" }, wasm["lib__U32__new"](lowerValue({ kind: "number" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_U32"](value);
  },
});

export const U64 = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "bigint" }, wasm["lib__U64__inner"](lowerValue({ kind: "named", brand: "lib.U64", showExport: "__js_show_lib_U64" }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "lib.U64", showExport: "__js_show_lib_U64" }, wasm["lib__U64__new"](lowerValue({ kind: "bigint" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_U64"](value);
  },
});

export const UnaryOp = Object.freeze({
  f32Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_abs"](), wasm);
  },
  f32Ceil() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_ceil"](), wasm);
  },
  f32ConvertI32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_convert_i32s"](), wasm);
  },
  f32ConvertI32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_convert_i32u"](), wasm);
  },
  f32ConvertI64s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_convert_i64s"](), wasm);
  },
  f32ConvertI64u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_convert_i64u"](), wasm);
  },
  f32DemoteF64() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_demote_f64"](), wasm);
  },
  f32Floor() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_floor"](), wasm);
  },
  f32Nearest() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_nearest"](), wasm);
  },
  f32Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_neg"](), wasm);
  },
  f32ReinterpretI32() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_reinterpret_i32"](), wasm);
  },
  f32Sqrt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_sqrt"](), wasm);
  },
  f32Trunc() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32_trunc"](), wasm);
  },
  f32x4Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_abs"](), wasm);
  },
  f32x4Ceil() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_ceil"](), wasm);
  },
  f32x4ConvertI32x4s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_convert_i32x4s"](), wasm);
  },
  f32x4ConvertI32x4u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_convert_i32x4u"](), wasm);
  },
  f32x4DemoteF64x2Zero() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_demote_f64x2_zero"](), wasm);
  },
  f32x4Floor() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_floor"](), wasm);
  },
  f32x4Nearest() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_nearest"](), wasm);
  },
  f32x4Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_neg"](), wasm);
  },
  f32x4Sqrt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_sqrt"](), wasm);
  },
  f32x4Trunc() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f32x4_trunc"](), wasm);
  },
  f64Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_abs"](), wasm);
  },
  f64Ceil() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_ceil"](), wasm);
  },
  f64ConvertI32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_convert_i32s"](), wasm);
  },
  f64ConvertI32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_convert_i32u"](), wasm);
  },
  f64ConvertI64s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_convert_i64s"](), wasm);
  },
  f64ConvertI64u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_convert_i64u"](), wasm);
  },
  f64Floor() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_floor"](), wasm);
  },
  f64Nearest() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_nearest"](), wasm);
  },
  f64Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_neg"](), wasm);
  },
  f64PromoteF32() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_promote_f32"](), wasm);
  },
  f64ReinterpretI64() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_reinterpret_i64"](), wasm);
  },
  f64Sqrt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_sqrt"](), wasm);
  },
  f64Trunc() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64_trunc"](), wasm);
  },
  f64x2Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_abs"](), wasm);
  },
  f64x2Ceil() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_ceil"](), wasm);
  },
  f64x2ConvertLowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_convert_low_i32x4s"](), wasm);
  },
  f64x2ConvertLowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_convert_low_i32x4u"](), wasm);
  },
  f64x2Floor() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_floor"](), wasm);
  },
  f64x2Nearest() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_nearest"](), wasm);
  },
  f64x2Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_neg"](), wasm);
  },
  f64x2PromoteLowF32x4() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_promote_low_f32x4"](), wasm);
  },
  f64x2Sqrt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_sqrt"](), wasm);
  },
  f64x2Trunc() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__f64x2_trunc"](), wasm);
  },
  i16x8Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_abs"](), wasm);
  },
  i16x8AllTrue() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_all_true"](), wasm);
  },
  i16x8Bitmask() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_bitmask"](), wasm);
  },
  i16x8ExtaddPairwiseI8x16s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_extadd_pairwise_i8x16s"](), wasm);
  },
  i16x8ExtaddPairwiseI8x16u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_extadd_pairwise_i8x16u"](), wasm);
  },
  i16x8ExtendHighI8x16s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_extend_high_i8x16s"](), wasm);
  },
  i16x8ExtendHighI8x16u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_extend_high_i8x16u"](), wasm);
  },
  i16x8ExtendLowI8x16s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_extend_low_i8x16s"](), wasm);
  },
  i16x8ExtendLowI8x16u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_extend_low_i8x16u"](), wasm);
  },
  i16x8Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i16x8_neg"](), wasm);
  },
  i32Clz() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_clz"](), wasm);
  },
  i32Ctz() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_ctz"](), wasm);
  },
  i32Eqz() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_eqz"](), wasm);
  },
  i32Extend16s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_extend16s"](), wasm);
  },
  i32Extend8s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_extend8s"](), wasm);
  },
  i32Popcnt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_popcnt"](), wasm);
  },
  i32ReinterpretF32() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_reinterpret_f32"](), wasm);
  },
  i32TruncF32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_f32s"](), wasm);
  },
  i32TruncF32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_f32u"](), wasm);
  },
  i32TruncF64s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_f64s"](), wasm);
  },
  i32TruncF64u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_f64u"](), wasm);
  },
  i32TruncSatF32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_sat_f32s"](), wasm);
  },
  i32TruncSatF32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_sat_f32u"](), wasm);
  },
  i32TruncSatF64s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_sat_f64s"](), wasm);
  },
  i32TruncSatF64u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_trunc_sat_f64u"](), wasm);
  },
  i32WrapI64() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32_wrap_i64"](), wasm);
  },
  i32x4Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_abs"](), wasm);
  },
  i32x4AllTrue() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_all_true"](), wasm);
  },
  i32x4Bitmask() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_bitmask"](), wasm);
  },
  i32x4ExtaddPairwiseI16x8s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_extadd_pairwise_i16x8s"](), wasm);
  },
  i32x4ExtaddPairwiseI16x8u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_extadd_pairwise_i16x8u"](), wasm);
  },
  i32x4ExtendHighI16x8s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_extend_high_i16x8s"](), wasm);
  },
  i32x4ExtendHighI16x8u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_extend_high_i16x8u"](), wasm);
  },
  i32x4ExtendLowI16x8s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_extend_low_i16x8s"](), wasm);
  },
  i32x4ExtendLowI16x8u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_extend_low_i16x8u"](), wasm);
  },
  i32x4Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_neg"](), wasm);
  },
  i32x4RelaxedTruncF32x4s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_relaxed_trunc_f32x4s"](), wasm);
  },
  i32x4RelaxedTruncF32x4u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_relaxed_trunc_f32x4u"](), wasm);
  },
  i32x4RelaxedTruncZeroF64x2s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_relaxed_trunc_zero_f64x2s"](), wasm);
  },
  i32x4RelaxedTruncZeroF64x2u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_relaxed_trunc_zero_f64x2u"](), wasm);
  },
  i32x4TruncSatF32x4s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_trunc_sat_f32x4s"](), wasm);
  },
  i32x4TruncSatF32x4u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_trunc_sat_f32x4u"](), wasm);
  },
  i32x4TruncSatF64x2sZero() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_trunc_sat_f64x2s_zero"](), wasm);
  },
  i32x4TruncSatF64x2uZero() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i32x4_trunc_sat_f64x2u_zero"](), wasm);
  },
  i64Clz() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_clz"](), wasm);
  },
  i64Ctz() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_ctz"](), wasm);
  },
  i64Eqz() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_eqz"](), wasm);
  },
  i64Extend16s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_extend16s"](), wasm);
  },
  i64Extend32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_extend32s"](), wasm);
  },
  i64Extend8s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_extend8s"](), wasm);
  },
  i64ExtendI32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_extend_i32s"](), wasm);
  },
  i64ExtendI32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_extend_i32u"](), wasm);
  },
  i64Popcnt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_popcnt"](), wasm);
  },
  i64ReinterpretF64() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_reinterpret_f64"](), wasm);
  },
  i64TruncF32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_f32s"](), wasm);
  },
  i64TruncF32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_f32u"](), wasm);
  },
  i64TruncF64s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_f64s"](), wasm);
  },
  i64TruncF64u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_f64u"](), wasm);
  },
  i64TruncSatF32s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_sat_f32s"](), wasm);
  },
  i64TruncSatF32u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_sat_f32u"](), wasm);
  },
  i64TruncSatF64s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_sat_f64s"](), wasm);
  },
  i64TruncSatF64u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64_trunc_sat_f64u"](), wasm);
  },
  i64x2Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_abs"](), wasm);
  },
  i64x2AllTrue() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_all_true"](), wasm);
  },
  i64x2Bitmask() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_bitmask"](), wasm);
  },
  i64x2ExtendHighI32x4s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_extend_high_i32x4s"](), wasm);
  },
  i64x2ExtendHighI32x4u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_extend_high_i32x4u"](), wasm);
  },
  i64x2ExtendLowI32x4s() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_extend_low_i32x4s"](), wasm);
  },
  i64x2ExtendLowI32x4u() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_extend_low_i32x4u"](), wasm);
  },
  i64x2Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i64x2_neg"](), wasm);
  },
  i8x16Abs() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i8x16_abs"](), wasm);
  },
  i8x16AllTrue() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i8x16_all_true"](), wasm);
  },
  i8x16Bitmask() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i8x16_bitmask"](), wasm);
  },
  i8x16Neg() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i8x16_neg"](), wasm);
  },
  i8x16Popcnt() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__i8x16_popcnt"](), wasm);
  },
  v128AnyTrue() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__v128_any_true"](), wasm);
  },
  v128Not() {
    return liftValue({ kind: "named", brand: "lib.UnaryOp", showExport: "__js_show_lib_UnaryOp" }, wasm["lib__UnaryOp__v128_not"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_UnaryOp"](value);
  },
});

export const V128LoadLaneOp = Object.freeze({
  v128Load16Lane() {
    return liftValue({ kind: "named", brand: "lib.V128LoadLaneOp", showExport: "__js_show_lib_V128LoadLaneOp" }, wasm["lib__V128LoadLaneOp__v128_load16_lane"](), wasm);
  },
  v128Load32Lane() {
    return liftValue({ kind: "named", brand: "lib.V128LoadLaneOp", showExport: "__js_show_lib_V128LoadLaneOp" }, wasm["lib__V128LoadLaneOp__v128_load32_lane"](), wasm);
  },
  v128Load64Lane() {
    return liftValue({ kind: "named", brand: "lib.V128LoadLaneOp", showExport: "__js_show_lib_V128LoadLaneOp" }, wasm["lib__V128LoadLaneOp__v128_load64_lane"](), wasm);
  },
  v128Load8Lane() {
    return liftValue({ kind: "named", brand: "lib.V128LoadLaneOp", showExport: "__js_show_lib_V128LoadLaneOp" }, wasm["lib__V128LoadLaneOp__v128_load8_lane"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_V128LoadLaneOp"](value);
  },
});

export const V128ShiftOp = Object.freeze({
  i16x8Shl() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i16x8_shl"](), wasm);
  },
  i16x8ShrS() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i16x8_shr_s"](), wasm);
  },
  i16x8ShrU() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i16x8_shr_u"](), wasm);
  },
  i32x4Shl() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i32x4_shl"](), wasm);
  },
  i32x4ShrS() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i32x4_shr_s"](), wasm);
  },
  i32x4ShrU() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i32x4_shr_u"](), wasm);
  },
  i64x2Shl() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i64x2_shl"](), wasm);
  },
  i64x2ShrS() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i64x2_shr_s"](), wasm);
  },
  i64x2ShrU() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i64x2_shr_u"](), wasm);
  },
  i8x16Shl() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i8x16_shl"](), wasm);
  },
  i8x16ShrS() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i8x16_shr_s"](), wasm);
  },
  i8x16ShrU() {
    return liftValue({ kind: "named", brand: "lib.V128ShiftOp", showExport: "__js_show_lib_V128ShiftOp" }, wasm["lib__V128ShiftOp__i8x16_shr_u"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_V128ShiftOp"](value);
  },
});

export const V128StoreLaneOp = Object.freeze({
  v128Store16Lane() {
    return liftValue({ kind: "named", brand: "lib.V128StoreLaneOp", showExport: "__js_show_lib_V128StoreLaneOp" }, wasm["lib__V128StoreLaneOp__v128_store16_lane"](), wasm);
  },
  v128Store32Lane() {
    return liftValue({ kind: "named", brand: "lib.V128StoreLaneOp", showExport: "__js_show_lib_V128StoreLaneOp" }, wasm["lib__V128StoreLaneOp__v128_store32_lane"](), wasm);
  },
  v128Store64Lane() {
    return liftValue({ kind: "named", brand: "lib.V128StoreLaneOp", showExport: "__js_show_lib_V128StoreLaneOp" }, wasm["lib__V128StoreLaneOp__v128_store64_lane"](), wasm);
  },
  v128Store8Lane() {
    return liftValue({ kind: "named", brand: "lib.V128StoreLaneOp", showExport: "__js_show_lib_V128StoreLaneOp" }, wasm["lib__V128StoreLaneOp__v128_store8_lane"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_V128StoreLaneOp"](value);
  },
});

export const V128TernaryOp = Object.freeze({
  f32x4RelaxedMadd() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__f32x4_relaxed_madd"](), wasm);
  },
  f32x4RelaxedNmadd() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__f32x4_relaxed_nmadd"](), wasm);
  },
  f64x2RelaxedMadd() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__f64x2_relaxed_madd"](), wasm);
  },
  f64x2RelaxedNmadd() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__f64x2_relaxed_nmadd"](), wasm);
  },
  i16x8RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__i16x8_relaxed_laneselect"](), wasm);
  },
  i32x4RelaxedDotI8x16i7x16AddS() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__i32x4_relaxed_dot_i8x16i7x16_add_s"](), wasm);
  },
  i32x4RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__i32x4_relaxed_laneselect"](), wasm);
  },
  i64x2RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__i64x2_relaxed_laneselect"](), wasm);
  },
  i8x16RelaxedLaneselect() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__i8x16_relaxed_laneselect"](), wasm);
  },
  v128Bitselect() {
    return liftValue({ kind: "named", brand: "lib.V128TernaryOp", showExport: "__js_show_lib_V128TernaryOp" }, wasm["lib__V128TernaryOp__v128_bitselect"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_V128TernaryOp"](value);
  },
});

export const ValType = Object.freeze({
  anyref() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__anyref"](), wasm);
  },
  bottom() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__bottom"](), wasm);
  },
  eqrefNull() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__eqref_null"](), wasm);
  },
  externref() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__externref"](), wasm);
  },
  f32() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__f32"](), wasm);
  },
  f64() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__f64"](), wasm);
  },
  funcref() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__funcref"](), wasm);
  },
  i31ref() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__i31ref"](), wasm);
  },
  i31refNullable() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__i31ref_nullable"](), wasm);
  },
  i32() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__i32"](), wasm);
  },
  i64() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__i64"](), wasm);
  },
  isRefType(arg0) {
    return liftValue({ kind: "bool" }, wasm["lib__ValType__is_ref_type"](lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg0, wasm)), wasm);
  },
  numType(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__num_type"](lowerValue({ kind: "named", brand: "lib.NumType", showExport: "__js_show_lib_NumType" }, arg0, wasm)), wasm);
  },
  refArrayNonnull(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__ref_array_nonnull"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  refArrayNullable(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__ref_array_nullable"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  refNull(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__ref_null"](lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg0, wasm)), wasm);
  },
  refNullArrayOf(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__ref_null_array_of"](lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg0, wasm)), wasm);
  },
  refNullExn() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__ref_null_exn"](), wasm);
  },
  refType(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__ref_type"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm)), wasm);
  },
  v128() {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["lib__ValType__v128"](), wasm);
  },
  show(value) {
    return wasm["__js_show_lib_ValType"](value);
  },
});
