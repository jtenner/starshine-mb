///|
pub(all) struct S33(UInt) derive(Eq, Hash)

///|
pub(all) struct I32(Int) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct I64(Int64) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct F32(Float) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct F64(Double) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct U32(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct U64(UInt64) derive(Eq, Arbitrary, Hash)

///|
pub(all) enum NumType {
  F32NumType
  F64NumType
  I32NumType
  I64NumType
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum AbsHeapType {
  ExnAbsHeapType
  ArrayAbsHeapType
  StructAbsHeapType
  I31AbsHeapType
  EqAbsHeapType
  AnyAbsHeapType
  ExternAbsHeapType
  FuncAbsHeapType
  NoneAbsHeapType
  NoExternAbsHeapType
  NoFuncAbsHeapType
  NoExnAbsHeapType
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum HeapType {
  AbsHeapTypeHeapType(AbsHeapType)
  HeapType(TypeIdx)
  DefTypeHeapType(DefType)
} derive(Eq, Hash)

///|
pub(all) enum RefType {
  HeapTypeRefType(Bool, HeapType)
  AbsHeapTypeRefType(AbsHeapType)
} derive(Arbitrary, Hash)

///|
pub(all) enum ValType {
  NumTypeValType(NumType)
  VecTypeValType
  RefTypeValType(RefType)
  BotValType
} derive(Eq, Hash)

///|
pub type ResultType = Array[ValType]

///|
pub(all) enum PackType {
  I16PackType
  I8PackType
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum StorageType {
  ValTypeStorageType(ValType)
  PackTypeStorageType(PackType)
} derive(Eq, Arbitrary, Hash)

///|
pub(all) struct FieldType(StorageType, Mut) derive(Eq, Arbitrary, Hash)

///|
pub(all) enum Mut {
  Const
  Var
} derive(Arbitrary, Eq, Hash)

///|
pub(all) enum TypeIdx {
  TypeIdx(UInt)
  RecIdx(UInt)
} derive(Eq, Hash)

///|
pub(all) struct FuncIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct TableIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct MemIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct GlobalIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct TagIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct ElemIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct DataIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct LocalIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct LabelIdx(UInt) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct LaneIdx(Byte) derive(Eq, Hash)

///|
pub(all) enum CompType {
  ArrayCompType(FieldType)
  StructCompType(Array[FieldType])
  FuncCompType(ResultType, ResultType)
} derive(Eq, Hash)

///|
pub(all) enum SubType {
  SubType(Bool, Array[TypeIdx], CompType)
  CompTypeSubType(CompType)
} derive(Eq, Hash)

///|
pub(all) enum RecType {
  SingleRecType(SubType)
  GroupRecType(Array[SubType])
} derive(Hash)

///|
pub(all) struct DefType(RecType, UInt) derive(Eq, Hash)

///|
pub(all) enum Limits {
  I32Limits(UInt, UInt?)
  I64Limits(UInt64, UInt64?)
} derive(Eq, Hash)

///|
pub(all) struct TagType(TypeIdx) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct GlobalType(ValType, Bool) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct MemType(Limits) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct TableType(RefType, Limits) derive(Eq, Arbitrary, Hash)

///|
pub(all) enum ExternType {
  FuncExternType(TypeIdx)
  TableExternType(TableType)
  MemExternType(MemType)
  GlobalExternType(GlobalType)
  TagExternType(TagType)
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum ExternIdx {
  FuncExternIdx(FuncIdx)
  TableExternIdx(TableIdx)
  MemExternIdx(MemIdx)
  GlobalExternIdx(GlobalIdx)
  TagExternIdx(TagIdx)
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum ElemMode {
  Passive
  Active(TableIdx, Expr)
  Declarative
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum ElemKind {
  FuncsElemKind(Array[FuncIdx])
  FuncExprsElemKind(Array[Expr])
  TypedExprsElemKind(RefType, Array[Expr])
} derive(Eq, Arbitrary, Hash)

///|
pub(all) struct Elem(ElemMode, ElemKind) derive(Eq, Hash)

///|
pub(all) struct Expr(Array[Instruction]) derive(Eq, Hash)

///|
pub(all) struct Import(Name, Name, ExternType) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct Table(TableType, Expr?) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct Global(GlobalType, Expr) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct Export(Name, ExternIdx) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct Locals(UInt, ValType) derive(Eq, Hash)

///|
pub(all) enum DataMode {
  Active(MemIdx, Expr)
  Passive
} derive(Eq, Arbitrary, Hash)

///|
pub(all) struct Data(DataMode, Bytes) derive(Eq, Hash)

///|
pub(all) struct Name(StringView) derive(Eq, Hash)

///|
pub(all) struct Module {
  custom_secs : Array[CustomSec]
  type_sec : TypeSec?
  import_sec : ImportSec?
  func_sec : FuncSec?
  table_sec : TableSec?
  mem_sec : MemSec?
  tag_sec : TagSec?
  global_sec : GlobalSec?
  export_sec : ExportSec?
  start_sec : StartSec?
  elem_sec : ElemSec?
  data_cnt_sec : DataCntSec?
  code_sec : CodeSec?
  data_sec : DataSec?
} derive(Hash)

///|
pub(all) struct FuncType(Array[ValType], Array[ValType]) derive(Hash, Eq)

///|
pub(all) struct Env {
  global_types : Array[SubType]
  rec_stack : Stack[Array[SubType]]
  funcs : Array[FuncType]
  tables : Array[TableType]
  mems : Array[MemType]
  globals : Array[GlobalType]
  elems : Array[Elem]
  datas : Array[Data]
  tags : Array[TagType]
  locals : Array[ValType]
  labels : Stack[Array[ValType]]
  return_type : Array[ValType]?
} derive(Hash)

///|
pub(all) enum Func {
  Func(Array[Locals], Expr)
  TFunc(Array[ValType], TExpr)
} derive(Eq, Hash)

///|
pub(all) struct CustomSec(Name, Bytes) derive(Eq, Hash)

///|
pub(all) struct TypeSec(Array[RecType]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct ImportSec(Array[Import]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct FuncSec(Array[TypeIdx]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct TableSec(Array[Table]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct MemSec(Array[MemType]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct GlobalSec(Array[Global]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct ExportSec(Array[Export]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct StartSec(FuncIdx) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct ElemSec(Array[Elem]) derive(Eq, Hash)

///|
pub(all) struct DataCntSec(U32) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct TagSec(Array[TagType]) derive(Eq, Arbitrary, Hash)

///|
pub(all) struct MemArg(U32, MemIdx?, U64) derive(Hash)

///|
pub(all) enum BlockType {
  EmptyBlockType
  ValTypeBlockType(ValType)
  TypeIdxBlockType(TypeIdx)
} derive(Eq, Arbitrary, Hash)

///|
pub(all) enum Catch {
  Catch(TagIdx, LabelIdx)
  CatchRef(TagIdx, LabelIdx)
  CatchAll(LabelIdx)
  CatchAllRef(LabelIdx)
} derive(Eq, Arbitrary, Hash)

///|
pub(all) struct CodeSec(Array[Func]) derive(Eq, Hash)

///|
pub(all) struct DataSec(Array[Data]) derive(Eq, Hash)

///|
pub(all) struct CastOp(Bool, Bool) derive(Eq, Arbitrary, Show, Hash)

///|
pub(all) enum Instruction {
  Unreachable
  Nop
  Block(BlockType, Expr)
  Loop(BlockType, Expr)
  If(BlockType, Array[Instruction], Array[Instruction]?)
  Throw(TagIdx)
  ThrowRef
  Br(LabelIdx)
  BrIf(LabelIdx)
  BrTable(Array[LabelIdx], LabelIdx)
  Return
  Call(FuncIdx)
  CallIndirect(TypeIdx, TableIdx)
  ReturnCall(FuncIdx)
  ReturnCallIndirect(TypeIdx, TableIdx)
  CallRef(TypeIdx)
  ReturnCallRef(TypeIdx)
  Drop
  Select(Array[ValType]?)
  TryTable(BlockType, Array[Catch], Expr)
  LocalGet(LocalIdx)
  LocalSet(LocalIdx)
  LocalTee(LocalIdx)
  GlobalGet(GlobalIdx)
  GlobalSet(GlobalIdx)
  TableGet(TableIdx)
  TableSet(TableIdx)
  I32Load(MemArg)
  I64Load(MemArg)
  F32Load(MemArg)
  F64Load(MemArg)
  I32Load8S(MemArg)
  I32Load8U(MemArg)
  I32Load16S(MemArg)
  I32Load16U(MemArg)
  I64Load8S(MemArg)
  I64Load8U(MemArg)
  I64Load16S(MemArg)
  I64Load16U(MemArg)
  I64Load32S(MemArg)
  I64Load32U(MemArg)
  I32Store(MemArg)
  I64Store(MemArg)
  F32Store(MemArg)
  F64Store(MemArg)
  I32Store8(MemArg)
  I32Store16(MemArg)
  I64Store8(MemArg)
  I64Store16(MemArg)
  I64Store32(MemArg)
  MemorySize(MemIdx)
  MemoryGrow(MemIdx)
  I32Const(I32)
  I64Const(I64)
  F32Const(F32)
  F64Const(F64)
  I32Eqz
  I32Eq
  I32Ne
  I32LtS
  I32LtU
  I32GtS
  I32GtU
  I32LeS
  I32LeU
  I32GeS
  I32GeU
  I64Eqz
  I64Eq
  I64Ne
  I64LtS
  I64LtU
  I64GtS
  I64GtU
  I64LeS
  I64LeU
  I64GeS
  I64GeU
  F32Eq
  F32Ne
  F32Lt
  F32Gt
  F32Le
  F32Ge
  F64Eq
  F64Ne
  F64Lt
  F64Gt
  F64Le
  F64Ge
  I32Clz
  I32Ctz
  I32Popcnt
  I32Add
  I32Sub
  I32Mul
  I32DivS
  I32DivU
  I32RemS
  I32RemU
  I32And
  I32Or
  I32Xor
  I32Shl
  I32ShrS
  I32ShrU
  I32Rotl
  I32Rotr
  I64Clz
  I64Ctz
  I64Popcnt
  I64Add
  I64Sub
  I64Mul
  I64DivS
  I64DivU
  I64RemS
  I64RemU
  I64And
  I64Or
  I64Xor
  I64Shl
  I64ShrS
  I64ShrU
  I64Rotl
  I64Rotr
  F32Abs
  F32Neg
  F32Ceil
  F32Floor
  F32Trunc
  F32Nearest
  F32Sqrt
  F32Add
  F32Sub
  F32Mul
  F32Div
  F32Min
  F32Max
  F32Copysign
  F64Abs
  F64Neg
  F64Ceil
  F64Floor
  F64Trunc
  F64Nearest
  F64Sqrt
  F64Add
  F64Sub
  F64Mul
  F64Div
  F64Min
  F64Max
  F64Copysign
  I32WrapI64
  I32TruncF32S
  I32TruncF32U
  I32TruncF64S
  I32TruncF64U
  I64ExtendI32S
  I64ExtendI32U
  I64TruncF32S
  I64TruncF32U
  I64TruncF64S
  I64TruncF64U
  F32ConvertI32S
  F32ConvertI32U
  F32ConvertI64S
  F32ConvertI64U
  F32DemoteF64
  F64ConvertI32S
  F64ConvertI32U
  F64ConvertI64S
  F64ConvertI64U
  F64PromoteF32
  I32ReinterpretF32
  I64ReinterpretF64
  F32ReinterpretI32
  F64ReinterpretI64
  I32Extend8S
  I32Extend16S
  I64Extend8S
  I64Extend16S
  I64Extend32S
  RefNull(HeapType)
  RefIsNull
  RefFunc(FuncIdx)
  RefEq
  RefAsNonNull
  BrOnNull(LabelIdx)
  BrOnNonNull(LabelIdx)
  StructNew(TypeIdx)
  StructNewDefault(TypeIdx)
  StructGet(TypeIdx, U32)
  StructGetS(TypeIdx, U32)
  StructGetU(TypeIdx, U32)
  StructSet(TypeIdx, U32)
  ArrayNew(TypeIdx)
  ArrayNewDefault(TypeIdx)
  ArrayNewFixed(TypeIdx, U32)
  ArrayNewData(TypeIdx, DataIdx)
  ArrayNewElem(TypeIdx, ElemIdx)
  ArrayGet(TypeIdx)
  ArrayGetS(TypeIdx)
  ArrayGetU(TypeIdx)
  ArraySet(TypeIdx)
  ArrayLen
  ArrayFill(TypeIdx)
  ArrayCopy(TypeIdx, TypeIdx)
  ArrayInitData(TypeIdx, DataIdx)
  ArrayInitElem(TypeIdx, ElemIdx)
  RefTest(Bool, HeapType)
  RefCast(Bool, HeapType)
  BrOnCast(LabelIdx, CastOp, HeapType, HeapType)
  BrOnCastFail(LabelIdx, CastOp, HeapType, HeapType)
  AnyConvertExtern
  ExternConvertAny
  RefI31
  I31GetS
  I31GetU
  I32TruncSatF32S
  I32TruncSatF32U
  I32TruncSatF64S
  I32TruncSatF64U
  I64TruncSatF32S
  I64TruncSatF32U
  I64TruncSatF64S
  I64TruncSatF64U
  MemoryInit(DataIdx, MemIdx)
  DataDrop(DataIdx)
  MemoryCopy(MemIdx, MemIdx)
  MemoryFill(MemIdx)
  TableInit(ElemIdx, TableIdx)
  ElemDrop(ElemIdx)
  TableCopy(TableIdx, TableIdx)
  TableGrow(TableIdx)
  TableSize(TableIdx)
  TableFill(TableIdx)
  V128Load(MemArg)
  V128Load8x8S(MemArg)
  V128Load8x8U(MemArg)
  V128Load16x4S(MemArg)
  V128Load16x4U(MemArg)
  V128Load32x2S(MemArg)
  V128Load32x2U(MemArg)
  V128Load8Splat(MemArg)
  V128Load16Splat(MemArg)
  V128Load32Splat(MemArg)
  V128Load64Splat(MemArg)
  V128Store(MemArg)
  V128Const(
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte
  )
  I8x16Shuffle(
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx
  )
  I8x16Swizzle
  I8x16Splat
  I16x8Splat
  I32x4Splat
  I64x2Splat
  F32x4Splat
  F64x2Splat
  I8x16ExtractLaneS(LaneIdx)
  I8x16ExtractLaneU(LaneIdx)
  I8x16ReplaceLane(LaneIdx)
  I16x8ExtractLaneS(LaneIdx)
  I16x8ExtractLaneU(LaneIdx)
  I16x8ReplaceLane(LaneIdx)
  I32x4ExtractLane(LaneIdx)
  I32x4ReplaceLane(LaneIdx)
  I64x2ExtractLane(LaneIdx)
  I64x2ReplaceLane(LaneIdx)
  F32x4ExtractLane(LaneIdx)
  F32x4ReplaceLane(LaneIdx)
  F64x2ExtractLane(LaneIdx)
  F64x2ReplaceLane(LaneIdx)
  I8x16Eq
  I8x16Ne
  I8x16LtS
  I8x16LtU
  I8x16GtS
  I8x16GtU
  I8x16LeS
  I8x16LeU
  I8x16GeS
  I8x16GeU
  I16x8Eq
  I16x8Ne
  I16x8LtS
  I16x8LtU
  I16x8GtS
  I16x8GtU
  I16x8LeS
  I16x8LeU
  I16x8GeS
  I16x8GeU
  I32x4Eq
  I32x4Ne
  I32x4LtS
  I32x4LtU
  I32x4GtS
  I32x4GtU
  I32x4LeS
  I32x4LeU
  I32x4GeS
  I32x4GeU
  F32x4Eq
  F32x4Ne
  F32x4Lt
  F32x4Gt
  F32x4Le
  F32x4Ge
  F64x2Eq
  F64x2Ne
  F64x2Lt
  F64x2Gt
  F64x2Le
  F64x2Ge
  V128Not
  V128And
  V128Andnot
  V128Or
  V128Xor
  V128Bitselect
  V128AnyTrue
  V128Load8Lane(MemArg, LaneIdx)
  V128Load16Lane(MemArg, LaneIdx)
  V128Load32Lane(MemArg, LaneIdx)
  V128Load64Lane(MemArg, LaneIdx)
  V128Store8Lane(MemArg, LaneIdx)
  V128Store16Lane(MemArg, LaneIdx)
  V128Store32Lane(MemArg, LaneIdx)
  V128Store64Lane(MemArg, LaneIdx)
  V128Load32Zero(MemArg)
  V128Load64Zero(MemArg)
  F32x4DemoteF64x2Zero
  F64x2PromoteLowF32x4
  I8x16Abs
  I8x16Neg
  I8x16Popcnt
  I8x16AllTrue
  I8x16Bitmask
  I8x16NarrowI16x8S
  I8x16NarrowI16x8U
  F32x4Ceil
  F32x4Floor
  F32x4Trunc
  F32x4Nearest
  I8x16Shl
  I8x16ShrS
  I8x16ShrU
  I8x16Add
  I8x16AddSatS
  I8x16AddSatU
  I8x16Sub
  I8x16SubSatS
  I8x16SubSatU
  F64x2Ceil
  F64x2Floor
  I8x16MinS
  I8x16MinU
  I8x16MaxS
  I8x16MaxU
  F64x2Trunc
  I8x16AvgrU
  I16x8ExtaddPairwiseI8x16S
  I16x8ExtaddPairwiseI8x16U
  I32x4ExtaddPairwiseI16x8S
  I32x4ExtaddPairwiseI16x8U
  I16x8Abs
  I16x8Neg
  I16x8Q15mulrSatS
  I16x8AllTrue
  I16x8Bitmask
  I16x8NarrowI32x4S
  I16x8NarrowI32x4U
  I16x8ExtendLowI8x16S
  I16x8ExtendHighI8x16S
  I16x8ExtendLowI8x16U
  I16x8ExtendHighI8x16U
  I16x8Shl
  I16x8ShrS
  I16x8ShrU
  I16x8Add
  I16x8AddSatS
  I16x8AddSatU
  I16x8Sub
  I16x8SubSatS
  I16x8SubSatU
  F64x2Nearest
  I16x8Mul
  I16x8MinS
  I16x8MinU
  I16x8MaxS
  I16x8MaxU
  I16x8AvgrU
  I16x8ExtmulLowI8x16S
  I16x8ExtmulHighI8x16S
  I16x8ExtmulLowI8x16U
  I16x8ExtmulHighI8x16U
  I32x4Abs
  I32x4Neg
  I32x4AllTrue
  I32x4Bitmask
  I32x4ExtendLowI16x8S
  I32x4ExtendHighI16x8S
  I32x4ExtendLowI16x8U
  I32x4ExtendHighI16x8U
  I32x4Shl
  I32x4ShrS
  I32x4ShrU
  I32x4Add
  I32x4Sub
  I32x4Mul
  I32x4MinS
  I32x4MinU
  I32x4MaxS
  I32x4MaxU
  I32x4DotI16x8S
  I32x4ExtmulLowI16x8S
  I32x4ExtmulHighI16x8S
  I32x4ExtmulLowI16x8U
  I32x4ExtmulHighI16x8U
  I64x2Abs
  I64x2Neg
  I64x2AllTrue
  I64x2Bitmask
  I64x2ExtendLowI32x4S
  I64x2ExtendHighI32x4S
  I64x2ExtendLowI32x4U
  I64x2ExtendHighI32x4U
  I64x2Shl
  I64x2ShrS
  I64x2ShrU
  I64x2Add
  I64x2Sub
  I64x2Mul
  I64x2Eq
  I64x2Ne
  I64x2LtS
  I64x2GtS
  I64x2LeS
  I64x2GeS
  I64x2ExtmulLowI32x4S
  I64x2ExtmulHighI32x4S
  I64x2ExtmulLowI32x4U
  I64x2ExtmulHighI32x4U
  F32x4Abs
  F32x4Neg
  F32x4Sqrt
  F32x4Add
  F32x4Sub
  F32x4Mul
  F32x4Div
  F32x4Min
  F32x4Max
  F32x4Pmin
  F32x4Pmax
  F64x2Abs
  F64x2Neg
  F64x2Sqrt
  F64x2Add
  F64x2Sub
  F64x2Mul
  F64x2Div
  F64x2Min
  F64x2Max
  F64x2Pmin
  F64x2Pmax
  I32x4TruncSatF32x4S
  I32x4TruncSatF32x4U
  F32x4ConvertI32x4S
  F32x4ConvertI32x4U
  I32x4TruncSatF64x2SZero
  I32x4TruncSatF64x2UZero
  F64x2ConvertLowI32x4S
  F64x2ConvertLowI32x4U
  I8x16RelaxedSwizzle
  I32x4RelaxedTruncF32x4S
  I32x4RelaxedTruncF32x4U
  I32x4RelaxedTruncZeroF64x2S
  I32x4RelaxedTruncZeroF64x2U
  F32x4RelaxedMadd
  F32x4RelaxedNmadd
  F64x2RelaxedMadd
  F64x2RelaxedNmadd
  I8x16RelaxedLaneselect
  I16x8RelaxedLaneselect
  I32x4RelaxedLaneselect
  I64x2RelaxedLaneselect
  F32x4RelaxedMin
  F32x4RelaxedMax
  F64x2RelaxedMin
  F64x2RelaxedMax
  I16x8RelaxedQ15mulrS
  I16x8RelaxedDotI8x16I7x16S
  I32x4RelaxedDotI8x16I7x16AddS
} derive(Eq, Hash)

///|
type Stack[T] = Array[T]

///|
pub fn Limits::mem_addr_bits(lim : Limits) -> Int {
  match lim {
    I32Limits(_, _) => 32
    I64Limits(_, _) => 64
  }
}

///|
pub fn RefType::is_nullable(rt : RefType) -> Bool {
  match rt {
    HeapTypeRefType(b, _) => b
    AbsHeapTypeRefType(_) => true
  }
}

///|
pub fn RefType::get_heap_type(rt : RefType) -> HeapType {
  match rt {
    HeapTypeRefType(_, ht) => ht
    AbsHeapTypeRefType(ahs) => AbsHeapTypeHeapType(ahs)
  }
}

///|
pub fn SubType::super_types(self : SubType) -> Array[TypeIdx] {
  match self {
    SubType(_, sts, _) => sts
    CompTypeSubType(_) => []
  }
}

///|
pub fn SubType::get_comptype(self : SubType) -> CompType {
  match self {
    SubType(_, _, ct) => ct
    CompTypeSubType(ct) => ct
  }
}

///|
pub fn RecType::get_subtype(self : RecType, idx : UInt) -> SubType? {
  match (self, idx) {
    (SingleRecType(st), 0) => Some(st)
    (GroupRecType(sts), i) => sts.get(i.reinterpret_as_int())
    _ => None
  }
}

///|
pub fn DefType::project(self : DefType) -> SubType? {
  let DefType(rt, n) = self
  match rt {
    SingleRecType(st) => if n == 0 { Some(st) } else { None }
    GroupRecType(sts) => sts.get(n.reinterpret_as_int())
  }
}

///|
pub impl Show for FuncType with output(self, logger) {
  let FuncType(props, results) = self
  logger.write_string("FuncType {\n  props : ")
  props.output(logger)
  logger.write_string("\n  results : ")
  results.output(logger)
  logger.write_string("\n}")
}

///|
pub impl Show for Env with output(self, logger) {
  logger.write_string("Env {\n  global_types : ")
  self.global_types.output(logger)
  logger.write_string("\n  rec_stack : ")
  self.rec_stack.output(logger)
  logger.write_string("\n  funcs : ")
  self.funcs.output(logger)
  logger.write_string("\n  tables : ")
  self.tables.output(logger)
  logger.write_string("\n  mems : ")
  self.mems.output(logger)
  logger.write_string("\n  globals : ")
  self.globals.output(logger)
  logger.write_string("\n  elems : ")
  self.elems.output(logger)
  logger.write_string("\n  datas : ")
  self.datas.output(logger)
  logger.write_string("\n  tags : ")
  self.tags.output(logger)
  logger.write_string("\n  locals : ")
  self.locals.output(logger)
  logger.write_string("\n  labels : ")
  self.labels.output(logger)
  logger.write_string("\n  return_type : ")
  self.return_type.output(logger)
  logger.write_string("\n}")
}

///|
pub fn i32_valtype() -> ValType {
  NumTypeValType(I32NumType)
}

///|
pub fn i64_valtype() -> ValType {
  NumTypeValType(I64NumType)
}

///|
pub fn ref_valtype(rt : RefType) -> ValType {
  RefTypeValType(rt)
}

///|
pub fn ref_null_exn_valtype() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExnAbsHeapType)))
}

///|
pub fn funcref_valtype() -> ValType {
  // In core Wasm, call_indirect uses funcref.
  // Your encoding: AbsHeapTypeRefType(_) is nullable; funcref is (ref null func).
  RefTypeValType(AbsHeapTypeRefType(FuncAbsHeapType))
}

///|
pub fn[T : Eq] equals(a : Array[T], b : Array[T]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
pub fn Limits::addr_valtype(at : Limits) -> ValType {
  match at {
    I32Limits(_) => NumTypeValType(I32NumType)
    I64Limits(_) => NumTypeValType(I64NumType)
  }
}

///|
pub fn min_addr(a : Limits, b : Limits) -> Limits {
  match (a, b) {
    (I32Limits(_), _) => a
    (_, I32Limits(_)) => b
    _ => a
  }
}

///|
pub fn elem_reftype(e : Elem) -> RefType {
  match e {
    Elem(_, kind) =>
      match kind {
        FuncsElemKind(_) => AbsHeapTypeRefType(FuncAbsHeapType) // funcref
        FuncExprsElemKind(_) => AbsHeapTypeRefType(FuncAbsHeapType) // funcref
        TypedExprsElemKind(rt, _) => rt
      }
  }
}

///|
pub fn ref_null_valtype(ht : HeapType) -> ValType {
  RefTypeValType(HeapTypeRefType(true, ht))
}

///|
pub fn eqref_null_valtype() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)))
}

///|
pub fn unpack_storage(st : StorageType) -> ValType {
  match st {
    ValTypeStorageType(vt) => vt
    PackTypeStorageType(_) => NumTypeValType(I32NumType)
  }
}

///|
pub fn is_packed(st : StorageType) -> Bool {
  match st {
    PackTypeStorageType(_) => true
    _ => false
  }
}

///|
pub fn u32_to_int(u : U32) -> Int {
  let U32(i) = u
  i.reinterpret_as_int()
}

///|
pub fn has_default(vt : ValType) -> Bool {
  match vt {
    NumTypeValType(_) => true
    VecTypeValType => true
    RefTypeValType(rt) => rt.is_nullable() // default is ref.null
    BotValType => true
  }
}

///|
pub fn get_struct_field(
  fields : Array[FieldType],
  i : U32,
) -> Result[FieldType, String] {
  let idx = u32_to_int(i)
  match fields.get(idx) {
    None => Err("struct field index out of range")
    Some(ft) => Ok(ft)
  }
}

///|
pub fn field_is_mutable(ft : FieldType) -> Bool {
  match ft {
    FieldType(_, Var) => true
    _ => false
  }
}

///|
pub fn vt_i32() -> ValType {
  NumTypeValType(I32NumType)
}

///|
pub fn vt_i64() -> ValType {
  NumTypeValType(I64NumType)
}

///|
pub fn vt_f32() -> ValType {
  NumTypeValType(F32NumType)
}

///|
pub fn vt_f64() -> ValType {
  NumTypeValType(F64NumType)
}

///|
pub fn vt_v128() -> ValType {
  VecTypeValType
}

///|
pub fn min_addr_valtype(l1 : Limits, l2 : Limits) -> ValType {
  match (l1, l2) {
    (I64Limits(_, _), I64Limits(_, _)) => NumTypeValType(I64NumType)
    _ => NumTypeValType(I32NumType)
  }
}

///|
pub fn anyref_valtype() -> ValType {
  // (ref null any)
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)))
}

///|
pub fn externref_valtype() -> ValType {
  // (ref null extern)
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType)))
}

///|
pub fn i31ref_valtype() -> ValType {
  // (ref i31) (non-null)
  RefTypeValType(HeapTypeRefType(false, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
pub fn i31ref_nullable_valtype() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
pub fn ref_array_nonnull(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(false, HeapType(x)))
}

///|
pub fn ref_array_nullable(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(true, HeapType(x)))
}

///|
pub fn ref_null_array_of(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(true, HeapType(x)))
}

///|
/// A tree-based expression where operands are explicit children rather than implicit stack values.
/// Each TInstr node contains its consumed operands as children.
pub(all) struct TExpr(Array[TInstr]) derive(Eq, Show, Hash)

///|
/// A tree-based instruction with explicit operands
pub(all) enum TInstr {
  // === Constants (0 children, 1 result) ===
  TI32Const(I32)
  TI64Const(I64)
  TF32Const(F32)
  TF64Const(F64)
  TRefNull(HeapType)
  TRefFunc(FuncIdx)
  TV128Const(
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte,
    Byte
  )

  // === Nullary (0 children) ===
  TUnreachable
  TNop
  TLocalGet(LocalIdx)
  TGlobalGet(GlobalIdx)
  TMemorySize(MemIdx)
  TTableSize(TableIdx)

  // === Unary (1 child) ===
  TUnary(UnaryOp, TInstr)
  TDrop(TInstr)
  TLocalSet(LocalIdx, TInstr)
  TLocalTee(LocalIdx, TInstr)
  TGlobalSet(GlobalIdx, TInstr)
  TRefIsNull(TInstr)
  TRefAsNonNull(TInstr)
  TI31GetS(TInstr)
  TI31GetU(TInstr)
  TRefI31(TInstr)
  TArrayLen(TInstr)
  TAnyConvertExtern(TInstr)
  TExternConvertAny(TInstr)
  TThrowRef(TInstr)

  // === Binary (2 children) ===
  TBinary(BinaryOp, TInstr, TInstr)
  TRefEq(TInstr, TInstr)
  TStore(StoreOp, MemArg, TInstr, TInstr) // addr, value

  // === Load (1 child - address) ===
  TLoad(LoadOp, MemArg, TInstr)

  // === Memory operations ===
  TMemoryGrow(MemIdx, TInstr)
  TMemoryFill(MemIdx, TInstr, TInstr, TInstr) // dest, val, len
  TMemoryCopy(MemIdx, MemIdx, TInstr, TInstr, TInstr) // dest, src, len
  TMemoryInit(DataIdx, MemIdx, TInstr, TInstr, TInstr)
  TDataDrop(DataIdx)

  // === Table operations ===
  TTableGet(TableIdx, TInstr)
  TTableSet(TableIdx, TInstr, TInstr)
  TTableGrow(TableIdx, TInstr, TInstr)
  TTableFill(TableIdx, TInstr, TInstr, TInstr)
  TTableCopy(TableIdx, TableIdx, TInstr, TInstr, TInstr)
  TTableInit(ElemIdx, TableIdx, TInstr, TInstr, TInstr)
  TElemDrop(ElemIdx)

  // === Calls (N children based on function type) ===
  TCall(FuncIdx, Array[TInstr])
  TCallIndirect(TypeIdx, TableIdx, Array[TInstr], TInstr) // args, table index
  TCallRef(TypeIdx, Array[TInstr], TInstr) // args, funcref
  TReturnCall(FuncIdx, Array[TInstr])
  TReturnCallIndirect(TypeIdx, TableIdx, Array[TInstr], TInstr)
  TReturnCallRef(TypeIdx, Array[TInstr], TInstr)

  // === Control flow ===
  TBlock(BlockType, TExpr)
  TLoop(BlockType, TExpr)
  TIf(BlockType, TInstr, TExpr, TExpr?) // condition, then, else
  TTryTable(BlockType, Array[Catch], TExpr)
  TThrow(TagIdx, Array[TInstr])

  // === Branches ===
  TBr(LabelIdx, Array[TInstr]) // values to pass
  TBrIf(LabelIdx, TInstr, Array[TInstr]) // condition, values
  TBrTable(Array[LabelIdx], LabelIdx, TInstr, Array[TInstr]) // index, values
  TBrOnNull(LabelIdx, TInstr, Array[TInstr])
  TBrOnNonNull(LabelIdx, TInstr, Array[TInstr])
  TBrOnCast(LabelIdx, CastOp, HeapType, HeapType, TInstr, Array[TInstr])
  TBrOnCastFail(LabelIdx, CastOp, HeapType, HeapType, TInstr, Array[TInstr])
  TReturn(Array[TInstr])

  // === Select ===
  TSelect(Array[ValType]?, TInstr, TInstr, TInstr) // cond, if_true, if_false

  // === GC: Structs ===
  TStructNew(TypeIdx, Array[TInstr])
  TStructNewDefault(TypeIdx)
  TStructGet(TypeIdx, U32, TInstr)
  TStructGetS(TypeIdx, U32, TInstr)
  TStructGetU(TypeIdx, U32, TInstr)
  TStructSet(TypeIdx, U32, TInstr, TInstr) // struct, value

  // === GC: Arrays ===
  TArrayNew(TypeIdx, TInstr, TInstr) // init, len
  TArrayNewDefault(TypeIdx, TInstr) // len
  TArrayNewFixed(TypeIdx, Array[TInstr])
  TArrayNewData(TypeIdx, DataIdx, TInstr, TInstr) // offset, len
  TArrayNewElem(TypeIdx, ElemIdx, TInstr, TInstr)
  TArrayGet(TypeIdx, TInstr, TInstr) // arr, idx
  TArrayGetS(TypeIdx, TInstr, TInstr)
  TArrayGetU(TypeIdx, TInstr, TInstr)
  TArraySet(TypeIdx, TInstr, TInstr, TInstr) // arr, idx, val
  TArrayFill(TypeIdx, TInstr, TInstr, TInstr, TInstr) // arr, offset, val, len
  TArrayCopy(TypeIdx, TypeIdx, TInstr, TInstr, TInstr, TInstr, TInstr)
  TArrayInitData(TypeIdx, DataIdx, TInstr, TInstr, TInstr, TInstr)
  TArrayInitElem(TypeIdx, ElemIdx, TInstr, TInstr, TInstr, TInstr)

  // === GC: Casts ===
  TRefTest(Bool, HeapType, TInstr)
  TRefCast(Bool, HeapType, TInstr)

  // === SIMD: Splat (scalar -> v128) ===
  TI8x16Splat(TInstr)
  TI16x8Splat(TInstr)
  TI32x4Splat(TInstr)
  TI64x2Splat(TInstr)
  TF32x4Splat(TInstr)
  TF64x2Splat(TInstr)

  // === SIMD: Extract lane (v128 -> scalar) ===
  TExtractLane(ExtractLaneOp, LaneIdx, TInstr)

  // === SIMD: Replace lane (v128, scalar -> v128) ===
  TReplaceLane(ReplaceLaneOp, LaneIdx, TInstr, TInstr)

  // === SIMD: Shuffle (v128, v128 -> v128 with 16 lane indices) ===
  TI8x16Shuffle(
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    LaneIdx,
    TInstr,
    TInstr
  )

  // === SIMD: Swizzle (v128, v128 -> v128) ===
  TI8x16Swizzle(TInstr, TInstr)
  TI8x16RelaxedSwizzle(TInstr, TInstr)

  // === SIMD: Shift (v128, i32 -> v128) ===
  TV128Shift(V128ShiftOp, TInstr, TInstr)

  // === SIMD: Ternary (v128, v128, v128 -> v128) ===
  TV128Ternary(V128TernaryOp, TInstr, TInstr, TInstr)

  // === SIMD: Lane load (v128, addr -> v128) ===
  TV128LoadLane(V128LoadLaneOp, MemArg, LaneIdx, TInstr, TInstr)

  // === SIMD: Lane store (v128, addr -> void) ===
  TV128StoreLane(V128StoreLaneOp, MemArg, LaneIdx, TInstr, TInstr)
} derive(Eq, Show, Hash)

///|
/// Unary operations
pub(all) enum UnaryOp {
  // === Scalar ===
  I32EqzOp
  I64EqzOp
  I32ClzOp
  I32CtzOp
  I32PopcntOp
  I64ClzOp
  I64CtzOp
  I64PopcntOp
  F32AbsOp
  F32NegOp
  F32CeilOp
  F32FloorOp
  F32TruncOp
  F32NearestOp
  F32SqrtOp
  F64AbsOp
  F64NegOp
  F64CeilOp
  F64FloorOp
  F64TruncOp
  F64NearestOp
  F64SqrtOp
  I32WrapI64Op
  I32TruncF32SOp
  I32TruncF32UOp
  I32TruncF64SOp
  I32TruncF64UOp
  I64ExtendI32SOp
  I64ExtendI32UOp
  I64TruncF32SOp
  I64TruncF32UOp
  I64TruncF64SOp
  I64TruncF64UOp
  F32ConvertI32SOp
  F32ConvertI32UOp
  F32ConvertI64SOp
  F32ConvertI64UOp
  F32DemoteF64Op
  F64ConvertI32SOp
  F64ConvertI32UOp
  F64ConvertI64SOp
  F64ConvertI64UOp
  F64PromoteF32Op
  I32ReinterpretF32Op
  I64ReinterpretF64Op
  F32ReinterpretI32Op
  F64ReinterpretI64Op
  I32Extend8SOp
  I32Extend16SOp
  I64Extend8SOp
  I64Extend16SOp
  I64Extend32SOp
  I32TruncSatF32SOp
  I32TruncSatF32UOp
  I32TruncSatF64SOp
  I32TruncSatF64UOp
  I64TruncSatF32SOp
  I64TruncSatF32UOp
  I64TruncSatF64SOp
  I64TruncSatF64UOp

  // === SIMD: v128 -> v128 ===
  V128NotOp
  I8x16AbsOp
  I8x16NegOp
  I8x16PopcntOp
  I16x8AbsOp
  I16x8NegOp
  I32x4AbsOp
  I32x4NegOp
  I64x2AbsOp
  I64x2NegOp
  F32x4AbsOp
  F32x4NegOp
  F32x4SqrtOp
  F32x4CeilOp
  F32x4FloorOp
  F32x4TruncOp
  F32x4NearestOp
  F64x2AbsOp
  F64x2NegOp
  F64x2SqrtOp
  F64x2CeilOp
  F64x2FloorOp
  F64x2TruncOp
  F64x2NearestOp

  // === SIMD: v128 -> i32 (bitmask/alltrue) ===
  V128AnyTrueOp
  I8x16AllTrueOp
  I8x16BitmaskOp
  I16x8AllTrueOp
  I16x8BitmaskOp
  I32x4AllTrueOp
  I32x4BitmaskOp
  I64x2AllTrueOp
  I64x2BitmaskOp

  // === SIMD: Extend/narrow (v128 -> v128) ===
  I16x8ExtendLowI8x16SOp
  I16x8ExtendHighI8x16SOp
  I16x8ExtendLowI8x16UOp
  I16x8ExtendHighI8x16UOp
  I32x4ExtendLowI16x8SOp
  I32x4ExtendHighI16x8SOp
  I32x4ExtendLowI16x8UOp
  I32x4ExtendHighI16x8UOp
  I64x2ExtendLowI32x4SOp
  I64x2ExtendHighI32x4SOp
  I64x2ExtendLowI32x4UOp
  I64x2ExtendHighI32x4UOp

  // === SIMD: Pairwise add (v128 -> v128) ===
  I16x8ExtaddPairwiseI8x16SOp
  I16x8ExtaddPairwiseI8x16UOp
  I32x4ExtaddPairwiseI16x8SOp
  I32x4ExtaddPairwiseI16x8UOp

  // === SIMD: Conversion (v128 -> v128) ===
  F32x4DemoteF64x2ZeroOp
  F64x2PromoteLowF32x4Op
  I32x4TruncSatF32x4SOp
  I32x4TruncSatF32x4UOp
  F32x4ConvertI32x4SOp
  F32x4ConvertI32x4UOp
  I32x4TruncSatF64x2SZeroOp
  I32x4TruncSatF64x2UZeroOp
  F64x2ConvertLowI32x4SOp
  F64x2ConvertLowI32x4UOp

  // === SIMD: Relaxed truncation (v128 -> v128) ===
  I32x4RelaxedTruncF32x4SOp
  I32x4RelaxedTruncF32x4UOp
  I32x4RelaxedTruncZeroF64x2SOp
  I32x4RelaxedTruncZeroF64x2UOp
} derive(Eq, Show, Hash)

///|
/// Binary operations
pub(all) enum BinaryOp {
  // === Scalar ===
  I32EqOp
  I32NeOp
  I32LtSOp
  I32LtUOp
  I32GtSOp
  I32GtUOp
  I32LeSOp
  I32LeUOp
  I32GeSOp
  I32GeUOp
  I64EqOp
  I64NeOp
  I64LtSOp
  I64LtUOp
  I64GtSOp
  I64GtUOp
  I64LeSOp
  I64LeUOp
  I64GeSOp
  I64GeUOp
  F32EqOp
  F32NeOp
  F32LtOp
  F32GtOp
  F32LeOp
  F32GeOp
  F64EqOp
  F64NeOp
  F64LtOp
  F64GtOp
  F64LeOp
  F64GeOp
  I32AddOp
  I32SubOp
  I32MulOp
  I32DivSOp
  I32DivUOp
  I32RemSOp
  I32RemUOp
  I32AndOp
  I32OrOp
  I32XorOp
  I32ShlOp
  I32ShrSOp
  I32ShrUOp
  I32RotlOp
  I32RotrOp
  I64AddOp
  I64SubOp
  I64MulOp
  I64DivSOp
  I64DivUOp
  I64RemSOp
  I64RemUOp
  I64AndOp
  I64OrOp
  I64XorOp
  I64ShlOp
  I64ShrSOp
  I64ShrUOp
  I64RotlOp
  I64RotrOp
  F32AddOp
  F32SubOp
  F32MulOp
  F32DivOp
  F32MinOp
  F32MaxOp
  F32CopysignOp
  F64AddOp
  F64SubOp
  F64MulOp
  F64DivOp
  F64MinOp
  F64MaxOp
  F64CopysignOp

  // === SIMD: Bitwise (v128, v128 -> v128) ===
  V128AndOp
  V128AndnotOp
  V128OrOp
  V128XorOp

  // === SIMD: i8x16 comparisons ===
  I8x16EqOp
  I8x16NeOp
  I8x16LtSOp
  I8x16LtUOp
  I8x16GtSOp
  I8x16GtUOp
  I8x16LeSOp
  I8x16LeUOp
  I8x16GeSOp
  I8x16GeUOp

  // === SIMD: i16x8 comparisons ===
  I16x8EqOp
  I16x8NeOp
  I16x8LtSOp
  I16x8LtUOp
  I16x8GtSOp
  I16x8GtUOp
  I16x8LeSOp
  I16x8LeUOp
  I16x8GeSOp
  I16x8GeUOp

  // === SIMD: i32x4 comparisons ===
  I32x4EqOp
  I32x4NeOp
  I32x4LtSOp
  I32x4LtUOp
  I32x4GtSOp
  I32x4GtUOp
  I32x4LeSOp
  I32x4LeUOp
  I32x4GeSOp
  I32x4GeUOp

  // === SIMD: i64x2 comparisons ===
  I64x2EqOp
  I64x2NeOp
  I64x2LtSOp
  I64x2GtSOp
  I64x2LeSOp
  I64x2GeSOp

  // === SIMD: f32x4 comparisons ===
  F32x4EqOp
  F32x4NeOp
  F32x4LtOp
  F32x4GtOp
  F32x4LeOp
  F32x4GeOp

  // === SIMD: f64x2 comparisons ===
  F64x2EqOp
  F64x2NeOp
  F64x2LtOp
  F64x2GtOp
  F64x2LeOp
  F64x2GeOp

  // === SIMD: i8x16 arithmetic ===
  I8x16AddOp
  I8x16AddSatSOp
  I8x16AddSatUOp
  I8x16SubOp
  I8x16SubSatSOp
  I8x16SubSatUOp
  I8x16MinSOp
  I8x16MinUOp
  I8x16MaxSOp
  I8x16MaxUOp
  I8x16AvgrUOp
  I8x16NarrowI16x8SOp
  I8x16NarrowI16x8UOp

  // === SIMD: i16x8 arithmetic ===
  I16x8AddOp
  I16x8AddSatSOp
  I16x8AddSatUOp
  I16x8SubOp
  I16x8SubSatSOp
  I16x8SubSatUOp
  I16x8MulOp
  I16x8MinSOp
  I16x8MinUOp
  I16x8MaxSOp
  I16x8MaxUOp
  I16x8AvgrUOp
  I16x8Q15mulrSatSOp
  I16x8NarrowI32x4SOp
  I16x8NarrowI32x4UOp
  I16x8ExtmulLowI8x16SOp
  I16x8ExtmulHighI8x16SOp
  I16x8ExtmulLowI8x16UOp
  I16x8ExtmulHighI8x16UOp

  // === SIMD: i32x4 arithmetic ===
  I32x4AddOp
  I32x4SubOp
  I32x4MulOp
  I32x4MinSOp
  I32x4MinUOp
  I32x4MaxSOp
  I32x4MaxUOp
  I32x4DotI16x8SOp
  I32x4ExtmulLowI16x8SOp
  I32x4ExtmulHighI16x8SOp
  I32x4ExtmulLowI16x8UOp
  I32x4ExtmulHighI16x8UOp

  // === SIMD: i64x2 arithmetic ===
  I64x2AddOp
  I64x2SubOp
  I64x2MulOp
  I64x2ExtmulLowI32x4SOp
  I64x2ExtmulHighI32x4SOp
  I64x2ExtmulLowI32x4UOp
  I64x2ExtmulHighI32x4UOp

  // === SIMD: f32x4 arithmetic ===
  F32x4AddOp
  F32x4SubOp
  F32x4MulOp
  F32x4DivOp
  F32x4MinOp
  F32x4MaxOp
  F32x4PminOp
  F32x4PmaxOp

  // === SIMD: f64x2 arithmetic ===
  F64x2AddOp
  F64x2SubOp
  F64x2MulOp
  F64x2DivOp
  F64x2MinOp
  F64x2MaxOp
  F64x2PminOp
  F64x2PmaxOp

  // === SIMD: Relaxed ===
  F32x4RelaxedMinOp
  F32x4RelaxedMaxOp
  F64x2RelaxedMinOp
  F64x2RelaxedMaxOp
  I16x8RelaxedQ15mulrSOp
  I16x8RelaxedDotI8x16I7x16SOp
} derive(Eq, Show, Hash)

///|
pub(all) enum LoadOp {
  // === Scalar ===
  I32LoadOp
  I64LoadOp
  F32LoadOp
  F64LoadOp
  I32Load8SOp
  I32Load8UOp
  I32Load16SOp
  I32Load16UOp
  I64Load8SOp
  I64Load8UOp
  I64Load16SOp
  I64Load16UOp
  I64Load32SOp
  I64Load32UOp

  // === SIMD ===
  V128LoadOp
  V128Load8x8SOp
  V128Load8x8UOp
  V128Load16x4SOp
  V128Load16x4UOp
  V128Load32x2SOp
  V128Load32x2UOp
  V128Load8SplatOp
  V128Load16SplatOp
  V128Load32SplatOp
  V128Load64SplatOp
  V128Load32ZeroOp
  V128Load64ZeroOp
} derive(Eq, Show, Hash)

///|
/// Store operations
pub(all) enum StoreOp {
  // === Scalar ===
  I32StoreOp
  I64StoreOp
  F32StoreOp
  F64StoreOp
  I32Store8Op
  I32Store16Op
  I64Store8Op
  I64Store16Op
  I64Store32Op

  // === SIMD ===
  V128StoreOp
} derive(Eq, Show, Hash)

///|
/// Extract lane operations (v128 -> scalar)
pub(all) enum ExtractLaneOp {
  I8x16ExtractLaneSOp
  I8x16ExtractLaneUOp
  I16x8ExtractLaneSOp
  I16x8ExtractLaneUOp
  I32x4ExtractLaneOp
  I64x2ExtractLaneOp
  F32x4ExtractLaneOp
  F64x2ExtractLaneOp
} derive(Eq, Show, Hash)

///|
/// Replace lane operations (v128, scalar -> v128)
pub(all) enum ReplaceLaneOp {
  I8x16ReplaceLaneOp
  I16x8ReplaceLaneOp
  I32x4ReplaceLaneOp
  I64x2ReplaceLaneOp
  F32x4ReplaceLaneOp
  F64x2ReplaceLaneOp
} derive(Eq, Show, Hash)

///|
/// V128 shift operations (v128, i32 -> v128)
pub(all) enum V128ShiftOp {
  I8x16ShlOp
  I8x16ShrSOp
  I8x16ShrUOp
  I16x8ShlOp
  I16x8ShrSOp
  I16x8ShrUOp
  I32x4ShlOp
  I32x4ShrSOp
  I32x4ShrUOp
  I64x2ShlOp
  I64x2ShrSOp
  I64x2ShrUOp
} derive(Eq, Show, Hash)

///|
/// V128 ternary operations (v128, v128, v128 -> v128)
pub(all) enum V128TernaryOp {
  V128BitselectOp
  I8x16RelaxedLaneselectOp
  I16x8RelaxedLaneselectOp
  I32x4RelaxedLaneselectOp
  I64x2RelaxedLaneselectOp
  F32x4RelaxedMaddOp
  F32x4RelaxedNmaddOp
  F64x2RelaxedMaddOp
  F64x2RelaxedNmaddOp
  I32x4RelaxedDotI8x16I7x16AddSOp
} derive(Eq, Show, Hash)

///|
/// V128 lane load operations
pub(all) enum V128LoadLaneOp {
  V128Load8LaneOp
  V128Load16LaneOp
  V128Load32LaneOp
  V128Load64LaneOp
} derive(Eq, Show, Hash)

///|
/// V128 lane store operations
pub(all) enum V128StoreLaneOp {
  V128Store8LaneOp
  V128Store16LaneOp
  V128Store32LaneOp
  V128Store64LaneOp
} derive(Eq, Show, Hash)

///|
pub fn f32_num_type() -> NumType {
  F32NumType
}

///|
pub fn f64_num_type() -> NumType {
  F64NumType
}

///|
pub fn i32_num_type() -> NumType {
  I32NumType
}

///|
pub fn i64_num_type() -> NumType {
  I64NumType
}

///|
pub fn exn_abs_heap_type() -> AbsHeapType {
  ExnAbsHeapType
}

///|
pub fn array_abs_heap_type() -> AbsHeapType {
  ArrayAbsHeapType
}

///|
pub fn struct_abs_heap_type() -> AbsHeapType {
  StructAbsHeapType
}

///|
pub fn i31_abs_heap_type() -> AbsHeapType {
  I31AbsHeapType
}

///|
pub fn eq_abs_heap_type() -> AbsHeapType {
  EqAbsHeapType
}

///|
pub fn any_abs_heap_type() -> AbsHeapType {
  AnyAbsHeapType
}

///|
pub fn extern_abs_heap_type() -> AbsHeapType {
  ExternAbsHeapType
}

///|
pub fn func_abs_heap_type() -> AbsHeapType {
  FuncAbsHeapType
}

///|
pub fn none_abs_heap_type() -> AbsHeapType {
  NoneAbsHeapType
}

///|
pub fn no_extern_abs_heap_type() -> AbsHeapType {
  NoExternAbsHeapType
}

///|
pub fn no_func_abs_heap_type() -> AbsHeapType {
  NoFuncAbsHeapType
}

///|
pub fn no_exn_abs_heap_type() -> AbsHeapType {
  NoExnAbsHeapType
}

///|
pub fn abs_heap_type_heap_type(abs : AbsHeapType) -> HeapType {
  AbsHeapTypeHeapType(abs)
}

///|
pub fn type_idx(idx : UInt) -> TypeIdx {
  TypeIdx(idx)
}

///|
pub fn heap_type(ty_idx : TypeIdx) -> HeapType {
  HeapType(ty_idx)
}

///|
pub fn def_type_heap_type(dt : DefType) -> HeapType {
  DefTypeHeapType(dt)
}

///|
pub fn heap_type_ref_type(nullable : Bool, ht : HeapType) -> RefType {
  HeapTypeRefType(nullable, ht)
}

///|
pub fn abs_heap_type_ref_type(abs : AbsHeapType) -> RefType {
  AbsHeapTypeRefType(abs)
}

///|
pub fn num_type_val_type(nt : NumType) -> ValType {
  NumTypeValType(nt)
}

///|
pub fn vec_type_val_type() -> ValType {
  VecTypeValType
}

///|
pub fn ref_type_val_type(rt : RefType) -> ValType {
  RefTypeValType(rt)
}

///|
pub fn bot_val_type() -> ValType {
  BotValType
}

///|
pub fn i16_pack_type() -> PackType {
  I16PackType
}

///|
pub fn i8_pack_type() -> PackType {
  I8PackType
}

///|
pub fn val_type_storage_type(vt : ValType) -> StorageType {
  ValTypeStorageType(vt)
}

///|
pub fn pack_type_storage_type(pt : PackType) -> StorageType {
  PackTypeStorageType(pt)
}

///|
pub fn mut_const() -> Mut {
  Const
}

///|
pub fn mut_var() -> Mut {
  Var
}

///|
pub fn catch_(ti : TagIdx, li : LabelIdx) -> Catch {
  Catch(ti, li)
}

///|
pub fn catch_ref(ti : TagIdx, li : LabelIdx) -> Catch {
  CatchRef(ti, li)
}

///|
pub fn catch_all(li : LabelIdx) -> Catch {
  CatchAll(li)
}

///|
pub fn catch_all_ref(li : LabelIdx) -> Catch {
  CatchAllRef(li)
}

///|
pub fn rec_idx(idx : UInt) -> TypeIdx {
  RecIdx(idx)
}

///|
pub fn array_comp_type(ft : FieldType) -> CompType {
  ArrayCompType(ft)
}

///|
pub fn struct_comp_type(fs : Array[FieldType]) -> CompType {
  StructCompType(fs)
}

///|
pub fn func_comp_type(props : ResultType, results : ResultType) -> CompType {
  FuncCompType(props, results)
}

///|
pub fn sub_type(f : Bool, supers : Array[TypeIdx], ct : CompType) -> SubType {
  SubType(f, supers, ct)
}

///|
pub fn comp_type_sub_type(ct : CompType) -> SubType {
  CompTypeSubType(ct)
}

///|
pub fn single_rec_type(st : SubType) -> RecType {
  SingleRecType(st)
}

///|
pub fn group_rec_type(sts : Array[SubType]) -> RecType {
  GroupRecType(sts)
}

///|
pub fn i32_limits(min : UInt, max : UInt?) -> Limits {
  I32Limits(min, max)
}

///|
pub fn i64_limits(min : UInt64, max : UInt64?) -> Limits {
  I64Limits(min, max)
}

///|
pub fn func_extern_type(idx : TypeIdx) -> ExternType {
  FuncExternType(idx)
}

///|
pub fn table_type(rt : RefType, limits : Limits) -> TableType {
  TableType(rt, limits)
}

///|
pub fn table_extern_type(tt : TableType) -> ExternType {
  TableExternType(tt)
}

///|
pub fn mem_type(l : Limits) -> MemType {
  MemType(l)
}

///|
pub fn mem_extern_type(mt : MemType) -> ExternType {
  MemExternType(mt)
}

///|
pub fn global_type(vt : ValType, nullable : Bool) -> GlobalType {
  GlobalType(vt, nullable)
}

///|
pub fn global_extern_type(gt : GlobalType) -> ExternType {
  GlobalExternType(gt)
}

///|
pub fn tag_type(idx : TypeIdx) -> TagType {
  TagType(idx)
}

///|
pub fn tag_extern_type(tt : TagType) -> ExternType {
  TagExternType(tt)
}

///|
pub fn func_idx(idx : UInt) -> FuncIdx {
  FuncIdx(idx)
}

///|
pub fn func_extern_idx(fi : FuncIdx) -> ExternIdx {
  FuncExternIdx(fi)
}

///|
pub fn table_idx(idx : UInt) -> TableIdx {
  TableIdx(idx)
}

///|
pub fn table_extern_idx(ti : TableIdx) -> ExternIdx {
  TableExternIdx(ti)
}

///|
pub fn mem_extern_idx(mi : MemIdx) -> ExternIdx {
  MemExternIdx(mi)
}

///|
pub fn global_idx(idx : UInt) -> GlobalIdx {
  GlobalIdx(idx)
}

///|
pub fn global_extern_idx(gi : GlobalIdx) -> ExternIdx {
  GlobalExternIdx(gi)
}

///|
pub fn tag_extern_idx(ti : TagIdx) -> ExternIdx {
  TagExternIdx(ti)
}

///|
pub fn elem_passive() -> ElemMode {
  Passive
}

///|
pub fn elem_active(ti : TableIdx, val : Expr) -> ElemMode {
  Active(ti, val)
}

///|
pub fn declarative() -> ElemMode {
  Declarative
}

///|
pub fn funcs_elem_kind(fs : Array[FuncIdx]) -> ElemKind {
  FuncsElemKind(fs)
}

///|
pub fn func_exprs_elem_kind(fs : Array[Expr]) -> ElemKind {
  FuncExprsElemKind(fs)
}

///|
pub fn typed_exprs_elem_kind(rt : RefType, els : Array[Expr]) -> ElemKind {
  TypedExprsElemKind(rt, els)
}

///|
pub fn active(mi : MemIdx, expr : Expr) -> DataMode {
  Active(mi, expr)
}

///|
pub fn passive() -> DataMode {
  Passive
}

///|
pub fn label_idx(idx : UInt) -> LabelIdx {
  LabelIdx(idx)
}

///|
pub fn unreachable_inst() -> Instruction {
  Unreachable
}

///|
pub fn nop_inst() -> Instruction {
  Nop
}

///|
pub fn block_inst(bt : BlockType, val : Expr) -> Instruction {
  Block(bt, val)
}

///|
pub fn loop_inst(bt : BlockType, val : Expr) -> Instruction {
  Loop(bt, val)
}

///|
pub fn if_inst(
  bt : BlockType,
  if_block : Array[Instruction],
  else_block : Array[Instruction]?,
) -> Instruction {
  If(bt, if_block, else_block)
}

///|
pub fn throw_inst(ti : TagIdx) -> Instruction {
  Throw(ti)
}

///|
pub fn throw_ref_inst() -> Instruction {
  ThrowRef
}

///|
pub fn br_inst(li : LabelIdx) -> Instruction {
  Br(li)
}

///|
pub fn br_if_inst(li : LabelIdx) -> Instruction {
  BrIf(li)
}

///|
pub fn br_table_inst(ls : Array[LabelIdx], li0 : LabelIdx) -> Instruction {
  BrTable(ls, li0)
}

///|
pub fn return_inst() -> Instruction {
  Return
}

///|
pub fn call_inst(fi : FuncIdx) -> Instruction {
  Call(fi)
}

///|
pub fn call_indirect_inst(ty_idx : TypeIdx, tbl_idx : TableIdx) -> Instruction {
  CallIndirect(ty_idx, tbl_idx)
}

///|
pub fn return_call_inst(fi : FuncIdx) -> Instruction {
  ReturnCall(fi)
}

///|
pub fn return_call_indirect_inst(
  ty_idx : TypeIdx,
  tbl_idx : TableIdx,
) -> Instruction {
  ReturnCallIndirect(ty_idx, tbl_idx)
}

///|
pub fn call_ref_inst(ti : TypeIdx) -> Instruction {
  CallRef(ti)
}

///|
pub fn return_call_ref_inst(ti : TypeIdx) -> Instruction {
  ReturnCallRef(ti)
}

///|
pub fn drop_inst() -> Instruction {
  Drop
}

///|
pub fn select_inst(types? : Array[ValType]? = None) -> Instruction {
  Select(types)
}

///|
pub fn try_table_inst(
  bt : BlockType,
  catches : Array[Catch],
  val : Expr,
) -> Instruction {
  TryTable(bt, catches, val)
}

///|
pub fn local_get_inst(li : LocalIdx) -> Instruction {
  LocalGet(li)
}

///|
pub fn local_set_inst(li : LocalIdx) -> Instruction {
  LocalSet(li)
}

///|
pub fn local_tee_inst(li : LocalIdx) -> Instruction {
  LocalTee(li)
}

///|
pub fn global_get_inst(gi : GlobalIdx) -> Instruction {
  GlobalGet(gi)
}

///|
pub fn global_set_inst(gi : GlobalIdx) -> Instruction {
  GlobalSet(gi)
}

///|
pub fn table_get_inst(ti : TableIdx) -> Instruction {
  TableGet(ti)
}

///|
pub fn table_set_inst(ti : TableIdx) -> Instruction {
  TableSet(ti)
}

///|
pub fn i32_load_inst(ma : MemArg) -> Instruction {
  I32Load(ma)
}

///|
pub fn i64_load_inst(ma : MemArg) -> Instruction {
  I64Load(ma)
}

///|
pub fn f32_load_inst(ma : MemArg) -> Instruction {
  F32Load(ma)
}

///|
pub fn f64_load_inst(ma : MemArg) -> Instruction {
  F64Load(ma)
}

///|
pub fn i32_load8s_inst(ma : MemArg) -> Instruction {
  I32Load8S(ma)
}

///|
pub fn i32_load8u_inst(ma : MemArg) -> Instruction {
  I32Load8U(ma)
}

///|
pub fn i32_load16s_inst(ma : MemArg) -> Instruction {
  I32Load16S(ma)
}

///|
pub fn i32_load16u_inst(ma : MemArg) -> Instruction {
  I32Load16U(ma)
}

///|
pub fn i64_load8s_inst(ma : MemArg) -> Instruction {
  I64Load8S(ma)
}

///|
pub fn i64_load8u_inst(ma : MemArg) -> Instruction {
  I64Load8U(ma)
}

///|
pub fn i64_load16s_inst(ma : MemArg) -> Instruction {
  I64Load16S(ma)
}

///|
pub fn i64_load16u_inst(ma : MemArg) -> Instruction {
  I64Load16U(ma)
}

///|
pub fn i64_load32s_inst(ma : MemArg) -> Instruction {
  I64Load32S(ma)
}

///|
pub fn i64_load32u_inst(ma : MemArg) -> Instruction {
  I64Load32U(ma)
}

///|
pub fn i32_store_inst(ma : MemArg) -> Instruction {
  I32Store(ma)
}

///|
pub fn i64_store_inst(ma : MemArg) -> Instruction {
  I64Store(ma)
}

///|
pub fn f32_store_inst(ma : MemArg) -> Instruction {
  F32Store(ma)
}

///|
pub fn f64_store_inst(ma : MemArg) -> Instruction {
  F64Store(ma)
}

///|
pub fn i32_store8_inst(ma : MemArg) -> Instruction {
  I32Store8(ma)
}

///|
pub fn i32_store16_inst(ma : MemArg) -> Instruction {
  I32Store16(ma)
}

///|
pub fn i64_store8_inst(ma : MemArg) -> Instruction {
  I64Store8(ma)
}

///|
pub fn i64_store16_inst(ma : MemArg) -> Instruction {
  I64Store16(ma)
}

///|
pub fn i64_store32_inst(ma : MemArg) -> Instruction {
  I64Store32(ma)
}

///|
pub fn memory_size_inst(mi : MemIdx) -> Instruction {
  MemorySize(mi)
}

///|
pub fn memory_grow_inst(mi : MemIdx) -> Instruction {
  MemoryGrow(mi)
}

///|
pub fn i32_const_inst(val : I32) -> Instruction {
  I32Const(val)
}

///|
pub fn i64_const_inst(val : I64) -> Instruction {
  I64Const(val)
}

///|
pub fn f32_const_inst(val : F32) -> Instruction {
  F32Const(val)
}

///|
pub fn f64_const_inst(val : F64) -> Instruction {
  F64Const(val)
}

///|
pub fn i32_eqz_inst() -> Instruction {
  I32Eqz
}

///|
pub fn i32_eq_inst() -> Instruction {
  I32Eq
}

///|
pub fn i32_ne_inst() -> Instruction {
  I32Ne
}

///|
pub fn i32_lt_s_inst() -> Instruction {
  I32LtS
}

///|
pub fn i32_lt_u_inst() -> Instruction {
  I32LtU
}

///|
pub fn i32_gt_s_inst() -> Instruction {
  I32GtS
}

///|
pub fn i32_gt_u_inst() -> Instruction {
  I32GtU
}

///|
pub fn i32_le_s_inst() -> Instruction {
  I32LeS
}

///|
pub fn i32_le_u_inst() -> Instruction {
  I32LeU
}

///|
pub fn i32_ge_s_inst() -> Instruction {
  I32GeS
}

///|
pub fn i32_ge_u_inst() -> Instruction {
  I32GeU
}

///|
pub fn i64_eqz_inst() -> Instruction {
  I64Eqz
}

///|
pub fn i64_eq_inst() -> Instruction {
  I64Eq
}

///|
pub fn i64_ne_inst() -> Instruction {
  I64Ne
}

///|
pub fn i64_lt_s_inst() -> Instruction {
  I64LtS
}

///|
pub fn i64_lt_u_inst() -> Instruction {
  I64LtU
}

///|
pub fn i64_gt_s_inst() -> Instruction {
  I64GtS
}

///|
pub fn i64_gt_u_inst() -> Instruction {
  I64GtU
}

///|
pub fn i64_le_s_inst() -> Instruction {
  I64LeS
}

///|
pub fn i64_le_u_inst() -> Instruction {
  I64LeU
}

///|
pub fn i64_ge_s_inst() -> Instruction {
  I64GeS
}

///|
pub fn i64_ge_u_inst() -> Instruction {
  I64GeU
}

///|
pub fn f32_eq_inst() -> Instruction {
  F32Eq
}

///|
pub fn f32_ne_inst() -> Instruction {
  F32Ne
}

///|
pub fn f32_lt_inst() -> Instruction {
  F32Lt
}

///|
pub fn f32_gt_inst() -> Instruction {
  F32Gt
}

///|
pub fn f32_le_inst() -> Instruction {
  F32Le
}

///|
pub fn f32_ge_inst() -> Instruction {
  F32Ge
}

///|
pub fn f64_eq_inst() -> Instruction {
  F64Eq
}

///|
pub fn f64_ne_inst() -> Instruction {
  F64Ne
}

///|
pub fn f64_lt_inst() -> Instruction {
  F64Lt
}

///|
pub fn f64_gt_inst() -> Instruction {
  F64Gt
}

///|
pub fn f64_le_inst() -> Instruction {
  F64Le
}

///|
pub fn f64_ge_inst() -> Instruction {
  F64Ge
}

///|
pub fn i32_clz_inst() -> Instruction {
  I32Clz
}

///|
pub fn i32_ctz_inst() -> Instruction {
  I32Ctz
}

///|
pub fn i32_popcnt_inst() -> Instruction {
  I32Popcnt
}

///|
pub fn i32_add_inst() -> Instruction {
  I32Add
}

///|
pub fn i32_sub_inst() -> Instruction {
  I32Sub
}

///|
pub fn i32_mul_inst() -> Instruction {
  I32Mul
}

///|
pub fn i32_div_s_inst() -> Instruction {
  I32DivS
}

///|
pub fn i32_div_u_inst() -> Instruction {
  I32DivU
}

///|
pub fn i32_rem_s_inst() -> Instruction {
  I32RemS
}

///|
pub fn i32_rem_u_inst() -> Instruction {
  I32RemU
}

///|
pub fn i32_and_inst() -> Instruction {
  I32And
}

///|
pub fn i32_or_inst() -> Instruction {
  I32Or
}

///|
pub fn i32_xor_inst() -> Instruction {
  I32Xor
}

///|
pub fn i32_shl_inst() -> Instruction {
  I32Shl
}

///|
pub fn i32_shr_s_inst() -> Instruction {
  I32ShrS
}

///|
pub fn i32_shr_u_inst() -> Instruction {
  I32ShrU
}

///|
pub fn i32_rotl_inst() -> Instruction {
  I32Rotl
}

///|
pub fn i32_rotr_inst() -> Instruction {
  I32Rotr
}

///|
pub fn i64_clz_inst() -> Instruction {
  I64Clz
}

///|
pub fn i64_ctz_inst() -> Instruction {
  I64Ctz
}

///|
pub fn i64_popcnt_inst() -> Instruction {
  I64Popcnt
}

///|
pub fn i64_add_inst() -> Instruction {
  I64Add
}

///|
pub fn i64_sub_inst() -> Instruction {
  I64Sub
}

///|
pub fn i64_mul_inst() -> Instruction {
  I64Mul
}

///|
pub fn i64_div_s_inst() -> Instruction {
  I64DivS
}

///|
pub fn i64_div_u_inst() -> Instruction {
  I64DivU
}

///|
pub fn i64_rem_s_inst() -> Instruction {
  I64RemS
}

///|
pub fn i64_rem_u_inst() -> Instruction {
  I64RemU
}

///|
pub fn i64_and_inst() -> Instruction {
  I64And
}

///|
pub fn i64_or_inst() -> Instruction {
  I64Or
}

///|
pub fn i64_xor_inst() -> Instruction {
  I64Xor
}

///|
pub fn i64_shl_inst() -> Instruction {
  I64Shl
}

///|
pub fn i64_shr_s_inst() -> Instruction {
  I64ShrS
}

///|
pub fn i64_shr_u_inst() -> Instruction {
  I64ShrU
}

///|
pub fn i64_rotl_inst() -> Instruction {
  I64Rotl
}

///|
pub fn i64_rotr_inst() -> Instruction {
  I64Rotr
}

///|
pub fn f32_abs_inst() -> Instruction {
  F32Abs
}

///|
pub fn f32_neg_inst() -> Instruction {
  F32Neg
}

///|
pub fn f32_ceil_inst() -> Instruction {
  F32Ceil
}

///|
pub fn f32_floor_inst() -> Instruction {
  F32Floor
}

///|
pub fn f32_trunc_inst() -> Instruction {
  F32Trunc
}

///|
pub fn f32_nearest_inst() -> Instruction {
  F32Nearest
}

///|
pub fn f32_sqrt_inst() -> Instruction {
  F32Sqrt
}

///|
pub fn f32_add_inst() -> Instruction {
  F32Add
}

///|
pub fn f32_sub_inst() -> Instruction {
  F32Sub
}

///|
pub fn f32_mul_inst() -> Instruction {
  F32Mul
}

///|
pub fn f32_div_inst() -> Instruction {
  F32Div
}

///|
pub fn f32_min_inst() -> Instruction {
  F32Min
}

///|
pub fn f32_max_inst() -> Instruction {
  F32Max
}

///|
pub fn f32_copysign_inst() -> Instruction {
  F32Copysign
}

///|
pub fn f64_abs_inst() -> Instruction {
  F64Abs
}

///|
pub fn f64_neg_inst() -> Instruction {
  F64Neg
}

///|
pub fn f64_ceil_inst() -> Instruction {
  F64Ceil
}

///|
pub fn f64_floor_inst() -> Instruction {
  F64Floor
}

///|
pub fn f64_trunc_inst() -> Instruction {
  F64Trunc
}

///|
pub fn f64_nearest_inst() -> Instruction {
  F64Nearest
}

///|
pub fn f64_sqrt_inst() -> Instruction {
  F64Sqrt
}

///|
pub fn f64_add_inst() -> Instruction {
  F64Add
}

///|
pub fn f64_sub_inst() -> Instruction {
  F64Sub
}

///|
pub fn f64_mul_inst() -> Instruction {
  F64Mul
}

///|
pub fn f64_div_inst() -> Instruction {
  F64Div
}

///|
pub fn f64_min_inst() -> Instruction {
  F64Min
}

///|
pub fn f64_max_inst() -> Instruction {
  F64Max
}

///|
pub fn f64_copysign_inst() -> Instruction {
  F64Copysign
}

///|
pub fn i32_wrap_i64_inst() -> Instruction {
  I32WrapI64
}

///|
pub fn i32_trunc_f32s_inst() -> Instruction {
  I32TruncF32S
}

///|
pub fn i32_trunc_f32u_inst() -> Instruction {
  I32TruncF32U
}

///|
pub fn i32_trunc_f64s_inst() -> Instruction {
  I32TruncF64S
}

///|
pub fn i32_trunc_f64u_inst() -> Instruction {
  I32TruncF64U
}

///|
pub fn i64_extend_i32s_inst() -> Instruction {
  I64ExtendI32S
}

///|
pub fn i64_extend_i32u_inst() -> Instruction {
  I64ExtendI32U
}

///|
pub fn i64_trunc_f32s_inst() -> Instruction {
  I64TruncF32S
}

///|
pub fn i64_trunc_f32u_inst() -> Instruction {
  I64TruncF32U
}

///|
pub fn i64_trunc_f64s_inst() -> Instruction {
  I64TruncF64S
}

///|
pub fn i64_trunc_f64u_inst() -> Instruction {
  I64TruncF64U
}

///|
pub fn f32_convert_i32s_inst() -> Instruction {
  F32ConvertI32S
}

///|
pub fn f32_convert_i32u_inst() -> Instruction {
  F32ConvertI32U
}

///|
pub fn f32_convert_i64s_inst() -> Instruction {
  F32ConvertI64S
}

///|
pub fn f32_convert_i64u_inst() -> Instruction {
  F32ConvertI64U
}

///|
pub fn f32_demote_f64_inst() -> Instruction {
  F32DemoteF64
}

///|
pub fn f64_convert_i32s_inst() -> Instruction {
  F64ConvertI32S
}

///|
pub fn f64_convert_i32u_inst() -> Instruction {
  F64ConvertI32U
}

///|
pub fn f64_convert_i64s_inst() -> Instruction {
  F64ConvertI64S
}

///|
pub fn f64_convert_i64u_inst() -> Instruction {
  F64ConvertI64U
}

///|
pub fn f64_promote_f32_inst() -> Instruction {
  F64PromoteF32
}

///|
pub fn i32_reinterpret_f32_inst() -> Instruction {
  I32ReinterpretF32
}

///|
pub fn i64_reinterpret_f64_inst() -> Instruction {
  I64ReinterpretF64
}

///|
pub fn f32_reinterpret_i32_inst() -> Instruction {
  F32ReinterpretI32
}

///|
pub fn f64_reinterpret_i64_inst() -> Instruction {
  F64ReinterpretI64
}

///|
pub fn i32_extend8s_inst() -> Instruction {
  I32Extend8S
}

///|
pub fn i32_extend16s_inst() -> Instruction {
  I32Extend16S
}

///|
pub fn i64_extend8s_inst() -> Instruction {
  I64Extend8S
}

///|
pub fn i64_extend16s_inst() -> Instruction {
  I64Extend16S
}

///|
pub fn i64_extend32s_inst() -> Instruction {
  I64Extend32S
}

///|
pub fn ref_null_inst(ht : HeapType) -> Instruction {
  RefNull(ht)
}

///|
pub fn ref_is_null_inst() -> Instruction {
  RefIsNull
}

///|
pub fn ref_func_inst(fi : FuncIdx) -> Instruction {
  RefFunc(fi)
}

///|
pub fn ref_eq_inst() -> Instruction {
  RefEq
}

///|
pub fn ref_as_non_null_inst() -> Instruction {
  RefAsNonNull
}

///|
pub fn br_on_null_inst(li : LabelIdx) -> Instruction {
  BrOnNull(li)
}

///|
pub fn br_on_non_null_inst(li : LabelIdx) -> Instruction {
  BrOnNonNull(li)
}

///|
pub fn struct_new_inst(ti : TypeIdx) -> Instruction {
  StructNew(ti)
}

///|
pub fn struct_new_default_inst(ti : TypeIdx) -> Instruction {
  StructNewDefault(ti)
}

///|
pub fn struct_get_inst(ty : TypeIdx, fi : U32) -> Instruction {
  StructGet(ty, fi)
}

///|
pub fn struct_get_s_inst(ty : TypeIdx, fi : U32) -> Instruction {
  StructGetS(ty, fi)
}

///|
pub fn struct_get_u_inst(ty : TypeIdx, fi : U32) -> Instruction {
  StructGetU(ty, fi)
}

///|
pub fn struct_set_inst(ty : TypeIdx, fi : U32) -> Instruction {
  StructSet(ty, fi)
}

///|
pub fn array_new_inst(ti : TypeIdx) -> Instruction {
  ArrayNew(ti)
}

///|
pub fn array_new_default_inst(ti : TypeIdx) -> Instruction {
  ArrayNewDefault(ti)
}

///|
pub fn array_new_fixed_inst(ti : TypeIdx, len : U32) -> Instruction {
  ArrayNewFixed(ti, len)
}

///|
pub fn array_new_data_inst(ti : TypeIdx, di : DataIdx) -> Instruction {
  ArrayNewData(ti, di)
}

///|
pub fn array_new_elem_inst(ti : TypeIdx, ei : ElemIdx) -> Instruction {
  ArrayNewElem(ti, ei)
}

///|
pub fn array_get_inst(ti : TypeIdx) -> Instruction {
  ArrayGet(ti)
}

///|
pub fn array_get_s_inst(ti : TypeIdx) -> Instruction {
  ArrayGetS(ti)
}

///|
pub fn array_get_u_inst(ti : TypeIdx) -> Instruction {
  ArrayGetU(ti)
}

///|
pub fn array_set_inst(ti : TypeIdx) -> Instruction {
  ArraySet(ti)
}

///|
pub fn array_len_inst() -> Instruction {
  ArrayLen
}

///|
pub fn array_fill_inst(ti : TypeIdx) -> Instruction {
  ArrayFill(ti)
}

///|
pub fn array_copy_inst(ti0 : TypeIdx, ti1 : TypeIdx) -> Instruction {
  ArrayCopy(ti0, ti1)
}

///|
pub fn array_init_data_inst(ti : TypeIdx, di : DataIdx) -> Instruction {
  ArrayInitData(ti, di)
}

///|
pub fn array_init_elem_inst(ti : TypeIdx, ei : ElemIdx) -> Instruction {
  ArrayInitElem(ti, ei)
}

///|
pub fn ref_test_inst(nullable : Bool, ht : HeapType) -> Instruction {
  RefTest(nullable, ht)
}

///|
pub fn ref_cast_inst(nullable : Bool, ht : HeapType) -> Instruction {
  RefCast(nullable, ht)
}

///|
pub fn br_on_cast_inst(
  li : LabelIdx,
  t_nullable_0 : Bool,
  ht0 : HeapType,
  t_nullable_1 : Bool,
  ht1 : HeapType,
) -> Instruction {
  BrOnCast(li, CastOp(t_nullable_0, t_nullable_1), ht0, ht1)
}

///|
pub fn br_on_cast_fail_inst(
  li : LabelIdx,
  t_nullable_0 : Bool,
  ht0 : HeapType,
  t_nullable_1 : Bool,
  ht1 : HeapType,
) -> Instruction {
  BrOnCastFail(li, CastOp(t_nullable_0, t_nullable_1), ht0, ht1)
}

///|
pub fn any_convert_extern_inst() -> Instruction {
  AnyConvertExtern
}

///|
pub fn extern_convert_any_inst() -> Instruction {
  ExternConvertAny
}

///|
pub fn ref_i31_inst() -> Instruction {
  RefI31
}

///|
pub fn i31_get_s_inst() -> Instruction {
  I31GetS
}

///|
pub fn i31_get_u_inst() -> Instruction {
  I31GetU
}

///|
pub fn i32_trunc_sat_f32s_inst() -> Instruction {
  I32TruncSatF32S
}

///|
pub fn i32_trunc_sat_f32u_inst() -> Instruction {
  I32TruncSatF32U
}

///|
pub fn i32_trunc_sat_f64s_inst() -> Instruction {
  I32TruncSatF64S
}

///|
pub fn i32_trunc_sat_f64u_inst() -> Instruction {
  I32TruncSatF64U
}

///|
pub fn i64_trunc_sat_f32s_inst() -> Instruction {
  I64TruncSatF32S
}

///|
pub fn i64_trunc_sat_f32u_inst() -> Instruction {
  I64TruncSatF32U
}

///|
pub fn i64_trunc_sat_f64s_inst() -> Instruction {
  I64TruncSatF64S
}

///|
pub fn i64_trunc_sat_f64u_inst() -> Instruction {
  I64TruncSatF64U
}

///|
pub fn memory_init_inst(di : DataIdx, mi : MemIdx) -> Instruction {
  MemoryInit(di, mi)
}

///|
pub fn data_drop_inst(di : DataIdx) -> Instruction {
  DataDrop(di)
}

///|
pub fn memory_copy_inst(mi0 : MemIdx, mi1 : MemIdx) -> Instruction {
  MemoryCopy(mi0, mi1)
}

///|
pub fn memory_fill_inst(mi : MemIdx) -> Instruction {
  MemoryFill(mi)
}

///|
pub fn table_init_inst(ei : ElemIdx, ti : TableIdx) -> Instruction {
  TableInit(ei, ti)
}

///|
pub fn elem_drop_inst(ei : ElemIdx) -> Instruction {
  ElemDrop(ei)
}

///|
pub fn table_copy_inst(ti0 : TableIdx, ti1 : TableIdx) -> Instruction {
  TableCopy(ti0, ti1)
}

///|
pub fn table_grow_inst(ti : TableIdx) -> Instruction {
  TableGrow(ti)
}

///|
pub fn table_size_inst(ti : TableIdx) -> Instruction {
  TableSize(ti)
}

///|
pub fn table_fill_inst(ti : TableIdx) -> Instruction {
  TableFill(ti)
}

///|
pub fn v128_load_inst(ma : MemArg) -> Instruction {
  V128Load(ma)
}

///|
pub fn v128_load8x8s_inst(ma : MemArg) -> Instruction {
  V128Load8x8S(ma)
}

///|
pub fn v128_load8x8u_inst(ma : MemArg) -> Instruction {
  V128Load8x8U(ma)
}

///|
pub fn v128_load16x4s_inst(ma : MemArg) -> Instruction {
  V128Load16x4S(ma)
}

///|
pub fn v128_load16x4u_inst(ma : MemArg) -> Instruction {
  V128Load16x4U(ma)
}

///|
pub fn v128_load32x2s_inst(ma : MemArg) -> Instruction {
  V128Load32x2S(ma)
}

///|
pub fn v128_load32x2u_inst(ma : MemArg) -> Instruction {
  V128Load32x2U(ma)
}

///|
pub fn v128_load8_splat_inst(ma : MemArg) -> Instruction {
  V128Load8Splat(ma)
}

///|
pub fn v128_load16_splat_inst(ma : MemArg) -> Instruction {
  V128Load16Splat(ma)
}

///|
pub fn v128_load32_splat_inst(ma : MemArg) -> Instruction {
  V128Load32Splat(ma)
}

///|
pub fn v128_load64_splat_inst(ma : MemArg) -> Instruction {
  V128Load64Splat(ma)
}

///|
pub fn v128_store_inst(ma : MemArg) -> Instruction {
  V128Store(ma)
}

///|
pub fn v128_const_inst(
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
  b4 : Byte,
  b5 : Byte,
  b6 : Byte,
  b7 : Byte,
  b8 : Byte,
  b9 : Byte,
  b10 : Byte,
  b11 : Byte,
  b12 : Byte,
  b13 : Byte,
  b14 : Byte,
  b15 : Byte,
) -> Instruction {
  V128Const(
    b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
  )
}

///|
pub fn i8x16_shuffle_inst(
  li0 : LaneIdx,
  li1 : LaneIdx,
  li2 : LaneIdx,
  li3 : LaneIdx,
  li4 : LaneIdx,
  li5 : LaneIdx,
  li6 : LaneIdx,
  li7 : LaneIdx,
  li8 : LaneIdx,
  li9 : LaneIdx,
  li10 : LaneIdx,
  li11 : LaneIdx,
  li12 : LaneIdx,
  li13 : LaneIdx,
  li14 : LaneIdx,
  li15 : LaneIdx,
) -> Instruction {
  I8x16Shuffle(
    li0, li1, li2, li3, li4, li5, li6, li7, li8, li9, li10, li11, li12, li13, li14,
    li15,
  )
}

///|
pub fn i8x16_swizzle_inst() -> Instruction {
  I8x16Swizzle
}

///|
pub fn i8x16_splat_inst() -> Instruction {
  I8x16Splat
}

///|
pub fn i16x8_splat_inst() -> Instruction {
  I16x8Splat
}

///|
pub fn i32x4_splat_inst() -> Instruction {
  I32x4Splat
}

///|
pub fn i64x2_splat_inst() -> Instruction {
  I64x2Splat
}

///|
pub fn f32x4_splat_inst() -> Instruction {
  F32x4Splat
}

///|
pub fn f64x2_splat_inst() -> Instruction {
  F64x2Splat
}

///|
pub fn i8x16_extract_lane_s_inst(li : LaneIdx) -> Instruction {
  I8x16ExtractLaneS(li)
}

///|
pub fn i8x16_extract_lane_u_inst(li : LaneIdx) -> Instruction {
  I8x16ExtractLaneU(li)
}

///|
pub fn i8x16_replace_lane_inst(li : LaneIdx) -> Instruction {
  I8x16ReplaceLane(li)
}

///|
pub fn i16x8_extract_lane_s_inst(li : LaneIdx) -> Instruction {
  I16x8ExtractLaneS(li)
}

///|
pub fn i16x8_extract_lane_u_inst(li : LaneIdx) -> Instruction {
  I16x8ExtractLaneU(li)
}

///|
pub fn i16x8_replace_lane_inst(li : LaneIdx) -> Instruction {
  I16x8ReplaceLane(li)
}

///|
pub fn i32x4_extract_lane_inst(li : LaneIdx) -> Instruction {
  I32x4ExtractLane(li)
}

///|
pub fn i32x4_replace_lane_inst(li : LaneIdx) -> Instruction {
  I32x4ReplaceLane(li)
}

///|
pub fn i64x2_extract_lane_inst(li : LaneIdx) -> Instruction {
  I64x2ExtractLane(li)
}

///|
pub fn i64x2_replace_lane_inst(li : LaneIdx) -> Instruction {
  I64x2ReplaceLane(li)
}

///|
pub fn f32x4_extract_lane_inst(li : LaneIdx) -> Instruction {
  F32x4ExtractLane(li)
}

///|
pub fn f32x4_replace_lane_inst(li : LaneIdx) -> Instruction {
  F32x4ReplaceLane(li)
}

///|
pub fn f64x2_extract_lane_inst(li : LaneIdx) -> Instruction {
  F64x2ExtractLane(li)
}

///|
pub fn f64x2_replace_lane_inst(li : LaneIdx) -> Instruction {
  F64x2ReplaceLane(li)
}

///|
pub fn i8x16_eq_inst() -> Instruction {
  I8x16Eq
}

///|
pub fn i8x16_ne_inst() -> Instruction {
  I8x16Ne
}

///|
pub fn i8x16_lt_s_inst() -> Instruction {
  I8x16LtS
}

///|
pub fn i8x16_lt_u_inst() -> Instruction {
  I8x16LtU
}

///|
pub fn i8x16_gt_s_inst() -> Instruction {
  I8x16GtS
}

///|
pub fn i8x16_gt_u_inst() -> Instruction {
  I8x16GtU
}

///|
pub fn i8x16_le_s_inst() -> Instruction {
  I8x16LeS
}

///|
pub fn i8x16_le_u_inst() -> Instruction {
  I8x16LeU
}

///|
pub fn i8x16_ge_s_inst() -> Instruction {
  I8x16GeS
}

///|
pub fn i8x16_ge_u_inst() -> Instruction {
  I8x16GeU
}

///|
pub fn i16x8_eq_inst() -> Instruction {
  I16x8Eq
}

///|
pub fn i16x8_ne_inst() -> Instruction {
  I16x8Ne
}

///|
pub fn i16x8_lt_s_inst() -> Instruction {
  I16x8LtS
}

///|
pub fn i16x8_lt_u_inst() -> Instruction {
  I16x8LtU
}

///|
pub fn i16x8_gt_s_inst() -> Instruction {
  I16x8GtS
}

///|
pub fn i16x8_gt_u_inst() -> Instruction {
  I16x8GtU
}

///|
pub fn i16x8_le_s_inst() -> Instruction {
  I16x8LeS
}

///|
pub fn i16x8_le_u_inst() -> Instruction {
  I16x8LeU
}

///|
pub fn i16x8_ge_s_inst() -> Instruction {
  I16x8GeS
}

///|
pub fn i16x8_ge_u_inst() -> Instruction {
  I16x8GeU
}

///|
pub fn i32x4_eq_inst() -> Instruction {
  I32x4Eq
}

///|
pub fn i32x4_ne_inst() -> Instruction {
  I32x4Ne
}

///|
pub fn i32x4_lt_s_inst() -> Instruction {
  I32x4LtS
}

///|
pub fn i32x4_lt_u_inst() -> Instruction {
  I32x4LtU
}

///|
pub fn i32x4_gt_s_inst() -> Instruction {
  I32x4GtS
}

///|
pub fn i32x4_gt_u_inst() -> Instruction {
  I32x4GtU
}

///|
pub fn i32x4_le_s_inst() -> Instruction {
  I32x4LeS
}

///|
pub fn i32x4_le_u_inst() -> Instruction {
  I32x4LeU
}

///|
pub fn i32x4_ge_s_inst() -> Instruction {
  I32x4GeS
}

///|
pub fn i32x4_ge_u_inst() -> Instruction {
  I32x4GeU
}

///|
pub fn f32x4_eq_inst() -> Instruction {
  F32x4Eq
}

///|
pub fn f32x4_ne_inst() -> Instruction {
  F32x4Ne
}

///|
pub fn f32x4_lt_inst() -> Instruction {
  F32x4Lt
}

///|
pub fn f32x4_gt_inst() -> Instruction {
  F32x4Gt
}

///|
pub fn f32x4_le_inst() -> Instruction {
  F32x4Le
}

///|
pub fn f32x4_ge_inst() -> Instruction {
  F32x4Ge
}

///|
pub fn f64x2_eq_inst() -> Instruction {
  F64x2Eq
}

///|
pub fn f64x2_ne_inst() -> Instruction {
  F64x2Ne
}

///|
pub fn f64x2_lt_inst() -> Instruction {
  F64x2Lt
}

///|
pub fn f64x2_gt_inst() -> Instruction {
  F64x2Gt
}

///|
pub fn f64x2_le_inst() -> Instruction {
  F64x2Le
}

///|
pub fn f64x2_ge_inst() -> Instruction {
  F64x2Ge
}

///|
pub fn v128_not_inst() -> Instruction {
  V128Not
}

///|
pub fn v128_and_inst() -> Instruction {
  V128And
}

///|
pub fn v128_andnot_inst() -> Instruction {
  V128Andnot
}

///|
pub fn v128_or_inst() -> Instruction {
  V128Or
}

///|
pub fn v128_xor_inst() -> Instruction {
  V128Xor
}

///|
pub fn v128_bitselect_inst() -> Instruction {
  V128Bitselect
}

///|
pub fn v128_any_true_inst() -> Instruction {
  V128AnyTrue
}

///|
pub fn v128_load8_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load8Lane(ma, li)
}

