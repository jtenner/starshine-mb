import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function libModuleToWat(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wat__lib_module_to_wat"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function lookupKeyword(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_100_none","some":"__js_option_100_some","isSome":"__js_option_100_is_some","unwrap":"__js_option_100_unwrap"}, item: { kind: "named", brand: "wast.TokenType", showExport: "__js_show_wast_TokenType" } }, wasm["wat__lookup_keyword"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function moduleToWat(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wat__module_to_wat"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function moduleToWatWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wat__module_to_wat_with_context"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: null }, arg1, wasm)), wasm);
}

export function runWatRoundtripFuzz(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_51_is_ok","unwrapOk":"__js_result_51_unwrap_ok","unwrapErr":"__js_result_51_unwrap_err"}, ok: { kind: "named", brand: "wat.WatRoundtripFuzzStats", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["wat__run_wat_roundtrip_fuzz"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function scriptToWat(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wat__script_to_wat"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm)), wasm);
}

export function scriptToWatWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wat__script_to_wat_with_context"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: null }, arg1, wasm)), wasm);
}

export function watToModule(arg0, filename) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_49_is_ok","unwrapOk":"__js_result_49_unwrap_ok","unwrapErr":"__js_result_49_unwrap_err"}, ok: { kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, err: { kind: "string", moonType: "String" } }, wasm["wat__wat_to_module"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export function watToScript(arg0, filename) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_50_is_ok","unwrapOk":"__js_result_50_unwrap_ok","unwrapErr":"__js_result_50_unwrap_err"}, ok: { kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, err: { kind: "string", moonType: "String" } }, wasm["wat__wat_to_script"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export const WatRoundtripFuzzStats = Object.freeze({
});
