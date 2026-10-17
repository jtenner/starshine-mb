import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function compilerFactModuleOpcodeOffsets(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_1_is_ok","unwrapOk":"__js_result_1_unwrap_ok","unwrapErr":"__js_result_1_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "number", moonType: "UInt" } } }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__compiler_fact_module_opcode_offsets"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function compilerFactModuleOpcodeSites(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_2_is_ok","unwrapOk":"__js_result_2_unwrap_ok","unwrapErr":"__js_result_2_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_3_new","push":"__js_array_3_push","length":"__js_array_3_length","get":"__js_array_3_get"}, item: { kind: "array", helper: {"new":"__js_array_4_new","push":"__js_array_4_push","length":"__js_array_4_length","get":"__js_array_4_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_1_new","getters":["__js_tuple_1_get_0","__js_tuple_1_get_1"]}, items: [{ kind: "number", moonType: "UInt" }, { kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }] } } }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__compiler_fact_module_opcode_sites"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function compilerFactOpcodeOffsets(arg0, stringrefs) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_3_is_ok","unwrapOk":"__js_result_3_unwrap_ok","unwrapErr":"__js_result_3_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "number", moonType: "UInt" } }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__compiler_fact_opcode_offsets"](lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_5_new","push":"__js_array_5_push","length":"__js_array_5_length","get":"__js_array_5_get"}, item: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} } } } }, stringrefs, wasm)), wasm);
}

export function compilerFactOpcodeSites(arg0, stringrefs) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_4_is_ok","unwrapOk":"__js_result_4_unwrap_ok","unwrapErr":"__js_result_4_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_4_new","push":"__js_array_4_push","length":"__js_array_4_length","get":"__js_array_4_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_1_new","getters":["__js_tuple_1_get_0","__js_tuple_1_get_1"]}, items: [{ kind: "number", moonType: "UInt" }, { kind: "named", brand: "lib.Instruction", showExport: "__js_show_lib_Instruction" }] } }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__compiler_fact_opcode_sites"](lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_5_new","push":"__js_array_5_push","length":"__js_array_5_length","get":"__js_array_5_get"}, item: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} } } } }, stringrefs, wasm)), wasm);
}

export function decodeModule(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_5_is_ok","unwrapOk":"__js_result_5_unwrap_ok","unwrapErr":"__js_result_5_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "named", brand: "binary.DecodeError", showExport: "__js_show_binary_DecodeError" } }, wasm["binary__decode_module"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm)), wasm);
}

export function decodeModuleWithDetail(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_6_is_ok","unwrapOk":"__js_result_6_unwrap_ok","unwrapErr":"__js_result_6_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_2_new","getters":["__js_tuple_2_get_0","__js_tuple_2_get_1"]}, items: [{ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, { kind: "number", moonType: "Int" }] }, err: { kind: "named", brand: "binary.ModuleDecodeErrorDetail", showExport: null } }, wasm["binary__decode_module_with_detail"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
}

export function encodeModule(arg0, compactImports) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_7_is_ok","unwrapOk":"__js_result_7_unwrap_ok","unwrapErr":"__js_result_7_unwrap_err"}, ok: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, err: { kind: "named", brand: "binary.EncodeError", showExport: "__js_show_binary_EncodeError" } }, wasm["binary__encode_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, compactImports, wasm)), wasm);
}

export function encodedModuleSizes(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_8_is_ok","unwrapOk":"__js_result_8_unwrap_ok","unwrapErr":"__js_result_8_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_3_new","getters":["__js_tuple_3_get_0","__js_tuple_3_get_1"]}, items: [{ kind: "number", moonType: "Int" }, { kind: "number", moonType: "Int" }] }, err: { kind: "named", brand: "binary.EncodeError", showExport: "__js_show_binary_EncodeError" } }, wasm["binary__encoded_module_sizes"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg1, wasm)), wasm);
}

export function sizeSigned(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "number", moonType: "Int" }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__size_signed"](lowerValue({ kind: "bigint", moonType: "Int64" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
}

export function sizeUnsigned(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "number", moonType: "Int" }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__size_unsigned"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
}

export const BinaryDecodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_BinaryDecodeError"](lowerValue({ kind: "named", brand: "binary.BinaryDecodeError" }, value, wasm));
  },
});

export const BinaryEncodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_BinaryEncodeError"](lowerValue({ kind: "named", brand: "binary.BinaryEncodeError" }, value, wasm));
  },
});

export const DecodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_DecodeError"](lowerValue({ kind: "named", brand: "binary.DecodeError" }, value, wasm));
  },
});

export const EncodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_EncodeError"](lowerValue({ kind: "named", brand: "binary.EncodeError" }, value, wasm));
  },
});

export const ModuleDecodeErrorDetail = Object.freeze({
});
