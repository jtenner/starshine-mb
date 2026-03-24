///|
pub type NodeId = Int

///|
pub type TypeId = Int

///|
pub type LocalId = Int

///|
pub type LabelId = Int

///|
pub type SideTableId = Int

///|
pub type RootId = Int

///|
pub enum HotOp {
  Nop
  Unreachable
  Block
  Loop
  If
  Try
  TryTable
  Br
  BrIf
  BrTable
  BrOnNull
  BrOnNonNull
  BrOnCast
  BrOnCastFail
  Return
  Call
  CallIndirect
  CallRef
  ReturnCall
  ReturnCallIndirect
  ReturnCallRef
  LocalGet
  LocalSet
  LocalTee
  GlobalGet
  GlobalSet
  Load
  Store
  MemorySize
  MemoryGrow
  MemoryCopy
  MemoryFill
  MemoryInit
  DataDrop
  TableGet
  TableSet
  TableSize
  TableGrow
  TableFill
  TableCopy
  TableInit
  ElemDrop
  Const
  Drop
  Select
  RefNull
  RefIsNull
  RefFunc
  RefGetDesc
  RefTest
  RefCast
  RefTestDesc
  RefCastDescEq
  Unary
  Binary
  Compare
  Convert
  TupleMake
  TupleExtract
  StringOp
  Throw
  Rethrow
  ThrowRef
  Delegate
  Catch
  CatchAll
  Atomic
  Simd
} derive(Eq, Show, Debug)

///|
pub struct HotNode {
  op : HotOp
  ty : TypeId
  flags : UInt
  imm0 : Int
  imm1 : Int
  child_base : Int
  child_count : Int
} derive(Eq, Show, Debug)

///|
pub struct HotLocals {
  param_count : Int
  locals : Array[ValType]
} derive(Eq, Show, Debug)

///|
pub fn HotLocals::new(
  param_count? : Int = 0,
  locals? : Array[ValType] = [],
) -> HotLocals {
  { param_count, locals }
}

///|
pub enum HotTypeInfo {
  VoidType
  BlockResult(BlockType)
  Value(ValType)
  Results(Array[ValType])
} derive(Eq, Show, Debug)

///|
pub enum HotLabelKind {
  BlockLabel
  LoopLabel
  IfLabel
  RegionLabel
  TryLabel
  TryTableLabel
} derive(Eq, Show, Debug)

///|
pub struct HotLabelInfo {
  kind : HotLabelKind
  result_type : TypeId
  owner : NodeId
  branch_arity : Int
} derive(Eq, Show, Debug)

///|
pub enum HotConstPayload {
  I32Const(I32)
  I64Const(I64)
  RefNullConst(RefType)
  StringConst(Bytes)
} derive(Eq, Show, Debug)

///|
pub struct HotMemArg {
  memarg : MemArg
} derive(Eq, Show, Debug)

///|
pub struct HotBranchTable {
  targets : Array[LabelId]
  default_target : LabelId
} derive(Eq, Show, Debug)

///|
pub enum HotCatchArm {
  CatchArm(TagIdx, LabelId)
  CatchRefArm(TagIdx, LabelId)
  CatchAllArm(LabelId)
  CatchAllRefArm(LabelId)
} derive(Eq, Show, Debug)

///|
pub struct HotCatchInfo {
  catches : Array[HotCatchArm]
} derive(Eq, Show, Debug)

///|
pub struct HotCallSig {
  type_idx : TypeIdx
  table_idx : TableIdx?
} derive(Eq, Show, Debug)

///|
pub enum HotStringBuiltin {
  NewWtf16Array
} derive(Eq, Show, Debug)

///|
pub enum HotExtra {
  UnaryOp(UnaryOp)
  BinaryOp(BinaryOp)
} derive(Eq, Show, Debug)

///|
pub struct HotFunc {
  nodes : Array[HotNode]
  children : Array[NodeId]
  roots : Array[NodeId]
  locals : HotLocals
  types : Array[HotTypeInfo]
  labels : Array[HotLabelInfo]
  consts : Array[HotConstPayload]
  memargs : Array[HotMemArg]
  branch_tables : Array[HotBranchTable]
  catches : Array[HotCatchInfo]
  call_sigs : Array[HotCallSig]
  extras : Array[HotExtra]
  mut body_result_type : TypeId
  free_nodes : Array[NodeId]
  mut revision : Int
}

///|
pub enum HotVisitCtl[S, E] {
  Continue(S)
  Skip(S)
  Stop(S)
  Error(E)
}

