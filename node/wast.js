import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function evaluateWastStaticAssertion(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_45_is_ok","unwrapOk":"__js_result_45_unwrap_ok","unwrapErr":"__js_result_45_unwrap_err"}, ok: { kind: "named", brand: "wast.WastStaticAssertionResult", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["wast__evaluate_wast_static_assertion"](lowerValue({ kind: "named", brand: "wast.WastCommand", showExport: "__js_show_wast_WastCommand" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
}

export function lookupKeyword(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_100_none","some":"__js_option_100_some","isSome":"__js_option_100_is_some","unwrap":"__js_option_100_unwrap"}, item: { kind: "named", brand: "wast.TokenType", showExport: "__js_show_wast_TokenType" } }, wasm["wast__lookup_keyword"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function moduleToWast(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wast__module_to_wast"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function moduleToWastWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wast__module_to_wast_with_context"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: null }, arg1, wasm)), wasm);
}

export function runWastRoundtripFuzz(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_47_is_ok","unwrapOk":"__js_result_47_unwrap_ok","unwrapErr":"__js_result_47_unwrap_err"}, ok: { kind: "named", brand: "wast.WastRoundtripFuzzStats", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["wast__run_wast_roundtrip_fuzz"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function runWastSpecFile(arg0, arg1) {
  return liftValue({ kind: "named", brand: "wast.WastSpecFileReport", showExport: null }, wasm["wast__run_wast_spec_file"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
}

export function runWastSpecSuite(arg0) {
  return liftValue({ kind: "named", brand: "wast.WastSpecRunSummary", showExport: "__js_show_wast_WastSpecRunSummary" }, wasm["wast__run_wast_spec_suite"](lowerValue({ kind: "array", helper: {"new":"__js_array_15_new","push":"__js_array_15_push","length":"__js_array_15_length","get":"__js_array_15_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_6_new","getters":["__js_tuple_6_get_0","__js_tuple_6_get_1"]}, items: [{ kind: "string", moonType: "String" }, { kind: "string", moonType: "String" }] } }, arg0, wasm)), wasm);
}

export function scriptToWast(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wast__script_to_wast"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm)), wasm);
}

export function scriptToWastWithContext(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_46_is_ok","unwrapOk":"__js_result_46_unwrap_ok","unwrapErr":"__js_result_46_unwrap_err"}, ok: { kind: "string", moonType: "String" }, err: { kind: "string", moonType: "String" } }, wasm["wast__script_to_wast_with_context"](lowerValue({ kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.PrettyPrintContext", showExport: null }, arg1, wasm)), wasm);
}

export function wastArbitraryFeatureStats(arg0) {
  return liftValue({ kind: "named", brand: "wast.WastArbitraryFeatureStats", showExport: null }, wasm["wast__wast_arbitrary_feature_stats"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function wastAstToBinaryModule(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string", moonType: "String" } }, wasm["wast__wast_ast_to_binary_module"](lowerValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, arg0, wasm)), wasm);
}

export function wastTextBinaryRoundtrip(arg0, filename) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_48_is_ok","unwrapOk":"__js_result_48_unwrap_ok","unwrapErr":"__js_result_48_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_11_new","getters":["__js_tuple_11_get_0","__js_tuple_11_get_1"]}, items: [{ kind: "string", moonType: "String" }, { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }] }, err: { kind: "string", moonType: "String" } }, wasm["wast__wast_text_binary_roundtrip"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export function wastToBinaryModule(arg0, filename) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string", moonType: "String" } }, wasm["wast__wast_to_binary_module"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export function wastToModule(arg0, filename) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_49_is_ok","unwrapOk":"__js_result_49_unwrap_ok","unwrapErr":"__js_result_49_unwrap_err"}, ok: { kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, err: { kind: "string", moonType: "String" } }, wasm["wast__wast_to_module"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export function wastToScript(arg0, filename) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_50_is_ok","unwrapOk":"__js_result_50_unwrap_ok","unwrapErr":"__js_result_50_unwrap_err"}, ok: { kind: "named", brand: "wast.WastScript", showExport: "__js_show_wast_WastScript" }, err: { kind: "string", moonType: "String" } }, wasm["wast__wast_to_script"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export const Annotation = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Annotation"](lowerValue({ kind: "named", brand: "wast.Annotation" }, value, wasm));
  },
});

