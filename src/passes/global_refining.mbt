///|
pub fn global_refining_summary() -> String {
  "Refine defined global reference types from their initializer and observed writes, while preserving mutable export boundaries."
}

///|
fn gr_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn gr_imported_global_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn gr_slot_for_abs_idx(slots : Array[Int], abs_idx : UInt) -> Int {
  let slot = abs_idx.reinterpret_as_int()
  if slot < 0 || slot >= slots.length() {
    -1
  } else {
    slots[slot]
  }
}

///|
fn gr_global_ref_type(global_type : @lib.GlobalType) -> @lib.RefType? {
  match global_type {
    @lib.GlobalType(@lib.RefTypeValType(ref_type), _) => Some(ref_type)
    _ => None
  }
}

///|
fn gr_null_bottom_type_for_comp(comp_type : @lib.CompType) -> @lib.AbsHeapType {
  match comp_type {
    @lib.FuncCompType(_, _) => @lib.AbsHeapType::no_func()
    @lib.StructCompType(_) | @lib.ArrayCompType(_) => @lib.AbsHeapType::none()
  }
}

///|
fn gr_ref_func_result_type(
  env : @validate.Env,
  func_idx : @lib.FuncIdx,
) -> @lib.RefType? {
  match env.get_functypeidx_by_funcidx(func_idx) {
    Some(type_idx) =>
      Some(@lib.RefType::new(false, @lib.HeapType::new(type_idx), exact=true))
    None => None
  }
}

///|
fn gr_ref_null_result_type(
  ref_type : @lib.RefType,
  env : @validate.Env,
) -> @lib.RefType {
  match ref_type.get_heap_type() {
    @lib.AbsHeapTypeHeapType(abs) => {
      let bottom = match abs {
        @lib.FuncAbsHeapType => @lib.AbsHeapType::no_func()
        @lib.NoFuncAbsHeapType => @lib.AbsHeapType::no_func()
        @lib.ExternAbsHeapType => @lib.AbsHeapType::no_extern()
        @lib.NoExternAbsHeapType => @lib.AbsHeapType::no_extern()
        @lib.ExnAbsHeapType => @lib.AbsHeapType::no_exn()
        @lib.NoExnAbsHeapType => @lib.AbsHeapType::no_exn()
        @lib.AnyAbsHeapType
        | @lib.EqAbsHeapType
        | @lib.I31AbsHeapType
        | @lib.StructAbsHeapType
        | @lib.ArrayAbsHeapType
        | @lib.StringAbsHeapType
        | @lib.NoneAbsHeapType => @lib.AbsHeapType::none()
      }
      @lib.RefType::new(true, @lib.HeapType::abs(bottom))
    }
    heap_type =>
      match env.resolve_heaptype_subtype(heap_type) {
        Some(subtype) =>
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(
              gr_null_bottom_type_for_comp(subtype.get_comptype()),
            ),
          )
        None => ref_type.make_nullable()
      }
  }
}

///|
fn gr_expr_typechecked_result_type(
  env : @validate.Env,
  expr : @lib.Expr,
) -> @lib.ValType? {
  match @validate.Typecheck::typecheck(expr, @validate.make_state(env, [])) {
    Ok(state) =>
      if state.reachable && state.stack.length() == 1 {
        Some(state.stack[0])
      } else {
        None
      }
    Err(_) => None
  }
}

///|
fn gr_expr_result_type(env : @validate.Env, expr : @lib.Expr) -> @lib.ValType? {
  match expr {
    @lib.Expr([@lib.RefNull(ref_type)]) =>
      Some(@lib.ValType::ref_type(gr_ref_null_result_type(ref_type, env)))
    _ => gr_expr_typechecked_result_type(env, expr)
  }
}

///|
fn gr_valtype_is_public(
  val_type : @lib.ValType,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  match val_type {
    @lib.RefTypeValType(ref_type) =>
      gr_reftype_is_public(ref_type, env, type_states)
    _ => true
  }
}

