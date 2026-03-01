import type { OpaqueHandle, StarshineResult } from "./internal/shared.js";

export type AbsHeapType = OpaqueHandle<"lib.AbsHeapType">;
export type AtomicCmpxchgOp = OpaqueHandle<"lib.AtomicCmpxchgOp">;
export type AtomicRmwOp = OpaqueHandle<"lib.AtomicRmwOp">;
export type BinaryOp = OpaqueHandle<"lib.BinaryOp">;
export type BlockType = OpaqueHandle<"lib.BlockType">;
export type CastOp = OpaqueHandle<"lib.CastOp">;
export type Catch = OpaqueHandle<"lib.Catch">;
export type CodeSec = OpaqueHandle<"lib.CodeSec">;
export type CompType = OpaqueHandle<"lib.CompType">;
export type CustomSec = OpaqueHandle<"lib.CustomSec">;
export type Data = OpaqueHandle<"lib.Data">;
export type DataCntSec = OpaqueHandle<"lib.DataCntSec">;
export type DataIdx = OpaqueHandle<"lib.DataIdx">;
export type DataMode = OpaqueHandle<"lib.DataMode">;
export type DataSec = OpaqueHandle<"lib.DataSec">;
export type DefType = OpaqueHandle<"lib.DefType">;
export type Elem = OpaqueHandle<"lib.Elem">;
export type ElemIdx = OpaqueHandle<"lib.ElemIdx">;
export type ElemKind = OpaqueHandle<"lib.ElemKind">;
export type ElemMode = OpaqueHandle<"lib.ElemMode">;
export type ElemSec = OpaqueHandle<"lib.ElemSec">;
export type Export = OpaqueHandle<"lib.Export">;
export type ExportSec = OpaqueHandle<"lib.ExportSec">;
export type Expr = OpaqueHandle<"lib.Expr">;
export type ExternIdx = OpaqueHandle<"lib.ExternIdx">;
export type ExternType = OpaqueHandle<"lib.ExternType">;
export type ExtractLaneOp = OpaqueHandle<"lib.ExtractLaneOp">;
export type F32 = OpaqueHandle<"lib.F32">;
export type F64 = OpaqueHandle<"lib.F64">;
export type FieldType = OpaqueHandle<"lib.FieldType">;
export type Func = OpaqueHandle<"lib.Func">;
export type FuncIdx = OpaqueHandle<"lib.FuncIdx">;
export type FuncSec = OpaqueHandle<"lib.FuncSec">;
export type FuncType = OpaqueHandle<"lib.FuncType">;
export type Global = OpaqueHandle<"lib.Global">;
export type GlobalIdx = OpaqueHandle<"lib.GlobalIdx">;
export type GlobalSec = OpaqueHandle<"lib.GlobalSec">;
export type GlobalType = OpaqueHandle<"lib.GlobalType">;
export type HashResult = OpaqueHandle<"lib.HashResult">;
export type HeapType = OpaqueHandle<"lib.HeapType">;
export type I32 = OpaqueHandle<"lib.I32">;
export type I64 = OpaqueHandle<"lib.I64">;
export type Import = OpaqueHandle<"lib.Import">;
export type ImportSec = OpaqueHandle<"lib.ImportSec">;
export type Instruction = OpaqueHandle<"lib.Instruction">;
export type LabelIdx = OpaqueHandle<"lib.LabelIdx">;
export type LaneIdx = OpaqueHandle<"lib.LaneIdx">;
export type Limits = OpaqueHandle<"lib.Limits">;
export type LoadOp = OpaqueHandle<"lib.LoadOp">;
export type LocalIdx = OpaqueHandle<"lib.LocalIdx">;
export type Locals = OpaqueHandle<"lib.Locals">;
export type MemArg = OpaqueHandle<"lib.MemArg">;
export type MemIdx = OpaqueHandle<"lib.MemIdx">;
export type MemSec = OpaqueHandle<"lib.MemSec">;
export type MemType = OpaqueHandle<"lib.MemType">;
export type Module = OpaqueHandle<"lib.Module">;
export type Mut = OpaqueHandle<"lib.Mut">;
export type Name = OpaqueHandle<"lib.Name">;
export type NumType = OpaqueHandle<"lib.NumType">;
export type PackType = OpaqueHandle<"lib.PackType">;
export type PrettyPrintContext = OpaqueHandle<"lib.PrettyPrintContext">;
export type RecType = OpaqueHandle<"lib.RecType">;
export type RefType = OpaqueHandle<"lib.RefType">;
export type ReplaceLaneOp = OpaqueHandle<"lib.ReplaceLaneOp">;
export type ResultType = OpaqueHandle<"lib.ResultType">;
export type S33 = OpaqueHandle<"lib.S33">;
export type StartSec = OpaqueHandle<"lib.StartSec">;
export type StorageType = OpaqueHandle<"lib.StorageType">;
export type StoreOp = OpaqueHandle<"lib.StoreOp">;
export type SubType = OpaqueHandle<"lib.SubType">;
export type TExpr = OpaqueHandle<"lib.TExpr">;
export type TInstr = OpaqueHandle<"lib.TInstr">;
export type TInstrKind = OpaqueHandle<"lib.TInstrKind">;
export type Table = OpaqueHandle<"lib.Table">;
export type TableIdx = OpaqueHandle<"lib.TableIdx">;
export type TableSec = OpaqueHandle<"lib.TableSec">;
export type TableType = OpaqueHandle<"lib.TableType">;
export type TabsOrSpaces = OpaqueHandle<"lib.TabsOrSpaces">;
export type TagIdx = OpaqueHandle<"lib.TagIdx">;
export type TagSec = OpaqueHandle<"lib.TagSec">;
export type TagType = OpaqueHandle<"lib.TagType">;
export type TypeIdx = OpaqueHandle<"lib.TypeIdx">;
export type TypeSec = OpaqueHandle<"lib.TypeSec">;
export type U32 = OpaqueHandle<"lib.U32">;
export type U64 = OpaqueHandle<"lib.U64">;
export type UnaryOp = OpaqueHandle<"lib.UnaryOp">;
export type V128LoadLaneOp = OpaqueHandle<"lib.V128LoadLaneOp">;
export type V128ShiftOp = OpaqueHandle<"lib.V128ShiftOp">;
export type V128StoreLaneOp = OpaqueHandle<"lib.V128StoreLaneOp">;
export type V128TernaryOp = OpaqueHandle<"lib.V128TernaryOp">;
export type ValType = OpaqueHandle<"lib.ValType">;

export function applyPrettyContext(arg0: string, arg1: PrettyPrintContext): string;
export function arrayCompType(arg0: FieldType): CompType;
export function arrayOfArbitrary(...args: never[]): never;
export function compTypeSubType(arg0: CompType): SubType;
export function equals(...args: never[]): never;
export function expandLocals(arg0: Array<Locals>): StarshineResult<Array<ValType>, string>;
export function funcCompType(arg0: Array<ValType>, arg1: Array<ValType>): CompType;
export function funcExternIdx(arg0: FuncIdx): ExternIdx;
export function funcExternType(arg0: TypeIdx): ExternType;
export function funcIdx(arg0: number): FuncIdx;
export function getStructField(arg0: Array<FieldType>, arg1: U32): StarshineResult<FieldType, string>;
export function globalExternIdx(arg0: GlobalIdx): ExternIdx;
export function globalExternType(arg0: GlobalType): ExternType;
export function globalIdx(arg0: number): GlobalIdx;
export function globalType(arg0: ValType, arg1: boolean): GlobalType;
export function groupRecType(arg0: Array<SubType>): RecType;
export function hasDefault(arg0: ValType): boolean;
export function inspectDebug(...args: never[]): never;
export function inspectPrettyPrint(...args: never[]): never;
export function memExternIdx(arg0: MemIdx): ExternIdx;
export function memExternType(arg0: MemType): ExternType;
export function memType(arg0: Limits): MemType;
export function minAddr(arg0: Limits, arg1: Limits): Limits;
export function minAddrValtype(arg0: Limits, arg1: Limits): ValType;
export function recIdx(arg0: number): TypeIdx;
export function resultType(arg0: Array<ValType>): Array<ValType>;
export function singleRecType(arg0: SubType): RecType;
export function structCompType(arg0: Array<FieldType>): CompType;
export function subType(arg0: boolean, arg1: Array<TypeIdx>, arg2: CompType): SubType;
export function tableExternIdx(arg0: TableIdx): ExternIdx;
export function tableExternType(arg0: TableType): ExternType;
export function tableIdx(arg0: number): TableIdx;
export function tagExternIdx(arg0: TagIdx): ExternIdx;
export function tagExternType(arg0: TagType): ExternType;
export function tagType(arg0: TypeIdx): TagType;
export function tlocalsToLocals(arg0: Array<ValType>): Array<Locals>;

export const AbsHeapType: {
  any(): AbsHeapType;
  array(): AbsHeapType;
  eq(): AbsHeapType;
  exn(): AbsHeapType;
  extern(): AbsHeapType;
  func(): AbsHeapType;
  i31(): AbsHeapType;
  noExn(): AbsHeapType;
  noExtern(): AbsHeapType;
  noFunc(): AbsHeapType;
  none(): AbsHeapType;
  struct(): AbsHeapType;
  show(value: AbsHeapType): string;
};

export const AtomicCmpxchgOp: {
  i32(): AtomicCmpxchgOp;
  i3216U(): AtomicCmpxchgOp;
  i328U(): AtomicCmpxchgOp;
  i64(): AtomicCmpxchgOp;
  i6416U(): AtomicCmpxchgOp;
  i6432U(): AtomicCmpxchgOp;
  i648U(): AtomicCmpxchgOp;
  show(value: AtomicCmpxchgOp): string;
};

