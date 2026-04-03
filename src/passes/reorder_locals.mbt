///|
pub fn reorder_locals_summary() -> String {
  "Sort body locals by access frequency and drop unaccessed body locals."
}

///|
priv struct RLScanState {
  counts : Array[Int]
  first_uses : Array[Int]
  used_body_locals : Array[Int]
  param_count : Int
  mut next_rank : Int
}

///|
fn RLScanState::new(local_count : Int, param_count : Int) -> RLScanState {
  {
    counts: Array::make(local_count, 0),
    first_uses: Array::make(local_count, 0),
    used_body_locals: Array::new(capacity=local_count - param_count),
    param_count,
    next_rank: 1,
  }
}

///|
priv struct RLFuncRewrite {
  func : @lib.Func
  old_to_new : Array[Int]
  changed : Bool
}

///|
fn rl_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn rl_local_idx_raw(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rl_local_idx_from_int(idx : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(idx.reinterpret_as_uint())
}

///|

///|
fn rl_flatten_locals(
  locals : @lib.Locals,
  local_count : Int,
) -> Array[@lib.ValType] {
  let out : Array[@lib.ValType] = Array::new(capacity=local_count)
  for run in locals.runs() {
    let ty = run.val_type()
    let run_len = run.count().reinterpret_as_int()
    for idx = 0; idx < run_len; idx = idx + 1 {
      out.push(ty)
    }
  }
  out
}

///|
fn rl_push_local_run(runs : Array[@lib.LocalRun], ty : @lib.ValType) -> Unit {
  match runs.last() {
    Some(last) if last.val_type() == ty =>
      runs[runs.length() - 1] = @lib.LocalRun::new(last.count() + 1U, ty)
    _ => runs.push(@lib.LocalRun::new(1U, ty))
  }
}

///|
fn rl_note_access(state : RLScanState, idx : @lib.LocalIdx) -> Unit {
  let raw = rl_local_idx_raw(idx)
  if raw < 0 || raw >= state.counts.length() {
    abort("reorder-locals encountered out-of-range local index")
  }
  state.counts[raw] += 1
  if raw >= state.param_count && state.first_uses[raw] == 0 {
    state.first_uses[raw] = state.next_rank
    state.used_body_locals.push(raw)
    state.next_rank += 1
  }
}

///|
fn rl_scan_expr(expr : @lib.Expr, state : RLScanState) -> Unit {
  let @lib.Expr(instrs) = expr
  rl_scan_instrs(instrs, state)
}

///|
fn rl_scan_instrs(
  instrs : Array[@lib.Instruction],
  state : RLScanState,
) -> Unit {
  for instr in instrs {
    rl_scan_instruction(instr, state)
  }
}

///|
fn rl_scan_instruction(instr : @lib.Instruction, state : RLScanState) -> Unit {
  match instr {
    @lib.Block(_, body) => rl_scan_expr(body, state)
    @lib.Loop(_, body) => rl_scan_expr(body, state)
    @lib.If(_, then_body, else_body) => {
      rl_scan_instrs(then_body, state)
      match else_body {
        Some(body) => rl_scan_instrs(body, state)
        None => ()
      }
    }
    @lib.TryTable(_, _, body) => rl_scan_expr(body, state)
    @lib.LocalGet(idx) => rl_note_access(state, idx)
    @lib.LocalSet(idx) => rl_note_access(state, idx)
    @lib.LocalTee(idx) => rl_note_access(state, idx)
    _ => ()
  }
}

///|
fn rl_sort_used_body_locals(
  used_body_locals : Array[Int],
  counts : Array[Int],
  first_uses : Array[Int],
) -> Array[Int] {
  used_body_locals.sort_by(fn(lhs, rhs) {
    let lhs_count = counts[lhs]
    let rhs_count = counts[rhs]
    if lhs_count == rhs_count {
      if first_uses[lhs] == first_uses[rhs] {
        lhs - rhs
      } else {
        first_uses[lhs] - first_uses[rhs]
      }
    } else {
      rhs_count - lhs_count
    }
  })
  used_body_locals
}

///|
fn rl_rewrite_local_idx(
  idx : @lib.LocalIdx,
  old_to_new : Array[Int],
) -> @lib.LocalIdx {
  let raw = rl_local_idx_raw(idx)
  if raw < 0 || raw >= old_to_new.length() {
    abort("reorder-locals local remap out of range")
  }
  let mapped = old_to_new[raw]
  if mapped < 0 {
    abort("reorder-locals attempted to rewrite dropped local access")
  }
  rl_local_idx_from_int(mapped)
}

///|
fn rl_rewrite_expr(expr : @lib.Expr, old_to_new : Array[Int]) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  rl_rewrite_instrs_in_place(instrs, old_to_new)
  expr
}

