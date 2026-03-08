import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function descriptorCompatible(arg0, arg1, arg2) {
  return liftValue({ kind: "bool" }, wasm["validate__descriptor_compatible"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg2, wasm)), wasm);
}

export function diff(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_14_is_ok","unwrapOk":"__js_result_14_unwrap_ok","unwrapErr":"__js_result_14_unwrap_err"}, ok: { kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, err: { kind: "string" } }, wasm["validate__diff"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg1, wasm)), wasm);
}

export function emptyEnv() {
  return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__empty_env"](), wasm);
}

export function genSideEffectTinstr(arg0, arg1, labelDepth) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 2:
      return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["validate__gen_side_effect_tinstr__arity_2"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
    case 3:
      return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["validate__gen_side_effect_tinstr"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm), lowerValue({ kind: "number" }, labelDepth, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for validate.genSideEffectTinstr.");
  }
}

export function genTinstrOfType(arg0, arg1) {
  return liftValue({ kind: "named", brand: "lib.TInstr", showExport: "__js_show_lib_TInstr" }, wasm["validate__gen_tinstr_of_type"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg1, wasm)), wasm);
}

export function genValidModule(arg0) {
  return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["validate__gen_valid_module"](lowerValue({ kind: "opaque", brand: "@splitmix.RandomState" }, arg0, wasm)), wasm);
}

export function genValidNumtype(arg0) {
  return liftValue({ kind: "named", brand: "lib.NumType", showExport: "__js_show_lib_NumType" }, wasm["validate__gen_valid_numtype"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm)), wasm);
}

export function genValidResultType(arg0, arg1, arg2) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, wasm["validate__gen_valid_result_type"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.TypeGenerationStrategy", showExport: null }, arg2, wasm)), wasm);
}

export function genValidTfunc(arg0, arg1, arg2) {
  return liftValue({ kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" }, wasm["validate__gen_valid_tfunc"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg2, wasm)), wasm);
}

export function genValidValtype(arg0) {
  return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["validate__gen_valid_valtype"](lowerValue({ kind: "named", brand: "validate.GenValidContext", showExport: null }, arg0, wasm)), wasm);
}

export function toTexpr(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_15_is_ok","unwrapOk":"__js_result_15_unwrap_ok","unwrapErr":"__js_result_15_unwrap_err"}, ok: { kind: "named", brand: "lib.TExpr", showExport: "__js_show_lib_TExpr" }, err: { kind: "string" } }, wasm["validate__to_texpr"](lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateCodesec(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["validate__validate_codesec"](lowerValue({ kind: "option", helper: {"none":"__js_option_29_none","some":"__js_option_29_some","isSome":"__js_option_29_is_some","unwrap":"__js_option_29_unwrap"}, item: { kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" } }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg2, wasm)), wasm);
}