///|
pub fn v128_load16_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load16Lane(ma, li)
}

///|
pub fn v128_load32_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load32Lane(ma, li)
}

///|
pub fn v128_load64_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load64Lane(ma, li)
}

///|
pub fn v128_store8_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store8Lane(ma, li)
}

///|
pub fn v128_store16_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store16Lane(ma, li)
}

///|
pub fn v128_store32_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store32Lane(ma, li)
}

///|
pub fn v128_store64_lane_inst(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store64Lane(ma, li)
}

///|
pub fn v128_load32_zero_inst(ma : MemArg) -> Instruction {
  V128Load32Zero(ma)
}

///|
pub fn v128_load64_zero_inst(ma : MemArg) -> Instruction {
  V128Load64Zero(ma)
}

///|
pub fn f32x4_demote_f64x2_zero_inst() -> Instruction {
  F32x4DemoteF64x2Zero
}

///|
pub fn f64x2_promote_low_f32x4_inst() -> Instruction {
  F64x2PromoteLowF32x4
}

///|
pub fn i8x16_abs_inst() -> Instruction {
  I8x16Abs
}

///|
pub fn i8x16_neg_inst() -> Instruction {
  I8x16Neg
}

///|
pub fn i8x16_popcnt_inst() -> Instruction {
  I8x16Popcnt
}

