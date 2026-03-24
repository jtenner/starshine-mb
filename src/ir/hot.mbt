///|
fn hot_alloc_const(func : HotFunc, payload : HotConstPayload) -> Int {
  let id = func.consts.length()
  func.consts.push(payload)
  id
}

///|
fn hot_alloc_label(
  func : HotFunc,
  kind : HotLabelKind,
  result_type : TypeId,
  owner : NodeId,
  branch_arity : Int,
) -> LabelId {
  let id = func.labels.length()
  func.labels.push({ kind, result_type, owner, branch_arity })
  id
}

///|
fn hot_intern_type(func : HotFunc, info : HotTypeInfo) -> TypeId {
  for i = 0; i < func.types.length(); i = i + 1 {
    if func.types[i] == info {
      return i
    }
  }
  let id = func.types.length()
  func.types.push(info)
  id
}

///|
pub fn hot_type_void(func : HotFunc) -> TypeId {
  hot_intern_type(func, HotTypeInfo::VoidType)
}

///|
fn hot_type_from_block_type(func : HotFunc, block_type : BlockType) -> TypeId {
  hot_intern_type(func, HotTypeInfo::BlockResult(block_type))
}

///|
fn hot_make_node_with_children(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  flags : UInt,
  imm0 : Int,
  imm1 : Int,
  children : Array[NodeId],
) -> HotNode {
  let _ = flags
  let base = hot_alloc_children(func, children.length())
  for i = 0; i < children.length(); i = i + 1 {
    func.children[base + i] = children[i]
  }
  {
    op,
    ty,
    flags: hot_default_flags_for_op(op),
    imm0,
    imm1,
    child_base: base,
    child_count: children.length(),
  }
}

///|
fn hot_replace_children(
  func : HotFunc,
  id : NodeId,
  children : Array[NodeId],
) -> Unit {
  let node = func.nodes[id]
  let base = hot_alloc_children(func, children.length())
  for i = 0; i < children.length(); i = i + 1 {
    func.children[base + i] = children[i]
  }
  func.nodes[id] = { ..node, child_base: base, child_count: children.length() }
  func.revision += 1
}

///|
fn hot_result_arity_from_block_type(block_type : BlockType) -> Int {
  match block_type {
    VoidBlockType => 0
    ValTypeBlockType(_) => 1
    TypeIdxBlockType(_) =>
      abort("type-index block types are not supported by the current hot lift")
  }
}

///|
fn hot_result_arity_from_type(func : HotFunc, ty : TypeId) -> Int {
  match func.types[ty] {
    VoidType => 0
    BlockResult(block_type) => hot_result_arity_from_block_type(block_type)
    Value(_) => 1
    Results(values) => values.length()
  }
}

///|
fn hot_pop_value(values : Array[NodeId]) -> NodeId {
  match values.pop() {
    Some(id) => id
    None => abort("hot lift stack underflow")
  }
}

///|
fn hot_pop_values(values : Array[NodeId], count : Int) -> Array[NodeId] {
  let rev : Array[NodeId] = []
  for _ in 0..<count {
    rev.push(hot_pop_value(values))
  }
  let out : Array[NodeId] = []
  for id in rev.rev_iter() {
    out.push(id)
  }
  out
}

///|
fn hot_region_body(
  func : HotFunc,
  expr : Expr,
  label_stack : Array[LabelId],
  result_arity : Int,
) -> Array[NodeId] {
  let Expr(instrs) = expr
  let roots : Array[NodeId] = []
  let values : Array[NodeId] = []
  for instr in instrs {
    hot_lift_instruction(func, instr, label_stack, roots, values)
  }
  let keep = if result_arity > values.length() {
    values.length()
  } else {
    result_arity
  }
  let start = values.length() - keep
  for i = start; i < values.length(); i = i + 1 {
    roots.push(values[i])
  }
  if keep == 0 {
    for value in values {
      roots.push(value)
    }
  }
  roots
}