export const AtomicRmwOp: {
  i3216AddU(): AtomicRmwOp;
  i3216AndU(): AtomicRmwOp;
  i3216OrU(): AtomicRmwOp;
  i3216SubU(): AtomicRmwOp;
  i3216XchgU(): AtomicRmwOp;
  i3216XorU(): AtomicRmwOp;
  i328AddU(): AtomicRmwOp;
  i328AndU(): AtomicRmwOp;
  i328OrU(): AtomicRmwOp;
  i328SubU(): AtomicRmwOp;
  i328XchgU(): AtomicRmwOp;
  i328XorU(): AtomicRmwOp;
  i32Add(): AtomicRmwOp;
  i32And(): AtomicRmwOp;
  i32Or(): AtomicRmwOp;
  i32Sub(): AtomicRmwOp;
  i32Xchg(): AtomicRmwOp;
  i32Xor(): AtomicRmwOp;
  i6416AddU(): AtomicRmwOp;
  i6416AndU(): AtomicRmwOp;
  i6416OrU(): AtomicRmwOp;
  i6416SubU(): AtomicRmwOp;
  i6416XchgU(): AtomicRmwOp;
  i6416XorU(): AtomicRmwOp;
  i6432AddU(): AtomicRmwOp;
  i6432AndU(): AtomicRmwOp;
  i6432OrU(): AtomicRmwOp;
  i6432SubU(): AtomicRmwOp;
  i6432XchgU(): AtomicRmwOp;
  i6432XorU(): AtomicRmwOp;
  i648AddU(): AtomicRmwOp;
  i648AndU(): AtomicRmwOp;
  i648OrU(): AtomicRmwOp;
  i648SubU(): AtomicRmwOp;
  i648XchgU(): AtomicRmwOp;
  i648XorU(): AtomicRmwOp;
  i64Add(): AtomicRmwOp;
  i64And(): AtomicRmwOp;
  i64Or(): AtomicRmwOp;
  i64Sub(): AtomicRmwOp;
  i64Xchg(): AtomicRmwOp;
  i64Xor(): AtomicRmwOp;
  show(value: AtomicRmwOp): string;
};

export const BinaryOp: {
  f32Add(): BinaryOp;
  f32Copysign(): BinaryOp;
  f32Div(): BinaryOp;
  f32Eq(): BinaryOp;
  f32Ge(): BinaryOp;
  f32Gt(): BinaryOp;
  f32Le(): BinaryOp;
  f32Lt(): BinaryOp;
  f32Max(): BinaryOp;
  f32Min(): BinaryOp;
  f32Mul(): BinaryOp;
  f32Ne(): BinaryOp;
  f32Sub(): BinaryOp;
  f32x4Add(): BinaryOp;
  f32x4Div(): BinaryOp;
  f32x4Eq(): BinaryOp;
  f32x4Ge(): BinaryOp;
  f32x4Gt(): BinaryOp;
  f32x4Le(): BinaryOp;
  f32x4Lt(): BinaryOp;
  f32x4Max(): BinaryOp;
  f32x4Min(): BinaryOp;
  f32x4Mul(): BinaryOp;
  f32x4Ne(): BinaryOp;
  f32x4Pmax(): BinaryOp;
  f32x4Pmin(): BinaryOp;
  f32x4RelaxedMax(): BinaryOp;
  f32x4RelaxedMin(): BinaryOp;
  f32x4Sub(): BinaryOp;
  f64Add(): BinaryOp;
  f64Copysign(): BinaryOp;
  f64Div(): BinaryOp;
  f64Eq(): BinaryOp;
  f64Ge(): BinaryOp;
  f64Gt(): BinaryOp;
  f64Le(): BinaryOp;
  f64Lt(): BinaryOp;
  f64Max(): BinaryOp;
  f64Min(): BinaryOp;
  f64Mul(): BinaryOp;
  f64Ne(): BinaryOp;
  f64Sub(): BinaryOp;
  f64x2Add(): BinaryOp;
  f64x2Div(): BinaryOp;
  f64x2Eq(): BinaryOp;
  f64x2Ge(): BinaryOp;
  f64x2Gt(): BinaryOp;
  f64x2Le(): BinaryOp;
  f64x2Lt(): BinaryOp;
  f64x2Max(): BinaryOp;
  f64x2Min(): BinaryOp;
  f64x2Mul(): BinaryOp;
  f64x2Ne(): BinaryOp;
  f64x2Pmax(): BinaryOp;
  f64x2Pmin(): BinaryOp;
  f64x2RelaxedMax(): BinaryOp;
  f64x2RelaxedMin(): BinaryOp;
  f64x2Sub(): BinaryOp;
  i16x8Add(): BinaryOp;
  i16x8AddSatS(): BinaryOp;
  i16x8AddSatU(): BinaryOp;
  i16x8AvgrU(): BinaryOp;
  i16x8Eq(): BinaryOp;
  i16x8ExtmulHighI8x16s(): BinaryOp;
  i16x8ExtmulHighI8x16u(): BinaryOp;
  i16x8ExtmulLowI8x16s(): BinaryOp;
  i16x8ExtmulLowI8x16u(): BinaryOp;
  i16x8GeS(): BinaryOp;
  i16x8GeU(): BinaryOp;
  i16x8GtS(): BinaryOp;
  i16x8GtU(): BinaryOp;
  i16x8LeS(): BinaryOp;
  i16x8LeU(): BinaryOp;
  i16x8LtS(): BinaryOp;
  i16x8LtU(): BinaryOp;
  i16x8MaxS(): BinaryOp;
  i16x8MaxU(): BinaryOp;
  i16x8MinS(): BinaryOp;
  i16x8MinU(): BinaryOp;
  i16x8Mul(): BinaryOp;
  i16x8NarrowI32x4s(): BinaryOp;
  i16x8NarrowI32x4u(): BinaryOp;
  i16x8Ne(): BinaryOp;
  i16x8RelaxedDotI8x16i7x16s(): BinaryOp;
  i16x8RelaxedQ15mulrS(): BinaryOp;
  i16x8Sub(): BinaryOp;
  i16x8SubSatS(): BinaryOp;
  i16x8SubSatU(): BinaryOp;
  i16x8q15mulrSatS(): BinaryOp;
  i32Add(): BinaryOp;
  i32And(): BinaryOp;
  i32DivS(): BinaryOp;
  i32DivU(): BinaryOp;
  i32Eq(): BinaryOp;
  i32GeS(): BinaryOp;
  i32GeU(): BinaryOp;
  i32GtS(): BinaryOp;
  i32GtU(): BinaryOp;
  i32LeS(): BinaryOp;
  i32LeU(): BinaryOp;
  i32LtS(): BinaryOp;
  i32LtU(): BinaryOp;
  i32Mul(): BinaryOp;
  i32Ne(): BinaryOp;
  i32Or(): BinaryOp;
  i32RemS(): BinaryOp;
  i32RemU(): BinaryOp;
  i32Rotl(): BinaryOp;
  i32Rotr(): BinaryOp;
  i32Shl(): BinaryOp;
  i32ShrS(): BinaryOp;
  i32ShrU(): BinaryOp;
  i32Sub(): BinaryOp;
  i32Xor(): BinaryOp;
  i32x4Add(): BinaryOp;
  i32x4DotI16x8s(): BinaryOp;
  i32x4Eq(): BinaryOp;
  i32x4ExtmulHighI16x8s(): BinaryOp;
  i32x4ExtmulHighI16x8u(): BinaryOp;
  i32x4ExtmulLowI16x8s(): BinaryOp;
  i32x4ExtmulLowI16x8u(): BinaryOp;
  i32x4GeS(): BinaryOp;
  i32x4GeU(): BinaryOp;
  i32x4GtS(): BinaryOp;
  i32x4GtU(): BinaryOp;
  i32x4LeS(): BinaryOp;
  i32x4LeU(): BinaryOp;
  i32x4LtS(): BinaryOp;
  i32x4LtU(): BinaryOp;
  i32x4MaxS(): BinaryOp;
  i32x4MaxU(): BinaryOp;
  i32x4MinS(): BinaryOp;
  i32x4MinU(): BinaryOp;
  i32x4Mul(): BinaryOp;
  i32x4Ne(): BinaryOp;
  i32x4Sub(): BinaryOp;
  i64Add(): BinaryOp;
  i64And(): BinaryOp;
  i64DivS(): BinaryOp;
  i64DivU(): BinaryOp;
  i64Eq(): BinaryOp;
  i64GeS(): BinaryOp;
  i64GeU(): BinaryOp;
  i64GtS(): BinaryOp;
  i64GtU(): BinaryOp;
  i64LeS(): BinaryOp;
  i64LeU(): BinaryOp;
  i64LtS(): BinaryOp;
  i64LtU(): BinaryOp;
  i64Mul(): BinaryOp;
  i64Ne(): BinaryOp;
  i64Or(): BinaryOp;
  i64RemS(): BinaryOp;
  i64RemU(): BinaryOp;
  i64Rotl(): BinaryOp;
  i64Rotr(): BinaryOp;
  i64Shl(): BinaryOp;
  i64ShrS(): BinaryOp;
  i64ShrU(): BinaryOp;
  i64Sub(): BinaryOp;
  i64Xor(): BinaryOp;
  i64x2Add(): BinaryOp;
  i64x2Eq(): BinaryOp;
  i64x2ExtmulHighI32x4s(): BinaryOp;
  i64x2ExtmulHighI32x4u(): BinaryOp;
  i64x2ExtmulLowI32x4s(): BinaryOp;
  i64x2ExtmulLowI32x4u(): BinaryOp;
  i64x2GeS(): BinaryOp;
  i64x2GtS(): BinaryOp;
  i64x2LeS(): BinaryOp;
  i64x2LtS(): BinaryOp;
  i64x2Mul(): BinaryOp;
  i64x2Ne(): BinaryOp;
  i64x2Sub(): BinaryOp;
  i8x16Add(): BinaryOp;
  i8x16AddSatS(): BinaryOp;
  i8x16AddSatU(): BinaryOp;
  i8x16AvgrU(): BinaryOp;
  i8x16Eq(): BinaryOp;
  i8x16GeS(): BinaryOp;
  i8x16GeU(): BinaryOp;
  i8x16GtS(): BinaryOp;
  i8x16GtU(): BinaryOp;
  i8x16LeS(): BinaryOp;
  i8x16LeU(): BinaryOp;
  i8x16LtS(): BinaryOp;
  i8x16LtU(): BinaryOp;
  i8x16MaxS(): BinaryOp;
  i8x16MaxU(): BinaryOp;
  i8x16MinS(): BinaryOp;
  i8x16MinU(): BinaryOp;
  i8x16NarrowI16x8s(): BinaryOp;
  i8x16NarrowI16x8u(): BinaryOp;
  i8x16Ne(): BinaryOp;
  i8x16Sub(): BinaryOp;
  i8x16SubSatS(): BinaryOp;
  i8x16SubSatU(): BinaryOp;
  v128And(): BinaryOp;
  v128Andnot(): BinaryOp;
  v128Or(): BinaryOp;
  v128Xor(): BinaryOp;
  show(value: BinaryOp): string;
};

