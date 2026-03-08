import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function decodeModule(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_1_is_ok","unwrapOk":"__js_result_1_unwrap_ok","unwrapErr":"__js_result_1_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "named", brand: "binary.DecodeError", showExport: "__js_show_binary_DecodeError" } }, wasm["binary__decode_module"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg0, wasm)), wasm);
}

export function decodeModuleWithDetail(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_2_is_ok","unwrapOk":"__js_result_2_unwrap_ok","unwrapErr":"__js_result_2_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_1_new","getters":["__js_tuple_1_get_0","__js_tuple_1_get_1"]}, items: [{ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, { kind: "number" }] }, err: { kind: "named", brand: "binary.ModuleDecodeErrorDetail", showExport: "__js_show_binary_ModuleDecodeErrorDetail" } }, wasm["binary__decode_module_with_detail"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
}

export function encodeModule(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_3_is_ok","unwrapOk":"__js_result_3_unwrap_ok","unwrapErr":"__js_result_3_unwrap_err"}, ok: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, err: { kind: "named", brand: "binary.EncodeError", showExport: "__js_show_binary_EncodeError" } }, wasm["binary__encode_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function sizeSigned(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_4_is_ok","unwrapOk":"__js_result_4_unwrap_ok","unwrapErr":"__js_result_4_unwrap_err"}, ok: { kind: "number" }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__size_signed"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
}

export function sizeUnsigned(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_4_is_ok","unwrapOk":"__js_result_4_unwrap_ok","unwrapErr":"__js_result_4_unwrap_err"}, ok: { kind: "number" }, err: { kind: "named", brand: "binary.BinaryEncodeError", showExport: "__js_show_binary_BinaryEncodeError" } }, wasm["binary__size_unsigned"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm)), wasm);
}

export const BinaryDecodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_BinaryDecodeError"](value);
  },
});

export const BinaryEncodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_BinaryEncodeError"](value);
  },
});

export const DecodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_DecodeError"](value);
  },
});

export const EncodeError = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_EncodeError"](value);
  },
});

export const ModuleDecodeErrorDetail = Object.freeze({
  show(value) {
    return wasm["__js_show_binary_ModuleDecodeErrorDetail"](value);
  },
});