///|
fn hot_wrap_region(
  func : HotFunc,
  expr : Expr,
  label_stack : Array[LabelId],
  result_arity : Int,
) -> NodeId {
  let node = hot_make_node_with_children(
    func,
    HotOp::Block,
    hot_type_void(func),
    hot_default_flags_for_op(HotOp::Block),
    -1,
    0,
    [],
  )
  let id = hot_alloc_node(func, node)
  let label_id = hot_alloc_label(
    func,
    HotLabelKind::RegionLabel,
    hot_type_void(func),
    id,
    result_arity,
  )
  hot_replace_children(
    func,
    id,
    hot_region_body(func, expr, label_stack, result_arity),
  )
  hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
  id
}

///|
fn hot_lift_instruction(
  func : HotFunc,
  instr : Instruction,
  label_stack : Array[LabelId],
  roots : Array[NodeId],
  values : Array[NodeId],
) -> Unit {
  match instr {
    I32Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::I32Const(v))
      values.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::Const,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Const),
            const_id,
            0,
            [],
          ),
        ),
      )
    }
    I64Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::I64Const(v))
      values.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::Const,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Const),
            const_id,
            0,
            [],
          ),
        ),
      )
    }
    RefNull(rt) => {
      let const_id = hot_alloc_const(func, HotConstPayload::RefNullConst(rt))
      values.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::RefNull,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::RefNull),
            const_id,
            0,
            [],
          ),
        ),
      )
    }
    StringConst(bytes) => {
      let const_id = hot_alloc_const(func, HotConstPayload::StringConst(bytes))
      values.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::Const,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Const),
            const_id,
            0,
            [],
          ),
        ),
      )
    }
    LocalGet(LocalIdx(raw)) =>
      values.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::LocalGet,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::LocalGet),
            raw.reinterpret_as_int(),
            0,
            [],
          ),
        ),
      )
    GlobalGet(GlobalIdx(raw)) =>
      values.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::GlobalGet,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::GlobalGet),
            raw.reinterpret_as_int(),
            0,
            [],
          ),
        ),
      )
    Nop =>
      roots.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::Nop,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Nop),
            0,
            0,
            [],
          ),
        ),
      )
    Unreachable =>
      roots.push(
        hot_alloc_node(
          func,
          hot_make_simple_node(
            HotOp::Unreachable,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Unreachable),
            0,
            0,
            [],
          ),
        ),
      )
    Drop =>
      roots.push(
        hot_alloc_node(
          func,
          hot_make_node_with_children(
            func,
            HotOp::Drop,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Drop),
            0,
            0,
            [hot_pop_value(values)],
          ),
        ),
      )
    LocalSet(LocalIdx(raw)) =>
      roots.push(
        hot_alloc_node(
          func,
          hot_make_node_with_children(
            func,
            HotOp::LocalSet,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::LocalSet),
            raw.reinterpret_as_int(),
            0,
            [hot_pop_value(values)],
          ),
        ),
      )
    LocalTee(LocalIdx(raw)) => {
      let id = hot_alloc_node(
        func,
        hot_make_node_with_children(
          func,
          HotOp::LocalTee,
          hot_type_void(func),
          hot_default_flags_for_op(HotOp::LocalTee),
          raw.reinterpret_as_int(),
          0,
          [hot_pop_value(values)],
        ),
      )
      roots.push(id)
      values.push(id)
    }
    GlobalSet(GlobalIdx(raw)) =>
      roots.push(
        hot_alloc_node(
          func,
          hot_make_node_with_children(
            func,
            HotOp::GlobalSet,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::GlobalSet),
            raw.reinterpret_as_int(),
            0,
            [hot_pop_value(values)],
          ),
        ),
      )
    Block(block_type, expr) => {
      let ty = hot_type_from_block_type(func, block_type)
      let node = hot_make_node_with_children(
        func,
        HotOp::Block,
        ty,
        hot_default_flags_for_op(HotOp::Block),
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let result_arity = hot_result_arity_from_block_type(block_type)
      let label_id = hot_alloc_label(
        func,
        HotLabelKind::BlockLabel,
        ty,
        id,
        result_arity,
      )
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      hot_replace_children(
        func,
        id,
        hot_region_body(func, expr, next_stack, result_arity),
      )
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
      if result_arity > 0 {
        values.push(id)
      } else {
        roots.push(id)
      }
    }
    Loop(block_type, expr) => {
      let ty = hot_type_from_block_type(func, block_type)
      let node = hot_make_node_with_children(
        func,
        HotOp::Loop,
        ty,
        hot_default_flags_for_op(HotOp::Loop),
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let result_arity = hot_result_arity_from_block_type(block_type)
      let label_id = hot_alloc_label(
        func,
        HotLabelKind::LoopLabel,
        ty,
        id,
        result_arity,
      )
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      hot_replace_children(
        func,
        id,
        hot_region_body(func, expr, next_stack, result_arity),
      )
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
      if result_arity > 0 {
        values.push(id)
      } else {
        roots.push(id)
      }
    }
    If(block_type, then_instrs, else_instrs) => {
      let ty = hot_type_from_block_type(func, block_type)
      let node = hot_make_node_with_children(
        func,
        HotOp::If,
        ty,
        hot_default_flags_for_op(HotOp::If),
        -1,
        0,
        [],
      )
      let id = hot_alloc_node(func, node)
      let result_arity = hot_result_arity_from_block_type(block_type)
      let label_id = hot_alloc_label(
        func,
        HotLabelKind::IfLabel,
        ty,
        id,
        result_arity,
      )
      let next_stack = label_stack.copy()
      next_stack.push(label_id)
      let then_region = hot_wrap_region(
        func,
        Expr::new(then_instrs),
        next_stack,
        result_arity,
      )
      let else_region = match else_instrs {
        Some(instrs) =>
          hot_wrap_region(func, Expr::new(instrs), next_stack, result_arity)
        None => HOT_NONE_NODE
      }
      hot_replace_children(func, id, [
        hot_pop_value(values),
        then_region,
        else_region,
      ])
      hot_node_set(func, id, { ..func.nodes[id], imm0: label_id })
      if result_arity > 0 {
        values.push(id)
      } else {
        roots.push(id)
      }
    }
    Return =>
      roots.push(
        hot_alloc_node(
          func,
          hot_make_node_with_children(
            func,
            HotOp::Return,
            hot_type_void(func),
            hot_default_flags_for_op(HotOp::Return),
            0,
            0,
            hot_pop_values(
              values,
              hot_result_arity_from_type(func, func.body_result_type),
            ),
          ),
        ),
      )
    _ => abort("unsupported instruction for hot lift")
  }
}