///|
fn rl_rewrite_instrs_in_place(
  instrs : Array[@lib.Instruction],
  old_to_new : Array[Int],
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        rl_rewrite_instrs_in_place(body, old_to_new)
        instrs[idx] = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        rl_rewrite_instrs_in_place(body, old_to_new)
        instrs[idx] = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        rl_rewrite_instrs_in_place(then_body, old_to_new)
        match else_body {
          Some(else_instrs) =>
            rl_rewrite_instrs_in_place(else_instrs, old_to_new)
          None => ()
        }
        instrs[idx] = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        rl_rewrite_instrs_in_place(body, old_to_new)
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      @lib.LocalGet(local_idx) => {
        let next_idx = rl_rewrite_local_idx(local_idx, old_to_new)
        if next_idx != local_idx {
          instrs[idx] = @lib.Instruction::local_get(next_idx)
        }
      }
      @lib.LocalSet(local_idx) => {
        let next_idx = rl_rewrite_local_idx(local_idx, old_to_new)
        if next_idx != local_idx {
          instrs[idx] = @lib.Instruction::local_set(next_idx)
        }
      }
      @lib.LocalTee(local_idx) => {
        let next_idx = rl_rewrite_local_idx(local_idx, old_to_new)
        if next_idx != local_idx {
          instrs[idx] = @lib.Instruction::local_tee(next_idx)
        }
      }
      _ => ()
    }
  }
}

///|
fn rl_module_subtypes(mod_ : @lib.Module) -> Array[@lib.SubType] {
  let subtypes : Array[@lib.SubType] = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => Array::new(capacity=rec_types.length())
    None => []
  }
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => subtypes.push(subtype)
          @lib.GroupRecType(group) =>
            for subtype in group {
              subtypes.push(subtype)
            }
        }
      }
    None => abort("reorder-locals missing type section")
  }
  subtypes
}

///|
fn rl_params_for_type_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Array[@lib.ValType] {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => abort("reorder-locals missing function subtype")
      }
    @lib.RecIdx(_) =>
      abort("reorder-locals unsupported recursive function type index")
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => abort("reorder-locals expected function type")
  }
}

///|
fn rl_defined_func_param_cache(
  mod_ : @lib.Module,
) -> Array[Array[@lib.ValType]] {
  let subtypes = rl_module_subtypes(mod_)
  let out : Array[Array[@lib.ValType]] = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => Array::new(capacity=type_idxs.length())
    None => []
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out.push(rl_params_for_type_idx(subtypes, type_idx))
      }
    None => abort("reorder-locals missing function section")
  }
  out
}

///|
fn rl_used_body_locals_are_original_prefix(
  used_body_locals : Array[Int],
  param_count : Int,
) -> Bool {
  for idx = 0; idx < used_body_locals.length(); idx = idx + 1 {
    if used_body_locals[idx] != param_count + idx {
      return false
    }
  }
  true
}

///|
fn rl_rewrite_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> RLFuncRewrite {
  let @lib.Func(body_locals, body) = func
  let body_local_count = body_locals.length()
  if body_local_count == 0 {
    return { func, old_to_new: [], changed: false }
  }

  let total_locals = params.length() + body_local_count
  let scan = RLScanState::new(total_locals, params.length())
  rl_scan_expr(body, scan)

  let used_body_locals = rl_sort_used_body_locals(
    scan.used_body_locals,
    scan.counts,
    scan.first_uses,
  )
  let used_body_locals_are_original_prefix = rl_used_body_locals_are_original_prefix(
    used_body_locals,
    params.length(),
  )
  if used_body_locals.length() == body_local_count &&
    used_body_locals_are_original_prefix {
    return { func, old_to_new: [], changed: false }
  }

  let old_to_new = Array::make(total_locals, -1)
  for idx = 0; idx < params.length(); idx = idx + 1 {
    old_to_new[idx] = idx
  }

  let body_local_types = rl_flatten_locals(body_locals, body_local_count)
  let reordered_body_runs : Array[@lib.LocalRun] = Array::new(
    capacity=used_body_locals.length(),
  )
  for body_idx = 0
      body_idx < used_body_locals.length()
      body_idx = body_idx + 1 {
    let old_idx = used_body_locals[body_idx]
    old_to_new[old_idx] = params.length() + body_idx
    rl_push_local_run(
      reordered_body_runs,
      body_local_types[old_idx - params.length()],
    )
  }

  let rewritten_locals = @lib.Locals::new(reordered_body_runs)
  if used_body_locals_are_original_prefix {
    let rewritten_func = @lib.Func::new(rewritten_locals, body)
    return { func: rewritten_func, old_to_new, changed: true }
  }

  let rewritten_body = rl_rewrite_expr(body, old_to_new)
  let rewritten_func = @lib.Func::new(rewritten_locals, rewritten_body)
  { func: rewritten_func, old_to_new, changed: true }
}

