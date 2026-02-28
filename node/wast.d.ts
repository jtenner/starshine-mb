import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { Module, PrettyPrintContext } from "./lib.js";

export type BlockType = OpaqueHandle<"wast.BlockType">;
export type CatchClause = OpaqueHandle<"wast.CatchClause">;
export type DataSegment = OpaqueHandle<"wast.DataSegment">;
export type ElemInitExpr = OpaqueHandle<"wast.ElemInitExpr">;
export type ElemSegment = OpaqueHandle<"wast.ElemSegment">;
export type ErrorLevel = OpaqueHandle<"wast.ErrorLevel">;
export type Export = OpaqueHandle<"wast.Export">;
export type ExportDesc = OpaqueHandle<"wast.ExportDesc">;
export type Func = OpaqueHandle<"wast.Func">;
export type FuncType = OpaqueHandle<"wast.FuncType">;
export type Global = OpaqueHandle<"wast.Global">;
export type GlobalType = OpaqueHandle<"wast.GlobalType">;
export type HeapTypeRef = OpaqueHandle<"wast.HeapTypeRef">;
export type Import = OpaqueHandle<"wast.Import">;
export type ImportDesc = OpaqueHandle<"wast.ImportDesc">;
export type Index = OpaqueHandle<"wast.Index">;
export type InlineExport = OpaqueHandle<"wast.InlineExport">;
export type Instruction = OpaqueHandle<"wast.Instruction">;
export type KeywordTable = OpaqueHandle<"wast.KeywordTable">;
export type LegacyCatchClause = OpaqueHandle<"wast.LegacyCatchClause">;
export type LexerError = OpaqueHandle<"wast.LexerError">;
export type LexerState = OpaqueHandle<"wast.LexerState">;
export type Limits = OpaqueHandle<"wast.Limits">;
export type Literal = OpaqueHandle<"wast.Literal">;
export type LiteralType = OpaqueHandle<"wast.LiteralType">;
export type Local = OpaqueHandle<"wast.Local">;
export type Location = OpaqueHandle<"wast.Location">;
export type MemArg = OpaqueHandle<"wast.MemArg">;
export type Memory = OpaqueHandle<"wast.Memory">;
export type MemoryType = OpaqueHandle<"wast.MemoryType">;
export type Module = OpaqueHandle<"wast.Module">;
export type ModuleField = OpaqueHandle<"wast.ModuleField">;
export type Opcode = OpaqueHandle<"wast.Opcode">;
export type ParseError = OpaqueHandle<"wast.ParseError">;
export type ParserError = OpaqueHandle<"wast.ParserError">;
export type ShuffleLanes = OpaqueHandle<"wast.ShuffleLanes">;
export type SimdShape = OpaqueHandle<"wast.SimdShape">;
export type Start = OpaqueHandle<"wast.Start">;
export type Table = OpaqueHandle<"wast.Table">;
export type TableType = OpaqueHandle<"wast.TableType">;
export type Tag = OpaqueHandle<"wast.Tag">;
export type Token = OpaqueHandle<"wast.Token">;
export type TokenType = OpaqueHandle<"wast.TokenType">;
export type TokenValue = OpaqueHandle<"wast.TokenValue">;
export type TypeDef = OpaqueHandle<"wast.TypeDef">;
export type TypeUse = OpaqueHandle<"wast.TypeUse">;
export type V128Const = OpaqueHandle<"wast.V128Const">;
export type ValueType = OpaqueHandle<"wast.ValueType">;
export type WastAction = OpaqueHandle<"wast.WastAction">;
export type WastActionType = OpaqueHandle<"wast.WastActionType">;
export type WastCommand = OpaqueHandle<"wast.WastCommand">;
export type WastLexer = OpaqueHandle<"wast.WastLexer">;
export type WastModuleDef = OpaqueHandle<"wast.WastModuleDef">;
export type WastParser = OpaqueHandle<"wast.WastParser">;
export type WastResult = OpaqueHandle<"wast.WastResult">;
export type WastScript = OpaqueHandle<"wast.WastScript">;
export type WastSpecFileReport = OpaqueHandle<"wast.WastSpecFileReport">;
export type WastSpecFileStatus = OpaqueHandle<"wast.WastSpecFileStatus">;
export type WastSpecRunSummary = OpaqueHandle<"wast.WastSpecRunSummary">;
export type WastTextError = OpaqueHandle<"wast.WastTextError">;
export type WastValue = OpaqueHandle<"wast.WastValue">;