export const BlockType: {
  typeIdx(arg0: TypeIdx): BlockType;
  valType(arg0: ValType): BlockType;
  void(): BlockType;
  show(value: BlockType): string;
};

export const CastOp: {
  new(arg0: boolean, arg1: boolean): CastOp;
  sourceNullable(arg0: CastOp): boolean;
  targetNullable(arg0: CastOp): boolean;
  show(value: CastOp): string;
};

export const Catch: {
  all(arg0: LabelIdx): Catch;
  allRef(arg0: LabelIdx): Catch;
  new(arg0: TagIdx, arg1: LabelIdx): Catch;
  ref(arg0: TagIdx, arg1: LabelIdx): Catch;
  show(value: Catch): string;
};

export const CodeSec: {
  inner(arg0: CodeSec): Array<Func>;
  new(arg0: Array<Func>): CodeSec;
  show(value: CodeSec): string;
};

export const CompType: {
  array(arg0: FieldType): CompType;
  func(arg0: Array<ValType>, arg1: Array<ValType>): CompType;
  struct(arg0: Array<FieldType>): CompType;
  show(value: CompType): string;
};

export const CustomSec: {
  new(arg0: Name, arg1: Uint8Array): CustomSec;
  show(value: CustomSec): string;
};

export const Data: {
  new(arg0: DataMode, arg1: Uint8Array): Data;
  show(value: Data): string;
};

export const DataCntSec: {
  inner(arg0: DataCntSec): U32;
  new(arg0: U32): DataCntSec;
  show(value: DataCntSec): string;
};

export const DataIdx: {
  inner(arg0: DataIdx): number;
  new(arg0: number): DataIdx;
  show(value: DataIdx): string;
};

export const DataMode: {
  active(arg0: MemIdx, arg1: Expr): DataMode;
  passive(): DataMode;
  show(value: DataMode): string;
};

export const DataSec: {
  inner(arg0: DataSec): Array<Data>;
  new(arg0: Array<Data>): DataSec;
  show(value: DataSec): string;
};

export const DefType: {
  new(arg0: RecType, arg1: number): DefType;
  project(arg0: DefType): SubType | null;
  show(value: DefType): string;
};

export const Elem: {
  new(arg0: ElemMode, arg1: ElemKind): Elem;
  reftype(arg0: Elem): RefType;
  show(value: Elem): string;
};

export const ElemIdx: {
  inner(arg0: ElemIdx): number;
  new(arg0: number): ElemIdx;
  show(value: ElemIdx): string;
};

export const ElemKind: {
  funcExprs(arg0: Array<Expr>): ElemKind;
  funcs(arg0: Array<FuncIdx>): ElemKind;
  typedExprs(arg0: RefType, arg1: Array<Expr>): ElemKind;
  show(value: ElemKind): string;
};

export const ElemMode: {
  active(arg0: TableIdx, arg1: Expr): ElemMode;
  declarative(): ElemMode;
  passive(): ElemMode;
  show(value: ElemMode): string;
};

export const ElemSec: {
  inner(arg0: ElemSec): Array<Elem>;
  new(arg0: Array<Elem>): ElemSec;
  show(value: ElemSec): string;
};

export const Export: {
  new(arg0: Name, arg1: ExternIdx): Export;
  show(value: Export): string;
};

export const ExportSec: {
  inner(arg0: ExportSec): Array<Export>;
  new(arg0: Array<Export>): ExportSec;
  show(value: ExportSec): string;
};

export const Expr: {
  inner(arg0: Expr): Array<Instruction>;
  new(arg0: Array<Instruction>): Expr;
  show(value: Expr): string;
};

export const ExternIdx: {
  func(arg0: FuncIdx): ExternIdx;
  global(arg0: GlobalIdx): ExternIdx;
  mem(arg0: MemIdx): ExternIdx;
  table(arg0: TableIdx): ExternIdx;
  tag(arg0: TagIdx): ExternIdx;
  show(value: ExternIdx): string;
};

export const ExternType: {
  func(arg0: TypeIdx): ExternType;
  global(arg0: GlobalType): ExternType;
  mem(arg0: MemType): ExternType;
  table(arg0: TableType): ExternType;
  tag(arg0: TagType): ExternType;
  show(value: ExternType): string;
};

export const ExtractLaneOp: {
  f32x4ExtractLane(): ExtractLaneOp;
  f64x2ExtractLane(): ExtractLaneOp;
  i16x8ExtractLaneS(): ExtractLaneOp;
  i16x8ExtractLaneU(): ExtractLaneOp;
  i32x4ExtractLane(): ExtractLaneOp;
  i64x2ExtractLane(): ExtractLaneOp;
  i8x16ExtractLaneS(): ExtractLaneOp;
  i8x16ExtractLaneU(): ExtractLaneOp;
  show(value: ExtractLaneOp): string;
};

export const F32: {
  inner(arg0: F32): number;
  new(arg0: number): F32;
  show(value: F32): string;
};

export const F64: {
  inner(arg0: F64): number;
  new(arg0: number): F64;
  show(value: F64): string;
};

export const FieldType: {
  getStorageType(arg0: FieldType): StorageType;
  isMutable(arg0: FieldType): boolean;
  new(arg0: StorageType, arg1: Mut): FieldType;
  unpack(arg0: FieldType): ValType;
  show(value: FieldType): string;
};

export const Func: {
  new(arg0: Array<Locals>, arg1: Expr): Func;
  tFunc(arg0: Array<ValType>, arg1: TExpr): Func;
  show(value: Func): string;
};

export const FuncIdx: {
  inner(arg0: FuncIdx): number;
  new(arg0: number): FuncIdx;
  show(value: FuncIdx): string;
};

export const FuncSec: {
  inner(arg0: FuncSec): Array<TypeIdx>;
  new(arg0: Array<TypeIdx>): FuncSec;
  show(value: FuncSec): string;
};

export const FuncType: {
  new(arg0: Array<ValType>, arg1: Array<ValType>): FuncType;
  show(value: FuncType): string;
};

export const Global: {
  new(arg0: GlobalType, arg1: Expr): Global;
  show(value: Global): string;
};

export const GlobalIdx: {
  inner(arg0: GlobalIdx): number;
  new(arg0: number): GlobalIdx;
  show(value: GlobalIdx): string;
};

export const GlobalSec: {
  inner(arg0: GlobalSec): Array<Global>;
  new(arg0: Array<Global>): GlobalSec;
  show(value: GlobalSec): string;
};

export const GlobalType: {
  new(arg0: ValType, arg1: boolean): GlobalType;
  show(value: GlobalType): string;
};

export const HashResult: {
};

export const HeapType: {
  abs(arg0: AbsHeapType): HeapType;
  bottom(): HeapType;
  defType(arg0: DefType): HeapType;
  isArray(arg0: HeapType): boolean;
  isGcAggregate(arg0: HeapType): boolean;
  isStruct(arg0: HeapType): boolean;
  new(arg0: TypeIdx): HeapType;
  show(value: HeapType): string;
};

export const I32: {
  inner(arg0: I32): number;
  new(arg0: number): I32;
  show(value: I32): string;
};

export const I64: {
  inner(arg0: I64): bigint;
  new(arg0: bigint): I64;
  show(value: I64): string;
};

export const Import: {
  new(arg0: Name, arg1: Name, arg2: ExternType): Import;
  show(value: Import): string;
};

export const ImportSec: {
  inner(arg0: ImportSec): Array<Import>;
  new(arg0: Array<Import>): ImportSec;
  show(value: ImportSec): string;
};

