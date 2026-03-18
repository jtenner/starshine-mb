import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";
import type { BlockType, CodeSec, CompType, Data, DataCntSec, DataIdx, DataSec, Elem, ElemIdx, ElemSec, ExportSec, Expr, FieldType, Func, FuncIdx, FuncSec, FuncType, GlobalIdx, GlobalSec, GlobalType, HeapType, ImportSec, LabelIdx, LocalIdx, Locals, MemIdx, MemSec, MemType, Module, NumType, RecType, RefType, StartSec, SubType, TExpr, TInstr, TableIdx, TableSec, TableType, TagIdx, TagSec, TagType, TypeIdx, TypeSec, ValType } from "./lib.js";

export type Env = OpaqueHandle<"validate.Env">;
export type GenValidContext = OpaqueHandle<"validate.GenValidContext">;
export type TcEscape = OpaqueHandle<"validate.TcEscape">;
export type TcResult = OpaqueHandle<"validate.TcResult">;
export type TcState = OpaqueHandle<"validate.TcState">;
export type TypeGenerationStrategy = OpaqueHandle<"validate.TypeGenerationStrategy">;
export type ValidateInvalidFuzzStats = OpaqueHandle<"validate.ValidateInvalidFuzzStats">;
export type ValidateValidFuzzStats = OpaqueHandle<"validate.ValidateValidFuzzStats">;
export type ValidationDiagnostic = OpaqueHandle<"validate.ValidationDiagnostic">;
export type ValidationError = OpaqueHandle<"validate.ValidationError">;
export type ValidationIssue = OpaqueHandle<"validate.ValidationIssue">;

