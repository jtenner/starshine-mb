///|
fn hot_lower_impl_label_depth(
  label_stack : Array[LabelId],
  label_id : LabelId,
) -> LabelIdx {
  for i = label_stack.length() - 1; i >= 0; i = i - 1 {
    if label_stack[i] == label_id {
      let depth = label_stack.length() - 1 - i
      return LabelIdx::new(depth.reinterpret_as_uint())
    }
  }
  abort(
    "hot lower target label must be present in the active boundary label stack",
  )
}

///|
fn hot_lower_impl_control_block_type(func : HotFunc, id : NodeId) -> BlockType {
  match hot_type_get(func, hot_node_get(func, id).ty) {
    BlockResult(block_type) => block_type
    BlockResultResolved(block_type, _) => block_type
    _ => BlockType::void_()
  }
}

///|
fn hot_lower_impl_exact_instr(func : HotFunc, id : NodeId) -> Instruction {
  match hot_node_exact_instr(func, id) {
    Some(instr) => instr
    None =>
      abort(
        "hot lower exact-family node must carry an exact instruction payload",
      )
  }
}

///|
fn hot_lower_impl_const(
  func : HotFunc,
  id : NodeId,
  out : Array[Instruction],
) -> Unit {
  let node = hot_node_get(func, id)
  match hot_const_get(func, node.imm0) {
    HotConstPayload::I32Const(v) => out.push(Instruction::i32_const(v))
    HotConstPayload::I64Const(v) => out.push(Instruction::i64_const(v))
    HotConstPayload::F32Const(v) => out.push(Instruction::f32_const(v))
    HotConstPayload::F64Const(v) => out.push(Instruction::f64_const(v))
    HotConstPayload::RefNullConst(rt) =>
      out.push(Instruction::ref_null(rt.get_heap_type()))
    HotConstPayload::StringConst(bytes) =>
      out.push(Instruction::string_const(bytes))
  }
}

///|
fn hot_lower_impl_call_sig(func : HotFunc, id : SideTableId) -> HotCallSig {
  hot_call_sig_get(func, id)
}

///|
fn hot_lower_impl_table_idx(raw : Int) -> TableIdx {
  TableIdx::new(raw.reinterpret_as_uint())
}

///|
fn hot_lower_impl_mem_idx(raw : Int) -> MemIdx {
  MemIdx::new(raw.reinterpret_as_uint())
}

///|
fn hot_lower_impl_input_nodes(func : HotFunc, id : NodeId) -> Array[NodeId] {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Block
    | HotOp::Try
    | HotOp::TryTable
    | HotOp::Nop
    | HotOp::Unreachable
    | HotOp::Const
    | HotOp::RefNull
    | HotOp::LocalGet
    | HotOp::GlobalGet
    | HotOp::MemorySize
    | HotOp::TableSize
    | HotOp::DataDrop
    | HotOp::ElemDrop
    | HotOp::RefFunc => []
    HotOp::Loop => {
      let out : Array[NodeId] = []
      let input_count = hot_label_branch_arity(
        func,
        hot_control_node_label(func, id),
      )
      for i = 0; i < input_count; i = i + 1 {
        out.push(hot_child_get(func, id, i))
      }
      out
    }
    HotOp::If => [hot_child_get(func, id, 0)]
    _ => {
      let out : Array[NodeId] = []
      for i = 0; i < node.child_count; i = i + 1 {
        let child = hot_child_get(func, id, i)
        if child != HOT_NONE_NODE {
          out.push(child)
        }
      }
      out
    }
  }
}

///|
fn hot_lower_impl_input_pop_count(func : HotFunc, id : NodeId) -> Int {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Block
    | HotOp::Loop
    | HotOp::Try
    | HotOp::TryTable
    | HotOp::Nop
    | HotOp::Unreachable
    | HotOp::Const
    | HotOp::RefNull
    | HotOp::LocalGet
    | HotOp::GlobalGet
    | HotOp::MemorySize
    | HotOp::TableSize
    | HotOp::DataDrop
    | HotOp::ElemDrop
    | HotOp::RefFunc => 0
    HotOp::BrIf
    | HotOp::BrTable
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail => 1
    _ => hot_lower_impl_input_nodes(func, id).length()
  }
}

///|
fn hot_lower_impl_clear_stack_after_emit(op : HotOp) -> Bool {
  match op {
    HotOp::Br
    | HotOp::BrTable
    | HotOp::Return
    | HotOp::ReturnCall
    | HotOp::ReturnCallIndirect
    | HotOp::ReturnCallRef
    | HotOp::Throw
    | HotOp::ThrowRef
    | HotOp::Rethrow
    | HotOp::Delegate
    | HotOp::Unreachable => true
    _ => false
  }
}