export const Instruction: {
  anyConvertExtern(): Instruction;
  arrayCopy(arg0: TypeIdx, arg1: TypeIdx): Instruction;
  arrayFill(arg0: TypeIdx): Instruction;
  arrayGet(arg0: TypeIdx): Instruction;
  arrayGetS(arg0: TypeIdx): Instruction;
  arrayGetU(arg0: TypeIdx): Instruction;
  arrayInitData(arg0: TypeIdx, arg1: DataIdx): Instruction;
  arrayInitElem(arg0: TypeIdx, arg1: ElemIdx): Instruction;
  arrayLen(): Instruction;
  arrayNew(arg0: TypeIdx): Instruction;
  arrayNewData(arg0: TypeIdx, arg1: DataIdx): Instruction;
  arrayNewDefault(arg0: TypeIdx): Instruction;
  arrayNewElem(arg0: TypeIdx, arg1: ElemIdx): Instruction;
  arrayNewFixed(arg0: TypeIdx, arg1: U32): Instruction;
  arraySet(arg0: TypeIdx): Instruction;
  atomicCmpxchg(arg0: AtomicCmpxchgOp, arg1: MemArg): Instruction;
  atomicFence(): Instruction;
  atomicRmw(arg0: AtomicRmwOp, arg1: MemArg): Instruction;
  block(arg0: BlockType, arg1: Expr): Instruction;
  br(arg0: LabelIdx): Instruction;
  brIf(arg0: LabelIdx): Instruction;
  brOnCast(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType): Instruction;
  brOnCastFail(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType): Instruction;
  brOnNonNull(arg0: LabelIdx): Instruction;
  brOnNull(arg0: LabelIdx): Instruction;
  brTable(arg0: Array<LabelIdx>, arg1: LabelIdx): Instruction;
  call(arg0: FuncIdx): Instruction;
  callIndirect(arg0: TypeIdx, arg1: TableIdx): Instruction;
  callRef(arg0: TypeIdx): Instruction;
  dataDrop(arg0: DataIdx): Instruction;
  drop(): Instruction;
  elemDrop(arg0: ElemIdx): Instruction;
  externConvertAny(): Instruction;
  f32Abs(): Instruction;
  f32Add(): Instruction;
  f32Ceil(): Instruction;
  f32Const(arg0: F32): Instruction;
  f32ConvertI32s(): Instruction;
  f32ConvertI32u(): Instruction;
  f32ConvertI64s(): Instruction;
  f32ConvertI64u(): Instruction;
  f32Copysign(): Instruction;
  f32DemoteF64(): Instruction;
  f32Div(): Instruction;
  f32Eq(): Instruction;
  f32Floor(): Instruction;
  f32Ge(): Instruction;
  f32Gt(): Instruction;
  f32Le(): Instruction;
  f32Load(arg0: MemArg): Instruction;
  f32Lt(): Instruction;
  f32Max(): Instruction;
  f32Min(): Instruction;
  f32Mul(): Instruction;
  f32Ne(): Instruction;
  f32Nearest(): Instruction;
  f32Neg(): Instruction;
  f32ReinterpretI32(): Instruction;
  f32Sqrt(): Instruction;
  f32Store(arg0: MemArg): Instruction;
  f32Sub(): Instruction;
  f32Trunc(): Instruction;
  f32x4Abs(): Instruction;
  f32x4Add(): Instruction;
  f32x4Ceil(): Instruction;
  f32x4ConvertI32x4s(): Instruction;
  f32x4ConvertI32x4u(): Instruction;
  f32x4DemoteF64x2Zero(): Instruction;
  f32x4Div(): Instruction;
  f32x4Eq(): Instruction;
  f32x4ExtractLane(arg0: LaneIdx): Instruction;
  f32x4Floor(): Instruction;
  f32x4Ge(): Instruction;
  f32x4Gt(): Instruction;
  f32x4Le(): Instruction;
  f32x4Lt(): Instruction;
  f32x4Max(): Instruction;
  f32x4Min(): Instruction;
  f32x4Mul(): Instruction;
  f32x4Ne(): Instruction;
  f32x4Nearest(): Instruction;
  f32x4Neg(): Instruction;
  f32x4Pmax(): Instruction;
  f32x4Pmin(): Instruction;
  f32x4RelaxedMadd(): Instruction;
  f32x4RelaxedMax(): Instruction;
  f32x4RelaxedMin(): Instruction;
  f32x4RelaxedNmadd(): Instruction;
  f32x4ReplaceLane(arg0: LaneIdx): Instruction;
  f32x4Splat(): Instruction;
  f32x4Sqrt(): Instruction;
  f32x4Sub(): Instruction;
  f32x4Trunc(): Instruction;
  f64Abs(): Instruction;
  f64Add(): Instruction;
  f64Ceil(): Instruction;
  f64Const(arg0: F64): Instruction;
  f64ConvertI32s(): Instruction;
  f64ConvertI32u(): Instruction;
  f64ConvertI64s(): Instruction;
  f64ConvertI64u(): Instruction;
  f64Copysign(): Instruction;
  f64Div(): Instruction;
  f64Eq(): Instruction;
  f64Floor(): Instruction;
  f64Ge(): Instruction;
  f64Gt(): Instruction;
  f64Le(): Instruction;
  f64Load(arg0: MemArg): Instruction;
  f64Lt(): Instruction;
  f64Max(): Instruction;
  f64Min(): Instruction;
  f64Mul(): Instruction;
  f64Ne(): Instruction;
  f64Nearest(): Instruction;
  f64Neg(): Instruction;
  f64PromoteF32(): Instruction;
  f64ReinterpretI64(): Instruction;
  f64Sqrt(): Instruction;
  f64Store(arg0: MemArg): Instruction;
  f64Sub(): Instruction;
  f64Trunc(): Instruction;
  f64x2Abs(): Instruction;
  f64x2Add(): Instruction;
  f64x2Ceil(): Instruction;
  f64x2ConvertLowI32x4s(): Instruction;
  f64x2ConvertLowI32x4u(): Instruction;
  f64x2Div(): Instruction;
  f64x2Eq(): Instruction;
  f64x2ExtractLane(arg0: LaneIdx): Instruction;
  f64x2Floor(): Instruction;
  f64x2Ge(): Instruction;
  f64x2Gt(): Instruction;
  f64x2Le(): Instruction;
  f64x2Lt(): Instruction;
  f64x2Max(): Instruction;
  f64x2Min(): Instruction;
  f64x2Mul(): Instruction;
  f64x2Ne(): Instruction;
  f64x2Nearest(): Instruction;
  f64x2Neg(): Instruction;
  f64x2Pmax(): Instruction;
  f64x2Pmin(): Instruction;
  f64x2PromoteLowF32x4(): Instruction;
  f64x2RelaxedMadd(): Instruction;
  f64x2RelaxedMax(): Instruction;
  f64x2RelaxedMin(): Instruction;
  f64x2RelaxedNmadd(): Instruction;
  f64x2ReplaceLane(arg0: LaneIdx): Instruction;
  f64x2Splat(): Instruction;
  f64x2Sqrt(): Instruction;
  f64x2Sub(): Instruction;
  f64x2Trunc(): Instruction;
  globalGet(arg0: GlobalIdx): Instruction;
  globalSet(arg0: GlobalIdx): Instruction;
  i16x8Abs(): Instruction;
  i16x8Add(): Instruction;
  i16x8AddSatS(): Instruction;
  i16x8AddSatU(): Instruction;
  i16x8AllTrue(): Instruction;
  i16x8AvgrU(): Instruction;
  i16x8Bitmask(): Instruction;
  i16x8Eq(): Instruction;
  i16x8ExtaddPairwiseI8x16s(): Instruction;
  i16x8ExtaddPairwiseI8x16u(): Instruction;
  i16x8ExtendHighI8x16s(): Instruction;
  i16x8ExtendHighI8x16u(): Instruction;
  i16x8ExtendLowI8x16s(): Instruction;
  i16x8ExtendLowI8x16u(): Instruction;
  i16x8ExtmulHighI8x16s(): Instruction;
  i16x8ExtmulHighI8x16u(): Instruction;
  i16x8ExtmulLowI8x16s(): Instruction;
  i16x8ExtmulLowI8x16u(): Instruction;
  i16x8ExtractLaneS(arg0: LaneIdx): Instruction;
  i16x8ExtractLaneU(arg0: LaneIdx): Instruction;
  i16x8GeS(): Instruction;
  i16x8GeU(): Instruction;
  i16x8GtS(): Instruction;
  i16x8GtU(): Instruction;
  i16x8LeS(): Instruction;
  i16x8LeU(): Instruction;
  i16x8LtS(): Instruction;
  i16x8LtU(): Instruction;
  i16x8MaxS(): Instruction;
  i16x8MaxU(): Instruction;
  i16x8MinS(): Instruction;
  i16x8MinU(): Instruction;
  i16x8Mul(): Instruction;
  i16x8NarrowI32x4s(): Instruction;
  i16x8NarrowI32x4u(): Instruction;
  i16x8Ne(): Instruction;
  i16x8Neg(): Instruction;
  i16x8RelaxedDotI8x16i7x16s(): Instruction;
  i16x8RelaxedLaneselect(): Instruction;
  i16x8RelaxedQ15mulrS(): Instruction;
  i16x8ReplaceLane(arg0: LaneIdx): Instruction;
  i16x8Shl(): Instruction;
  i16x8ShrS(): Instruction;
  i16x8ShrU(): Instruction;
  i16x8Splat(): Instruction;
  i16x8Sub(): Instruction;
  i16x8SubSatS(): Instruction;
  i16x8SubSatU(): Instruction;
  i16x8q15mulrSatS(): Instruction;
  i31GetS(): Instruction;
  i31GetU(): Instruction;
  i32Add(): Instruction;
  i32And(): Instruction;
  i32AtomicLoad(arg0: MemArg): Instruction;
  i32AtomicLoad16U(arg0: MemArg): Instruction;
  i32AtomicLoad8U(arg0: MemArg): Instruction;
  i32AtomicStore(arg0: MemArg): Instruction;
  i32AtomicStore16(arg0: MemArg): Instruction;
  i32AtomicStore8(arg0: MemArg): Instruction;
  i32Clz(): Instruction;
  i32Const(arg0: I32): Instruction;
  i32Ctz(): Instruction;
  i32DivS(): Instruction;
  i32DivU(): Instruction;
  i32Eq(): Instruction;
  i32Eqz(): Instruction;
  i32Extend16s(): Instruction;
  i32Extend8s(): Instruction;
  i32GeS(): Instruction;
  i32GeU(): Instruction;
  i32GtS(): Instruction;
  i32GtU(): Instruction;
  i32LeS(): Instruction;
  i32LeU(): Instruction;
  i32Load(arg0: MemArg): Instruction;
  i32Load16s(arg0: MemArg): Instruction;
  i32Load16u(arg0: MemArg): Instruction;
  i32Load8s(arg0: MemArg): Instruction;
  i32Load8u(arg0: MemArg): Instruction;
  i32LtS(): Instruction;
  i32LtU(): Instruction;
  i32Mul(): Instruction;
  i32Ne(): Instruction;
  i32Or(): Instruction;
  i32Popcnt(): Instruction;
  i32ReinterpretF32(): Instruction;
  i32RemS(): Instruction;
  i32RemU(): Instruction;
  i32Rotl(): Instruction;
  i32Rotr(): Instruction;
  i32Shl(): Instruction;
  i32ShrS(): Instruction;
  i32ShrU(): Instruction;
  i32Store(arg0: MemArg): Instruction;
  i32Store16(arg0: MemArg): Instruction;
  i32Store8(arg0: MemArg): Instruction;
  i32Sub(): Instruction;
  i32TruncF32s(): Instruction;
  i32TruncF32u(): Instruction;
  i32TruncF64s(): Instruction;
  i32TruncF64u(): Instruction;
  i32TruncSatF32s(): Instruction;
  i32TruncSatF32u(): Instruction;
  i32TruncSatF64s(): Instruction;
  i32TruncSatF64u(): Instruction;
  i32WrapI64(): Instruction;
  i32Xor(): Instruction;
  i32x4Abs(): Instruction;
  i32x4Add(): Instruction;
  i32x4AllTrue(): Instruction;
  i32x4Bitmask(): Instruction;
  i32x4DotI16x8s(): Instruction;
  i32x4Eq(): Instruction;
  i32x4ExtaddPairwiseI16x8s(): Instruction;
  i32x4ExtaddPairwiseI16x8u(): Instruction;
  i32x4ExtendHighI16x8s(): Instruction;
  i32x4ExtendHighI16x8u(): Instruction;
  i32x4ExtendLowI16x8s(): Instruction;
  i32x4ExtendLowI16x8u(): Instruction;
  i32x4ExtmulHighI16x8s(): Instruction;
  i32x4ExtmulHighI16x8u(): Instruction;
  i32x4ExtmulLowI16x8s(): Instruction;
  i32x4ExtmulLowI16x8u(): Instruction;
  i32x4ExtractLane(arg0: LaneIdx): Instruction;
  i32x4GeS(): Instruction;
  i32x4GeU(): Instruction;
  i32x4GtS(): Instruction;
  i32x4GtU(): Instruction;
  i32x4LeS(): Instruction;
  i32x4LeU(): Instruction;
  i32x4LtS(): Instruction;
  i32x4LtU(): Instruction;
  i32x4MaxS(): Instruction;
  i32x4MaxU(): Instruction;
  i32x4MinS(): Instruction;
  i32x4MinU(): Instruction;
  i32x4Mul(): Instruction;
  i32x4Ne(): Instruction;
  i32x4Neg(): Instruction;
  i32x4RelaxedDotI8x16i7x16AddS(): Instruction;
  i32x4RelaxedLaneselect(): Instruction;
  i32x4RelaxedTruncF32x4s(): Instruction;
  i32x4RelaxedTruncF32x4u(): Instruction;
  i32x4RelaxedTruncZeroF64x2s(): Instruction;
  i32x4RelaxedTruncZeroF64x2u(): Instruction;
  i32x4ReplaceLane(arg0: LaneIdx): Instruction;
  i32x4Shl(): Instruction;
  i32x4ShrS(): Instruction;
  i32x4ShrU(): Instruction;
  i32x4Splat(): Instruction;
  i32x4Sub(): Instruction;
  i32x4TruncSatF32x4s(): Instruction;
  i32x4TruncSatF32x4u(): Instruction;
  i32x4TruncSatF64x2sZero(): Instruction;
  i32x4TruncSatF64x2uZero(): Instruction;
  i64Add(): Instruction;
  i64And(): Instruction;
  i64AtomicLoad(arg0: MemArg): Instruction;
  i64AtomicLoad16U(arg0: MemArg): Instruction;
  i64AtomicLoad32U(arg0: MemArg): Instruction;
  i64AtomicLoad8U(arg0: MemArg): Instruction;
  i64AtomicStore(arg0: MemArg): Instruction;
  i64AtomicStore16(arg0: MemArg): Instruction;
  i64AtomicStore32(arg0: MemArg): Instruction;
  i64AtomicStore8(arg0: MemArg): Instruction;
  i64Clz(): Instruction;
  i64Const(arg0: I64): Instruction;
  i64Ctz(): Instruction;
  i64DivS(): Instruction;
  i64DivU(): Instruction;
  i64Eq(): Instruction;
  i64Eqz(): Instruction;
  i64Extend16s(): Instruction;
  i64Extend32s(): Instruction;
  i64Extend8s(): Instruction;
  i64ExtendI32s(): Instruction;
  i64ExtendI32u(): Instruction;
  i64GeS(): Instruction;
  i64GeU(): Instruction;
  i64GtS(): Instruction;
  i64GtU(): Instruction;
  i64LeS(): Instruction;
  i64LeU(): Instruction;
  i64Load(arg0: MemArg): Instruction;
  i64Load16s(arg0: MemArg): Instruction;
  i64Load16u(arg0: MemArg): Instruction;
  i64Load32s(arg0: MemArg): Instruction;
  i64Load32u(arg0: MemArg): Instruction;
  i64Load8s(arg0: MemArg): Instruction;
  i64Load8u(arg0: MemArg): Instruction;
  i64LtS(): Instruction;
  i64LtU(): Instruction;
  i64Mul(): Instruction;
  i64Ne(): Instruction;
  i64Or(): Instruction;
  i64Popcnt(): Instruction;
  i64ReinterpretF64(): Instruction;
  i64RemS(): Instruction;
  i64RemU(): Instruction;
  i64Rotl(): Instruction;
  i64Rotr(): Instruction;
  i64Shl(): Instruction;
  i64ShrS(): Instruction;
  i64ShrU(): Instruction;
  i64Store(arg0: MemArg): Instruction;
  i64Store16(arg0: MemArg): Instruction;
  i64Store32(arg0: MemArg): Instruction;
  i64Store8(arg0: MemArg): Instruction;
  i64Sub(): Instruction;
  i64TruncF32s(): Instruction;
  i64TruncF32u(): Instruction;
  i64TruncF64s(): Instruction;
  i64TruncF64u(): Instruction;
  i64TruncSatF32s(): Instruction;
  i64TruncSatF32u(): Instruction;
  i64TruncSatF64s(): Instruction;
  i64TruncSatF64u(): Instruction;
  i64Xor(): Instruction;
  i64x2Abs(): Instruction;
  i64x2Add(): Instruction;
  i64x2AllTrue(): Instruction;
  i64x2Bitmask(): Instruction;
  i64x2Eq(): Instruction;
  i64x2ExtendHighI32x4s(): Instruction;
  i64x2ExtendHighI32x4u(): Instruction;
  i64x2ExtendLowI32x4s(): Instruction;
  i64x2ExtendLowI32x4u(): Instruction;
  i64x2ExtmulHighI32x4s(): Instruction;
  i64x2ExtmulHighI32x4u(): Instruction;
  i64x2ExtmulLowI32x4s(): Instruction;
  i64x2ExtmulLowI32x4u(): Instruction;
  i64x2ExtractLane(arg0: LaneIdx): Instruction;
  i64x2GeS(): Instruction;
  i64x2GtS(): Instruction;
  i64x2LeS(): Instruction;
  i64x2LtS(): Instruction;
  i64x2Mul(): Instruction;
  i64x2Ne(): Instruction;
  i64x2Neg(): Instruction;
  i64x2RelaxedLaneselect(): Instruction;
  i64x2ReplaceLane(arg0: LaneIdx): Instruction;
  i64x2Shl(): Instruction;
  i64x2ShrS(): Instruction;
  i64x2ShrU(): Instruction;
  i64x2Splat(): Instruction;
  i64x2Sub(): Instruction;
  i8x16Abs(): Instruction;
  i8x16Add(): Instruction;
  i8x16AddSatS(): Instruction;
  i8x16AddSatU(): Instruction;
  i8x16AllTrue(): Instruction;
  i8x16AvgrU(): Instruction;
  i8x16Bitmask(): Instruction;
  i8x16Eq(): Instruction;
  i8x16ExtractLaneS(arg0: LaneIdx): Instruction;
  i8x16ExtractLaneU(arg0: LaneIdx): Instruction;
  i8x16GeS(): Instruction;
  i8x16GeU(): Instruction;
  i8x16GtS(): Instruction;
  i8x16GtU(): Instruction;
  i8x16LeS(): Instruction;
  i8x16LeU(): Instruction;
  i8x16LtS(): Instruction;
  i8x16LtU(): Instruction;
  i8x16MaxS(): Instruction;
  i8x16MaxU(): Instruction;
  i8x16MinS(): Instruction;
  i8x16MinU(): Instruction;
  i8x16NarrowI16x8s(): Instruction;
  i8x16NarrowI16x8u(): Instruction;
  i8x16Ne(): Instruction;
  i8x16Neg(): Instruction;
  i8x16Popcnt(): Instruction;
  i8x16RelaxedLaneselect(): Instruction;
  i8x16RelaxedSwizzle(): Instruction;
  i8x16ReplaceLane(arg0: LaneIdx): Instruction;
  i8x16Shl(): Instruction;
  i8x16ShrS(): Instruction;
  i8x16ShrU(): Instruction;
  i8x16Shuffle(arg0: LaneIdx, arg1: LaneIdx, arg2: LaneIdx, arg3: LaneIdx, arg4: LaneIdx, arg5: LaneIdx, arg6: LaneIdx, arg7: LaneIdx, arg8: LaneIdx, arg9: LaneIdx, arg10: LaneIdx, arg11: LaneIdx, arg12: LaneIdx, arg13: LaneIdx, arg14: LaneIdx, arg15: LaneIdx): Instruction;
  i8x16Splat(): Instruction;
  i8x16Sub(): Instruction;
  i8x16SubSatS(): Instruction;
  i8x16SubSatU(): Instruction;
  i8x16Swizzle(): Instruction;
  if(arg0: BlockType, arg1: Array<Instruction>, arg2: Array<Instruction> | null): Instruction;
  localGet(arg0: LocalIdx): Instruction;
  localSet(arg0: LocalIdx): Instruction;
  localTee(arg0: LocalIdx): Instruction;
  loop(arg0: BlockType, arg1: Expr): Instruction;
  memoryAtomicNotify(arg0: MemArg): Instruction;
  memoryAtomicWait32(arg0: MemArg): Instruction;
  memoryAtomicWait64(arg0: MemArg): Instruction;
  memoryCopy(arg0: MemIdx, arg1: MemIdx): Instruction;
  memoryFill(arg0: MemIdx): Instruction;
  memoryGrow(arg0: MemIdx): Instruction;
  memoryInit(arg0: DataIdx, arg1: MemIdx): Instruction;
  memorySize(arg0: MemIdx): Instruction;
  nop(): Instruction;
  refAsNonNull(): Instruction;
  refCast(arg0: boolean, arg1: HeapType): Instruction;
  refCastDescEq(arg0: boolean, arg1: HeapType): Instruction;
  refEq(): Instruction;
  refFunc(arg0: FuncIdx): Instruction;
  refGetDesc(): Instruction;
  refI31(): Instruction;
  refIsNull(): Instruction;
  refNull(arg0: HeapType): Instruction;
  refTest(arg0: boolean, arg1: HeapType): Instruction;
  refTestDesc(arg0: boolean, arg1: HeapType): Instruction;
  return(): Instruction;
  returnCall(arg0: FuncIdx): Instruction;
  returnCallIndirect(arg0: TypeIdx, arg1: TableIdx): Instruction;
  returnCallRef(arg0: TypeIdx): Instruction;
  select(types?: Array<ValType> | null): Instruction;
  structGet(arg0: TypeIdx, arg1: U32): Instruction;
  structGetS(arg0: TypeIdx, arg1: U32): Instruction;
  structGetU(arg0: TypeIdx, arg1: U32): Instruction;
  structNew(arg0: TypeIdx): Instruction;
  structNewDefault(arg0: TypeIdx): Instruction;
  structSet(arg0: TypeIdx, arg1: U32): Instruction;
  tableCopy(arg0: TableIdx, arg1: TableIdx): Instruction;
  tableFill(arg0: TableIdx): Instruction;
  tableGet(arg0: TableIdx): Instruction;
  tableGrow(arg0: TableIdx): Instruction;
  tableInit(arg0: ElemIdx, arg1: TableIdx): Instruction;
  tableSet(arg0: TableIdx): Instruction;
  tableSize(arg0: TableIdx): Instruction;
  throw(arg0: TagIdx): Instruction;
  throwRef(): Instruction;
  tryTable(arg0: BlockType, arg1: Array<Catch>, arg2: Expr): Instruction;
  unreachable(): Instruction;
  v128And(): Instruction;
  v128Andnot(): Instruction;
  v128AnyTrue(): Instruction;
  v128Bitselect(): Instruction;
  v128Const(arg0: number, arg1: number, arg2: number, arg3: number, arg4: number, arg5: number, arg6: number, arg7: number, arg8: number, arg9: number, arg10: number, arg11: number, arg12: number, arg13: number, arg14: number, arg15: number): Instruction;
  v128Load(arg0: MemArg): Instruction;
  v128Load16Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Load16Splat(arg0: MemArg): Instruction;
  v128Load16x4s(arg0: MemArg): Instruction;
  v128Load16x4u(arg0: MemArg): Instruction;
  v128Load32Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Load32Splat(arg0: MemArg): Instruction;
  v128Load32Zero(arg0: MemArg): Instruction;
  v128Load32x2s(arg0: MemArg): Instruction;
  v128Load32x2u(arg0: MemArg): Instruction;
  v128Load64Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Load64Splat(arg0: MemArg): Instruction;
  v128Load64Zero(arg0: MemArg): Instruction;
  v128Load8Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Load8Splat(arg0: MemArg): Instruction;
  v128Load8x8s(arg0: MemArg): Instruction;
  v128Load8x8u(arg0: MemArg): Instruction;
  v128Not(): Instruction;
  v128Or(): Instruction;
  v128Store(arg0: MemArg): Instruction;
  v128Store16Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Store32Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Store64Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Store8Lane(arg0: MemArg, arg1: LaneIdx): Instruction;
  v128Xor(): Instruction;
  show(value: Instruction): string;
};

