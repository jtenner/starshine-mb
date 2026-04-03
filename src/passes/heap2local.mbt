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
  source_node_id : Int
  user_node_id : Int
} derive(Eq, Show, Debug)

///|
priv struct H2LCopySite {
  source_node_id : Int
  write_node_id : Int
  target_local : Int
} derive(Eq, Show, Debug)

///|
priv struct H2LCandidate {
  owner_local : Int
  write_node_id : Int
  init_node_id : Int
  struct_type : @lib.TypeIdx
  fields : Array[@lib.FieldType]
  use_sites : Array[H2LUseSite]
  copy_sites : Array[H2LCopySite]
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
fn h2l_local_can_hold_struct_ref(
  func : @ir.HotFunc,
  local_id : Int,
  struct_type : @lib.TypeIdx,
) -> Bool {
  match @ir.hot_local_type(func, local_id) {
    Some(@lib.RefTypeValType(ref_type)) =>
      ref_type.is_nullable() &&
      ref_type.get_heap_type() == @lib.HeapType::new(struct_type)
    _ => false
  }
}

///|
fn h2l_collect_source_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  source_node_id : Int,
  current_local : Int,
  struct_type : @lib.TypeIdx,
  field_count : Int,
  family_locals : Array[Int],
  use_sites : Array[H2LUseSite],
  copy_sites : Array[H2LCopySite],
  allow_copy : Bool,
) -> Bool {
  if !@ir.hot_node_is_live(func, source_node_id) {
    return false
  }
  let sites = use_def.node_uses[source_node_id]
  if sites.length() != 1 {
    return false
  }
  let site = sites[0]
  let (flowed_source_node_id, flowed_user_node_id) = match site.kind {
    @ir.HotUseSlotKind::ChildUseSlot =>
      if site.slot != 0 {
        return false
      } else {
        (source_node_id, site.user)
      }
    @ir.HotUseSlotKind::RootUseSlot => {
      if site.user < 0 {
        return false
      }
      let block_node_id = site.user
      let block_node = @ir.hot_node_get(func, block_node_id)
      match block_node.op {
        @ir.HotOp::Block => ()
        _ => return false
      }
      let body_ref = @ir.hot_region_body_ref(func, block_node_id)
      let root_count = @ir.hot_region_root_count(func, body_ref)
      if root_count == 0 || site.slot != root_count - 1 {
        return false
      }
      for root_idx = 0; root_idx < root_count - 1; root_idx = root_idx + 1 {
        let root_node = @ir.hot_node_get(
          func,
          @ir.hot_region_get(func, body_ref, root_idx),
        )
        match root_node.op {
          @ir.HotOp::Block
          | @ir.HotOp::Loop
          | @ir.HotOp::If
          | @ir.HotOp::Try
          | @ir.HotOp::TryTable
          | @ir.HotOp::Br
          | @ir.HotOp::BrIf
          | @ir.HotOp::BrTable
          | @ir.HotOp::BrOnNull
          | @ir.HotOp::BrOnNonNull
          | @ir.HotOp::BrOnCast
          | @ir.HotOp::BrOnCastFail
          | @ir.HotOp::Return
          | @ir.HotOp::Throw
          | @ir.HotOp::Rethrow
          | @ir.HotOp::ThrowRef
          | @ir.HotOp::Delegate
          | @ir.HotOp::Catch
          | @ir.HotOp::CatchAll => return false
          _ => ()
        }
      }
      let block_sites = use_def.node_uses[block_node_id]
      if block_sites.length() != 1 {
        return false
      }
      let block_site = block_sites[0]
      match block_site.kind {
        @ir.HotUseSlotKind::ChildUseSlot =>
          if block_site.slot != 0 {
            return false
          }
        _ => return false
      }
      (block_node_id, block_site.user)
    }
  }
  if h2l_exact_field_user_matches(
      func, flowed_user_node_id, struct_type, field_count,
    ) {
    use_sites.push({
      source_node_id: flowed_source_node_id,
      user_node_id: flowed_user_node_id,
    })
    return true
  }
  if flowed_source_node_id != source_node_id {
    return false
  }
  match @ir.hot_node_exact_instr(func, site.user) {
    Some(@lib.Instruction::RefAsNonNull) => {
      let flow_sites = use_def.node_uses[site.user]
      if flow_sites.length() != 1 {
        return false
      }
      let flow_site = flow_sites[0]
      match flow_site.kind {
        @ir.HotUseSlotKind::ChildUseSlot =>
          if flow_site.slot != 0 {
            return false
          }
        _ => return false
      }
      if h2l_exact_field_user_matches(
          func,
          flow_site.user,
          struct_type,
          field_count,
        ) {
        use_sites.push({
          source_node_id: site.user,
          user_node_id: flow_site.user,
        })
        return true
      }
      return false
    }
    _ => ()
  }
  if !allow_copy {
    return false
  }
  let user_node = @ir.hot_node_get(func, site.user)
  match user_node.op {
    @ir.HotOp::LocalSet =>
      if user_node.child_count != 1 || user_node.imm0 == current_local {
        false
      } else {
        let target_local = user_node.imm0
        if target_local < @ir.hot_param_count(func) {
          return false
        }
        if !h2l_local_can_hold_struct_ref(func, target_local, struct_type) {
          return false
        }
        let writes = use_def.local_writes[target_local]
        if writes.length() != 1 || writes[0] != site.user {
          return false
        }
        copy_sites.push({
          source_node_id,
          write_node_id: site.user,
          target_local,
        })
        if !family_locals.contains(target_local) {
          family_locals.push(target_local)
        }
        true
      }
    _ => false
  }
}