export function descriptorCompatible(arg0: RefType, arg1: RefType, arg2: Env): boolean;
export function diff(arg0: RefType, arg1: RefType): StarshineResult<RefType, string>;
export function emptyEnv(): Env;
export function genSideEffectTinstr(arg0: GenValidContext, arg1: number, labelDepth?: number): TInstr;
export function genTinstrOfType(arg0: GenValidContext, arg1: ValType): TInstr;
export function genValidModule(arg0: OpaqueHandle<"@splitmix.RandomState">): Module;
export function genValidNumtype(arg0: GenValidContext): NumType;
export function genValidResultType(arg0: GenValidContext, arg1: Array<ValType>, arg2: TypeGenerationStrategy): Array<ValType>;
export function genValidTfunc(arg0: GenValidContext, arg1: Array<ValType>, arg2: Array<ValType>): Func;
export function genValidValtype(arg0: GenValidContext): ValType;
export function makeState(arg0: Env, arg1: Array<ValType>): TcState;
export function runValidateInvalidFuzz(arg0: string, arg1: bigint): StarshineResult<ValidateInvalidFuzzStats, string>;
export function runValidateValidFuzz(arg0: string, arg1: bigint): StarshineResult<ValidateValidFuzzStats, string>;
export function tinstrResultArity(arg0: TInstr, arg1: Env): number;
export function tinstrsResultArity(arg0: Array<TInstr>, arg1: Env): number;
export function toTexpr(arg0: Expr, arg1: Env): StarshineResult<TExpr, string>;
export function validateCodesec(arg0: CodeSec | null, arg1: FuncSec | null, arg2: Env): StarshineResult<void, string>;
export function validateDatacnt(arg0: DataCntSec | null, arg1: DataSec | null): StarshineResult<void, string>;
export function validateDatasec(arg0: DataSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateElemsec(arg0: ElemSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateExportsec(arg0: ExportSec | null, arg1: Env): StarshineResult<void, string>;
export function validateFuncsec(arg0: FuncSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateGlobalsec(arg0: GlobalSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateImportsec(arg0: ImportSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateMemsec(arg0: MemSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateModule(arg0: Module): StarshineResult<void, ValidationError>;
export function validateModuleWithTrace(...args: never[]): never;
export function validateStartsec(arg0: StartSec | null, arg1: Env): StarshineResult<void, string>;
export function validateTablesec(arg0: TableSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateTagsec(arg0: TagSec | null, arg1: Env): StarshineResult<Env, string>;
export function validateTypesec(arg0: TypeSec | null, arg1: Env): StarshineResult<Env, string>;
export function validationErrorDiagnostic(arg0: ValidationError): ValidationDiagnostic;
export function validationErrorFuncIdx(arg0: ValidationError): FuncIdx | null;
export function validationErrorMessage(arg0: ValidationError): string;
export function validationIssueMessage(arg0: ValidationIssue): string;

export const Env: {
  appendRectypeTypes(arg0: Env, arg1: RecType): Env;
  descriptorResultType(arg0: Env): ValType;
  expandBlocktype(arg0: Env, arg1: BlockType): StarshineResult<[Array<ValType>, Array<ValType>], string>;
  getCatchLabelTypes(arg0: Env, arg1: LabelIdx): Array<ValType> | null;
  getElem(arg0: Env, arg1: ElemIdx): Elem | null;
  getFunctypeByFuncidx(arg0: Env, arg1: FuncIdx): FuncType | null;
  getFunctypeidxByFuncidx(arg0: Env, arg1: FuncIdx): TypeIdx | null;
  getGlobalType(arg0: Env, arg1: GlobalIdx): GlobalType | null;
  getLabel(arg0: Env, arg1: LabelIdx): Array<ValType> | null;
  getLabelTypes(arg0: Env, arg1: LabelIdx): Array<ValType> | null;
  getLocalType(arg0: Env, arg1: LocalIdx): ValType | null;
  getMemtype(arg0: Env, arg1: MemIdx): MemType | null;
  getTableType(arg0: Env, arg1: TableIdx): TableType | null;
  getTag(arg0: Env, arg1: TagIdx): TagType | null;
  hasData(arg0: Env, arg1: DataIdx): boolean;
  hasFunc(arg0: Env, arg1: FuncIdx): boolean;
  new(): Env;
  pushData(arg0: Env, arg1: Data): Env;
  pushElem(arg0: Env, arg1: Elem): Env;
  pushFunc(arg0: Env, arg1: FuncType): Env;
  pushFuncWithTypeidx(arg0: Env, arg1: FuncType, arg2: TypeIdx | null): Env;
  pushGlobal(arg0: Env, arg1: GlobalType): Env;
  pushMem(arg0: Env, arg1: MemType): Env;
  pushTable(arg0: Env, arg1: TableType): Env;
  pushTag(arg0: Env, arg1: TagType): Env;
  resolveArrayField(arg0: Env, arg1: TypeIdx): StarshineResult<FieldType, string>;
  resolveComptype(arg0: Env, arg1: TypeIdx): CompType | null;
  resolveDescriptorTargetRefType(arg0: Env, arg1: boolean, arg2: HeapType): StarshineResult<RefType, string>;
  resolveFunctype(arg0: Env, arg1: TypeIdx): FuncType | null;
  resolveHeaptypeSubtype(arg0: Env, arg1: HeapType): SubType | null;
  resolveStructFields(arg0: Env, arg1: TypeIdx): StarshineResult<Array<FieldType>, string>;
  resolveSubtype(arg0: Env, arg1: TypeIdx): SubType | null;
  resolveTagFunctype(arg0: Env, arg1: TagIdx): FuncType | null;
  resolveTypeidxSubtype(arg0: Env, arg1: TypeIdx): SubType | null;
  withElems(arg0: Env, arg1: Array<Elem>): Env;
  withFuncs(arg0: Env, arg1: Array<FuncType>): Env;
  withGlobals(arg0: Env, arg1: Array<GlobalType>): Env;
  withLabel(arg0: Env, arg1: Array<ValType>): Env;
  withLabels(arg0: Env, arg1: Array<Array<ValType>>): Env;
  withLocals(arg0: Env, arg1: Locals): Env;
  withMems(arg0: Env, arg1: Array<MemType>): Env;
  withModule(arg0: Env, arg1: Module): Env;
  withRectype(arg0: Env, arg1: RecType): Env;
  withReturnType(arg0: Env, arg1: Array<ValType> | null): Env;
  withTables(arg0: Env, arg1: Array<TableType>): Env;
  withTags(arg0: Env, arg1: Array<TagType>): Env;
  withTypes(arg0: Env, arg1: Array<SubType>): Env;
  show(value: Env): string;
};

export const GenValidContext: {
};

export const TcEscape: {
  show(value: TcEscape): string;
};

export const TcResult: {
};

export const TcState: {
  show(value: TcState): string;
};

export const TypeGenerationStrategy: {
};

export const ValidateInvalidFuzzStats: {
  show(value: ValidateInvalidFuzzStats): string;
};

export const ValidateValidFuzzStats: {
  show(value: ValidateValidFuzzStats): string;
};

export const ValidationDiagnostic: {
  new(arg0: ValidationIssue, funcIdx?: FuncIdx | null): ValidationDiagnostic;
  show(value: ValidationDiagnostic): string;
};

export const ValidationError: {
  show(value: ValidationError): string;
};

export const ValidationIssue: {
  show(value: ValidationIssue): string;
};
