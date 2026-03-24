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
  LoadOp(LoadOp)
  StoreOp(StoreOp)
  SelectTypes(Array[ValType]?)
  RefGetDescType(TypeIdx)
  RefTestPayload(Bool, HeapType)
  RefCastPayload(Bool, HeapType)
  RefTestDescPayload(Bool, HeapType)
  RefCastDescEqPayload(Bool, HeapType)
  BrOnCastPayload(CastOp, HeapType, HeapType)
  BrOnCastFailPayload(CastOp, HeapType, HeapType)
  StringBuiltin(HotStringBuiltin)
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

  body_result_type : TypeId

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
const HOT_FLAG_TERMINATOR : UInt = 1U

///|
const HOT_FLAG_CONTROL : UInt = 2U

///|
const HOT_FLAG_SIDE_EFFECT : UInt = 4U

///|
const HOT_FLAG_VALUE : UInt = 8U

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
pub fn hot_type_void(_func : HotFunc) -> TypeId {
  0
}

///|
pub fn hot_type_intern(func : HotFunc, info : HotTypeInfo) -> TypeId {
  for i = 0; i < func.types.length(); i = i + 1 {
    if func.types[i] == info {
      return i
    }
  }
  func.types.push(info)
  func.types.length() - 1
}

///|
fn hot_type_from_block_type(func : HotFunc, block_type : BlockType) -> TypeId {
  hot_type_intern(func, HotTypeInfo::BlockResult(block_type))
}

///|
fn hot_alloc_label(
  func : HotFunc,
  kind : HotLabelKind,
  result_type : TypeId,
  owner : NodeId,
) -> LabelId {
  func.labels.push({ kind, result_type, owner, branch_arity: 0 })
  func.labels.length() - 1
}

///|
fn hot_alloc_const(func : HotFunc, payload : HotConstPayload) -> SideTableId {
  func.consts.push(payload)
  func.consts.length() - 1
}

///|
fn hot_alloc_memarg(func : HotFunc, memarg : MemArg) -> SideTableId {
  func.memargs.push({ memarg, })
  func.memargs.length() - 1
}

///|
fn hot_alloc_branch_table(
  func : HotFunc,
  table : HotBranchTable,
) -> SideTableId {
  func.branch_tables.push(table)
  func.branch_tables.length() - 1
}

///|
fn hot_alloc_catch_info(
  func : HotFunc,
  catches : Array[HotCatchArm],
) -> SideTableId {
  func.catches.push({ catches, })
  func.catches.length() - 1
}

