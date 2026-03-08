import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function lookupKeyword(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_40_none","some":"__js_option_40_some","isSome":"__js_option_40_is_some","unwrap":"__js_option_40_unwrap"}, item: { kind: "named", brand: "wast.TokenType", showExport: "__js_show_wast_TokenType" } }, wasm["wat__lookup_keyword"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
}

export function moduleToWat(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wat__module_to_wat"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function moduleToWatWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wat__module_to_wat_with_context"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg1, wasm)), wasm);
}

export function scriptToWat(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wat__script_to_wat"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm)), wasm);
}

export function scriptToWatWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wat__script_to_wat_with_context"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg1, wasm)), wasm);
}

export function watToModule(arg0, filename) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, err: { kind: "string" } }, wasm["wat__wat_to_module__arity_1"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, err: { kind: "string" } }, wasm["wat__wat_to_module"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, filename, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for wat.watToModule.");
  }
}

export function watToScript(arg0, filename) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_23_is_ok","unwrapOk":"__js_result_23_unwrap_ok","unwrapErr":"__js_result_23_unwrap_err"}, ok: { kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, err: { kind: "string" } }, wasm["wat__wat_to_script__arity_1"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_23_is_ok","unwrapOk":"__js_result_23_unwrap_ok","unwrapErr":"__js_result_23_unwrap_err"}, ok: { kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, err: { kind: "string" } }, wasm["wat__wat_to_script"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, filename, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for wat.watToScript.");
  }
}
