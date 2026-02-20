///|
pub struct BlockId(Int) derive(Eq, Hash, Show, Compare)

///|
pub struct BasicBlock {
  id : BlockId
  instrs : Array[TInstr]
  terminator : Terminator
} derive(Show)

///|
pub enum Terminator {
  Br(BlockId)
  BrIf(TInstr, BlockId, BlockId)
  BrTable(TInstr, Array[BlockId], BlockId)
  BrOnNull(TInstr, BlockId, BlockId)
  BrOnNonNull(TInstr, BlockId, BlockId)
  BrOnCast(CastOp, HeapType, HeapType, TInstr, BlockId, BlockId)
  BrOnCastFail(CastOp, HeapType, HeapType, TInstr, BlockId, BlockId)
  Return(Array[TInstr])
  ReturnCall(FuncIdx, Array[TInstr])
  ReturnCallIndirect(TypeIdx, TableIdx, Array[TInstr], TInstr)
  ReturnCallRef(TypeIdx, Array[TInstr], TInstr)
  ThrowRef(TInstr)
  Unreachable
} derive(Show)

///|
pub struct CFG {
  entry : BlockId
  blocks : Map[BlockId, BasicBlock]
  preds : Map[BlockId, Array[BlockId]]
} derive(Show)

///|
priv struct CFGBuilder {
  mut next_block : Int
  blocks : Map[BlockId, BasicBlock]
}

///|
priv struct BlockContext {
  id : BlockId
  instrs : Array[TInstr]
}

///|
pub struct SSAValue(Int) derive(Eq, Hash, Show, Compare)

///|
pub struct PhiNode {
  local_idx : LocalIdx
  result : SSAValue
  args : Map[BlockId, SSAValue]
} derive(Show)

///|
pub struct SSABlock {
  id : BlockId
  phis : Array[PhiNode]
  instrs : Array[SSAInstr]
  terminator : SSATerminator
} derive(Show)

///|
pub enum SSAInstr {
  // v = op(args...)
  Assign(SSAValue, SSAOp)
  // Side effect only
  Effect(SSAOp)
} derive(Show)

///|
pub enum SSAOp {
  // Constants
  I32Const(I32)
  I64Const(I64)
  F32Const(F32)
  F64Const(F64)
  RefNull(HeapType)
  RefFunc(FuncIdx)
  V128Const(Bytes)

  // Copy (replaces local.get/set/tee)
  Copy(SSAValue)

  // Arithmetic
  Binary(BinaryOp, SSAValue, SSAValue)
  Unary(UnaryOp, SSAValue)

  // Memory
  Load(LoadOp, MemArg, SSAValue) // addr
  Store(StoreOp, MemArg, SSAValue, SSAValue) // addr, value
  MemorySize(MemIdx)
  MemoryGrow(MemIdx, SSAValue)
  MemoryAtomicNotify(MemArg, SSAValue, SSAValue) // addr, count
  MemoryAtomicWait32(MemArg, SSAValue, SSAValue, SSAValue) // addr, expected, timeout
  MemoryAtomicWait64(MemArg, SSAValue, SSAValue, SSAValue) // addr, expected, timeout
  AtomicFence
  AtomicRmw(AtomicRmwOp, MemArg, SSAValue, SSAValue) // addr, value
  AtomicCmpxchg(AtomicCmpxchgOp, MemArg, SSAValue, SSAValue, SSAValue) // addr, expected, replacement
  MemoryFill(MemIdx, SSAValue, SSAValue, SSAValue)
  MemoryCopy(MemIdx, MemIdx, SSAValue, SSAValue, SSAValue)
  MemoryInit(DataIdx, MemIdx, SSAValue, SSAValue, SSAValue)
  DataDrop(DataIdx)

  // Globals
  GlobalGet(GlobalIdx)
  GlobalSet(GlobalIdx, SSAValue)

  // Tables
  TableGet(TableIdx, SSAValue)
  TableSet(TableIdx, SSAValue, SSAValue)
  TableSize(TableIdx)
  TableGrow(TableIdx, SSAValue, SSAValue)
  TableFill(TableIdx, SSAValue, SSAValue, SSAValue)
  TableCopy(TableIdx, TableIdx, SSAValue, SSAValue, SSAValue)
  TableInit(ElemIdx, TableIdx, SSAValue, SSAValue, SSAValue)
  ElemDrop(ElemIdx)