///|
fn hot_lower_impl_push_results(
  func : HotFunc,
  id : NodeId,
  stack : Array[NodeId],
) -> Unit {
  let result_arity = hot_node_result_arity(func, id)
  for _ in 0..<result_arity {
    stack.push(id)
  }
}

///|
fn hot_lower_impl_matching_input_prefix(
  stack : Array[NodeId],
  inputs : Array[NodeId],
) -> Int {
  let max_count = if stack.length() < inputs.length() {
    stack.length()
  } else {
    inputs.length()
  }
  let mut best = 0
  for count = 0; count <= max_count; count = count + 1 {
    let stack_start = stack.length() - count
    let mut ok = true
    for i = 0; i < count; i = i + 1 {
      if stack[stack_start + i] != inputs[i] {
        ok = false
        break
      }
    }
    if ok {
      best = count
    }
  }
  best
}

///|
fn hot_lower_impl_update_stack(
  func : HotFunc,
  id : NodeId,
  stack : Array[NodeId],
) -> Unit {
  let node = hot_node_get(func, id)
  if hot_lower_impl_clear_stack_after_emit(node.op) {
    stack.clear()
    return
  }
  let pop_count = hot_lower_impl_input_pop_count(func, id)
  for _ in 0..<pop_count {
    ignore(stack.pop())
  }
  hot_lower_impl_push_results(func, id, stack)
}

///|
fn hot_lower_impl_lower_br_on_cast(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> Instruction {
  let node = hot_node_get(func, id)
  let label_idx = hot_lower_impl_label_depth(label_stack, node.imm0)
  match hot_lower_impl_exact_instr(func, id) {
    Instruction::BrOnCast(_, CastOp(src_nullable, dst_nullable), src_ht, dst_ht) =>
      Instruction::br_on_cast(
        label_idx, src_nullable, src_ht, dst_nullable, dst_ht,
      )
    Instruction::BrOnCastFail(
      _,
      CastOp(src_nullable, dst_nullable),
      src_ht,
      dst_ht
    ) =>
      Instruction::br_on_cast_fail(
        label_idx, src_nullable, src_ht, dst_nullable, dst_ht,
      )
    other =>
      abort(
        "hot lower expected br_on_cast exact payload for \{node.op}, got \{other}",
      )
  }
}

///|
fn hot_lower_impl_try_catches(
  func : HotFunc,
  id : NodeId,
  label_stack : Array[LabelId],
) -> Array[Catch] {
  let node = hot_node_get(func, id)
  let info = hot_catch_info_get(func, node.imm1)
  let catches : Array[Catch] = []
  for arm in info.catches {
    match arm {
      HotCatchArm::CatchArm(tag_idx, label_id) =>
        catches.push(
          Catch::new(tag_idx, hot_lower_impl_label_depth(label_stack, label_id)),
        )
      HotCatchArm::CatchRefArm(tag_idx, label_id) =>
        catches.push(
          Catch::ref_(
            tag_idx,
            hot_lower_impl_label_depth(label_stack, label_id),
          ),
        )
      HotCatchArm::CatchAllArm(label_id) =>
        catches.push(
          Catch::all(hot_lower_impl_label_depth(label_stack, label_id)),
        )
      HotCatchArm::CatchAllRefArm(label_id) =>
        catches.push(
          Catch::all_ref(hot_lower_impl_label_depth(label_stack, label_id)),
        )
    }
  }
  catches
}

///|
fn hot_lower_impl_body_items(
  func : HotFunc,
  id : NodeId,
  use_def : HotUseDef,
  label_stack : Array[LabelId],
) -> Array[Instruction] {
  let out : Array[Instruction] = []
  let next_stack = label_stack.copy()
  let label_id = hot_control_node_label(func, id)
  if label_id >= 0 &&
    hot_label_kind(func, label_id) != HotLabelKind::RegionLabel {
    next_stack.push(label_id)
  }
  let node = hot_node_get(func, id)
  let body_base = if node.op == HotOp::Loop {
    hot_label_branch_arity(func, label_id)
  } else {
    0
  }
  let value_stack : Array[NodeId] = []
  for i = 0; i < body_base; i = i + 1 {
    value_stack.push(hot_child_get(func, id, i))
  }
  let root_ids : Array[NodeId] = []
  for i = body_base; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child != HOT_NONE_NODE {
      root_ids.push(child)
    }
  }
  let preserve_region_results = hot_lower_impl_preserve_region_result_roots(
    func,
    use_def,
    root_ids,
    hot_label_branch_arity(func, label_id),
  )
  let mut root_idx = 0
  for i = body_base; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child != HOT_NONE_NODE {
      hot_lower_impl_emit_root(func, child, use_def, next_stack, value_stack, out)
      let is_final_root = i + 1 == node.child_count
      hot_lower_impl_drop_dead_nonfinal_root_results(
        func,
        child,
        use_def,
        preserve_region_results[root_idx],
        is_final_root,
        value_stack,
        out,
      )
      root_idx += 1
    }
  }
  out
}