export const AtomicOrder = Object.freeze({
});

export const BlockType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_BlockType"](lowerValue({ kind: "named", brand: "wast.BlockType" }, value, wasm));
  },
});

export const CatchClause = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_CatchClause"](lowerValue({ kind: "named", brand: "wast.CatchClause" }, value, wasm));
  },
});

export const DataSegment = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_DataSegment"](lowerValue({ kind: "named", brand: "wast.DataSegment" }, value, wasm));
  },
});

export const ElemInitExpr = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ElemInitExpr"](lowerValue({ kind: "named", brand: "wast.ElemInitExpr" }, value, wasm));
  },
});

export const ElemSegment = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ElemSegment"](lowerValue({ kind: "named", brand: "wast.ElemSegment" }, value, wasm));
  },
});

export const ErrorLevel = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ErrorLevel"](lowerValue({ kind: "named", brand: "wast.ErrorLevel" }, value, wasm));
  },
});

export const Export = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Export"](lowerValue({ kind: "named", brand: "wast.Export" }, value, wasm));
  },
});

export const ExportDesc = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ExportDesc"](lowerValue({ kind: "named", brand: "wast.ExportDesc" }, value, wasm));
  },
});

export const FieldStorage = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_FieldStorage"](lowerValue({ kind: "named", brand: "wast.FieldStorage" }, value, wasm));
  },
});

export const Func = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Func"](lowerValue({ kind: "named", brand: "wast.Func" }, value, wasm));
  },
});

export const FuncType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_FuncType"](lowerValue({ kind: "named", brand: "wast.FuncType" }, value, wasm));
  },
});

export const Global = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Global"](lowerValue({ kind: "named", brand: "wast.Global" }, value, wasm));
  },
});

export const GlobalType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_GlobalType"](lowerValue({ kind: "named", brand: "wast.GlobalType" }, value, wasm));
  },
});

export const HeapTypeRef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_HeapTypeRef"](lowerValue({ kind: "named", brand: "wast.HeapTypeRef" }, value, wasm));
  },
});

export const Import = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Import"](lowerValue({ kind: "named", brand: "wast.Import" }, value, wasm));
  },
});

export const ImportDesc = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ImportDesc"](lowerValue({ kind: "named", brand: "wast.ImportDesc" }, value, wasm));
  },
});

export const Index = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Index"](lowerValue({ kind: "named", brand: "wast.Index" }, value, wasm));
  },
});

export const InlineExport = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_InlineExport"](lowerValue({ kind: "named", brand: "wast.InlineExport" }, value, wasm));
  },
});

export const Instruction = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Instruction"](lowerValue({ kind: "named", brand: "wast.Instruction" }, value, wasm));
  },
});

export const KeywordTable = Object.freeze({
  lookup(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_100_none","some":"__js_option_100_some","isSome":"__js_option_100_is_some","unwrap":"__js_option_100_unwrap"}, item: { kind: "named", brand: "wast.TokenType", showExport: "__js_show_wast_TokenType" } }, wasm["wast__KeywordTable__lookup"](lowerValue({ kind: "named", brand: "wast.KeywordTable", showExport: null }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
});

export const LegacyCatchClause = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_LegacyCatchClause"](lowerValue({ kind: "named", brand: "wast.LegacyCatchClause" }, value, wasm));
  },
});

export const LexerError = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_LexerError"](lowerValue({ kind: "named", brand: "wast.LexerError" }, value, wasm));
  },
});

export const LexerState = Object.freeze({
});

export const Limits = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Limits"](lowerValue({ kind: "named", brand: "wast.Limits" }, value, wasm));
  },
});

export const Literal = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Literal"](lowerValue({ kind: "named", brand: "wast.Literal" }, value, wasm));
  },
});

export const LiteralType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_LiteralType"](lowerValue({ kind: "named", brand: "wast.LiteralType" }, value, wasm));
  },
});

