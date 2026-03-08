import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function lookupKeyword(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_40_none","some":"__js_option_40_some","isSome":"__js_option_40_is_some","unwrap":"__js_option_40_unwrap"}, item: { kind: "named", brand: "wast.TokenType", showExport: "__js_show_wast_TokenType" } }, wasm["wast__lookup_keyword"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
}

export function moduleToWast(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wast__module_to_wast"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function moduleToWastWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wast__module_to_wast_with_context"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg1, wasm)), wasm);
}

export function runWastSpecFile(arg0, arg1) {
  return liftValue({ kind: "named", brand: "wast.WastSpecFileReport", showExport: "__js_show_wast_WastSpecFileReport" }, wasm["wast__run_wast_spec_file"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, arg1, wasm)), wasm);
}

export function runWastSpecSuite(arg0) {
  return liftValue({ kind: "named", brand: "wast.WastSpecRunSummary", showExport: "__js_show_wast_WastSpecRunSummary" }, wasm["wast__run_wast_spec_suite"](lowerValue({ kind: "array", helper: {"new":"__js_array_4_new","push":"__js_array_4_push","length":"__js_array_4_length","get":"__js_array_4_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_4_new","getters":["__js_tuple_4_get_0","__js_tuple_4_get_1"]}, items: [{ kind: "string" }, { kind: "string" }] } }, arg0, wasm)), wasm);
}

export function scriptToWast(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wast__script_to_wast"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm)), wasm);
}

export function scriptToWastWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_20_is_ok","unwrapOk":"__js_result_20_unwrap_ok","unwrapErr":"__js_result_20_unwrap_err"}, ok: { kind: "string" }, err: { kind: "string" } }, wasm["wast__script_to_wast_with_context"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: "__js_show_lib_PrettyPrintContext" }, arg1, wasm)), wasm);
}

export function wastAstToBinaryModule(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_13_is_ok","unwrapOk":"__js_result_13_unwrap_ok","unwrapErr":"__js_result_13_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string" } }, wasm["wast__wast_ast_to_binary_module"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function wastTextBinaryRoundtrip(arg0, filename) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_21_is_ok","unwrapOk":"__js_result_21_unwrap_ok","unwrapErr":"__js_result_21_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_7_new","getters":["__js_tuple_7_get_0","__js_tuple_7_get_1"]}, items: [{ kind: "string" }, { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }] }, err: { kind: "string" } }, wasm["wast__wast_text_binary_roundtrip__arity_1"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_21_is_ok","unwrapOk":"__js_result_21_unwrap_ok","unwrapErr":"__js_result_21_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_7_new","getters":["__js_tuple_7_get_0","__js_tuple_7_get_1"]}, items: [{ kind: "string" }, { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }] }, err: { kind: "string" } }, wasm["wast__wast_text_binary_roundtrip"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, filename, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for wast.wastTextBinaryRoundtrip.");
  }
}

export function wastToBinaryModule(arg0, filename) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_13_is_ok","unwrapOk":"__js_result_13_unwrap_ok","unwrapErr":"__js_result_13_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string" } }, wasm["wast__wast_to_binary_module__arity_1"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_13_is_ok","unwrapOk":"__js_result_13_unwrap_ok","unwrapErr":"__js_result_13_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string" } }, wasm["wast__wast_to_binary_module"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, filename, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for wast.wastToBinaryModule.");
  }
}

export function wastToModule(arg0, filename) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, err: { kind: "string" } }, wasm["wast__wast_to_module__arity_1"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, err: { kind: "string" } }, wasm["wast__wast_to_module"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, filename, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for wast.wastToModule.");
  }
}

export function wastToScript(arg0, filename) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_23_is_ok","unwrapOk":"__js_result_23_unwrap_ok","unwrapErr":"__js_result_23_unwrap_err"}, ok: { kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, err: { kind: "string" } }, wasm["wast__wast_to_script__arity_1"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_23_is_ok","unwrapOk":"__js_result_23_unwrap_ok","unwrapErr":"__js_result_23_unwrap_err"}, ok: { kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, err: { kind: "string" } }, wasm["wast__wast_to_script"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, filename, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for wast.wastToScript.");
  }
}

export const BlockType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_BlockType"](value);
  },
});

export const CatchClause = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_CatchClause"](value);
  },
});

export const DataSegment = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_DataSegment"](value);
  },
});

export const ElemInitExpr = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ElemInitExpr"](value);
  },
});

export const ElemSegment = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ElemSegment"](value);
  },
});

export const ErrorLevel = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ErrorLevel"](value);
  },
});

export const Export = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Export"](value);
  },
});

export const ExportDesc = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ExportDesc"](value);
  },
});

export const Func = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Func"](value);
  },
});

export const FuncType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_FuncType"](value);
  },
});

export const Global = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Global"](value);
  },
});

export const GlobalType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_GlobalType"](value);
  },
});

export const HeapTypeRef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_HeapTypeRef"](value);
  },
});

export const Import = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Import"](value);
  },
});

export const ImportDesc = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ImportDesc"](value);
  },
});