///|
fn hot_alloc_extra(func : HotFunc, extra : HotExtra) -> SideTableId {
  func.extras.push(extra)
  func.extras.length() - 1
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
pub fn hot_replace_node(func : HotFunc, id : NodeId, new_node : HotNode) -> Unit {
  hot_node_set(func, id, new_node)
}

///|
pub fn hot_node_with_op(node : HotNode, op : HotOp) -> HotNode {
  {
    op,
    ty: node.ty,
    flags: node.flags,
    imm0: node.imm0,
    imm1: node.imm1,
    child_base: node.child_base,
    child_count: node.child_count,
  }
}

///|
pub fn hot_node_is_block(node : HotNode) -> Bool {
  match node.op {
    Block => true
    _ => false
  }
}

///|
pub fn hot_node_is_loop(node : HotNode) -> Bool {
  match node.op {
    Loop => true
    _ => false
  }
}

///|
pub fn hot_node_is_try_table(node : HotNode) -> Bool {
  match node.op {
    TryTable => true
    _ => false
  }
}

///|
pub fn hot_node_is_const(node : HotNode) -> Bool {
  match node.op {
    Const => true
    _ => false
  }
}

///|
pub fn hot_node_is_branch_targeting(node : HotNode) -> Bool {
  match node.op {
    Br | BrIf | BrOnNull | BrOnNonNull | BrOnCast | BrOnCastFail | BrTable =>
      true
    _ => false
  }
}

///|
pub fn hot_node_as_block(node : HotNode) -> HotNode {
  hot_node_with_op(node, HotOp::Block)
}

///|
pub fn hot_node_as_global_get(node : HotNode, idx : Int) -> HotNode {
  {
    op: HotOp::GlobalGet,
    ty: node.ty,
    flags: node.flags,
    imm0: idx,
    imm1: 0,
    child_base: 0,
    child_count: 0,
  }
}

///|
pub fn hot_set_label_kind(
  func : HotFunc,
  label_id : LabelId,
  kind : HotLabelKind,
) -> Unit {
  let label = func.labels[label_id]
  func.labels[label_id] = {
    kind,
    result_type: label.result_type,
    owner: label.owner,
    branch_arity: label.branch_arity,
  }
  func.revision += 1
}

///|
pub fn hot_set_label_block(func : HotFunc, label_id : LabelId) -> Unit {
  hot_set_label_kind(func, label_id, HotLabelKind::BlockLabel)
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
  match func.free_nodes.pop() {
    Some(id) => {
      func.nodes[id] = node
      func.revision += 1
      id
    }
    None => {
      func.nodes.push(node)
      func.revision += 1
      func.nodes.length() - 1
    }
  }
}

///|
pub fn hot_append_root(func : HotFunc, id : NodeId) -> Unit {
  func.roots.push(id)
  func.revision += 1
}

///|
pub fn hot_make_simple_node(
  op : HotOp,
  ty : TypeId,
  flags : UInt,
  imm0 : Int,
  imm1 : Int,
  _children : Array[NodeId],
) -> HotNode {
  { op, ty, flags, imm0, imm1, child_base: 0, child_count: 0 }
}

///|
fn hot_make_node_with_children(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  flags : UInt,
  imm0 : Int,
  imm1 : Int,
  child_ids : Array[NodeId],
) -> HotNode {
  let base = hot_alloc_children(func, child_ids.length())
  for i = 0; i < child_ids.length(); i = i + 1 {
    func.children[base + i] = child_ids[i]
  }
  { op, ty, flags, imm0, imm1, child_base: base, child_count: child_ids.length() }
}

///|
pub fn hot_replace_children(
  func : HotFunc,
  id : NodeId,
  next_children : Array[NodeId],
) -> Unit {
  let node = func.nodes[id]
  let base = hot_alloc_children(func, next_children.length())
  for i = 0; i < next_children.length(); i = i + 1 {
    func.children[base + i] = next_children[i]
  }
  func.nodes[id] = {
    ..node,
    child_base: base,
    child_count: next_children.length(),
  }
  func.revision += 1
}

///|
pub fn hot_body_splice(
  func : HotFunc,
  id : NodeId,
  start : Int,
  delete_count : Int,
  inserted : Array[NodeId],
) -> Unit {
  let current : Array[NodeId] = []
  let total = hot_child_count(func, id)
  for i = 0; i < start; i = i + 1 {
    current.push(hot_child_get(func, id, i))
  }
  for item in inserted {
    current.push(item)
  }
  for i = start + delete_count; i < total; i = i + 1 {
    current.push(hot_child_get(func, id, i))
  }
  hot_replace_children(func, id, current)
}

///|
fn hot_branch_target_from_stack(
  label_stack : Array[LabelId],
  label : LabelIdx,
) -> LabelId {
  let LabelIdx(raw) = label
  let depth = raw.reinterpret_as_int()
  label_stack[label_stack.length() - 1 - depth]
}

///|
fn hot_branch_depth(label_stack : Array[LabelId], label_id : LabelId) -> LabelIdx {
  let mut i = label_stack.length() - 1
  let mut depth = 0
  while i >= 0 {
    if label_stack[i] == label_id {
      return LabelIdx::new(depth.reinterpret_as_uint())
    }
    i -= 1
    depth += 1
  }
  abort("missing hot label depth")
}

///|
fn hot_wrap_region(
  func : HotFunc,
  body : Array[TInstr],
  label_stack : Array[LabelId],
) -> NodeId {
  let region_ty = hot_type_void(func)
  let node = hot_make_node_with_children(
    func,
    HotOp::Block,
    region_ty,
    HOT_FLAG_CONTROL,
    -1,
    0,
    hot_lift_instrs(func, body, label_stack),
  )
  let id = hot_alloc_node(func, node)
  let label_id = hot_alloc_label(func, HotLabelKind::RegionLabel, region_ty, id)
  hot_node_set(func, id, { ..node, imm0: label_id })
  id
}

///|
fn hot_lift_instrs(
  func : HotFunc,
  instrs : Array[TInstr],
  label_stack : Array[LabelId],
) -> Array[NodeId] {
  let out : Array[NodeId] = []
  for instr in instrs {
    out.push(hot_lift_tinstr(func, instr, label_stack))
  }
  out
}

///|
fn hot_lift_catches(
  catches : Array[Catch],
  label_stack : Array[LabelId],
) -> Array[HotCatchArm] {
  let out : Array[HotCatchArm] = []
  for catch_ in catches {
    match catch_ {
      @lib.Catch(tag, label) =>
        out.push(CatchArm(tag, hot_branch_target_from_stack(label_stack, label)))
      @lib.CatchRef(tag, label) =>
        out.push(
          CatchRefArm(tag, hot_branch_target_from_stack(label_stack, label)),
        )
      @lib.CatchAll(label) =>
        out.push(CatchAllArm(hot_branch_target_from_stack(label_stack, label)))
      @lib.CatchAllRef(label) =>
        out.push(
          CatchAllRefArm(hot_branch_target_from_stack(label_stack, label)),
        )
    }
  }
  out
}

///|
fn hot_lift_tinstr(
  func : HotFunc,
  instr : TInstr,
  label_stack : Array[LabelId],
) -> NodeId {
  match instr.kind {
    @lib.TNop => hot_alloc_node(
      func,
      hot_make_simple_node(HotOp::Nop, hot_type_void(func), 0U, 0, 0, []),
    )
    @lib.TUnreachable => hot_alloc_node(
      func,
      hot_make_simple_node(
        HotOp::Unreachable,
        hot_type_void(func),
        HOT_FLAG_TERMINATOR,
        0,
        0,
        [],
      ),
    )
    @lib.TI32Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::I32Const(v))
      hot_alloc_node(
        func,
        hot_make_simple_node(HotOp::Const, hot_type_void(func), HOT_FLAG_VALUE, const_id, 0, []),
      )
    }
    @lib.TI64Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::I64Const(v))
      hot_alloc_node(
        func,
        hot_make_simple_node(HotOp::Const, hot_type_void(func), HOT_FLAG_VALUE, const_id, 0, []),
      )
    }
    @lib.TRefNull(ht) => {
      let const_id = hot_alloc_const(func, HotConstPayload::RefNullConst(ht))
      hot_alloc_node(
        func,
        hot_make_simple_node(HotOp::RefNull, hot_type_void(func), HOT_FLAG_VALUE, const_id, 0, []),
      )
    }
    @lib.TStringConst(bytes) => {
      let const_id = hot_alloc_const(func, HotConstPayload::StringConst(bytes))
      hot_alloc_node(
        func,
        hot_make_simple_node(HotOp::Const, hot_type_void(func), HOT_FLAG_VALUE, const_id, 0, []),
      )
    }
    @lib.TLocalGet(LocalIdx(raw)) => hot_alloc_node(
      func,
      hot_make_simple_node(
        HotOp::LocalGet,
        hot_type_void(func),
        HOT_FLAG_VALUE,
        raw.reinterpret_as_int(),
        0,
        [],
      ),
    )
    @lib.TGlobalGet(GlobalIdx(raw)) => hot_alloc_node(
      func,
      hot_make_simple_node(
        HotOp::GlobalGet,
        hot_type_void(func),
        HOT_FLAG_VALUE,
        raw.reinterpret_as_int(),
        0,
        [],
      ),
    )
    @lib.TLocalSet(LocalIdx(raw), value) => hot_alloc_node(
      func,
      hot_make_node_with_children(
        func,
        HotOp::LocalSet,
        hot_type_void(func),
        HOT_FLAG_SIDE_EFFECT,
        raw.reinterpret_as_int(),
        0,
        [hot_lift_tinstr(func, value, label_stack)],
      ),
    )
    @lib.TLocalTee(LocalIdx(raw), value) => hot_alloc_node(
      func,
      hot_make_node_with_children(
        func,
        HotOp::LocalTee,
        hot_type_void(func),
        HOT_FLAG_SIDE_EFFECT | HOT_FLAG_VALUE,
        raw.reinterpret_as_int(),
        0,
        [hot_lift_tinstr(func, value, label_stack)],
      ),
    )
    @lib.TGlobalSet(GlobalIdx(raw), value) => hot_alloc_node(
      func,
      hot_make_node_with_children(
        func,
        HotOp::GlobalSet,
        hot_type_void(func),
        HOT_FLAG_SIDE_EFFECT,
        raw.reinterpret_as_int(),
        0,
        [hot_lift_tinstr(func, value, label_stack)],
      ),
    )
    @lib.TUnary(op, child) => {
      let extra = hot_alloc_extra(func, HotExtra::UnaryOp(op))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Unary,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [hot_lift_tinstr(func, child, label_stack)],
        ),
      )
    }
    @lib.TBinary(op, left, right) => {
      let extra = hot_alloc_extra(func, HotExtra::BinaryOp(op))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Binary,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [
            hot_lift_tinstr(func, left, label_stack),
            hot_lift_tinstr(func, right, label_stack),
          ],
        ),
      )
    }
    @lib.TDrop(child) => hot_alloc_node(
      func,
      hot_make_node_with_children(
        func,
        HotOp::Drop,
        hot_type_void(func),
        HOT_FLAG_SIDE_EFFECT,
        0,
        0,
        [hot_lift_tinstr(func, child, label_stack)],
      ),
    )
    @lib.TCall(FuncIdx(raw), args) => {
      let lifted = hot_lift_instrs(func, args, label_stack)
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Call,
          hot_type_void(func),
          HOT_FLAG_SIDE_EFFECT | HOT_FLAG_VALUE,
          raw.reinterpret_as_int(),
          0,
          lifted,
        ),
      )
    }
    @lib.TReturn(args) => {
      let lifted = hot_lift_instrs(func, args, label_stack)
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Return,
          hot_type_void(func),
          HOT_FLAG_TERMINATOR | HOT_FLAG_SIDE_EFFECT,
          0,
          0,
          lifted,
        ),
      )
    }
    @lib.TBr(label, values) => {
      let lifted = hot_lift_instrs(func, values, label_stack)
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Br,
          hot_type_void(func),
          HOT_FLAG_TERMINATOR | HOT_FLAG_CONTROL,
          hot_branch_target_from_stack(label_stack, label),
          0,
          lifted,
        ),
      )
    }
    @lib.TBrIf(label, cond, values) => {
      let lifted = [hot_lift_tinstr(func, cond, label_stack)]
      for value in values {
        lifted.push(hot_lift_tinstr(func, value, label_stack))
      }
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::BrIf,
          hot_type_void(func),
          HOT_FLAG_CONTROL,
          hot_branch_target_from_stack(label_stack, label),
          0,
          lifted,
        ),
      )
    }
    @lib.TBrTable(labels, default_label, selector, values) => {
      let targets : Array[LabelId] = []
      for label in labels {
        targets.push(hot_branch_target_from_stack(label_stack, label))
      }
      let table_id = hot_alloc_branch_table(
        func,
        {
          targets,
          default_target: hot_branch_target_from_stack(label_stack, default_label),
        },
      )
      let lifted = [hot_lift_tinstr(func, selector, label_stack)]
      for value in values {
        lifted.push(hot_lift_tinstr(func, value, label_stack))
      }
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::BrTable,
          hot_type_void(func),
          HOT_FLAG_TERMINATOR | HOT_FLAG_CONTROL,
          0,
          table_id,
          lifted,
        ),
      )
    }
    @lib.TBrOnNull(label, ref_, values) => {
      let lifted = [hot_lift_tinstr(func, ref_, label_stack)]
      for value in values {
        lifted.push(hot_lift_tinstr(func, value, label_stack))
      }
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::BrOnNull,
          hot_type_void(func),
          HOT_FLAG_CONTROL,
          hot_branch_target_from_stack(label_stack, label),
          0,
          lifted,
        ),
      )
    }
    @lib.TBrOnNonNull(label, ref_, values) => {
      let lifted = [hot_lift_tinstr(func, ref_, label_stack)]
      for value in values {
        lifted.push(hot_lift_tinstr(func, value, label_stack))
      }
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::BrOnNonNull,
          hot_type_void(func),
          HOT_FLAG_CONTROL,
          hot_branch_target_from_stack(label_stack, label),
          0,
          lifted,
        ),
      )
    }
    @lib.TBrOnCast(label, cast_op, source_ht, target_ht, ref_, values) => {
      let extra = hot_alloc_extra(
        func,
        HotExtra::BrOnCastPayload(cast_op, source_ht, target_ht),
      )
      let lifted = [hot_lift_tinstr(func, ref_, label_stack)]
      for value in values {
        lifted.push(hot_lift_tinstr(func, value, label_stack))
      }
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::BrOnCast,
          hot_type_void(func),
          HOT_FLAG_CONTROL,
          hot_branch_target_from_stack(label_stack, label),
          extra,
          lifted,
        ),
      )
    }
    @lib.TBrOnCastFail(label, cast_op, source_ht, target_ht, ref_, values) => {
      let extra = hot_alloc_extra(
        func,
        HotExtra::BrOnCastFailPayload(cast_op, source_ht, target_ht),
      )
      let lifted = [hot_lift_tinstr(func, ref_, label_stack)]
      for value in values {
        lifted.push(hot_lift_tinstr(func, value, label_stack))
      }
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::BrOnCastFail,
          hot_type_void(func),
          HOT_FLAG_CONTROL,
          hot_branch_target_from_stack(label_stack, label),
          extra,
          lifted,
        ),
      )
    }
    @lib.TBlock(block_type, body) => {
      let node = hot_make_node_with_children(
        func,
        HotOp::Block,
        hot_type_from_block_type(func, block_type),
        HOT_FLAG_CONTROL,
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let label_id = hot_alloc_label(func, HotLabelKind::BlockLabel, node.ty, id)
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      hot_replace_children(func, id, hot_lift_instrs(func, body, next_stack))
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
      id
    }
    @lib.TLoop(block_type, body) => {
      let node = hot_make_node_with_children(
        func,
        HotOp::Loop,
        hot_type_from_block_type(func, block_type),
        HOT_FLAG_CONTROL,
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let label_id = hot_alloc_label(func, HotLabelKind::LoopLabel, node.ty, id)
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      hot_replace_children(func, id, hot_lift_instrs(func, body, next_stack))
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
      id
    }
    @lib.TIf(block_type, cond, then_body, else_body) => {
      let ty = hot_type_from_block_type(func, block_type)
      let node = hot_make_node_with_children(
        func,
        HotOp::If,
        ty,
        HOT_FLAG_CONTROL,
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let label_id = hot_alloc_label(func, HotLabelKind::IfLabel, ty, id)
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      let then_region = hot_wrap_region(func, then_body, next_stack)
      let else_region = match else_body {
        Some(other) => hot_wrap_region(func, other, next_stack)
        None => HOT_NONE_NODE
      }
      hot_replace_children(
        func,
        id,
        [hot_lift_tinstr(func, cond, label_stack), then_region, else_region],
      )
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
      id
    }
    @lib.TTryTable(block_type, catches, body) => {
      let ty = hot_type_from_block_type(func, block_type)
      let node = hot_make_node_with_children(
        func,
        HotOp::TryTable,
        ty,
        HOT_FLAG_CONTROL,
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let label_id = hot_alloc_label(func, HotLabelKind::TryTableLabel, ty, id)
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      let catch_id = hot_alloc_catch_info(func, hot_lift_catches(catches, next_stack))
      hot_replace_children(func, id, hot_lift_instrs(func, body, next_stack))
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id, imm1: catch_id })
      id
    }
    @lib.TLoad(op, memarg, addr) => {
      let memarg_id = hot_alloc_memarg(func, memarg)
      let extra = hot_alloc_extra(func, HotExtra::LoadOp(op))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Load,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          memarg_id,
          extra,
          [hot_lift_tinstr(func, addr, label_stack)],
        ),
      )
    }
    @lib.TStore(op, memarg, addr, value) => {
      let memarg_id = hot_alloc_memarg(func, memarg)
      let extra = hot_alloc_extra(func, HotExtra::StoreOp(op))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Store,
          hot_type_void(func),
          HOT_FLAG_SIDE_EFFECT,
          memarg_id,
          extra,
          [
            hot_lift_tinstr(func, addr, label_stack),
            hot_lift_tinstr(func, value, label_stack),
          ],
        ),
      )
    }
    @lib.TSelect(type_hint, cond, if_true, if_false) => {
      let extra = hot_alloc_extra(func, HotExtra::SelectTypes(type_hint))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::Select,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [
            hot_lift_tinstr(func, cond, label_stack),
            hot_lift_tinstr(func, if_true, label_stack),
            hot_lift_tinstr(func, if_false, label_stack),
          ],
        ),
      )
    }
    @lib.TRefGetDesc(type_idx, child) => {
      let extra = hot_alloc_extra(func, HotExtra::RefGetDescType(type_idx))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::RefGetDesc,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [hot_lift_tinstr(func, child, label_stack)],
        ),
      )
    }
    @lib.TRefTest(nullable, heap_type, child) => {
      let extra = hot_alloc_extra(func, HotExtra::RefTestPayload(nullable, heap_type))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::RefTest,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [hot_lift_tinstr(func, child, label_stack)],
        ),
      )
    }
    @lib.TRefCast(nullable, heap_type, child) => {
      let extra = hot_alloc_extra(func, HotExtra::RefCastPayload(nullable, heap_type))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::RefCast,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [hot_lift_tinstr(func, child, label_stack)],
        ),
      )
    }
    @lib.TRefTestDesc(nullable, heap_type, child) => {
      let extra = hot_alloc_extra(
        func,
        HotExtra::RefTestDescPayload(nullable, heap_type),
      )
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::RefTestDesc,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [hot_lift_tinstr(func, child, label_stack)],
        ),
      )
    }
    @lib.TRefCastDescEq(nullable, heap_type, child) => {
      let extra = hot_alloc_extra(
        func,
        HotExtra::RefCastDescEqPayload(nullable, heap_type),
      )
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::RefCastDescEq,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [hot_lift_tinstr(func, child, label_stack)],
        ),
      )
    }
    @lib.TStringNewWtf16Array(array, start, end_) => {
      let extra = hot_alloc_extra(func, HotExtra::StringBuiltin(NewWtf16Array))
      hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::StringOp,
          hot_type_void(func),
          HOT_FLAG_VALUE,
          0,
          extra,
          [
            hot_lift_tinstr(func, array, label_stack),
            hot_lift_tinstr(func, start, label_stack),
            hot_lift_tinstr(func, end_, label_stack),
          ],
        ),
      )
    }
    _ => abort("unsupported hot lift instruction")
  }
}

