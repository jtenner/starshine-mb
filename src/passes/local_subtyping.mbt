///|
pub fn local_subtyping_summary() -> String {
  "Narrow reference-typed body locals to the most specific safe supertype of their writes."
}

///|
fn ls_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn ls_abs_heap_is_subtype(
  source : @lib.AbsHeapType,
  target : @lib.AbsHeapType,
) -> Bool {
  if source == target {
    return true
  }
  match (source, target) {
    (@lib.NoneAbsHeapType, @lib.StructAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.ArrayAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.NoneAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.NoFuncAbsHeapType, @lib.FuncAbsHeapType)
    | (@lib.NoFuncAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.NoExternAbsHeapType, @lib.ExternAbsHeapType)
    | (@lib.NoExnAbsHeapType, @lib.ExnAbsHeapType)
    | (@lib.I31AbsHeapType, @lib.EqAbsHeapType)
    | (@lib.I31AbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.StructAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.StructAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.ArrayAbsHeapType, @lib.EqAbsHeapType)
    | (@lib.ArrayAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.EqAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.FuncAbsHeapType, @lib.AnyAbsHeapType)
    | (@lib.ExternAbsHeapType, @lib.AnyAbsHeapType) => true
    _ => false
  }
}

///|
fn ls_comptype_matches_abs(ct : @lib.CompType, abs : @lib.AbsHeapType) -> Bool {
  match ct {
    @lib.StructCompType(_) =>
      abs == @lib.AbsHeapType::struct_() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.ArrayCompType(_) =>
      abs == @lib.AbsHeapType::array() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.FuncCompType(_, _) =>
      abs == @lib.AbsHeapType::func() || abs == @lib.AbsHeapType::any()
  }
}

///|
fn ls_subtype_as_heap_is_subtype(
  module_ctx : @ir.HotModuleContext,
  subtype : @lib.SubType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  let (is_final, supers, ct) = match subtype {
    @lib.CompTypeSubType(_, ct) => (false, [], ct)
    @lib.SubType(is_final, supers, _, ct) => (is_final, supers, ct)
  }
  match target {
    @lib.AbsHeapTypeHeapType(abs) => {
      if ls_comptype_matches_abs(ct, abs) {
        return true
      }
      if is_final {
        return false
      }
    }
    _ => ()
  }
  for super_idx in supers {
    if ls_heap_is_subtype(
        module_ctx,
        @lib.HeapType::new(super_idx),
        target,
        fuel - 1,
      ) {
      return true
    }
  }
  false
}

