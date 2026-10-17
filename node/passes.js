import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function optimizeModule(arg0, arg1, optimizeLevel, shrinkLevel) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string", moonType: "String" } }, wasm["ffi_bridge__optimize_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg1, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, optimizeLevel, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, shrinkLevel, wasm)), wasm);
}