///|
fn gr_storage_type_is_public(
  storage_type : @lib.StorageType,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      gr_valtype_is_public(val_type, env, type_states)
    @lib.PackTypeStorageType(_) => true
  }
}

///|
fn gr_field_type_is_public(
  field_type : @lib.FieldType,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  gr_storage_type_is_public(field_type.get_storage_type(), env, type_states)
}

///|
fn gr_comptype_is_public(
  comp_type : @lib.CompType,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  match comp_type {
    @lib.FuncCompType(params, results) => {
      for param in params {
        if !gr_valtype_is_public(param, env, type_states) {
          return false
        }
      }
      for result in results {
        if !gr_valtype_is_public(result, env, type_states) {
          return false
        }
      }
      true
    }
    @lib.StructCompType(fields) => {
      for field in fields {
        if !gr_field_type_is_public(field, env, type_states) {
          return false
        }
      }
      true
    }
    @lib.ArrayCompType(field) =>
      gr_field_type_is_public(field, env, type_states)
  }
}

///|
fn gr_typeidx_is_public(
  type_idx : @lib.TypeIdx,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  match type_idx {
    @lib.TypeIdx(raw) => {
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= type_states.length() {
        return true
      }
      match type_states[idx] {
        2 => return true
        3 => return false
        1 => return true
        _ => ()
      }
      type_states[idx] = 1
      let public = match env.resolve_subtype(type_idx) {
        Some(subtype) =>
          gr_comptype_is_public(subtype.get_comptype(), env, type_states)
        None => true
      }
      type_states[idx] = if public { 2 } else { 3 }
      public
    }
    @lib.RecIdx(_) =>
      match env.resolve_subtype(type_idx) {
        Some(subtype) =>
          gr_comptype_is_public(subtype.get_comptype(), env, type_states)
        None => true
      }
  }
}

///|
fn gr_heaptype_is_public(
  heap_type : @lib.HeapType,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) => true
    @lib.HeapType(type_idx) => gr_typeidx_is_public(type_idx, env, type_states)
    @lib.DefTypeHeapType(def_type) =>
      match def_type.project() {
        Some(subtype) =>
          gr_comptype_is_public(subtype.get_comptype(), env, type_states)
        None => true
      }
  }
}

///|
fn gr_reftype_is_public(
  ref_type : @lib.RefType,
  env : @validate.Env,
  type_states : Array[Int],
) -> Bool {
  if ref_type.is_exact() {
    return false
  }
  gr_heaptype_is_public(ref_type.get_heap_type(), env, type_states)
}

///|
fn gr_custom_descriptors_enabled_locally(_env : @validate.Env) -> Bool {
  // Starshine's current direct-pass and preset feature model runs with the
  // custom-descriptors proposal available, matching the `--all-features`
  // Binaryen oracle lane used by pass-fuzz-compare. Binaryen's
  // PublicTypeValidator accepts every exported immutable refinement under that
  // feature, including exact refs and types whose bodies mention exact refs.
  true
}

///|
fn gr_refined_export_type_is_public(
  ref_type : @lib.RefType,
  env : @validate.Env,
) -> Bool {
  if gr_custom_descriptors_enabled_locally(env) {
    return true
  }
  gr_reftype_is_public(ref_type, env, Array::make(env.global_types.length(), 0))
}

///|
fn gr_append_unique_heaptype(
  out : Array[@lib.HeapType],
  heap_type : @lib.HeapType,
) -> Unit {
  for existing in out {
    if existing == heap_type {
      return
    }
  }
  out.push(heap_type)
}

///|
fn gr_append_abs_heap_supertypes(
  out : Array[@lib.HeapType],
  abs : @lib.AbsHeapType,
) -> Unit {
  match abs {
    @lib.I31AbsHeapType | @lib.StructAbsHeapType | @lib.ArrayAbsHeapType => {
      gr_append_unique_heaptype(out, @lib.HeapType::abs(@lib.AbsHeapType::eq()))
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::any()),
      )
    }
    @lib.EqAbsHeapType =>
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::any()),
      )
    _ => ()
  }
}