export const Index = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Index"](value);
  },
});

export const InlineExport = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_InlineExport"](value);
  },
});

export const Instruction = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Instruction"](value);
  },
});

export const KeywordTable = Object.freeze({
  lookup(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_40_none","some":"__js_option_40_some","isSome":"__js_option_40_is_some","unwrap":"__js_option_40_unwrap"}, item: { kind: "named", brand: "wast.TokenType", showExport: "__js_show_wast_TokenType" } }, wasm["wast__KeywordTable__lookup"](lowerValue({ kind: "named", brand: "wast.KeywordTable", showExport: null }, arg0, wasm), lowerValue({ kind: "string" }, arg1, wasm)), wasm);
  },
});

export const LegacyCatchClause = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_LegacyCatchClause"](value);
  },
});

export const LexerError = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_LexerError"](value);
  },
});

export const LexerState = Object.freeze({
});

export const Limits = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Limits"](value);
  },
});

export const Literal = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Literal"](value);
  },
});

export const LiteralType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_LiteralType"](value);
  },
});

export const Local = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Local"](value);
  },
});

export const Location = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Location"](value);
  },
});

export const MemArg = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_MemArg"](value);
  },
});

export const Memory = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Memory"](value);
  },
});

export const MemoryType = Object.freeze({
  inner(arg0) {
    return liftValue({ kind: "named", brand: "wast.Limits", showExport: "__js_show_wast_Limits" }, wasm["wast__MemoryType__inner"](lowerValue({ kind: "named", brand: "wast.MemoryType", showExport: "__js_show_wast_MemoryType" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_wast_MemoryType"](value);
  },
});

export const Module = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Module"](value);
  },
});

export const ModuleField = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ModuleField"](value);
  },
});

export const Opcode = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Opcode"](value);
  },
});

export const ParseError = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ParseError"](value);
  },
});

export const ParserError = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ParserError"](value);
  },
});

export const ShuffleLanes = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ShuffleLanes"](value);
  },
});

export const SimdShape = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_SimdShape"](value);
  },
});

export const Start = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Start"](value);
  },
});

export const Table = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Table"](value);
  },
});

export const TableType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TableType"](value);
  },
});

export const Tag = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Tag"](value);
  },
});

export const Token = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Token"](value);
  },
});

export const TokenType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TokenType"](value);
  },
});

export const TokenValue = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TokenValue"](value);
  },
});

export const TypeDef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TypeDef"](value);
  },
});

export const TypeUse = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TypeUse"](value);
  },
});

export const V128Const = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_V128Const"](value);
  },
});

export const ValueType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ValueType"](value);
  },
});

export const WastAction = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastAction"](value);
  },
});

export const WastActionType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastActionType"](value);
  },
});

export const WastCommand = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastCommand"](value);
  },
});

export const WastLexer = Object.freeze({
  getErrors(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_34_new","push":"__js_array_34_push","length":"__js_array_34_length","get":"__js_array_34_get"}, item: { kind: "named", brand: "wast.LexerError", showExport: "__js_show_wast_LexerError" } }, wasm["wast__WastLexer__get_errors"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  getToken(arg0) {
    return liftValue({ kind: "named", brand: "wast.Token", showExport: "__js_show_wast_Token" }, wasm["wast__WastLexer__get_token"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  hasErrors(arg0) {
    return liftValue({ kind: "bool" }, wasm["wast__WastLexer__has_errors"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, wasm["wast__WastLexer__new"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg0, wasm), lowerValue({ kind: "string" }, arg1, wasm)), wasm);
  },
});

export const WastModuleDef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastModuleDef"](value);
  },
});

export const WastParser = Object.freeze({
  getErrors(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_35_new","push":"__js_array_35_push","length":"__js_array_35_length","get":"__js_array_35_get"}, item: { kind: "named", brand: "wast.ParseError", showExport: "__js_show_wast_ParseError" } }, wasm["wast__WastParser__get_errors"](lowerValue({ kind: "named", brand: "wast.WastParser", showExport: null }, arg0, wasm)), wasm);
  },
  hasErrors(arg0) {
    return liftValue({ kind: "bool" }, wasm["wast__WastParser__has_errors"](lowerValue({ kind: "named", brand: "wast.WastParser", showExport: null }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "wast.WastParser", showExport: null }, wasm["wast__WastParser__new"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  parseModule: unsupportedExport("wast.WastParser.parseModule", "Exports with `raise` effects are not available through the wasm-gc adapter."),
  parseScript: unsupportedExport("wast.WastParser.parseScript", "Exports with `raise` effects are not available through the wasm-gc adapter."),
});

export const WastResult = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastResult"](value);
  },
});

export const WastScript = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastScript"](value);
  },
});

export const WastSpecFileReport = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastSpecFileReport"](value);
  },
});

export const WastSpecFileStatus = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastSpecFileStatus"](value);
  },
});

export const WastSpecRunSummary = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastSpecRunSummary"](value);
  },
});

export const WastTextError = Object.freeze({
});

export const WastValue = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastValue"](value);
  },
});