///|
pub fn hot_lift_body(body : Array[TInstr], locals : HotLocals) -> HotFunc {
  let func = HotFunc::new(locals=locals)
  let roots = hot_lift_instrs(func, body, [])
  for root in roots {
    hot_append_root(func, root)
  }
  func
}

///|
fn hot_lower_region_body(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> Array[TInstr] {
  if id == HOT_NONE_NODE {
    return []
  }
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Block => hot_lower_body_items(func, id, label_stack)
    _ => [hot_lower_tinstr(func, id, label_stack)]
  }
}

///|
fn hot_lower_catches(
  catches : Array[HotCatchArm],
  label_stack : Array[LabelId],
) -> Array[Catch] {
  let out : Array[Catch] = []
  for catch_ in catches {
    match catch_ {
      CatchArm(tag, label_id) =>
        out.push(Catch::new(tag, hot_branch_depth(label_stack, label_id)))
      CatchRefArm(tag, label_id) =>
        out.push(Catch::ref_(tag, hot_branch_depth(label_stack, label_id)))
      CatchAllArm(label_id) =>
        out.push(Catch::all(hot_branch_depth(label_stack, label_id)))
      CatchAllRefArm(label_id) =>
        out.push(Catch::all_ref(hot_branch_depth(label_stack, label_id)))
    }
  }
  out
}

