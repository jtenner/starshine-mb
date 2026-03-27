///|
pub enum HotLiftError {
  InvalidLabelDepth(Int)
  InvalidFunctionIndex(FuncIdx)
  MissingFunctionBody(FuncIdx)
  MissingFunctionType(FuncIdx)
  InvalidBodyState(String)
  TypecheckFailure(String, String)
  UnsupportedInstruction(String)
} derive(Eq, Show, Debug)

///|
priv struct HotLiftLabelFrames {
  active : Array[LabelId]
}

///|
fn hot_lift_impl_new_label_frames() -> HotLiftLabelFrames {
  { active: [] }
}

///|
fn hot_lift_impl_push_label(
  frames : HotLiftLabelFrames,
  label_stack_head : Int,
  label_id : LabelId,
) -> Int {
  ignore(label_stack_head)
  frames.active.push(label_id)
  frames.active.length() - 1
}

///|
fn hot_lift_impl_pop_label(
  frames : HotLiftLabelFrames,
  label_stack_head : Int,
) -> Unit {
  ignore(label_stack_head)
  match frames.active.pop() {
    Some(_) => ()
    None => abort("hot lift label pop requires a non-empty active label stack")
  }
}

///|
fn hot_lift_impl_result_type(
  func : HotFunc,
  result_types : Array[ValType],
) -> TypeId {
  match result_types.length() {
    0 => hot_type_void(func)
    1 => hot_type_intern_value(func, result_types[0])
    _ => hot_type_intern_results(func, result_types)
  }
}

///|
fn hot_lift_impl_fail_typecheck(
  instr : Instruction,
  err : String,
) -> HotLiftError {
  HotLiftError::TypecheckFailure(instr.to_string(), err)
}

///|
fn hot_lift_impl_all_locals(locals : HotLocals) -> @lib.Locals {
  let out : Array[ValType] = []
  if locals.params.length() > 0 {
    for param in locals.params {
      out.push(param)
    }
  } else {
    for _ in 0..<locals.param_count {
      out.push(@lib.ValType::bottom())
    }
  }
  for local_ in locals.locals {
    out.push(local_)
  }
  @lib.Locals::from_types(out)
}

///|
fn hot_lift_impl_declared_locals(locals : @lib.Locals) -> Array[ValType] {
  let out : Array[ValType] = []
  for vt in locals.iter() {
    out.push(vt)
  }
  out
}

///|
fn hot_lift_impl_env_from_context(
  ctx : HotModuleContext,
  locals : HotLocals,
  return_types : Array[ValType],
) -> Env {
  let env = empty_env()
    .with_types(ctx.subtypes)
    .with_funcs_and_type_idxs(ctx.func_types, ctx.func_type_slots)
    .with_tables(ctx.tables)
    .with_mems(ctx.mems)
    .with_globals(ctx.globals)
    .with_elems(ctx.elems)
    .with_datas(ctx.datas)
    .with_tags(ctx.tags)
    .with_locals(hot_lift_impl_all_locals(locals))
    .with_return_type(Some(return_types))
  env
}

///|
fn hot_lift_impl_env_without_context(
  locals : HotLocals,
  return_types : Array[ValType],
) -> Env {
  empty_env()
  .with_locals(hot_lift_impl_all_locals(locals))
  .with_return_type(Some(return_types))
}

///|
fn hot_lift_impl_block_results(
  env : Env,
  block_type : BlockType,
) -> Result[(Array[ValType], Array[ValType]), HotLiftError] {
  match env.expand_blocktype(block_type) {
    Ok(types) => Ok(types)
    Err(err) =>
      Err(
        HotLiftError::InvalidBodyState(
          "invalid block type \{block_type}: \{err}",
        ),
      )
  }
}

///|
fn hot_lift_impl_pop_concrete_type(concrete_values : Array[ValType]) -> ValType {
  match concrete_values.pop() {
    Some(ty) => ty
    None => abort("hot lift concrete stack underflow")
  }
}

///|
fn hot_lift_impl_pop_value(
  values : Array[NodeId],
  concrete_values : Array[ValType],
) -> NodeId {
  match values.pop() {
    Some(id) => {
      ignore(hot_lift_impl_pop_concrete_type(concrete_values))
      id
    }
    None => abort("hot lift stack underflow")
  }
}

///|
fn hot_lift_impl_pop_values(
  values : Array[NodeId],
  concrete_values : Array[ValType],
  count : Int,
) -> Array[NodeId] {
  let out = Array::make(count, HOT_NONE_NODE)
  for idx = count - 1; idx >= 0; idx = idx - 1 {
    out[idx] = hot_lift_impl_pop_value(values, concrete_values)
  }
  out
}

///|
fn hot_lift_impl_pop_typed_values(
  values : Array[NodeId],
  concrete_values : Array[ValType],
  count : Int,
) -> (Array[NodeId], Array[ValType]) {
  let out_values = Array::make(count, HOT_NONE_NODE)
  let out_types = Array::make(count, @lib.ValType::i32())
  for idx = count - 1; idx >= 0; idx = idx - 1 {
    match values.pop() {
      Some(id) => {
        out_values[idx] = id
        out_types[idx] = hot_lift_impl_pop_concrete_type(concrete_values)
      }
      None => abort("hot lift stack underflow")
    }
  }
  (out_values, out_types)
}

///|
fn hot_lift_impl_peek_values_with_extra(
  values : Array[NodeId],
  count : Int,
  extra : NodeId,
) -> Array[NodeId] {
  let out = Array::make(count + 1, extra)
  let start = values.length() - count
  for i = 0; i < count; i = i + 1 {
    out[i] = values[start + i]
  }
  out
}

///|
fn hot_lift_impl_require_value_count(
  instr : Instruction,
  values : Array[NodeId],
  count : Int,
  context : String,
) -> Result[Unit, HotLiftError] {
  if count <= values.length() {
    return Ok(())
  }
  Err(
    HotLiftError::InvalidBodyState(
      "hot lift stack underflow in \{context} for \{instr}: need \{count}, have \{values.length()}",
    ),
  )
}

///|
fn hot_lift_impl_pop_value_for_instr(
  instr : Instruction,
  values : Array[NodeId],
  concrete_values : Array[ValType],
  context : String,
) -> Result[NodeId, HotLiftError] {
  match hot_lift_impl_require_value_count(instr, values, 1, context) {
    Ok(_) => Ok(hot_lift_impl_pop_value(values, concrete_values))
    Err(err) => Err(err)
  }
}

///|
fn hot_lift_impl_pop_values_for_instr(
  instr : Instruction,
  values : Array[NodeId],
  concrete_values : Array[ValType],
  count : Int,
  context : String,
) -> Result[Array[NodeId], HotLiftError] {
  match hot_lift_impl_require_value_count(instr, values, count, context) {
    Ok(_) => Ok(hot_lift_impl_pop_values(values, concrete_values, count))
    Err(err) => Err(err)
  }
}

///|
fn hot_lift_impl_pop_typed_values_for_instr(
  instr : Instruction,
  values : Array[NodeId],
  concrete_values : Array[ValType],
  count : Int,
  context : String,
) -> Result[(Array[NodeId], Array[ValType]), HotLiftError] {
  match hot_lift_impl_require_value_count(instr, values, count, context) {
    Ok(_) => Ok(hot_lift_impl_pop_typed_values(values, concrete_values, count))
    Err(err) => Err(err)
  }
}

///|
fn hot_lift_impl_resolve_label(
  frames : HotLiftLabelFrames,
  label_stack_head : Int,
  label_idx : LabelIdx,
) -> Result[LabelId, HotLiftError] {
  ignore(label_stack_head)
  let LabelIdx(raw) = label_idx
  let depth = raw.reinterpret_as_int()
  let idx = frames.active.length() - 1 - depth
  if idx >= 0 && idx < frames.active.length() {
    return Ok(frames.active[idx])
  }
  Err(HotLiftError::InvalidLabelDepth(raw.reinterpret_as_int()))
}

///|
fn hot_lift_impl_try_catch_arm(
  frames : HotLiftLabelFrames,
  label_stack_head : Int,
  catch_ : Catch,
) -> Result[HotCatchArm, HotLiftError] {
  match catch_ {
    Catch::Catch(tag_idx, label_idx) =>
      match hot_lift_impl_resolve_label(frames, label_stack_head, label_idx) {
        Ok(label_id) => Ok(HotCatchArm::catch_(tag_idx, label_id))
        Err(err) => Err(err)
      }
    Catch::CatchRef(tag_idx, label_idx) =>
      match hot_lift_impl_resolve_label(frames, label_stack_head, label_idx) {
        Ok(label_id) => Ok(HotCatchArm::catch_ref(tag_idx, label_id))
        Err(err) => Err(err)
      }
    Catch::CatchAll(label_idx) =>
      match hot_lift_impl_resolve_label(frames, label_stack_head, label_idx) {
        Ok(label_id) => Ok(HotCatchArm::all(label_id))
        Err(err) => Err(err)
      }
    Catch::CatchAllRef(label_idx) =>
      match hot_lift_impl_resolve_label(frames, label_stack_head, label_idx) {
        Ok(label_id) => Ok(HotCatchArm::all_ref(label_id))
        Err(err) => Err(err)
      }
  }
}

