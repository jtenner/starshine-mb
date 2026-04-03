///|
pub fn heap2local_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "heap2local",
    requires=[@ir.HotAnalysis::use_def()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn heap2local_summary() -> String {
  "Replace non-escaping struct locals with scalar field locals when every use stays exact field traffic."
}

///|
priv struct H2LUseSite {
  read_node_id : Int
  user_node_id : Int
} derive(Eq, Show, Debug)

///|
priv struct H2LCandidate {
  owner_local : Int
  write_node_id : Int
  init_node_id : Int
  struct_type : @lib.TypeIdx
  fields : Array[@lib.FieldType]
  use_sites : Array[H2LUseSite]
} derive(Eq, Show, Debug)

///|
fn h2l_build_default_value(func : @ir.HotFunc, vt : @lib.ValType) -> Int? {
  match vt {
    @lib.NumTypeValType(@lib.I32NumType) =>
      Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
    @lib.NumTypeValType(@lib.I64NumType) =>
      Some(@ir.hot_build_const_i64(func, @lib.I64(0L)))
    @lib.NumTypeValType(@lib.F32NumType) =>
      Some(@ir.hot_build_const_f32(func, @lib.F32(0.0)))
    @lib.NumTypeValType(@lib.F64NumType) =>
      Some(@ir.hot_build_const_f64(func, @lib.F64(0.0)))
    @lib.VecTypeValType => Some(@ir.hot_build_const_v128_zero(func))
    @lib.RefTypeValType(ref_type) =>
      if ref_type.is_nullable() {
        Some(@ir.hot_build_ref_null(func, ref_type))
      } else {
        None
      }
    @lib.BotValType => None
  }
}

///|
fn h2l_supported_struct_new_fields(
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
  node_id : Int,
) -> (@lib.TypeIdx, Array[@lib.FieldType], Bool)? {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructNew(type_idx)) =>
      match @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
        Some(fields) =>
          if fields.length() == @ir.hot_child_count(func, node_id) {
            Some((type_idx, fields, false))
          } else {
            None
          }
        None => None
      }
    Some(@lib.Instruction::StructNewDefault(type_idx)) =>
      match @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
        Some(fields) => {
          for field in fields {
            let defaultable = match
              h2l_build_default_value(func, field.unpack()) {
              Some(_) => true
              None => false
            }
            if !defaultable {
              return None
            }
          }
          Some((type_idx, fields, true))
        }
        None => None
      }
    _ => None
  }
}

///|
fn h2l_field_index(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.StructGet(_, field_idx)
    | @lib.StructGetS(_, field_idx)
    | @lib.StructGetU(_, field_idx)
    | @lib.StructSet(_, field_idx) => {
      let @lib.U32(raw_field_idx) = field_idx
      Some(raw_field_idx.reinterpret_as_int())
    }
    _ => None
  }
}

///|
fn h2l_exact_field_user_matches(
  func : @ir.HotFunc,
  user_node_id : Int,
  struct_type : @lib.TypeIdx,
  field_count : Int,
) -> Bool {
  let instr = match @ir.hot_node_exact_instr(func, user_node_id) {
    Some(instr) => instr
    None => return false
  }
  let user_type = match instr {
    @lib.StructGet(type_idx, _)
    | @lib.StructGetS(type_idx, _)
    | @lib.StructGetU(type_idx, _)
    | @lib.StructSet(type_idx, _) => type_idx
    _ => return false
  }
  if user_type != struct_type {
    return false
  }
  match h2l_field_index(instr) {
    Some(field_idx) => field_idx >= 0 && field_idx < field_count
    None => false
  }
}

///|
fn h2l_find_candidate_for_local(
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
  use_def : @ir.HotUseDef,
  local_id : Int,
) -> H2LCandidate? {
  let writes = use_def.local_writes[local_id]
  if writes.length() != 1 {
    return None
  }
  let write_node_id = writes[0]
  if !@ir.hot_node_is_live(func, write_node_id) {
    return None
  }
  let write_node = @ir.hot_node_get(func, write_node_id)
  match write_node.op {
    @ir.HotOp::LocalSet =>
      if write_node.imm0 != local_id || write_node.child_count != 1 {
        return None
      }
    _ => return None
  }
  let init_node_id = @ir.hot_child_get(func, write_node_id, 0)
  let (struct_type, fields, uses_default) = match
    h2l_supported_struct_new_fields(func, module_ctx, init_node_id) {
    Some(info) => info
    None => return None
  }
  ignore(uses_default)
  let reads = use_def.local_reads[local_id]
  if reads.is_empty() {
    return None
  }
  let use_sites : Array[H2LUseSite] = []
  for read_node_id in reads {
    if !@ir.hot_node_is_live(func, read_node_id) {
      return None
    }
    let sites = use_def.node_uses[read_node_id]
    if sites.length() != 1 {
      return None
    }
    let site = sites[0]
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot => if site.slot != 0 { return None }
      _ => return None
    }
    if !h2l_exact_field_user_matches(
        func,
        site.user,
        struct_type,
        fields.length(),
      ) {
      return None
    }
    use_sites.push({ read_node_id, user_node_id: site.user })
  }
  Some({
    owner_local: local_id,
    write_node_id,
    init_node_id,
    struct_type,
    fields,
    use_sites,
  })
}