///|
fn gr_append_shape_heap_supertypes(
  out : Array[@lib.HeapType],
  comp_type : @lib.CompType,
) -> Unit {
  match comp_type {
    @lib.StructCompType(_) => {
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::struct_()),
      )
      gr_append_unique_heaptype(out, @lib.HeapType::abs(@lib.AbsHeapType::eq()))
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::any()),
      )
    }
    @lib.ArrayCompType(_) => {
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::array()),
      )
      gr_append_unique_heaptype(out, @lib.HeapType::abs(@lib.AbsHeapType::eq()))
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::any()),
      )
    }
    @lib.FuncCompType(_, _) =>
      gr_append_unique_heaptype(
        out,
        @lib.HeapType::abs(@lib.AbsHeapType::func()),
      )
  }
}

///|
fn gr_collect_heaptype_candidates(
  heap_type : @lib.HeapType,
  env : @validate.Env,
) -> Array[@lib.HeapType] {
  let out : Array[@lib.HeapType] = []
  let abstract_fallbacks : Array[@lib.HeapType] = []
  let work : Array[@lib.HeapType] = [heap_type]
  while work.length() > 0 {
    let current = work.pop().unwrap()
    let prior_len = out.length()
    gr_append_unique_heaptype(out, current)
    if out.length() == prior_len {
      continue
    }
    match current {
      @lib.AbsHeapTypeHeapType(abs) =>
        gr_append_abs_heap_supertypes(abstract_fallbacks, abs)
      @lib.HeapType(type_idx) =>
        match env.resolve_subtype(type_idx) {
          Some(subtype) => {
            for super_type in subtype.super_types().rev_iter() {
              work.push(@lib.HeapType::new(super_type))
            }
            gr_append_shape_heap_supertypes(
              abstract_fallbacks,
              subtype.get_comptype(),
            )
          }
          None => ()
        }
      @lib.DefTypeHeapType(def_type) =>
        match def_type.project() {
          Some(subtype) => {
            for super_type in subtype.super_types().rev_iter() {
              work.push(@lib.HeapType::new(super_type))
            }
            gr_append_shape_heap_supertypes(
              abstract_fallbacks,
              subtype.get_comptype(),
            )
          }
          None => ()
        }
    }
  }
  for fallback in abstract_fallbacks {
    gr_append_unique_heaptype(out, fallback)
  }
  out
}

///|
fn gr_join_heaptypes(
  left : @lib.HeapType,
  right : @lib.HeapType,
  env : @validate.Env,
) -> @lib.HeapType? {
  if @validate.Match::matches(left, right, env) {
    return Some(right)
  }
  if @validate.Match::matches(right, left, env) {
    return Some(left)
  }
  let candidates = gr_collect_heaptype_candidates(left, env)
  for candidate in candidates {
    if @validate.Match::matches(left, candidate, env) &&
      @validate.Match::matches(right, candidate, env) {
      return Some(candidate)
    }
  }
  None
}

///|
fn gr_heaptype_supports_exact(heap_type : @lib.HeapType) -> Bool {
  match heap_type {
    @lib.HeapType(_) | @lib.DefTypeHeapType(_) => true
    @lib.AbsHeapTypeHeapType(_) => false
  }
}

///|
fn gr_ref_type_is_nullable_bottom_for_heap(
  ref_type : @lib.RefType,
  heap_type : @lib.HeapType,
  env : @validate.Env,
) -> Bool {
  if !ref_type.is_nullable() || ref_type.is_exact() {
    return false
  }
  let bottom = match ref_type.get_heap_type() {
    @lib.AbsHeapTypeHeapType(abs) => abs
    _ => return false
  }
  match env.resolve_heaptype_subtype(heap_type) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.FuncCompType(_, _) => bottom == @lib.AbsHeapType::no_func()
        @lib.StructCompType(_) | @lib.ArrayCompType(_) =>
          bottom == @lib.AbsHeapType::none()
      }
    None => false
  }
}