export const LabelIdx: {
  inner(arg0: LabelIdx): number;
  new(arg0: number): LabelIdx;
  show(value: LabelIdx): string;
};

export const LaneIdx: {
  inner(arg0: LaneIdx): number;
  new(arg0: number): LaneIdx;
  show(value: LaneIdx): string;
};

export const Limits: {
  addrValtype(arg0: Limits): ValType;
  i32(arg0: number, arg1: number | null): Limits;
  i64(arg0: bigint, arg1: bigint | null): Limits;
  memAddrBits(arg0: Limits): number;
  show(value: Limits): string;
};

export const LoadOp: {
  f32Load(): LoadOp;
  f64Load(): LoadOp;
  i32AtomicLoad(): LoadOp;
  i32AtomicLoad16U(): LoadOp;
  i32AtomicLoad8U(): LoadOp;
  i32Load(): LoadOp;
  i32Load16s(): LoadOp;
  i32Load16u(): LoadOp;
  i32Load8s(): LoadOp;
  i32Load8u(): LoadOp;
  i64AtomicLoad(): LoadOp;
  i64AtomicLoad16U(): LoadOp;
  i64AtomicLoad32U(): LoadOp;
  i64AtomicLoad8U(): LoadOp;
  i64Load(): LoadOp;
  i64Load16s(): LoadOp;
  i64Load16u(): LoadOp;
  i64Load32s(): LoadOp;
  i64Load32u(): LoadOp;
  i64Load8s(): LoadOp;
  i64Load8u(): LoadOp;
  v128Load(): LoadOp;
  v128Load16Splat(): LoadOp;
  v128Load16x4s(): LoadOp;
  v128Load16x4u(): LoadOp;
  v128Load32Splat(): LoadOp;
  v128Load32Zero(): LoadOp;
  v128Load32x2s(): LoadOp;
  v128Load32x2u(): LoadOp;
  v128Load64Splat(): LoadOp;
  v128Load64Zero(): LoadOp;
  v128Load8Splat(): LoadOp;
  v128Load8x8s(): LoadOp;
  v128Load8x8u(): LoadOp;
  show(value: LoadOp): string;
};