///|
fn h2l_alloc_field_locals(
  func : @ir.HotFunc,
  fields : Array[@lib.FieldType],
) -> Array[Int] {
  let field_locals : Array[Int] = []
  for field in fields {
    let local_id = @ir.hot_local_count(func)
    func.locals.locals.push(field.unpack())
    field_locals.push(local_id)
  }
  field_locals
}

///|
fn h2l_build_init_replacement(
  func : @ir.HotFunc,
  candidate : H2LCandidate,
  field_locals : Array[Int],
) -> Int? {
  let init_roots : Array[Int] = []
  match @ir.hot_node_exact_instr(func, candidate.init_node_id) {
    Some(@lib.Instruction::StructNew(_)) =>
      for idx = 0; idx < candidate.fields.length(); idx = idx + 1 {
        init_roots.push(
          @ir.hot_build_local_set(
            func,
            field_locals[idx],
            @ir.hot_child_get(func, candidate.init_node_id, idx),
          ),
        )
      }
    Some(@lib.Instruction::StructNewDefault(_)) =>
      for idx = 0; idx < candidate.fields.length(); idx = idx + 1 {
        let init_value = match
          h2l_build_default_value(func, candidate.fields[idx].unpack()) {
          Some(node_id) => node_id
          None => return None
        }
        init_roots.push(
          @ir.hot_build_local_set(func, field_locals[idx], init_value),
        )
      }
    _ => return None
  }
  Some(
    if init_roots.length() == 1 {
      init_roots[0]
    } else {
      @ir.hot_build_block(func, @lib.BlockType::void_(), init_roots)
    },
  )
}

///|
fn h2l_apply_candidate(
  func : @ir.HotFunc,
  candidate : H2LCandidate,
  detached_nodes : Array[Int],
) -> Bool {
  let field_locals = h2l_alloc_field_locals(func, candidate.fields)
  let init_replacement = match
    h2l_build_init_replacement(func, candidate, field_locals) {
    Some(node_id) => node_id
    None => return false
  }
  @ir.hot_replace_node(
    func,
    candidate.write_node_id,
    @ir.hot_node_get(func, init_replacement),
  )
  detached_nodes.push(candidate.init_node_id)
  for use_site in candidate.use_sites {
    let replacement = match
      @ir.hot_node_exact_instr(func, use_site.user_node_id) {
      Some(instr) =>
        match h2l_field_index(instr) {
          Some(field_idx) =>
            match instr {
              @lib.StructGet(_, _)
              | @lib.StructGetS(_, _)
              | @lib.StructGetU(_, _) =>
                Some(@ir.hot_build_local_get(func, field_locals[field_idx]))
              @lib.StructSet(_, _) =>
                Some(
                  @ir.hot_build_local_set(
                    func,
                    field_locals[field_idx],
                    @ir.hot_child_get(func, use_site.user_node_id, 1),
                  ),
                )
              _ => None
            }
          None => None
        }
      None => None
    }
    match replacement {
      Some(replacement_id) => {
        @ir.hot_replace_node(
          func,
          use_site.user_node_id,
          @ir.hot_node_get(func, replacement_id),
        )
        detached_nodes.push(use_site.read_node_id)
      }
      None => return false
    }
  }
  true
}

///|
fn h2l_delete_detached_live_nodes(
  func : @ir.HotFunc,
  detached_nodes : Array[Int],
) -> Unit {
  let seen : Array[Int] = []
  for node_id in detached_nodes {
    if seen.contains(node_id) {
      continue
    }
    seen.push(node_id)
    if @ir.hot_node_is_live(func, node_id) {
      @ir.hot_delete_node(func, node_id)
    }
  }
}

///|
pub fn heap2local_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return HotPassResult::unchanged()
  }
  let use_def = pass_require_use_def(ctx, func)
  let candidates : Array[H2LCandidate] = []
  for local_id = 0
      local_id < @ir.hot_local_count(func)
      local_id = local_id + 1 {
    match h2l_find_candidate_for_local(func, module_ctx, use_def, local_id) {
      Some(candidate) => candidates.push(candidate)
      None => ()
    }
  }
  if candidates.is_empty() {
    return HotPassResult::unchanged()
  }
  let detached_nodes : Array[Int] = []
  let mut changed = false
  for candidate in candidates {
    if h2l_apply_candidate(func, candidate, detached_nodes) {
      changed = true
    }
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  h2l_delete_detached_live_nodes(func, detached_nodes)
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