///|
fn rl_rewrite_name_map(
  names : @lib.NameMap,
  old_to_new : Array[Int],
) -> @lib.NameMap? {
  let @lib.NameMap(entries) = names
  let rewritten : Array[@lib.NameAssoc] = Array::new(capacity=entries.length())
  let mut sorted = true
  let mut last_mapped = -1
  for entry in entries {
    let @lib.NameAssoc(idx, name) = entry
    let raw = idx.reinterpret_as_int()
    if raw < 0 || raw >= old_to_new.length() {
      continue
    }
    let mapped = old_to_new[raw]
    if mapped >= 0 {
      if mapped < last_mapped {
        sorted = false
      } else {
        last_mapped = mapped
      }
      rewritten.push(@lib.NameAssoc::new(mapped.reinterpret_as_uint(), name))
    }
  }
  if rewritten.length() == 0 {
    return None
  }
  if !sorted {
    rewritten.sort_by(fn(lhs, rhs) {
      let @lib.NameAssoc(lhs_idx, _) = lhs
      let @lib.NameAssoc(rhs_idx, _) = rhs
      lhs_idx.reinterpret_as_int() - rhs_idx.reinterpret_as_int()
    })
  }
  Some(@lib.NameMap::new(rewritten))
}

///|
fn rl_rewrite_local_names(
  names : @lib.IndirectNameMap?,
  imported_func_count : Int,
  func_remaps : Array[Array[Int]?],
) -> @lib.IndirectNameMap? {
  match names {
    Some(@lib.IndirectNameMap(entries)) => {
      let rewritten : Array[@lib.IndirectNameAssoc] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let @lib.IndirectNameAssoc(func_idx, local_names) = entry
        let raw_func_idx = func_idx.reinterpret_as_int()
        if raw_func_idx < imported_func_count {
          rewritten.push(entry)
          continue
        }
        let code_idx = raw_func_idx - imported_func_count
        match func_remaps.get(code_idx) {
          Some(Some(old_to_new)) =>
            match rl_rewrite_name_map(local_names, old_to_new) {
              Some(next_names) =>
                rewritten.push(
                  @lib.IndirectNameAssoc::new(func_idx, next_names),
                )
              None => ()
            }
          _ => rewritten.push(entry)
        }
      }
      if rewritten.length() == 0 {
        None
      } else {
        Some(@lib.IndirectNameMap::new(rewritten))
      }
    }
    None => None
  }
}

///|
fn rl_name_sec_is_empty(name_sec : @lib.NameSec) -> Bool {
  name_sec.module_name is None &&
  name_sec.func_names is None &&
  name_sec.local_names is None &&
  name_sec.label_names is None &&
  name_sec.type_names is None &&
  name_sec.table_names is None &&
  name_sec.memory_names is None &&
  name_sec.global_names is None &&
  name_sec.elem_names is None &&
  name_sec.data_names is None &&
  name_sec.field_names is None &&
  name_sec.tag_names is None
}

///|
fn rl_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  imported_func_count : Int,
  func_remaps : Array[Array[Int]?],
) -> @lib.NameSec? {
  match name_sec {
    Some(sec) => {
      let {
        module_name,
        func_names,
        label_names,
        type_names,
        table_names,
        memory_names,
        global_names,
        elem_names,
        data_names,
        field_names,
        tag_names,
        ..,
      } = sec
      let next = @lib.NameSec::new(
        module_name~,
        func_names~,
        local_names=rl_rewrite_local_names(
          sec.local_names,
          imported_func_count,
          func_remaps,
        ),
        label_names~,
        type_names~,
        table_names~,
        memory_names~,
        global_names~,
        elem_names~,
        data_names~,
        field_names~,
        tag_names~,
      )
      if rl_name_sec_is_empty(next) {
        None
      } else {
        Some(next)
      }
    }
    None => None
  }
}

///|
fn rl_rebuild_module(
  mod_ : @lib.Module,
  next_code_sec : @lib.CodeSec?,
  next_name_sec : @lib.NameSec?,
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
    name_sec=next_name_sec,
  )
}

///|
pub fn reorder_locals_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let imported_func_count = rl_imported_func_count(mod_)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let defined_func_params = rl_defined_func_param_cache(mod_)
      let rewritten_funcs : Array[@lib.Func] = Array::new(
        capacity=funcs.length(),
      )
      let func_remaps : Array[Array[Int]?] = Array::new(capacity=funcs.length())
      let mut changed = false
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        let func = funcs[code_idx]
        let params = match defined_func_params.get(code_idx) {
          Some(params) => params
          None => abort("reorder-locals missing defined function params")
        }
        let rewrite = rl_rewrite_func(func, params)
        rewritten_funcs.push(rewrite.func)
        if rewrite.changed {
          func_remaps.push(Some(rewrite.old_to_new))
          changed = true
        } else {
          func_remaps.push(None)
        }
      }
      if !changed {
        return mod_
      }
      rl_rebuild_module(
        mod_,
        Some(@lib.CodeSec::new(rewritten_funcs)),
        rl_rewrite_name_sec(mod_.name_sec, imported_func_count, func_remaps),
      )
    }
    None => mod_
  }
}