///|
fn gr_join_reftypes_preserves_exact(
  left : @lib.RefType,
  right : @lib.RefType,
  heap_type : @lib.HeapType,
  env : @validate.Env,
) -> Bool {
  if !gr_heaptype_supports_exact(heap_type) {
    return false
  }
  if left.is_exact() &&
    right.is_exact() &&
    left.get_heap_type() == heap_type &&
    right.get_heap_type() == heap_type {
    return true
  }
  if left.is_exact() &&
    left.get_heap_type() == heap_type &&
    gr_ref_type_is_nullable_bottom_for_heap(right, heap_type, env) {
    return true
  }
  if right.is_exact() &&
    right.get_heap_type() == heap_type &&
    gr_ref_type_is_nullable_bottom_for_heap(left, heap_type, env) {
    return true
  }
  false
}

///|
fn gr_join_reftypes(
  left : @lib.RefType,
  right : @lib.RefType,
  env : @validate.Env,
) -> @lib.RefType? {
  let heap_type = match
    gr_join_heaptypes(left.get_heap_type(), right.get_heap_type(), env) {
    Some(heap_type) => heap_type
    None => return None
  }
  let exact = gr_join_reftypes_preserves_exact(left, right, heap_type, env)
  let joined = @lib.RefType::new(
    left.is_nullable() || right.is_nullable(),
    heap_type,
    exact~,
  )
  if @validate.Match::matches(left, joined, env) &&
    @validate.Match::matches(right, joined, env) {
    Some(joined)
  } else {
    None
  }
}

///|
fn gr_note_ref_type(
  noted : Array[@lib.RefType?],
  slot : Int,
  next : @lib.RefType,
  env : @validate.Env,
) -> Unit {
  if slot < 0 || slot >= noted.length() {
    return
  }
  match noted[slot] {
    None => noted[slot] = Some(next)
    Some(current) =>
      match gr_join_reftypes(current, next, env) {
        Some(joined) => noted[slot] = Some(joined)
        None => ()
      }
  }
}