///|
fn hot_lift_impl_make_region(
  func : HotFunc,
  body : Array[NodeId],
  result_arity : Int,
) -> NodeId {
  let id = hot_build_node(
    func,
    HotOp::Block,
    hot_type_void(func),
    children=body,
  )
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::RegionLabel,
    hot_type_void(func),
    id,
    result_arity,
  )
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
  id
}

///|
fn hot_lift_impl_intern_control_result_type(
  func : HotFunc,
  block_type : BlockType,
  results : Array[ValType],
) -> TypeId {
  match block_type {
    TypeIdxBlockType(_) =>
      hot_type_intern_resolved_block_result(func, block_type, results)
    _ => hot_type_intern_block_result(func, block_type)
  }
}

///|
fn hot_lift_impl_stack_suffix(
  types : Array[ValType],
  suffix_len : Int,
) -> Array[ValType] {
  let out : Array[ValType] = []
  let start = types.length() - suffix_len
  for i = start; i < types.length(); i = i + 1 {
    out.push(types[i])
  }
  out
}

///|
fn hot_lift_impl_matches_candidate_after(
  before_types : Array[ValType],
  after_state : TcState,
  pop_count : Int,
  candidate_after : TcState,
) -> Bool {
  if candidate_after.reachable != after_state.reachable ||
    candidate_after.escape != after_state.escape {
    return false
  }
  let prefix_len = before_types.length() - pop_count
  if prefix_len + candidate_after.stack.length() != after_state.stack.length() {
    return false
  }
  for i = 0; i < prefix_len; i = i + 1 {
    if before_types[i] != after_state.stack[i] {
      return false
    }
  }
  for i = 0; i < candidate_after.stack.length(); i = i + 1 {
    if candidate_after.stack[i] != after_state.stack[prefix_len + i] {
      return false
    }
  }
  true
}

///|
fn hot_lift_impl_generic_pop_count(
  instr : Instruction,
  candidate_before_types : Array[ValType],
  before_state : TcState,
  after_state : TcState,
  min_count : Int,
) -> Result[(Int, Array[ValType]), HotLiftError] {
  for count = min_count
      count <= candidate_before_types.length()
      count = count + 1 {
    let candidate_state = tc_state_with_owned_stack(
      before_state,
      hot_lift_impl_stack_suffix(candidate_before_types, count),
    )
    match Typecheck::typecheck(instr, candidate_state) {
      Ok(candidate_after) =>
        if hot_lift_impl_matches_candidate_after(
            candidate_before_types, after_state, count, candidate_after,
          ) {
          return Ok((count, candidate_after.stack))
        }
      Err(_) => ()
    }
  }
  Err(
    HotLiftError::InvalidBodyState(
      "unable to derive concrete operand count for \{instr}: before=\{candidate_before_types} after=\{after_state.stack} reachable=\{before_state.reachable}",
    ),
  )
}

///|
fn hot_lift_impl_resolve_generic_pop_count(
  instr : Instruction,
  before_state : TcState,
  after_state : TcState,
  concrete_before_types : Array[ValType],
) -> Result[(Int, Array[ValType]), HotLiftError] {
  let primary = hot_lift_impl_generic_pop_count(
    instr,
    before_state.stack,
    before_state,
    after_state,
    0,
  )
  if concrete_before_types.length() == 0 {
    return primary
  }
  let can_promote = match instr {
    Instruction::Nop
    | Instruction::Unreachable
    | Instruction::I32Const(_)
    | Instruction::I64Const(_)
    | Instruction::F32Const(_)
    | Instruction::F64Const(_)
    | Instruction::RefNull(_)
    | Instruction::StringConst(_)
    | Instruction::RefFunc(_)
    | Instruction::LocalGet(_)
    | Instruction::GlobalGet(_)
    | Instruction::MemorySize(_)
    | Instruction::TableSize(_)
    | Instruction::DataDrop(_)
    | Instruction::ElemDrop(_) => false
    _ => true
  }
  if !can_promote {
    return primary
  }
  if before_state.reachable {
    let has_concrete_prefix = concrete_before_types.length() >
      before_state.stack.length()
    return match primary {
      Ok((count, _)) if count > 0 => primary
      Ok(_) if has_concrete_prefix =>
        match
          hot_lift_impl_generic_pop_count(
            instr, concrete_before_types, before_state, after_state, 1,
          ) {
          Ok(promoted) => Ok(promoted)
          Err(_) => primary
        }
      Err(_) if has_concrete_prefix =>
        hot_lift_impl_generic_pop_count(
          instr, concrete_before_types, before_state, after_state, 1,
        )
      _ => primary
    }
  }
  match primary {
    Ok((count, _)) if count > 0 => primary
    Ok(_) =>
      match
        hot_lift_impl_generic_pop_count(
          instr, concrete_before_types, before_state, after_state, 1,
        ) {
        Ok(promoted) => Ok(promoted)
        Err(_) => primary
      }
    Err(_) =>
      hot_lift_impl_generic_pop_count(
        instr, concrete_before_types, before_state, after_state, 1,
      )
  }
}

///|
fn hot_lift_impl_call_param_count(env : Env, instr : Instruction) -> Int? {
  match instr {
    Instruction::Call(func_idx) | Instruction::ReturnCall(func_idx) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(params, _)) => Some(params.length())
        None => None
      }
    Instruction::CallIndirect(type_idx, _)
    | Instruction::ReturnCallIndirect(type_idx, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => Some(params.length() + 1)
        None => None
      }
    Instruction::CallRef(type_idx) | Instruction::ReturnCallRef(type_idx) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => Some(params.length() + 1)
        None => None
      }
    _ => None
  }
}

///|
fn hot_lift_impl_known_pop_count(instr : Instruction, env : Env) -> Int? {
  match hot_lift_impl_direct_family(instr) {
    Some(HotOp::Nop)
    | Some(HotOp::Unreachable)
    | Some(HotOp::Const)
    | Some(HotOp::LocalGet)
    | Some(HotOp::GlobalGet)
    | Some(HotOp::TableSize)
    | Some(HotOp::MemorySize)
    | Some(HotOp::ElemDrop)
    | Some(HotOp::DataDrop)
    | Some(HotOp::RefNull)
    | Some(HotOp::RefFunc) => return Some(0)
    Some(HotOp::LocalSet)
    | Some(HotOp::LocalTee)
    | Some(HotOp::GlobalSet)
    | Some(HotOp::TableGet)
    | Some(HotOp::MemoryGrow)
    | Some(HotOp::Drop)
    | Some(HotOp::RefIsNull) => return Some(1)
    Some(HotOp::TableSet) | Some(HotOp::TableGrow) => return Some(2)
    Some(HotOp::TableFill)
    | Some(HotOp::TableCopy)
    | Some(HotOp::TableInit)
    | Some(HotOp::MemoryCopy)
    | Some(HotOp::MemoryFill)
    | Some(HotOp::MemoryInit) => return Some(3)
    Some(HotOp::Call) =>
      match hot_lift_impl_call_param_count(env, instr) {
        Some(count) => return Some(count)
        None => ()
      }
    _ => ()
  }
  match hot_lift_impl_exact_family(instr) {
    Some(HotOp::Select) => Some(3)
    Some(HotOp::Load)
    | Some(HotOp::RefTest)
    | Some(HotOp::RefCast)
    | Some(HotOp::RefTestDesc)
    | Some(HotOp::RefCastDescEq)
    | Some(HotOp::Unary)
    | Some(HotOp::Convert) => Some(1)
    Some(HotOp::Store) | Some(HotOp::Binary) | Some(HotOp::Compare) => Some(2)
    Some(HotOp::Heap) =>
      match instr {
        Instruction::StructGet(_, _)
        | Instruction::StructGetS(_, _)
        | Instruction::StructGetU(_, _)
        | Instruction::ArrayLen
        | Instruction::RefAsNonNull
        | Instruction::AnyConvertExtern
        | Instruction::ExternConvertAny
        | Instruction::RefI31
        | Instruction::I31GetS
        | Instruction::I31GetU => Some(1)
        Instruction::StructSet(_, _)
        | Instruction::ArrayGet(_)
        | Instruction::ArrayGetS(_)
        | Instruction::ArrayGetU(_)
        | Instruction::RefEq => Some(2)
        Instruction::ArraySet(_) => Some(3)
        _ => None
      }
    Some(HotOp::Atomic) =>
      match instr {
        Instruction::I32AtomicLoad(_)
        | Instruction::I64AtomicLoad(_)
        | Instruction::I32AtomicLoad8U(_)
        | Instruction::I32AtomicLoad16U(_)
        | Instruction::I64AtomicLoad8U(_)
        | Instruction::I64AtomicLoad16U(_)
        | Instruction::I64AtomicLoad32U(_) => Some(1)
        Instruction::MemoryAtomicNotify(_)
        | Instruction::AtomicRmw(_, _)
        | Instruction::I32AtomicStore(_)
        | Instruction::I64AtomicStore(_)
        | Instruction::I32AtomicStore8(_)
        | Instruction::I32AtomicStore16(_)
        | Instruction::I64AtomicStore8(_)
        | Instruction::I64AtomicStore16(_)
        | Instruction::I64AtomicStore32(_) => Some(2)
        Instruction::MemoryAtomicWait32(_)
        | Instruction::MemoryAtomicWait64(_)
        | Instruction::AtomicCmpxchg(_, _) => Some(3)
        _ => None
      }
    _ => None
  }
}