  // Calls
  Call(FuncIdx, Array[SSAValue])
  CallIndirect(TypeIdx, TableIdx, Array[SSAValue], SSAValue)
  CallRef(TypeIdx, Array[SSAValue], SSAValue)

  // References
  RefIsNull(SSAValue)
  RefEq(SSAValue, SSAValue)
  RefAsNonNull(SSAValue)
  RefI31(SSAValue)
  I31GetS(SSAValue)
  I31GetU(SSAValue)
  RefTest(Bool, HeapType, SSAValue)
  RefCast(Bool, HeapType, SSAValue)
  AnyConvertExtern(SSAValue)
  ExternConvertAny(SSAValue)

  // Structs
  StructNew(TypeIdx, Array[SSAValue])
  StructNewDefault(TypeIdx)
  StructGet(TypeIdx, U32, SSAValue)
  StructGetS(TypeIdx, U32, SSAValue)
  StructGetU(TypeIdx, U32, SSAValue)
  StructSet(TypeIdx, U32, SSAValue, SSAValue)

  // Arrays
  ArrayNew(TypeIdx, SSAValue, SSAValue)
  ArrayNewDefault(TypeIdx, SSAValue)
  ArrayNewFixed(TypeIdx, Array[SSAValue])
  ArrayNewData(TypeIdx, DataIdx, SSAValue, SSAValue)
  ArrayNewElem(TypeIdx, ElemIdx, SSAValue, SSAValue)
  ArrayGet(TypeIdx, SSAValue, SSAValue)
  ArrayGetS(TypeIdx, SSAValue, SSAValue)
  ArrayGetU(TypeIdx, SSAValue, SSAValue)
  ArraySet(TypeIdx, SSAValue, SSAValue, SSAValue)
  ArrayLen(SSAValue)
  ArrayFill(TypeIdx, SSAValue, SSAValue, SSAValue, SSAValue)
  ArrayCopy(TypeIdx, TypeIdx, SSAValue, SSAValue, SSAValue, SSAValue, SSAValue)
  ArrayInitData(TypeIdx, DataIdx, SSAValue, SSAValue, SSAValue, SSAValue)
  ArrayInitElem(TypeIdx, ElemIdx, SSAValue, SSAValue, SSAValue, SSAValue)

  // SIMD
  Splat(SplatOp, SSAValue)
  ExtractLane(ExtractLaneOp, LaneIdx, SSAValue)
  ReplaceLane(ReplaceLaneOp, LaneIdx, SSAValue, SSAValue)
  Shuffle(Array[LaneIdx], SSAValue, SSAValue)
  Swizzle(SSAValue, SSAValue)
  V128Shift(V128ShiftOp, SSAValue, SSAValue)
  V128Ternary(V128TernaryOp, SSAValue, SSAValue, SSAValue)
  V128LoadLane(V128LoadLaneOp, MemArg, LaneIdx, SSAValue, SSAValue)
  V128StoreLane(V128StoreLaneOp, MemArg, LaneIdx, SSAValue, SSAValue)

  // Select
  Select(Array[ValType]?, SSAValue, SSAValue, SSAValue)

  // Exceptions
  Throw(TagIdx, Array[SSAValue])
} derive(Show)

///|
pub enum SplatOp {
  I8x16Splat
  I16x8Splat
  I32x4Splat
  I64x2Splat
  F32x4Splat
  F64x2Splat
} derive(Show, Eq, Hash)