///|
fn gr_scan_candidate_sets(
  instrs : Array[@lib.Instruction],
  candidate_slots : Array[Int],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) =>
        if gr_slot_for_abs_idx(candidate_slots, global_idx) >= 0 {
          return true
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if gr_scan_candidate_sets(body, candidate_slots) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if gr_scan_candidate_sets(then_body, candidate_slots) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if gr_scan_candidate_sets(else_body, candidate_slots) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if gr_scan_candidate_sets(body, candidate_slots) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn gr_collect_func_global_sets(
  hot_func : @ir.HotFunc,
  candidate_slots : Array[Int],
  noted : Array[@lib.RefType?],
  env : @validate.Env,
) -> Unit {
  let stack : Array[Int] = []
  for root_idx = @ir.hot_root_count(hot_func) - 1
      root_idx >= 0
      root_idx = root_idx - 1 {
    stack.push(@ir.hot_root_get(hot_func, root_idx))
  }
  while stack.length() > 0 {
    let node_id = stack.pop().unwrap()
    let node = @ir.hot_node_get(hot_func, node_id)
    match node.op {
      @ir.HotOp::GlobalSet => {
        let global_idx = node.imm0
        if global_idx >= 0 && global_idx < candidate_slots.length() {
          let slot = candidate_slots[global_idx]
          if slot >= 0 && @ir.hot_child_count(hot_func, node_id) > 0 {
            let value_id = @ir.hot_child_get(hot_func, node_id, 0)
            if value_id >= 0 {
              let value_node = @ir.hot_node_get(hot_func, value_id)
              match value_node.op {
                @ir.HotOp::RefFunc =>
                  if value_node.imm0 >= 0 {
                    match
                      gr_ref_func_result_type(
                        env,
                        @lib.FuncIdx::new(value_node.imm0.reinterpret_as_uint()),
                      ) {
                      Some(ref_type) =>
                        gr_note_ref_type(noted, slot, ref_type, env)
                      None => ()
                    }
                  }
                @ir.HotOp::RefNull =>
                  if value_node.imm0 >= 0 {
                    match @ir.hot_const_get(hot_func, value_node.imm0) {
                      @ir.HotConstPayload::RefNullConst(ref_type) => {
                        let noted_ref_type = match ref_type.get_heap_type() {
                          @lib.AbsHeapTypeHeapType(_) =>
                            gr_ref_null_result_type(ref_type, env)
                          _ => ref_type
                        }
                        gr_note_ref_type(noted, slot, noted_ref_type, env)
                      }
                      _ => ()
                    }
                  }
                _ =>
                  match
                    @ir.hot_type_results(
                      hot_func,
                      @ir.hot_node_type(hot_func, value_id),
                    ) {
                    [@lib.RefTypeValType(ref_type)] =>
                      gr_note_ref_type(noted, slot, ref_type, env)
                    _ => ()
                  }
              }
            }
          }
        }
      }
      _ => ()
    }
    for child_idx = 0
        child_idx < @ir.hot_child_count(hot_func, node_id)
        child_idx = child_idx + 1 {
      let child_id = @ir.hot_child_get(hot_func, node_id, child_idx)
      if child_id >= 0 && @ir.hot_node_is_live(hot_func, child_id) {
        stack.push(child_id)
      }
    }
  }
}

///|
fn gr_rewrite_ref_null_set_instrs(
  instrs : Array[@lib.Instruction],
  refined_globals : Array[@lib.RefType?],
) -> (Array[@lib.Instruction], Bool) {
  let next = instrs.copy()
  let mut changed = false
  for idx = 0; idx < next.length(); idx = idx + 1 {
    match next[idx] {
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = global_idx.reinterpret_as_int()
        if idx > 0 && slot >= 0 && slot < refined_globals.length() {
          match (next[idx - 1], refined_globals[slot]) {
            (@lib.RefNull(_), Some(refined_ref_type)) => {
              next[idx - 1] = @lib.Instruction::ref_null_type(refined_ref_type)
              changed = true
            }
            _ => ()
          }
        }
      }
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = gr_rewrite_ref_null_set_instrs(
          body, refined_globals,
        )
        if body_changed {
          next[idx] = @lib.Instruction::block(
            block_type,
            @lib.Expr::new(next_body),
          )
          changed = true
        }
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = gr_rewrite_ref_null_set_instrs(
          body, refined_globals,
        )
        if body_changed {
          next[idx] = @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(next_body),
          )
          changed = true
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        let (next_then, then_changed) = gr_rewrite_ref_null_set_instrs(
          then_body, refined_globals,
        )
        let (next_else, else_changed) = match else_body {
          Some(else_body) => {
            let (rewritten_else, changed) = gr_rewrite_ref_null_set_instrs(
              else_body, refined_globals,
            )
            (Some(rewritten_else), changed)
          }
          None => (None, false)
        }
        if then_changed || else_changed {
          next[idx] = @lib.Instruction::if_(block_type, next_then, next_else)
          changed = true
        }
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (next_body, body_changed) = gr_rewrite_ref_null_set_instrs(
          body, refined_globals,
        )
        if body_changed {
          next[idx] = @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(next_body),
          )
          changed = true
        }
      }
      _ => ()
    }
  }
  (next, changed)
}

///|
fn gr_rewrite_ref_null_sets_in_code(
  mod_ : @lib.Module,
  refined_globals : Array[@lib.RefType?],
) -> (@lib.Module, Bool) {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return (mod_, false)
  }
  let next_funcs = funcs.copy()
  let mut changed = false
  for idx = 0; idx < funcs.length(); idx = idx + 1 {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[idx]
    let (next_body, body_changed) = gr_rewrite_ref_null_set_instrs(
      body, refined_globals,
    )
    if body_changed {
      next_funcs[idx] = @lib.Func::new(locals, @lib.Expr::new(next_body))
      changed = true
    }
  }
  if changed {
    (mod_.with_code_sec(@lib.CodeSec::new(next_funcs)), true)
  } else {
    (mod_, false)
  }
}