///|
fn hot_lower_impl_region_body(
  func : HotFunc,
  id : NodeId,
  use_def : HotUseDef,
  label_stack : Array[LabelId],
) -> Array[Instruction] {
  if id == HOT_NONE_NODE {
    return []
  }
  let label_id = hot_control_node_label(func, id)
  let node = hot_node_get(func, id)
  if node.op == HotOp::Block &&
    label_id >= 0 &&
    hot_label_kind(func, label_id) == HotLabelKind::RegionLabel {
    return hot_lower_impl_body_items(func, id, use_def, label_stack)
  }
  let out : Array[Instruction] = []
  let value_stack : Array[NodeId] = []
  hot_lower_impl_emit_root(func, id, use_def, label_stack, value_stack, out)
  out
}

///|
fn hot_lower_impl_drop_dead_nonfinal_root_results(
  func : HotFunc,
  id : NodeId,
  use_def : HotUseDef,
  preserve_region_result : Bool,
  is_final_root : Bool,
  stack : Array[NodeId],
  out : Array[Instruction],
) -> Unit {
  if is_final_root || preserve_region_result {
    return
  }
  let result_arity = hot_node_result_arity(func, id)
  if result_arity == 0 || node_use_count(use_def, id) != 1 {
    return
  }
  for _ in 0..<result_arity {
    out.push(Instruction::drop())
    ignore(stack.pop())
  }
}

///|
fn hot_lower_impl_preserve_region_result_roots(
  func : HotFunc,
  use_def : HotUseDef,
  root_ids : Array[NodeId],
  region_result_arity : Int,
) -> Array[Bool] {
  let preserve : Array[Bool] = []
  for _ in 0..<root_ids.length() {
    preserve.push(false)
  }
  let mut remaining = region_result_arity
  for i = root_ids.length() - 1; i >= 0; i = i - 1 {
    if remaining <= 0 {
      break
    }
    let root_id = root_ids[i]
    if node_use_count(use_def, root_id) != 1 {
      continue
    }
    let result_arity = hot_node_result_arity(func, root_id)
    if result_arity == 0 {
      continue
    }
    preserve[i] = true
    if result_arity >= remaining {
      remaining = 0
    } else {
      remaining = remaining - result_arity
    }
  }
  preserve
}