///|
pub fn i8x16_all_true_inst() -> Instruction {
  I8x16AllTrue
}

///|
pub fn i8x16_bitmask_inst() -> Instruction {
  I8x16Bitmask
}

///|
pub fn i8x16_narrow_i16x8s_inst() -> Instruction {
  I8x16NarrowI16x8S
}

///|
pub fn i8x16_narrow_i16x8u_inst() -> Instruction {
  I8x16NarrowI16x8U
}

///|
pub fn f32x4_ceil_inst() -> Instruction {
  F32x4Ceil
}

///|
pub fn f32x4_floor_inst() -> Instruction {
  F32x4Floor
}

///|
pub fn f32x4_trunc_inst() -> Instruction {
  F32x4Trunc
}

///|
pub fn f32x4_nearest_inst() -> Instruction {
  F32x4Nearest
}

///|
pub fn i8x16_shl_inst() -> Instruction {
  I8x16Shl
}

///|
pub fn i8x16_shr_s_inst() -> Instruction {
  I8x16ShrS
}

///|
pub fn i8x16_shr_u_inst() -> Instruction {
  I8x16ShrU
}

///|
pub fn i8x16_add_inst() -> Instruction {
  I8x16Add
}

///|
pub fn i8x16_add_sat_s_inst() -> Instruction {
  I8x16AddSatS
}