///|
fn hot_lower_body_items(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> Array[TInstr] {
  let out : Array[TInstr] = []
  let node = hot_node_get(func, id)
  let next_stack = label_stack.copy()
  match node.op {
    HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
      if node.imm0 >= 0 {
        next_stack.push(node.imm0)
      }
    _ => ()
  }
  for i = 0; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child != HOT_NONE_NODE {
      out.push(hot_lower_tinstr(func, child, next_stack))
    }
  }
  out
}

///|
fn hot_lower_tinstr(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> TInstr {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Nop => TInstr::nop()
    HotOp::Unreachable => TInstr::unreachable_()
    HotOp::Const =>
      match func.consts[node.imm0] {
        HotConstPayload::I32Const(v) => TInstr::i32_const(v)
        HotConstPayload::I64Const(v) => TInstr::i64_const(v)
        HotConstPayload::StringConst(bytes) => TInstr::string_const(bytes)
        HotConstPayload::RefNullConst(rt) => TInstr::ref_null_type(rt)
      }
    HotOp::RefNull =>
      match func.consts[node.imm0] {
        HotConstPayload::RefNullConst(rt) => TInstr::ref_null_type(rt)
        _ => abort("invalid hot ref.null payload")
      }
    HotOp::LocalGet =>
      TInstr::local_get(LocalIdx::new(node.imm0.reinterpret_as_uint()))
    HotOp::GlobalGet =>
      TInstr::global_get(GlobalIdx::new(node.imm0.reinterpret_as_uint()))
    HotOp::LocalSet =>
      TInstr::local_set(
        LocalIdx::new(node.imm0.reinterpret_as_uint()),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
      )
    HotOp::LocalTee =>
      TInstr::local_tee(
        LocalIdx::new(node.imm0.reinterpret_as_uint()),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
      )
    HotOp::GlobalSet =>
      TInstr::global_set(
        GlobalIdx::new(node.imm0.reinterpret_as_uint()),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
      )
    HotOp::Unary =>
      match func.extras[node.imm1] {
        HotExtra::UnaryOp(op) =>
          TInstr::unary(op, hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack))
        _ => abort("invalid hot unary extra")
      }
    HotOp::Binary =>
      match func.extras[node.imm1] {
        HotExtra::BinaryOp(op) =>
          TInstr::binary(
            op,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
            hot_lower_tinstr(func, hot_child_get(func, id, 1), label_stack),
          )
        _ => abort("invalid hot binary extra")
      }
    HotOp::Drop =>
      TInstr::drop(hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack))
    HotOp::Call => {
      let args : Array[TInstr] = []
      for i = 0; i < node.child_count; i = i + 1 {
        args.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::call(FuncIdx::new(node.imm0.reinterpret_as_uint()), args)
    }
    HotOp::Return => {
      let args : Array[TInstr] = []
      for i = 0; i < node.child_count; i = i + 1 {
        args.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::return_(args)
    }
    HotOp::Br => {
      let args : Array[TInstr] = []
      for i = 0; i < node.child_count; i = i + 1 {
        args.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::br(hot_branch_depth(label_stack, node.imm0), args)
    }
    HotOp::BrIf => {
      let values : Array[TInstr] = []
      for i = 1; i < node.child_count; i = i + 1 {
        values.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::br_if(
        hot_branch_depth(label_stack, node.imm0),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
        values,
      )
    }
    HotOp::BrTable => {
      let table = func.branch_tables[node.imm1]
      let labels : Array[LabelIdx] = []
      for target in table.targets {
        labels.push(hot_branch_depth(label_stack, target))
      }
      let values : Array[TInstr] = []
      for i = 1; i < node.child_count; i = i + 1 {
        values.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::br_table(
        labels,
        hot_branch_depth(label_stack, table.default_target),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
        values,
      )
    }
    HotOp::BrOnNull => {
      let values : Array[TInstr] = []
      for i = 1; i < node.child_count; i = i + 1 {
        values.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::br_on_null(
        hot_branch_depth(label_stack, node.imm0),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
        values,
      )
    }
    HotOp::BrOnNonNull => {
      let values : Array[TInstr] = []
      for i = 1; i < node.child_count; i = i + 1 {
        values.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
      }
      TInstr::br_on_non_null(
        hot_branch_depth(label_stack, node.imm0),
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
        values,
      )
    }
    HotOp::BrOnCast =>
      match func.extras[node.imm1] {
        HotExtra::BrOnCastPayload(cast_op, source_ht, target_ht) => {
          let CastOp(source_nullable, target_nullable) = cast_op
          let values : Array[TInstr] = []
          for i = 1; i < node.child_count; i = i + 1 {
            values.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
          }
          TInstr::br_on_cast(
            hot_branch_depth(label_stack, node.imm0),
            source_nullable,
            source_ht,
            target_nullable,
            target_ht,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
            values,
          )
        }
        _ => abort("invalid hot br_on_cast extra")
      }
    HotOp::BrOnCastFail =>
      match func.extras[node.imm1] {
        HotExtra::BrOnCastFailPayload(cast_op, source_ht, target_ht) => {
          let CastOp(source_nullable, target_nullable) = cast_op
          let values : Array[TInstr] = []
          for i = 1; i < node.child_count; i = i + 1 {
            values.push(hot_lower_tinstr(func, hot_child_get(func, id, i), label_stack))
          }
          TInstr::br_on_cast_fail(
            hot_branch_depth(label_stack, node.imm0),
            source_nullable,
            source_ht,
            target_nullable,
            target_ht,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
            values,
          )
        }
        _ => abort("invalid hot br_on_cast_fail extra")
      }
    HotOp::Block => {
      let next_stack = label_stack.copy()
      next_stack.push(node.imm0)
      let block_type = match func.types[node.ty] {
        HotTypeInfo::BlockResult(block_type) => block_type
        HotTypeInfo::VoidType => BlockType::void_()
        _ => BlockType::void_()
      }
      TInstr::block(block_type, hot_lower_body_items(func, id, label_stack))
    }
    HotOp::Loop => {
      let block_type = match func.types[node.ty] {
        HotTypeInfo::BlockResult(block_type) => block_type
        HotTypeInfo::VoidType => BlockType::void_()
        _ => BlockType::void_()
      }
      let next_stack = label_stack.copy()
      next_stack.push(node.imm0)
      TInstr::loop_(block_type, hot_lower_body_items(func, id, label_stack))
    }
    HotOp::If => {
      let block_type = match func.types[node.ty] {
        HotTypeInfo::BlockResult(block_type) => block_type
        HotTypeInfo::VoidType => BlockType::void_()
        _ => BlockType::void_()
      }
      let next_stack = label_stack.copy()
      next_stack.push(node.imm0)
      TInstr::if_(
        block_type,
        hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
        hot_lower_region_body(func, hot_child_get(func, id, 1), next_stack),
        match hot_child_get(func, id, 2) {
          HOT_NONE_NODE => None
          child => Some(hot_lower_region_body(func, child, next_stack))
        },
      )
    }
    HotOp::TryTable => {
      let block_type = match func.types[node.ty] {
        HotTypeInfo::BlockResult(block_type) => block_type
        HotTypeInfo::VoidType => BlockType::void_()
        _ => BlockType::void_()
      }
      let next_stack = label_stack.copy()
      next_stack.push(node.imm0)
      TInstr::try_table(
        block_type,
        hot_lower_catches(func.catches[node.imm1].catches, next_stack),
        hot_lower_body_items(func, id, label_stack),
      )
    }
    HotOp::Load =>
      match func.extras[node.imm1] {
        HotExtra::LoadOp(op) =>
          TInstr::load(
            op,
            func.memargs[node.imm0].memarg,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
          )
        _ => abort("invalid hot load extra")
      }
    HotOp::Store =>
      match func.extras[node.imm1] {
        HotExtra::StoreOp(op) =>
          TInstr::store(
            op,
            func.memargs[node.imm0].memarg,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
            hot_lower_tinstr(func, hot_child_get(func, id, 1), label_stack),
          )
        _ => abort("invalid hot store extra")
      }
    HotOp::Select =>
      match func.extras[node.imm1] {
        HotExtra::SelectTypes(type_hint) =>
          TInstr::select(
            type_hint,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
            hot_lower_tinstr(func, hot_child_get(func, id, 1), label_stack),
            hot_lower_tinstr(func, hot_child_get(func, id, 2), label_stack),
          )
        _ => abort("invalid hot select extra")
      }
    HotOp::RefGetDesc =>
      match func.extras[node.imm1] {
        HotExtra::RefGetDescType(type_idx) =>
          TInstr::ref_get_desc(
            type_idx,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
          )
        _ => abort("invalid hot ref.get_desc extra")
      }
    HotOp::RefTest =>
      match func.extras[node.imm1] {
        HotExtra::RefTestPayload(nullable, heap_type) =>
          TInstr::ref_test(
            nullable,
            heap_type,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
          )
        _ => abort("invalid hot ref.test extra")
      }
    HotOp::RefCast =>
      match func.extras[node.imm1] {
        HotExtra::RefCastPayload(nullable, heap_type) =>
          TInstr::ref_cast(
            nullable,
            heap_type,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
          )
        _ => abort("invalid hot ref.cast extra")
      }
    HotOp::RefTestDesc =>
      match func.extras[node.imm1] {
        HotExtra::RefTestDescPayload(nullable, heap_type) =>
          TInstr::ref_test_desc(
            nullable,
            heap_type,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
          )
        _ => abort("invalid hot ref.test_desc extra")
      }
    HotOp::RefCastDescEq =>
      match func.extras[node.imm1] {
        HotExtra::RefCastDescEqPayload(nullable, heap_type) =>
          TInstr::ref_cast_desc_eq(
            nullable,
            heap_type,
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
          )
        _ => abort("invalid hot ref.cast_desc_eq extra")
      }
    HotOp::StringOp =>
      match func.extras[node.imm1] {
        HotExtra::StringBuiltin(NewWtf16Array) =>
          TInstr::string_new_wtf16_array(
            hot_lower_tinstr(func, hot_child_get(func, id, 0), label_stack),
            hot_lower_tinstr(func, hot_child_get(func, id, 1), label_stack),
            hot_lower_tinstr(func, hot_child_get(func, id, 2), label_stack),
          )
        _ => abort("invalid hot string extra")
      }
    _ => abort("unsupported hot lower instruction")
  }
}

///|
pub fn hot_lower_body(func : HotFunc) -> Array[TInstr] {
  let instrs : Array[TInstr] = []
  for root in func.roots {
    instrs.push(hot_lower_tinstr(func, root, []))
  }
  instrs
}
