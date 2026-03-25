///|
pub fn global_refining_summary() -> String {
  "Refine private defined global reference types from their initializer and observed writes."
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
fn gr_expr_result_type(env : @validate.Env, expr : @lib.Expr) -> @lib.ValType? {
  match expr {
    @lib.Expr([@lib.RefNull(ref_type)]) =>
      Some(@lib.ValType::ref_type(ref_type.make_nullable()))
    @lib.Expr([@lib.GlobalGet(global_idx)]) =>
      match env.get_global_type(global_idx) {
        Some(global_type) =>
          match gr_global_ref_type(global_type) {
            Some(ref_type) => Some(@lib.ValType::ref_type(ref_type))
            None => None
          }
        None => None
      }
    @lib.Expr([@lib.RefFunc(func_idx)]) =>
      match env.get_functypeidx_by_funcidx(func_idx) {
        Some(type_idx) =>
          Some(
            @lib.ValType::ref_type(
              @lib.RefType::new(false, @lib.HeapType::new(type_idx)),
            ),
          )
        None => None
      }
    _ => None
  }
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
  let exact = left.is_exact() &&
    right.is_exact() &&
    left.get_heap_type() == right.get_heap_type() &&
    gr_heaptype_supports_exact(heap_type)
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
pub fn global_refining_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
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
    if exported_globals[abs_idx] {
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
      let imported_func_count = gr_imported_func_count(mod_)
      for defined_idx = 0
          defined_idx < funcs.length()
          defined_idx = defined_idx + 1 {
        let @lib.Func(_, @lib.Expr(instrs)) = funcs[defined_idx]
        if !gr_scan_candidate_sets(instrs, candidate_slots) {
          continue
        }
        let abs_idx = imported_func_count + defined_idx
        let hot_func = @ir.hot_lift_func(
          mod_,
          @lib.FuncIdx::new(abs_idx.reinterpret_as_uint()),
        )
        gr_collect_func_global_sets(hot_func, candidate_slots, noted, env)
      }
    }
    None => ()
  }

  let next_globals = globals.copy()
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
    let @lib.Global(@lib.GlobalType(_, mutable_), init) = next_globals[defined_idx]
    next_globals[defined_idx] = @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::ref_type(refined_ref_type), mutable_),
      init,
    )
    changed = true
  }
  if !changed {
    return mod_
  }
  mod_.with_global_sec(@lib.GlobalSec::new(next_globals))
}