///|
pub fn i8x16_add_sat_u_inst() -> Instruction {
  I8x16AddSatU
}

///|
pub fn i8x16_sub_inst() -> Instruction {
  I8x16Sub
}

///|
pub fn i8x16_sub_sat_s_inst() -> Instruction {
  I8x16SubSatS
}

///|
pub fn i8x16_sub_sat_u_inst() -> Instruction {
  I8x16SubSatU
}

///|
pub fn f64x2_ceil_inst() -> Instruction {
  F64x2Ceil
}

///|
pub fn f64x2_floor_inst() -> Instruction {
  F64x2Floor
}

///|
pub fn i8x16_min_s_inst() -> Instruction {
  I8x16MinS
}

///|
pub fn i8x16_min_u_inst() -> Instruction {
  I8x16MinU
}

///|
pub fn i8x16_max_s_inst() -> Instruction {
  I8x16MaxS
}

///|
pub fn i8x16_max_u_inst() -> Instruction {
  I8x16MaxU
}

///|
pub fn f64x2_trunc_inst() -> Instruction {
  F64x2Trunc
}

///|
pub fn i8x16_avgr_u_inst() -> Instruction {
  I8x16AvgrU
}

///|
pub fn i16x8_extadd_pairwise_i8x16s_inst() -> Instruction {
  I16x8ExtaddPairwiseI8x16S
}