export function lookupKeyword(arg0: string): TokenType | null;
export function moduleToWast(arg0: Module): StarshineResult<string, string>;
export function moduleToWastWithContext(arg0: Module, arg1: PrettyPrintContext): StarshineResult<string, string>;
export function runWastSpecFile(arg0: string, arg1: string): WastSpecFileReport;
export function runWastSpecSuite(arg0: Array<[string, string]>): WastSpecRunSummary;
export function scriptToWast(arg0: WastScript): StarshineResult<string, string>;
export function scriptToWastWithContext(arg0: WastScript, arg1: PrettyPrintContext): StarshineResult<string, string>;
export function wastAstToBinaryModule(arg0: Module): StarshineResult<Module, string>;
export function wastTextBinaryRoundtrip(arg0: string, filename?: string): StarshineResult<[string, Module], string>;
export function wastToBinaryModule(arg0: string, filename?: string): StarshineResult<Module, string>;
export function wastToModule(arg0: string, filename?: string): StarshineResult<Module, string>;
export function wastToScript(arg0: string, filename?: string): StarshineResult<WastScript, string>;

export const BlockType: {
  show(value: BlockType): string;
};

export const CatchClause: {
  show(value: CatchClause): string;
};

export const DataSegment: {
  show(value: DataSegment): string;
};

export const ElemInitExpr: {
  show(value: ElemInitExpr): string;
};

export const ElemSegment: {
  show(value: ElemSegment): string;
};

export const ErrorLevel: {
  show(value: ErrorLevel): string;
};

export const Export: {
  show(value: Export): string;
};

export const ExportDesc: {
  show(value: ExportDesc): string;
};

export const Func: {
  show(value: Func): string;
};

export const FuncType: {
  show(value: FuncType): string;
};

export const Global: {
  show(value: Global): string;
};

export const GlobalType: {
  show(value: GlobalType): string;
};

export const HeapTypeRef: {
  show(value: HeapTypeRef): string;
};

export const Import: {
  show(value: Import): string;
};

export const ImportDesc: {
  show(value: ImportDesc): string;
};

export const Index: {
  show(value: Index): string;
};

export const InlineExport: {
  show(value: InlineExport): string;
};

export const Instruction: {
  show(value: Instruction): string;
};

export const KeywordTable: {
  lookup(arg0: KeywordTable, arg1: string): TokenType | null;
};

export const LegacyCatchClause: {
  show(value: LegacyCatchClause): string;
};

export const LexerError: {
  show(value: LexerError): string;
};

export const LexerState: {
};

export const Limits: {
  show(value: Limits): string;
};

export const Literal: {
  show(value: Literal): string;
};

export const LiteralType: {
  show(value: LiteralType): string;
};

export const Local: {
  show(value: Local): string;
};

export const Location: {
  show(value: Location): string;
};

export const MemArg: {
  show(value: MemArg): string;
};

export const Memory: {
  show(value: Memory): string;
};

export const MemoryType: {
  inner(arg0: MemoryType): Limits;
  show(value: MemoryType): string;
};

export const Module: {
  show(value: Module): string;
};

export const ModuleField: {
  show(value: ModuleField): string;
};

export const Opcode: {
  show(value: Opcode): string;
};

export const ParseError: {
  show(value: ParseError): string;
};

export const ParserError: {
  show(value: ParserError): string;
};

export const ShuffleLanes: {
  show(value: ShuffleLanes): string;
};

export const SimdShape: {
  show(value: SimdShape): string;
};

export const Start: {
  show(value: Start): string;
};

export const Table: {
  show(value: Table): string;
};

export const TableType: {
  show(value: TableType): string;
};

export const Tag: {
  show(value: Tag): string;
};

export const Token: {
  show(value: Token): string;
};

export const TokenType: {
  show(value: TokenType): string;
};

export const TokenValue: {
  show(value: TokenValue): string;
};

export const TypeDef: {
  show(value: TypeDef): string;
};

export const TypeUse: {
  show(value: TypeUse): string;
};

export const V128Const: {
  show(value: V128Const): string;
};

export const ValueType: {
  show(value: ValueType): string;
};

export const WastAction: {
  show(value: WastAction): string;
};

export const WastActionType: {
  show(value: WastActionType): string;
};

export const WastCommand: {
  show(value: WastCommand): string;
};

export const WastLexer: {
  getErrors(arg0: WastLexer): Array<LexerError>;
  getToken(arg0: WastLexer): Token;
  hasErrors(arg0: WastLexer): boolean;
  new(arg0: Uint8Array, arg1: string): WastLexer;
};

export const WastModuleDef: {
  show(value: WastModuleDef): string;
};

export const WastParser: {
  getErrors(arg0: WastParser): Array<ParseError>;
  hasErrors(arg0: WastParser): boolean;
  new(arg0: WastLexer): WastParser;
  parseModule(...args: never[]): never;
  parseScript(...args: never[]): never;
};

export const WastResult: {
  show(value: WastResult): string;
};

export const WastScript: {
  show(value: WastScript): string;
};

export const WastSpecFileReport: {
  show(value: WastSpecFileReport): string;
};

export const WastSpecFileStatus: {
  show(value: WastSpecFileStatus): string;
};

export const WastSpecRunSummary: {
  show(value: WastSpecRunSummary): string;
};

export const WastTextError: {
};

export const WastValue: {
  show(value: WastValue): string;
};