///|
fn hot_lift_impl_can_materialize_unreachable_instr(
  instr : Instruction,
  tc_state : TcState,
  concrete_values : Array[ValType],
  child_count : Int,
) -> Bool {
  if child_count > concrete_values.length() {
    return false
  }
  if tc_state.reachable {
    return true
  }
  match
    Typecheck::typecheck(
      instr,
      make_state_owned(
        tc_state.env,
        hot_lift_impl_stack_suffix(concrete_values, child_count),
      ),
    ) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn hot_lift_impl_direct_family(instr : Instruction) -> HotOp? {
  match instr {
    Instruction::Nop => Some(HotOp::Nop)
    Instruction::Unreachable => Some(HotOp::Unreachable)
    Instruction::I32Const(_)
    | Instruction::I64Const(_)
    | Instruction::F32Const(_)
    | Instruction::F64Const(_)
    | Instruction::StringConst(_) => Some(HotOp::Const)
    Instruction::LocalGet(_) => Some(HotOp::LocalGet)
    Instruction::LocalSet(_) => Some(HotOp::LocalSet)
    Instruction::LocalTee(_) => Some(HotOp::LocalTee)
    Instruction::GlobalGet(_) => Some(HotOp::GlobalGet)
    Instruction::GlobalSet(_) => Some(HotOp::GlobalSet)
    Instruction::TableGet(_) => Some(HotOp::TableGet)
    Instruction::TableSet(_) => Some(HotOp::TableSet)
    Instruction::TableSize(_) => Some(HotOp::TableSize)
    Instruction::TableGrow(_) => Some(HotOp::TableGrow)
    Instruction::TableFill(_) => Some(HotOp::TableFill)
    Instruction::TableCopy(_, _) => Some(HotOp::TableCopy)
    Instruction::TableInit(_, _) => Some(HotOp::TableInit)
    Instruction::ElemDrop(_) => Some(HotOp::ElemDrop)
    Instruction::MemorySize(_) => Some(HotOp::MemorySize)
    Instruction::MemoryGrow(_) => Some(HotOp::MemoryGrow)
    Instruction::MemoryCopy(_, _) => Some(HotOp::MemoryCopy)
    Instruction::MemoryFill(_) => Some(HotOp::MemoryFill)
    Instruction::MemoryInit(_, _) => Some(HotOp::MemoryInit)
    Instruction::DataDrop(_) => Some(HotOp::DataDrop)
    Instruction::Drop => Some(HotOp::Drop)
    Instruction::Call(_) => Some(HotOp::Call)
    Instruction::CallIndirect(_, _) => Some(HotOp::CallIndirect)
    Instruction::CallRef(_) => Some(HotOp::CallRef)
    Instruction::ReturnCall(_) => Some(HotOp::ReturnCall)
    Instruction::ReturnCallIndirect(_, _) => Some(HotOp::ReturnCallIndirect)
    Instruction::ReturnCallRef(_) => Some(HotOp::ReturnCallRef)
    Instruction::RefNull(_) => Some(HotOp::RefNull)
    Instruction::RefIsNull => Some(HotOp::RefIsNull)
    Instruction::RefFunc(_) => Some(HotOp::RefFunc)
    Instruction::Throw(_) => Some(HotOp::Throw)
    Instruction::ThrowRef => Some(HotOp::ThrowRef)
    _ => None
  }
}

///|
fn hot_lift_impl_exact_family(instr : Instruction) -> HotOp? {
  match instr {
    Instruction::Select(_) => Some(HotOp::Select)
    Instruction::I32Load(_)
    | Instruction::I64Load(_)
    | Instruction::F32Load(_)
    | Instruction::F64Load(_)
    | Instruction::I32Load8S(_)
    | Instruction::I32Load8U(_)
    | Instruction::I32Load16S(_)
    | Instruction::I32Load16U(_)
    | Instruction::I64Load8S(_)
    | Instruction::I64Load8U(_)
    | Instruction::I64Load16S(_)
    | Instruction::I64Load16U(_)
    | Instruction::I64Load32S(_)
    | Instruction::I64Load32U(_) => Some(HotOp::Load)
    Instruction::I32Store(_)
    | Instruction::I64Store(_)
    | Instruction::F32Store(_)
    | Instruction::F64Store(_)
    | Instruction::I32Store8(_)
    | Instruction::I32Store16(_)
    | Instruction::I64Store8(_)
    | Instruction::I64Store16(_)
    | Instruction::I64Store32(_) => Some(HotOp::Store)
    Instruction::RefTest(_, _) => Some(HotOp::RefTest)
    Instruction::RefCast(_, _) => Some(HotOp::RefCast)
    Instruction::RefTestDesc(_, _) => Some(HotOp::RefTestDesc)
    Instruction::RefCastDescEq(_, _) => Some(HotOp::RefCastDescEq)
    Instruction::StringNewUtf8Array
    | Instruction::StringNewWtf16Array
    | Instruction::StringEncodeUtf8Array
    | Instruction::StringEncodeWtf16Array
    | Instruction::StringNewLossyUtf8Array
    | Instruction::StringNewWtf8Array
    | Instruction::StringEncodeLossyUtf8Array
    | Instruction::StringEncodeWtf8Array => Some(HotOp::StringOp)
    Instruction::MemoryAtomicNotify(_)
    | Instruction::MemoryAtomicWait32(_)
    | Instruction::MemoryAtomicWait64(_)
    | Instruction::I32AtomicLoad(_)
    | Instruction::I64AtomicLoad(_)
    | Instruction::I32AtomicLoad8U(_)
    | Instruction::I32AtomicLoad16U(_)
    | Instruction::I64AtomicLoad8U(_)
    | Instruction::I64AtomicLoad16U(_)
    | Instruction::I64AtomicLoad32U(_)
    | Instruction::I32AtomicStore(_)
    | Instruction::I64AtomicStore(_)
    | Instruction::I32AtomicStore8(_)
    | Instruction::I32AtomicStore16(_)
    | Instruction::I64AtomicStore8(_)
    | Instruction::I64AtomicStore16(_)
    | Instruction::I64AtomicStore32(_)
    | Instruction::AtomicRmw(_, _)
    | Instruction::AtomicCmpxchg(_, _) => Some(HotOp::Atomic)
    Instruction::StructNew(_)
    | Instruction::StructNewDefault(_)
    | Instruction::StructNewDesc(_)
    | Instruction::StructNewDefaultDesc(_)
    | Instruction::StructGet(_, _)
    | Instruction::StructGetS(_, _)
    | Instruction::StructGetU(_, _)
    | Instruction::StructSet(_, _)
    | Instruction::ArrayNew(_)
    | Instruction::ArrayNewDefault(_)
    | Instruction::ArrayNewFixed(_, _)
    | Instruction::ArrayNewData(_, _)
    | Instruction::ArrayNewElem(_, _)
    | Instruction::ArrayGet(_)
    | Instruction::ArrayGetS(_)
    | Instruction::ArrayGetU(_)
    | Instruction::ArraySet(_)
    | Instruction::ArrayLen
    | Instruction::ArrayFill(_)
    | Instruction::ArrayCopy(_, _)
    | Instruction::ArrayInitData(_, _)
    | Instruction::ArrayInitElem(_, _)
    | Instruction::RefEq
    | Instruction::RefAsNonNull
    | Instruction::RefGetDesc(_)
    | Instruction::AnyConvertExtern
    | Instruction::ExternConvertAny
    | Instruction::RefI31
    | Instruction::I31GetS
    | Instruction::I31GetU => Some(HotOp::Heap)
    Instruction::I32Eqz
    | Instruction::I64Eqz
    | Instruction::I32Clz
    | Instruction::I32Ctz
    | Instruction::I32Popcnt
    | Instruction::I64Clz
    | Instruction::I64Ctz
    | Instruction::I64Popcnt
    | Instruction::F32Abs
    | Instruction::F32Neg
    | Instruction::F32Ceil
    | Instruction::F32Floor
    | Instruction::F32Trunc
    | Instruction::F32Nearest
    | Instruction::F32Sqrt
    | Instruction::F64Abs
    | Instruction::F64Neg
    | Instruction::F64Ceil
    | Instruction::F64Floor
    | Instruction::F64Trunc
    | Instruction::F64Nearest
    | Instruction::F64Sqrt
    | Instruction::I32Extend8S
    | Instruction::I32Extend16S
    | Instruction::I64Extend8S
    | Instruction::I64Extend16S
    | Instruction::I64Extend32S => Some(HotOp::Unary)
    Instruction::I32Eq
    | Instruction::I32Ne
    | Instruction::I32LtS
    | Instruction::I32LtU
    | Instruction::I32GtS
    | Instruction::I32GtU
    | Instruction::I32LeS
    | Instruction::I32LeU
    | Instruction::I32GeS
    | Instruction::I32GeU
    | Instruction::I64Eq
    | Instruction::I64Ne
    | Instruction::I64LtS
    | Instruction::I64LtU
    | Instruction::I64GtS
    | Instruction::I64GtU
    | Instruction::I64LeS
    | Instruction::I64LeU
    | Instruction::I64GeS
    | Instruction::I64GeU
    | Instruction::F32Eq
    | Instruction::F32Ne
    | Instruction::F32Lt
    | Instruction::F32Gt
    | Instruction::F32Le
    | Instruction::F32Ge
    | Instruction::F64Eq
    | Instruction::F64Ne
    | Instruction::F64Lt
    | Instruction::F64Gt
    | Instruction::F64Le
    | Instruction::F64Ge => Some(HotOp::Compare)
    Instruction::I32Add
    | Instruction::I32Sub
    | Instruction::I32Mul
    | Instruction::I32DivS
    | Instruction::I32DivU
    | Instruction::I32RemS
    | Instruction::I32RemU
    | Instruction::I32And
    | Instruction::I32Or
    | Instruction::I32Xor
    | Instruction::I32Shl
    | Instruction::I32ShrS
    | Instruction::I32ShrU
    | Instruction::I32Rotl
    | Instruction::I32Rotr
    | Instruction::I64Add
    | Instruction::I64Sub
    | Instruction::I64Mul
    | Instruction::I64DivS
    | Instruction::I64DivU
    | Instruction::I64RemS
    | Instruction::I64RemU
    | Instruction::I64And
    | Instruction::I64Or
    | Instruction::I64Xor
    | Instruction::I64Shl
    | Instruction::I64ShrS
    | Instruction::I64ShrU
    | Instruction::I64Rotl
    | Instruction::I64Rotr
    | Instruction::F32Add
    | Instruction::F32Sub
    | Instruction::F32Mul
    | Instruction::F32Div
    | Instruction::F32Min
    | Instruction::F32Max
    | Instruction::F32Copysign
    | Instruction::F64Add
    | Instruction::F64Sub
    | Instruction::F64Mul
    | Instruction::F64Div
    | Instruction::F64Min
    | Instruction::F64Max
    | Instruction::F64Copysign => Some(HotOp::Binary)
    Instruction::I32WrapI64
    | Instruction::I32TruncF32S
    | Instruction::I32TruncF32U
    | Instruction::I32TruncF64S
    | Instruction::I32TruncF64U
    | Instruction::I64ExtendI32S
    | Instruction::I64ExtendI32U
    | Instruction::I64TruncF32S
    | Instruction::I64TruncF32U
    | Instruction::I64TruncF64S
    | Instruction::I64TruncF64U
    | Instruction::F32ConvertI32S
    | Instruction::F32ConvertI32U
    | Instruction::F32ConvertI64S
    | Instruction::F32ConvertI64U
    | Instruction::F32DemoteF64
    | Instruction::F64ConvertI32S
    | Instruction::F64ConvertI32U
    | Instruction::F64ConvertI64S
    | Instruction::F64ConvertI64U
    | Instruction::F64PromoteF32
    | Instruction::I32ReinterpretF32
    | Instruction::I64ReinterpretF64
    | Instruction::F32ReinterpretI32
    | Instruction::F64ReinterpretI64
    | Instruction::I32TruncSatF32S
    | Instruction::I32TruncSatF32U
    | Instruction::I32TruncSatF64S
    | Instruction::I32TruncSatF64U
    | Instruction::I64TruncSatF32S
    | Instruction::I64TruncSatF32U
    | Instruction::I64TruncSatF64S
    | Instruction::I64TruncSatF64U => Some(HotOp::Convert)
    Instruction::V128Load(_)
    | Instruction::V128Load8x8S(_)
    | Instruction::V128Load8x8U(_)
    | Instruction::V128Load16x4S(_)
    | Instruction::V128Load16x4U(_)
    | Instruction::V128Load32x2S(_)
    | Instruction::V128Load32x2U(_)
    | Instruction::V128Load8Splat(_)
    | Instruction::V128Load16Splat(_)
    | Instruction::V128Load32Splat(_)
    | Instruction::V128Load64Splat(_)
    | Instruction::V128Store(_)
    | Instruction::V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | Instruction::I8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | Instruction::I8x16Swizzle
    | Instruction::I8x16Splat
    | Instruction::I16x8Splat
    | Instruction::I32x4Splat
    | Instruction::I64x2Splat
    | Instruction::F32x4Splat
    | Instruction::F64x2Splat
    | Instruction::I8x16ExtractLaneS(_)
    | Instruction::I8x16ExtractLaneU(_)
    | Instruction::I8x16ReplaceLane(_)
    | Instruction::I16x8ExtractLaneS(_)
    | Instruction::I16x8ExtractLaneU(_)
    | Instruction::I16x8ReplaceLane(_)
    | Instruction::I32x4ExtractLane(_)
    | Instruction::I32x4ReplaceLane(_)
    | Instruction::I64x2ExtractLane(_)
    | Instruction::I64x2ReplaceLane(_)
    | Instruction::F32x4ExtractLane(_)
    | Instruction::F32x4ReplaceLane(_)
    | Instruction::F64x2ExtractLane(_)
    | Instruction::F64x2ReplaceLane(_)
    | Instruction::I8x16Eq
    | Instruction::I8x16Ne
    | Instruction::I8x16LtS
    | Instruction::I8x16LtU
    | Instruction::I8x16GtS
    | Instruction::I8x16GtU
    | Instruction::I8x16LeS
    | Instruction::I8x16LeU
    | Instruction::I8x16GeS
    | Instruction::I8x16GeU
    | Instruction::I16x8Eq
    | Instruction::I16x8Ne
    | Instruction::I16x8LtS
    | Instruction::I16x8LtU
    | Instruction::I16x8GtS
    | Instruction::I16x8GtU
    | Instruction::I16x8LeS
    | Instruction::I16x8LeU
    | Instruction::I16x8GeS
    | Instruction::I16x8GeU
    | Instruction::I32x4Eq
    | Instruction::I32x4Ne
    | Instruction::I32x4LtS
    | Instruction::I32x4LtU
    | Instruction::I32x4GtS
    | Instruction::I32x4GtU
    | Instruction::I32x4LeS
    | Instruction::I32x4LeU
    | Instruction::I32x4GeS
    | Instruction::I32x4GeU
    | Instruction::F32x4Eq
    | Instruction::F32x4Ne
    | Instruction::F32x4Lt
    | Instruction::F32x4Gt
    | Instruction::F32x4Le
    | Instruction::F32x4Ge
    | Instruction::F64x2Eq
    | Instruction::F64x2Ne
    | Instruction::F64x2Lt
    | Instruction::F64x2Gt
    | Instruction::F64x2Le
    | Instruction::F64x2Ge
    | Instruction::V128Not
    | Instruction::V128And
    | Instruction::V128Andnot
    | Instruction::V128Or
    | Instruction::V128Xor
    | Instruction::V128Bitselect
    | Instruction::V128AnyTrue
    | Instruction::V128Load8Lane(_, _)
    | Instruction::V128Load16Lane(_, _)
    | Instruction::V128Load32Lane(_, _)
    | Instruction::V128Load64Lane(_, _)
    | Instruction::V128Store8Lane(_, _)
    | Instruction::V128Store16Lane(_, _)
    | Instruction::V128Store32Lane(_, _)
    | Instruction::V128Store64Lane(_, _)
    | Instruction::V128Load32Zero(_)
    | Instruction::V128Load64Zero(_)
    | Instruction::F32x4DemoteF64x2Zero
    | Instruction::F64x2PromoteLowF32x4 => Some(HotOp::Simd)
    _ => None
  }
}

///|
fn hot_lift_impl_direct_node_shape(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
) -> (HotOp, TypeId, Int, Int) {
  let ty = hot_lift_impl_result_type(func, result_types)
  match instr {
    Instruction::LocalGet(LocalIdx(raw))
    | Instruction::LocalSet(LocalIdx(raw))
    | Instruction::LocalTee(LocalIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::GlobalGet(GlobalIdx(raw))
    | Instruction::GlobalSet(GlobalIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::TableGet(TableIdx(raw))
    | Instruction::TableSet(TableIdx(raw))
    | Instruction::TableSize(TableIdx(raw))
    | Instruction::TableGrow(TableIdx(raw))
    | Instruction::TableFill(TableIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::TableCopy(TableIdx(dst), TableIdx(src)) =>
      (op, ty, dst.reinterpret_as_int(), src.reinterpret_as_int())
    Instruction::TableInit(ElemIdx(elem), TableIdx(table)) =>
      (op, ty, elem.reinterpret_as_int(), table.reinterpret_as_int())
    Instruction::ElemDrop(ElemIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::MemorySize(MemIdx(raw))
    | Instruction::MemoryGrow(MemIdx(raw))
    | Instruction::MemoryFill(MemIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::MemoryCopy(MemIdx(dst), MemIdx(src)) =>
      (op, ty, dst.reinterpret_as_int(), src.reinterpret_as_int())
    Instruction::MemoryInit(DataIdx(data), MemIdx(mem)) =>
      (op, ty, data.reinterpret_as_int(), mem.reinterpret_as_int())
    Instruction::DataDrop(DataIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::Call(FuncIdx(raw)) | Instruction::ReturnCall(FuncIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::CallIndirect(type_idx, table_idx)
    | Instruction::ReturnCallIndirect(type_idx, table_idx) => {
      let sig_id = hot_alloc_call_sig(
        func,
        HotCallSig::new(type_idx, table_idx=Some(table_idx)),
      )
      (op, ty, sig_id, 0)
    }
    Instruction::CallRef(type_idx) | Instruction::ReturnCallRef(type_idx) => {
      let sig_id = hot_alloc_call_sig(func, HotCallSig::new(type_idx))
      (op, ty, sig_id, 0)
    }
    Instruction::I32Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::i32_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::I64Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::i64_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::F32Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::f32_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::F64Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::f64_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::RefNull(rt) => {
      let const_id = hot_alloc_const(func, HotConstPayload::ref_null_const(rt))
      (HotOp::RefNull, ty, const_id, 0)
    }
    Instruction::StringConst(bytes) => {
      let const_id = hot_alloc_const(func, HotConstPayload::string_const(bytes))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::RefFunc(FuncIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::Throw(TagIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    _ => (op, ty, 0, 0)
  }
}

///|
fn hot_lift_impl_build_direct_node(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  children : Array[NodeId],
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_direct_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node(func, build_op, ty, imm0~, imm1~, children~)
}

///|
fn hot_lift_impl_build_direct_node1(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  child0 : NodeId,
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_direct_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node1(func, build_op, ty, child0, imm0~, imm1~)
}

///|
fn hot_lift_impl_build_direct_node2(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  child0 : NodeId,
  child1 : NodeId,
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_direct_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node2(func, build_op, ty, child0, child1, imm0~, imm1~)
}

///|
fn hot_lift_impl_build_direct_node3(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  child0 : NodeId,
  child1 : NodeId,
  child2 : NodeId,
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_direct_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node3(func, build_op, ty, child0, child1, child2, imm0~, imm1~)
}

///|
fn hot_lift_impl_exact_node_shape(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
) -> (HotOp, TypeId, Int, Int) {
  let ty = hot_lift_impl_result_type(func, result_types)
  let payload_id = hot_alloc_instr_payload(func, HotInstrPayload::new(instr))
  match instr {
    Instruction::I32Load(memarg)
    | Instruction::I64Load(memarg)
    | Instruction::F32Load(memarg)
    | Instruction::F64Load(memarg)
    | Instruction::I32Load8S(memarg)
    | Instruction::I32Load8U(memarg)
    | Instruction::I32Load16S(memarg)
    | Instruction::I32Load16U(memarg)
    | Instruction::I64Load8S(memarg)
    | Instruction::I64Load8U(memarg)
    | Instruction::I64Load16S(memarg)
    | Instruction::I64Load16U(memarg)
    | Instruction::I64Load32S(memarg)
    | Instruction::I64Load32U(memarg)
    | Instruction::I32Store(memarg)
    | Instruction::I64Store(memarg)
    | Instruction::F32Store(memarg)
    | Instruction::F64Store(memarg)
    | Instruction::I32Store8(memarg)
    | Instruction::I32Store16(memarg)
    | Instruction::I64Store8(memarg)
    | Instruction::I64Store16(memarg)
    | Instruction::I64Store32(memarg) => {
      let memarg_id = hot_alloc_memarg(func, HotMemArg::new(memarg))
      (op, ty, memarg_id, payload_id)
    }
    Instruction::MemoryAtomicNotify(memarg)
    | Instruction::MemoryAtomicWait32(memarg)
    | Instruction::MemoryAtomicWait64(memarg)
    | Instruction::I32AtomicLoad(memarg)
    | Instruction::I64AtomicLoad(memarg)
    | Instruction::I32AtomicLoad8U(memarg)
    | Instruction::I32AtomicLoad16U(memarg)
    | Instruction::I64AtomicLoad8U(memarg)
    | Instruction::I64AtomicLoad16U(memarg)
    | Instruction::I64AtomicLoad32U(memarg)
    | Instruction::I32AtomicStore(memarg)
    | Instruction::I64AtomicStore(memarg)
    | Instruction::I32AtomicStore8(memarg)
    | Instruction::I32AtomicStore16(memarg)
    | Instruction::I64AtomicStore8(memarg)
    | Instruction::I64AtomicStore16(memarg)
    | Instruction::I64AtomicStore32(memarg)
    | Instruction::AtomicRmw(_, memarg)
    | Instruction::AtomicCmpxchg(_, memarg) => {
      let memarg_id = hot_alloc_memarg(func, HotMemArg::new(memarg))
      (op, ty, memarg_id, payload_id)
    }
    Instruction::RefTest(_, _)
    | Instruction::RefCast(_, _)
    | Instruction::RefTestDesc(_, _)
    | Instruction::RefCastDescEq(_, _) => (op, ty, 0, payload_id)
    _ => (op, ty, payload_id, 0)
  }
}

///|
fn hot_lift_impl_build_exact_node(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  children : Array[NodeId],
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_exact_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node(func, build_op, ty, imm0~, imm1~, children~)
}

///|
fn hot_lift_impl_build_exact_node1(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  child0 : NodeId,
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_exact_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node1(func, build_op, ty, child0, imm0~, imm1~)
}

///|
fn hot_lift_impl_build_exact_node2(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  child0 : NodeId,
  child1 : NodeId,
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_exact_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node2(func, build_op, ty, child0, child1, imm0~, imm1~)
}

///|
fn hot_lift_impl_build_exact_node3(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
  child0 : NodeId,
  child1 : NodeId,
  child2 : NodeId,
) -> NodeId {
  let (build_op, ty, imm0, imm1) = hot_lift_impl_exact_node_shape(
    func, op, instr, result_types,
  )
  hot_build_node3(func, build_op, ty, child0, child1, child2, imm0~, imm1~)
}

///|
fn hot_lift_impl_push_node(
  roots : Array[NodeId],
  values : Array[NodeId],
  concrete_values : Array[ValType],
  node_id : NodeId,
  result_types : Array[ValType],
) -> Unit {
  if result_types.length() == 0 {
    roots.push(node_id)
  } else {
    for ty in result_types {
      values.push(node_id)
      concrete_values.push(ty)
    }
  }
}

///|
fn hot_lift_impl_typecheck(
  instr : Instruction,
  tc_state : TcState,
) -> Result[TcState, HotLiftError] {
  match Typecheck::typecheck(instr, tc_state) {
    Ok(next) => Ok(next)
    Err(err) => Err(hot_lift_impl_fail_typecheck(instr, err))
  }
}

///|
fn hot_lift_impl_invalid_body_state(err : String) -> HotLiftError {
  HotLiftError::InvalidBodyState(err)
}

///|
fn hot_lift_impl_region_state(
  entry_state : TcState,
  region_env : Env,
  entry_types : Array[ValType],
) -> TcState {
  tc_state_new(
    region_env,
    entry_types,
    entry_state.reachable,
    entry_state.escape,
  )
}

///|
fn hot_lift_impl_copy_node_ids(values : Array[NodeId]) -> Array[NodeId] {
  if values.length() == 0 {
    return []
  }
  values.copy()
}

///|
fn hot_lift_impl_copy_val_types(types : Array[ValType]) -> Array[ValType] {
  if types.length() == 0 {
    return []
  }
  types.copy()
}

///|
fn hot_lift_impl_restore_outer_state(
  outer_state : TcState,
  entry_state : TcState,
) -> TcState {
  tc_state_new(
    outer_state.env,
    entry_state.stack,
    outer_state.reachable,
    outer_state.escape,
  )
}

///|
fn hot_lift_impl_pushed_types(
  before_types : Array[ValType],
  after_types : Array[ValType],
  pop_count : Int,
) -> Array[ValType] {
  let prefix_len = before_types.length() - pop_count
  let out : Array[ValType] = []
  for i = prefix_len; i < after_types.length(); i = i + 1 {
    out.push(after_types[i])
  }
  out
}

///|
fn hot_lift_impl_lift_region(
  func : HotFunc,
  expr : Expr,
  tc_state : TcState,
  label_frames : HotLiftLabelFrames,
  label_stack_head : Int,
  initial_values? : Array[NodeId] = [],
  initial_value_types? : Array[ValType] = [],
) -> Result[(Array[NodeId], Array[NodeId], TcState), HotLiftError] {
  let Expr(instrs) = expr
  let mut tc_state = tc_state
  let roots : Array[NodeId] = []
  let values : Array[NodeId] = hot_lift_impl_copy_node_ids(initial_values)
  let concrete_values : Array[ValType] = hot_lift_impl_copy_val_types(
    initial_value_types,
  )
  for instr in instrs {
    match
      hot_lift_impl_lift_instruction(
        func, instr, tc_state, label_frames, label_stack_head, roots, values, concrete_values,
      ) {
      Ok(next) => tc_state = next
      Err(err) => return Err(err)
    }
  }
  for value in values {
    roots.push(value)
  }
  Ok((roots, values, tc_state))
}

///|
fn hot_lift_impl_lift_control(
  func : HotFunc,
  instr : Instruction,
  tc_state : TcState,
  label_frames : HotLiftLabelFrames,
  label_stack_head : Int,
  roots : Array[NodeId],
  values : Array[NodeId],
  concrete_values : Array[ValType],
) -> Result[TcState, HotLiftError] {
  match instr {
    Instruction::Block(block_type, body) => {
      let (params, results) = match
        hot_lift_impl_block_results(tc_state.env, block_type) {
        Ok(types) => types
        Err(err) => return Err(err)
      }
      let entry_state = match tc_state_pop_types(tc_state, params) {
        Ok(next) => next
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let (entry_values, entry_types) = match
        hot_lift_impl_pop_typed_values_for_instr(
          instr,
          values,
          concrete_values,
          params.length(),
          "block entry values",
        ) {
        Ok(entry_values) => entry_values
        Err(err) => return Err(err)
      }
      let ty = hot_lift_impl_intern_control_result_type(
        func, block_type, results,
      )
      let id = hot_build_node(func, HotOp::Block, ty)
      let label_id = hot_label_alloc(
        func,
        HotLabelKind::BlockLabel,
        ty,
        id,
        results.length(),
      )
      let next_stack = hot_lift_impl_push_label(
        label_frames, label_stack_head, label_id,
      )
      let region_env = entry_state.env.with_label(results)
      let region_state = hot_lift_impl_region_state(
        entry_state, region_env, entry_types,
      )
      let (body_roots, _, body_exit_state) = match
        hot_lift_impl_lift_region(
          func,
          body,
          region_state,
          label_frames,
          next_stack,
          initial_values=entry_values,
          initial_value_types=entry_types,
        ) {
        Ok(state) => state
        Err(err) => return Err(err)
      }
      hot_lift_impl_pop_label(label_frames, next_stack)
      let after_state = match
        tc_state_normalize_untyped_block_exit(body_exit_state, results) {
        Ok((true, _)) =>
          tc_state_push_types(
            hot_lift_impl_restore_outer_state(tc_state, entry_state),
            results,
          )
        Ok((false, block_escape)) =>
          tc_state_new(tc_state.env, [], false, block_escape)
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      ignore(hot_replace_child_span(func, id, body_roots))
      hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
      hot_lift_impl_push_node(roots, values, concrete_values, id, results)
      Ok(after_state)
    }
    Instruction::Loop(block_type, body) => {
      let (params, results) = match
        hot_lift_impl_block_results(tc_state.env, block_type) {
        Ok(types) => types
        Err(err) => return Err(err)
      }
      let entry_state = match tc_state_pop_types(tc_state, params) {
        Ok(next) => next
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let (entry_values, entry_types) = match
        hot_lift_impl_pop_typed_values_for_instr(
          instr,
          values,
          concrete_values,
          params.length(),
          "loop entry values",
        ) {
        Ok(entry_values) => entry_values
        Err(err) => return Err(err)
      }
      let ty = hot_lift_impl_intern_control_result_type(
        func, block_type, results,
      )
      let id = hot_build_node(func, HotOp::Loop, ty)
      let label_id = hot_label_alloc(
        func,
        HotLabelKind::LoopLabel,
        ty,
        id,
        params.length(),
      )
      let next_stack = hot_lift_impl_push_label(
        label_frames, label_stack_head, label_id,
      )
      let region_env = entry_state.env.with_label(params)
      let region_state = hot_lift_impl_region_state(
        entry_state, region_env, entry_types,
      )
      let (body_roots, _, body_exit_state) = match
        hot_lift_impl_lift_region(
          func,
          body,
          region_state,
          label_frames,
          next_stack,
          initial_values=entry_values,
          initial_value_types=entry_types,
        ) {
        Ok(state) => state
        Err(err) => return Err(err)
      }
      hot_lift_impl_pop_label(label_frames, next_stack)
      match tc_state_validate_end_stack(body_exit_state, results) {
        Ok(_) => ()
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let after_state = tc_state_push_types(
        hot_lift_impl_restore_outer_state(tc_state, entry_state),
        results,
      )
      let loop_children : Array[NodeId] = []
      for entry_value in entry_values {
        loop_children.push(entry_value)
      }
      for body_root in body_roots {
        loop_children.push(body_root)
      }
      ignore(hot_replace_child_span(func, id, loop_children))
      hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
      hot_lift_impl_push_node(roots, values, concrete_values, id, results)
      Ok(after_state)
    }
    Instruction::If(block_type, then_instrs, else_instrs) => {
      let (params, results) = match
        hot_lift_impl_block_results(tc_state.env, block_type) {
        Ok(types) => types
        Err(err) => return Err(err)
      }
      let st0 = match tc_state_pop_expect(tc_state, ValType::i32()) {
        Ok(next) => next
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let entry_state = match tc_state_pop_types(st0, params) {
        Ok(next) => next
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let condition = match
        hot_lift_impl_pop_value_for_instr(
          instr, values, concrete_values, "if condition",
        ) {
        Ok(condition) => condition
        Err(err) => return Err(err)
      }
      let (entry_values, entry_types) = match
        hot_lift_impl_pop_typed_values_for_instr(
          instr,
          values,
          concrete_values,
          params.length(),
          "if entry values",
        ) {
        Ok(entry_values) => entry_values
        Err(err) => return Err(err)
      }
      let ty = hot_lift_impl_intern_control_result_type(
        func, block_type, results,
      )
      let result_arity = results.length()
      let id = hot_build_node(func, HotOp::If, ty)
      let label_id = hot_label_alloc(
        func,
        HotLabelKind::IfLabel,
        ty,
        id,
        result_arity,
      )
      let next_stack = hot_lift_impl_push_label(
        label_frames, label_stack_head, label_id,
      )
      let region_env = entry_state.env.with_label(results)
      let then_entry_types = hot_lift_impl_copy_val_types(entry_types)
      let then_state = hot_lift_impl_region_state(
        entry_state, region_env, then_entry_types,
      )
      let (then_roots, _, then_exit_state) = match
        hot_lift_impl_lift_region(
          func,
          Expr::new(then_instrs),
          then_state,
          label_frames,
          next_stack,
          initial_values=entry_values,
          initial_value_types=then_entry_types,
        ) {
        Ok(state) => state
        Err(err) => return Err(err)
      }
      let (then_reach, then_escape) = match
        tc_state_normalize_untyped_if_branch_exit(then_exit_state, results) {
        Ok(normalized) => normalized
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let then_region = hot_lift_impl_make_region(
        func, then_roots, result_arity,
      )
      let mut else_reach = false
      let mut else_escape : TcEscape = tc_escape_terminal()
      let else_region = match else_instrs {
        Some(instrs) => {
          let else_state = hot_lift_impl_region_state(
            entry_state, region_env, entry_types,
          )
          match
            hot_lift_impl_lift_region(
              func,
              Expr::new(instrs),
              else_state,
              label_frames,
              next_stack,
              initial_values=entry_values,
              initial_value_types=entry_types,
            ) {
            Ok((else_roots, _, else_exit_state)) => {
              match
                tc_state_normalize_untyped_if_branch_exit(
                  else_exit_state, results,
                ) {
                Ok((reaches_merge, exit_escape)) => {
                  else_reach = reaches_merge
                  else_escape = exit_escape
                }
                Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
              }
              hot_lift_impl_make_region(func, else_roots, result_arity)
            }
            Err(err) => return Err(err)
          }
        }
        None => {
          let else_exit_state = hot_lift_impl_region_state(
            entry_state, region_env, entry_types,
          )
          match
            tc_state_normalize_untyped_if_branch_exit(else_exit_state, results) {
            Ok((reaches_merge, exit_escape)) => {
              else_reach = reaches_merge
              else_escape = exit_escape
            }
            Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
          }
          HOT_NONE_NODE
        }
      }
      hot_lift_impl_pop_label(label_frames, next_stack)
      let after_state = if then_reach || else_reach {
        tc_state_push_types(
          tc_state_new(tc_state.env, entry_state.stack, true, tc_escape_none()),
          results,
        )
      } else {
        tc_state_new(
          tc_state.env,
          [],
          false,
          tc_state_merge_nonfallthrough_if_exits(then_escape, else_escape),
        )
      }
      ignore(
        hot_replace_child_span(func, id, [condition, then_region, else_region]),
      )
      hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
      hot_lift_impl_push_node(roots, values, concrete_values, id, results)
      Ok(after_state)
    }
    Instruction::TryTable(block_type, catches, body) => {
      let (params, results) = match
        hot_lift_impl_block_results(tc_state.env, block_type) {
        Ok(types) => types
        Err(err) => return Err(err)
      }
      let entry_state = match tc_state_pop_types(tc_state, params) {
        Ok(next) => next
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let (entry_values, entry_types) = match
        hot_lift_impl_pop_typed_values_for_instr(
          instr,
          values,
          concrete_values,
          params.length(),
          "try_table entry values",
        ) {
        Ok(entry_values) => entry_values
        Err(err) => return Err(err)
      }
      let ty = hot_lift_impl_intern_control_result_type(
        func, block_type, results,
      )
      let result_arity = results.length()
      let id = hot_build_node(func, HotOp::TryTable, ty)
      let label_id = hot_label_alloc(
        func,
        HotLabelKind::TryTableLabel,
        ty,
        id,
        result_arity,
      )
      let next_stack = hot_lift_impl_push_label(
        label_frames, label_stack_head, label_id,
      )
      let region_env = entry_state.env.with_label(results)
      let body_state = hot_lift_impl_region_state(
        entry_state, region_env, entry_types,
      )
      let (body_roots, _, body_exit_state) = match
        hot_lift_impl_lift_region(
          func,
          body,
          body_state,
          label_frames,
          next_stack,
          initial_values=entry_values,
          initial_value_types=entry_types,
        ) {
        Ok(state) => state
        Err(err) => return Err(err)
      }
      hot_lift_impl_pop_label(label_frames, next_stack)
      for catch_ in catches {
        match tc_state_typecheck_catch_clause(entry_state, catch_) {
          Ok(_) => ()
          Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
        }
      }
      match tc_state_validate_end_stack(body_exit_state, results) {
        Ok(_) => ()
        Err(err) => return Err(hot_lift_impl_invalid_body_state(err))
      }
      let catch_arms : Array[HotCatchArm] = []
      for catch_ in catches {
        match
          hot_lift_impl_try_catch_arm(label_frames, label_stack_head, catch_) {
          Ok(arm) => catch_arms.push(arm)
          Err(err) => return Err(err)
        }
      }
      let after_state = tc_state_push_types(
        tc_state_new(
          tc_state.env,
          entry_state.stack,
          body_exit_state.reachable,
          body_exit_state.escape,
        ),
        results,
      )
      let catch_region = hot_lift_impl_make_region(func, [], result_arity)
      let catch_info_id = hot_alloc_catch_info(
        func,
        HotCatchInfo::new(catch_arms),
      )
      ignore(
        hot_replace_child_span(func, id, [
          hot_lift_impl_make_region(func, body_roots, result_arity),
          catch_region,
        ]),
      )
      hot_node_set(func, id, {
        ..hot_node_get(func, id),
        imm0: label_id,
        imm1: catch_info_id,
      })
      hot_lift_impl_push_node(roots, values, concrete_values, id, results)
      Ok(after_state)
    }
    _ => Err(HotLiftError::UnsupportedInstruction(instr.to_string()))
  }
}

///|
fn hot_lift_impl_lift_instruction(
  func : HotFunc,
  instr : Instruction,
  tc_state : TcState,
  label_frames : HotLiftLabelFrames,
  label_stack_head : Int,
  roots : Array[NodeId],
  values : Array[NodeId],
  concrete_values : Array[ValType],
) -> Result[TcState, HotLiftError] {
  match instr {
    Instruction::Block(_, _)
    | Instruction::Loop(_, _)
    | Instruction::If(_, _, _)
    | Instruction::TryTable(_, _, _) =>
      return hot_lift_impl_lift_control(
        func, instr, tc_state, label_frames, label_stack_head, roots, values, concrete_values,
      )
    Instruction::Br(label_idx) => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let target = match
        hot_lift_impl_resolve_label(label_frames, label_stack_head, label_idx) {
        Ok(label_id) => label_id
        Err(err) => return Err(err)
      }
      let payload_count = hot_label_branch_arity(func, target)
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr, tc_state, concrete_values, payload_count,
        ) {
        return Ok(after_state)
      }
      let payload = match
        hot_lift_impl_pop_values_for_instr(
          instr, values, concrete_values, payload_count, "br payload",
        ) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let node_id = hot_build_node(
        func,
        HotOp::Br,
        hot_type_void(func),
        imm0=target,
        children=payload,
      )
      roots.push(node_id)
      values.clear()
      concrete_values.clear()
      return Ok(after_state)
    }
    Instruction::BrIf(label_idx) => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let target = match
        hot_lift_impl_resolve_label(label_frames, label_stack_head, label_idx) {
        Ok(label_id) => label_id
        Err(err) => return Err(err)
      }
      let payload_count = hot_label_branch_arity(func, target)
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr,
          tc_state,
          concrete_values,
          payload_count + 1,
        ) {
        return Ok(after_state)
      }
      let condition = match
        hot_lift_impl_pop_value_for_instr(
          instr, values, concrete_values, "br_if condition",
        ) {
        Ok(condition) => condition
        Err(err) => return Err(err)
      }
      let children = hot_lift_impl_peek_values_with_extra(
        values, payload_count, condition,
      )
      roots.push(
        hot_build_node(
          func,
          HotOp::BrIf,
          hot_type_void(func),
          imm0=target,
          children~,
        ),
      )
      return Ok(after_state)
    }
    Instruction::BrTable(targets, default_target) => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let default_label = match
        hot_lift_impl_resolve_label(
          label_frames, label_stack_head, default_target,
        ) {
        Ok(label_id) => label_id
        Err(err) => return Err(err)
      }
      let table_targets : Array[LabelId] = []
      for target in targets {
        match
          hot_lift_impl_resolve_label(label_frames, label_stack_head, target) {
          Ok(label_id) => table_targets.push(label_id)
          Err(err) => return Err(err)
        }
      }
      let payload_count = hot_label_branch_arity(func, default_label)
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr,
          tc_state,
          concrete_values,
          payload_count + 1,
        ) {
        return Ok(after_state)
      }
      let selector = match
        hot_lift_impl_pop_value_for_instr(
          instr, values, concrete_values, "br_table selector",
        ) {
        Ok(selector) => selector
        Err(err) => return Err(err)
      }
      let table_id = hot_alloc_branch_table(
        func,
        HotBranchTable::new(table_targets, default_label),
      )
      let children = hot_lift_impl_peek_values_with_extra(
        values, payload_count, selector,
      )
      roots.push(
        hot_build_node(
          func,
          HotOp::BrTable,
          hot_type_void(func),
          imm0=table_id,
          children~,
        ),
      )
      return Ok(after_state)
    }
    Instruction::Return => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let return_types = match tc_state.env.return_type {
        Some(types) => types
        None =>
          return Err(
            HotLiftError::InvalidBodyState(
              "return requires a function return type in the lift context",
            ),
          )
      }
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr,
          tc_state,
          concrete_values,
          return_types.length(),
        ) {
        return Ok(after_state)
      }
      let payload = match
        hot_lift_impl_pop_values_for_instr(
          instr,
          values,
          concrete_values,
          return_types.length(),
          "return payload",
        ) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      roots.push(
        hot_build_node(
          func,
          HotOp::Return,
          hot_type_void(func),
          children=payload,
        ),
      )
      values.clear()
      concrete_values.clear()
      return Ok(after_state)
    }
    Instruction::Throw(tag_idx) => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let payload_types = match tc_state.env.resolve_tag_functype(tag_idx) {
        Some(@lib.FuncType(params, _)) => params
        None =>
          return Err(
            HotLiftError::InvalidBodyState(
              "throw requires a resolved tag function type",
            ),
          )
      }
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr,
          tc_state,
          concrete_values,
          payload_types.length(),
        ) {
        return Ok(after_state)
      }
      let payload = match
        hot_lift_impl_pop_values_for_instr(
          instr,
          values,
          concrete_values,
          payload_types.length(),
          "throw payload",
        ) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let @lib.TagIdx(raw) = tag_idx
      roots.push(
        hot_build_node(
          func,
          HotOp::Throw,
          hot_type_void(func),
          imm0=raw.reinterpret_as_int(),
          children=payload,
        ),
      )
      values.clear()
      concrete_values.clear()
      return Ok(after_state)
    }
    Instruction::ThrowRef => {
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr, tc_state, concrete_values, 1,
        ) {
        return Ok(after_state)
      }
      let exnref = match
        hot_lift_impl_pop_value_for_instr(
          instr, values, concrete_values, "throw_ref payload",
        ) {
        Ok(exnref) => exnref
        Err(err) => return Err(err)
      }
      roots.push(
        hot_build_node1(func, HotOp::ThrowRef, hot_type_void(func), exnref),
      )
      values.clear()
      concrete_values.clear()
      return Ok(after_state)
    }
    Instruction::BrOnNull(label_idx) => {
      let before_types = tc_state.stack
      let after_state = match hot_lift_impl_typecheck(instr, tc_state) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
      let target = match
        hot_lift_impl_resolve_label(label_frames, label_stack_head, label_idx) {
        Ok(label_id) => label_id
        Err(err) => return Err(err)
      }
      let payload_count = hot_label_branch_arity(func, target)
      if !hot_lift_impl_can_materialize_unreachable_instr(
          instr,
          tc_state,
          concrete_values,
          payload_count + 1,
        ) {
        return Ok(after_state)
      }
      let guard_id = match
        hot_lift_impl_pop_value_for_instr(
          instr, values, concrete_values, "br_on_null guard",
        ) {
        Ok(guard_id) => guard_id
        Err(err) => return Err(err)
      }
      let children = hot_lift_impl_peek_values_with_extra(
        values, payload_count, guard_id,
      )
      let pushed_types = hot_lift_impl_pushed_types(
        before_types,
        after_state.stack,
        payload_count + 1,
      )
      let node_id = hot_build_node(
        func,
        HotOp::BrOnNull,
        hot_lift_impl_result_type(func, pushed_types),
        imm0=target,
        children~,
      )
      hot_lift_impl_push_node(
        roots, values, concrete_values, node_id, pushed_types,
      )
      return Ok(after_state)
    }
    _ => ()
  }

  let before_types = tc_state.stack
  let before_state = tc_state
  let typecheck_state = tc_state_with_stack(tc_state, before_types)
  let after_state = match hot_lift_impl_typecheck(instr, typecheck_state) {
    Ok(next) => next
    Err(err) => return Err(err)
  }
  let concrete_before_types = concrete_values
  let (child_count, pushed_types) = match
    hot_lift_impl_known_pop_count(instr, tc_state.env) {
    Some(count) if count <= before_types.length() =>
      (
        count,
        hot_lift_impl_pushed_types(before_types, after_state.stack, count),
      )
    _ =>
      match
        hot_lift_impl_resolve_generic_pop_count(
          instr, before_state, after_state, concrete_before_types,
        ) {
        Ok(resolved) => resolved
        Err(err) => return Err(err)
      }
  }
  if !hot_lift_impl_can_materialize_unreachable_instr(
      instr, tc_state, concrete_values, child_count,
    ) {
    return Ok(after_state)
  }
  match hot_lift_impl_direct_family(instr) {
    Some(op) => {
      let node_id = match child_count {
        0 => {
          let (build_op, ty, imm0, imm1) = hot_lift_impl_direct_node_shape(
            func, op, instr, pushed_types,
          )
          hot_build_node(func, build_op, ty, imm0~, imm1~)
        }
        1 => {
          let child0 = hot_lift_impl_pop_value(values, concrete_values)
          hot_lift_impl_build_direct_node1(
            func, op, instr, pushed_types, child0,
          )
        }
        2 => {
          let child1 = hot_lift_impl_pop_value(values, concrete_values)
          let child0 = hot_lift_impl_pop_value(values, concrete_values)
          hot_lift_impl_build_direct_node2(
            func, op, instr, pushed_types, child0, child1,
          )
        }
        3 => {
          let child2 = hot_lift_impl_pop_value(values, concrete_values)
          let child1 = hot_lift_impl_pop_value(values, concrete_values)
          let child0 = hot_lift_impl_pop_value(values, concrete_values)
          hot_lift_impl_build_direct_node3(
            func, op, instr, pushed_types, child0, child1, child2,
          )
        }
        _ => {
          let children = match
            hot_lift_impl_pop_values_for_instr(
              instr, values, concrete_values, child_count, "generic operands",
            ) {
            Ok(children) => children
            Err(err) => return Err(err)
          }
          hot_lift_impl_build_direct_node(
            func, op, instr, pushed_types, children,
          )
        }
      }
      hot_lift_impl_push_node(
        roots, values, concrete_values, node_id, pushed_types,
      )
      Ok(after_state)
    }
    None =>
      match hot_lift_impl_exact_family(instr) {
        Some(op) => {
          let node_id = match child_count {
            0 => {
              let (build_op, ty, imm0, imm1) = hot_lift_impl_exact_node_shape(
                func, op, instr, pushed_types,
              )
              hot_build_node(func, build_op, ty, imm0~, imm1~)
            }
            1 => {
              let child0 = hot_lift_impl_pop_value(values, concrete_values)
              hot_lift_impl_build_exact_node1(
                func, op, instr, pushed_types, child0,
              )
            }
            2 => {
              let child1 = hot_lift_impl_pop_value(values, concrete_values)
              let child0 = hot_lift_impl_pop_value(values, concrete_values)
              hot_lift_impl_build_exact_node2(
                func, op, instr, pushed_types, child0, child1,
              )
            }
            3 => {
              let child2 = hot_lift_impl_pop_value(values, concrete_values)
              let child1 = hot_lift_impl_pop_value(values, concrete_values)
              let child0 = hot_lift_impl_pop_value(values, concrete_values)
              hot_lift_impl_build_exact_node3(
                func, op, instr, pushed_types, child0, child1, child2,
              )
            }
            _ => {
              let children = match
                hot_lift_impl_pop_values_for_instr(
                  instr, values, concrete_values, child_count, "generic operands",
                ) {
                Ok(children) => children
                Err(err) => return Err(err)
              }
              hot_lift_impl_build_exact_node(
                func, op, instr, pushed_types, children,
              )
            }
          }
          hot_lift_impl_push_node(
            roots, values, concrete_values, node_id, pushed_types,
          )
          Ok(after_state)
        }
        None => Err(HotLiftError::UnsupportedInstruction(instr.to_string()))
      }
  }
}

///|
fn hot_lift_impl_finish(
  func : HotFunc,
  roots : Array[NodeId],
  verify? : Bool = true,
) -> HotFunc {
  for root in roots {
    hot_root_append(func, root)
  }
  if verify {
    hot_verify_all_or_abort(func)
  }
  func
}

///|
pub fn hot_lift_body_result(
  body : Expr,
  locals : HotLocals,
  body_result_type? : BlockType = BlockType::void_(),
) -> Result[HotFunc, HotLiftError] {
  let env = hot_lift_impl_env_without_context(
    locals,
    match hot_lift_impl_block_results(empty_env(), body_result_type) {
      Ok((_, results)) => results
      Err(err) => return Err(err)
    },
  )
  let func = HotFunc::new(locals~)
  hot_body_result_type_set(
    func,
    hot_type_intern_block_result(func, body_result_type),
  )
  let state = make_state(env, [])
  let label_frames = hot_lift_impl_new_label_frames()
  match hot_lift_impl_lift_region(func, body, state, label_frames, -1) {
    Ok((roots, _, _)) => Ok(hot_lift_impl_finish(func, roots))
    Err(err) => Err(err)
  }
}

///|
pub fn hot_lift_body_with_context(
  body : Expr,
  locals : HotLocals,
  ctx : HotModuleContext,
  body_result_type? : BlockType = BlockType::void_(),
) -> HotFunc {
  let func = hot_lift_body_with_context_unverified(
    body,
    locals,
    ctx,
    body_result_type~,
  )
  hot_verify_all_or_abort(func)
  func
}

///|
pub fn hot_lift_body_with_context_unverified(
  body : Expr,
  locals : HotLocals,
  ctx : HotModuleContext,
  body_result_type? : BlockType = BlockType::void_(),
) -> HotFunc {
  let return_env = hot_lift_impl_env_from_context(ctx, locals, [])
  let (_, return_types) = match
    hot_lift_impl_block_results(return_env, body_result_type) {
    Ok(types) => types
    Err(err) => abort(err.to_string())
  }
  let env = hot_lift_impl_env_from_context(ctx, locals, return_types)
  let func = HotFunc::new(locals~)
  hot_body_result_type_set(
    func,
    hot_lift_impl_intern_control_result_type(
      func, body_result_type, return_types,
    ),
  )
  let label_frames = hot_lift_impl_new_label_frames()
  match
    hot_lift_impl_lift_region(func, body, make_state(env, []), label_frames, -1) {
    Ok((roots, _, _)) => hot_lift_impl_finish(func, roots, verify=false)
    Err(err) => abort(err.to_string())
  }
}

///|
fn hot_lift_impl_imported_func_count(mod_ : Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count = count + 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
pub fn hot_lift_func_with_context(
  mod_ : Module,
  func_idx : FuncIdx,
  ctx : HotModuleContext,
) -> HotFunc {
  let func = hot_lift_func_with_context_unverified(mod_, func_idx, ctx)
  hot_verify_all_or_abort(func)
  func
}

///|
pub fn hot_lift_func_with_context_unverified(
  mod_ : Module,
  func_idx : FuncIdx,
  ctx : HotModuleContext,
) -> HotFunc {
  let func_type = match hot_module_resolve_func_type(ctx, func_idx) {
    Some(type_) => type_
    None => abort(HotLiftError::MissingFunctionType(func_idx).to_string())
  }
  let code_idx = match func_idx {
    FuncIdx(raw) =>
      raw.reinterpret_as_int() - hot_lift_impl_imported_func_count(mod_)
  }
  if code_idx < 0 {
    abort(HotLiftError::MissingFunctionBody(func_idx).to_string())
  }
  let def = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) =>
      match defs.get(code_idx) {
        Some(def_) => def_
        None => abort(HotLiftError::MissingFunctionBody(func_idx).to_string())
      }
    None => abort(HotLiftError::MissingFunctionBody(func_idx).to_string())
  }
  let @lib.Func(body_locals, body) = def
  let @lib.FuncType(params, results) = func_type
  let locals = HotLocals::new(
    params~,
    locals=hot_lift_impl_declared_locals(body_locals),
  )
  let body_result_type = match hot_module_resolve_func_type_idx(ctx, func_idx) {
    Some(type_idx) => BlockType::type_idx(type_idx)
    None =>
      match results {
        [] => BlockType::void_()
        [result] => BlockType::val_type(result)
        _ => abort(HotLiftError::MissingFunctionType(func_idx).to_string())
      }
  }
  hot_lift_body_with_context_unverified(body, locals, ctx, body_result_type~)
}

///|
pub fn hot_lift_func(mod_ : Module, func_idx : FuncIdx) -> HotFunc {
  hot_lift_func_with_context(
    mod_,
    func_idx,
    hot_module_context_from_module(mod_),
  )
}