///|
fn ls_heap_is_subtype(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if source == target {
    return true
  }
  if fuel <= 0 {
    return false
  }
  match (source, target) {
    (@lib.AbsHeapTypeHeapType(source_abs), @lib.AbsHeapTypeHeapType(target_abs)) =>
      ls_abs_heap_is_subtype(source_abs, target_abs)
    (@lib.HeapType(source_idx), _) =>
      match @ir.hot_module_resolve_subtype(module_ctx, source_idx) {
        Some(subtype) =>
          ls_subtype_as_heap_is_subtype(module_ctx, subtype, target, fuel - 1)
        None => false
      }
    (_, @lib.HeapType(target_idx)) =>
      match source {
        @lib.AbsHeapTypeHeapType(@lib.NoneAbsHeapType) =>
          match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.StructCompType(_) | @lib.ArrayCompType(_) => true
                _ => false
              }
            None => false
          }
        @lib.AbsHeapTypeHeapType(@lib.NoFuncAbsHeapType) =>
          match @ir.hot_module_resolve_subtype(module_ctx, target_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.FuncCompType(_, _) => true
                _ => false
              }
            None => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn ls_ref_is_subtype(
  module_ctx : @ir.HotModuleContext,
  source : @lib.RefType,
  target : @lib.RefType,
) -> Bool {
  if source.is_nullable() && !target.is_nullable() {
    return false
  }
  if target.is_exact() {
    return source.is_exact() && source.get_heap_type() == target.get_heap_type()
  }
  ls_heap_is_subtype(
    module_ctx,
    source.get_heap_type(),
    target.get_heap_type(),
    512,
  )
}

///|
fn ls_as_ref(vt : @lib.ValType) -> @lib.RefType? {
  match vt {
    @lib.RefTypeValType(ref_type) => Some(ref_type)
    _ => None
  }
}

///|
fn ls_candidate_local_type(
  declared : @lib.ValType,
  assigned : Array[@lib.ValType],
  module_ctx : @ir.HotModuleContext,
) -> @lib.ValType? {
  let declared_ref = match ls_as_ref(declared) {
    Some(ref_type) => ref_type
    None => return None
  }
  if assigned.is_empty() {
    return None
  }
  let ref_candidates : Array[@lib.RefType] = []
  for vt in assigned {
    match ls_as_ref(vt) {
      Some(ref_type) => ref_candidates.push(ref_type)
      None => return None
    }
  }
  let mut best : @lib.RefType? = None
  for candidate in ref_candidates {
    let local_candidate = @lib.RefType::new(
      declared_ref.is_nullable() || candidate.is_nullable(),
      candidate.get_heap_type(),
      exact=candidate.is_exact(),
    )
    if !ls_ref_is_subtype(module_ctx, local_candidate, declared_ref) {
      continue
    }
    let mut accepts_all = true
    for assigned_ref in ref_candidates {
      if !ls_ref_is_subtype(module_ctx, assigned_ref, local_candidate) {
        accepts_all = false
        break
      }
    }
    if !accepts_all {
      continue
    }
    match best {
      None => best = Some(local_candidate)
      Some(best_ref) =>
        if ls_ref_is_subtype(module_ctx, local_candidate, best_ref) {
          best = Some(local_candidate)
        }
    }
  }
  match best {
    Some(best_ref) => {
      let vt = @lib.ValType::ref_type(best_ref)
      if vt == declared {
        None
      } else {
        Some(vt)
      }
    }
    None => None
  }
}

///|
fn ls_collect_assignments(func : @ir.HotFunc) -> Array[Array[@lib.ValType]] {
  let locals : Array[Array[@lib.ValType]] = []
  for i = 0; i < @ir.hot_local_count(func); i = i + 1 {
    ignore(i)
    locals.push([])
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
        if node.imm0 < 0 || node.imm0 >= locals.length() {
          continue
        }
        if @ir.hot_child_count(func, node_id) != 1 {
          continue
        }
        let child = @ir.hot_child_get(func, node_id, 0)
        let results = @ir.hot_type_results(func, @ir.hot_node_type(func, child))
        if results.length() == 1 {
          locals[node.imm0].push(results[0])
        }
      }
      _ => ()
    }
  }
  locals
}

///|
fn ls_rewrite_func(
  func : @lib.Func,
  func_idx : @lib.FuncIdx,
  mod_ : @lib.Module,
  module_ctx : @ir.HotModuleContext,
) -> (@lib.Func, Bool) {
  let hot_func = @ir.hot_lift_func_with_context(mod_, func_idx, module_ctx)
  let assignments = ls_collect_assignments(hot_func)
  let param_count = @ir.hot_local_param_count(hot_func)
  let @lib.Func(body_locals, body) = func
  let rewritten_locals = body_locals.copy()
  let mut changed = false
  for body_idx = 0; body_idx < body_locals.length(); body_idx = body_idx + 1 {
    let local_idx = param_count + body_idx
    let declared = match body_locals.at(body_idx) {
      Some(vt) => vt
      None => continue
    }
    let assigned = match assignments.get(local_idx) {
      Some(types) => types
      None => continue
    }
    match ls_candidate_local_type(declared, assigned, module_ctx) {
      Some(next) => if rewritten_locals.set(body_idx, next) { changed = true }
      None => ()
    }
  }
  if changed {
    (@lib.Func::new(rewritten_locals, body), true)
  } else {
    (func, false)
  }
}

///|
fn ls_rebuild_module(
  mod_ : @lib.Module,
  next_code_sec : @lib.CodeSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=next_code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
  )
}

///|
pub fn local_subtyping_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let module_ctx = @ir.hot_module_context_from_module(mod_)
      let imported_func_count = ls_imported_func_count(mod_)
      let rewritten_funcs : Array[@lib.Func] = Array::new(
        capacity=funcs.length(),
      )
      let mut changed = false
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        let (next_func, next_changed) = ls_rewrite_func(
          funcs[code_idx],
          func_idx,
          mod_,
          module_ctx,
        )
        rewritten_funcs.push(next_func)
        if next_changed {
          changed = true
        }
      }
      if !changed {
        return mod_
      }
      ls_rebuild_module(mod_, Some(@lib.CodeSec::new(rewritten_funcs)))
    }
    None => mod_
  }
}