///|
pub fn i16x8_extadd_pairwise_i8x16u_inst() -> Instruction {
  I16x8ExtaddPairwiseI8x16U
}

///|
pub fn i32x4_extadd_pairwise_i16x8s_inst() -> Instruction {
  I32x4ExtaddPairwiseI16x8S
}

///|
pub fn i32x4_extadd_pairwise_i16x8u_inst() -> Instruction {
  I32x4ExtaddPairwiseI16x8U
}

///|
pub fn i16x8_abs_inst() -> Instruction {
  I16x8Abs
}

///|
pub fn i16x8_neg_inst() -> Instruction {
  I16x8Neg
}

///|
pub fn i16x8q15mulr_sat_s_inst() -> Instruction {
  I16x8Q15mulrSatS
}

///|
pub fn i16x8_all_true_inst() -> Instruction {
  I16x8AllTrue
}

///|
pub fn i16x8_bitmask_inst() -> Instruction {
  I16x8Bitmask
}

///|
pub fn i16x8_narrow_i32x4s_inst() -> Instruction {
  I16x8NarrowI32x4S
}

///|
pub fn i16x8_narrow_i32x4u_inst() -> Instruction {
  I16x8NarrowI32x4U
}

///|
pub fn i16x8_extend_low_i8x16s_inst() -> Instruction {
  I16x8ExtendLowI8x16S
}

///|
pub fn i16x8_extend_high_i8x16s_inst() -> Instruction {
  I16x8ExtendHighI8x16S
}

///|
pub fn i16x8_extend_low_i8x16u_inst() -> Instruction {
  I16x8ExtendLowI8x16U
}

///|
pub fn i16x8_extend_high_i8x16u_inst() -> Instruction {
  I16x8ExtendHighI8x16U
}

///|
pub fn i16x8_shl_inst() -> Instruction {
  I16x8Shl
}

///|
pub fn i16x8_shr_s_inst() -> Instruction {
  I16x8ShrS
}

///|
pub fn i16x8_shr_u_inst() -> Instruction {
  I16x8ShrU
}

///|
pub fn i16x8_add_inst() -> Instruction {
  I16x8Add
}

///|
pub fn i16x8_add_sat_s_inst() -> Instruction {
  I16x8AddSatS
}

///|
pub fn i16x8_add_sat_u_inst() -> Instruction {
  I16x8AddSatU
}

///|
pub fn i16x8_sub_inst() -> Instruction {
  I16x8Sub
}

///|
pub fn i16x8_sub_sat_s_inst() -> Instruction {
  I16x8SubSatS
}

///|
pub fn i16x8_sub_sat_u_inst() -> Instruction {
  I16x8SubSatU
}

///|
pub fn f64x2_nearest_inst() -> Instruction {
  F64x2Nearest
}

///|
pub fn i16x8_mul_inst() -> Instruction {
  I16x8Mul
}

///|
pub fn i16x8_min_s_inst() -> Instruction {
  I16x8MinS
}

///|
pub fn i16x8_min_u_inst() -> Instruction {
  I16x8MinU
}

///|
pub fn i16x8_max_s_inst() -> Instruction {
  I16x8MaxS
}

///|
pub fn i16x8_max_u_inst() -> Instruction {
  I16x8MaxU
}

///|
pub fn i16x8_avgr_u_inst() -> Instruction {
  I16x8AvgrU
}

///|
pub fn i16x8_extmul_low_i8x16s_inst() -> Instruction {
  I16x8ExtmulLowI8x16S
}

///|
pub fn i16x8_extmul_high_i8x16s_inst() -> Instruction {
  I16x8ExtmulHighI8x16S
}

///|
pub fn i16x8_extmul_low_i8x16u_inst() -> Instruction {
  I16x8ExtmulLowI8x16U
}

///|
pub fn i16x8_extmul_high_i8x16u_inst() -> Instruction {
  I16x8ExtmulHighI8x16U
}

///|
pub fn i32x4_abs_inst() -> Instruction {
  I32x4Abs
}

///|
pub fn i32x4_neg_inst() -> Instruction {
  I32x4Neg
}

///|
pub fn i32x4_all_true_inst() -> Instruction {
  I32x4AllTrue
}

///|
pub fn i32x4_bitmask_inst() -> Instruction {
  I32x4Bitmask
}

///|
pub fn i32x4_extend_low_i16x8s_inst() -> Instruction {
  I32x4ExtendLowI16x8S
}

///|
pub fn i32x4_extend_high_i16x8s_inst() -> Instruction {
  I32x4ExtendHighI16x8S
}

///|
pub fn i32x4_extend_low_i16x8u_inst() -> Instruction {
  I32x4ExtendLowI16x8U
}

///|
pub fn i32x4_extend_high_i16x8u_inst() -> Instruction {
  I32x4ExtendHighI16x8U
}

///|
pub fn i32x4_shl_inst() -> Instruction {
  I32x4Shl
}

///|
pub fn i32x4_shr_s_inst() -> Instruction {
  I32x4ShrS
}

///|
pub fn i32x4_shr_u_inst() -> Instruction {
  I32x4ShrU
}

///|
pub fn i32x4_add_inst() -> Instruction {
  I32x4Add
}

///|
pub fn i32x4_sub_inst() -> Instruction {
  I32x4Sub
}

///|
pub fn i32x4_mul_inst() -> Instruction {
  I32x4Mul
}

///|
pub fn i32x4_min_s_inst() -> Instruction {
  I32x4MinS
}

///|
pub fn i32x4_min_u_inst() -> Instruction {
  I32x4MinU
}

///|
pub fn i32x4_max_s_inst() -> Instruction {
  I32x4MaxS
}

///|
pub fn i32x4_max_u_inst() -> Instruction {
  I32x4MaxU
}

///|
pub fn i32x4_dot_i16x8s_inst() -> Instruction {
  I32x4DotI16x8S
}

///|
pub fn i32x4_extmul_low_i16x8s_inst() -> Instruction {
  I32x4ExtmulLowI16x8S
}

///|
pub fn i32x4_extmul_high_i16x8s_inst() -> Instruction {
  I32x4ExtmulHighI16x8S
}

///|
pub fn i32x4_extmul_low_i16x8u_inst() -> Instruction {
  I32x4ExtmulLowI16x8U
}

///|
pub fn i32x4_extmul_high_i16x8u_inst() -> Instruction {
  I32x4ExtmulHighI16x8U
}

///|
pub fn i64x2_abs_inst() -> Instruction {
  I64x2Abs
}

///|
pub fn i64x2_neg_inst() -> Instruction {
  I64x2Neg
}

///|
pub fn i64x2_all_true_inst() -> Instruction {
  I64x2AllTrue
}

///|
pub fn i64x2_bitmask_inst() -> Instruction {
  I64x2Bitmask
}

///|
pub fn i64x2_extend_low_i32x4s_inst() -> Instruction {
  I64x2ExtendLowI32x4S
}

///|
pub fn i64x2_extend_high_i32x4s_inst() -> Instruction {
  I64x2ExtendHighI32x4S
}

///|
pub fn i64x2_extend_low_i32x4u_inst() -> Instruction {
  I64x2ExtendLowI32x4U
}

///|
pub fn i64x2_extend_high_i32x4u_inst() -> Instruction {
  I64x2ExtendHighI32x4U
}

///|
pub fn i64x2_shl_inst() -> Instruction {
  I64x2Shl
}

///|
pub fn i64x2_shr_s_inst() -> Instruction {
  I64x2ShrS
}

///|
pub fn i64x2_shr_u_inst() -> Instruction {
  I64x2ShrU
}

///|
pub fn i64x2_add_inst() -> Instruction {
  I64x2Add
}

///|
pub fn i64x2_sub_inst() -> Instruction {
  I64x2Sub
}

///|
pub fn i64x2_mul_inst() -> Instruction {
  I64x2Mul
}

///|
pub fn i64x2_eq_inst() -> Instruction {
  I64x2Eq
}

///|
pub fn i64x2_ne_inst() -> Instruction {
  I64x2Ne
}

///|
pub fn i64x2_lt_s_inst() -> Instruction {
  I64x2LtS
}

///|
pub fn i64x2_gt_s_inst() -> Instruction {
  I64x2GtS
}

///|
pub fn i64x2_le_s_inst() -> Instruction {
  I64x2LeS
}

///|
pub fn i64x2_ge_s_inst() -> Instruction {
  I64x2GeS
}

///|
pub fn i64x2_extmul_low_i32x4s_inst() -> Instruction {
  I64x2ExtmulLowI32x4S
}

///|
pub fn i64x2_extmul_high_i32x4s_inst() -> Instruction {
  I64x2ExtmulHighI32x4S
}

///|
pub fn i64x2_extmul_low_i32x4u_inst() -> Instruction {
  I64x2ExtmulLowI32x4U
}

///|
pub fn i64x2_extmul_high_i32x4u_inst() -> Instruction {
  I64x2ExtmulHighI32x4U
}

///|
pub fn f32x4_abs_inst() -> Instruction {
  F32x4Abs
}

///|
pub fn f32x4_neg_inst() -> Instruction {
  F32x4Neg
}

///|
pub fn f32x4_sqrt_inst() -> Instruction {
  F32x4Sqrt
}

///|
pub fn f32x4_add_inst() -> Instruction {
  F32x4Add
}

///|
pub fn f32x4_sub_inst() -> Instruction {
  F32x4Sub
}

///|
pub fn f32x4_mul_inst() -> Instruction {
  F32x4Mul
}

///|
pub fn f32x4_div_inst() -> Instruction {
  F32x4Div
}

///|
pub fn f32x4_min_inst() -> Instruction {
  F32x4Min
}

///|
pub fn f32x4_max_inst() -> Instruction {
  F32x4Max
}