export function validateDatacnt(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["validate__validate_datacnt"](lowerValue({ kind: "option", helper: {"none":"__js_option_28_none","some":"__js_option_28_some","isSome":"__js_option_28_is_some","unwrap":"__js_option_28_unwrap"}, item: { kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" } }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_30_none","some":"__js_option_30_some","isSome":"__js_option_30_is_some","unwrap":"__js_option_30_unwrap"}, item: { kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" } }, arg1, wasm)), wasm);
}

export function validateDatasec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_datasec"](lowerValue({ kind: "option", helper: {"none":"__js_option_30_none","some":"__js_option_30_some","isSome":"__js_option_30_is_some","unwrap":"__js_option_30_unwrap"}, item: { kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateElemsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_elemsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_27_none","some":"__js_option_27_some","isSome":"__js_option_27_is_some","unwrap":"__js_option_27_unwrap"}, item: { kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateExportsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["validate__validate_exportsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateFuncsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_funcsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateGlobalsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_globalsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateImportsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_importsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateMemsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_memsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateModule(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_17_is_ok","unwrapOk":"__js_result_17_unwrap_ok","unwrapErr":"__js_result_17_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "named", brand: "validate.ValidationError", showExport: "__js_show_validate_ValidationError" } }, wasm["validate__validate_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function validateStartsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["validate__validate_startsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateTablesec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_tablesec"](lowerValue({ kind: "option", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateTagsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_tagsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateTypesec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string" } }, wasm["validate__validate_typesec"](lowerValue({ kind: "option", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export const Env = Object.freeze({
  appendRectypeTypes(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__append_rectype_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, arg1, wasm)), wasm);
  },
  descriptorResultType(arg0) {
    return liftValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, wasm["validate__Env__descriptor_result_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm)), wasm);
  },
  expandBlocktype(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_6_new","getters":["__js_tuple_6_get_0","__js_tuple_6_get_1"]}, items: [{ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }] }, err: { kind: "string" } }, wasm["validate__Env__expand_blocktype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg1, wasm)), wasm);
  },
  getCatchLabelTypes(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__Env__get_catch_label_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  getElem(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_32_none","some":"__js_option_32_some","isSome":"__js_option_32_is_some","unwrap":"__js_option_32_unwrap"}, item: { kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" } }, wasm["validate__Env__get_elem"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg1, wasm)), wasm);
  },
  getFunctypeByFuncidx(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_33_none","some":"__js_option_33_some","isSome":"__js_option_33_is_some","unwrap":"__js_option_33_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__get_functype_by_funcidx"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm)), wasm);
  },
  getFunctypeidxByFuncidx(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_34_none","some":"__js_option_34_some","isSome":"__js_option_34_is_some","unwrap":"__js_option_34_unwrap"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, wasm["validate__Env__get_functypeidx_by_funcidx"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm)), wasm);
  },
  getGlobalType(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_35_none","some":"__js_option_35_some","isSome":"__js_option_35_is_some","unwrap":"__js_option_35_unwrap"}, item: { kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" } }, wasm["validate__Env__get_global_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg1, wasm)), wasm);
  },
  getLabel(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__Env__get_label"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  getLabelTypes(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__Env__get_label_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  getLocalType(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_12_none","some":"__js_option_12_some","isSome":"__js_option_12_is_some","unwrap":"__js_option_12_unwrap"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, wasm["validate__Env__get_local_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg1, wasm)), wasm);
  },
  getMemtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_36_none","some":"__js_option_36_some","isSome":"__js_option_36_is_some","unwrap":"__js_option_36_unwrap"}, item: { kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" } }, wasm["validate__Env__get_memtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg1, wasm)), wasm);
  },
  getTableType(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_37_none","some":"__js_option_37_some","isSome":"__js_option_37_is_some","unwrap":"__js_option_37_unwrap"}, item: { kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" } }, wasm["validate__Env__get_table_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm)), wasm);
  },
  getTag(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_38_none","some":"__js_option_38_some","isSome":"__js_option_38_is_some","unwrap":"__js_option_38_unwrap"}, item: { kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" } }, wasm["validate__Env__get_tag"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg1, wasm)), wasm);
  },
  hasData(arg0, arg1) {
    return liftValue({ kind: "bool" }, wasm["validate__Env__has_data"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg1, wasm)), wasm);
  },
  hasFunc(arg0, arg1) {
    return liftValue({ kind: "bool" }, wasm["validate__Env__has_func"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm)), wasm);
  },
  new() {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__new"](), wasm);
  },
  pushData(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_data"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Data", showExport: "__js_show_lib_Data" }, arg1, wasm)), wasm);
  },
  pushElem(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_elem"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" }, arg1, wasm)), wasm);
  },
  pushFunc(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_func"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" }, arg1, wasm)), wasm);
  },
  pushFuncWithTypeidx(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_func_with_typeidx"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_34_none","some":"__js_option_34_some","isSome":"__js_option_34_is_some","unwrap":"__js_option_34_unwrap"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, arg2, wasm)), wasm);
  },
  pushGlobal(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_global"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, arg1, wasm)), wasm);
  },
  pushMem(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_mem"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, arg1, wasm)), wasm);
  },
  pushTable(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_table"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" }, arg1, wasm)), wasm);
  },
  pushTag(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_tag"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, arg1, wasm)), wasm);
  },
  resolveArrayField(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_12_is_ok","unwrapOk":"__js_result_12_unwrap_ok","unwrapErr":"__js_result_12_unwrap_err"}, ok: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, err: { kind: "string" } }, wasm["validate__Env__resolve_array_field"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveComptype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_39_none","some":"__js_option_39_some","isSome":"__js_option_39_is_some","unwrap":"__js_option_39_unwrap"}, item: { kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" } }, wasm["validate__Env__resolve_comptype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveDescriptorTargetRefType(arg0, arg1, arg2) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_14_is_ok","unwrapOk":"__js_result_14_unwrap_ok","unwrapErr":"__js_result_14_unwrap_err"}, ok: { kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, err: { kind: "string" } }, wasm["validate__Env__resolve_descriptor_target_ref_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg2, wasm)), wasm);
  },
  resolveFunctype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_33_none","some":"__js_option_33_some","isSome":"__js_option_33_is_some","unwrap":"__js_option_33_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__resolve_functype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveHeaptypeSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["validate__Env__resolve_heaptype_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  resolveStructFields(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_19_is_ok","unwrapOk":"__js_result_19_unwrap_ok","unwrapErr":"__js_result_19_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_10_new","push":"__js_array_10_push","length":"__js_array_10_length","get":"__js_array_10_get"}, item: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" } }, err: { kind: "string" } }, wasm["validate__Env__resolve_struct_fields"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["validate__Env__resolve_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveTagFunctype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_33_none","some":"__js_option_33_some","isSome":"__js_option_33_is_some","unwrap":"__js_option_33_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__resolve_tag_functype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg1, wasm)), wasm);
  },
  resolveTypeidxSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["validate__Env__resolve_typeidx_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  withElems(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_elems"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_17_new","push":"__js_array_17_push","length":"__js_array_17_length","get":"__js_array_17_get"}, item: { kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" } }, arg1, wasm)), wasm);
  },
  withFuncs(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_funcs"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_30_new","push":"__js_array_30_push","length":"__js_array_30_length","get":"__js_array_30_get"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, arg1, wasm)), wasm);
  },
  withGlobals(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_globals"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_31_new","push":"__js_array_31_push","length":"__js_array_31_length","get":"__js_array_31_get"}, item: { kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" } }, arg1, wasm)), wasm);
  },
  withLabel(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_label"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  withLabels(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_labels"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_32_new","push":"__js_array_32_push","length":"__js_array_32_length","get":"__js_array_32_get"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, arg1, wasm)), wasm);
  },
  withLocals(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_locals"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  withMems(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_mems"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_24_new","push":"__js_array_24_push","length":"__js_array_24_length","get":"__js_array_24_get"}, item: { kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" } }, arg1, wasm)), wasm);
  },
  withModule(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_module"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg1, wasm)), wasm);
  },
  withRectype(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_rectype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, arg1, wasm)), wasm);
  },
  withReturnType(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_return_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, arg1, wasm)), wasm);
  },
  withTables(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_tables"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_33_new","push":"__js_array_33_push","length":"__js_array_33_length","get":"__js_array_33_get"}, item: { kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" } }, arg1, wasm)), wasm);
  },
  withTags(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_tags"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_27_new","push":"__js_array_27_push","length":"__js_array_27_length","get":"__js_array_27_get"}, item: { kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" } }, arg1, wasm)), wasm);
  },
  withTypes(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_11_new","push":"__js_array_11_push","length":"__js_array_11_length","get":"__js_array_11_get"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_Env"](value);
  },
});

export const GenValidContext = Object.freeze({
});

export const TcResult = Object.freeze({
});

export const TcState = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_TcState"](value);
  },
});

export const TypeGenerationStrategy = Object.freeze({
});

export const ValidationError = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidationError"](value);
  },
});