///|
pub enum HotRewriteCtl[S, E] {
  Same(S)
  Replace(S, NodeId)
  Remove(S)
  Error(E)
}

///|
const HOT_NONE_NODE : NodeId = -1

///|
pub fn HotFunc::new(
  locals? : HotLocals = HotLocals::new(),
  body_result_type? : TypeId = 0,
) -> HotFunc {
  {
    nodes: [],
    children: [],
    roots: [],
    locals,
    types: [HotTypeInfo::VoidType],
    labels: [],
    consts: [],
    memargs: [],
    branch_tables: [],
    catches: [],
    call_sigs: [],
    extras: [],
    body_result_type,
    free_nodes: [],
    revision: 0,
  }
}

///|
pub fn hot_node_count(func : HotFunc) -> Int {
  func.nodes.length()
}

///|
pub fn hot_child_storage_count(func : HotFunc) -> Int {
  func.children.length()
}

///|
pub fn hot_root_storage_count(func : HotFunc) -> Int {
  func.roots.length()
}

///|
pub fn hot_body_result_type(func : HotFunc) -> TypeId {
  func.body_result_type
}

///|
fn hot_core_type_id_is_valid(func : HotFunc, ty : TypeId) -> Bool {
  ty >= 0 && ty < func.types.length()
}

///|
pub fn hot_body_result_type_set(func : HotFunc, ty : TypeId) -> Unit {
  if !hot_core_type_id_is_valid(func, ty) {
    abort("hot body result type must reference a valid interned TypeId")
  }
  func.body_result_type = ty
  func.revision += 1
}

///|
pub fn hot_node_is_live(func : HotFunc, node_id : NodeId) -> Bool {
  if node_id < 0 || node_id >= func.nodes.length() {
    return false
  }
  for free_id in func.free_nodes {
    if free_id == node_id {
      return false
    }
  }
  true
}

///|
pub fn hot_debug_dump_core(func : HotFunc) -> String {
  "nodes=\{hot_node_count(func)} children=\{hot_child_storage_count(func)} roots=\{hot_root_storage_count(func)} body_result_type=\{func.body_result_type} revision=\{func.revision} free_nodes=\{func.free_nodes.length()}"
}

///|
pub fn hot_root_count(func : HotFunc) -> Int {
  func.roots.length()
}

///|
pub fn hot_root_get(func : HotFunc, idx : Int) -> NodeId {
  func.roots[idx]
}

///|
pub fn hot_root_set(func : HotFunc, idx : Int, id : NodeId) -> Unit {
  func.roots[idx] = id
  func.revision += 1
}

///|
pub fn hot_append_root(func : HotFunc, id : NodeId) -> Unit {
  func.roots.push(id)
  func.revision += 1
}

///|
pub fn hot_child_count(func : HotFunc, id : NodeId) -> Int {
  func.nodes[id].child_count
}

///|
pub fn hot_child_get(func : HotFunc, id : NodeId, idx : Int) -> NodeId {
  let node = func.nodes[id]
  func.children[node.child_base + idx]
}

///|
pub fn hot_child_set(
  func : HotFunc,
  id : NodeId,
  idx : Int,
  child : NodeId,
) -> Unit {
  let node = func.nodes[id]
  func.children[node.child_base + idx] = child
  func.revision += 1
}

///|
pub fn hot_node_get(func : HotFunc, id : NodeId) -> HotNode {
  func.nodes[id]
}

///|
pub fn hot_node_set(func : HotFunc, id : NodeId, node : HotNode) -> Unit {
  func.nodes[id] = node
  func.revision += 1
}

///|
pub fn hot_replace_node(
  func : HotFunc,
  id : NodeId,
  new_node : HotNode,
) -> Unit {
  hot_node_set(func, id, new_node)
}

///|
pub fn hot_alloc_children(func : HotFunc, count : Int) -> Int {
  let base = func.children.length()
  for _ in 0..<count {
    func.children.push(HOT_NONE_NODE)
  }
  base
}

///|
pub fn hot_alloc_node(func : HotFunc, node : HotNode) -> NodeId {
  let id = func.nodes.length()
  func.nodes.push(node)
  func.revision += 1
  id
}

///|
pub fn hot_make_simple_node(
  op : HotOp,
  ty : TypeId,
  flags : UInt,
  imm0 : Int,
  imm1 : Int,
  children : Array[NodeId],
) -> HotNode {
  { op, ty, flags, imm0, imm1, child_base: 0, child_count: children.length() }
}