///|
pub fn f32x4_pmin_inst() -> Instruction {
  F32x4Pmin
}

///|
pub fn f32x4_pmax_inst() -> Instruction {
  F32x4Pmax
}

///|
pub fn f64x2_abs_inst() -> Instruction {
  F64x2Abs
}

///|
pub fn f64x2_neg_inst() -> Instruction {
  F64x2Neg
}

///|
pub fn f64x2_sqrt_inst() -> Instruction {
  F64x2Sqrt
}

///|
pub fn f64x2_add_inst() -> Instruction {
  F64x2Add
}

///|
pub fn f64x2_sub_inst() -> Instruction {
  F64x2Sub
}

///|
pub fn f64x2_mul_inst() -> Instruction {
  F64x2Mul
}

///|
pub fn f64x2_div_inst() -> Instruction {
  F64x2Div
}

///|
pub fn f64x2_min_inst() -> Instruction {
  F64x2Min
}

///|
pub fn f64x2_max_inst() -> Instruction {
  F64x2Max
}

///|
pub fn f64x2_pmin_inst() -> Instruction {
  F64x2Pmin
}

///|
pub fn f64x2_pmax_inst() -> Instruction {
  F64x2Pmax
}

///|
pub fn i32x4_trunc_sat_f32x4s_inst() -> Instruction {
  I32x4TruncSatF32x4S
}

///|
pub fn i32x4_trunc_sat_f32x4u_inst() -> Instruction {
  I32x4TruncSatF32x4U
}

///|
pub fn f32x4_convert_i32x4s_inst() -> Instruction {
  F32x4ConvertI32x4S
}

///|
pub fn f32x4_convert_i32x4u_inst() -> Instruction {
  F32x4ConvertI32x4U
}

///|
pub fn i32x4_trunc_sat_f64x2s_zero_inst() -> Instruction {
  I32x4TruncSatF64x2SZero
}

///|
pub fn i32x4_trunc_sat_f64x2u_zero_inst() -> Instruction {
  I32x4TruncSatF64x2UZero
}

///|
pub fn f64x2_convert_low_i32x4s_inst() -> Instruction {
  F64x2ConvertLowI32x4S
}

///|
pub fn f64x2_convert_low_i32x4u_inst() -> Instruction {
  F64x2ConvertLowI32x4U
}

///|
pub fn i8x16_relaxed_swizzle_inst() -> Instruction {
  I8x16RelaxedSwizzle
}

///|
pub fn i32x4_relaxed_trunc_f32x4s_inst() -> Instruction {
  I32x4RelaxedTruncF32x4S
}

///|
pub fn i32x4_relaxed_trunc_f32x4u_inst() -> Instruction {
  I32x4RelaxedTruncF32x4U
}

///|
pub fn i32x4_relaxed_trunc_zero_f64x2s_inst() -> Instruction {
  I32x4RelaxedTruncZeroF64x2S
}

///|
pub fn i32x4_relaxed_trunc_zero_f64x2u_inst() -> Instruction {
  I32x4RelaxedTruncZeroF64x2U
}

///|
pub fn f32x4_relaxed_madd_inst() -> Instruction {
  F32x4RelaxedMadd
}

///|
pub fn f32x4_relaxed_nmadd_inst() -> Instruction {
  F32x4RelaxedNmadd
}

///|
pub fn f64x2_relaxed_madd_inst() -> Instruction {
  F64x2RelaxedMadd
}

///|
pub fn f64x2_relaxed_nmadd_inst() -> Instruction {
  F64x2RelaxedNmadd
}

///|
pub fn i8x16_relaxed_laneselect_inst() -> Instruction {
  I8x16RelaxedLaneselect
}

///|
pub fn i16x8_relaxed_laneselect_inst() -> Instruction {
  I16x8RelaxedLaneselect
}

///|
pub fn i32x4_relaxed_laneselect_inst() -> Instruction {
  I32x4RelaxedLaneselect
}

///|
pub fn i64x2_relaxed_laneselect_inst() -> Instruction {
  I64x2RelaxedLaneselect
}

///|
pub fn f32x4_relaxed_min_inst() -> Instruction {
  F32x4RelaxedMin
}

///|
pub fn f32x4_relaxed_max_inst() -> Instruction {
  F32x4RelaxedMax
}

///|
pub fn f64x2_relaxed_min_inst() -> Instruction {
  F64x2RelaxedMin
}

///|
pub fn f64x2_relaxed_max_inst() -> Instruction {
  F64x2RelaxedMax
}

///|
pub fn i16x8_relaxed_q15mulr_s_inst() -> Instruction {
  I16x8RelaxedQ15mulrS
}

///|
pub fn i16x8_relaxed_dot_i8x16i7x16s_inst() -> Instruction {
  I16x8RelaxedDotI8x16I7x16S
}

///|
pub fn i32x4_relaxed_dot_i8x16i7x16_add_s_inst() -> Instruction {
  I32x4RelaxedDotI8x16I7x16AddS
}

///|
pub fn t_i32_const(val : I32) -> TInstr {
  TI32Const(val)
}

///|
pub fn t_i64_const(val : I64) -> TInstr {
  TI64Const(val)
}

///|
pub fn t_f32_const(val : F32) -> TInstr {
  TF32Const(val)
}

///|
pub fn t_f64_const(val : F64) -> TInstr {
  TF64Const(val)
}

///|
pub fn t_ref_null(val : HeapType) -> TInstr {
  TRefNull(val)
}

///|
pub fn t_ref_func(val : FuncIdx) -> TInstr {
  TRefFunc(val)
}

///|
pub fn t_v128_const_inst(
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
  b4 : Byte,
  b5 : Byte,
  b6 : Byte,
  b7 : Byte,
  b8 : Byte,
  b9 : Byte,
  b10 : Byte,
  b11 : Byte,
  b12 : Byte,
  b13 : Byte,
  b14 : Byte,
  b15 : Byte,
) -> TInstr {
  TV128Const(
    b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
  )
}

///|
pub fn t_unreachable() -> TInstr {
  TUnreachable
}

///|
pub fn t_nop() -> TInstr {
  TNop
}

///|
pub fn t_local_get(idx : LocalIdx) -> TInstr {
  TLocalGet(idx)
}

///|
pub fn t_global_get(idx : GlobalIdx) -> TInstr {
  TGlobalGet(idx)
}

///|
pub fn t_memory_size(idx : MemIdx) -> TInstr {
  TMemorySize(idx)
}

///|
pub fn t_table_size(idx : TableIdx) -> TInstr {
  TTableSize(idx)
}

///|
pub fn t_unary(op : UnaryOp, i : TInstr) -> TInstr {
  TUnary(op, i)
}

///|
pub fn t_drop(i : TInstr) -> TInstr {
  TDrop(i)
}

///|
pub fn t_local_set(idx : LocalIdx, i : TInstr) -> TInstr {
  TLocalSet(idx, i)
}

///|
pub fn t_local_tee(idx : LocalIdx, i : TInstr) -> TInstr {
  TLocalTee(idx, i)
}

///|
pub fn t_global_set(idx : GlobalIdx, i : TInstr) -> TInstr {
  TGlobalSet(idx, i)
}

///|
pub fn t_ref_is_null(i : TInstr) -> TInstr {
  TRefIsNull(i)
}

///|
pub fn t_ref_as_non_null(i : TInstr) -> TInstr {
  TRefAsNonNull(i)
}

///|
pub fn t_i31_get_s(i : TInstr) -> TInstr {
  TI31GetS(i)
}

///|
pub fn t_i31_get_u(i : TInstr) -> TInstr {
  TI31GetU(i)
}

///|
pub fn t_ref_i31(i : TInstr) -> TInstr {
  TRefI31(i)
}

///|
pub fn t_array_len(i : TInstr) -> TInstr {
  TArrayLen(i)
}

///|
pub fn t_any_convert_extern(i : TInstr) -> TInstr {
  TAnyConvertExtern(i)
}

///|
pub fn t_extern_convert_any(i : TInstr) -> TInstr {
  TExternConvertAny(i)
}

///|
pub fn t_throw_ref(i : TInstr) -> TInstr {
  TThrowRef(i)
}

///|
pub fn t_binary(op : BinaryOp, i0 : TInstr, i1 : TInstr) -> TInstr {
  TBinary(op, i0, i1)
}

///|
pub fn t_ref_eq(i0 : TInstr, i1 : TInstr) -> TInstr {
  TRefEq(i0, i1)
}

///|
pub fn t_store(op : StoreOp, ma : MemArg, i0 : TInstr, i1 : TInstr) -> TInstr {
  TStore(op, ma, i0, i1)
}

///|
pub fn t_load(op : LoadOp, ma : MemArg, i : TInstr) -> TInstr {
  TLoad(op, ma, i)
}

///|
pub fn t_memory_grow(mi : MemIdx, i : TInstr) -> TInstr {
  TMemoryGrow(mi, i)
}

///|
pub fn t_memory_fill(
  mi : MemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryFill(mi, i0, i1, i2)
}

///|
pub fn t_memory_copy(
  mi0 : MemIdx,
  mi1 : MemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryCopy(mi0, mi1, i0, i1, i2)
}

///|
pub fn t_memory_init(
  di : DataIdx,
  mi : MemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryInit(di, mi, i0, i1, i2)
}

///|
pub fn t_data_drop(di : DataIdx) -> TInstr {
  TDataDrop(di)
}

///|
pub fn t_table_get(ti : TableIdx, i : TInstr) -> TInstr {
  TTableGet(ti, i)
}

///|
pub fn t_table_set(ti : TableIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TTableSet(ti, i0, i1)
}

///|
pub fn t_table_grow(ti : TableIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TTableGrow(ti, i0, i1)
}

///|
pub fn t_table_fill(
  ti : TableIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TTableFill(ti, i0, i1, i2)
}

///|
pub fn t_table_copy(
  ti0 : TableIdx,
  ti1 : TableIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TTableCopy(ti0, ti1, i0, i1, i2)
}

///|
pub fn t_table_init(
  ei : ElemIdx,
  ti : TableIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TTableInit(ei, ti, i0, i1, i2)
}

///|
pub fn t_elem_drop(ei : ElemIdx) -> TInstr {
  TElemDrop(ei)
}

///|
pub fn t_call(di : FuncIdx, props : Array[TInstr]) -> TInstr {
  TCall(di, props)
}

///|
pub fn t_call_indirect(
  ty_i : TypeIdx,
  tbl_i : TableIdx,
  props : Array[TInstr],
  i : TInstr,
) -> TInstr {
  TCallIndirect(ty_i, tbl_i, props, i)
}

///|
pub fn t_call_ref(ti : TypeIdx, props : Array[TInstr], r : TInstr) -> TInstr {
  TCallRef(ti, props, r)
}

///|
pub fn t_return_call(fi : FuncIdx, props : Array[TInstr]) -> TInstr {
  TReturnCall(fi, props)
}

///|
pub fn t_return_call_indirect(
  ty_i : TypeIdx,
  tbl_i : TableIdx,
  props : Array[TInstr],
  i : TInstr,
) -> TInstr {
  TReturnCallIndirect(ty_i, tbl_i, props, i)
}

///|
pub fn t_return_call_ref(
  ti : TypeIdx,
  props : Array[TInstr],
  i : TInstr,
) -> TInstr {
  TReturnCallRef(ti, props, i)
}

///|
pub fn t_block(bt : BlockType, e : TExpr) -> TInstr {
  TBlock(bt, e)
}

///|
pub fn t_loop(bt : BlockType, e : TExpr) -> TInstr {
  TLoop(bt, e)
}

///|
pub fn t_if(bt : BlockType, i : TInstr, e0 : TExpr, e1_opt : TExpr?) -> TInstr {
  TIf(bt, i, e0, e1_opt)
}

///|
pub fn t_try_table(bt : BlockType, c : Array[Catch], e : TExpr) -> TInstr {
  TTryTable(bt, c, e)
}

///|
pub fn t_throw(ti : TagIdx, i : Array[TInstr]) -> TInstr {
  TThrow(ti, i)
}

///|
pub fn t_br(li : LabelIdx, i : Array[TInstr]) -> TInstr {
  TBr(li, i)
}

///|
pub fn t_br_if(li : LabelIdx, i0 : TInstr, i : Array[TInstr]) -> TInstr {
  TBrIf(li, i0, i)
}

///|
pub fn t_br_table(
  l : Array[LabelIdx],
  l0 : LabelIdx,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrTable(l, l0, i0, i)
}

///|
pub fn t_br_on_null(li : LabelIdx, i0 : TInstr, i : Array[TInstr]) -> TInstr {
  TBrOnNull(li, i0, i)
}

///|
pub fn t_br_on_non_null(
  li : LabelIdx,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrOnNonNull(li, i0, i)
}

///|
pub fn t_br_on_cast(
  li : LabelIdx,
  ht_null_0 : Bool,
  ht0 : HeapType,
  ht_null_1 : Bool,
  ht1 : HeapType,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrOnCast(li, CastOp(ht_null_0, ht_null_1), ht0, ht1, i0, i)
}

///|
pub fn t_br_on_cast_fail(
  li : LabelIdx,
  ht_null_0 : Bool,
  ht0 : HeapType,
  ht_null_1 : Bool,
  ht1 : HeapType,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrOnCastFail(li, CastOp(ht_null_0, ht_null_1), ht0, ht1, i0, i)
}

///|
pub fn t_return(i : Array[TInstr]) -> TInstr {
  TReturn(i)
}

///|
pub fn t_select(
  tys : Array[ValType]?,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TSelect(tys, i0, i1, i2)
}

///|
pub fn t_struct_new(ti : TypeIdx, i : Array[TInstr]) -> TInstr {
  TStructNew(ti, i)
}

///|
pub fn t_struct_new_default(ti : TypeIdx) -> TInstr {
  TStructNewDefault(ti)
}

///|
pub fn t_struct_get(ti : TypeIdx, idx : U32, i : TInstr) -> TInstr {
  TStructGet(ti, idx, i)
}

///|
pub fn t_struct_get_s(ti : TypeIdx, idx : U32, i : TInstr) -> TInstr {
  TStructGetS(ti, idx, i)
}

///|
pub fn t_struct_get_u(ti : TypeIdx, idx : U32, i : TInstr) -> TInstr {
  TStructGetU(ti, idx, i)
}

///|
pub fn t_struct_set(
  ti : TypeIdx,
  idx : U32,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TStructSet(ti, idx, i0, i1)
}

///|
pub fn t_array_new(ti : TypeIdx, t0 : TInstr, t1 : TInstr) -> TInstr {
  TArrayNew(ti, t0, t1)
}

///|
pub fn t_array_new_default(ti : TypeIdx, i : TInstr) -> TInstr {
  TArrayNewDefault(ti, i)
}

///|
pub fn t_array_new_fixed(ti : TypeIdx, i : Array[TInstr]) -> TInstr {
  TArrayNewFixed(ti, i)
}

///|
pub fn t_array_new_data(
  ti : TypeIdx,
  di : DataIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TArrayNewData(ti, di, i0, i1)
}

///|
pub fn t_array_new_elem(
  ti : TypeIdx,
  ei : ElemIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TArrayNewElem(ti, ei, i0, i1)
}

///|
pub fn t_array_get(ti : TypeIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TArrayGet(ti, i0, i1)
}

///|
pub fn t_array_get_s(ti : TypeIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TArrayGetS(ti, i0, i1)
}

///|
pub fn t_array_get_u(ti : TypeIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TArrayGetU(ti, i0, i1)
}

///|
pub fn t_array_set(
  ti : TypeIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TArraySet(ti, i0, i1, i2)
}

///|
pub fn t_array_fill(
  ti : TypeIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
  i3 : TInstr,
) -> TInstr {
  TArrayFill(ti, i0, i1, i2, i3)
}

///|
pub fn t_array_copy(
  ti0 : TypeIdx,
  ti1 : TypeIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
  i3 : TInstr,
  i4 : TInstr,
) -> TInstr {
  TArrayCopy(ti0, ti1, i0, i1, i2, i3, i4)
}

///|
pub fn t_array_init_data(
  ti : TypeIdx,
  di : DataIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
  i3 : TInstr,
) -> TInstr {
  TArrayInitData(ti, di, i0, i1, i2, i3)
}

///|
pub fn t_array_init_elem(
  ti : TypeIdx,
  ei : ElemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
  i3 : TInstr,
) -> TInstr {
  TArrayInitElem(ti, ei, i0, i1, i2, i3)
}

///|
pub fn t_ref_test(nullable : Bool, ht : HeapType, i : TInstr) -> TInstr {
  TRefTest(nullable, ht, i)
}

///|
pub fn t_ref_cast(nullable : Bool, ht : HeapType, i : TInstr) -> TInstr {
  TRefCast(nullable, ht, i)
}

// === SIMD: Splat (scalar -> v128) ===

///|
pub fn t_i8x16_splat(i : TInstr) -> TInstr {
  TI8x16Splat(i)
}

///|
pub fn t_i16x8_splat(i : TInstr) -> TInstr {
  TI16x8Splat(i)
}

///|
pub fn t_i32x4_splat(i : TInstr) -> TInstr {
  TI32x4Splat(i)
}

///|
pub fn t_i64x2_splat(i : TInstr) -> TInstr {
  TI64x2Splat(i)
}

///|
pub fn t_f32x4_splat(i : TInstr) -> TInstr {
  TF32x4Splat(i)
}

///|
pub fn t_f64x2_splat(i : TInstr) -> TInstr {
  TF64x2Splat(i)
}

///|
pub fn t_extract_lane(op : ExtractLaneOp, li : LaneIdx, i : TInstr) -> TInstr {
  TExtractLane(op, li, i)
}

///|
pub fn t_replace_lane(
  op : ReplaceLaneOp,
  li : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TReplaceLane(op, li, i0, i1)
}

///|
pub fn t_i8x16_shuffle(
  li0 : LaneIdx,
  li1 : LaneIdx,
  li2 : LaneIdx,
  li3 : LaneIdx,
  li4 : LaneIdx,
  li5 : LaneIdx,
  li6 : LaneIdx,
  li7 : LaneIdx,
  li8 : LaneIdx,
  li9 : LaneIdx,
  li10 : LaneIdx,
  li11 : LaneIdx,
  li12 : LaneIdx,
  li13 : LaneIdx,
  li14 : LaneIdx,
  li15 : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TI8x16Shuffle(
    li0, li1, li2, li3, li4, li5, li6, li7, li8, li9, li10, li11, li12, li13, li14,
    li15, i0, i1,
  )
}

///|
pub fn t_i8x16_swizzle(i0 : TInstr, i1 : TInstr) -> TInstr {
  TI8x16Swizzle(i0, i1)
}

///|
pub fn t_i8x16_relaxed_swizzle(i0 : TInstr, i1 : TInstr) -> TInstr {
  TI8x16RelaxedSwizzle(i0, i1)
}

///|
pub fn tv128_shift(op : V128ShiftOp, i0 : TInstr, i1 : TInstr) -> TInstr {
  TV128Shift(op, i0, i1)
}

///|
pub fn tv128_ternary(
  op : V128TernaryOp,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TV128Ternary(op, i0, i1, i2)
}

///|
pub fn tv128_load_lane(
  op : V128LoadLaneOp,
  ma : MemArg,
  li : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TV128LoadLane(op, ma, li, i0, i1)
}

///|
pub fn tv128_store_lane(
  op : V128StoreLaneOp,
  ma : MemArg,
  li : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TV128StoreLane(op, ma, li, i0, i1)
}

///|
pub fn i32_eqz_op() -> UnaryOp {
  I32EqzOp
}

///|
pub fn i64_eqz_op() -> UnaryOp {
  I64EqzOp
}

///|
pub fn i32_clz_op() -> UnaryOp {
  I32ClzOp
}

///|
pub fn i32_ctz_op() -> UnaryOp {
  I32CtzOp
}

///|
pub fn i32_popcnt_op() -> UnaryOp {
  I32PopcntOp
}

///|
pub fn i64_clz_op() -> UnaryOp {
  I64ClzOp
}

///|
pub fn i64_ctz_op() -> UnaryOp {
  I64CtzOp
}

///|
pub fn i64_popcnt_op() -> UnaryOp {
  I64PopcntOp
}

///|
pub fn f32_abs_op() -> UnaryOp {
  F32AbsOp
}

///|
pub fn f32_neg_op() -> UnaryOp {
  F32NegOp
}

///|
pub fn f32_ceil_op() -> UnaryOp {
  F32CeilOp
}

///|
pub fn f32_floor_op() -> UnaryOp {
  F32FloorOp
}

///|
pub fn f32_trunc_op() -> UnaryOp {
  F32TruncOp
}

///|
pub fn f32_nearest_op() -> UnaryOp {
  F32NearestOp
}

///|
pub fn f32_sqrt_op() -> UnaryOp {
  F32SqrtOp
}

///|
pub fn f64_abs_op() -> UnaryOp {
  F64AbsOp
}

///|
pub fn f64_neg_op() -> UnaryOp {
  F64NegOp
}

///|
pub fn f64_ceil_op() -> UnaryOp {
  F64CeilOp
}