export const LocalIdx: {
  inner(arg0: LocalIdx): number;
  new(arg0: number): LocalIdx;
  show(value: LocalIdx): string;
};

export const Locals: {
  new(arg0: number, arg1: ValType): Locals;
  show(value: Locals): string;
};

export const MemArg: {
  new(arg0: U32, arg1: MemIdx | null, arg2: U64): MemArg;
  show(value: MemArg): string;
};

export const MemIdx: {
  inner(arg0: MemIdx): number;
  new(arg0: number): MemIdx;
  show(value: MemIdx): string;
};

export const MemSec: {
  inner(arg0: MemSec): Array<MemType>;
  new(arg0: Array<MemType>): MemSec;
  show(value: MemSec): string;
};

export const MemType: {
  inner(arg0: MemType): Limits;
  new(arg0: Limits): MemType;
  show(value: MemType): string;
};

export const Module: {
  new(customSecs?: Array<CustomSec>, typeSec?: TypeSec | null, importSec?: ImportSec | null, funcSec?: FuncSec | null, tableSec?: TableSec | null, memSec?: MemSec | null, tagSec?: TagSec | null, globalSec?: GlobalSec | null, exportSec?: ExportSec | null, startSec?: StartSec | null, elemSec?: ElemSec | null, dataCntSec?: DataCntSec | null, codeSec?: CodeSec | null, dataSec?: DataSec | null): Module;
  withCodeSec(arg0: Module, arg1: CodeSec): Module;
  withCustomSecs(arg0: Module, arg1: Array<CustomSec>): Module;
  withDataCntSec(arg0: Module, arg1: DataCntSec): Module;
  withDataSec(arg0: Module, arg1: DataSec): Module;
  withElemSec(arg0: Module, arg1: ElemSec): Module;
  withExportSec(arg0: Module, arg1: ExportSec): Module;
  withFuncSec(arg0: Module, arg1: FuncSec): Module;
  withGlobalSec(arg0: Module, arg1: GlobalSec): Module;
  withImportSec(arg0: Module, arg1: ImportSec): Module;
  withMemSec(arg0: Module, arg1: MemSec): Module;
  withStartSec(arg0: Module, arg1: StartSec): Module;
  withTableSec(arg0: Module, arg1: TableSec): Module;
  withTagSec(arg0: Module, arg1: TagSec): Module;
  withTypeSec(arg0: Module, arg1: TypeSec): Module;
  show(value: Module): string;
};

export const Mut: {
  const(): Mut;
  var(): Mut;
  show(value: Mut): string;
};

export const Name: {
  fromString(arg0: string): Name;
  inner(arg0: Name): OpaqueHandle<"StringView">;
  new(arg0: OpaqueHandle<"StringView">): Name;
  show(value: Name): string;
};

export const NumType: {
  f32(): NumType;
  f64(): NumType;
  i32(): NumType;
  i64(): NumType;
  show(value: NumType): string;
};

export const PackType: {
  i16(): PackType;
  i8(): PackType;
  show(value: PackType): string;
};

export const PrettyPrintContext: {
  indent(arg0: PrettyPrintContext, arg1: number): string;
  indentUnit(arg0: PrettyPrintContext): string;
  new(maxLineWidth?: number, tabsOrSpaces?: TabsOrSpaces, tabWidth?: number, continuationIndent?: number, sourceIndentWidth?: number): PrettyPrintContext;
  show(value: PrettyPrintContext): string;
};

export const RecType: {
  getSubtype(arg0: RecType, arg1: number): SubType | null;
  group(arg0: Array<SubType>): RecType;
  new(arg0: SubType): RecType;
  show(value: RecType): string;
};

export const RefType: {
  abs(arg0: AbsHeapType): RefType;
  getHeapType(arg0: RefType): HeapType;
  isDefaultable(arg0: RefType): boolean;
  isNonNullable(arg0: RefType): boolean;
  isNullable(arg0: RefType): boolean;
  makeNullable(arg0: RefType): RefType;
  new(arg0: boolean, arg1: HeapType): RefType;
  show(value: RefType): string;
};

export const ReplaceLaneOp: {
  f32x4ReplaceLane(): ReplaceLaneOp;
  f64x2ReplaceLane(): ReplaceLaneOp;
  i16x8ReplaceLane(): ReplaceLaneOp;
  i32x4ReplaceLane(): ReplaceLaneOp;
  i64x2ReplaceLane(): ReplaceLaneOp;
  i8x16ReplaceLane(): ReplaceLaneOp;
  show(value: ReplaceLaneOp): string;
};

export const ResultType: {
};

export const S33: {
  inner(arg0: S33): number;
  new(arg0: number): S33;
  show(value: S33): string;
};

export const StartSec: {
  inner(arg0: StartSec): FuncIdx;
  new(arg0: FuncIdx): StartSec;
  show(value: StartSec): string;
};

export const StorageType: {
  isPacked(arg0: StorageType): boolean;
  packType(arg0: PackType): StorageType;
  unpack(arg0: StorageType): ValType;
  valType(arg0: ValType): StorageType;
  show(value: StorageType): string;
};

export const StoreOp: {
  f32Store(): StoreOp;
  f64Store(): StoreOp;
  i32AtomicStore(): StoreOp;
  i32AtomicStore16(): StoreOp;
  i32AtomicStore8(): StoreOp;
  i32Store(): StoreOp;
  i32Store16(): StoreOp;
  i32Store8(): StoreOp;
  i64AtomicStore(): StoreOp;
  i64AtomicStore16(): StoreOp;
  i64AtomicStore32(): StoreOp;
  i64AtomicStore8(): StoreOp;
  i64Store(): StoreOp;
  i64Store16(): StoreOp;
  i64Store32(): StoreOp;
  i64Store8(): StoreOp;
  v128Store(): StoreOp;
  show(value: StoreOp): string;
};

export const SubType: {
  compType(arg0: CompType): SubType;
  getComptype(arg0: SubType): CompType;
  new(arg0: boolean, arg1: Array<TypeIdx>, arg2: CompType): SubType;
  superTypes(arg0: SubType): Array<TypeIdx>;
  show(value: SubType): string;
};