///|
pub fn hot_lift_body(
  body : Expr,
  locals : HotLocals,
  body_result_type? : BlockType = BlockType::void_(),
) -> HotFunc {
  let func = HotFunc::new(locals~)
  func.body_result_type = hot_type_from_block_type(func, body_result_type)
  let roots = hot_region_body(
    func,
    body,
    [],
    hot_result_arity_from_block_type(body_result_type),
  )
  for root in roots {
    hot_append_root(func, root)
  }
  func
}

///|
fn hot_label_kind(func : HotFunc, label_id : LabelId) -> HotLabelKind {
  func.labels[label_id].kind
}

///|
fn hot_lower_region_body(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> Array[Instruction] {
  if id == HOT_NONE_NODE {
    return []
  }
  let node = hot_node_get(func, id)
  if node.op == HotOp::Block &&
    node.imm0 >= 0 &&
    hot_label_kind(func, node.imm0) == HotLabelKind::RegionLabel {
    return hot_lower_body_items(func, id, label_stack)
  }
  let out : Array[Instruction] = []
  hot_lower_node(func, id, label_stack, out)
  out
}

///|
fn hot_lower_body_items(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> Array[Instruction] {
  let out : Array[Instruction] = []
  let node = hot_node_get(func, id)
  let next_stack = label_stack.copy()
  if node.imm0 >= 0 {
    next_stack.push(node.imm0)
  }
  for i = 0; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child != HOT_NONE_NODE {
      hot_lower_node(func, child, next_stack, out)
    }
  }
  out
}

///|
fn hot_lower_const(
  func : HotFunc,
  id : NodeId,
  out : Array[Instruction],
) -> Unit {
  let node = hot_node_get(func, id)
  match func.consts[node.imm0] {
    HotConstPayload::I32Const(v) => out.push(Instruction::i32_const(v))
    HotConstPayload::I64Const(v) => out.push(Instruction::i64_const(v))
    HotConstPayload::RefNullConst(rt) =>
      out.push(Instruction::ref_null(rt.get_heap_type()))
    HotConstPayload::StringConst(bytes) =>
      out.push(Instruction::string_const(bytes))
  }
}

///|
fn hot_lower_node(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
  out : Array[Instruction],
) -> Unit {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Nop => out.push(Instruction::nop())
    HotOp::Unreachable => out.push(Instruction::unreachable_())
    HotOp::Const | HotOp::RefNull => hot_lower_const(func, id, out)
    HotOp::LocalGet =>
      out.push(
        Instruction::local_get(LocalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::GlobalGet =>
      out.push(
        Instruction::global_get(GlobalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::Drop => {
      hot_lower_node(func, hot_child_get(func, id, 0), label_stack, out)
      out.push(Instruction::drop())
    }
    HotOp::LocalSet => {
      hot_lower_node(func, hot_child_get(func, id, 0), label_stack, out)
      out.push(
        Instruction::local_set(LocalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    }
    HotOp::LocalTee => {
      hot_lower_node(func, hot_child_get(func, id, 0), label_stack, out)
      out.push(
        Instruction::local_tee(LocalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    }
    HotOp::GlobalSet => {
      hot_lower_node(func, hot_child_get(func, id, 0), label_stack, out)
      out.push(
        Instruction::global_set(GlobalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    }
    HotOp::Return => {
      for i = 0; i < node.child_count; i = i + 1 {
        hot_lower_node(func, hot_child_get(func, id, i), label_stack, out)
      }
      out.push(Instruction::return_())
    }
    HotOp::Block => {
      let block_type = match func.types[node.ty] {
        BlockResult(bt) => bt
        _ => BlockType::void_()
      }
      out.push(
        Instruction::block(
          block_type,
          Expr::new(hot_lower_body_items(func, id, label_stack)),
        ),
      )
    }
    HotOp::Loop => {
      let block_type = match func.types[node.ty] {
        BlockResult(bt) => bt
        _ => BlockType::void_()
      }
      out.push(
        Instruction::loop_(
          block_type,
          Expr::new(hot_lower_body_items(func, id, label_stack)),
        ),
      )
    }
    HotOp::If => {
      let block_type = match func.types[node.ty] {
        BlockResult(bt) => bt
        _ => BlockType::void_()
      }
      hot_lower_node(func, hot_child_get(func, id, 0), label_stack, out)
      let next_stack = label_stack.copy()
      if node.imm0 >= 0 {
        next_stack.push(node.imm0)
      }
      let else_id = hot_child_get(func, id, 2)
      out.push(
        Instruction::if_(
          block_type,
          hot_lower_region_body(func, hot_child_get(func, id, 1), next_stack),
          if else_id == HOT_NONE_NODE {
            None
          } else {
            Some(hot_lower_region_body(func, else_id, next_stack))
          },
        ),
      )
    }
    _ => abort("unsupported node for hot lowering")
  }
}

///|
pub fn hot_lower_body(func : HotFunc) -> Expr {
  let out : Array[Instruction] = []
  for root in func.roots {
    hot_lower_node(func, root, [], out)
  }
  Expr::new(out)
}