///|
pub fn f64_floor_op() -> UnaryOp {
  F64FloorOp
}

///|
pub fn f64_trunc_op() -> UnaryOp {
  F64TruncOp
}

///|
pub fn f64_nearest_op() -> UnaryOp {
  F64NearestOp
}

///|
pub fn f64_sqrt_op() -> UnaryOp {
  F64SqrtOp
}

///|
pub fn i32_wrap_i64_op() -> UnaryOp {
  I32WrapI64Op
}

///|
pub fn i32_trunc_f32s_op() -> UnaryOp {
  I32TruncF32SOp
}

///|
pub fn i32_trunc_f32u_op() -> UnaryOp {
  I32TruncF32UOp
}

///|
pub fn i32_trunc_f64s_op() -> UnaryOp {
  I32TruncF64SOp
}

///|
pub fn i32_trunc_f64u_op() -> UnaryOp {
  I32TruncF64UOp
}

///|
pub fn i64_extend_i32s_op() -> UnaryOp {
  I64ExtendI32SOp
}

///|
pub fn i64_extend_i32u_op() -> UnaryOp {
  I64ExtendI32UOp
}

///|
pub fn i64_trunc_f32s_op() -> UnaryOp {
  I64TruncF32SOp
}

///|
pub fn i64_trunc_f32u_op() -> UnaryOp {
  I64TruncF32UOp
}

///|
pub fn i64_trunc_f64s_op() -> UnaryOp {
  I64TruncF64SOp
}

///|
pub fn i64_trunc_f64u_op() -> UnaryOp {
  I64TruncF64UOp
}

///|
pub fn f32_convert_i32s_op() -> UnaryOp {
  F32ConvertI32SOp
}

///|
pub fn f32_convert_i32u_op() -> UnaryOp {
  F32ConvertI32UOp
}

///|
pub fn f32_convert_i64s_op() -> UnaryOp {
  F32ConvertI64SOp
}

///|
pub fn f32_convert_i64u_op() -> UnaryOp {
  F32ConvertI64UOp
}

///|
pub fn f32_demote_f64_op() -> UnaryOp {
  F32DemoteF64Op
}

///|
pub fn f64_convert_i32s_op() -> UnaryOp {
  F64ConvertI32SOp
}

///|
pub fn f64_convert_i32u_op() -> UnaryOp {
  F64ConvertI32UOp
}

///|
pub fn f64_convert_i64s_op() -> UnaryOp {
  F64ConvertI64SOp
}

///|
pub fn f64_convert_i64u_op() -> UnaryOp {
  F64ConvertI64UOp
}

///|
pub fn f64_promote_f32_op() -> UnaryOp {
  F64PromoteF32Op
}

///|
pub fn i32_reinterpret_f32_op() -> UnaryOp {
  I32ReinterpretF32Op
}

///|
pub fn i64_reinterpret_f64_op() -> UnaryOp {
  I64ReinterpretF64Op
}

///|
pub fn f32_reinterpret_i32_op() -> UnaryOp {
  F32ReinterpretI32Op
}

///|
pub fn f64_reinterpret_i64_op() -> UnaryOp {
  F64ReinterpretI64Op
}

///|
pub fn i32_extend8s_op() -> UnaryOp {
  I32Extend8SOp
}

///|
pub fn i32_extend16s_op() -> UnaryOp {
  I32Extend16SOp
}

///|
pub fn i64_extend8s_op() -> UnaryOp {
  I64Extend8SOp
}

///|
pub fn i64_extend16s_op() -> UnaryOp {
  I64Extend16SOp
}

///|
pub fn i64_extend32s_op() -> UnaryOp {
  I64Extend32SOp
}

///|
pub fn i32_trunc_sat_f32s_op() -> UnaryOp {
  I32TruncSatF32SOp
}

///|
pub fn i32_trunc_sat_f32u_op() -> UnaryOp {
  I32TruncSatF32UOp
}

///|
pub fn i32_trunc_sat_f64s_op() -> UnaryOp {
  I32TruncSatF64SOp
}

///|
pub fn i32_trunc_sat_f64u_op() -> UnaryOp {
  I32TruncSatF64UOp
}

///|
pub fn i64_trunc_sat_f32s_op() -> UnaryOp {
  I64TruncSatF32SOp
}

///|
pub fn i64_trunc_sat_f32u_op() -> UnaryOp {
  I64TruncSatF32UOp
}

///|
pub fn i64_trunc_sat_f64s_op() -> UnaryOp {
  I64TruncSatF64SOp
}

///|
pub fn i64_trunc_sat_f64u_op() -> UnaryOp {
  I64TruncSatF64UOp
}

///|
pub fn v128_not_op() -> UnaryOp {
  V128NotOp
}

///|
pub fn i8x16_abs_op() -> UnaryOp {
  I8x16AbsOp
}

///|
pub fn i8x16_neg_op() -> UnaryOp {
  I8x16NegOp
}

///|
pub fn i8x16_popcnt_op() -> UnaryOp {
  I8x16PopcntOp
}

///|
pub fn i16x8_abs_op() -> UnaryOp {
  I16x8AbsOp
}

///|
pub fn i16x8_neg_op() -> UnaryOp {
  I16x8NegOp
}

///|
pub fn i32x4_abs_op() -> UnaryOp {
  I32x4AbsOp
}

///|
pub fn i32x4_neg_op() -> UnaryOp {
  I32x4NegOp
}

///|
pub fn i64x2_abs_op() -> UnaryOp {
  I64x2AbsOp
}

///|
pub fn i64x2_neg_op() -> UnaryOp {
  I64x2NegOp
}

///|
pub fn f32x4_abs_op() -> UnaryOp {
  F32x4AbsOp
}

///|
pub fn f32x4_neg_op() -> UnaryOp {
  F32x4NegOp
}

///|
pub fn f32x4_sqrt_op() -> UnaryOp {
  F32x4SqrtOp
}

///|
pub fn f32x4_ceil_op() -> UnaryOp {
  F32x4CeilOp
}

///|
pub fn f32x4_floor_op() -> UnaryOp {
  F32x4FloorOp
}

///|
pub fn f32x4_trunc_op() -> UnaryOp {
  F32x4TruncOp
}

///|
pub fn f32x4_nearest_op() -> UnaryOp {
  F32x4NearestOp
}

///|
pub fn f64x2_abs_op() -> UnaryOp {
  F64x2AbsOp
}

///|
pub fn f64x2_neg_op() -> UnaryOp {
  F64x2NegOp
}

///|
pub fn f64x2_sqrt_op() -> UnaryOp {
  F64x2SqrtOp
}

///|
pub fn f64x2_ceil_op() -> UnaryOp {
  F64x2CeilOp
}

///|
pub fn f64x2_floor_op() -> UnaryOp {
  F64x2FloorOp
}

///|
pub fn f64x2_trunc_op() -> UnaryOp {
  F64x2TruncOp
}

///|
pub fn f64x2_nearest_op() -> UnaryOp {
  F64x2NearestOp
}

///|
pub fn v128_any_true_op() -> UnaryOp {
  V128AnyTrueOp
}

///|
pub fn i8x16_all_true_op() -> UnaryOp {
  I8x16AllTrueOp
}

///|
pub fn i8x16_bitmask_op() -> UnaryOp {
  I8x16BitmaskOp
}

///|
pub fn i16x8_all_true_op() -> UnaryOp {
  I16x8AllTrueOp
}

///|
pub fn i16x8_bitmask_op() -> UnaryOp {
  I16x8BitmaskOp
}

///|
pub fn i32x4_all_true_op() -> UnaryOp {
  I32x4AllTrueOp
}

///|
pub fn i32x4_bitmask_op() -> UnaryOp {
  I32x4BitmaskOp
}

///|
pub fn i64x2_all_true_op() -> UnaryOp {
  I64x2AllTrueOp
}

///|
pub fn i64x2_bitmask_op() -> UnaryOp {
  I64x2BitmaskOp
}

///|
pub fn i16x8_extend_low_i8x16s_op() -> UnaryOp {
  I16x8ExtendLowI8x16SOp
}

///|
pub fn i16x8_extend_high_i8x16s_op() -> UnaryOp {
  I16x8ExtendHighI8x16SOp
}

///|
pub fn i16x8_extend_low_i8x16u_op() -> UnaryOp {
  I16x8ExtendLowI8x16UOp
}

///|
pub fn i16x8_extend_high_i8x16u_op() -> UnaryOp {
  I16x8ExtendHighI8x16UOp
}

///|
pub fn i32x4_extend_low_i16x8s_op() -> UnaryOp {
  I32x4ExtendLowI16x8SOp
}

///|
pub fn i32x4_extend_high_i16x8s_op() -> UnaryOp {
  I32x4ExtendHighI16x8SOp
}

///|
pub fn i32x4_extend_low_i16x8u_op() -> UnaryOp {
  I32x4ExtendLowI16x8UOp
}

///|
pub fn i32x4_extend_high_i16x8u_op() -> UnaryOp {
  I32x4ExtendHighI16x8UOp
}

///|
pub fn i64x2_extend_low_i32x4s_op() -> UnaryOp {
  I64x2ExtendLowI32x4SOp
}

///|
pub fn i64x2_extend_high_i32x4s_op() -> UnaryOp {
  I64x2ExtendHighI32x4SOp
}

///|
pub fn i64x2_extend_low_i32x4u_op() -> UnaryOp {
  I64x2ExtendLowI32x4UOp
}

///|
pub fn i64x2_extend_high_i32x4u_op() -> UnaryOp {
  I64x2ExtendHighI32x4UOp
}

///|
pub fn i16x8_extadd_pairwise_i8x16s_op() -> UnaryOp {
  I16x8ExtaddPairwiseI8x16SOp
}

///|
pub fn i16x8_extadd_pairwise_i8x16u_op() -> UnaryOp {
  I16x8ExtaddPairwiseI8x16UOp
}

///|
pub fn i32x4_extadd_pairwise_i16x8s_op() -> UnaryOp {
  I32x4ExtaddPairwiseI16x8SOp
}

///|
pub fn i32x4_extadd_pairwise_i16x8u_op() -> UnaryOp {
  I32x4ExtaddPairwiseI16x8UOp
}

///|
pub fn f32x4_demote_f64x2_zero_op() -> UnaryOp {
  F32x4DemoteF64x2ZeroOp
}

///|
pub fn f64x2_promote_low_f32x4_op() -> UnaryOp {
  F64x2PromoteLowF32x4Op
}

///|
pub fn i32x4_trunc_sat_f32x4s_op() -> UnaryOp {
  I32x4TruncSatF32x4SOp
}

///|
pub fn i32x4_trunc_sat_f32x4u_op() -> UnaryOp {
  I32x4TruncSatF32x4UOp
}

///|
pub fn f32x4_convert_i32x4s_op() -> UnaryOp {
  F32x4ConvertI32x4SOp
}

///|
pub fn f32x4_convert_i32x4u_op() -> UnaryOp {
  F32x4ConvertI32x4UOp
}

///|
pub fn i32x4_trunc_sat_f64x2s_zero_op() -> UnaryOp {
  I32x4TruncSatF64x2SZeroOp
}

///|
pub fn i32x4_trunc_sat_f64x2u_zero_op() -> UnaryOp {
  I32x4TruncSatF64x2UZeroOp
}

///|
pub fn f64x2_convert_low_i32x4s_op() -> UnaryOp {
  F64x2ConvertLowI32x4SOp
}

///|
pub fn f64x2_convert_low_i32x4u_op() -> UnaryOp {
  F64x2ConvertLowI32x4UOp
}

///|
pub fn i32x4_relaxed_trunc_f32x4s_op() -> UnaryOp {
  I32x4RelaxedTruncF32x4SOp
}

///|
pub fn i32x4_relaxed_trunc_f32x4u_op() -> UnaryOp {
  I32x4RelaxedTruncF32x4UOp
}

///|
pub fn i32x4_relaxed_trunc_zero_f64x2s_op() -> UnaryOp {
  I32x4RelaxedTruncZeroF64x2SOp
}

///|
pub fn i32x4_relaxed_trunc_zero_f64x2u_op() -> UnaryOp {
  I32x4RelaxedTruncZeroF64x2UOp
}

///|
pub fn i32_eq_op() -> BinaryOp {
  I32EqOp
}

///|
pub fn i32_ne_op() -> BinaryOp {
  I32NeOp
}

///|
pub fn i32_lt_s_op() -> BinaryOp {
  I32LtSOp
}

///|
pub fn i32_lt_u_op() -> BinaryOp {
  I32LtUOp
}

///|
pub fn i32_gt_s_op() -> BinaryOp {
  I32GtSOp
}

///|
pub fn i32_gt_u_op() -> BinaryOp {
  I32GtUOp
}

///|
pub fn i32_le_s_op() -> BinaryOp {
  I32LeSOp
}

///|
pub fn i32_le_u_op() -> BinaryOp {
  I32LeUOp
}

///|
pub fn i32_ge_s_op() -> BinaryOp {
  I32GeSOp
}

///|
pub fn i32_ge_u_op() -> BinaryOp {
  I32GeUOp
}

///|
pub fn i64_eq_op() -> BinaryOp {
  I64EqOp
}

///|
pub fn i64_ne_op() -> BinaryOp {
  I64NeOp
}

///|
pub fn i64_lt_s_op() -> BinaryOp {
  I64LtSOp
}

///|
pub fn i64_lt_u_op() -> BinaryOp {
  I64LtUOp
}

///|
pub fn i64_gt_s_op() -> BinaryOp {
  I64GtSOp
}

///|
pub fn i64_gt_u_op() -> BinaryOp {
  I64GtUOp
}

///|
pub fn i64_le_s_op() -> BinaryOp {
  I64LeSOp
}

///|
pub fn i64_le_u_op() -> BinaryOp {
  I64LeUOp
}

///|
pub fn i64_ge_s_op() -> BinaryOp {
  I64GeSOp
}

///|
pub fn i64_ge_u_op() -> BinaryOp {
  I64GeUOp
}

///|
pub fn f32_eq_op() -> BinaryOp {
  F32EqOp
}

///|
pub fn f32_ne_op() -> BinaryOp {
  F32NeOp
}

///|
pub fn f32_lt_op() -> BinaryOp {
  F32LtOp
}

///|
pub fn f32_gt_op() -> BinaryOp {
  F32GtOp
}

///|
pub fn f32_le_op() -> BinaryOp {
  F32LeOp
}

///|
pub fn f32_ge_op() -> BinaryOp {
  F32GeOp
}

///|
pub fn f64_eq_op() -> BinaryOp {
  F64EqOp
}

///|
pub fn f64_ne_op() -> BinaryOp {
  F64NeOp
}

///|
pub fn f64_lt_op() -> BinaryOp {
  F64LtOp
}

///|
pub fn f64_gt_op() -> BinaryOp {
  F64GtOp
}

///|
pub fn f64_le_op() -> BinaryOp {
  F64LeOp
}

///|
pub fn f64_ge_op() -> BinaryOp {
  F64GeOp
}

///|
pub fn i32_add_op() -> BinaryOp {
  I32AddOp
}

///|
pub fn i32_sub_op() -> BinaryOp {
  I32SubOp
}

///|
pub fn i32_mul_op() -> BinaryOp {
  I32MulOp
}

///|
pub fn i32_div_s_op() -> BinaryOp {
  I32DivSOp
}

///|
pub fn i32_div_u_op() -> BinaryOp {
  I32DivUOp
}

///|
pub fn i32_rem_s_op() -> BinaryOp {
  I32RemSOp
}

///|
pub fn i32_rem_u_op() -> BinaryOp {
  I32RemUOp
}

///|
pub fn i32_and_op() -> BinaryOp {
  I32AndOp
}

///|
pub fn i32_or_op() -> BinaryOp {
  I32OrOp
}

///|
pub fn i32_xor_op() -> BinaryOp {
  I32XorOp
}

///|
pub fn i32_shl_op() -> BinaryOp {
  I32ShlOp
}

///|
pub fn i32_shr_s_op() -> BinaryOp {
  I32ShrSOp
}

///|
pub fn i32_shr_u_op() -> BinaryOp {
  I32ShrUOp
}

///|
pub fn i32_rotl_op() -> BinaryOp {
  I32RotlOp
}

///|
pub fn i32_rotr_op() -> BinaryOp {
  I32RotrOp
}

///|
pub fn i64_add_op() -> BinaryOp {
  I64AddOp
}

///|
pub fn i64_sub_op() -> BinaryOp {
  I64SubOp
}

///|
pub fn i64_mul_op() -> BinaryOp {
  I64MulOp
}

///|
pub fn i64_div_s_op() -> BinaryOp {
  I64DivSOp
}

///|
pub fn i64_div_u_op() -> BinaryOp {
  I64DivUOp
}

///|
pub fn i64_rem_s_op() -> BinaryOp {
  I64RemSOp
}

///|
pub fn i64_rem_u_op() -> BinaryOp {
  I64RemUOp
}

///|
pub fn i64_and_op() -> BinaryOp {
  I64AndOp
}

///|
pub fn i64_or_op() -> BinaryOp {
  I64OrOp
}

///|
pub fn i64_xor_op() -> BinaryOp {
  I64XorOp
}

///|
pub fn i64_shl_op() -> BinaryOp {
  I64ShlOp
}

///|
pub fn i64_shr_s_op() -> BinaryOp {
  I64ShrSOp
}

///|
pub fn i64_shr_u_op() -> BinaryOp {
  I64ShrUOp
}

///|
pub fn i64_rotl_op() -> BinaryOp {
  I64RotlOp
}

///|
pub fn i64_rotr_op() -> BinaryOp {
  I64RotrOp
}

///|
pub fn f32_add_op() -> BinaryOp {
  F32AddOp
}

///|
pub fn f32_sub_op() -> BinaryOp {
  F32SubOp
}

///|
pub fn f32_mul_op() -> BinaryOp {
  F32MulOp
}

///|
pub fn f32_div_op() -> BinaryOp {
  F32DivOp
}

///|
pub fn f32_min_op() -> BinaryOp {
  F32MinOp
}

///|
pub fn f32_max_op() -> BinaryOp {
  F32MaxOp
}

///|
pub fn f32_copysign_op() -> BinaryOp {
  F32CopysignOp
}

///|
pub fn f64_add_op() -> BinaryOp {
  F64AddOp
}

///|
pub fn f64_sub_op() -> BinaryOp {
  F64SubOp
}

///|
pub fn f64_mul_op() -> BinaryOp {
  F64MulOp
}

///|
pub fn f64_div_op() -> BinaryOp {
  F64DivOp
}

///|
pub fn f64_min_op() -> BinaryOp {
  F64MinOp
}

///|
pub fn f64_max_op() -> BinaryOp {
  F64MaxOp
}

///|
pub fn f64_copysign_op() -> BinaryOp {
  F64CopysignOp
}

///|
pub fn v128_and_op() -> BinaryOp {
  V128AndOp
}

///|
pub fn v128_andnot_op() -> BinaryOp {
  V128AndnotOp
}

///|
pub fn v128_or_op() -> BinaryOp {
  V128OrOp
}

///|
pub fn v128_xor_op() -> BinaryOp {
  V128XorOp
}

///|
pub fn i8x16_eq_op() -> BinaryOp {
  I8x16EqOp
}

///|
pub fn i8x16_ne_op() -> BinaryOp {
  I8x16NeOp
}

///|
pub fn i8x16_lt_s_op() -> BinaryOp {
  I8x16LtSOp
}

///|
pub fn i8x16_lt_u_op() -> BinaryOp {
  I8x16LtUOp
}

///|
pub fn i8x16_gt_s_op() -> BinaryOp {
  I8x16GtSOp
}

///|
pub fn i8x16_gt_u_op() -> BinaryOp {
  I8x16GtUOp
}

///|
pub fn i8x16_le_s_op() -> BinaryOp {
  I8x16LeSOp
}

///|
pub fn i8x16_le_u_op() -> BinaryOp {
  I8x16LeUOp
}

///|
pub fn i8x16_ge_s_op() -> BinaryOp {
  I8x16GeSOp
}

///|
pub fn i8x16_ge_u_op() -> BinaryOp {
  I8x16GeUOp
}

///|
pub fn i16x8_eq_op() -> BinaryOp {
  I16x8EqOp
}

///|
pub fn i16x8_ne_op() -> BinaryOp {
  I16x8NeOp
}

///|
pub fn i16x8_lt_s_op() -> BinaryOp {
  I16x8LtSOp
}

///|
pub fn i16x8_lt_u_op() -> BinaryOp {
  I16x8LtUOp
}

///|
pub fn i16x8_gt_s_op() -> BinaryOp {
  I16x8GtSOp
}

///|
pub fn i16x8_gt_u_op() -> BinaryOp {
  I16x8GtUOp
}

///|
pub fn i16x8_le_s_op() -> BinaryOp {
  I16x8LeSOp
}

///|
pub fn i16x8_le_u_op() -> BinaryOp {
  I16x8LeUOp
}

///|
pub fn i16x8_ge_s_op() -> BinaryOp {
  I16x8GeSOp
}

///|
pub fn i16x8_ge_u_op() -> BinaryOp {
  I16x8GeUOp
}