export const TExpr: {
  inner(arg0: TExpr): Array<TInstr>;
  new(arg0: Array<TInstr>): TExpr;
  toExpr(arg0: TExpr): Expr;
  show(value: TExpr): string;
};

export const TInstr: {
  anyConvertExtern(arg0: TInstr): TInstr;
  arrayCopy(arg0: TypeIdx, arg1: TypeIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr, arg5: TInstr, arg6: TInstr): TInstr;
  arrayFill(arg0: TypeIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr;
  arrayGet(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr;
  arrayGetS(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr;
  arrayGetU(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr;
  arrayInitData(arg0: TypeIdx, arg1: DataIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr, arg5: TInstr): TInstr;
  arrayInitElem(arg0: TypeIdx, arg1: ElemIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr, arg5: TInstr): TInstr;
  arrayLen(arg0: TInstr): TInstr;
  arrayNew(arg0: TypeIdx, arg1: TInstr, arg2: TInstr): TInstr;
  arrayNewData(arg0: TypeIdx, arg1: DataIdx, arg2: TInstr, arg3: TInstr): TInstr;
  arrayNewDefault(arg0: TypeIdx, arg1: TInstr): TInstr;
  arrayNewElem(arg0: TypeIdx, arg1: ElemIdx, arg2: TInstr, arg3: TInstr): TInstr;
  arrayNewFixed(arg0: TypeIdx, arg1: Array<TInstr>): TInstr;
  arraySet(arg0: TypeIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  atomicCmpxchg(arg0: AtomicCmpxchgOp, arg1: MemArg, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr;
  atomicFence(): TInstr;
  atomicRmw(arg0: AtomicRmwOp, arg1: MemArg, arg2: TInstr, arg3: TInstr): TInstr;
  binary(arg0: BinaryOp, arg1: TInstr, arg2: TInstr): TInstr;
  block(arg0: BlockType, arg1: TExpr): TInstr;
  br(arg0: LabelIdx, arg1: Array<TInstr>): TInstr;
  brIf(arg0: LabelIdx, arg1: TInstr, arg2: Array<TInstr>): TInstr;
  brOnCast(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType, arg5: TInstr, arg6: Array<TInstr>): TInstr;
  brOnCastFail(arg0: LabelIdx, arg1: boolean, arg2: HeapType, arg3: boolean, arg4: HeapType, arg5: TInstr, arg6: Array<TInstr>): TInstr;
  brOnNonNull(arg0: LabelIdx, arg1: TInstr, arg2: Array<TInstr>): TInstr;
  brOnNull(arg0: LabelIdx, arg1: TInstr, arg2: Array<TInstr>): TInstr;
  brTable(arg0: Array<LabelIdx>, arg1: LabelIdx, arg2: TInstr, arg3: Array<TInstr>): TInstr;
  call(arg0: FuncIdx, arg1: Array<TInstr>): TInstr;
  callIndirect(arg0: TypeIdx, arg1: TableIdx, arg2: Array<TInstr>, arg3: TInstr): TInstr;
  callRef(arg0: TypeIdx, arg1: Array<TInstr>, arg2: TInstr): TInstr;
  dataDrop(arg0: DataIdx): TInstr;
  drop(arg0: TInstr): TInstr;
  elemDrop(arg0: ElemIdx): TInstr;
  externConvertAny(arg0: TInstr): TInstr;
  extractLane(arg0: ExtractLaneOp, arg1: LaneIdx, arg2: TInstr): TInstr;
  f32Const(arg0: F32): TInstr;
  f32x4Splat(arg0: TInstr): TInstr;
  f64Const(arg0: F64): TInstr;
  f64x2Splat(arg0: TInstr): TInstr;
  globalGet(arg0: GlobalIdx): TInstr;
  globalSet(arg0: GlobalIdx, arg1: TInstr): TInstr;
  i16x8Splat(arg0: TInstr): TInstr;
  i31GetS(arg0: TInstr): TInstr;
  i31GetU(arg0: TInstr): TInstr;
  i32Const(arg0: I32): TInstr;
  i32x4Splat(arg0: TInstr): TInstr;
  i64Const(arg0: I64): TInstr;
  i64x2Splat(arg0: TInstr): TInstr;
  i8x16RelaxedSwizzle(arg0: TInstr, arg1: TInstr): TInstr;
  i8x16Shuffle(arg0: LaneIdx, arg1: LaneIdx, arg2: LaneIdx, arg3: LaneIdx, arg4: LaneIdx, arg5: LaneIdx, arg6: LaneIdx, arg7: LaneIdx, arg8: LaneIdx, arg9: LaneIdx, arg10: LaneIdx, arg11: LaneIdx, arg12: LaneIdx, arg13: LaneIdx, arg14: LaneIdx, arg15: LaneIdx, arg16: TInstr, arg17: TInstr): TInstr;
  i8x16Splat(arg0: TInstr): TInstr;
  i8x16Swizzle(arg0: TInstr, arg1: TInstr): TInstr;
  if(arg0: BlockType, arg1: TInstr, arg2: TExpr, arg3: TExpr | null): TInstr;
  load(arg0: LoadOp, arg1: MemArg, arg2: TInstr): TInstr;
  localGet(arg0: LocalIdx): TInstr;
  localSet(arg0: LocalIdx, arg1: TInstr): TInstr;
  localTee(arg0: LocalIdx, arg1: TInstr): TInstr;
  loop(arg0: BlockType, arg1: TExpr): TInstr;
  memoryAtomicNotify(arg0: MemArg, arg1: TInstr, arg2: TInstr): TInstr;
  memoryAtomicWait32(arg0: MemArg, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  memoryAtomicWait64(arg0: MemArg, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  memoryCopy(arg0: MemIdx, arg1: MemIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr;
  memoryFill(arg0: MemIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  memoryGrow(arg0: MemIdx, arg1: TInstr): TInstr;
  memoryInit(arg0: DataIdx, arg1: MemIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr;
  memorySize(arg0: MemIdx): TInstr;
  nop(): TInstr;
  refAsNonNull(arg0: TInstr): TInstr;
  refCast(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr;
  refCastDescEq(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr;
  refEq(arg0: TInstr, arg1: TInstr): TInstr;
  refFunc(arg0: FuncIdx): TInstr;
  refGetDesc(arg0: TInstr): TInstr;
  refI31(arg0: TInstr): TInstr;
  refIsNull(arg0: TInstr): TInstr;
  refNull(arg0: HeapType): TInstr;
  refTest(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr;
  refTestDesc(arg0: boolean, arg1: HeapType, arg2: TInstr): TInstr;
  replaceLane(arg0: ReplaceLaneOp, arg1: LaneIdx, arg2: TInstr, arg3: TInstr): TInstr;
  return(arg0: Array<TInstr>): TInstr;
  returnCall(arg0: FuncIdx, arg1: Array<TInstr>): TInstr;
  returnCallIndirect(arg0: TypeIdx, arg1: TableIdx, arg2: Array<TInstr>, arg3: TInstr): TInstr;
  returnCallRef(arg0: TypeIdx, arg1: Array<TInstr>, arg2: TInstr): TInstr;
  select(arg0: Array<ValType> | null, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  store(arg0: StoreOp, arg1: MemArg, arg2: TInstr, arg3: TInstr): TInstr;
  structGet(arg0: TypeIdx, arg1: U32, arg2: TInstr): TInstr;
  structGetS(arg0: TypeIdx, arg1: U32, arg2: TInstr): TInstr;
  structGetU(arg0: TypeIdx, arg1: U32, arg2: TInstr): TInstr;
  structNew(arg0: TypeIdx, arg1: Array<TInstr>): TInstr;
  structNewDefault(arg0: TypeIdx): TInstr;
  structSet(arg0: TypeIdx, arg1: U32, arg2: TInstr, arg3: TInstr): TInstr;
  tableCopy(arg0: TableIdx, arg1: TableIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr;
  tableFill(arg0: TableIdx, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  tableGet(arg0: TableIdx, arg1: TInstr): TInstr;
  tableGrow(arg0: TableIdx, arg1: TInstr, arg2: TInstr): TInstr;
  tableInit(arg0: ElemIdx, arg1: TableIdx, arg2: TInstr, arg3: TInstr, arg4: TInstr): TInstr;
  tableSet(arg0: TableIdx, arg1: TInstr, arg2: TInstr): TInstr;
  tableSize(arg0: TableIdx): TInstr;
  throw(arg0: TagIdx, arg1: Array<TInstr>): TInstr;
  throwRef(arg0: TInstr): TInstr;
  tryTable(arg0: BlockType, arg1: Array<Catch>, arg2: TExpr): TInstr;
  unary(arg0: UnaryOp, arg1: TInstr): TInstr;
  unreachable(): TInstr;
  v128Const(arg0: number, arg1: number, arg2: number, arg3: number, arg4: number, arg5: number, arg6: number, arg7: number, arg8: number, arg9: number, arg10: number, arg11: number, arg12: number, arg13: number, arg14: number, arg15: number): TInstr;
  v128LoadLane(arg0: V128LoadLaneOp, arg1: MemArg, arg2: LaneIdx, arg3: TInstr, arg4: TInstr): TInstr;
  v128Shift(arg0: V128ShiftOp, arg1: TInstr, arg2: TInstr): TInstr;
  v128StoreLane(arg0: V128StoreLaneOp, arg1: MemArg, arg2: LaneIdx, arg3: TInstr, arg4: TInstr): TInstr;
  v128Ternary(arg0: V128TernaryOp, arg1: TInstr, arg2: TInstr, arg3: TInstr): TInstr;
  show(value: TInstr): string;
};

export const TInstrKind: {
  show(value: TInstrKind): string;
};

export const Table: {
  new(arg0: TableType, arg1: Expr | null): Table;
  show(value: Table): string;
};

export const TableIdx: {
  inner(arg0: TableIdx): number;
  new(arg0: number): TableIdx;
  show(value: TableIdx): string;
};

export const TableSec: {
  inner(arg0: TableSec): Array<Table>;
  new(arg0: Array<Table>): TableSec;
  show(value: TableSec): string;
};

export const TableType: {
  new(arg0: RefType, arg1: Limits): TableType;
  show(value: TableType): string;
};

export const TabsOrSpaces: {
  spaces(): TabsOrSpaces;
  tabs(): TabsOrSpaces;
  show(value: TabsOrSpaces): string;
};

export const TagIdx: {
  inner(arg0: TagIdx): number;
  new(arg0: number): TagIdx;
  show(value: TagIdx): string;
};

export const TagSec: {
  inner(arg0: TagSec): Array<TagType>;
  new(arg0: Array<TagType>): TagSec;
  show(value: TagSec): string;
};

export const TagType: {
  inner(arg0: TagType): TypeIdx;
  new(arg0: TypeIdx): TagType;
  show(value: TagType): string;
};

export const TypeIdx: {
  new(arg0: number): TypeIdx;
  rec(arg0: number): TypeIdx;
  show(value: TypeIdx): string;
};

export const TypeSec: {
  inner(arg0: TypeSec): Array<RecType>;
  new(arg0: Array<RecType>): TypeSec;
  show(value: TypeSec): string;
};

export const U32: {
  inner(arg0: U32): number;
  new(arg0: number): U32;
  show(value: U32): string;
};

export const U64: {
  inner(arg0: U64): bigint;
  new(arg0: bigint): U64;
  show(value: U64): string;
};

export const UnaryOp: {
  f32Abs(): UnaryOp;
  f32Ceil(): UnaryOp;
  f32ConvertI32s(): UnaryOp;
  f32ConvertI32u(): UnaryOp;
  f32ConvertI64s(): UnaryOp;
  f32ConvertI64u(): UnaryOp;
  f32DemoteF64(): UnaryOp;
  f32Floor(): UnaryOp;
  f32Nearest(): UnaryOp;
  f32Neg(): UnaryOp;
  f32ReinterpretI32(): UnaryOp;
  f32Sqrt(): UnaryOp;
  f32Trunc(): UnaryOp;
  f32x4Abs(): UnaryOp;
  f32x4Ceil(): UnaryOp;
  f32x4ConvertI32x4s(): UnaryOp;
  f32x4ConvertI32x4u(): UnaryOp;
  f32x4DemoteF64x2Zero(): UnaryOp;
  f32x4Floor(): UnaryOp;
  f32x4Nearest(): UnaryOp;
  f32x4Neg(): UnaryOp;
  f32x4Sqrt(): UnaryOp;
  f32x4Trunc(): UnaryOp;
  f64Abs(): UnaryOp;
  f64Ceil(): UnaryOp;
  f64ConvertI32s(): UnaryOp;
  f64ConvertI32u(): UnaryOp;
  f64ConvertI64s(): UnaryOp;
  f64ConvertI64u(): UnaryOp;
  f64Floor(): UnaryOp;
  f64Nearest(): UnaryOp;
  f64Neg(): UnaryOp;
  f64PromoteF32(): UnaryOp;
  f64ReinterpretI64(): UnaryOp;
  f64Sqrt(): UnaryOp;
  f64Trunc(): UnaryOp;
  f64x2Abs(): UnaryOp;
  f64x2Ceil(): UnaryOp;
  f64x2ConvertLowI32x4s(): UnaryOp;
  f64x2ConvertLowI32x4u(): UnaryOp;
  f64x2Floor(): UnaryOp;
  f64x2Nearest(): UnaryOp;
  f64x2Neg(): UnaryOp;
  f64x2PromoteLowF32x4(): UnaryOp;
  f64x2Sqrt(): UnaryOp;
  f64x2Trunc(): UnaryOp;
  i16x8Abs(): UnaryOp;
  i16x8AllTrue(): UnaryOp;
  i16x8Bitmask(): UnaryOp;
  i16x8ExtaddPairwiseI8x16s(): UnaryOp;
  i16x8ExtaddPairwiseI8x16u(): UnaryOp;
  i16x8ExtendHighI8x16s(): UnaryOp;
  i16x8ExtendHighI8x16u(): UnaryOp;
  i16x8ExtendLowI8x16s(): UnaryOp;
  i16x8ExtendLowI8x16u(): UnaryOp;
  i16x8Neg(): UnaryOp;
  i32Clz(): UnaryOp;
  i32Ctz(): UnaryOp;
  i32Eqz(): UnaryOp;
  i32Extend16s(): UnaryOp;
  i32Extend8s(): UnaryOp;
  i32Popcnt(): UnaryOp;
  i32ReinterpretF32(): UnaryOp;
  i32TruncF32s(): UnaryOp;
  i32TruncF32u(): UnaryOp;
  i32TruncF64s(): UnaryOp;
  i32TruncF64u(): UnaryOp;
  i32TruncSatF32s(): UnaryOp;
  i32TruncSatF32u(): UnaryOp;
  i32TruncSatF64s(): UnaryOp;
  i32TruncSatF64u(): UnaryOp;
  i32WrapI64(): UnaryOp;
  i32x4Abs(): UnaryOp;
  i32x4AllTrue(): UnaryOp;
  i32x4Bitmask(): UnaryOp;
  i32x4ExtaddPairwiseI16x8s(): UnaryOp;
  i32x4ExtaddPairwiseI16x8u(): UnaryOp;
  i32x4ExtendHighI16x8s(): UnaryOp;
  i32x4ExtendHighI16x8u(): UnaryOp;
  i32x4ExtendLowI16x8s(): UnaryOp;
  i32x4ExtendLowI16x8u(): UnaryOp;
  i32x4Neg(): UnaryOp;
  i32x4RelaxedTruncF32x4s(): UnaryOp;
  i32x4RelaxedTruncF32x4u(): UnaryOp;
  i32x4RelaxedTruncZeroF64x2s(): UnaryOp;
  i32x4RelaxedTruncZeroF64x2u(): UnaryOp;
  i32x4TruncSatF32x4s(): UnaryOp;
  i32x4TruncSatF32x4u(): UnaryOp;
  i32x4TruncSatF64x2sZero(): UnaryOp;
  i32x4TruncSatF64x2uZero(): UnaryOp;
  i64Clz(): UnaryOp;
  i64Ctz(): UnaryOp;
  i64Eqz(): UnaryOp;
  i64Extend16s(): UnaryOp;
  i64Extend32s(): UnaryOp;
  i64Extend8s(): UnaryOp;
  i64ExtendI32s(): UnaryOp;
  i64ExtendI32u(): UnaryOp;
  i64Popcnt(): UnaryOp;
  i64ReinterpretF64(): UnaryOp;
  i64TruncF32s(): UnaryOp;
  i64TruncF32u(): UnaryOp;
  i64TruncF64s(): UnaryOp;
  i64TruncF64u(): UnaryOp;
  i64TruncSatF32s(): UnaryOp;
  i64TruncSatF32u(): UnaryOp;
  i64TruncSatF64s(): UnaryOp;
  i64TruncSatF64u(): UnaryOp;
  i64x2Abs(): UnaryOp;
  i64x2AllTrue(): UnaryOp;
  i64x2Bitmask(): UnaryOp;
  i64x2ExtendHighI32x4s(): UnaryOp;
  i64x2ExtendHighI32x4u(): UnaryOp;
  i64x2ExtendLowI32x4s(): UnaryOp;
  i64x2ExtendLowI32x4u(): UnaryOp;
  i64x2Neg(): UnaryOp;
  i8x16Abs(): UnaryOp;
  i8x16AllTrue(): UnaryOp;
  i8x16Bitmask(): UnaryOp;
  i8x16Neg(): UnaryOp;
  i8x16Popcnt(): UnaryOp;
  v128AnyTrue(): UnaryOp;
  v128Not(): UnaryOp;
  show(value: UnaryOp): string;
};

export const V128LoadLaneOp: {
  v128Load16Lane(): V128LoadLaneOp;
  v128Load32Lane(): V128LoadLaneOp;
  v128Load64Lane(): V128LoadLaneOp;
  v128Load8Lane(): V128LoadLaneOp;
  show(value: V128LoadLaneOp): string;
};

export const V128ShiftOp: {
  i16x8Shl(): V128ShiftOp;
  i16x8ShrS(): V128ShiftOp;
  i16x8ShrU(): V128ShiftOp;
  i32x4Shl(): V128ShiftOp;
  i32x4ShrS(): V128ShiftOp;
  i32x4ShrU(): V128ShiftOp;
  i64x2Shl(): V128ShiftOp;
  i64x2ShrS(): V128ShiftOp;
  i64x2ShrU(): V128ShiftOp;
  i8x16Shl(): V128ShiftOp;
  i8x16ShrS(): V128ShiftOp;
  i8x16ShrU(): V128ShiftOp;
  show(value: V128ShiftOp): string;
};

export const V128StoreLaneOp: {
  v128Store16Lane(): V128StoreLaneOp;
  v128Store32Lane(): V128StoreLaneOp;
  v128Store64Lane(): V128StoreLaneOp;
  v128Store8Lane(): V128StoreLaneOp;
  show(value: V128StoreLaneOp): string;
};

export const V128TernaryOp: {
  f32x4RelaxedMadd(): V128TernaryOp;
  f32x4RelaxedNmadd(): V128TernaryOp;
  f64x2RelaxedMadd(): V128TernaryOp;
  f64x2RelaxedNmadd(): V128TernaryOp;
  i16x8RelaxedLaneselect(): V128TernaryOp;
  i32x4RelaxedDotI8x16i7x16AddS(): V128TernaryOp;
  i32x4RelaxedLaneselect(): V128TernaryOp;
  i64x2RelaxedLaneselect(): V128TernaryOp;
  i8x16RelaxedLaneselect(): V128TernaryOp;
  v128Bitselect(): V128TernaryOp;
  show(value: V128TernaryOp): string;
};

export const ValType: {
  anyref(): ValType;
  bottom(): ValType;
  eqrefNull(): ValType;
  externref(): ValType;
  f32(): ValType;
  f64(): ValType;
  funcref(): ValType;
  i31ref(): ValType;
  i31refNullable(): ValType;
  i32(): ValType;
  i64(): ValType;
  isRefType(arg0: ValType): boolean;
  numType(arg0: NumType): ValType;
  refArrayNonnull(arg0: TypeIdx): ValType;
  refArrayNullable(arg0: TypeIdx): ValType;
  refNull(arg0: HeapType): ValType;
  refNullArrayOf(arg0: TypeIdx): ValType;
  refNullExn(): ValType;
  refType(arg0: RefType): ValType;
  v128(): ValType;
  show(value: ValType): string;
};
