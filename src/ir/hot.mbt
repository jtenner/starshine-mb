///|
fn hot_make_node_with_children(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  flags : UInt,
  imm0 : Int,
  imm1 : Int,
  children : Array[NodeId],
) -> NodeId {
  let _ = flags
  let id = hot_alloc_node(func, {
    op,
    ty,
    flags: hot_default_flags_for_op(op),
    imm0,
    imm1,
    child_base: 0,
    child_count: 0,
  })
  if children.length() > 0 {
    ignore(hot_replace_child_span(func, id, children))
  }
  id
}

///|
fn hot_replace_children(
  func : HotFunc,
  id : NodeId,
  children : Array[NodeId],
) -> Unit {
  ignore(hot_replace_child_span(func, id, children))
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
  let id = hot_make_node_with_children(
    func,
    HotOp::Block,
    hot_type_void(func),
    hot_default_flags_for_op(HotOp::Block),
    -1,
    0,
    [],
  )
  let label_id = hot_label_alloc(
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
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
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
        hot_make_node_with_children(
          func,
          HotOp::Drop,
          hot_type_void(func),
          hot_default_flags_for_op(HotOp::Drop),
          0,
          0,
          [hot_pop_value(values)],
        ),
      )
    LocalSet(LocalIdx(raw)) =>
      roots.push(
        hot_make_node_with_children(
          func,
          HotOp::LocalSet,
          hot_type_void(func),
          hot_default_flags_for_op(HotOp::LocalSet),
          raw.reinterpret_as_int(),
          0,
          [hot_pop_value(values)],
        ),
      )
    LocalTee(LocalIdx(raw)) => {
      let id = hot_make_node_with_children(
        func,
        HotOp::LocalTee,
        hot_type_void(func),
        hot_default_flags_for_op(HotOp::LocalTee),
        raw.reinterpret_as_int(),
        0,
        [hot_pop_value(values)],
      )
      roots.push(id)
      values.push(id)
    }
    GlobalSet(GlobalIdx(raw)) =>
      roots.push(
        hot_make_node_with_children(
          func,
          HotOp::GlobalSet,
          hot_type_void(func),
          hot_default_flags_for_op(HotOp::GlobalSet),
          raw.reinterpret_as_int(),
          0,
          [hot_pop_value(values)],
        ),
      )
    Block(block_type, expr) => {
      let ty = hot_type_intern_block_result(func, block_type)
      let id = hot_make_node_with_children(
        func,
        HotOp::Block,
        ty,
        hot_default_flags_for_op(HotOp::Block),
        -1,
        0,
        [],
      )
      let result_arity = hot_type_result_arity(func, ty)
      let label_id = hot_label_alloc(
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
      hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
      if result_arity > 0 {
        values.push(id)
      } else {
        roots.push(id)
      }
    }
    Loop(block_type, expr) => {
      let ty = hot_type_intern_block_result(func, block_type)
      let id = hot_make_node_with_children(
        func,
        HotOp::Loop,
        ty,
        hot_default_flags_for_op(HotOp::Loop),
        -1,
        0,
        [],
      )
      let result_arity = hot_type_result_arity(func, ty)
      let label_id = hot_label_alloc(
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
      hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
      if result_arity > 0 {
        values.push(id)
      } else {
        roots.push(id)
      }
    }
    If(block_type, then_instrs, else_instrs) => {
      let ty = hot_type_intern_block_result(func, block_type)
      let id = hot_make_node_with_children(
        func,
        HotOp::If,
        ty,
        hot_default_flags_for_op(HotOp::If),
        -1,
        0,
        [],
      )
      let result_arity = hot_type_result_arity(func, ty)
      let label_id = hot_label_alloc(
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
      hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
      if result_arity > 0 {
        values.push(id)
      } else {
        roots.push(id)
      }
    }
    Return =>
      roots.push(
        hot_make_node_with_children(
          func,
          HotOp::Return,
          hot_type_void(func),
          hot_default_flags_for_op(HotOp::Return),
          0,
          0,
          hot_pop_values(
            values,
            hot_type_result_arity(func, func.body_result_type),
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
  match hot_lift_body_result(body, locals, body_result_type~) {
    Ok(func) => func
    Err(err) => abort(err.to_string())
  }
}