///|
pub fn i32x4_eq_op() -> BinaryOp {
  I32x4EqOp
}

///|
pub fn i32x4_ne_op() -> BinaryOp {
  I32x4NeOp
}

///|
pub fn i32x4_lt_s_op() -> BinaryOp {
  I32x4LtSOp
}

///|
pub fn i32x4_lt_u_op() -> BinaryOp {
  I32x4LtUOp
}

///|
pub fn i32x4_gt_s_op() -> BinaryOp {
  I32x4GtSOp
}

///|
pub fn i32x4_gt_u_op() -> BinaryOp {
  I32x4GtUOp
}

///|
pub fn i32x4_le_s_op() -> BinaryOp {
  I32x4LeSOp
}

///|
pub fn i32x4_le_u_op() -> BinaryOp {
  I32x4LeUOp
}

///|
pub fn i32x4_ge_s_op() -> BinaryOp {
  I32x4GeSOp
}

///|
pub fn i32x4_ge_u_op() -> BinaryOp {
  I32x4GeUOp
}

///|
pub fn i64x2_eq_op() -> BinaryOp {
  I64x2EqOp
}

///|
pub fn i64x2_ne_op() -> BinaryOp {
  I64x2NeOp
}

///|
pub fn i64x2_lt_s_op() -> BinaryOp {
  I64x2LtSOp
}

///|
pub fn i64x2_gt_s_op() -> BinaryOp {
  I64x2GtSOp
}

///|
pub fn i64x2_le_s_op() -> BinaryOp {
  I64x2LeSOp
}

///|
pub fn i64x2_ge_s_op() -> BinaryOp {
  I64x2GeSOp
}

///|
pub fn f32x4_eq_op() -> BinaryOp {
  F32x4EqOp
}

///|
pub fn f32x4_ne_op() -> BinaryOp {
  F32x4NeOp
}

///|
pub fn f32x4_lt_op() -> BinaryOp {
  F32x4LtOp
}

///|
pub fn f32x4_gt_op() -> BinaryOp {
  F32x4GtOp
}

///|
pub fn f32x4_le_op() -> BinaryOp {
  F32x4LeOp
}

///|
pub fn f32x4_ge_op() -> BinaryOp {
  F32x4GeOp
}

///|
pub fn f64x2_eq_op() -> BinaryOp {
  F64x2EqOp
}

///|
pub fn f64x2_ne_op() -> BinaryOp {
  F64x2NeOp
}

///|
pub fn f64x2_lt_op() -> BinaryOp {
  F64x2LtOp
}

///|
pub fn f64x2_gt_op() -> BinaryOp {
  F64x2GtOp
}

///|
pub fn f64x2_le_op() -> BinaryOp {
  F64x2LeOp
}

///|
pub fn f64x2_ge_op() -> BinaryOp {
  F64x2GeOp
}

///|
pub fn i8x16_add_op() -> BinaryOp {
  I8x16AddOp
}

///|
pub fn i8x16_add_sat_s_op() -> BinaryOp {
  I8x16AddSatSOp
}

///|
pub fn i8x16_add_sat_u_op() -> BinaryOp {
  I8x16AddSatUOp
}

///|
pub fn i8x16_sub_op() -> BinaryOp {
  I8x16SubOp
}

///|
pub fn i8x16_sub_sat_s_op() -> BinaryOp {
  I8x16SubSatSOp
}

///|
pub fn i8x16_sub_sat_u_op() -> BinaryOp {
  I8x16SubSatUOp
}

///|
pub fn i8x16_min_s_op() -> BinaryOp {
  I8x16MinSOp
}

///|
pub fn i8x16_min_u_op() -> BinaryOp {
  I8x16MinUOp
}

///|
pub fn i8x16_max_s_op() -> BinaryOp {
  I8x16MaxSOp
}

///|
pub fn i8x16_max_u_op() -> BinaryOp {
  I8x16MaxUOp
}

///|
pub fn i8x16_avgr_u_op() -> BinaryOp {
  I8x16AvgrUOp
}

///|
pub fn i8x16_narrow_i16x8s_op() -> BinaryOp {
  I8x16NarrowI16x8SOp
}

///|
pub fn i8x16_narrow_i16x8u_op() -> BinaryOp {
  I8x16NarrowI16x8UOp
}

///|
pub fn i16x8_add_op() -> BinaryOp {
  I16x8AddOp
}

///|
pub fn i16x8_add_sat_s_op() -> BinaryOp {
  I16x8AddSatSOp
}

///|
pub fn i16x8_add_sat_u_op() -> BinaryOp {
  I16x8AddSatUOp
}

///|
pub fn i16x8_sub_op() -> BinaryOp {
  I16x8SubOp
}

///|
pub fn i16x8_sub_sat_s_op() -> BinaryOp {
  I16x8SubSatSOp
}

///|
pub fn i16x8_sub_sat_u_op() -> BinaryOp {
  I16x8SubSatUOp
}

///|
pub fn i16x8_mul_op() -> BinaryOp {
  I16x8MulOp
}

///|
pub fn i16x8_min_s_op() -> BinaryOp {
  I16x8MinSOp
}

///|
pub fn i16x8_min_u_op() -> BinaryOp {
  I16x8MinUOp
}

///|
pub fn i16x8_max_s_op() -> BinaryOp {
  I16x8MaxSOp
}

///|
pub fn i16x8_max_u_op() -> BinaryOp {
  I16x8MaxUOp
}

///|
pub fn i16x8_avgr_u_op() -> BinaryOp {
  I16x8AvgrUOp
}

///|
pub fn i16x8q15mulr_sat_s_op() -> BinaryOp {
  I16x8Q15mulrSatSOp
}

///|
pub fn i16x8_narrow_i32x4s_op() -> BinaryOp {
  I16x8NarrowI32x4SOp
}

///|
pub fn i16x8_narrow_i32x4u_op() -> BinaryOp {
  I16x8NarrowI32x4UOp
}

///|
pub fn i16x8_extmul_low_i8x16s_op() -> BinaryOp {
  I16x8ExtmulLowI8x16SOp
}

///|
pub fn i16x8_extmul_high_i8x16s_op() -> BinaryOp {
  I16x8ExtmulHighI8x16SOp
}

///|
pub fn i16x8_extmul_low_i8x16u_op() -> BinaryOp {
  I16x8ExtmulLowI8x16UOp
}

///|
pub fn i16x8_extmul_high_i8x16u_op() -> BinaryOp {
  I16x8ExtmulHighI8x16UOp
}

///|
pub fn i32x4_add_op() -> BinaryOp {
  I32x4AddOp
}

///|
pub fn i32x4_sub_op() -> BinaryOp {
  I32x4SubOp
}

///|
pub fn i32x4_mul_op() -> BinaryOp {
  I32x4MulOp
}

///|
pub fn i32x4_min_s_op() -> BinaryOp {
  I32x4MinSOp
}

///|
pub fn i32x4_min_u_op() -> BinaryOp {
  I32x4MinUOp
}

///|
pub fn i32x4_max_s_op() -> BinaryOp {
  I32x4MaxSOp
}

///|
pub fn i32x4_max_u_op() -> BinaryOp {
  I32x4MaxUOp
}

///|
pub fn i32x4_dot_i16x8s_op() -> BinaryOp {
  I32x4DotI16x8SOp
}

///|
pub fn i32x4_extmul_low_i16x8s_op() -> BinaryOp {
  I32x4ExtmulLowI16x8SOp
}

///|
pub fn i32x4_extmul_high_i16x8s_op() -> BinaryOp {
  I32x4ExtmulHighI16x8SOp
}

///|
pub fn i32x4_extmul_low_i16x8u_op() -> BinaryOp {
  I32x4ExtmulLowI16x8UOp
}

///|
pub fn i32x4_extmul_high_i16x8u_op() -> BinaryOp {
  I32x4ExtmulHighI16x8UOp
}

///|
pub fn i64x2_add_op() -> BinaryOp {
  I64x2AddOp
}

///|
pub fn i64x2_sub_op() -> BinaryOp {
  I64x2SubOp
}

///|
pub fn i64x2_mul_op() -> BinaryOp {
  I64x2MulOp
}

///|
pub fn i64x2_extmul_low_i32x4s_op() -> BinaryOp {
  I64x2ExtmulLowI32x4SOp
}

///|
pub fn i64x2_extmul_high_i32x4s_op() -> BinaryOp {
  I64x2ExtmulHighI32x4SOp
}

///|
pub fn i64x2_extmul_low_i32x4u_op() -> BinaryOp {
  I64x2ExtmulLowI32x4UOp
}

///|
pub fn i64x2_extmul_high_i32x4u_op() -> BinaryOp {
  I64x2ExtmulHighI32x4UOp
}

///|
pub fn f32x4_add_op() -> BinaryOp {
  F32x4AddOp
}

///|
pub fn f32x4_sub_op() -> BinaryOp {
  F32x4SubOp
}

///|
pub fn f32x4_mul_op() -> BinaryOp {
  F32x4MulOp
}

///|
pub fn f32x4_div_op() -> BinaryOp {
  F32x4DivOp
}

///|
pub fn f32x4_min_op() -> BinaryOp {
  F32x4MinOp
}

///|
pub fn f32x4_max_op() -> BinaryOp {
  F32x4MaxOp
}

///|
pub fn f32x4_pmin_op() -> BinaryOp {
  F32x4PminOp
}

///|
pub fn f32x4_pmax_op() -> BinaryOp {
  F32x4PmaxOp
}

///|
pub fn f64x2_add_op() -> BinaryOp {
  F64x2AddOp
}

///|
pub fn f64x2_sub_op() -> BinaryOp {
  F64x2SubOp
}

///|
pub fn f64x2_mul_op() -> BinaryOp {
  F64x2MulOp
}

///|
pub fn f64x2_div_op() -> BinaryOp {
  F64x2DivOp
}

///|
pub fn f64x2_min_op() -> BinaryOp {
  F64x2MinOp
}

///|
pub fn f64x2_max_op() -> BinaryOp {
  F64x2MaxOp
}

///|
pub fn f64x2_pmin_op() -> BinaryOp {
  F64x2PminOp
}

///|
pub fn f64x2_pmax_op() -> BinaryOp {
  F64x2PmaxOp
}

///|
pub fn f32x4_relaxed_min_op() -> BinaryOp {
  F32x4RelaxedMinOp
}

///|
pub fn f32x4_relaxed_max_op() -> BinaryOp {
  F32x4RelaxedMaxOp
}

///|
pub fn f64x2_relaxed_min_op() -> BinaryOp {
  F64x2RelaxedMinOp
}

///|
pub fn f64x2_relaxed_max_op() -> BinaryOp {
  F64x2RelaxedMaxOp
}

///|
pub fn i16x8_relaxed_q15mulr_s_op() -> BinaryOp {
  I16x8RelaxedQ15mulrSOp
}

///|
pub fn i16x8_relaxed_dot_i8x16i7x16s_op() -> BinaryOp {
  I16x8RelaxedDotI8x16I7x16SOp
}

///|
pub fn i32_load_op() -> LoadOp {
  I32LoadOp
}

///|
pub fn i64_load_op() -> LoadOp {
  I64LoadOp
}

///|
pub fn f32_load_op() -> LoadOp {
  F32LoadOp
}

///|
pub fn f64_load_op() -> LoadOp {
  F64LoadOp
}

///|
pub fn i32_load8s_op() -> LoadOp {
  I32Load8SOp
}

///|
pub fn i32_load8u_op() -> LoadOp {
  I32Load8UOp
}

///|
pub fn i32_load16s_op() -> LoadOp {
  I32Load16SOp
}

///|
pub fn i32_load16u_op() -> LoadOp {
  I32Load16UOp
}

///|
pub fn i64_load8s_op() -> LoadOp {
  I64Load8SOp
}

///|
pub fn i64_load8u_op() -> LoadOp {
  I64Load8UOp
}

///|
pub fn i64_load16s_op() -> LoadOp {
  I64Load16SOp
}

///|
pub fn i64_load16u_op() -> LoadOp {
  I64Load16UOp
}

///|
pub fn i64_load32s_op() -> LoadOp {
  I64Load32SOp
}

///|
pub fn i64_load32u_op() -> LoadOp {
  I64Load32UOp
}

///|
pub fn v128_load_op() -> LoadOp {
  V128LoadOp
}

///|
pub fn v128_load8x8s_op() -> LoadOp {
  V128Load8x8SOp
}

///|
pub fn v128_load8x8u_op() -> LoadOp {
  V128Load8x8UOp
}

///|
pub fn v128_load16x4s_op() -> LoadOp {
  V128Load16x4SOp
}

///|
pub fn v128_load16x4u_op() -> LoadOp {
  V128Load16x4UOp
}

///|
pub fn v128_load32x2s_op() -> LoadOp {
  V128Load32x2SOp
}

///|
pub fn v128_load32x2u_op() -> LoadOp {
  V128Load32x2UOp
}

///|
pub fn v128_load8_splat_op() -> LoadOp {
  V128Load8SplatOp
}

///|
pub fn v128_load16_splat_op() -> LoadOp {
  V128Load16SplatOp
}

///|
pub fn v128_load32_splat_op() -> LoadOp {
  V128Load32SplatOp
}

///|
pub fn v128_load64_splat_op() -> LoadOp {
  V128Load64SplatOp
}

///|
pub fn v128_load32_zero_op() -> LoadOp {
  V128Load32ZeroOp
}

///|
pub fn v128_load64_zero_op() -> LoadOp {
  V128Load64ZeroOp
}

///|
pub fn i32_store_op() -> StoreOp {
  I32StoreOp
}

///|
pub fn i64_store_op() -> StoreOp {
  I64StoreOp
}

///|
pub fn f32_store_op() -> StoreOp {
  F32StoreOp
}

///|
pub fn f64_store_op() -> StoreOp {
  F64StoreOp
}

///|
pub fn i32_store8_op() -> StoreOp {
  I32Store8Op
}

///|
pub fn i32_store16_op() -> StoreOp {
  I32Store16Op
}

///|
pub fn i64_store8_op() -> StoreOp {
  I64Store8Op
}

///|
pub fn i64_store16_op() -> StoreOp {
  I64Store16Op
}

///|
pub fn i64_store32_op() -> StoreOp {
  I64Store32Op
}

///|
pub fn v128_store_op() -> StoreOp {
  V128StoreOp
}

///|
pub fn i8x16_extract_lane_s_op() -> ExtractLaneOp {
  I8x16ExtractLaneSOp
}

///|
pub fn i8x16_extract_lane_u_op() -> ExtractLaneOp {
  I8x16ExtractLaneUOp
}

///|
pub fn i16x8_extract_lane_s_op() -> ExtractLaneOp {
  I16x8ExtractLaneSOp
}

///|
pub fn i16x8_extract_lane_u_op() -> ExtractLaneOp {
  I16x8ExtractLaneUOp
}

///|
pub fn i32x4_extract_lane_op() -> ExtractLaneOp {
  I32x4ExtractLaneOp
}

///|
pub fn i64x2_extract_lane_op() -> ExtractLaneOp {
  I64x2ExtractLaneOp
}

///|
pub fn f32x4_extract_lane_op() -> ExtractLaneOp {
  F32x4ExtractLaneOp
}

///|
pub fn f64x2_extract_lane_op() -> ExtractLaneOp {
  F64x2ExtractLaneOp
}

///|
pub fn i8x16_replace_lane_op() -> ReplaceLaneOp {
  I8x16ReplaceLaneOp
}

///|
pub fn i16x8_replace_lane_op() -> ReplaceLaneOp {
  I16x8ReplaceLaneOp
}

///|
pub fn i32x4_replace_lane_op() -> ReplaceLaneOp {
  I32x4ReplaceLaneOp
}

///|
pub fn i64x2_replace_lane_op() -> ReplaceLaneOp {
  I64x2ReplaceLaneOp
}

///|
pub fn f32x4_replace_lane_op() -> ReplaceLaneOp {
  F32x4ReplaceLaneOp
}

///|
pub fn f64x2_replace_lane_op() -> ReplaceLaneOp {
  F64x2ReplaceLaneOp
}

///|
pub fn i8x16_shl_op() -> V128ShiftOp {
  I8x16ShlOp
}

///|
pub fn i8x16_shr_s_op() -> V128ShiftOp {
  I8x16ShrSOp
}

///|
pub fn i8x16_shr_u_op() -> V128ShiftOp {
  I8x16ShrUOp
}

///|
pub fn i16x8_shl_op() -> V128ShiftOp {
  I16x8ShlOp
}

///|
pub fn i16x8_shr_s_op() -> V128ShiftOp {
  I16x8ShrSOp
}

///|
pub fn i16x8_shr_u_op() -> V128ShiftOp {
  I16x8ShrUOp
}

///|
pub fn i32x4_shl_op() -> V128ShiftOp {
  I32x4ShlOp
}

///|
pub fn i32x4_shr_s_op() -> V128ShiftOp {
  I32x4ShrSOp
}

///|
pub fn i32x4_shr_u_op() -> V128ShiftOp {
  I32x4ShrUOp
}

///|
pub fn i64x2_shl_op() -> V128ShiftOp {
  I64x2ShlOp
}

///|
pub fn i64x2_shr_s_op() -> V128ShiftOp {
  I64x2ShrSOp
}

///|
pub fn i64x2_shr_u_op() -> V128ShiftOp {
  I64x2ShrUOp
}

///|
pub fn v128_bitselect_op() -> V128TernaryOp {
  V128BitselectOp
}

///|
pub fn i8x16_relaxed_laneselect_op() -> V128TernaryOp {
  I8x16RelaxedLaneselectOp
}

///|
pub fn i16x8_relaxed_laneselect_op() -> V128TernaryOp {
  I16x8RelaxedLaneselectOp
}

///|
pub fn i32x4_relaxed_laneselect_op() -> V128TernaryOp {
  I32x4RelaxedLaneselectOp
}

///|
pub fn i64x2_relaxed_laneselect_op() -> V128TernaryOp {
  I64x2RelaxedLaneselectOp
}

///|
pub fn f32x4_relaxed_madd_op() -> V128TernaryOp {
  F32x4RelaxedMaddOp
}

///|
pub fn f32x4_relaxed_nmadd_op() -> V128TernaryOp {
  F32x4RelaxedNmaddOp
}

///|
pub fn f64x2_relaxed_madd_op() -> V128TernaryOp {
  F64x2RelaxedMaddOp
}

///|
pub fn f64x2_relaxed_nmadd_op() -> V128TernaryOp {
  F64x2RelaxedNmaddOp
}

///|
pub fn i32x4_relaxed_dot_i8x16i7x16_add_s_op() -> V128TernaryOp {
  I32x4RelaxedDotI8x16I7x16AddSOp
}

///|
pub fn v128_load8_lane_op() -> V128LoadLaneOp {
  V128Load8LaneOp
}

///|
pub fn v128_load16_lane_op() -> V128LoadLaneOp {
  V128Load16LaneOp
}

///|
pub fn v128_load32_lane_op() -> V128LoadLaneOp {
  V128Load32LaneOp
}

///|
pub fn v128_load64_lane_op() -> V128LoadLaneOp {
  V128Load64LaneOp
}

///|
pub fn v128_store8_lane_op() -> V128StoreLaneOp {
  V128Store8LaneOp
}

///|
pub fn v128_store16_lane_op() -> V128StoreLaneOp {
  V128Store16LaneOp
}

///|
pub fn v128_store32_lane_op() -> V128StoreLaneOp {
  V128Store32LaneOp
}

///|
pub fn v128_store64_lane_op() -> V128StoreLaneOp {
  V128Store64LaneOp
}

pub fn def_type(rec : RecType, idx : UInt) -> DefType {
  DefType(rec, idx)
}

pub fn HeapType::is_struct(self : Self) -> Bool {
  match self {
    DefTypeHeapType(def) => {
      match def.project() {
        Some(st) => {
          match st.get_comptype() {
            StructCompType(_) => true
            _ => false
          }
        }
        None => false
      }
    }
    _ => false
  }
}

pub fn HeapType::is_array(self : Self) -> Bool {
  match self {
    DefTypeHeapType(def) => {
      match def.project() {
        Some(st) => {
          match st.get_comptype() {
            ArrayCompType(_) => true
            _ => false
          }
        }
        None => false
      }
    }
    _ => false
  }
}

pub fn HeapType::is_gc_aggregate(self : Self) -> Bool {
  self.is_struct() || self.is_array()
}

pub fn bottom_heap_type() -> HeapType {
  AbsHeapTypeHeapType(NoneAbsHeapType)
}

pub fn cast_op(b0 : Bool, b1 : Bool) -> CastOp {
  CastOp(b0, b1)
}

pub fn type_sec(rts : Array[RecType])-> TypeSec {
  TypeSec(rts)
}

pub fn code_sec(fs : Array[Func]) -> CodeSec {
  CodeSec(fs)
}

pub fn t_expr(instrs : Array[TInstr]) -> TExpr {
  TExpr(instrs)
}

pub fn t_func(args : Array[ValType], expr : TExpr) -> Func {
  TFunc(args, expr)
}