export const Local = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Local"](lowerValue({ kind: "named", brand: "wast.Local" }, value, wasm));
  },
});

export const Location = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Location"](lowerValue({ kind: "named", brand: "wast.Location" }, value, wasm));
  },
});

export const MemArg = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_MemArg"](lowerValue({ kind: "named", brand: "wast.MemArg" }, value, wasm));
  },
});

export const Memory = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Memory"](lowerValue({ kind: "named", brand: "wast.Memory" }, value, wasm));
  },
});

export const MemoryAtomicOp = Object.freeze({
});

export const MemoryType = Object.freeze({
  new(arg0, max, shared, memory64) {
    return liftValue({ kind: "named", brand: "wast.MemoryType", showExport: "__js_show_wast_MemoryType" }, wasm["wast__MemoryType__new"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_17_none","some":"__js_option_17_some","isSome":"__js_option_17_is_some","unwrap":"__js_option_17_unwrap"}, item: { kind: "bigint", moonType: "UInt64" } } }, max, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, shared, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, memory64, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_wast_MemoryType"](lowerValue({ kind: "named", brand: "wast.MemoryType" }, value, wasm));
  },
});

export const Module = Object.freeze({
  new(arg0, id) {
    return liftValue({ kind: "named", brand: "wast.Module", showExport: "__js_show_wast_Module" }, wasm["wast__Module__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_64_new","push":"__js_array_64_push","length":"__js_array_64_length","get":"__js_array_64_get"}, item: { kind: "named", brand: "wast.ModuleField", showExport: "__js_show_wast_ModuleField" } }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } } }, id, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_wast_Module"](lowerValue({ kind: "named", brand: "wast.Module" }, value, wasm));
  },
});

export const ModuleField = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ModuleField"](lowerValue({ kind: "named", brand: "wast.ModuleField" }, value, wasm));
  },
});

export const Opcode = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Opcode"](lowerValue({ kind: "named", brand: "wast.Opcode" }, value, wasm));
  },
});

export const ParseError = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ParseError"](lowerValue({ kind: "named", brand: "wast.ParseError" }, value, wasm));
  },
});

export const ParserError = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ParserError"](lowerValue({ kind: "named", brand: "wast.ParserError" }, value, wasm));
  },
});

export const ShuffleLanes = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ShuffleLanes"](lowerValue({ kind: "named", brand: "wast.ShuffleLanes" }, value, wasm));
  },
});

export const SimdShape = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_SimdShape"](lowerValue({ kind: "named", brand: "wast.SimdShape" }, value, wasm));
  },
});

export const Start = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Start"](lowerValue({ kind: "named", brand: "wast.Start" }, value, wasm));
  },
});

export const StructFieldDef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_StructFieldDef"](lowerValue({ kind: "named", brand: "wast.StructFieldDef" }, value, wasm));
  },
});

export const Table = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Table"](lowerValue({ kind: "named", brand: "wast.Table" }, value, wasm));
  },
});

export const TableType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TableType"](lowerValue({ kind: "named", brand: "wast.TableType" }, value, wasm));
  },
});

export const Tag = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Tag"](lowerValue({ kind: "named", brand: "wast.Tag" }, value, wasm));
  },
});

export const Token = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_Token"](lowerValue({ kind: "named", brand: "wast.Token" }, value, wasm));
  },
});

export const TokenType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TokenType"](lowerValue({ kind: "named", brand: "wast.TokenType" }, value, wasm));
  },
});

export const TokenValue = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TokenValue"](lowerValue({ kind: "named", brand: "wast.TokenValue" }, value, wasm));
  },
});

export const TypeDef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TypeDef"](lowerValue({ kind: "named", brand: "wast.TypeDef" }, value, wasm));
  },
});

export const TypeDefBody = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TypeDefBody"](lowerValue({ kind: "named", brand: "wast.TypeDefBody" }, value, wasm));
  },
});

export const TypeDefMetadata = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TypeDefMetadata"](lowerValue({ kind: "named", brand: "wast.TypeDefMetadata" }, value, wasm));
  },
});

export const TypeUse = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_TypeUse"](lowerValue({ kind: "named", brand: "wast.TypeUse" }, value, wasm));
  },
});