///|
pub enum SSATerminator {
  Br(BlockId)
  BrIf(SSAValue, BlockId, BlockId)
  BrTable(SSAValue, Array[BlockId], BlockId)
  BrOnNull(SSAValue, BlockId, BlockId) // null_target, non_null_target
  BrOnNonNull(SSAValue, BlockId, BlockId)
  BrOnCast(CastOp, HeapType, HeapType, SSAValue, BlockId, BlockId)
  BrOnCastFail(CastOp, HeapType, HeapType, SSAValue, BlockId, BlockId)
  Return(Array[SSAValue])
  ReturnCall(FuncIdx, Array[SSAValue])
  ReturnCallIndirect(TypeIdx, TableIdx, Array[SSAValue], SSAValue)
  ReturnCallRef(TypeIdx, Array[SSAValue], SSAValue)
  ThrowRef(SSAValue)
  Unreachable
} derive(Show)

///|
pub struct SSACFG {
  entry : BlockId
  blocks : Map[BlockId, SSABlock]
  preds : Map[BlockId, Array[BlockId]]
  param_values : Map[LocalIdx, SSAValue]
  next_value : Int
} derive(Show)

// ============================================
// SSA Builder
// ============================================

///|
priv struct SSABuilder {
  mut next_value : Int
  // Current stacks for each local (for renaming)
  stacks : Map[LocalIdx, Array[SSAValue]]
  // Track what we pushed so we can pop
  pushed_per_block : Array[(LocalIdx, SSAValue)]
}

///|
pub enum SSAUse {
  InInstr(BlockId, Int) // Block, instruction index
  InPhi(BlockId, LocalIdx, BlockId) // Block, phi's local, from predecessor
  InTerminator(BlockId)
}

///|
pub struct UseDefInfo {
  defs : Map[SSAValue, (BlockId, SSADef)]
  uses : Map[SSAValue, Array[SSAUse]]
}

///|
pub enum SSADef {
  Param(LocalIdx)
  Phi(LocalIdx)
  Instr(Int) // Instruction index in block
}

///|
pub struct SSADestructor {
  value_to_local : Map[SSAValue, LocalIdx]
  mut next_local : UInt
}

///|
/// Hash key for expressions - represents the "value" of an operation
pub enum GVNKey {
  Const32(Int)
  Const64(Int64)
  ConstF32(Float)
  ConstF64(Double)
  Unary(UnaryOp, SSAValue)
  Binary(BinaryOp, SSAValue, SSAValue)
  Load(LoadOp, MemArg, SSAValue) // Careful: only valid if no intervening stores
  RefNull(HeapType)
  RefFunc(FuncIdx)
  GlobalGet(GlobalIdx) // Only for immutable globals
  StructGet(TypeIdx, U32, SSAValue)
  ArrayGet(TypeIdx, SSAValue, SSAValue)
} derive(Eq, Hash)

///|
pub struct GVNState {
  value_map : Map[GVNKey, SSAValue]
  // Track which values should be replaced
  replacements : Map[SSAValue, SSAValue]
}

///|
pub struct LivenessInfo {
  live_in : Map[BlockId, @set.Set[SSAValue]]
  live_out : Map[BlockId, @set.Set[SSAValue]]
}

///|
/// Represents the possible writers to a local.get
pub enum LocalSet {
  InitValue // implicit initial value
  Set(LocalIdx, TInstr) // actual local.set
} derive(Eq, Hash)

///|
pub struct LocalGraph {
  /// Map each local.get instruction (by id) to its possible sets
  get_sets : Map[Int, Set[LocalSet]]
}

///|
priv struct Block {
  id : Int
  instr_ids : Array[Int]
  preds : Array[Int]
}

///|
priv struct BlockBuilder {
  id : Int
  instr_ids : Array[Int]
}

///|
priv struct BlockInfo {
  /// Actions in this block, in program order
  actions : Array[Action]
  /// For each local, the last local.set in this block (instr id)
  last_sets : Map[LocalIdx, Int]
}

///|
priv enum Action {
  Get(LocalIdx, Int) // local, action_index
  Set(LocalIdx, Int)
}

///|
pub struct IRContext {
  mut mod_ : Module?
  mut body : TExpr
  mut locals : Array[ValType]
  mut type_ctx : TypeContext?
  mut cfg : CFG?
  mut ssa : SSACFG?
  mut usedef : UseDefInfo?
  mut liveness : LivenessInfo?
  mut types : SSATypeInfo?
  mut gvn : SSACFG?
  mut local_graph : LocalGraph?
}