///|
fn h2l_find_candidate_for_local(
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
  use_def : @ir.HotUseDef,
  local_id : Int,
) -> H2LCandidate? {
  if local_id < @ir.hot_param_count(func) {
    return None
  }
  let writes = use_def.local_writes[local_id]
  if writes.length() != 1 {
    return None
  }
  let write_node_id = writes[0]
  if !@ir.hot_node_is_live(func, write_node_id) {
    return None
  }
  let write_node = @ir.hot_node_get(func, write_node_id)
  let write_is_tee = match write_node.op {
    @ir.HotOp::LocalSet =>
      if write_node.imm0 != local_id || write_node.child_count != 1 {
        return None
      } else {
        false
      }
    @ir.HotOp::LocalTee =>
      if write_node.imm0 != local_id || write_node.child_count != 1 {
        return None
      } else {
        true
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
  if !h2l_local_can_hold_struct_ref(func, local_id, struct_type) {
    return None
  }
  let use_sites : Array[H2LUseSite] = []
  let copy_sites : Array[H2LCopySite] = []
  let family_locals : Array[Int] = [local_id]
  if write_is_tee &&
    !h2l_collect_source_use(
      func,
      use_def,
      write_node_id,
      local_id,
      struct_type,
      fields.length(),
      family_locals,
      use_sites,
      copy_sites,
      false,
    ) {
    return None
  }
  for family_idx = 0
      family_idx < family_locals.length()
      family_idx = family_idx + 1 {
    let current_local = family_locals[family_idx]
    let reads = use_def.local_reads[current_local]
    for read_node_id in reads {
      if !h2l_collect_source_use(
          func,
          use_def,
          read_node_id,
          current_local,
          struct_type,
          fields.length(),
          family_locals,
          use_sites,
          copy_sites,
          true,
        ) {
        return None
      }
    }
  }
  if use_sites.is_empty() {
    return None
  }
  Some({
    owner_local: local_id,
    write_node_id,
    init_node_id,
    struct_type,
    fields,
    use_sites,
    copy_sites,
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
fn h2l_wrap_replacement_with_init(
  func : @ir.HotFunc,
  candidate : H2LCandidate,
  init_replacement : Int,
  field_idx : Int,
  replacement_id : Int,
) -> Int {
  let block_type = match @ir.hot_node_result_arity(func, replacement_id) {
    0 => @lib.BlockType::void_()
    _ => @lib.BlockType::val_type(candidate.fields[field_idx].unpack())
  }
  @ir.hot_build_block(func, block_type, [init_replacement, replacement_id])
}

///|
fn h2l_passthrough_child_node(func : @ir.HotFunc, source_node_id : Int) -> Int? {
  match @ir.hot_node_exact_instr(func, source_node_id) {
    Some(@lib.Instruction::RefAsNonNull) =>
      if @ir.hot_child_count(func, source_node_id) == 1 {
        Some(@ir.hot_child_get(func, source_node_id, 0))
      } else {
        None
      }
    _ => None
  }
}

///|
fn h2l_node_is_block(func : @ir.HotFunc, node_id : Int) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => true
    _ => false
  }
}

///|
fn h2l_block_flow_tail_node(func : @ir.HotFunc, block_node_id : Int) -> Int? {
  let block_node = @ir.hot_node_get(func, block_node_id)
  match block_node.op {
    @ir.HotOp::Block => ()
    _ => return None
  }
  let body_ref = @ir.hot_region_body_ref(func, block_node_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count == 0 {
    None
  } else {
    Some(@ir.hot_region_get(func, body_ref, root_count - 1))
  }
}

///|
fn h2l_wrap_replacement_with_block_prefix(
  func : @ir.HotFunc,
  candidate : H2LCandidate,
  block_node_id : Int,
  field_idx : Int,
  replacement_id : Int,
) -> Int? {
  let tail_node_id = match h2l_block_flow_tail_node(func, block_node_id) {
    Some(node_id) => node_id
    None => return None
  }
  if tail_node_id == block_node_id {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, block_node_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  let roots : Array[Int] = []
  for root_idx = 0; root_idx < root_count - 1; root_idx = root_idx + 1 {
    roots.push(@ir.hot_region_get(func, body_ref, root_idx))
  }
  roots.push(replacement_id)
  let block_type = match @ir.hot_node_result_arity(func, replacement_id) {
    0 => @lib.BlockType::void_()
    _ => @lib.BlockType::val_type(candidate.fields[field_idx].unpack())
  }
  Some(@ir.hot_build_block(func, block_type, roots))
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
  let write_is_tee = match @ir.hot_node_get(func, candidate.write_node_id).op {
    @ir.HotOp::LocalTee => true
    _ => false
  }
  if !write_is_tee {
    @ir.hot_replace_node(
      func,
      candidate.write_node_id,
      @ir.hot_node_get(func, init_replacement),
    )
    detached_nodes.push(candidate.init_node_id)
  }
  for copy_site in candidate.copy_sites {
    @ir.hot_replace_node(
      func,
      copy_site.write_node_id,
      @ir.hot_node_get(func, @ir.hot_build_nop(func)),
    )
    detached_nodes.push(copy_site.source_node_id)
  }
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
                Some(
                  {
                    let local_get = @ir.hot_build_local_get(
                      func,
                      field_locals[field_idx],
                    )
                    if write_is_tee &&
                      use_site.source_node_id == candidate.write_node_id {
                      h2l_wrap_replacement_with_init(
                        func, candidate, init_replacement, field_idx, local_get,
                      )
                    } else if h2l_node_is_block(func, use_site.source_node_id) {
                      match
                        h2l_wrap_replacement_with_block_prefix(
                          func,
                          candidate,
                          use_site.source_node_id,
                          field_idx,
                          local_get,
                        ) {
                        Some(node_id) => node_id
                        None => return false
                      }
                    } else {
                      local_get
                    }
                  },
                )
              @lib.StructSet(_, _) =>
                Some(
                  {
                    let local_set = @ir.hot_build_local_set(
                      func,
                      field_locals[field_idx],
                      @ir.hot_child_get(func, use_site.user_node_id, 1),
                    )
                    if write_is_tee &&
                      use_site.source_node_id == candidate.write_node_id {
                      h2l_wrap_replacement_with_init(
                        func, candidate, init_replacement, field_idx, local_set,
                      )
                    } else if h2l_node_is_block(func, use_site.source_node_id) {
                      match
                        h2l_wrap_replacement_with_block_prefix(
                          func,
                          candidate,
                          use_site.source_node_id,
                          field_idx,
                          local_set,
                        ) {
                        Some(node_id) => node_id
                        None => return false
                      }
                    } else {
                      local_set
                    }
                  },
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
        detached_nodes.push(use_site.source_node_id)
        match h2l_passthrough_child_node(func, use_site.source_node_id) {
          Some(child_node_id) => detached_nodes.push(child_node_id)
          None => ()
        }
        if h2l_node_is_block(func, use_site.source_node_id) {
          match h2l_block_flow_tail_node(func, use_site.source_node_id) {
            Some(tail_node_id) => detached_nodes.push(tail_node_id)
            None => return false
          }
        }
      }
      None => return false
    }
  }
  if write_is_tee {
    detached_nodes.push(candidate.write_node_id)
    detached_nodes.push(candidate.init_node_id)
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