export const V128Const = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_V128Const"](lowerValue({ kind: "named", brand: "wast.V128Const" }, value, wasm));
  },
});

export const ValueType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_ValueType"](lowerValue({ kind: "named", brand: "wast.ValueType" }, value, wasm));
  },
});

export const WastAction = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastAction"](lowerValue({ kind: "named", brand: "wast.WastAction" }, value, wasm));
  },
});

export const WastActionType = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastActionType"](lowerValue({ kind: "named", brand: "wast.WastActionType" }, value, wasm));
  },
});

export const WastArbitraryFeatureStats = Object.freeze({
});

export const WastCommand = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastCommand"](lowerValue({ kind: "named", brand: "wast.WastCommand" }, value, wasm));
  },
});

export const WastLexer = Object.freeze({
  getErrors(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_65_new","push":"__js_array_65_push","length":"__js_array_65_length","get":"__js_array_65_get"}, item: { kind: "named", brand: "wast.LexerError", showExport: "__js_show_wast_LexerError" } }, wasm["wast__WastLexer__get_errors"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  getToken(arg0) {
    return liftValue({ kind: "named", brand: "wast.Token", showExport: "__js_show_wast_Token" }, wasm["wast__WastLexer__get_token"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  hasErrors(arg0) {
    return liftValue({ kind: "bool", moonType: "Bool" }, wasm["wast__WastLexer__has_errors"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, wasm["wast__WastLexer__new"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
});

export const WastModuleDef = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastModuleDef"](lowerValue({ kind: "named", brand: "wast.WastModuleDef" }, value, wasm));
  },
});

export const WastParser = Object.freeze({
  getErrors(arg0) {
    return liftValue({ kind: "array", helper: {"new":"__js_array_66_new","push":"__js_array_66_push","length":"__js_array_66_length","get":"__js_array_66_get"}, item: { kind: "named", brand: "wast.ParseError", showExport: "__js_show_wast_ParseError" } }, wasm["wast__WastParser__get_errors"](lowerValue({ kind: "named", brand: "wast.WastParser", showExport: null }, arg0, wasm)), wasm);
  },
  hasErrors(arg0) {
    return liftValue({ kind: "bool", moonType: "Bool" }, wasm["wast__WastParser__has_errors"](lowerValue({ kind: "named", brand: "wast.WastParser", showExport: null }, arg0, wasm)), wasm);
  },
  new(arg0) {
    return liftValue({ kind: "named", brand: "wast.WastParser", showExport: null }, wasm["wast__WastParser__new"](lowerValue({ kind: "named", brand: "wast.WastLexer", showExport: null }, arg0, wasm)), wasm);
  },
  parseModule: unsupportedExport("wast.WastParser.parseModule", "MoonBit raise effects require an explicit JavaScript error adapter."),
  parseScript: unsupportedExport("wast.WastParser.parseScript", "MoonBit raise effects require an explicit JavaScript error adapter."),
});

export const WastResult = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastResult"](lowerValue({ kind: "named", brand: "wast.WastResult" }, value, wasm));
  },
});

export const WastRoundtripFuzzStats = Object.freeze({
});

export const WastScript = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastScript"](lowerValue({ kind: "named", brand: "wast.WastScript" }, value, wasm));
  },
});

export const WastSpecCommandReport = Object.freeze({
});

export const WastSpecCommandStatus = Object.freeze({
});

export const WastSpecFileReport = Object.freeze({
});

export const WastSpecFileStatus = Object.freeze({
});

export const WastSpecRunSummary = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastSpecRunSummary"](lowerValue({ kind: "named", brand: "wast.WastSpecRunSummary" }, value, wasm));
  },
});

export const WastStaticAssertionKind = Object.freeze({
});

export const WastStaticAssertionResult = Object.freeze({
});

export const WastStaticAssertionStage = Object.freeze({
});

export const WastTextError = Object.freeze({
});

export const WastValue = Object.freeze({
  show(value) {
    return wasm["__js_show_wast_WastValue"](lowerValue({ kind: "named", brand: "wast.WastValue" }, value, wasm));
  },
});
