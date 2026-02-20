///|
pub(all) struct S33(UInt) derive(Eq, Hash, Debug)

///|
pub(all) struct I32(Int) derive(Eq, Arbitrary, Hash, Debug)

///|
pub(all) struct I64(Int64) derive(Eq, Arbitrary, Hash, Debug)

///|
pub(all) struct F32(Float) derive(Eq, Arbitrary, Hash, Debug)

///|
pub(all) struct F64(Double) derive(Eq, Arbitrary, Hash, Debug)

///|
pub(all) struct U32(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub(all) struct U64(UInt64) derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum NumType {
  F32NumType
  F64NumType
  I32NumType
  I64NumType
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum AbsHeapType {
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
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum HeapType {
  AbsHeapTypeHeapType(AbsHeapType)
  HeapType(TypeIdx)
  DefTypeHeapType(DefType)
} derive(Eq, Hash, Debug)

///|
pub enum RefType {
  HeapTypeRefType(Bool, HeapType)
  AbsHeapTypeRefType(AbsHeapType)
} derive(Arbitrary, Hash, Debug)

///|
pub enum ValType {
  NumTypeValType(NumType)
  VecTypeValType
  RefTypeValType(RefType)
  BotValType
} derive(Eq, Hash, Debug)

///|
pub type ResultType = Array[ValType]

///|
pub enum PackType {
  I16PackType
  I8PackType
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum StorageType {
  ValTypeStorageType(ValType)
  PackTypeStorageType(PackType)
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct FieldType(StorageType, Mut) derive(Eq, Arbitrary, Hash, Debug)

///|
pub(all) enum Mut {
  Const
  Var
} derive(Arbitrary, Eq, Hash, Debug)

///|
pub enum TypeIdx {
  TypeIdx(UInt)
  RecIdx(UInt)
} derive(Eq, Hash, Debug)

///|
pub struct FuncIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct TableIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct MemIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct GlobalIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct TagIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct ElemIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct DataIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct LocalIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct LabelIdx(UInt) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct LaneIdx(Byte) derive(Eq, Hash, Debug)

///|
pub enum CompType {
  ArrayCompType(FieldType)
  StructCompType(Array[FieldType])
  FuncCompType(ResultType, ResultType)
} derive(Eq, Hash, Debug)

///|
pub enum SubType {
  SubType(Bool, Array[TypeIdx], CompType)
  CompTypeSubType(CompType)
} derive(Eq, Hash, Debug)

///|
pub enum RecType {
  SingleRecType(SubType)
  GroupRecType(Array[SubType])
} derive(Hash, Debug)

///|
pub struct DefType(RecType, UInt) derive(Eq, Hash, Debug)

///|
pub enum Limits {
  I32Limits(UInt, UInt?)
  I64Limits(UInt64, UInt64?)
} derive(Eq, Hash, Debug)

///|
pub struct TagType(TypeIdx) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct GlobalType(ValType, Bool) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct MemType(Limits) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct TableType(RefType, Limits) derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum ExternType {
  FuncExternType(TypeIdx)
  TableExternType(TableType)
  MemExternType(MemType)
  GlobalExternType(GlobalType)
  TagExternType(TagType)
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum ExternIdx {
  FuncExternIdx(FuncIdx)
  TableExternIdx(TableIdx)
  MemExternIdx(MemIdx)
  GlobalExternIdx(GlobalIdx)
  TagExternIdx(TagIdx)
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum ElemMode {
  Passive
  Active(TableIdx, Expr)
  Declarative
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum ElemKind {
  FuncsElemKind(Array[FuncIdx])
  FuncExprsElemKind(Array[Expr])
  TypedExprsElemKind(RefType, Array[Expr])
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct Elem(ElemMode, ElemKind) derive(Eq, Hash, Debug)

///|
pub struct Expr(Array[Instruction]) derive(Eq, Hash, Debug)

///|
pub struct Import(Name, Name, ExternType) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct Table(TableType, Expr?) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct Global(GlobalType, Expr) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct Export(Name, ExternIdx) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct Locals(UInt, ValType) derive(Eq, Hash, Debug)

///|
pub enum DataMode {
  Active(MemIdx, Expr)
  Passive
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct Data(DataMode, Bytes) derive(Eq, Hash, Debug)

///|
pub struct Name(StringView) derive(Eq, Hash, Debug)

///|
pub struct Module {
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
} derive(Hash, Debug)

///|
pub fn Module::new(
  custom_secs? : Array[CustomSec] = [],
  type_sec? : TypeSec? = None,
  import_sec? : ImportSec? = None,
  func_sec? : FuncSec? = None,
  table_sec? : TableSec? = None,
  mem_sec? : MemSec? = None,
  tag_sec? : TagSec? = None,
  global_sec? : GlobalSec? = None,
  export_sec? : ExportSec? = None,
  start_sec? : StartSec? = None,
  elem_sec? : ElemSec? = None,
  data_cnt_sec? : DataCntSec? = None,
  code_sec? : CodeSec? = None,
  data_sec? : DataSec? = None,
) -> Module {
  Module::{
    custom_secs,
    type_sec,
    import_sec,
    func_sec,
    table_sec,
    mem_sec,
    tag_sec,
    global_sec,
    export_sec,
    start_sec,
    elem_sec,
    data_cnt_sec,
    code_sec,
    data_sec,
  }
}

///|
pub struct FuncType(Array[ValType], Array[ValType]) derive(Hash, Eq, Debug)

///|
pub enum Func {
  Func(Array[Locals], Expr)
  TFunc(Array[ValType], TExpr)
} derive(Eq, Hash, Debug)

///|
pub struct CustomSec(Name, Bytes) derive(Eq, Hash, Debug)

///|
pub struct TypeSec(Array[RecType]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct ImportSec(Array[Import]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct FuncSec(Array[TypeIdx]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct TableSec(Array[Table]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct MemSec(Array[MemType]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct GlobalSec(Array[Global]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct ExportSec(Array[Export]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct StartSec(FuncIdx) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct ElemSec(Array[Elem]) derive(Eq, Hash, Debug)

///|
pub struct DataCntSec(U32) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct TagSec(Array[TagType]) derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct MemArg(U32, MemIdx?, U64) derive(Hash, Debug)

///|
pub enum BlockType {
  VoidBlockType
  ValTypeBlockType(ValType)
  TypeIdxBlockType(TypeIdx)
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub enum Catch {
  Catch(TagIdx, LabelIdx)
  CatchRef(TagIdx, LabelIdx)
  CatchAll(LabelIdx)
  CatchAllRef(LabelIdx)
} derive(Eq, Arbitrary, Hash, Debug)

///|
pub struct CodeSec(Array[Func]) derive(Eq, Hash, Debug)

///|
pub struct DataSec(Array[Data]) derive(Eq, Hash, Debug)

///|
pub struct CastOp(Bool, Bool) derive(Eq, Arbitrary, Show, Hash, Debug)

///|
pub enum Instruction {
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
  MemoryAtomicNotify(MemArg)
  MemoryAtomicWait32(MemArg)
  MemoryAtomicWait64(MemArg)
  AtomicFence
  I32AtomicLoad(MemArg)
  I64AtomicLoad(MemArg)
  I32AtomicLoad8U(MemArg)
  I32AtomicLoad16U(MemArg)
  I64AtomicLoad8U(MemArg)
  I64AtomicLoad16U(MemArg)
  I64AtomicLoad32U(MemArg)
  I32AtomicStore(MemArg)
  I64AtomicStore(MemArg)
  I32AtomicStore8(MemArg)
  I32AtomicStore16(MemArg)
  I64AtomicStore8(MemArg)
  I64AtomicStore16(MemArg)
  I64AtomicStore32(MemArg)
  AtomicRmw(AtomicRmwOp, MemArg)
  AtomicCmpxchg(AtomicCmpxchgOp, MemArg)
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
  RefGetDesc
  RefTest(Bool, HeapType)
  RefCast(Bool, HeapType)
  RefTestDesc(Bool, HeapType)
  RefCastDescEq(Bool, HeapType)
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
} derive(Eq, Hash, Debug)

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
pub fn RefType::is_non_nullable(rt : RefType) -> Bool {
  !rt.is_nullable()
}

///|
pub fn RefType::get_heap_type(rt : RefType) -> HeapType {
  match rt {
    HeapTypeRefType(_, ht) => ht
    AbsHeapTypeRefType(ahs) => AbsHeapTypeHeapType(ahs)
  }
}

///|
pub fn RefType::make_nullable(rt : RefType) -> RefType {
  match rt {
    AbsHeapTypeRefType(ahs) => AbsHeapTypeRefType(ahs)
    HeapTypeRefType(_, ht) => HeapTypeRefType(true, ht)
  }
}

///|
pub fn RefType::is_defaultable(rt : RefType) -> Bool {
  rt.is_nullable()
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
pub fn ValType::i32() -> ValType {
  NumTypeValType(I32NumType)
}

///|
pub fn ValType::i64() -> ValType {
  NumTypeValType(I64NumType)
}

///|
pub fn ValType::f32() -> ValType {
  NumTypeValType(F32NumType)
}

///|
pub fn ValType::f64() -> ValType {
  NumTypeValType(F64NumType)
}

///|
pub fn ValType::v128() -> ValType {
  VecTypeValType
}

///|
pub fn ValType::num_type(t : NumType) -> ValType {
  NumTypeValType(t)
}

///|
pub fn ValType::ref_type(rt : RefType) -> ValType {
  RefTypeValType(rt)
}

///|
pub fn ValType::is_ref_type(vt : ValType) -> Bool {
  match vt {
    RefTypeValType(_) => true
    _ => false
  }
}

///|
pub fn ValType::ref_null_exn() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExnAbsHeapType)))
}

///|
pub fn ValType::funcref() -> ValType {
  // In core Wasm, call_indirect uses funcref.
  // Your encoding: AbsHeapTypeRefType(_) is nullable; funcref is (ref null func).
  RefTypeValType(AbsHeapTypeRefType(FuncAbsHeapType))
}

///|
pub fn ValType::bottom() -> ValType {
  BotValType
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
pub fn Elem::reftype(self : Elem) -> RefType {
  match self {
    Elem(_, kind) =>
      match kind {
        FuncsElemKind(_) => AbsHeapTypeRefType(FuncAbsHeapType) // funcref
        FuncExprsElemKind(_) => AbsHeapTypeRefType(FuncAbsHeapType) // funcref
        TypedExprsElemKind(rt, _) => rt
      }
  }
}

///|
pub fn ValType::ref_null(ht : HeapType) -> ValType {
  RefTypeValType(HeapTypeRefType(true, ht))
}

///|
pub fn ValType::eqref_null() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)))
}

///|
pub fn StorageType::unpack(st : StorageType) -> ValType {
  match st {
    ValTypeStorageType(vt) => vt
    PackTypeStorageType(_) => NumTypeValType(I32NumType)
  }
}

///|
pub fn StorageType::is_packed(st : StorageType) -> Bool {
  match st {
    PackTypeStorageType(_) => true
    _ => false
  }
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
  let U32(idx) = i
  match fields.get(idx.reinterpret_as_int()) {
    None => Err("struct field index out of range")
    Some(ft) => Ok(ft)
  }
}

///|
pub fn FieldType::is_mutable(ft : FieldType) -> Bool {
  match ft {
    FieldType(_, Var) => true
    _ => false
  }
}

///|
pub fn FieldType::unpack(self : Self) -> ValType {
  let FieldType(st, _) = self
  st.unpack()
}

///|
pub fn FieldType::get_storage_type(self : Self) -> StorageType {
  self.0
}

///|
pub fn min_addr_valtype(l1 : Limits, l2 : Limits) -> ValType {
  match (l1, l2) {
    (I64Limits(_, _), I64Limits(_, _)) => NumTypeValType(I64NumType)
    _ => NumTypeValType(I32NumType)
  }
}

///|
pub fn ValType::anyref() -> ValType {
  // (ref null any)
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)))
}

///|
pub fn ValType::externref() -> ValType {
  // (ref null extern)
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType)))
}

///|
pub fn ValType::i31ref() -> ValType {
  // (ref i31) (non-null)
  RefTypeValType(HeapTypeRefType(false, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
pub fn ValType::i31ref_nullable() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
pub fn ValType::ref_array_nonnull(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(false, HeapType(x)))
}

///|
pub fn ValType::ref_array_nullable(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(true, HeapType(x)))
}

///|
pub fn ValType::ref_null_array_of(x : TypeIdx) -> ValType {
  RefTypeValType(HeapTypeRefType(true, HeapType(x)))
}

///|
/// A tree-based expression where operands are explicit children rather than implicit stack values.
/// Each TInstr node contains its consumed operands as children.
pub struct TExpr(Array[TInstr]) derive(Eq, Show, Hash, Debug)

///|
/// A tree-based instruction with explicit operands
pub enum TInstr {
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
  TMemoryAtomicNotify(MemArg, TInstr, TInstr) // addr, count
  TMemoryAtomicWait32(MemArg, TInstr, TInstr, TInstr) // addr, expected, timeout
  TMemoryAtomicWait64(MemArg, TInstr, TInstr, TInstr) // addr, expected, timeout
  TAtomicFence
  TAtomicRmw(AtomicRmwOp, MemArg, TInstr, TInstr) // addr, value
  TAtomicCmpxchg(AtomicCmpxchgOp, MemArg, TInstr, TInstr, TInstr) // addr, expected, replacement

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
  TRefGetDesc(TInstr)
  TRefTest(Bool, HeapType, TInstr)
  TRefCast(Bool, HeapType, TInstr)
  TRefTestDesc(Bool, HeapType, TInstr)
  TRefCastDescEq(Bool, HeapType, TInstr)

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
} derive(Eq, Show, Hash, Debug)

///|
/// Unary operations
pub enum UnaryOp {
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
} derive(Eq, Show, Hash, Debug)

///|
/// Binary operations
pub enum BinaryOp {
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
} derive(Eq, Show, Hash, Debug)

///|
pub enum LoadOp {
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
  I32AtomicLoadOp
  I64AtomicLoadOp
  I32AtomicLoad8UOp
  I32AtomicLoad16UOp
  I64AtomicLoad8UOp
  I64AtomicLoad16UOp
  I64AtomicLoad32UOp

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
} derive(Eq, Show, Hash, Debug)

///|
/// Store operations
pub enum StoreOp {
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
  I32AtomicStoreOp
  I64AtomicStoreOp
  I32AtomicStore8Op
  I32AtomicStore16Op
  I64AtomicStore8Op
  I64AtomicStore16Op
  I64AtomicStore32Op

  // === SIMD ===
  V128StoreOp
} derive(Eq, Show, Hash, Debug)

///|
pub enum AtomicRmwOp {
  I32AtomicRmwAddOp
  I64AtomicRmwAddOp
  I32AtomicRmw8AddUOp
  I32AtomicRmw16AddUOp
  I64AtomicRmw8AddUOp
  I64AtomicRmw16AddUOp
  I64AtomicRmw32AddUOp
  I32AtomicRmwSubOp
  I64AtomicRmwSubOp
  I32AtomicRmw8SubUOp
  I32AtomicRmw16SubUOp
  I64AtomicRmw8SubUOp
  I64AtomicRmw16SubUOp
  I64AtomicRmw32SubUOp
  I32AtomicRmwAndOp
  I64AtomicRmwAndOp
  I32AtomicRmw8AndUOp
  I32AtomicRmw16AndUOp
  I64AtomicRmw8AndUOp
  I64AtomicRmw16AndUOp
  I64AtomicRmw32AndUOp
  I32AtomicRmwOrOp
  I64AtomicRmwOrOp
  I32AtomicRmw8OrUOp
  I32AtomicRmw16OrUOp
  I64AtomicRmw8OrUOp
  I64AtomicRmw16OrUOp
  I64AtomicRmw32OrUOp
  I32AtomicRmwXorOp
  I64AtomicRmwXorOp
  I32AtomicRmw8XorUOp
  I32AtomicRmw16XorUOp
  I64AtomicRmw8XorUOp
  I64AtomicRmw16XorUOp
  I64AtomicRmw32XorUOp
  I32AtomicRmwXchgOp
  I64AtomicRmwXchgOp
  I32AtomicRmw8XchgUOp
  I32AtomicRmw16XchgUOp
  I64AtomicRmw8XchgUOp
  I64AtomicRmw16XchgUOp
  I64AtomicRmw32XchgUOp
} derive(Eq, Show, Hash, Debug)

///|
pub enum AtomicCmpxchgOp {
  I32AtomicRmwCmpxchgOp
  I64AtomicRmwCmpxchgOp
  I32AtomicRmw8CmpxchgUOp
  I32AtomicRmw16CmpxchgUOp
  I64AtomicRmw8CmpxchgUOp
  I64AtomicRmw16CmpxchgUOp
  I64AtomicRmw32CmpxchgUOp
} derive(Eq, Show, Hash, Debug)

///|
/// Extract lane operations (v128 -> scalar)
pub enum ExtractLaneOp {
  I8x16ExtractLaneSOp
  I8x16ExtractLaneUOp
  I16x8ExtractLaneSOp
  I16x8ExtractLaneUOp
  I32x4ExtractLaneOp
  I64x2ExtractLaneOp
  F32x4ExtractLaneOp
  F64x2ExtractLaneOp
} derive(Eq, Show, Hash, Debug)

///|
/// Replace lane operations (v128, scalar -> v128)
pub enum ReplaceLaneOp {
  I8x16ReplaceLaneOp
  I16x8ReplaceLaneOp
  I32x4ReplaceLaneOp
  I64x2ReplaceLaneOp
  F32x4ReplaceLaneOp
  F64x2ReplaceLaneOp
} derive(Eq, Show, Hash, Debug)

///|
/// V128 shift operations (v128, i32 -> v128)
pub enum V128ShiftOp {
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
} derive(Eq, Show, Hash, Debug)

///|
/// V128 ternary operations (v128, v128, v128 -> v128)
pub enum V128TernaryOp {
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
} derive(Eq, Show, Hash, Debug)

///|
/// V128 lane load operations
pub enum V128LoadLaneOp {
  V128Load8LaneOp
  V128Load16LaneOp
  V128Load32LaneOp
  V128Load64LaneOp
} derive(Eq, Show, Hash, Debug)

///|
/// V128 lane store operations
pub enum V128StoreLaneOp {
  V128Store8LaneOp
  V128Store16LaneOp
  V128Store32LaneOp
  V128Store64LaneOp
} derive(Eq, Show, Hash, Debug)

///|
pub fn AbsHeapType::exn() -> AbsHeapType {
  ExnAbsHeapType
}

///|
pub fn AbsHeapType::array() -> AbsHeapType {
  ArrayAbsHeapType
}

///|
pub fn AbsHeapType::struct_() -> AbsHeapType {
  StructAbsHeapType
}

///|
pub fn AbsHeapType::i31() -> AbsHeapType {
  I31AbsHeapType
}

///|
pub fn AbsHeapType::eq() -> AbsHeapType {
  EqAbsHeapType
}

///|
pub fn AbsHeapType::any() -> AbsHeapType {
  AnyAbsHeapType
}

///|
pub fn AbsHeapType::extern_() -> AbsHeapType {
  ExternAbsHeapType
}

///|
pub fn AbsHeapType::func() -> AbsHeapType {
  FuncAbsHeapType
}

///|
pub fn AbsHeapType::none() -> AbsHeapType {
  NoneAbsHeapType
}

///|
pub fn AbsHeapType::no_extern() -> AbsHeapType {
  NoExternAbsHeapType
}

///|
pub fn AbsHeapType::no_func() -> AbsHeapType {
  NoFuncAbsHeapType
}

///|
pub fn AbsHeapType::no_exn() -> AbsHeapType {
  NoExnAbsHeapType
}

///|
pub fn HeapType::abs(abs : AbsHeapType) -> HeapType {
  AbsHeapTypeHeapType(abs)
}

///|
pub fn TypeIdx::new(idx : UInt) -> TypeIdx {
  TypeIdx(idx)
}

///|
pub fn TypeIdx::rec(idx : UInt) -> TypeIdx {
  RecIdx(idx)
}

///|
pub fn HeapType::new(ty_idx : TypeIdx) -> HeapType {
  HeapType(ty_idx)
}

///|
pub fn HeapType::def_type(dt : DefType) -> HeapType {
  DefTypeHeapType(dt)
}

///|
pub fn RefType::new(nullable : Bool, ht : HeapType) -> RefType {
  HeapTypeRefType(nullable, ht)
}

///|
pub fn RefType::abs(abs : AbsHeapType) -> RefType {
  AbsHeapTypeRefType(abs)
}

///|
pub fn PackType::i16() -> PackType {
  I16PackType
}

///|
pub fn PackType::i8() -> PackType {
  I8PackType
}

///|
pub fn StorageType::val_type(vt : ValType) -> StorageType {
  ValTypeStorageType(vt)
}

///|
pub fn StorageType::pack_type(pt : PackType) -> StorageType {
  PackTypeStorageType(pt)
}

///|
pub fn Mut::const_() -> Mut {
  Const
}

///|
pub fn Mut::var_() -> Mut {
  Var
}

///|
pub fn Catch::new(ti : TagIdx, li : LabelIdx) -> Catch {
  Catch(ti, li)
}

///|
pub fn Catch::ref_(ti : TagIdx, li : LabelIdx) -> Catch {
  CatchRef(ti, li)
}

///|
pub fn Catch::all(li : LabelIdx) -> Catch {
  CatchAll(li)
}

///|
pub fn Catch::all_ref(li : LabelIdx) -> Catch {
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
pub fn Limits::i32(min : UInt, max : UInt?) -> Limits {
  I32Limits(min, max)
}

///|
pub fn Limits::i64(min : UInt64, max : UInt64?) -> Limits {
  I64Limits(min, max)
}

///|
pub fn func_extern_type(idx : TypeIdx) -> ExternType {
  FuncExternType(idx)
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
pub fn ElemMode::passive() -> ElemMode {
  Passive
}

///|
pub fn ElemMode::active(ti : TableIdx, val : Expr) -> ElemMode {
  Active(ti, val)
}

///|
pub fn ElemMode::declarative() -> ElemMode {
  Declarative
}

///|
pub fn ElemKind::funcs(fs : Array[FuncIdx]) -> ElemKind {
  FuncsElemKind(fs)
}

///|
pub fn ElemKind::func_exprs(fs : Array[Expr]) -> ElemKind {
  FuncExprsElemKind(fs)
}

///|
pub fn ElemKind::typed_exprs(rt : RefType, els : Array[Expr]) -> ElemKind {
  TypedExprsElemKind(rt, els)
}

///|
pub fn DataMode::active(mi : MemIdx, expr : Expr) -> DataMode {
  Active(mi, expr)
}

///|
pub fn DataMode::passive() -> DataMode {
  Passive
}

///|
pub fn LabelIdx::new(idx : UInt) -> LabelIdx {
  LabelIdx(idx)
}

///|
pub fn Instruction::unreachable_() -> Instruction {
  Unreachable
}

///|
pub fn Instruction::nop() -> Instruction {
  Nop
}

///|
pub fn Instruction::block(bt : BlockType, val : Expr) -> Instruction {
  Block(bt, val)
}

///|
pub fn Instruction::loop_(bt : BlockType, val : Expr) -> Instruction {
  Loop(bt, val)
}

///|
pub fn Instruction::if_(
  bt : BlockType,
  if_block : Array[Instruction],
  else_block : Array[Instruction]?,
) -> Instruction {
  If(bt, if_block, else_block)
}

///|
pub fn Instruction::throw_(ti : TagIdx) -> Instruction {
  Throw(ti)
}

///|
pub fn Instruction::throw_ref() -> Instruction {
  ThrowRef
}

///|
pub fn Instruction::br(li : LabelIdx) -> Instruction {
  Br(li)
}

///|
pub fn Instruction::br_if(li : LabelIdx) -> Instruction {
  BrIf(li)
}

///|
pub fn Instruction::br_table(
  ls : Array[LabelIdx],
  li0 : LabelIdx,
) -> Instruction {
  BrTable(ls, li0)
}

///|
pub fn Instruction::return_() -> Instruction {
  Return
}

///|
pub fn Instruction::call(fi : FuncIdx) -> Instruction {
  Call(fi)
}

///|
pub fn Instruction::call_indirect(
  ty_idx : TypeIdx,
  tbl_idx : TableIdx,
) -> Instruction {
  CallIndirect(ty_idx, tbl_idx)
}

///|
pub fn Instruction::return_call(fi : FuncIdx) -> Instruction {
  ReturnCall(fi)
}

///|
pub fn Instruction::return_call_indirect(
  ty_idx : TypeIdx,
  tbl_idx : TableIdx,
) -> Instruction {
  ReturnCallIndirect(ty_idx, tbl_idx)
}

///|
pub fn Instruction::call_ref(ti : TypeIdx) -> Instruction {
  CallRef(ti)
}

///|
pub fn Instruction::return_call_ref(ti : TypeIdx) -> Instruction {
  ReturnCallRef(ti)
}

///|
pub fn Instruction::drop() -> Instruction {
  Drop
}

///|
pub fn Instruction::select(types? : Array[ValType]? = None) -> Instruction {
  Select(types)
}

///|
pub fn Instruction::try_table(
  bt : BlockType,
  catches : Array[Catch],
  val : Expr,
) -> Instruction {
  TryTable(bt, catches, val)
}

///|
pub fn Instruction::local_get(li : LocalIdx) -> Instruction {
  LocalGet(li)
}

///|
pub fn Instruction::local_set(li : LocalIdx) -> Instruction {
  LocalSet(li)
}

///|
pub fn Instruction::local_tee(li : LocalIdx) -> Instruction {
  LocalTee(li)
}

///|
pub fn Instruction::global_get(gi : GlobalIdx) -> Instruction {
  GlobalGet(gi)
}

///|
pub fn Instruction::global_set(gi : GlobalIdx) -> Instruction {
  GlobalSet(gi)
}

///|
pub fn Instruction::table_get(ti : TableIdx) -> Instruction {
  TableGet(ti)
}

///|
pub fn Instruction::table_set(ti : TableIdx) -> Instruction {
  TableSet(ti)
}

///|
pub fn Instruction::i32_load(ma : MemArg) -> Instruction {
  I32Load(ma)
}

///|
pub fn Instruction::i64_load(ma : MemArg) -> Instruction {
  I64Load(ma)
}

///|
pub fn Instruction::f32_load(ma : MemArg) -> Instruction {
  F32Load(ma)
}

///|
pub fn Instruction::f64_load(ma : MemArg) -> Instruction {
  F64Load(ma)
}

///|
pub fn Instruction::i32_load8s(ma : MemArg) -> Instruction {
  I32Load8S(ma)
}

///|
pub fn Instruction::i32_load8u(ma : MemArg) -> Instruction {
  I32Load8U(ma)
}

///|
pub fn Instruction::i32_load16s(ma : MemArg) -> Instruction {
  I32Load16S(ma)
}

///|
pub fn Instruction::i32_load16u(ma : MemArg) -> Instruction {
  I32Load16U(ma)
}

///|
pub fn Instruction::i64_load8s(ma : MemArg) -> Instruction {
  I64Load8S(ma)
}

///|
pub fn Instruction::i64_load8u(ma : MemArg) -> Instruction {
  I64Load8U(ma)
}

///|
pub fn Instruction::i64_load16s(ma : MemArg) -> Instruction {
  I64Load16S(ma)
}

///|
pub fn Instruction::i64_load16u(ma : MemArg) -> Instruction {
  I64Load16U(ma)
}

///|
pub fn Instruction::i64_load32s(ma : MemArg) -> Instruction {
  I64Load32S(ma)
}

///|
pub fn Instruction::i64_load32u(ma : MemArg) -> Instruction {
  I64Load32U(ma)
}

///|
pub fn Instruction::i32_store(ma : MemArg) -> Instruction {
  I32Store(ma)
}

///|
pub fn Instruction::i64_store(ma : MemArg) -> Instruction {
  I64Store(ma)
}

///|
pub fn Instruction::f32_store(ma : MemArg) -> Instruction {
  F32Store(ma)
}

///|
pub fn Instruction::f64_store(ma : MemArg) -> Instruction {
  F64Store(ma)
}

///|
pub fn Instruction::i32_store8(ma : MemArg) -> Instruction {
  I32Store8(ma)
}

///|
pub fn Instruction::i32_store16(ma : MemArg) -> Instruction {
  I32Store16(ma)
}

///|
pub fn Instruction::i64_store8(ma : MemArg) -> Instruction {
  I64Store8(ma)
}

///|
pub fn Instruction::i64_store16(ma : MemArg) -> Instruction {
  I64Store16(ma)
}

///|
pub fn Instruction::i64_store32(ma : MemArg) -> Instruction {
  I64Store32(ma)
}

///|
pub fn Instruction::memory_size(mi : MemIdx) -> Instruction {
  MemorySize(mi)
}

///|
pub fn Instruction::memory_grow(mi : MemIdx) -> Instruction {
  MemoryGrow(mi)
}

///|
pub fn Instruction::memory_atomic_notify(ma : MemArg) -> Instruction {
  MemoryAtomicNotify(ma)
}

///|
pub fn Instruction::memory_atomic_wait32(ma : MemArg) -> Instruction {
  MemoryAtomicWait32(ma)
}

///|
pub fn Instruction::memory_atomic_wait64(ma : MemArg) -> Instruction {
  MemoryAtomicWait64(ma)
}

///|
pub fn Instruction::atomic_fence() -> Instruction {
  AtomicFence
}

///|
pub fn Instruction::i32_atomic_load(ma : MemArg) -> Instruction {
  I32AtomicLoad(ma)
}

///|
pub fn Instruction::i64_atomic_load(ma : MemArg) -> Instruction {
  I64AtomicLoad(ma)
}

///|
pub fn Instruction::i32_atomic_load8_u(ma : MemArg) -> Instruction {
  I32AtomicLoad8U(ma)
}

///|
pub fn Instruction::i32_atomic_load16_u(ma : MemArg) -> Instruction {
  I32AtomicLoad16U(ma)
}

///|
pub fn Instruction::i64_atomic_load8_u(ma : MemArg) -> Instruction {
  I64AtomicLoad8U(ma)
}

///|
pub fn Instruction::i64_atomic_load16_u(ma : MemArg) -> Instruction {
  I64AtomicLoad16U(ma)
}

///|
pub fn Instruction::i64_atomic_load32_u(ma : MemArg) -> Instruction {
  I64AtomicLoad32U(ma)
}

///|
pub fn Instruction::i32_atomic_store(ma : MemArg) -> Instruction {
  I32AtomicStore(ma)
}

///|
pub fn Instruction::i64_atomic_store(ma : MemArg) -> Instruction {
  I64AtomicStore(ma)
}

///|
pub fn Instruction::i32_atomic_store8(ma : MemArg) -> Instruction {
  I32AtomicStore8(ma)
}

///|
pub fn Instruction::i32_atomic_store16(ma : MemArg) -> Instruction {
  I32AtomicStore16(ma)
}

///|
pub fn Instruction::i64_atomic_store8(ma : MemArg) -> Instruction {
  I64AtomicStore8(ma)
}

///|
pub fn Instruction::i64_atomic_store16(ma : MemArg) -> Instruction {
  I64AtomicStore16(ma)
}

///|
pub fn Instruction::i64_atomic_store32(ma : MemArg) -> Instruction {
  I64AtomicStore32(ma)
}

///|
pub fn Instruction::atomic_rmw(op : AtomicRmwOp, ma : MemArg) -> Instruction {
  AtomicRmw(op, ma)
}

///|
pub fn Instruction::atomic_cmpxchg(
  op : AtomicCmpxchgOp,
  ma : MemArg,
) -> Instruction {
  AtomicCmpxchg(op, ma)
}

///|
pub fn Instruction::i32_const(val : I32) -> Instruction {
  I32Const(val)
}

///|
pub fn Instruction::i64_const(val : I64) -> Instruction {
  I64Const(val)
}

///|
pub fn Instruction::f32_const(val : F32) -> Instruction {
  F32Const(val)
}

///|
pub fn Instruction::f64_const(val : F64) -> Instruction {
  F64Const(val)
}

///|
pub fn Instruction::i32_eqz() -> Instruction {
  I32Eqz
}

///|
pub fn Instruction::i32_eq() -> Instruction {
  I32Eq
}

///|
pub fn Instruction::i32_ne() -> Instruction {
  I32Ne
}

///|
pub fn Instruction::i32_lt_s() -> Instruction {
  I32LtS
}

///|
pub fn Instruction::i32_lt_u() -> Instruction {
  I32LtU
}

///|
pub fn Instruction::i32_gt_s() -> Instruction {
  I32GtS
}

///|
pub fn Instruction::i32_gt_u() -> Instruction {
  I32GtU
}

///|
pub fn Instruction::i32_le_s() -> Instruction {
  I32LeS
}

///|
pub fn Instruction::i32_le_u() -> Instruction {
  I32LeU
}

///|
pub fn Instruction::i32_ge_s() -> Instruction {
  I32GeS
}

///|
pub fn Instruction::i32_ge_u() -> Instruction {
  I32GeU
}

///|
pub fn Instruction::i64_eqz() -> Instruction {
  I64Eqz
}

///|
pub fn Instruction::i64_eq() -> Instruction {
  I64Eq
}

///|
pub fn Instruction::i64_ne() -> Instruction {
  I64Ne
}

///|
pub fn Instruction::i64_lt_s() -> Instruction {
  I64LtS
}

///|
pub fn Instruction::i64_lt_u() -> Instruction {
  I64LtU
}

///|
pub fn Instruction::i64_gt_s() -> Instruction {
  I64GtS
}

///|
pub fn Instruction::i64_gt_u() -> Instruction {
  I64GtU
}

///|
pub fn Instruction::i64_le_s() -> Instruction {
  I64LeS
}

///|
pub fn Instruction::i64_le_u() -> Instruction {
  I64LeU
}

///|
pub fn Instruction::i64_ge_s() -> Instruction {
  I64GeS
}

///|
pub fn Instruction::i64_ge_u() -> Instruction {
  I64GeU
}

///|
pub fn Instruction::f32_eq() -> Instruction {
  F32Eq
}

///|
pub fn Instruction::f32_ne() -> Instruction {
  F32Ne
}

///|
pub fn Instruction::f32_lt() -> Instruction {
  F32Lt
}

///|
pub fn Instruction::f32_gt() -> Instruction {
  F32Gt
}

///|
pub fn Instruction::f32_le() -> Instruction {
  F32Le
}

///|
pub fn Instruction::f32_ge() -> Instruction {
  F32Ge
}

///|
pub fn Instruction::f64_eq() -> Instruction {
  F64Eq
}

///|
pub fn Instruction::f64_ne() -> Instruction {
  F64Ne
}

///|
pub fn Instruction::f64_lt() -> Instruction {
  F64Lt
}

///|
pub fn Instruction::f64_gt() -> Instruction {
  F64Gt
}

///|
pub fn Instruction::f64_le() -> Instruction {
  F64Le
}

///|
pub fn Instruction::f64_ge() -> Instruction {
  F64Ge
}

///|
pub fn Instruction::i32_clz() -> Instruction {
  I32Clz
}

///|
pub fn Instruction::i32_ctz() -> Instruction {
  I32Ctz
}

///|
pub fn Instruction::i32_popcnt() -> Instruction {
  I32Popcnt
}

///|
pub fn Instruction::i32_add() -> Instruction {
  I32Add
}

///|
pub fn Instruction::i32_sub() -> Instruction {
  I32Sub
}

///|
pub fn Instruction::i32_mul() -> Instruction {
  I32Mul
}

///|
pub fn Instruction::i32_div_s() -> Instruction {
  I32DivS
}

///|
pub fn Instruction::i32_div_u() -> Instruction {
  I32DivU
}

///|
pub fn Instruction::i32_rem_s() -> Instruction {
  I32RemS
}

///|
pub fn Instruction::i32_rem_u() -> Instruction {
  I32RemU
}

///|
pub fn Instruction::i32_and() -> Instruction {
  I32And
}

///|
pub fn Instruction::i32_or() -> Instruction {
  I32Or
}

///|
pub fn Instruction::i32_xor() -> Instruction {
  I32Xor
}

///|
pub fn Instruction::i32_shl() -> Instruction {
  I32Shl
}

///|
pub fn Instruction::i32_shr_s() -> Instruction {
  I32ShrS
}

///|
pub fn Instruction::i32_shr_u() -> Instruction {
  I32ShrU
}

///|
pub fn Instruction::i32_rotl() -> Instruction {
  I32Rotl
}

///|
pub fn Instruction::i32_rotr() -> Instruction {
  I32Rotr
}

///|
pub fn Instruction::i64_clz() -> Instruction {
  I64Clz
}

///|
pub fn Instruction::i64_ctz() -> Instruction {
  I64Ctz
}

///|
pub fn Instruction::i64_popcnt() -> Instruction {
  I64Popcnt
}

///|
pub fn Instruction::i64_add() -> Instruction {
  I64Add
}

///|
pub fn Instruction::i64_sub() -> Instruction {
  I64Sub
}

///|
pub fn Instruction::i64_mul() -> Instruction {
  I64Mul
}

///|
pub fn Instruction::i64_div_s() -> Instruction {
  I64DivS
}

///|
pub fn Instruction::i64_div_u() -> Instruction {
  I64DivU
}

///|
pub fn Instruction::i64_rem_s() -> Instruction {
  I64RemS
}

///|
pub fn Instruction::i64_rem_u() -> Instruction {
  I64RemU
}

///|
pub fn Instruction::i64_and() -> Instruction {
  I64And
}

///|
pub fn Instruction::i64_or() -> Instruction {
  I64Or
}

///|
pub fn Instruction::i64_xor() -> Instruction {
  I64Xor
}

///|
pub fn Instruction::i64_shl() -> Instruction {
  I64Shl
}

///|
pub fn Instruction::i64_shr_s() -> Instruction {
  I64ShrS
}

///|
pub fn Instruction::i64_shr_u() -> Instruction {
  I64ShrU
}

///|
pub fn Instruction::i64_rotl() -> Instruction {
  I64Rotl
}

///|
pub fn Instruction::i64_rotr() -> Instruction {
  I64Rotr
}

///|
pub fn Instruction::f32_abs() -> Instruction {
  F32Abs
}

///|
pub fn Instruction::f32_neg() -> Instruction {
  F32Neg
}

///|
pub fn Instruction::f32_ceil() -> Instruction {
  F32Ceil
}

///|
pub fn Instruction::f32_floor() -> Instruction {
  F32Floor
}

///|
pub fn Instruction::f32_trunc() -> Instruction {
  F32Trunc
}

///|
pub fn Instruction::f32_nearest() -> Instruction {
  F32Nearest
}

///|
pub fn Instruction::f32_sqrt() -> Instruction {
  F32Sqrt
}

///|
pub fn Instruction::f32_add() -> Instruction {
  F32Add
}

///|
pub fn Instruction::f32_sub() -> Instruction {
  F32Sub
}

///|
pub fn Instruction::f32_mul() -> Instruction {
  F32Mul
}

///|
pub fn Instruction::f32_div() -> Instruction {
  F32Div
}

///|
pub fn Instruction::f32_min() -> Instruction {
  F32Min
}

///|
pub fn Instruction::f32_max() -> Instruction {
  F32Max
}

///|
pub fn Instruction::f32_copysign() -> Instruction {
  F32Copysign
}

///|
pub fn Instruction::f64_abs() -> Instruction {
  F64Abs
}

///|
pub fn Instruction::f64_neg() -> Instruction {
  F64Neg
}

///|
pub fn Instruction::f64_ceil() -> Instruction {
  F64Ceil
}

///|
pub fn Instruction::f64_floor() -> Instruction {
  F64Floor
}

///|
pub fn Instruction::f64_trunc() -> Instruction {
  F64Trunc
}

///|
pub fn Instruction::f64_nearest() -> Instruction {
  F64Nearest
}

///|
pub fn Instruction::f64_sqrt() -> Instruction {
  F64Sqrt
}

///|
pub fn Instruction::f64_add() -> Instruction {
  F64Add
}

///|
pub fn Instruction::f64_sub() -> Instruction {
  F64Sub
}

///|
pub fn Instruction::f64_mul() -> Instruction {
  F64Mul
}

///|
pub fn Instruction::f64_div() -> Instruction {
  F64Div
}

///|
pub fn Instruction::f64_min() -> Instruction {
  F64Min
}

///|
pub fn Instruction::f64_max() -> Instruction {
  F64Max
}

///|
pub fn Instruction::f64_copysign() -> Instruction {
  F64Copysign
}

///|
pub fn Instruction::i32_wrap_i64() -> Instruction {
  I32WrapI64
}

///|
pub fn Instruction::i32_trunc_f32s() -> Instruction {
  I32TruncF32S
}

///|
pub fn Instruction::i32_trunc_f32u() -> Instruction {
  I32TruncF32U
}

///|
pub fn Instruction::i32_trunc_f64s() -> Instruction {
  I32TruncF64S
}

///|
pub fn Instruction::i32_trunc_f64u() -> Instruction {
  I32TruncF64U
}

///|
pub fn Instruction::i64_extend_i32s() -> Instruction {
  I64ExtendI32S
}

///|
pub fn Instruction::i64_extend_i32u() -> Instruction {
  I64ExtendI32U
}

///|
pub fn Instruction::i64_trunc_f32s() -> Instruction {
  I64TruncF32S
}

///|
pub fn Instruction::i64_trunc_f32u() -> Instruction {
  I64TruncF32U
}

///|
pub fn Instruction::i64_trunc_f64s() -> Instruction {
  I64TruncF64S
}

///|
pub fn Instruction::i64_trunc_f64u() -> Instruction {
  I64TruncF64U
}

///|
pub fn Instruction::f32_convert_i32s() -> Instruction {
  F32ConvertI32S
}

///|
pub fn Instruction::f32_convert_i32u() -> Instruction {
  F32ConvertI32U
}

///|
pub fn Instruction::f32_convert_i64s() -> Instruction {
  F32ConvertI64S
}

///|
pub fn Instruction::f32_convert_i64u() -> Instruction {
  F32ConvertI64U
}

///|
pub fn Instruction::f32_demote_f64() -> Instruction {
  F32DemoteF64
}

///|
pub fn Instruction::f64_convert_i32s() -> Instruction {
  F64ConvertI32S
}

///|
pub fn Instruction::f64_convert_i32u() -> Instruction {
  F64ConvertI32U
}

///|
pub fn Instruction::f64_convert_i64s() -> Instruction {
  F64ConvertI64S
}

///|
pub fn Instruction::f64_convert_i64u() -> Instruction {
  F64ConvertI64U
}

///|
pub fn Instruction::f64_promote_f32() -> Instruction {
  F64PromoteF32
}

///|
pub fn Instruction::i32_reinterpret_f32() -> Instruction {
  I32ReinterpretF32
}

///|
pub fn Instruction::i64_reinterpret_f64() -> Instruction {
  I64ReinterpretF64
}

///|
pub fn Instruction::f32_reinterpret_i32() -> Instruction {
  F32ReinterpretI32
}

///|
pub fn Instruction::f64_reinterpret_i64() -> Instruction {
  F64ReinterpretI64
}

///|
pub fn Instruction::i32_extend8s() -> Instruction {
  I32Extend8S
}

///|
pub fn Instruction::i32_extend16s() -> Instruction {
  I32Extend16S
}

///|
pub fn Instruction::i64_extend8s() -> Instruction {
  I64Extend8S
}

///|
pub fn Instruction::i64_extend16s() -> Instruction {
  I64Extend16S
}

///|
pub fn Instruction::i64_extend32s() -> Instruction {
  I64Extend32S
}

///|
pub fn Instruction::ref_null(ht : HeapType) -> Instruction {
  RefNull(ht)
}

///|
pub fn Instruction::ref_is_null() -> Instruction {
  RefIsNull
}

///|
pub fn Instruction::ref_func(fi : FuncIdx) -> Instruction {
  RefFunc(fi)
}

///|
pub fn Instruction::ref_eq() -> Instruction {
  RefEq
}

///|
pub fn Instruction::ref_as_non_null() -> Instruction {
  RefAsNonNull
}

///|
pub fn Instruction::br_on_null(li : LabelIdx) -> Instruction {
  BrOnNull(li)
}

///|
pub fn Instruction::br_on_non_null(li : LabelIdx) -> Instruction {
  BrOnNonNull(li)
}

///|
pub fn Instruction::struct_new(ti : TypeIdx) -> Instruction {
  StructNew(ti)
}

///|
pub fn Instruction::struct_new_default(ti : TypeIdx) -> Instruction {
  StructNewDefault(ti)
}

///|
pub fn Instruction::struct_get(ty : TypeIdx, fi : U32) -> Instruction {
  StructGet(ty, fi)
}

///|
pub fn Instruction::struct_get_s(ty : TypeIdx, fi : U32) -> Instruction {
  StructGetS(ty, fi)
}

///|
pub fn Instruction::struct_get_u(ty : TypeIdx, fi : U32) -> Instruction {
  StructGetU(ty, fi)
}

///|
pub fn Instruction::struct_set(ty : TypeIdx, fi : U32) -> Instruction {
  StructSet(ty, fi)
}

///|
pub fn Instruction::array_new(ti : TypeIdx) -> Instruction {
  ArrayNew(ti)
}

///|
pub fn Instruction::array_new_default(ti : TypeIdx) -> Instruction {
  ArrayNewDefault(ti)
}

///|
pub fn Instruction::array_new_fixed(ti : TypeIdx, len : U32) -> Instruction {
  ArrayNewFixed(ti, len)
}

///|
pub fn Instruction::array_new_data(ti : TypeIdx, di : DataIdx) -> Instruction {
  ArrayNewData(ti, di)
}

///|
pub fn Instruction::array_new_elem(ti : TypeIdx, ei : ElemIdx) -> Instruction {
  ArrayNewElem(ti, ei)
}

///|
pub fn Instruction::array_get(ti : TypeIdx) -> Instruction {
  ArrayGet(ti)
}

///|
pub fn Instruction::array_get_s(ti : TypeIdx) -> Instruction {
  ArrayGetS(ti)
}

///|
pub fn Instruction::array_get_u(ti : TypeIdx) -> Instruction {
  ArrayGetU(ti)
}

///|
pub fn Instruction::array_set(ti : TypeIdx) -> Instruction {
  ArraySet(ti)
}

///|
pub fn Instruction::array_len() -> Instruction {
  ArrayLen
}

///|
pub fn Instruction::array_fill(ti : TypeIdx) -> Instruction {
  ArrayFill(ti)
}

///|
pub fn Instruction::array_copy(ti0 : TypeIdx, ti1 : TypeIdx) -> Instruction {
  ArrayCopy(ti0, ti1)
}

///|
pub fn Instruction::array_init_data(ti : TypeIdx, di : DataIdx) -> Instruction {
  ArrayInitData(ti, di)
}

///|
pub fn Instruction::array_init_elem(ti : TypeIdx, ei : ElemIdx) -> Instruction {
  ArrayInitElem(ti, ei)
}

///|
pub fn Instruction::ref_get_desc() -> Instruction {
  RefGetDesc
}

///|
pub fn Instruction::ref_test(nullable : Bool, ht : HeapType) -> Instruction {
  RefTest(nullable, ht)
}

///|
pub fn Instruction::ref_cast(nullable : Bool, ht : HeapType) -> Instruction {
  RefCast(nullable, ht)
}

///|
pub fn Instruction::ref_test_desc(
  nullable : Bool,
  ht : HeapType,
) -> Instruction {
  RefTestDesc(nullable, ht)
}

///|
pub fn Instruction::ref_cast_desc_eq(
  nullable : Bool,
  ht : HeapType,
) -> Instruction {
  RefCastDescEq(nullable, ht)
}

///|
pub fn Instruction::br_on_cast(
  li : LabelIdx,
  t_nullable_0 : Bool,
  ht0 : HeapType,
  t_nullable_1 : Bool,
  ht1 : HeapType,
) -> Instruction {
  BrOnCast(li, CastOp(t_nullable_0, t_nullable_1), ht0, ht1)
}

///|
pub fn Instruction::br_on_cast_fail(
  li : LabelIdx,
  t_nullable_0 : Bool,
  ht0 : HeapType,
  t_nullable_1 : Bool,
  ht1 : HeapType,
) -> Instruction {
  BrOnCastFail(li, CastOp(t_nullable_0, t_nullable_1), ht0, ht1)
}

///|
pub fn Instruction::any_convert_extern() -> Instruction {
  AnyConvertExtern
}

///|
pub fn Instruction::extern_convert_any() -> Instruction {
  ExternConvertAny
}

///|
pub fn Instruction::ref_i31() -> Instruction {
  RefI31
}

///|
pub fn Instruction::i31_get_s() -> Instruction {
  I31GetS
}

///|
pub fn Instruction::i31_get_u() -> Instruction {
  I31GetU
}

///|
pub fn Instruction::i32_trunc_sat_f32s() -> Instruction {
  I32TruncSatF32S
}

///|
pub fn Instruction::i32_trunc_sat_f32u() -> Instruction {
  I32TruncSatF32U
}

///|
pub fn Instruction::i32_trunc_sat_f64s() -> Instruction {
  I32TruncSatF64S
}

///|
pub fn Instruction::i32_trunc_sat_f64u() -> Instruction {
  I32TruncSatF64U
}

///|
pub fn Instruction::i64_trunc_sat_f32s() -> Instruction {
  I64TruncSatF32S
}

///|
pub fn Instruction::i64_trunc_sat_f32u() -> Instruction {
  I64TruncSatF32U
}

///|
pub fn Instruction::i64_trunc_sat_f64s() -> Instruction {
  I64TruncSatF64S
}

///|
pub fn Instruction::i64_trunc_sat_f64u() -> Instruction {
  I64TruncSatF64U
}

///|
pub fn Instruction::memory_init(di : DataIdx, mi : MemIdx) -> Instruction {
  MemoryInit(di, mi)
}

///|
pub fn Instruction::data_drop(di : DataIdx) -> Instruction {
  DataDrop(di)
}

///|
pub fn Instruction::memory_copy(mi0 : MemIdx, mi1 : MemIdx) -> Instruction {
  MemoryCopy(mi0, mi1)
}

///|
pub fn Instruction::memory_fill(mi : MemIdx) -> Instruction {
  MemoryFill(mi)
}

///|
pub fn Instruction::table_init(ei : ElemIdx, ti : TableIdx) -> Instruction {
  TableInit(ei, ti)
}

///|
pub fn Instruction::elem_drop(ei : ElemIdx) -> Instruction {
  ElemDrop(ei)
}

///|
pub fn Instruction::table_copy(ti0 : TableIdx, ti1 : TableIdx) -> Instruction {
  TableCopy(ti0, ti1)
}

///|
pub fn Instruction::table_grow(ti : TableIdx) -> Instruction {
  TableGrow(ti)
}

///|
pub fn Instruction::table_size(ti : TableIdx) -> Instruction {
  TableSize(ti)
}

///|
pub fn Instruction::table_fill(ti : TableIdx) -> Instruction {
  TableFill(ti)
}

///|
pub fn Instruction::v128_load(ma : MemArg) -> Instruction {
  V128Load(ma)
}

///|
pub fn Instruction::v128_load8x8s(ma : MemArg) -> Instruction {
  V128Load8x8S(ma)
}

///|
pub fn Instruction::v128_load8x8u(ma : MemArg) -> Instruction {
  V128Load8x8U(ma)
}

///|
pub fn Instruction::v128_load16x4s(ma : MemArg) -> Instruction {
  V128Load16x4S(ma)
}

///|
pub fn Instruction::v128_load16x4u(ma : MemArg) -> Instruction {
  V128Load16x4U(ma)
}

///|
pub fn Instruction::v128_load32x2s(ma : MemArg) -> Instruction {
  V128Load32x2S(ma)
}

///|
pub fn Instruction::v128_load32x2u(ma : MemArg) -> Instruction {
  V128Load32x2U(ma)
}

///|
pub fn Instruction::v128_load8_splat(ma : MemArg) -> Instruction {
  V128Load8Splat(ma)
}

///|
pub fn Instruction::v128_load16_splat(ma : MemArg) -> Instruction {
  V128Load16Splat(ma)
}

///|
pub fn Instruction::v128_load32_splat(ma : MemArg) -> Instruction {
  V128Load32Splat(ma)
}

///|
pub fn Instruction::v128_load64_splat(ma : MemArg) -> Instruction {
  V128Load64Splat(ma)
}

///|
pub fn Instruction::v128_store(ma : MemArg) -> Instruction {
  V128Store(ma)
}

///|
pub fn Instruction::v128_const(
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
pub fn Instruction::i8x16_shuffle(
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
pub fn Instruction::i8x16_swizzle() -> Instruction {
  I8x16Swizzle
}

///|
pub fn Instruction::i8x16_splat() -> Instruction {
  I8x16Splat
}

///|
pub fn Instruction::i16x8_splat() -> Instruction {
  I16x8Splat
}

///|
pub fn Instruction::i32x4_splat() -> Instruction {
  I32x4Splat
}

///|
pub fn Instruction::i64x2_splat() -> Instruction {
  I64x2Splat
}

///|
pub fn Instruction::f32x4_splat() -> Instruction {
  F32x4Splat
}

///|
pub fn Instruction::f64x2_splat() -> Instruction {
  F64x2Splat
}

///|
pub fn Instruction::i8x16_extract_lane_s(li : LaneIdx) -> Instruction {
  I8x16ExtractLaneS(li)
}

///|
pub fn Instruction::i8x16_extract_lane_u(li : LaneIdx) -> Instruction {
  I8x16ExtractLaneU(li)
}

///|
pub fn Instruction::i8x16_replace_lane(li : LaneIdx) -> Instruction {
  I8x16ReplaceLane(li)
}

///|
pub fn Instruction::i16x8_extract_lane_s(li : LaneIdx) -> Instruction {
  I16x8ExtractLaneS(li)
}

///|
pub fn Instruction::i16x8_extract_lane_u(li : LaneIdx) -> Instruction {
  I16x8ExtractLaneU(li)
}

///|
pub fn Instruction::i16x8_replace_lane(li : LaneIdx) -> Instruction {
  I16x8ReplaceLane(li)
}

///|
pub fn Instruction::i32x4_extract_lane(li : LaneIdx) -> Instruction {
  I32x4ExtractLane(li)
}

///|
pub fn Instruction::i32x4_replace_lane(li : LaneIdx) -> Instruction {
  I32x4ReplaceLane(li)
}

///|
pub fn Instruction::i64x2_extract_lane(li : LaneIdx) -> Instruction {
  I64x2ExtractLane(li)
}

///|
pub fn Instruction::i64x2_replace_lane(li : LaneIdx) -> Instruction {
  I64x2ReplaceLane(li)
}

///|
pub fn Instruction::f32x4_extract_lane(li : LaneIdx) -> Instruction {
  F32x4ExtractLane(li)
}

///|
pub fn Instruction::f32x4_replace_lane(li : LaneIdx) -> Instruction {
  F32x4ReplaceLane(li)
}

///|
pub fn Instruction::f64x2_extract_lane(li : LaneIdx) -> Instruction {
  F64x2ExtractLane(li)
}

///|
pub fn Instruction::f64x2_replace_lane(li : LaneIdx) -> Instruction {
  F64x2ReplaceLane(li)
}

///|
pub fn Instruction::i8x16_eq() -> Instruction {
  I8x16Eq
}

///|
pub fn Instruction::i8x16_ne() -> Instruction {
  I8x16Ne
}

///|
pub fn Instruction::i8x16_lt_s() -> Instruction {
  I8x16LtS
}

///|
pub fn Instruction::i8x16_lt_u() -> Instruction {
  I8x16LtU
}

///|
pub fn Instruction::i8x16_gt_s() -> Instruction {
  I8x16GtS
}

///|
pub fn Instruction::i8x16_gt_u() -> Instruction {
  I8x16GtU
}

///|
pub fn Instruction::i8x16_le_s() -> Instruction {
  I8x16LeS
}

///|
pub fn Instruction::i8x16_le_u() -> Instruction {
  I8x16LeU
}

///|
pub fn Instruction::i8x16_ge_s() -> Instruction {
  I8x16GeS
}

///|
pub fn Instruction::i8x16_ge_u() -> Instruction {
  I8x16GeU
}

///|
pub fn Instruction::i16x8_eq() -> Instruction {
  I16x8Eq
}

///|
pub fn Instruction::i16x8_ne() -> Instruction {
  I16x8Ne
}

///|
pub fn Instruction::i16x8_lt_s() -> Instruction {
  I16x8LtS
}

///|
pub fn Instruction::i16x8_lt_u() -> Instruction {
  I16x8LtU
}

///|
pub fn Instruction::i16x8_gt_s() -> Instruction {
  I16x8GtS
}

///|
pub fn Instruction::i16x8_gt_u() -> Instruction {
  I16x8GtU
}

///|
pub fn Instruction::i16x8_le_s() -> Instruction {
  I16x8LeS
}

///|
pub fn Instruction::i16x8_le_u() -> Instruction {
  I16x8LeU
}

///|
pub fn Instruction::i16x8_ge_s() -> Instruction {
  I16x8GeS
}

///|
pub fn Instruction::i16x8_ge_u() -> Instruction {
  I16x8GeU
}

///|
pub fn Instruction::i32x4_eq() -> Instruction {
  I32x4Eq
}

///|
pub fn Instruction::i32x4_ne() -> Instruction {
  I32x4Ne
}

///|
pub fn Instruction::i32x4_lt_s() -> Instruction {
  I32x4LtS
}

///|
pub fn Instruction::i32x4_lt_u() -> Instruction {
  I32x4LtU
}

///|
pub fn Instruction::i32x4_gt_s() -> Instruction {
  I32x4GtS
}

///|
pub fn Instruction::i32x4_gt_u() -> Instruction {
  I32x4GtU
}

///|
pub fn Instruction::i32x4_le_s() -> Instruction {
  I32x4LeS
}

///|
pub fn Instruction::i32x4_le_u() -> Instruction {
  I32x4LeU
}

///|
pub fn Instruction::i32x4_ge_s() -> Instruction {
  I32x4GeS
}

///|
pub fn Instruction::i32x4_ge_u() -> Instruction {
  I32x4GeU
}

///|
pub fn Instruction::f32x4_eq() -> Instruction {
  F32x4Eq
}

///|
pub fn Instruction::f32x4_ne() -> Instruction {
  F32x4Ne
}

///|
pub fn Instruction::f32x4_lt() -> Instruction {
  F32x4Lt
}

///|
pub fn Instruction::f32x4_gt() -> Instruction {
  F32x4Gt
}

///|
pub fn Instruction::f32x4_le() -> Instruction {
  F32x4Le
}

///|
pub fn Instruction::f32x4_ge() -> Instruction {
  F32x4Ge
}

///|
pub fn Instruction::f64x2_eq() -> Instruction {
  F64x2Eq
}

///|
pub fn Instruction::f64x2_ne() -> Instruction {
  F64x2Ne
}

///|
pub fn Instruction::f64x2_lt() -> Instruction {
  F64x2Lt
}

///|
pub fn Instruction::f64x2_gt() -> Instruction {
  F64x2Gt
}

///|
pub fn Instruction::f64x2_le() -> Instruction {
  F64x2Le
}

///|
pub fn Instruction::f64x2_ge() -> Instruction {
  F64x2Ge
}

///|
pub fn Instruction::v128_not() -> Instruction {
  V128Not
}

///|
pub fn Instruction::v128_and() -> Instruction {
  V128And
}

///|
pub fn Instruction::v128_andnot() -> Instruction {
  V128Andnot
}

///|
pub fn Instruction::v128_or() -> Instruction {
  V128Or
}

///|
pub fn Instruction::v128_xor() -> Instruction {
  V128Xor
}

///|
pub fn Instruction::v128_bitselect() -> Instruction {
  V128Bitselect
}

///|
pub fn Instruction::v128_any_true() -> Instruction {
  V128AnyTrue
}

///|
pub fn Instruction::v128_load8_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load8Lane(ma, li)
}

///|
pub fn Instruction::v128_load16_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load16Lane(ma, li)
}

///|
pub fn Instruction::v128_load32_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load32Lane(ma, li)
}

///|
pub fn Instruction::v128_load64_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Load64Lane(ma, li)
}

///|
pub fn Instruction::v128_store8_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store8Lane(ma, li)
}

///|
pub fn Instruction::v128_store16_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store16Lane(ma, li)
}

///|
pub fn Instruction::v128_store32_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store32Lane(ma, li)
}

///|
pub fn Instruction::v128_store64_lane(ma : MemArg, li : LaneIdx) -> Instruction {
  V128Store64Lane(ma, li)
}

///|
pub fn Instruction::v128_load32_zero(ma : MemArg) -> Instruction {
  V128Load32Zero(ma)
}

///|
pub fn Instruction::v128_load64_zero(ma : MemArg) -> Instruction {
  V128Load64Zero(ma)
}

///|
pub fn Instruction::f32x4_demote_f64x2_zero() -> Instruction {
  F32x4DemoteF64x2Zero
}

///|
pub fn Instruction::f64x2_promote_low_f32x4() -> Instruction {
  F64x2PromoteLowF32x4
}

///|
pub fn Instruction::i8x16_abs() -> Instruction {
  I8x16Abs
}

///|
pub fn Instruction::i8x16_neg() -> Instruction {
  I8x16Neg
}

///|
pub fn Instruction::i8x16_popcnt() -> Instruction {
  I8x16Popcnt
}

///|
pub fn Instruction::i8x16_all_true() -> Instruction {
  I8x16AllTrue
}

///|
pub fn Instruction::i8x16_bitmask() -> Instruction {
  I8x16Bitmask
}

///|
pub fn Instruction::i8x16_narrow_i16x8s() -> Instruction {
  I8x16NarrowI16x8S
}

///|
pub fn Instruction::i8x16_narrow_i16x8u() -> Instruction {
  I8x16NarrowI16x8U
}

///|
pub fn Instruction::f32x4_ceil() -> Instruction {
  F32x4Ceil
}

///|
pub fn Instruction::f32x4_floor() -> Instruction {
  F32x4Floor
}

///|
pub fn Instruction::f32x4_trunc() -> Instruction {
  F32x4Trunc
}

///|
pub fn Instruction::f32x4_nearest() -> Instruction {
  F32x4Nearest
}

///|
pub fn Instruction::i8x16_shl() -> Instruction {
  I8x16Shl
}

///|
pub fn Instruction::i8x16_shr_s() -> Instruction {
  I8x16ShrS
}

///|
pub fn Instruction::i8x16_shr_u() -> Instruction {
  I8x16ShrU
}

///|
pub fn Instruction::i8x16_add() -> Instruction {
  I8x16Add
}

///|
pub fn Instruction::i8x16_add_sat_s() -> Instruction {
  I8x16AddSatS
}

///|
pub fn Instruction::i8x16_add_sat_u() -> Instruction {
  I8x16AddSatU
}

///|
pub fn Instruction::i8x16_sub() -> Instruction {
  I8x16Sub
}

///|
pub fn Instruction::i8x16_sub_sat_s() -> Instruction {
  I8x16SubSatS
}

///|
pub fn Instruction::i8x16_sub_sat_u() -> Instruction {
  I8x16SubSatU
}

///|
pub fn Instruction::f64x2_ceil() -> Instruction {
  F64x2Ceil
}

///|
pub fn Instruction::f64x2_floor() -> Instruction {
  F64x2Floor
}

///|
pub fn Instruction::i8x16_min_s() -> Instruction {
  I8x16MinS
}

///|
pub fn Instruction::i8x16_min_u() -> Instruction {
  I8x16MinU
}

///|
pub fn Instruction::i8x16_max_s() -> Instruction {
  I8x16MaxS
}

///|
pub fn Instruction::i8x16_max_u() -> Instruction {
  I8x16MaxU
}

///|
pub fn Instruction::f64x2_trunc() -> Instruction {
  F64x2Trunc
}

///|
pub fn Instruction::i8x16_avgr_u() -> Instruction {
  I8x16AvgrU
}

///|
pub fn Instruction::i16x8_extadd_pairwise_i8x16s() -> Instruction {
  I16x8ExtaddPairwiseI8x16S
}

///|
pub fn Instruction::i16x8_extadd_pairwise_i8x16u() -> Instruction {
  I16x8ExtaddPairwiseI8x16U
}

///|
pub fn Instruction::i32x4_extadd_pairwise_i16x8s() -> Instruction {
  I32x4ExtaddPairwiseI16x8S
}

///|
pub fn Instruction::i32x4_extadd_pairwise_i16x8u() -> Instruction {
  I32x4ExtaddPairwiseI16x8U
}

///|
pub fn Instruction::i16x8_abs() -> Instruction {
  I16x8Abs
}

///|
pub fn Instruction::i16x8_neg() -> Instruction {
  I16x8Neg
}

///|
pub fn Instruction::i16x8q15mulr_sat_s() -> Instruction {
  I16x8Q15mulrSatS
}

///|
pub fn Instruction::i16x8_all_true() -> Instruction {
  I16x8AllTrue
}

///|
pub fn Instruction::i16x8_bitmask() -> Instruction {
  I16x8Bitmask
}

///|
pub fn Instruction::i16x8_narrow_i32x4s() -> Instruction {
  I16x8NarrowI32x4S
}

///|
pub fn Instruction::i16x8_narrow_i32x4u() -> Instruction {
  I16x8NarrowI32x4U
}

///|
pub fn Instruction::i16x8_extend_low_i8x16s() -> Instruction {
  I16x8ExtendLowI8x16S
}

///|
pub fn Instruction::i16x8_extend_high_i8x16s() -> Instruction {
  I16x8ExtendHighI8x16S
}

///|
pub fn Instruction::i16x8_extend_low_i8x16u() -> Instruction {
  I16x8ExtendLowI8x16U
}

///|
pub fn Instruction::i16x8_extend_high_i8x16u() -> Instruction {
  I16x8ExtendHighI8x16U
}

///|
pub fn Instruction::i16x8_shl() -> Instruction {
  I16x8Shl
}

///|
pub fn Instruction::i16x8_shr_s() -> Instruction {
  I16x8ShrS
}

///|
pub fn Instruction::i16x8_shr_u() -> Instruction {
  I16x8ShrU
}

///|
pub fn Instruction::i16x8_add() -> Instruction {
  I16x8Add
}

///|
pub fn Instruction::i16x8_add_sat_s() -> Instruction {
  I16x8AddSatS
}

///|
pub fn Instruction::i16x8_add_sat_u() -> Instruction {
  I16x8AddSatU
}

///|
pub fn Instruction::i16x8_sub() -> Instruction {
  I16x8Sub
}

///|
pub fn Instruction::i16x8_sub_sat_s() -> Instruction {
  I16x8SubSatS
}

///|
pub fn Instruction::i16x8_sub_sat_u() -> Instruction {
  I16x8SubSatU
}

///|
pub fn Instruction::f64x2_nearest() -> Instruction {
  F64x2Nearest
}

///|
pub fn Instruction::i16x8_mul() -> Instruction {
  I16x8Mul
}

///|
pub fn Instruction::i16x8_min_s() -> Instruction {
  I16x8MinS
}

///|
pub fn Instruction::i16x8_min_u() -> Instruction {
  I16x8MinU
}

///|
pub fn Instruction::i16x8_max_s() -> Instruction {
  I16x8MaxS
}

///|
pub fn Instruction::i16x8_max_u() -> Instruction {
  I16x8MaxU
}

///|
pub fn Instruction::i16x8_avgr_u() -> Instruction {
  I16x8AvgrU
}

///|
pub fn Instruction::i16x8_extmul_low_i8x16s() -> Instruction {
  I16x8ExtmulLowI8x16S
}

///|
pub fn Instruction::i16x8_extmul_high_i8x16s() -> Instruction {
  I16x8ExtmulHighI8x16S
}

///|
pub fn Instruction::i16x8_extmul_low_i8x16u() -> Instruction {
  I16x8ExtmulLowI8x16U
}

///|
pub fn Instruction::i16x8_extmul_high_i8x16u() -> Instruction {
  I16x8ExtmulHighI8x16U
}

///|
pub fn Instruction::i32x4_abs() -> Instruction {
  I32x4Abs
}

///|
pub fn Instruction::i32x4_neg() -> Instruction {
  I32x4Neg
}

///|
pub fn Instruction::i32x4_all_true() -> Instruction {
  I32x4AllTrue
}

///|
pub fn Instruction::i32x4_bitmask() -> Instruction {
  I32x4Bitmask
}

///|
pub fn Instruction::i32x4_extend_low_i16x8s() -> Instruction {
  I32x4ExtendLowI16x8S
}

///|
pub fn Instruction::i32x4_extend_high_i16x8s() -> Instruction {
  I32x4ExtendHighI16x8S
}

///|
pub fn Instruction::i32x4_extend_low_i16x8u() -> Instruction {
  I32x4ExtendLowI16x8U
}

///|
pub fn Instruction::i32x4_extend_high_i16x8u() -> Instruction {
  I32x4ExtendHighI16x8U
}

///|
pub fn Instruction::i32x4_shl() -> Instruction {
  I32x4Shl
}

///|
pub fn Instruction::i32x4_shr_s() -> Instruction {
  I32x4ShrS
}

///|
pub fn Instruction::i32x4_shr_u() -> Instruction {
  I32x4ShrU
}

///|
pub fn Instruction::i32x4_add() -> Instruction {
  I32x4Add
}

///|
pub fn Instruction::i32x4_sub() -> Instruction {
  I32x4Sub
}

///|
pub fn Instruction::i32x4_mul() -> Instruction {
  I32x4Mul
}

///|
pub fn Instruction::i32x4_min_s() -> Instruction {
  I32x4MinS
}

///|
pub fn Instruction::i32x4_min_u() -> Instruction {
  I32x4MinU
}

///|
pub fn Instruction::i32x4_max_s() -> Instruction {
  I32x4MaxS
}

///|
pub fn Instruction::i32x4_max_u() -> Instruction {
  I32x4MaxU
}

///|
pub fn Instruction::i32x4_dot_i16x8s() -> Instruction {
  I32x4DotI16x8S
}

///|
pub fn Instruction::i32x4_extmul_low_i16x8s() -> Instruction {
  I32x4ExtmulLowI16x8S
}

///|
pub fn Instruction::i32x4_extmul_high_i16x8s() -> Instruction {
  I32x4ExtmulHighI16x8S
}

///|
pub fn Instruction::i32x4_extmul_low_i16x8u() -> Instruction {
  I32x4ExtmulLowI16x8U
}

///|
pub fn Instruction::i32x4_extmul_high_i16x8u() -> Instruction {
  I32x4ExtmulHighI16x8U
}

///|
pub fn Instruction::i64x2_abs() -> Instruction {
  I64x2Abs
}

///|
pub fn Instruction::i64x2_neg() -> Instruction {
  I64x2Neg
}

///|
pub fn Instruction::i64x2_all_true() -> Instruction {
  I64x2AllTrue
}

///|
pub fn Instruction::i64x2_bitmask() -> Instruction {
  I64x2Bitmask
}

///|
pub fn Instruction::i64x2_extend_low_i32x4s() -> Instruction {
  I64x2ExtendLowI32x4S
}

///|
pub fn Instruction::i64x2_extend_high_i32x4s() -> Instruction {
  I64x2ExtendHighI32x4S
}

///|
pub fn Instruction::i64x2_extend_low_i32x4u() -> Instruction {
  I64x2ExtendLowI32x4U
}

///|
pub fn Instruction::i64x2_extend_high_i32x4u() -> Instruction {
  I64x2ExtendHighI32x4U
}

///|
pub fn Instruction::i64x2_shl() -> Instruction {
  I64x2Shl
}

///|
pub fn Instruction::i64x2_shr_s() -> Instruction {
  I64x2ShrS
}

///|
pub fn Instruction::i64x2_shr_u() -> Instruction {
  I64x2ShrU
}

///|
pub fn Instruction::i64x2_add() -> Instruction {
  I64x2Add
}

///|
pub fn Instruction::i64x2_sub() -> Instruction {
  I64x2Sub
}

///|
pub fn Instruction::i64x2_mul() -> Instruction {
  I64x2Mul
}

///|
pub fn Instruction::i64x2_eq() -> Instruction {
  I64x2Eq
}

///|
pub fn Instruction::i64x2_ne() -> Instruction {
  I64x2Ne
}

///|
pub fn Instruction::i64x2_lt_s() -> Instruction {
  I64x2LtS
}

///|
pub fn Instruction::i64x2_gt_s() -> Instruction {
  I64x2GtS
}

///|
pub fn Instruction::i64x2_le_s() -> Instruction {
  I64x2LeS
}

///|
pub fn Instruction::i64x2_ge_s() -> Instruction {
  I64x2GeS
}

///|
pub fn Instruction::i64x2_extmul_low_i32x4s() -> Instruction {
  I64x2ExtmulLowI32x4S
}

///|
pub fn Instruction::i64x2_extmul_high_i32x4s() -> Instruction {
  I64x2ExtmulHighI32x4S
}

///|
pub fn Instruction::i64x2_extmul_low_i32x4u() -> Instruction {
  I64x2ExtmulLowI32x4U
}

///|
pub fn Instruction::i64x2_extmul_high_i32x4u() -> Instruction {
  I64x2ExtmulHighI32x4U
}

///|
pub fn Instruction::f32x4_abs() -> Instruction {
  F32x4Abs
}

///|
pub fn Instruction::f32x4_neg() -> Instruction {
  F32x4Neg
}

///|
pub fn Instruction::f32x4_sqrt() -> Instruction {
  F32x4Sqrt
}

///|
pub fn Instruction::f32x4_add() -> Instruction {
  F32x4Add
}

///|
pub fn Instruction::f32x4_sub() -> Instruction {
  F32x4Sub
}

///|
pub fn Instruction::f32x4_mul() -> Instruction {
  F32x4Mul
}

///|
pub fn Instruction::f32x4_div() -> Instruction {
  F32x4Div
}

///|
pub fn Instruction::f32x4_min() -> Instruction {
  F32x4Min
}

///|
pub fn Instruction::f32x4_max() -> Instruction {
  F32x4Max
}

///|
pub fn Instruction::f32x4_pmin() -> Instruction {
  F32x4Pmin
}

///|
pub fn Instruction::f32x4_pmax() -> Instruction {
  F32x4Pmax
}

///|
pub fn Instruction::f64x2_abs() -> Instruction {
  F64x2Abs
}

///|
pub fn Instruction::f64x2_neg() -> Instruction {
  F64x2Neg
}

///|
pub fn Instruction::f64x2_sqrt() -> Instruction {
  F64x2Sqrt
}

///|
pub fn Instruction::f64x2_add() -> Instruction {
  F64x2Add
}

///|
pub fn Instruction::f64x2_sub() -> Instruction {
  F64x2Sub
}

///|
pub fn Instruction::f64x2_mul() -> Instruction {
  F64x2Mul
}

///|
pub fn Instruction::f64x2_div() -> Instruction {
  F64x2Div
}

///|
pub fn Instruction::f64x2_min() -> Instruction {
  F64x2Min
}

///|
pub fn Instruction::f64x2_max() -> Instruction {
  F64x2Max
}

///|
pub fn Instruction::f64x2_pmin() -> Instruction {
  F64x2Pmin
}

///|
pub fn Instruction::f64x2_pmax() -> Instruction {
  F64x2Pmax
}

///|
pub fn Instruction::i32x4_trunc_sat_f32x4s() -> Instruction {
  I32x4TruncSatF32x4S
}

///|
pub fn Instruction::i32x4_trunc_sat_f32x4u() -> Instruction {
  I32x4TruncSatF32x4U
}

///|
pub fn Instruction::f32x4_convert_i32x4s() -> Instruction {
  F32x4ConvertI32x4S
}

///|
pub fn Instruction::f32x4_convert_i32x4u() -> Instruction {
  F32x4ConvertI32x4U
}

///|
pub fn Instruction::i32x4_trunc_sat_f64x2s_zero() -> Instruction {
  I32x4TruncSatF64x2SZero
}

///|
pub fn Instruction::i32x4_trunc_sat_f64x2u_zero() -> Instruction {
  I32x4TruncSatF64x2UZero
}

///|
pub fn Instruction::f64x2_convert_low_i32x4s() -> Instruction {
  F64x2ConvertLowI32x4S
}

///|
pub fn Instruction::f64x2_convert_low_i32x4u() -> Instruction {
  F64x2ConvertLowI32x4U
}

///|
pub fn Instruction::i8x16_relaxed_swizzle() -> Instruction {
  I8x16RelaxedSwizzle
}

///|
pub fn Instruction::i32x4_relaxed_trunc_f32x4s() -> Instruction {
  I32x4RelaxedTruncF32x4S
}

///|
pub fn Instruction::i32x4_relaxed_trunc_f32x4u() -> Instruction {
  I32x4RelaxedTruncF32x4U
}

///|
pub fn Instruction::i32x4_relaxed_trunc_zero_f64x2s() -> Instruction {
  I32x4RelaxedTruncZeroF64x2S
}

///|
pub fn Instruction::i32x4_relaxed_trunc_zero_f64x2u() -> Instruction {
  I32x4RelaxedTruncZeroF64x2U
}

///|
pub fn Instruction::f32x4_relaxed_madd() -> Instruction {
  F32x4RelaxedMadd
}

///|
pub fn Instruction::f32x4_relaxed_nmadd() -> Instruction {
  F32x4RelaxedNmadd
}

///|
pub fn Instruction::f64x2_relaxed_madd() -> Instruction {
  F64x2RelaxedMadd
}

///|
pub fn Instruction::f64x2_relaxed_nmadd() -> Instruction {
  F64x2RelaxedNmadd
}

///|
pub fn Instruction::i8x16_relaxed_laneselect() -> Instruction {
  I8x16RelaxedLaneselect
}

///|
pub fn Instruction::i16x8_relaxed_laneselect() -> Instruction {
  I16x8RelaxedLaneselect
}

///|
pub fn Instruction::i32x4_relaxed_laneselect() -> Instruction {
  I32x4RelaxedLaneselect
}

///|
pub fn Instruction::i64x2_relaxed_laneselect() -> Instruction {
  I64x2RelaxedLaneselect
}

///|
pub fn Instruction::f32x4_relaxed_min() -> Instruction {
  F32x4RelaxedMin
}

///|
pub fn Instruction::f32x4_relaxed_max() -> Instruction {
  F32x4RelaxedMax
}

///|
pub fn Instruction::f64x2_relaxed_min() -> Instruction {
  F64x2RelaxedMin
}

///|
pub fn Instruction::f64x2_relaxed_max() -> Instruction {
  F64x2RelaxedMax
}

///|
pub fn Instruction::i16x8_relaxed_q15mulr_s() -> Instruction {
  I16x8RelaxedQ15mulrS
}

///|
pub fn Instruction::i16x8_relaxed_dot_i8x16i7x16s() -> Instruction {
  I16x8RelaxedDotI8x16I7x16S
}

///|
pub fn Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s() -> Instruction {
  I32x4RelaxedDotI8x16I7x16AddS
}

///|
pub fn TInstr::i32_const(val : I32) -> TInstr {
  TI32Const(val)
}

///|
pub fn TInstr::i64_const(val : I64) -> TInstr {
  TI64Const(val)
}

///|
pub fn TInstr::f32_const(val : F32) -> TInstr {
  TF32Const(val)
}

///|
pub fn TInstr::f64_const(val : F64) -> TInstr {
  TF64Const(val)
}

///|
pub fn TInstr::ref_null(val : HeapType) -> TInstr {
  TRefNull(val)
}

///|
pub fn TInstr::ref_func(val : FuncIdx) -> TInstr {
  TRefFunc(val)
}

///|
pub fn TInstr::v128_const(
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
pub fn TInstr::unreachable_() -> TInstr {
  TUnreachable
}

///|
pub fn TInstr::nop() -> TInstr {
  TNop
}

///|
pub fn TInstr::local_get(idx : LocalIdx) -> TInstr {
  TLocalGet(idx)
}

///|
pub fn TInstr::global_get(idx : GlobalIdx) -> TInstr {
  TGlobalGet(idx)
}

///|
pub fn TInstr::memory_size(idx : MemIdx) -> TInstr {
  TMemorySize(idx)
}

///|
pub fn TInstr::table_size(idx : TableIdx) -> TInstr {
  TTableSize(idx)
}

///|
pub fn TInstr::unary(op : UnaryOp, i : TInstr) -> TInstr {
  TUnary(op, i)
}

///|
pub fn TInstr::drop(i : TInstr) -> TInstr {
  TDrop(i)
}

///|
pub fn TInstr::local_set(idx : LocalIdx, i : TInstr) -> TInstr {
  TLocalSet(idx, i)
}

///|
pub fn TInstr::local_tee(idx : LocalIdx, i : TInstr) -> TInstr {
  TLocalTee(idx, i)
}

///|
pub fn TInstr::global_set(idx : GlobalIdx, i : TInstr) -> TInstr {
  TGlobalSet(idx, i)
}

///|
pub fn TInstr::ref_is_null(i : TInstr) -> TInstr {
  TRefIsNull(i)
}

///|
pub fn TInstr::ref_as_non_null(i : TInstr) -> TInstr {
  TRefAsNonNull(i)
}

///|
pub fn TInstr::i31_get_s(i : TInstr) -> TInstr {
  TI31GetS(i)
}

///|
pub fn TInstr::i31_get_u(i : TInstr) -> TInstr {
  TI31GetU(i)
}

///|
pub fn TInstr::ref_i31(i : TInstr) -> TInstr {
  TRefI31(i)
}

///|
pub fn TInstr::array_len(i : TInstr) -> TInstr {
  TArrayLen(i)
}

///|
pub fn TInstr::any_convert_extern(i : TInstr) -> TInstr {
  TAnyConvertExtern(i)
}

///|
pub fn TInstr::extern_convert_any(i : TInstr) -> TInstr {
  TExternConvertAny(i)
}

///|
pub fn TInstr::throw_ref(i : TInstr) -> TInstr {
  TThrowRef(i)
}

///|
pub fn TInstr::binary(op : BinaryOp, i0 : TInstr, i1 : TInstr) -> TInstr {
  TBinary(op, i0, i1)
}

///|
pub fn TInstr::ref_eq(i0 : TInstr, i1 : TInstr) -> TInstr {
  TRefEq(i0, i1)
}

///|
pub fn TInstr::store(
  op : StoreOp,
  ma : MemArg,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TStore(op, ma, i0, i1)
}

///|
pub fn TInstr::load(op : LoadOp, ma : MemArg, i : TInstr) -> TInstr {
  TLoad(op, ma, i)
}

///|
pub fn TInstr::memory_grow(mi : MemIdx, i : TInstr) -> TInstr {
  TMemoryGrow(mi, i)
}

///|
pub fn TInstr::memory_fill(
  mi : MemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryFill(mi, i0, i1, i2)
}

///|
pub fn TInstr::memory_copy(
  mi0 : MemIdx,
  mi1 : MemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryCopy(mi0, mi1, i0, i1, i2)
}

///|
pub fn TInstr::memory_init(
  di : DataIdx,
  mi : MemIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryInit(di, mi, i0, i1, i2)
}

///|
pub fn TInstr::data_drop(di : DataIdx) -> TInstr {
  TDataDrop(di)
}

///|
pub fn TInstr::memory_atomic_notify(
  ma : MemArg,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TMemoryAtomicNotify(ma, i0, i1)
}

///|
pub fn TInstr::memory_atomic_wait32(
  ma : MemArg,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryAtomicWait32(ma, i0, i1, i2)
}

///|
pub fn TInstr::memory_atomic_wait64(
  ma : MemArg,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TMemoryAtomicWait64(ma, i0, i1, i2)
}

///|
pub fn TInstr::atomic_fence() -> TInstr {
  TAtomicFence
}

///|
pub fn TInstr::atomic_rmw(
  op : AtomicRmwOp,
  ma : MemArg,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TAtomicRmw(op, ma, i0, i1)
}

///|
pub fn TInstr::atomic_cmpxchg(
  op : AtomicCmpxchgOp,
  ma : MemArg,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TAtomicCmpxchg(op, ma, i0, i1, i2)
}

///|
pub fn TInstr::table_get(ti : TableIdx, i : TInstr) -> TInstr {
  TTableGet(ti, i)
}

///|
pub fn TInstr::table_set(ti : TableIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TTableSet(ti, i0, i1)
}

///|
pub fn TInstr::table_grow(ti : TableIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TTableGrow(ti, i0, i1)
}

///|
pub fn TInstr::table_fill(
  ti : TableIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TTableFill(ti, i0, i1, i2)
}

///|
pub fn TInstr::table_copy(
  ti0 : TableIdx,
  ti1 : TableIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TTableCopy(ti0, ti1, i0, i1, i2)
}

///|
pub fn TInstr::table_init(
  ei : ElemIdx,
  ti : TableIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TTableInit(ei, ti, i0, i1, i2)
}

///|
pub fn TInstr::elem_drop(ei : ElemIdx) -> TInstr {
  TElemDrop(ei)
}

///|
pub fn TInstr::call(di : FuncIdx, props : Array[TInstr]) -> TInstr {
  TCall(di, props)
}

///|
pub fn TInstr::call_indirect(
  ty_i : TypeIdx,
  tbl_i : TableIdx,
  props : Array[TInstr],
  i : TInstr,
) -> TInstr {
  TCallIndirect(ty_i, tbl_i, props, i)
}

///|
pub fn TInstr::call_ref(
  ti : TypeIdx,
  props : Array[TInstr],
  r : TInstr,
) -> TInstr {
  TCallRef(ti, props, r)
}

///|
pub fn TInstr::return_call(fi : FuncIdx, props : Array[TInstr]) -> TInstr {
  TReturnCall(fi, props)
}

///|
pub fn TInstr::return_call_indirect(
  ty_i : TypeIdx,
  tbl_i : TableIdx,
  props : Array[TInstr],
  i : TInstr,
) -> TInstr {
  TReturnCallIndirect(ty_i, tbl_i, props, i)
}

///|
pub fn TInstr::return_call_ref(
  ti : TypeIdx,
  props : Array[TInstr],
  i : TInstr,
) -> TInstr {
  TReturnCallRef(ti, props, i)
}

///|
pub fn TInstr::block(bt : BlockType, e : TExpr) -> TInstr {
  TBlock(bt, e)
}

///|
pub fn TInstr::loop_(bt : BlockType, e : TExpr) -> TInstr {
  TLoop(bt, e)
}

///|
pub fn TInstr::if_(
  bt : BlockType,
  i : TInstr,
  e0 : TExpr,
  e1_opt : TExpr?,
) -> TInstr {
  TIf(bt, i, e0, e1_opt)
}

///|
pub fn TInstr::try_table(bt : BlockType, c : Array[Catch], e : TExpr) -> TInstr {
  TTryTable(bt, c, e)
}

///|
pub fn TInstr::throw_(ti : TagIdx, i : Array[TInstr]) -> TInstr {
  TThrow(ti, i)
}

///|
pub fn TInstr::br(li : LabelIdx, i : Array[TInstr]) -> TInstr {
  TBr(li, i)
}

///|
pub fn TInstr::br_if(li : LabelIdx, i0 : TInstr, i : Array[TInstr]) -> TInstr {
  TBrIf(li, i0, i)
}

///|
pub fn TInstr::br_table(
  l : Array[LabelIdx],
  l0 : LabelIdx,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrTable(l, l0, i0, i)
}

///|
pub fn TInstr::br_on_null(
  li : LabelIdx,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrOnNull(li, i0, i)
}

///|
pub fn TInstr::br_on_non_null(
  li : LabelIdx,
  i0 : TInstr,
  i : Array[TInstr],
) -> TInstr {
  TBrOnNonNull(li, i0, i)
}

///|
pub fn TInstr::br_on_cast(
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
pub fn TInstr::br_on_cast_fail(
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
pub fn TInstr::return_(i : Array[TInstr]) -> TInstr {
  TReturn(i)
}

///|
pub fn TInstr::select(
  tys : Array[ValType]?,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TSelect(tys, i0, i1, i2)
}

///|
pub fn TInstr::struct_new(ti : TypeIdx, i : Array[TInstr]) -> TInstr {
  TStructNew(ti, i)
}

///|
pub fn TInstr::struct_new_default(ti : TypeIdx) -> TInstr {
  TStructNewDefault(ti)
}

///|
pub fn TInstr::struct_get(ti : TypeIdx, idx : U32, i : TInstr) -> TInstr {
  TStructGet(ti, idx, i)
}

///|
pub fn TInstr::struct_get_s(ti : TypeIdx, idx : U32, i : TInstr) -> TInstr {
  TStructGetS(ti, idx, i)
}

///|
pub fn TInstr::struct_get_u(ti : TypeIdx, idx : U32, i : TInstr) -> TInstr {
  TStructGetU(ti, idx, i)
}

///|
pub fn TInstr::struct_set(
  ti : TypeIdx,
  idx : U32,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TStructSet(ti, idx, i0, i1)
}

///|
pub fn TInstr::array_new(ti : TypeIdx, t0 : TInstr, t1 : TInstr) -> TInstr {
  TArrayNew(ti, t0, t1)
}

///|
pub fn TInstr::array_new_default(ti : TypeIdx, i : TInstr) -> TInstr {
  TArrayNewDefault(ti, i)
}

///|
pub fn TInstr::array_new_fixed(ti : TypeIdx, i : Array[TInstr]) -> TInstr {
  TArrayNewFixed(ti, i)
}

///|
pub fn TInstr::array_new_data(
  ti : TypeIdx,
  di : DataIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TArrayNewData(ti, di, i0, i1)
}

///|
pub fn TInstr::array_new_elem(
  ti : TypeIdx,
  ei : ElemIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TArrayNewElem(ti, ei, i0, i1)
}

///|
pub fn TInstr::array_get(ti : TypeIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TArrayGet(ti, i0, i1)
}

///|
pub fn TInstr::array_get_s(ti : TypeIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TArrayGetS(ti, i0, i1)
}

///|
pub fn TInstr::array_get_u(ti : TypeIdx, i0 : TInstr, i1 : TInstr) -> TInstr {
  TArrayGetU(ti, i0, i1)
}

///|
pub fn TInstr::array_set(
  ti : TypeIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TArraySet(ti, i0, i1, i2)
}

///|
pub fn TInstr::array_fill(
  ti : TypeIdx,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
  i3 : TInstr,
) -> TInstr {
  TArrayFill(ti, i0, i1, i2, i3)
}

///|
pub fn TInstr::array_copy(
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
pub fn TInstr::array_init_data(
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
pub fn TInstr::array_init_elem(
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
pub fn TInstr::ref_get_desc(i : TInstr) -> TInstr {
  TRefGetDesc(i)
}

///|
pub fn TInstr::ref_test(nullable : Bool, ht : HeapType, i : TInstr) -> TInstr {
  TRefTest(nullable, ht, i)
}

///|
pub fn TInstr::ref_cast(nullable : Bool, ht : HeapType, i : TInstr) -> TInstr {
  TRefCast(nullable, ht, i)
}

///|
pub fn TInstr::ref_test_desc(
  nullable : Bool,
  ht : HeapType,
  i : TInstr,
) -> TInstr {
  TRefTestDesc(nullable, ht, i)
}

///|
pub fn TInstr::ref_cast_desc_eq(
  nullable : Bool,
  ht : HeapType,
  i : TInstr,
) -> TInstr {
  TRefCastDescEq(nullable, ht, i)
}

// === SIMD: Splat (scalar -> v128) ===

///|
pub fn TInstr::i8x16_splat(i : TInstr) -> TInstr {
  TI8x16Splat(i)
}

///|
pub fn TInstr::i16x8_splat(i : TInstr) -> TInstr {
  TI16x8Splat(i)
}

///|
pub fn TInstr::i32x4_splat(i : TInstr) -> TInstr {
  TI32x4Splat(i)
}

///|
pub fn TInstr::i64x2_splat(i : TInstr) -> TInstr {
  TI64x2Splat(i)
}

///|
pub fn TInstr::f32x4_splat(i : TInstr) -> TInstr {
  TF32x4Splat(i)
}

///|
pub fn TInstr::f64x2_splat(i : TInstr) -> TInstr {
  TF64x2Splat(i)
}

///|
pub fn TInstr::extract_lane(
  op : ExtractLaneOp,
  li : LaneIdx,
  i : TInstr,
) -> TInstr {
  TExtractLane(op, li, i)
}

///|
pub fn TInstr::replace_lane(
  op : ReplaceLaneOp,
  li : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TReplaceLane(op, li, i0, i1)
}

///|
pub fn TInstr::i8x16_shuffle(
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
pub fn TInstr::i8x16_swizzle(i0 : TInstr, i1 : TInstr) -> TInstr {
  TI8x16Swizzle(i0, i1)
}

///|
pub fn TInstr::i8x16_relaxed_swizzle(i0 : TInstr, i1 : TInstr) -> TInstr {
  TI8x16RelaxedSwizzle(i0, i1)
}

///|
pub fn TInstr::v128_shift(op : V128ShiftOp, i0 : TInstr, i1 : TInstr) -> TInstr {
  TV128Shift(op, i0, i1)
}

///|
pub fn TInstr::v128_ternary(
  op : V128TernaryOp,
  i0 : TInstr,
  i1 : TInstr,
  i2 : TInstr,
) -> TInstr {
  TV128Ternary(op, i0, i1, i2)
}

///|
pub fn TInstr::v128_load_lane(
  op : V128LoadLaneOp,
  ma : MemArg,
  li : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TV128LoadLane(op, ma, li, i0, i1)
}

///|
pub fn TInstr::v128_store_lane(
  op : V128StoreLaneOp,
  ma : MemArg,
  li : LaneIdx,
  i0 : TInstr,
  i1 : TInstr,
) -> TInstr {
  TV128StoreLane(op, ma, li, i0, i1)
}

///|
pub fn UnaryOp::i32_eqz() -> UnaryOp {
  I32EqzOp
}

///|
pub fn UnaryOp::i64_eqz() -> UnaryOp {
  I64EqzOp
}

///|
pub fn UnaryOp::i32_clz() -> UnaryOp {
  I32ClzOp
}

///|
pub fn UnaryOp::i32_ctz() -> UnaryOp {
  I32CtzOp
}

///|
pub fn UnaryOp::i32_popcnt() -> UnaryOp {
  I32PopcntOp
}

///|
pub fn UnaryOp::i64_clz() -> UnaryOp {
  I64ClzOp
}

///|
pub fn UnaryOp::i64_ctz() -> UnaryOp {
  I64CtzOp
}

///|
pub fn UnaryOp::i64_popcnt() -> UnaryOp {
  I64PopcntOp
}

///|
pub fn UnaryOp::f32_abs() -> UnaryOp {
  F32AbsOp
}

///|
pub fn UnaryOp::f32_neg() -> UnaryOp {
  F32NegOp
}

///|
pub fn UnaryOp::f32_ceil() -> UnaryOp {
  F32CeilOp
}

///|
pub fn UnaryOp::f32_floor() -> UnaryOp {
  F32FloorOp
}

///|
pub fn UnaryOp::f32_trunc() -> UnaryOp {
  F32TruncOp
}

///|
pub fn UnaryOp::f32_nearest() -> UnaryOp {
  F32NearestOp
}

///|
pub fn UnaryOp::f32_sqrt() -> UnaryOp {
  F32SqrtOp
}

///|
pub fn UnaryOp::f64_abs() -> UnaryOp {
  F64AbsOp
}

///|
pub fn UnaryOp::f64_neg() -> UnaryOp {
  F64NegOp
}

///|
pub fn UnaryOp::f64_ceil() -> UnaryOp {
  F64CeilOp
}

///|
pub fn UnaryOp::f64_floor() -> UnaryOp {
  F64FloorOp
}

///|
pub fn UnaryOp::f64_trunc() -> UnaryOp {
  F64TruncOp
}

///|
pub fn UnaryOp::f64_nearest() -> UnaryOp {
  F64NearestOp
}

///|
pub fn UnaryOp::f64_sqrt() -> UnaryOp {
  F64SqrtOp
}

///|
pub fn UnaryOp::i32_wrap_i64() -> UnaryOp {
  I32WrapI64Op
}

///|
pub fn UnaryOp::i32_trunc_f32s() -> UnaryOp {
  I32TruncF32SOp
}

///|
pub fn UnaryOp::i32_trunc_f32u() -> UnaryOp {
  I32TruncF32UOp
}

///|
pub fn UnaryOp::i32_trunc_f64s() -> UnaryOp {
  I32TruncF64SOp
}

///|
pub fn UnaryOp::i32_trunc_f64u() -> UnaryOp {
  I32TruncF64UOp
}

///|
pub fn UnaryOp::i64_extend_i32s() -> UnaryOp {
  I64ExtendI32SOp
}

///|
pub fn UnaryOp::i64_extend_i32u() -> UnaryOp {
  I64ExtendI32UOp
}

///|
pub fn UnaryOp::i64_trunc_f32s() -> UnaryOp {
  I64TruncF32SOp
}

///|
pub fn UnaryOp::i64_trunc_f32u() -> UnaryOp {
  I64TruncF32UOp
}

///|
pub fn UnaryOp::i64_trunc_f64s() -> UnaryOp {
  I64TruncF64SOp
}

///|
pub fn UnaryOp::i64_trunc_f64u() -> UnaryOp {
  I64TruncF64UOp
}

///|
pub fn UnaryOp::f32_convert_i32s() -> UnaryOp {
  F32ConvertI32SOp
}

///|
pub fn UnaryOp::f32_convert_i32u() -> UnaryOp {
  F32ConvertI32UOp
}

///|
pub fn UnaryOp::f32_convert_i64s() -> UnaryOp {
  F32ConvertI64SOp
}

///|
pub fn UnaryOp::f32_convert_i64u() -> UnaryOp {
  F32ConvertI64UOp
}

///|
pub fn UnaryOp::f32_demote_f64() -> UnaryOp {
  F32DemoteF64Op
}

///|
pub fn UnaryOp::f64_convert_i32s() -> UnaryOp {
  F64ConvertI32SOp
}

///|
pub fn UnaryOp::f64_convert_i32u() -> UnaryOp {
  F64ConvertI32UOp
}

///|
pub fn UnaryOp::f64_convert_i64s() -> UnaryOp {
  F64ConvertI64SOp
}

///|
pub fn UnaryOp::f64_convert_i64u() -> UnaryOp {
  F64ConvertI64UOp
}

///|
pub fn UnaryOp::f64_promote_f32() -> UnaryOp {
  F64PromoteF32Op
}

///|
pub fn UnaryOp::i32_reinterpret_f32() -> UnaryOp {
  I32ReinterpretF32Op
}

///|
pub fn UnaryOp::i64_reinterpret_f64() -> UnaryOp {
  I64ReinterpretF64Op
}

///|
pub fn UnaryOp::f32_reinterpret_i32() -> UnaryOp {
  F32ReinterpretI32Op
}

///|
pub fn UnaryOp::f64_reinterpret_i64() -> UnaryOp {
  F64ReinterpretI64Op
}

///|
pub fn UnaryOp::i32_extend8s() -> UnaryOp {
  I32Extend8SOp
}

///|
pub fn UnaryOp::i32_extend16s() -> UnaryOp {
  I32Extend16SOp
}

///|
pub fn UnaryOp::i64_extend8s() -> UnaryOp {
  I64Extend8SOp
}

///|
pub fn UnaryOp::i64_extend16s() -> UnaryOp {
  I64Extend16SOp
}

///|
pub fn UnaryOp::i64_extend32s() -> UnaryOp {
  I64Extend32SOp
}

///|
pub fn UnaryOp::i32_trunc_sat_f32s() -> UnaryOp {
  I32TruncSatF32SOp
}

///|
pub fn UnaryOp::i32_trunc_sat_f32u() -> UnaryOp {
  I32TruncSatF32UOp
}

///|
pub fn UnaryOp::i32_trunc_sat_f64s() -> UnaryOp {
  I32TruncSatF64SOp
}

///|
pub fn UnaryOp::i32_trunc_sat_f64u() -> UnaryOp {
  I32TruncSatF64UOp
}

///|
pub fn UnaryOp::i64_trunc_sat_f32s() -> UnaryOp {
  I64TruncSatF32SOp
}

///|
pub fn UnaryOp::i64_trunc_sat_f32u() -> UnaryOp {
  I64TruncSatF32UOp
}

///|
pub fn UnaryOp::i64_trunc_sat_f64s() -> UnaryOp {
  I64TruncSatF64SOp
}

///|
pub fn UnaryOp::i64_trunc_sat_f64u() -> UnaryOp {
  I64TruncSatF64UOp
}

///|
pub fn UnaryOp::v128_not() -> UnaryOp {
  V128NotOp
}

///|
pub fn UnaryOp::i8x16_abs() -> UnaryOp {
  I8x16AbsOp
}

///|
pub fn UnaryOp::i8x16_neg() -> UnaryOp {
  I8x16NegOp
}

///|
pub fn UnaryOp::i8x16_popcnt() -> UnaryOp {
  I8x16PopcntOp
}

///|
pub fn UnaryOp::i16x8_abs() -> UnaryOp {
  I16x8AbsOp
}

///|
pub fn UnaryOp::i16x8_neg() -> UnaryOp {
  I16x8NegOp
}

///|
pub fn UnaryOp::i32x4_abs() -> UnaryOp {
  I32x4AbsOp
}

///|
pub fn UnaryOp::i32x4_neg() -> UnaryOp {
  I32x4NegOp
}

///|
pub fn UnaryOp::i64x2_abs() -> UnaryOp {
  I64x2AbsOp
}

///|
pub fn UnaryOp::i64x2_neg() -> UnaryOp {
  I64x2NegOp
}

///|
pub fn UnaryOp::f32x4_abs() -> UnaryOp {
  F32x4AbsOp
}

///|
pub fn UnaryOp::f32x4_neg() -> UnaryOp {
  F32x4NegOp
}

///|
pub fn UnaryOp::f32x4_sqrt() -> UnaryOp {
  F32x4SqrtOp
}

///|
pub fn UnaryOp::f32x4_ceil() -> UnaryOp {
  F32x4CeilOp
}

///|
pub fn UnaryOp::f32x4_floor() -> UnaryOp {
  F32x4FloorOp
}

///|
pub fn UnaryOp::f32x4_trunc() -> UnaryOp {
  F32x4TruncOp
}

///|
pub fn UnaryOp::f32x4_nearest() -> UnaryOp {
  F32x4NearestOp
}

///|
pub fn UnaryOp::f64x2_abs() -> UnaryOp {
  F64x2AbsOp
}

///|
pub fn UnaryOp::f64x2_neg() -> UnaryOp {
  F64x2NegOp
}

///|
pub fn UnaryOp::f64x2_sqrt() -> UnaryOp {
  F64x2SqrtOp
}

///|
pub fn UnaryOp::f64x2_ceil() -> UnaryOp {
  F64x2CeilOp
}

///|
pub fn UnaryOp::f64x2_floor() -> UnaryOp {
  F64x2FloorOp
}

///|
pub fn UnaryOp::f64x2_trunc() -> UnaryOp {
  F64x2TruncOp
}

///|
pub fn UnaryOp::f64x2_nearest() -> UnaryOp {
  F64x2NearestOp
}

///|
pub fn UnaryOp::v128_any_true() -> UnaryOp {
  V128AnyTrueOp
}

///|
pub fn UnaryOp::i8x16_all_true() -> UnaryOp {
  I8x16AllTrueOp
}

///|
pub fn UnaryOp::i8x16_bitmask() -> UnaryOp {
  I8x16BitmaskOp
}

///|
pub fn UnaryOp::i16x8_all_true() -> UnaryOp {
  I16x8AllTrueOp
}

///|
pub fn UnaryOp::i16x8_bitmask() -> UnaryOp {
  I16x8BitmaskOp
}

///|
pub fn UnaryOp::i32x4_all_true() -> UnaryOp {
  I32x4AllTrueOp
}

///|
pub fn UnaryOp::i32x4_bitmask() -> UnaryOp {
  I32x4BitmaskOp
}

///|
pub fn UnaryOp::i64x2_all_true() -> UnaryOp {
  I64x2AllTrueOp
}

///|
pub fn UnaryOp::i64x2_bitmask() -> UnaryOp {
  I64x2BitmaskOp
}

///|
pub fn UnaryOp::i16x8_extend_low_i8x16s() -> UnaryOp {
  I16x8ExtendLowI8x16SOp
}

///|
pub fn UnaryOp::i16x8_extend_high_i8x16s() -> UnaryOp {
  I16x8ExtendHighI8x16SOp
}

///|
pub fn UnaryOp::i16x8_extend_low_i8x16u() -> UnaryOp {
  I16x8ExtendLowI8x16UOp
}

///|
pub fn UnaryOp::i16x8_extend_high_i8x16u() -> UnaryOp {
  I16x8ExtendHighI8x16UOp
}

///|
pub fn UnaryOp::i32x4_extend_low_i16x8s() -> UnaryOp {
  I32x4ExtendLowI16x8SOp
}

///|
pub fn UnaryOp::i32x4_extend_high_i16x8s() -> UnaryOp {
  I32x4ExtendHighI16x8SOp
}

///|
pub fn UnaryOp::i32x4_extend_low_i16x8u() -> UnaryOp {
  I32x4ExtendLowI16x8UOp
}

///|
pub fn UnaryOp::i32x4_extend_high_i16x8u() -> UnaryOp {
  I32x4ExtendHighI16x8UOp
}

///|
pub fn UnaryOp::i64x2_extend_low_i32x4s() -> UnaryOp {
  I64x2ExtendLowI32x4SOp
}

///|
pub fn UnaryOp::i64x2_extend_high_i32x4s() -> UnaryOp {
  I64x2ExtendHighI32x4SOp
}

///|
pub fn UnaryOp::i64x2_extend_low_i32x4u() -> UnaryOp {
  I64x2ExtendLowI32x4UOp
}

///|
pub fn UnaryOp::i64x2_extend_high_i32x4u() -> UnaryOp {
  I64x2ExtendHighI32x4UOp
}

///|
pub fn UnaryOp::i16x8_extadd_pairwise_i8x16s() -> UnaryOp {
  I16x8ExtaddPairwiseI8x16SOp
}

///|
pub fn UnaryOp::i16x8_extadd_pairwise_i8x16u() -> UnaryOp {
  I16x8ExtaddPairwiseI8x16UOp
}

///|
pub fn UnaryOp::i32x4_extadd_pairwise_i16x8s() -> UnaryOp {
  I32x4ExtaddPairwiseI16x8SOp
}

///|
pub fn UnaryOp::i32x4_extadd_pairwise_i16x8u() -> UnaryOp {
  I32x4ExtaddPairwiseI16x8UOp
}

///|
pub fn UnaryOp::f32x4_demote_f64x2_zero() -> UnaryOp {
  F32x4DemoteF64x2ZeroOp
}

///|
pub fn UnaryOp::f64x2_promote_low_f32x4() -> UnaryOp {
  F64x2PromoteLowF32x4Op
}

///|
pub fn UnaryOp::i32x4_trunc_sat_f32x4s() -> UnaryOp {
  I32x4TruncSatF32x4SOp
}

///|
pub fn UnaryOp::i32x4_trunc_sat_f32x4u() -> UnaryOp {
  I32x4TruncSatF32x4UOp
}

///|
pub fn UnaryOp::f32x4_convert_i32x4s() -> UnaryOp {
  F32x4ConvertI32x4SOp
}

///|
pub fn UnaryOp::f32x4_convert_i32x4u() -> UnaryOp {
  F32x4ConvertI32x4UOp
}

///|
pub fn UnaryOp::i32x4_trunc_sat_f64x2s_zero() -> UnaryOp {
  I32x4TruncSatF64x2SZeroOp
}

///|
pub fn UnaryOp::i32x4_trunc_sat_f64x2u_zero() -> UnaryOp {
  I32x4TruncSatF64x2UZeroOp
}

///|
pub fn UnaryOp::f64x2_convert_low_i32x4s() -> UnaryOp {
  F64x2ConvertLowI32x4SOp
}

///|
pub fn UnaryOp::f64x2_convert_low_i32x4u() -> UnaryOp {
  F64x2ConvertLowI32x4UOp
}

///|
pub fn UnaryOp::i32x4_relaxed_trunc_f32x4s() -> UnaryOp {
  I32x4RelaxedTruncF32x4SOp
}

///|
pub fn UnaryOp::i32x4_relaxed_trunc_f32x4u() -> UnaryOp {
  I32x4RelaxedTruncF32x4UOp
}

///|
pub fn UnaryOp::i32x4_relaxed_trunc_zero_f64x2s() -> UnaryOp {
  I32x4RelaxedTruncZeroF64x2SOp
}

///|
pub fn UnaryOp::i32x4_relaxed_trunc_zero_f64x2u() -> UnaryOp {
  I32x4RelaxedTruncZeroF64x2UOp
}

///|
pub fn BinaryOp::i32_eq() -> BinaryOp {
  I32EqOp
}

///|
pub fn BinaryOp::i32_ne() -> BinaryOp {
  I32NeOp
}

///|
pub fn BinaryOp::i32_lt_s() -> BinaryOp {
  I32LtSOp
}

///|
pub fn BinaryOp::i32_lt_u() -> BinaryOp {
  I32LtUOp
}

///|
pub fn BinaryOp::i32_gt_s() -> BinaryOp {
  I32GtSOp
}

///|
pub fn BinaryOp::i32_gt_u() -> BinaryOp {
  I32GtUOp
}

///|
pub fn BinaryOp::i32_le_s() -> BinaryOp {
  I32LeSOp
}

///|
pub fn BinaryOp::i32_le_u() -> BinaryOp {
  I32LeUOp
}

///|
pub fn BinaryOp::i32_ge_s() -> BinaryOp {
  I32GeSOp
}

///|
pub fn BinaryOp::i32_ge_u() -> BinaryOp {
  I32GeUOp
}

///|
pub fn BinaryOp::i64_eq() -> BinaryOp {
  I64EqOp
}

///|
pub fn BinaryOp::i64_ne() -> BinaryOp {
  I64NeOp
}

///|
pub fn BinaryOp::i64_lt_s() -> BinaryOp {
  I64LtSOp
}

///|
pub fn BinaryOp::i64_lt_u() -> BinaryOp {
  I64LtUOp
}

///|
pub fn BinaryOp::i64_gt_s() -> BinaryOp {
  I64GtSOp
}

///|
pub fn BinaryOp::i64_gt_u() -> BinaryOp {
  I64GtUOp
}

///|
pub fn BinaryOp::i64_le_s() -> BinaryOp {
  I64LeSOp
}

///|
pub fn BinaryOp::i64_le_u() -> BinaryOp {
  I64LeUOp
}

///|
pub fn BinaryOp::i64_ge_s() -> BinaryOp {
  I64GeSOp
}

///|
pub fn BinaryOp::i64_ge_u() -> BinaryOp {
  I64GeUOp
}

///|
pub fn BinaryOp::f32_eq() -> BinaryOp {
  F32EqOp
}

///|
pub fn BinaryOp::f32_ne() -> BinaryOp {
  F32NeOp
}

///|
pub fn BinaryOp::f32_lt() -> BinaryOp {
  F32LtOp
}

///|
pub fn BinaryOp::f32_gt() -> BinaryOp {
  F32GtOp
}

///|
pub fn BinaryOp::f32_le() -> BinaryOp {
  F32LeOp
}

///|
pub fn BinaryOp::f32_ge() -> BinaryOp {
  F32GeOp
}

///|
pub fn BinaryOp::f64_eq() -> BinaryOp {
  F64EqOp
}

///|
pub fn BinaryOp::f64_ne() -> BinaryOp {
  F64NeOp
}

///|
pub fn BinaryOp::f64_lt() -> BinaryOp {
  F64LtOp
}

///|
pub fn BinaryOp::f64_gt() -> BinaryOp {
  F64GtOp
}

///|
pub fn BinaryOp::f64_le() -> BinaryOp {
  F64LeOp
}

///|
pub fn BinaryOp::f64_ge() -> BinaryOp {
  F64GeOp
}

///|
pub fn BinaryOp::i32_add() -> BinaryOp {
  I32AddOp
}

///|
pub fn BinaryOp::i32_sub() -> BinaryOp {
  I32SubOp
}

///|
pub fn BinaryOp::i32_mul() -> BinaryOp {
  I32MulOp
}

///|
pub fn BinaryOp::i32_div_s() -> BinaryOp {
  I32DivSOp
}

///|
pub fn BinaryOp::i32_div_u() -> BinaryOp {
  I32DivUOp
}

///|
pub fn BinaryOp::i32_rem_s() -> BinaryOp {
  I32RemSOp
}

///|
pub fn BinaryOp::i32_rem_u() -> BinaryOp {
  I32RemUOp
}

///|
pub fn BinaryOp::i32_and() -> BinaryOp {
  I32AndOp
}

///|
pub fn BinaryOp::i32_or() -> BinaryOp {
  I32OrOp
}

///|
pub fn BinaryOp::i32_xor() -> BinaryOp {
  I32XorOp
}

///|
pub fn BinaryOp::i32_shl() -> BinaryOp {
  I32ShlOp
}

///|
pub fn BinaryOp::i32_shr_s() -> BinaryOp {
  I32ShrSOp
}

///|
pub fn BinaryOp::i32_shr_u() -> BinaryOp {
  I32ShrUOp
}

///|
pub fn BinaryOp::i32_rotl() -> BinaryOp {
  I32RotlOp
}

///|
pub fn BinaryOp::i32_rotr() -> BinaryOp {
  I32RotrOp
}

///|
pub fn BinaryOp::i64_add() -> BinaryOp {
  I64AddOp
}

///|
pub fn BinaryOp::i64_sub() -> BinaryOp {
  I64SubOp
}

///|
pub fn BinaryOp::i64_mul() -> BinaryOp {
  I64MulOp
}

///|
pub fn BinaryOp::i64_div_s() -> BinaryOp {
  I64DivSOp
}

///|
pub fn BinaryOp::i64_div_u() -> BinaryOp {
  I64DivUOp
}

///|
pub fn BinaryOp::i64_rem_s() -> BinaryOp {
  I64RemSOp
}

///|
pub fn BinaryOp::i64_rem_u() -> BinaryOp {
  I64RemUOp
}

///|
pub fn BinaryOp::i64_and() -> BinaryOp {
  I64AndOp
}

///|
pub fn BinaryOp::i64_or() -> BinaryOp {
  I64OrOp
}

///|
pub fn BinaryOp::i64_xor() -> BinaryOp {
  I64XorOp
}

///|
pub fn BinaryOp::i64_shl() -> BinaryOp {
  I64ShlOp
}

///|
pub fn BinaryOp::i64_shr_s() -> BinaryOp {
  I64ShrSOp
}

///|
pub fn BinaryOp::i64_shr_u() -> BinaryOp {
  I64ShrUOp
}

///|
pub fn BinaryOp::i64_rotl() -> BinaryOp {
  I64RotlOp
}

///|
pub fn BinaryOp::i64_rotr() -> BinaryOp {
  I64RotrOp
}

///|
pub fn BinaryOp::f32_add() -> BinaryOp {
  F32AddOp
}

///|
pub fn BinaryOp::f32_sub() -> BinaryOp {
  F32SubOp
}

///|
pub fn BinaryOp::f32_mul() -> BinaryOp {
  F32MulOp
}

///|
pub fn BinaryOp::f32_div() -> BinaryOp {
  F32DivOp
}

///|
pub fn BinaryOp::f32_min() -> BinaryOp {
  F32MinOp
}

///|
pub fn BinaryOp::f32_max() -> BinaryOp {
  F32MaxOp
}

///|
pub fn BinaryOp::f32_copysign() -> BinaryOp {
  F32CopysignOp
}

///|
pub fn BinaryOp::f64_add() -> BinaryOp {
  F64AddOp
}

///|
pub fn BinaryOp::f64_sub() -> BinaryOp {
  F64SubOp
}

///|
pub fn BinaryOp::f64_mul() -> BinaryOp {
  F64MulOp
}

///|
pub fn BinaryOp::f64_div() -> BinaryOp {
  F64DivOp
}

///|
pub fn BinaryOp::f64_min() -> BinaryOp {
  F64MinOp
}

///|
pub fn BinaryOp::f64_max() -> BinaryOp {
  F64MaxOp
}

///|
pub fn BinaryOp::f64_copysign() -> BinaryOp {
  F64CopysignOp
}

///|
pub fn BinaryOp::v128_and() -> BinaryOp {
  V128AndOp
}

///|
pub fn BinaryOp::v128_andnot() -> BinaryOp {
  V128AndnotOp
}

///|
pub fn BinaryOp::v128_or() -> BinaryOp {
  V128OrOp
}

///|
pub fn BinaryOp::v128_xor() -> BinaryOp {
  V128XorOp
}

///|
pub fn BinaryOp::i8x16_eq() -> BinaryOp {
  I8x16EqOp
}

///|
pub fn BinaryOp::i8x16_ne() -> BinaryOp {
  I8x16NeOp
}

///|
pub fn BinaryOp::i8x16_lt_s() -> BinaryOp {
  I8x16LtSOp
}

///|
pub fn BinaryOp::i8x16_lt_u() -> BinaryOp {
  I8x16LtUOp
}

///|
pub fn BinaryOp::i8x16_gt_s() -> BinaryOp {
  I8x16GtSOp
}

///|
pub fn BinaryOp::i8x16_gt_u() -> BinaryOp {
  I8x16GtUOp
}

///|
pub fn BinaryOp::i8x16_le_s() -> BinaryOp {
  I8x16LeSOp
}

///|
pub fn BinaryOp::i8x16_le_u() -> BinaryOp {
  I8x16LeUOp
}

///|
pub fn BinaryOp::i8x16_ge_s() -> BinaryOp {
  I8x16GeSOp
}

///|
pub fn BinaryOp::i8x16_ge_u() -> BinaryOp {
  I8x16GeUOp
}

///|
pub fn BinaryOp::i16x8_eq() -> BinaryOp {
  I16x8EqOp
}

///|
pub fn BinaryOp::i16x8_ne() -> BinaryOp {
  I16x8NeOp
}

///|
pub fn BinaryOp::i16x8_lt_s() -> BinaryOp {
  I16x8LtSOp
}

///|
pub fn BinaryOp::i16x8_lt_u() -> BinaryOp {
  I16x8LtUOp
}

///|
pub fn BinaryOp::i16x8_gt_s() -> BinaryOp {
  I16x8GtSOp
}

///|
pub fn BinaryOp::i16x8_gt_u() -> BinaryOp {
  I16x8GtUOp
}

///|
pub fn BinaryOp::i16x8_le_s() -> BinaryOp {
  I16x8LeSOp
}

///|
pub fn BinaryOp::i16x8_le_u() -> BinaryOp {
  I16x8LeUOp
}

///|
pub fn BinaryOp::i16x8_ge_s() -> BinaryOp {
  I16x8GeSOp
}

///|
pub fn BinaryOp::i16x8_ge_u() -> BinaryOp {
  I16x8GeUOp
}

///|
pub fn BinaryOp::i32x4_eq() -> BinaryOp {
  I32x4EqOp
}

///|
pub fn BinaryOp::i32x4_ne() -> BinaryOp {
  I32x4NeOp
}

///|
pub fn BinaryOp::i32x4_lt_s() -> BinaryOp {
  I32x4LtSOp
}

///|
pub fn BinaryOp::i32x4_lt_u() -> BinaryOp {
  I32x4LtUOp
}

///|
pub fn BinaryOp::i32x4_gt_s() -> BinaryOp {
  I32x4GtSOp
}

///|
pub fn BinaryOp::i32x4_gt_u() -> BinaryOp {
  I32x4GtUOp
}

///|
pub fn BinaryOp::i32x4_le_s() -> BinaryOp {
  I32x4LeSOp
}

///|
pub fn BinaryOp::i32x4_le_u() -> BinaryOp {
  I32x4LeUOp
}

///|
pub fn BinaryOp::i32x4_ge_s() -> BinaryOp {
  I32x4GeSOp
}

///|
pub fn BinaryOp::i32x4_ge_u() -> BinaryOp {
  I32x4GeUOp
}

///|
pub fn BinaryOp::i64x2_eq() -> BinaryOp {
  I64x2EqOp
}

///|
pub fn BinaryOp::i64x2_ne() -> BinaryOp {
  I64x2NeOp
}

///|
pub fn BinaryOp::i64x2_lt_s() -> BinaryOp {
  I64x2LtSOp
}

///|
pub fn BinaryOp::i64x2_gt_s() -> BinaryOp {
  I64x2GtSOp
}

///|
pub fn BinaryOp::i64x2_le_s() -> BinaryOp {
  I64x2LeSOp
}

///|
pub fn BinaryOp::i64x2_ge_s() -> BinaryOp {
  I64x2GeSOp
}

///|
pub fn BinaryOp::f32x4_eq() -> BinaryOp {
  F32x4EqOp
}

///|
pub fn BinaryOp::f32x4_ne() -> BinaryOp {
  F32x4NeOp
}

///|
pub fn BinaryOp::f32x4_lt() -> BinaryOp {
  F32x4LtOp
}

///|
pub fn BinaryOp::f32x4_gt() -> BinaryOp {
  F32x4GtOp
}

///|
pub fn BinaryOp::f32x4_le() -> BinaryOp {
  F32x4LeOp
}

///|
pub fn BinaryOp::f32x4_ge() -> BinaryOp {
  F32x4GeOp
}

///|
pub fn BinaryOp::f64x2_eq() -> BinaryOp {
  F64x2EqOp
}

///|
pub fn BinaryOp::f64x2_ne() -> BinaryOp {
  F64x2NeOp
}

///|
pub fn BinaryOp::f64x2_lt() -> BinaryOp {
  F64x2LtOp
}

///|
pub fn BinaryOp::f64x2_gt() -> BinaryOp {
  F64x2GtOp
}

///|
pub fn BinaryOp::f64x2_le() -> BinaryOp {
  F64x2LeOp
}

///|
pub fn BinaryOp::f64x2_ge() -> BinaryOp {
  F64x2GeOp
}

///|
pub fn BinaryOp::i8x16_add() -> BinaryOp {
  I8x16AddOp
}

///|
pub fn BinaryOp::i8x16_add_sat_s() -> BinaryOp {
  I8x16AddSatSOp
}

///|
pub fn BinaryOp::i8x16_add_sat_u() -> BinaryOp {
  I8x16AddSatUOp
}

///|
pub fn BinaryOp::i8x16_sub() -> BinaryOp {
  I8x16SubOp
}

///|
pub fn BinaryOp::i8x16_sub_sat_s() -> BinaryOp {
  I8x16SubSatSOp
}

///|
pub fn BinaryOp::i8x16_sub_sat_u() -> BinaryOp {
  I8x16SubSatUOp
}

///|
pub fn BinaryOp::i8x16_min_s() -> BinaryOp {
  I8x16MinSOp
}

///|
pub fn BinaryOp::i8x16_min_u() -> BinaryOp {
  I8x16MinUOp
}

///|
pub fn BinaryOp::i8x16_max_s() -> BinaryOp {
  I8x16MaxSOp
}

///|
pub fn BinaryOp::i8x16_max_u() -> BinaryOp {
  I8x16MaxUOp
}

///|
pub fn BinaryOp::i8x16_avgr_u() -> BinaryOp {
  I8x16AvgrUOp
}

///|
pub fn BinaryOp::i8x16_narrow_i16x8s() -> BinaryOp {
  I8x16NarrowI16x8SOp
}

///|
pub fn BinaryOp::i8x16_narrow_i16x8u() -> BinaryOp {
  I8x16NarrowI16x8UOp
}

///|
pub fn BinaryOp::i16x8_add() -> BinaryOp {
  I16x8AddOp
}

///|
pub fn BinaryOp::i16x8_add_sat_s() -> BinaryOp {
  I16x8AddSatSOp
}

///|
pub fn BinaryOp::i16x8_add_sat_u() -> BinaryOp {
  I16x8AddSatUOp
}

///|
pub fn BinaryOp::i16x8_sub() -> BinaryOp {
  I16x8SubOp
}

///|
pub fn BinaryOp::i16x8_sub_sat_s() -> BinaryOp {
  I16x8SubSatSOp
}

///|
pub fn BinaryOp::i16x8_sub_sat_u() -> BinaryOp {
  I16x8SubSatUOp
}

///|
pub fn BinaryOp::i16x8_mul() -> BinaryOp {
  I16x8MulOp
}

///|
pub fn BinaryOp::i16x8_min_s() -> BinaryOp {
  I16x8MinSOp
}

///|
pub fn BinaryOp::i16x8_min_u() -> BinaryOp {
  I16x8MinUOp
}

///|
pub fn BinaryOp::i16x8_max_s() -> BinaryOp {
  I16x8MaxSOp
}

///|
pub fn BinaryOp::i16x8_max_u() -> BinaryOp {
  I16x8MaxUOp
}

///|
pub fn BinaryOp::i16x8_avgr_u() -> BinaryOp {
  I16x8AvgrUOp
}

///|
pub fn BinaryOp::i16x8q15mulr_sat_s() -> BinaryOp {
  I16x8Q15mulrSatSOp
}

///|
pub fn BinaryOp::i16x8_narrow_i32x4s() -> BinaryOp {
  I16x8NarrowI32x4SOp
}

///|
pub fn BinaryOp::i16x8_narrow_i32x4u() -> BinaryOp {
  I16x8NarrowI32x4UOp
}

///|
pub fn BinaryOp::i16x8_extmul_low_i8x16s() -> BinaryOp {
  I16x8ExtmulLowI8x16SOp
}

///|
pub fn BinaryOp::i16x8_extmul_high_i8x16s() -> BinaryOp {
  I16x8ExtmulHighI8x16SOp
}

///|
pub fn BinaryOp::i16x8_extmul_low_i8x16u() -> BinaryOp {
  I16x8ExtmulLowI8x16UOp
}

///|
pub fn BinaryOp::i16x8_extmul_high_i8x16u() -> BinaryOp {
  I16x8ExtmulHighI8x16UOp
}

///|
pub fn BinaryOp::i32x4_add() -> BinaryOp {
  I32x4AddOp
}

///|
pub fn BinaryOp::i32x4_sub() -> BinaryOp {
  I32x4SubOp
}

///|
pub fn BinaryOp::i32x4_mul() -> BinaryOp {
  I32x4MulOp
}

///|
pub fn BinaryOp::i32x4_min_s() -> BinaryOp {
  I32x4MinSOp
}

///|
pub fn BinaryOp::i32x4_min_u() -> BinaryOp {
  I32x4MinUOp
}

///|
pub fn BinaryOp::i32x4_max_s() -> BinaryOp {
  I32x4MaxSOp
}

///|
pub fn BinaryOp::i32x4_max_u() -> BinaryOp {
  I32x4MaxUOp
}

///|
pub fn BinaryOp::i32x4_dot_i16x8s() -> BinaryOp {
  I32x4DotI16x8SOp
}

///|
pub fn BinaryOp::i32x4_extmul_low_i16x8s() -> BinaryOp {
  I32x4ExtmulLowI16x8SOp
}

///|
pub fn BinaryOp::i32x4_extmul_high_i16x8s() -> BinaryOp {
  I32x4ExtmulHighI16x8SOp
}

///|
pub fn BinaryOp::i32x4_extmul_low_i16x8u() -> BinaryOp {
  I32x4ExtmulLowI16x8UOp
}

///|
pub fn BinaryOp::i32x4_extmul_high_i16x8u() -> BinaryOp {
  I32x4ExtmulHighI16x8UOp
}

///|
pub fn BinaryOp::i64x2_add() -> BinaryOp {
  I64x2AddOp
}

///|
pub fn BinaryOp::i64x2_sub() -> BinaryOp {
  I64x2SubOp
}

///|
pub fn BinaryOp::i64x2_mul() -> BinaryOp {
  I64x2MulOp
}

///|
pub fn BinaryOp::i64x2_extmul_low_i32x4s() -> BinaryOp {
  I64x2ExtmulLowI32x4SOp
}

///|
pub fn BinaryOp::i64x2_extmul_high_i32x4s() -> BinaryOp {
  I64x2ExtmulHighI32x4SOp
}

///|
pub fn BinaryOp::i64x2_extmul_low_i32x4u() -> BinaryOp {
  I64x2ExtmulLowI32x4UOp
}

///|
pub fn BinaryOp::i64x2_extmul_high_i32x4u() -> BinaryOp {
  I64x2ExtmulHighI32x4UOp
}

///|
pub fn BinaryOp::f32x4_add() -> BinaryOp {
  F32x4AddOp
}

///|
pub fn BinaryOp::f32x4_sub() -> BinaryOp {
  F32x4SubOp
}

///|
pub fn BinaryOp::f32x4_mul() -> BinaryOp {
  F32x4MulOp
}

///|
pub fn BinaryOp::f32x4_div() -> BinaryOp {
  F32x4DivOp
}

///|
pub fn BinaryOp::f32x4_min() -> BinaryOp {
  F32x4MinOp
}

///|
pub fn BinaryOp::f32x4_max() -> BinaryOp {
  F32x4MaxOp
}

///|
pub fn BinaryOp::f32x4_pmin() -> BinaryOp {
  F32x4PminOp
}

///|
pub fn BinaryOp::f32x4_pmax() -> BinaryOp {
  F32x4PmaxOp
}

///|
pub fn BinaryOp::f64x2_add() -> BinaryOp {
  F64x2AddOp
}

///|
pub fn BinaryOp::f64x2_sub() -> BinaryOp {
  F64x2SubOp
}

///|
pub fn BinaryOp::f64x2_mul() -> BinaryOp {
  F64x2MulOp
}

///|
pub fn BinaryOp::f64x2_div() -> BinaryOp {
  F64x2DivOp
}

///|
pub fn BinaryOp::f64x2_min() -> BinaryOp {
  F64x2MinOp
}

///|
pub fn BinaryOp::f64x2_max() -> BinaryOp {
  F64x2MaxOp
}

///|
pub fn BinaryOp::f64x2_pmin() -> BinaryOp {
  F64x2PminOp
}

///|
pub fn BinaryOp::f64x2_pmax() -> BinaryOp {
  F64x2PmaxOp
}

///|
pub fn BinaryOp::f32x4_relaxed_min() -> BinaryOp {
  F32x4RelaxedMinOp
}

///|
pub fn BinaryOp::f32x4_relaxed_max() -> BinaryOp {
  F32x4RelaxedMaxOp
}

///|
pub fn BinaryOp::f64x2_relaxed_min() -> BinaryOp {
  F64x2RelaxedMinOp
}

///|
pub fn BinaryOp::f64x2_relaxed_max() -> BinaryOp {
  F64x2RelaxedMaxOp
}

///|
pub fn BinaryOp::i16x8_relaxed_q15mulr_s() -> BinaryOp {
  I16x8RelaxedQ15mulrSOp
}

///|
pub fn BinaryOp::i16x8_relaxed_dot_i8x16i7x16s() -> BinaryOp {
  I16x8RelaxedDotI8x16I7x16SOp
}

///|
pub fn LoadOp::i32_load() -> LoadOp {
  I32LoadOp
}

///|
pub fn LoadOp::i64_load() -> LoadOp {
  I64LoadOp
}

///|
pub fn LoadOp::f32_load() -> LoadOp {
  F32LoadOp
}

///|
pub fn LoadOp::f64_load() -> LoadOp {
  F64LoadOp
}

///|
pub fn LoadOp::i32_load8s() -> LoadOp {
  I32Load8SOp
}

///|
pub fn LoadOp::i32_load8u() -> LoadOp {
  I32Load8UOp
}

///|
pub fn LoadOp::i32_load16s() -> LoadOp {
  I32Load16SOp
}

///|
pub fn LoadOp::i32_load16u() -> LoadOp {
  I32Load16UOp
}

///|
pub fn LoadOp::i64_load8s() -> LoadOp {
  I64Load8SOp
}

///|
pub fn LoadOp::i64_load8u() -> LoadOp {
  I64Load8UOp
}

///|
pub fn LoadOp::i64_load16s() -> LoadOp {
  I64Load16SOp
}

///|
pub fn LoadOp::i64_load16u() -> LoadOp {
  I64Load16UOp
}

///|
pub fn LoadOp::i64_load32s() -> LoadOp {
  I64Load32SOp
}

///|
pub fn LoadOp::i64_load32u() -> LoadOp {
  I64Load32UOp
}

///|
pub fn LoadOp::i32_atomic_load() -> LoadOp {
  I32AtomicLoadOp
}

///|
pub fn LoadOp::i64_atomic_load() -> LoadOp {
  I64AtomicLoadOp
}

///|
pub fn LoadOp::i32_atomic_load8_u() -> LoadOp {
  I32AtomicLoad8UOp
}

///|
pub fn LoadOp::i32_atomic_load16_u() -> LoadOp {
  I32AtomicLoad16UOp
}

///|
pub fn LoadOp::i64_atomic_load8_u() -> LoadOp {
  I64AtomicLoad8UOp
}

///|
pub fn LoadOp::i64_atomic_load16_u() -> LoadOp {
  I64AtomicLoad16UOp
}

///|
pub fn LoadOp::i64_atomic_load32_u() -> LoadOp {
  I64AtomicLoad32UOp
}

///|
pub fn LoadOp::v128_load() -> LoadOp {
  V128LoadOp
}

///|
pub fn LoadOp::v128_load8x8s() -> LoadOp {
  V128Load8x8SOp
}

///|
pub fn LoadOp::v128_load8x8u() -> LoadOp {
  V128Load8x8UOp
}

///|
pub fn LoadOp::v128_load16x4s() -> LoadOp {
  V128Load16x4SOp
}

///|
pub fn LoadOp::v128_load16x4u() -> LoadOp {
  V128Load16x4UOp
}

///|
pub fn LoadOp::v128_load32x2s() -> LoadOp {
  V128Load32x2SOp
}

///|
pub fn LoadOp::v128_load32x2u() -> LoadOp {
  V128Load32x2UOp
}

///|
pub fn LoadOp::v128_load8_splat() -> LoadOp {
  V128Load8SplatOp
}

///|
pub fn LoadOp::v128_load16_splat() -> LoadOp {
  V128Load16SplatOp
}

///|
pub fn LoadOp::v128_load32_splat() -> LoadOp {
  V128Load32SplatOp
}

///|
pub fn LoadOp::v128_load64_splat() -> LoadOp {
  V128Load64SplatOp
}

///|
pub fn LoadOp::v128_load32_zero() -> LoadOp {
  V128Load32ZeroOp
}

///|
pub fn LoadOp::v128_load64_zero() -> LoadOp {
  V128Load64ZeroOp
}

///|
pub fn StoreOp::i32_store() -> StoreOp {
  I32StoreOp
}

///|
pub fn StoreOp::i64_store() -> StoreOp {
  I64StoreOp
}

///|
pub fn StoreOp::f32_store() -> StoreOp {
  F32StoreOp
}

///|
pub fn StoreOp::f64_store() -> StoreOp {
  F64StoreOp
}

///|
pub fn StoreOp::i32_store8() -> StoreOp {
  I32Store8Op
}

///|
pub fn StoreOp::i32_store16() -> StoreOp {
  I32Store16Op
}

///|
pub fn StoreOp::i64_store8() -> StoreOp {
  I64Store8Op
}

///|
pub fn StoreOp::i64_store16() -> StoreOp {
  I64Store16Op
}

///|
pub fn StoreOp::i64_store32() -> StoreOp {
  I64Store32Op
}

///|
pub fn StoreOp::i32_atomic_store() -> StoreOp {
  I32AtomicStoreOp
}

///|
pub fn StoreOp::i64_atomic_store() -> StoreOp {
  I64AtomicStoreOp
}

///|
pub fn StoreOp::i32_atomic_store8() -> StoreOp {
  I32AtomicStore8Op
}

///|
pub fn StoreOp::i32_atomic_store16() -> StoreOp {
  I32AtomicStore16Op
}

///|
pub fn StoreOp::i64_atomic_store8() -> StoreOp {
  I64AtomicStore8Op
}

///|
pub fn StoreOp::i64_atomic_store16() -> StoreOp {
  I64AtomicStore16Op
}

///|
pub fn StoreOp::i64_atomic_store32() -> StoreOp {
  I64AtomicStore32Op
}

///|
pub fn StoreOp::v128_store() -> StoreOp {
  V128StoreOp
}

///|
pub fn AtomicRmwOp::i32_add() -> AtomicRmwOp {
  I32AtomicRmwAddOp
}

///|
pub fn AtomicRmwOp::i64_add() -> AtomicRmwOp {
  I64AtomicRmwAddOp
}

///|
pub fn AtomicRmwOp::i32_8_add_u() -> AtomicRmwOp {
  I32AtomicRmw8AddUOp
}

///|
pub fn AtomicRmwOp::i32_16_add_u() -> AtomicRmwOp {
  I32AtomicRmw16AddUOp
}

///|
pub fn AtomicRmwOp::i64_8_add_u() -> AtomicRmwOp {
  I64AtomicRmw8AddUOp
}

///|
pub fn AtomicRmwOp::i64_16_add_u() -> AtomicRmwOp {
  I64AtomicRmw16AddUOp
}

///|
pub fn AtomicRmwOp::i64_32_add_u() -> AtomicRmwOp {
  I64AtomicRmw32AddUOp
}

///|
pub fn AtomicRmwOp::i32_sub() -> AtomicRmwOp {
  I32AtomicRmwSubOp
}

///|
pub fn AtomicRmwOp::i64_sub() -> AtomicRmwOp {
  I64AtomicRmwSubOp
}

///|
pub fn AtomicRmwOp::i32_8_sub_u() -> AtomicRmwOp {
  I32AtomicRmw8SubUOp
}

///|
pub fn AtomicRmwOp::i32_16_sub_u() -> AtomicRmwOp {
  I32AtomicRmw16SubUOp
}

///|
pub fn AtomicRmwOp::i64_8_sub_u() -> AtomicRmwOp {
  I64AtomicRmw8SubUOp
}

///|
pub fn AtomicRmwOp::i64_16_sub_u() -> AtomicRmwOp {
  I64AtomicRmw16SubUOp
}

///|
pub fn AtomicRmwOp::i64_32_sub_u() -> AtomicRmwOp {
  I64AtomicRmw32SubUOp
}

///|
pub fn AtomicRmwOp::i32_and() -> AtomicRmwOp {
  I32AtomicRmwAndOp
}

///|
pub fn AtomicRmwOp::i64_and() -> AtomicRmwOp {
  I64AtomicRmwAndOp
}

///|
pub fn AtomicRmwOp::i32_8_and_u() -> AtomicRmwOp {
  I32AtomicRmw8AndUOp
}

///|
pub fn AtomicRmwOp::i32_16_and_u() -> AtomicRmwOp {
  I32AtomicRmw16AndUOp
}

///|
pub fn AtomicRmwOp::i64_8_and_u() -> AtomicRmwOp {
  I64AtomicRmw8AndUOp
}

///|
pub fn AtomicRmwOp::i64_16_and_u() -> AtomicRmwOp {
  I64AtomicRmw16AndUOp
}

///|
pub fn AtomicRmwOp::i64_32_and_u() -> AtomicRmwOp {
  I64AtomicRmw32AndUOp
}

///|
pub fn AtomicRmwOp::i32_or() -> AtomicRmwOp {
  I32AtomicRmwOrOp
}

///|
pub fn AtomicRmwOp::i64_or() -> AtomicRmwOp {
  I64AtomicRmwOrOp
}

///|
pub fn AtomicRmwOp::i32_8_or_u() -> AtomicRmwOp {
  I32AtomicRmw8OrUOp
}

///|
pub fn AtomicRmwOp::i32_16_or_u() -> AtomicRmwOp {
  I32AtomicRmw16OrUOp
}

///|
pub fn AtomicRmwOp::i64_8_or_u() -> AtomicRmwOp {
  I64AtomicRmw8OrUOp
}

///|
pub fn AtomicRmwOp::i64_16_or_u() -> AtomicRmwOp {
  I64AtomicRmw16OrUOp
}

///|
pub fn AtomicRmwOp::i64_32_or_u() -> AtomicRmwOp {
  I64AtomicRmw32OrUOp
}

///|
pub fn AtomicRmwOp::i32_xor() -> AtomicRmwOp {
  I32AtomicRmwXorOp
}

///|
pub fn AtomicRmwOp::i64_xor() -> AtomicRmwOp {
  I64AtomicRmwXorOp
}

///|
pub fn AtomicRmwOp::i32_8_xor_u() -> AtomicRmwOp {
  I32AtomicRmw8XorUOp
}

///|
pub fn AtomicRmwOp::i32_16_xor_u() -> AtomicRmwOp {
  I32AtomicRmw16XorUOp
}

///|
pub fn AtomicRmwOp::i64_8_xor_u() -> AtomicRmwOp {
  I64AtomicRmw8XorUOp
}

///|
pub fn AtomicRmwOp::i64_16_xor_u() -> AtomicRmwOp {
  I64AtomicRmw16XorUOp
}

///|
pub fn AtomicRmwOp::i64_32_xor_u() -> AtomicRmwOp {
  I64AtomicRmw32XorUOp
}

///|
pub fn AtomicRmwOp::i32_xchg() -> AtomicRmwOp {
  I32AtomicRmwXchgOp
}

///|
pub fn AtomicRmwOp::i64_xchg() -> AtomicRmwOp {
  I64AtomicRmwXchgOp
}

///|
pub fn AtomicRmwOp::i32_8_xchg_u() -> AtomicRmwOp {
  I32AtomicRmw8XchgUOp
}

///|
pub fn AtomicRmwOp::i32_16_xchg_u() -> AtomicRmwOp {
  I32AtomicRmw16XchgUOp
}

///|
pub fn AtomicRmwOp::i64_8_xchg_u() -> AtomicRmwOp {
  I64AtomicRmw8XchgUOp
}

///|
pub fn AtomicRmwOp::i64_16_xchg_u() -> AtomicRmwOp {
  I64AtomicRmw16XchgUOp
}

///|
pub fn AtomicRmwOp::i64_32_xchg_u() -> AtomicRmwOp {
  I64AtomicRmw32XchgUOp
}

///|
pub fn AtomicCmpxchgOp::i32() -> AtomicCmpxchgOp {
  I32AtomicRmwCmpxchgOp
}

///|
pub fn AtomicCmpxchgOp::i64() -> AtomicCmpxchgOp {
  I64AtomicRmwCmpxchgOp
}

///|
pub fn AtomicCmpxchgOp::i32_8_u() -> AtomicCmpxchgOp {
  I32AtomicRmw8CmpxchgUOp
}

///|
pub fn AtomicCmpxchgOp::i32_16_u() -> AtomicCmpxchgOp {
  I32AtomicRmw16CmpxchgUOp
}

///|
pub fn AtomicCmpxchgOp::i64_8_u() -> AtomicCmpxchgOp {
  I64AtomicRmw8CmpxchgUOp
}

///|
pub fn AtomicCmpxchgOp::i64_16_u() -> AtomicCmpxchgOp {
  I64AtomicRmw16CmpxchgUOp
}

///|
pub fn AtomicCmpxchgOp::i64_32_u() -> AtomicCmpxchgOp {
  I64AtomicRmw32CmpxchgUOp
}

///|
pub fn ExtractLaneOp::i8x16_extract_lane_s() -> ExtractLaneOp {
  I8x16ExtractLaneSOp
}

///|
pub fn ExtractLaneOp::i8x16_extract_lane_u() -> ExtractLaneOp {
  I8x16ExtractLaneUOp
}

///|
pub fn ExtractLaneOp::i16x8_extract_lane_s() -> ExtractLaneOp {
  I16x8ExtractLaneSOp
}

///|
pub fn ExtractLaneOp::i16x8_extract_lane_u() -> ExtractLaneOp {
  I16x8ExtractLaneUOp
}

///|
pub fn ExtractLaneOp::i32x4_extract_lane() -> ExtractLaneOp {
  I32x4ExtractLaneOp
}

///|
pub fn ExtractLaneOp::i64x2_extract_lane() -> ExtractLaneOp {
  I64x2ExtractLaneOp
}

///|
pub fn ExtractLaneOp::f32x4_extract_lane() -> ExtractLaneOp {
  F32x4ExtractLaneOp
}

///|
pub fn ExtractLaneOp::f64x2_extract_lane() -> ExtractLaneOp {
  F64x2ExtractLaneOp
}

///|
pub fn ReplaceLaneOp::i8x16_replace_lane() -> ReplaceLaneOp {
  I8x16ReplaceLaneOp
}

///|
pub fn ReplaceLaneOp::i16x8_replace_lane() -> ReplaceLaneOp {
  I16x8ReplaceLaneOp
}

///|
pub fn ReplaceLaneOp::i32x4_replace_lane() -> ReplaceLaneOp {
  I32x4ReplaceLaneOp
}

///|
pub fn ReplaceLaneOp::i64x2_replace_lane() -> ReplaceLaneOp {
  I64x2ReplaceLaneOp
}

///|
pub fn ReplaceLaneOp::f32x4_replace_lane() -> ReplaceLaneOp {
  F32x4ReplaceLaneOp
}

///|
pub fn ReplaceLaneOp::f64x2_replace_lane() -> ReplaceLaneOp {
  F64x2ReplaceLaneOp
}

///|
pub fn V128ShiftOp::i8x16_shl() -> V128ShiftOp {
  I8x16ShlOp
}

///|
pub fn V128ShiftOp::i8x16_shr_s() -> V128ShiftOp {
  I8x16ShrSOp
}

///|
pub fn V128ShiftOp::i8x16_shr_u() -> V128ShiftOp {
  I8x16ShrUOp
}

///|
pub fn V128ShiftOp::i16x8_shl() -> V128ShiftOp {
  I16x8ShlOp
}

///|
pub fn V128ShiftOp::i16x8_shr_s() -> V128ShiftOp {
  I16x8ShrSOp
}

///|
pub fn V128ShiftOp::i16x8_shr_u() -> V128ShiftOp {
  I16x8ShrUOp
}

///|
pub fn V128ShiftOp::i32x4_shl() -> V128ShiftOp {
  I32x4ShlOp
}

///|
pub fn V128ShiftOp::i32x4_shr_s() -> V128ShiftOp {
  I32x4ShrSOp
}

///|
pub fn V128ShiftOp::i32x4_shr_u() -> V128ShiftOp {
  I32x4ShrUOp
}

///|
pub fn V128ShiftOp::i64x2_shl() -> V128ShiftOp {
  I64x2ShlOp
}

///|
pub fn V128ShiftOp::i64x2_shr_s() -> V128ShiftOp {
  I64x2ShrSOp
}

///|
pub fn V128ShiftOp::i64x2_shr_u() -> V128ShiftOp {
  I64x2ShrUOp
}

///|
pub fn V128TernaryOp::v128_bitselect() -> V128TernaryOp {
  V128BitselectOp
}

///|
pub fn V128TernaryOp::i8x16_relaxed_laneselect() -> V128TernaryOp {
  I8x16RelaxedLaneselectOp
}

///|
pub fn V128TernaryOp::i16x8_relaxed_laneselect() -> V128TernaryOp {
  I16x8RelaxedLaneselectOp
}

///|
pub fn V128TernaryOp::i32x4_relaxed_laneselect() -> V128TernaryOp {
  I32x4RelaxedLaneselectOp
}

///|
pub fn V128TernaryOp::i64x2_relaxed_laneselect() -> V128TernaryOp {
  I64x2RelaxedLaneselectOp
}

///|
pub fn V128TernaryOp::f32x4_relaxed_madd() -> V128TernaryOp {
  F32x4RelaxedMaddOp
}

///|
pub fn V128TernaryOp::f32x4_relaxed_nmadd() -> V128TernaryOp {
  F32x4RelaxedNmaddOp
}

///|
pub fn V128TernaryOp::f64x2_relaxed_madd() -> V128TernaryOp {
  F64x2RelaxedMaddOp
}

///|
pub fn V128TernaryOp::f64x2_relaxed_nmadd() -> V128TernaryOp {
  F64x2RelaxedNmaddOp
}

///|
pub fn V128TernaryOp::i32x4_relaxed_dot_i8x16i7x16_add_s() -> V128TernaryOp {
  I32x4RelaxedDotI8x16I7x16AddSOp
}

///|
pub fn V128LoadLaneOp::v128_load8_lane() -> V128LoadLaneOp {
  V128Load8LaneOp
}

///|
pub fn V128LoadLaneOp::v128_load16_lane() -> V128LoadLaneOp {
  V128Load16LaneOp
}

///|
pub fn V128LoadLaneOp::v128_load32_lane() -> V128LoadLaneOp {
  V128Load32LaneOp
}

///|
pub fn V128LoadLaneOp::v128_load64_lane() -> V128LoadLaneOp {
  V128Load64LaneOp
}

///|
pub fn V128StoreLaneOp::v128_store8_lane() -> V128StoreLaneOp {
  V128Store8LaneOp
}

///|
pub fn V128StoreLaneOp::v128_store16_lane() -> V128StoreLaneOp {
  V128Store16LaneOp
}

///|
pub fn V128StoreLaneOp::v128_store32_lane() -> V128StoreLaneOp {
  V128Store32LaneOp
}

///|
pub fn V128StoreLaneOp::v128_store64_lane() -> V128StoreLaneOp {
  V128Store64LaneOp
}

///|
pub fn DefType::new(rec : RecType, idx : UInt) -> DefType {
  DefType(rec, idx)
}

///|
pub fn HeapType::is_struct(self : Self) -> Bool {
  match self {
    DefTypeHeapType(def) =>
      match def.project() {
        Some(st) =>
          match st.get_comptype() {
            StructCompType(_) => true
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
pub fn HeapType::is_array(self : Self) -> Bool {
  match self {
    DefTypeHeapType(def) =>
      match def.project() {
        Some(st) =>
          match st.get_comptype() {
            ArrayCompType(_) => true
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
pub fn HeapType::is_gc_aggregate(self : Self) -> Bool {
  self.is_struct() || self.is_array()
}

///|
pub fn HeapType::bottom() -> HeapType {
  AbsHeapTypeHeapType(NoneAbsHeapType)
}

///|
pub fn CastOp::new(b0 : Bool, b1 : Bool) -> CastOp {
  CastOp(b0, b1)
}

///|
pub fn TypeSec::new(rts : Array[RecType]) -> TypeSec {
  TypeSec(rts)
}

///|
pub fn MemSec::new(mems : Array[MemType]) -> MemSec {
  MemSec(mems)
}

///|
pub fn GlobalSec::new(gs : Array[Global]) -> GlobalSec {
  GlobalSec(gs)
}

///|
pub fn CodeSec::new(fs : Array[Func]) -> CodeSec {
  CodeSec(fs)
}

///|
pub fn DataSec::new(ds : Array[Data]) -> DataSec {
  DataSec(ds)
}

///|
pub fn DataCntSec::new(dc : U32) -> DataCntSec {
  DataCntSec(dc)
}

///|
pub fn CustomSec::new(name : Name, payload : Bytes) -> CustomSec {
  CustomSec(name, payload)
}

///|
pub fn ImportSec::new(imports : Array[Import]) -> ImportSec {
  ImportSec(imports)
}

///|
pub fn FuncSec::new(i : Array[TypeIdx]) -> FuncSec {
  FuncSec(i)
}

///|
pub fn ExportSec::new(exports : Array[Export]) -> ExportSec {
  ExportSec(exports)
}

///|
pub fn StartSec::new(fi : FuncIdx) -> StartSec {
  StartSec(fi)
}

///|
pub fn TExpr::new(instrs : Array[TInstr]) -> TExpr {
  TExpr(instrs)
}

///|
pub fn Func::new(locals : Array[Locals], expr : Expr) -> Func {
  Func(locals, expr)
}

///|
pub fn Func::t_func(args : Array[ValType], expr : TExpr) -> Func {
  TFunc(args, expr)
}

///|
pub fn BlockType::void_() -> BlockType {
  VoidBlockType
}

///|
pub fn BlockType::val_type(vt : ValType) -> BlockType {
  ValTypeBlockType(vt)
}

///|
pub fn BlockType::type_idx(ti : TypeIdx) -> BlockType {
  TypeIdxBlockType(ti)
}

///|
pub fn TableSec::new(t : Array[Table]) -> TableSec {
  TableSec(t)
}

///|
pub fn Table::new(tt : TableType, v : Expr?) -> Table {
  Table(tt, v)
}

///|
pub fn Expr::new(i : Array[Instruction]) -> Expr {
  Expr(i)
}

///|
pub fn Elem::new(mode : ElemMode, kind : ElemKind) -> Elem {
  Elem(mode, kind)
}

///|
pub fn ElemSec::new(e : Array[Elem]) -> ElemSec {
  ElemSec(e)
}

///|
pub fn TagSec::new(e : Array[TagType]) -> TagSec {
  TagSec(e)
}

///|
pub fn MemArg::new(align : U32, mem : MemIdx?, offset : U64) -> MemArg {
  MemArg(align, mem, offset)
}

///|
pub fn LocalIdx::new(idx : UInt) -> LocalIdx {
  LocalIdx(idx)
}

///|
pub fn LaneIdx::new(idx : Byte) -> LaneIdx {
  LaneIdx(idx)
}

///|
pub fn NumType::f32() -> NumType {
  F32NumType
}

///|
pub fn NumType::f64() -> NumType {
  F64NumType
}

///|
pub fn NumType::i32() -> NumType {
  I32NumType
}

///|
pub fn NumType::i64() -> NumType {
  I64NumType
}

///|
pub fn TableIdx::new(i : UInt) -> TableIdx {
  TableIdx(i)
}

///|
pub fn FieldType::new(st : StorageType, m : Mut) -> FieldType {
  FieldType(st, m)
}

///|
pub fn FuncIdx::new(idx : UInt) -> FuncIdx {
  FuncIdx(idx)
}

///|
pub fn MemIdx::new(idx : UInt) -> MemIdx {
  MemIdx(idx)
}

///|
pub fn GlobalIdx::new(idx : UInt) -> GlobalIdx {
  GlobalIdx(idx)
}

///|
pub fn TagIdx::new(idx : UInt) -> TagIdx {
  TagIdx(idx)
}

///|
pub fn ElemIdx::new(idx : UInt) -> ElemIdx {
  ElemIdx(idx)
}

///|
pub fn DataIdx::new(idx : UInt) -> DataIdx {
  DataIdx(idx)
}

///|
pub fn CompType::array(ft : FieldType) -> CompType {
  ArrayCompType(ft)
}

///|
pub fn CompType::struct_(fts : Array[FieldType]) -> CompType {
  StructCompType(fts)
}

///|
pub fn CompType::func(params : ResultType, results : ResultType) -> CompType {
  FuncCompType(params, results)
}

///|
pub fn SubType::new(
  f : Bool,
  supers : Array[TypeIdx],
  ct : CompType,
) -> SubType {
  SubType(f, supers, ct)
}

///|
pub fn SubType::comp_type(ct : CompType) -> SubType {
  CompTypeSubType(ct)
}

///|
pub fn RecType::new(st : SubType) -> RecType {
  SingleRecType(st)
}

///|
pub fn RecType::group(sts : Array[SubType]) -> RecType {
  GroupRecType(sts)
}

///|
pub fn TagType::new(ti : TypeIdx) -> TagType {
  TagType(ti)
}

///|
pub fn GlobalType::new(vt : ValType, nullable : Bool) -> GlobalType {
  GlobalType(vt, nullable)
}

///|
pub fn MemType::new(lim : Limits) -> MemType {
  MemType(lim)
}

///|
pub fn TableType::new(rt : RefType, lim : Limits) -> TableType {
  TableType(rt, lim)
}

///|
pub fn ExternType::func(idx : TypeIdx) -> ExternType {
  FuncExternType(idx)
}

///|
pub fn ExternType::table(tt : TableType) -> ExternType {
  TableExternType(tt)
}

///|
pub fn ExternType::mem(mt : MemType) -> ExternType {
  MemExternType(mt)
}

///|
pub fn ExternType::global(gt : GlobalType) -> ExternType {
  GlobalExternType(gt)
}

///|
pub fn ExternType::tag(tt : TagType) -> ExternType {
  TagExternType(tt)
}

///|
pub fn ExternIdx::func(fi : FuncIdx) -> ExternIdx {
  FuncExternIdx(fi)
}

///|
pub fn ExternIdx::table(ti : TableIdx) -> ExternIdx {
  TableExternIdx(ti)
}

///|
pub fn ExternIdx::mem(mi : MemIdx) -> ExternIdx {
  MemExternIdx(mi)
}

///|
pub fn ExternIdx::global(gi : GlobalIdx) -> ExternIdx {
  GlobalExternIdx(gi)
}

///|
pub fn ExternIdx::tag(ti : TagIdx) -> ExternIdx {
  TagExternIdx(ti)
}

///|
pub fn Import::new(n0 : Name, n1 : Name, et : ExternType) -> Import {
  Import(n0, n1, et)
}

///|
pub fn Global::new(gt : GlobalType, e : Expr) -> Global {
  Global(gt, e)
}

///|
pub fn Export::new(n : Name, ei : ExternIdx) -> Export {
  Export(n, ei)
}

///|
pub fn Locals::new(u : UInt, vt : ValType) -> Locals {
  Locals(u, vt)
}

///|
pub fn Data::new(dm : DataMode, b : Bytes) -> Data {
  Data(dm, b)
}

///|
pub fn Name::new(sv : StringView) -> Name {
  Name(sv)
}

///|
pub fn FuncType::new(
  params : Array[ValType],
  results : Array[ValType],
) -> FuncType {
  FuncType(params, results)
}