///|
fn hot_lower_impl_emit_instruction(
  func : HotFunc,
  id : NodeId,
  use_def : HotUseDef,
  label_stack : Array[LabelId],
  out : Array[Instruction],
) -> Unit {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Nop => out.push(Instruction::nop())
    HotOp::Unreachable => out.push(Instruction::unreachable_())
    HotOp::Const | HotOp::RefNull => hot_lower_impl_const(func, id, out)
    HotOp::LocalGet =>
      out.push(
        Instruction::local_get(LocalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::LocalSet =>
      out.push(
        Instruction::local_set(LocalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::LocalTee =>
      out.push(
        Instruction::local_tee(LocalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::GlobalGet =>
      out.push(
        Instruction::global_get(GlobalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::GlobalSet =>
      out.push(
        Instruction::global_set(GlobalIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::TableGet =>
      out.push(Instruction::table_get(hot_lower_impl_table_idx(node.imm0)))
    HotOp::TableSet =>
      out.push(Instruction::table_set(hot_lower_impl_table_idx(node.imm0)))
    HotOp::TableSize =>
      out.push(Instruction::table_size(hot_lower_impl_table_idx(node.imm0)))
    HotOp::TableGrow =>
      out.push(Instruction::table_grow(hot_lower_impl_table_idx(node.imm0)))
    HotOp::TableFill =>
      out.push(Instruction::table_fill(hot_lower_impl_table_idx(node.imm0)))
    HotOp::TableCopy =>
      out.push(
        Instruction::table_copy(
          hot_lower_impl_table_idx(node.imm0),
          hot_lower_impl_table_idx(node.imm1),
        ),
      )
    HotOp::TableInit =>
      out.push(
        Instruction::table_init(
          ElemIdx::new(node.imm0.reinterpret_as_uint()),
          hot_lower_impl_table_idx(node.imm1),
        ),
      )
    HotOp::ElemDrop =>
      out.push(
        Instruction::elem_drop(ElemIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::MemorySize =>
      out.push(Instruction::memory_size(hot_lower_impl_mem_idx(node.imm0)))
    HotOp::MemoryGrow =>
      out.push(Instruction::memory_grow(hot_lower_impl_mem_idx(node.imm0)))
    HotOp::MemoryCopy =>
      out.push(
        Instruction::memory_copy(
          hot_lower_impl_mem_idx(node.imm0),
          hot_lower_impl_mem_idx(node.imm1),
        ),
      )
    HotOp::MemoryFill =>
      out.push(Instruction::memory_fill(hot_lower_impl_mem_idx(node.imm0)))
    HotOp::MemoryInit =>
      out.push(
        Instruction::memory_init(
          DataIdx::new(node.imm0.reinterpret_as_uint()),
          hot_lower_impl_mem_idx(node.imm1),
        ),
      )
    HotOp::DataDrop =>
      out.push(
        Instruction::data_drop(DataIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::Drop => out.push(Instruction::drop())
    HotOp::Call =>
      out.push(Instruction::call(FuncIdx::new(node.imm0.reinterpret_as_uint())))
    HotOp::CallIndirect => {
      let sig = hot_lower_impl_call_sig(func, node.imm0)
      let table_idx = match sig.table_idx {
        Some(table_idx) => table_idx
        None => abort("hot lower call_indirect requires a table index")
      }
      out.push(Instruction::call_indirect(sig.type_idx, table_idx))
    }
    HotOp::CallRef =>
      out.push(
        Instruction::call_ref(hot_lower_impl_call_sig(func, node.imm0).type_idx),
      )
    HotOp::ReturnCall =>
      out.push(
        Instruction::return_call(FuncIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::ReturnCallIndirect => {
      let sig = hot_lower_impl_call_sig(func, node.imm0)
      let table_idx = match sig.table_idx {
        Some(table_idx) => table_idx
        None => abort("hot lower return_call_indirect requires a table index")
      }
      out.push(Instruction::return_call_indirect(sig.type_idx, table_idx))
    }
    HotOp::ReturnCallRef =>
      out.push(
        Instruction::return_call_ref(
          hot_lower_impl_call_sig(func, node.imm0).type_idx,
        ),
      )
    HotOp::Br =>
      out.push(
        Instruction::br(hot_lower_impl_label_depth(label_stack, node.imm0)),
      )
    HotOp::BrIf =>
      out.push(
        Instruction::br_if(hot_lower_impl_label_depth(label_stack, node.imm0)),
      )
    HotOp::BrTable => {
      let targets : Array[LabelIdx] = []
      for label_id in hot_branch_table_targets(func, node.imm0) {
        targets.push(hot_lower_impl_label_depth(label_stack, label_id))
      }
      out.push(
        Instruction::br_table(
          targets,
          hot_lower_impl_label_depth(
            label_stack,
            hot_branch_table_default_target(func, node.imm0),
          ),
        ),
      )
    }
    HotOp::BrOnNull =>
      out.push(
        Instruction::br_on_null(
          hot_lower_impl_label_depth(label_stack, node.imm0),
        ),
      )
    HotOp::BrOnNonNull =>
      out.push(
        Instruction::br_on_non_null(
          hot_lower_impl_label_depth(label_stack, node.imm0),
        ),
      )
    HotOp::BrOnCast | HotOp::BrOnCastFail =>
      out.push(hot_lower_impl_lower_br_on_cast(func, id, label_stack))
    HotOp::Return => out.push(Instruction::return_())
    HotOp::RefIsNull => out.push(Instruction::ref_is_null())
    HotOp::RefFunc =>
      out.push(
        Instruction::ref_func(FuncIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::Load
    | HotOp::Store
    | HotOp::Select
    | HotOp::RefTest
    | HotOp::RefCast
    | HotOp::RefTestDesc
    | HotOp::RefCastDescEq
    | HotOp::Heap
    | HotOp::Unary
    | HotOp::Binary
    | HotOp::Compare
    | HotOp::Convert
    | HotOp::StringOp
    | HotOp::Atomic
    | HotOp::Simd => out.push(hot_lower_impl_exact_instr(func, id))
    HotOp::Throw =>
      out.push(
        Instruction::throw_(TagIdx::new(node.imm0.reinterpret_as_uint())),
      )
    HotOp::ThrowRef => out.push(Instruction::throw_ref())
    HotOp::Block =>
      out.push(
        Instruction::block(
          hot_lower_impl_control_block_type(func, id),
          Expr::new(hot_lower_impl_body_items(func, id, use_def, label_stack)),
        ),
      )
    HotOp::Loop =>
      out.push(
        Instruction::loop_(
          hot_lower_impl_control_block_type(func, id),
          Expr::new(hot_lower_impl_body_items(func, id, use_def, label_stack)),
        ),
      )
    HotOp::If => {
      let next_stack = label_stack.copy()
      let label_id = hot_control_node_label(func, id)
      if label_id >= 0 {
        next_stack.push(label_id)
      }
      let else_id = hot_child_get(func, id, 2)
      out.push(
        Instruction::if_(
          hot_lower_impl_control_block_type(func, id),
          hot_lower_impl_region_body(
            func,
            hot_child_get(func, id, 1),
            use_def,
            next_stack,
          ),
          if else_id == HOT_NONE_NODE {
            None
          } else {
            Some(hot_lower_impl_region_body(func, else_id, use_def, next_stack))
          },
        ),
      )
    }
    HotOp::TryTable => {
      let next_stack = label_stack.copy()
      let label_id = hot_control_node_label(func, id)
      if label_id >= 0 {
        next_stack.push(label_id)
      }
      out.push(
        Instruction::try_table(
          hot_lower_impl_control_block_type(func, id),
          hot_lower_impl_try_catches(func, id, label_stack),
          Expr::new(
            hot_lower_impl_region_body(
              func,
              hot_child_get(func, id, 0),
              use_def,
              next_stack,
            ),
          ),
        ),
      )
    }
    _ => abort("unsupported node for hot lowering")
  }
}

///|
fn hot_lower_impl_emit_value(
  func : HotFunc,
  id : NodeId,
  use_def : HotUseDef,
  label_stack : Array[LabelId],
  stack : Array[NodeId],
  out : Array[Instruction],
) -> Unit {
  match stack.last() {
    Some(top) if top == id => ()
    _ => hot_lower_impl_emit_root(func, id, use_def, label_stack, stack, out)
  }
}

///|
fn hot_lower_impl_emit_inputs(
  func : HotFunc,
  inputs : Array[NodeId],
  use_def : HotUseDef,
  label_stack : Array[LabelId],
  stack : Array[NodeId],
  out : Array[Instruction],
) -> Unit {
  let matched = hot_lower_impl_matching_input_prefix(stack, inputs)
  for i = matched; i < inputs.length(); i = i + 1 {
    hot_lower_impl_emit_value(func, inputs[i], use_def, label_stack, stack, out)
  }
}

///|
fn hot_lower_impl_emit_root(
  func : HotFunc,
  id : NodeId,
  use_def : HotUseDef,
  label_stack : Array[LabelId],
  stack : Array[NodeId],
  out : Array[Instruction],
) -> Unit {
  if hot_node_result_arity(func, id) > 0 {
    match stack.last() {
      Some(top) if top == id => return
      _ => ()
    }
  }
  hot_lower_impl_emit_inputs(
    func,
    hot_lower_impl_input_nodes(func, id),
    use_def,
    label_stack,
    stack,
    out,
  )
  hot_lower_impl_emit_instruction(func, id, use_def, label_stack, out)
  hot_lower_impl_update_stack(func, id, stack)
}

///|
fn hot_lower_impl_declared_locals(func : HotFunc) -> Array[ValType] {
  let out : Array[ValType] = []
  for local_ in func.locals.locals {
    out.push(local_)
  }
  out
}

///|
pub fn hot_lower_body(func : HotFunc) -> Expr {
  hot_verify_all_or_abort(func)
  let use_def = use_def_build(func)
  let out : Array[Instruction] = []
  let value_stack : Array[NodeId] = []
  let root_ids = hot_root_span(func)
  let preserve_region_results = hot_lower_impl_preserve_region_result_roots(
    func,
    use_def,
    root_ids,
    hot_type_result_arity(func, hot_body_result_type(func)),
  )
  for i = 0; i < hot_root_count(func); i = i + 1 {
    let root_id = root_ids[i]
    hot_lower_impl_emit_root(func, root_id, use_def, [], value_stack, out)
    hot_lower_impl_drop_dead_nonfinal_root_results(
      func,
      root_id,
      use_def,
      preserve_region_results[i],
      i + 1 == hot_root_count(func),
      value_stack,
      out,
    )
  }
  Expr::new(out)
}

///|
pub fn hot_lower_func(func : HotFunc) -> @lib.Func {
  @lib.Func::new(
    @lib.Locals::from_types(hot_lower_impl_declared_locals(func)),
    hot_lower_body(func),
  )
}