///|
pub fn global_refining_run_module_pass(
  mod_ : @lib.Module,
  closed_world? : Bool = false,
) -> @lib.Module {
  let env = @validate.Env::new().with_module(mod_)
  let imported_global_count = gr_imported_global_count(mod_)
  let total_globals = env.globals.length()
  if imported_global_count >= total_globals {
    return mod_
  }
  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => return mod_
  }

  let exported_globals = Array::make(total_globals, false)
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(global_idx))) => {
            let slot = global_idx.reinterpret_as_int()
            if slot >= 0 && slot < exported_globals.length() {
              exported_globals[slot] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }

  let candidate_slots = Array::make(total_globals, -1)
  let candidate_abs_globals : Array[Int] = []
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_global_count + defined_idx
    let is_mutable = match env.globals[abs_idx] {
      @lib.GlobalType(_, mutable_) => mutable_
    }
    if exported_globals[abs_idx] && (closed_world || is_mutable) {
      continue
    }
    match gr_global_ref_type(env.globals[abs_idx]) {
      Some(_) => {
        candidate_slots[abs_idx] = candidate_abs_globals.length()
        candidate_abs_globals.push(abs_idx)
      }
      None => ()
    }
  }
  if candidate_abs_globals.length() == 0 {
    return mod_
  }

  let noted : Array[@lib.RefType?] = []
  for _ in candidate_abs_globals {
    noted.push(None)
  }

  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_global_count + defined_idx
    let slot = candidate_slots[abs_idx]
    if slot < 0 {
      continue
    }
    let @lib.Global(_, init) = globals[defined_idx]
    match gr_expr_result_type(env, init) {
      Some(@lib.RefTypeValType(ref_type)) =>
        gr_note_ref_type(noted, slot, ref_type, env)
      _ => ()
    }
  }

  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let module_ctx = @ir.hot_module_context_from_module(mod_)
      let imported_func_count = gr_imported_func_count(mod_)
      for defined_idx = 0
          defined_idx < funcs.length()
          defined_idx = defined_idx + 1 {
        let @lib.Func(_, @lib.Expr(instrs)) = funcs[defined_idx]
        if !gr_scan_candidate_sets(instrs, candidate_slots) {
          continue
        }
        let abs_idx = imported_func_count + defined_idx
        let hot_func = @ir.hot_lift_func_with_context(
          mod_,
          @lib.FuncIdx::new(abs_idx.reinterpret_as_uint()),
          module_ctx,
        )
        gr_collect_func_global_sets(hot_func, candidate_slots, noted, env)
      }
    }
    None => ()
  }

  let next_globals = globals.copy()
  let refined_globals : Array[@lib.RefType?] = Array::make(total_globals, None)
  let mut changed = false
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_global_count + defined_idx
    let slot = candidate_slots[abs_idx]
    if slot < 0 {
      continue
    }
    let old_global_type = env.globals[abs_idx]
    let old_ref_type = match gr_global_ref_type(old_global_type) {
      Some(ref_type) => ref_type
      None => continue
    }
    let refined_ref_type = match noted[slot] {
      Some(ref_type) => ref_type
      None => continue
    }
    if refined_ref_type == old_ref_type ||
      !@validate.Match::matches(refined_ref_type, old_ref_type, env) {
      continue
    }
    if exported_globals[abs_idx] &&
      !gr_refined_export_type_is_public(refined_ref_type, env) {
      continue
    }
    let @lib.Global(@lib.GlobalType(_, mutable_), init) = next_globals[defined_idx]
    let refined_init = match init {
      @lib.Expr([@lib.RefNull(_)]) =>
        @lib.Expr::new([@lib.Instruction::ref_null_type(refined_ref_type)])
      _ => init
    }
    next_globals[defined_idx] = @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::ref_type(refined_ref_type), mutable_),
      refined_init,
    )
    refined_globals[abs_idx] = Some(refined_ref_type)
    changed = true
  }
  if !changed {
    return mod_
  }
  let rewritten = mod_.with_global_sec(@lib.GlobalSec::new(next_globals))
  let (rewritten, _) = gr_rewrite_ref_null_sets_in_code(
    rewritten, refined_globals,
  )
  rewritten
}
