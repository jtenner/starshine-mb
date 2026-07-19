///|
pub fn coalesce_locals_summary() -> String {
  "Coalesce compatible same-typed body locals and remove redundant local copies."
}

///|
priv enum CLActionKind {
  Get
  Set
  Tee
}

///|
priv enum CLValueSource {
  Unique
  Const(String)
  Local(Int)
}

///|
priv struct CLAction {
  kind : CLActionKind
  local_idx : Int
  source : CLValueSource
}

///|
priv struct CLLiveness {
  effective : Array[Bool]
  live_at_entry : Array[Bool]
}

///|
priv struct CLValueInterner {
  keys : Array[String]
  mut next_value : Int
}

///|
fn CLValueInterner::new() -> CLValueInterner {
  { keys: [], next_value: 0 }
}

///|
fn CLValueInterner::fresh(self : CLValueInterner) -> Int {
  let value = self.next_value
  self.next_value += 1
  value
}

///|
fn CLValueInterner::intern(self : CLValueInterner, key : String) -> Int {
  for idx = 0; idx < self.keys.length(); idx = idx + 1 {
    if self.keys[idx] == key {
      return idx
    }
  }
  self.keys.push(key)
  self.keys.length() - 1
}

///|
priv struct CLColoring {
  old_to_new : Array[Int]
  slot_types : Array[@lib.ValType]
  removed_copies : Int
}

///|
priv struct CLFuncRewrite {
  func : @lib.Func
  changed : Bool
}

///|
fn cl_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn cl_local_idx_raw(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn cl_local_idx_from_int(idx : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn cl_label_idx_raw(idx : @lib.LabelIdx) -> Int {
  let @lib.LabelIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn cl_flatten_locals(
  locals : @lib.Locals,
  local_count : Int,
) -> Array[@lib.ValType] {
  let out : Array[@lib.ValType] = Array::new(capacity=local_count)
  for run in locals.runs() {
    let ty = run.val_type()
    let run_len = run.count().reinterpret_as_int()
    for _idx = 0; _idx < run_len; _idx = _idx + 1 {
      out.push(ty)
    }
  }
  out
}

///|
fn cl_all_local_types(
  params : Array[@lib.ValType],
  body_locals : @lib.Locals,
) -> Array[@lib.ValType] {
  let body_count = body_locals.length()
  let out : Array[@lib.ValType] = Array::new(
    capacity=params.length() + body_count,
  )
  for param in params {
    out.push(param)
  }
  for body_ty in cl_flatten_locals(body_locals, body_count) {
    out.push(body_ty)
  }
  out
}

///|
fn cl_simple_const_source(instr : @lib.Instruction) -> CLValueSource? {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.RefNull(_)
    | @lib.StringConst(_) => Some(CLValueSource::Const(@debug.to_string(instr)))
    _ => None
  }
}

///|
fn cl_value_source_before(
  instrs : Array[@lib.Instruction],
  idx : Int,
) -> CLValueSource {
  if idx <= 0 {
    return CLValueSource::Unique
  }
  match instrs[idx - 1] {
    @lib.LocalGet(local_idx) =>
      CLValueSource::Local(cl_local_idx_raw(local_idx))
    other =>
      match cl_simple_const_source(other) {
        Some(source) => source
        None => CLValueSource::Unique
      }
  }
}

///|
fn cl_instr_is_terminal(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable
    | @lib.Return
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Throw(_)
    | @lib.ThrowRef => true
    _ => false
  }
}

///|
fn cl_br_table_all_nonlocal(
  labels : Array[@lib.LabelIdx],
  default_label : @lib.LabelIdx,
) -> Bool {
  if cl_label_idx_raw(default_label) <= 0 {
    return false
  }
  for label in labels {
    if cl_label_idx_raw(label) <= 0 {
      return false
    }
  }
  true
}

///|
fn cl_instrs_end_in_nonlocal_escape(instrs : Array[@lib.Instruction]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  cl_instr_escapes_following_sibling(instrs[instrs.length() - 1])
}

///|
fn cl_instrs_end_in_unreachable(instrs : Array[@lib.Instruction]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  match instrs[instrs.length() - 1] {
    @lib.Unreachable => true
    _ => false
  }
}

///|
fn cl_instr_escapes_following_sibling(instr : @lib.Instruction) -> Bool {
  if cl_instr_is_terminal(instr) {
    return true
  }
  match instr {
    @lib.Br(label_idx) => cl_label_idx_raw(label_idx) > 0
    @lib.BrTable(labels, default_label) =>
      cl_br_table_all_nonlocal(labels, default_label)
    @lib.Block(_, @lib.Expr(body)) => cl_instrs_end_in_nonlocal_escape(body)
    @lib.If(_, then_body, Some(else_body)) =>
      cl_instrs_end_in_nonlocal_escape(then_body) &&
      cl_instrs_end_in_nonlocal_escape(else_body)
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      cl_instrs_end_in_nonlocal_escape(body)
    _ => false
  }
}

///|
fn cl_instr_never_falls_through(instr : @lib.Instruction) -> Bool {
  if cl_instr_is_terminal(instr) {
    return true
  }
  match instr {
    @lib.Br(_) | @lib.BrTable(_, _) => true
    @lib.Block(_, @lib.Expr(body)) => cl_instrs_end_in_nonlocal_escape(body)
    @lib.If(_, then_body, Some(else_body)) =>
      cl_instr_escapes_following_sibling(
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new(then_body),
        ),
      ) &&
      cl_instr_escapes_following_sibling(
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new(else_body),
        ),
      )
    @lib.TryTable(_, _, @lib.Expr(body)) =>
      cl_instrs_end_in_nonlocal_escape(body)
    _ => false
  }
}

///|
fn cl_instr_makes_rest_unreachable(instr : @lib.Instruction) -> Bool {
  cl_instr_never_falls_through(instr)
}

///|
fn cl_reachable_prefix_len(instrs : Array[@lib.Instruction]) -> Int {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    if cl_instr_makes_rest_unreachable(instrs[idx]) {
      return idx + 1
    }
  }
  instrs.length()
}

///|
fn cl_dense_coloring_local_limit() -> Int {
  // Dense interference and copy-weight tables are O(locals^2). Keep the
  // current Binaryen-compatible dense coloring path bounded until coalesce-
  // locals has a sparse interference representation for huge functions.
  4096
}

///|
fn cl_instrs_have_structured_control(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        ignore(body)
        return true
      }
      @lib.If(_, _, _) => return true
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) | @lib.Return =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn cl_instrs_have_loop_control(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(_, _) => return true
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if cl_instrs_have_loop_control(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if cl_instrs_have_loop_control(then_body) {
          return true
        }
        match else_body {
          Some(body) => if cl_instrs_have_loop_control(body) { return true }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn cl_mark_syntactic_local_accesses(
  instrs : Array[@lib.Instruction],
  accessed : Array[Bool],
  read : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_mark_syntactic_local_accesses(body, accessed, read)
      @lib.If(_, then_body, else_body) => {
        cl_mark_syntactic_local_accesses(then_body, accessed, read)
        match else_body {
          Some(body) => cl_mark_syntactic_local_accesses(body, accessed, read)
          None => ()
        }
      }
      @lib.LocalGet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < accessed.length() {
          accessed[raw] = true
          read[raw] = true
        }
      }
      @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < accessed.length() {
          accessed[raw] = true
        }
      }
      _ => ()
    }
  }
}

///|
fn cl_count_syntactic_local_accesses(
  instrs : Array[@lib.Instruction],
  gets : Array[Int],
  sets : Array[Int],
  tees : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_count_syntactic_local_accesses(body, gets, sets, tees)
      @lib.If(_, then_body, else_body) => {
        cl_count_syntactic_local_accesses(then_body, gets, sets, tees)
        match else_body {
          Some(body) =>
            cl_count_syntactic_local_accesses(body, gets, sets, tees)
          None => ()
        }
      }
      @lib.LocalGet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < gets.length() {
          gets[raw] += 1
        }
      }
      @lib.LocalSet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < sets.length() {
          sets[raw] += 1
        }
      }
      @lib.LocalTee(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < tees.length() {
          tees[raw] += 1
        }
      }
      _ => ()
    }
  }
}

///|
fn cl_instr_blocks_loop_copy_through(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Block(_, _)
    | @lib.Loop(_, _)
    | @lib.If(_, _, _)
    | @lib.TryTable(_, _, _)
    | @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _) => true
    _ => cl_instr_is_terminal(instr)
  }
}

///|
fn cl_loop_copy_through_dest_after_set(
  instrs : Array[@lib.Instruction],
  set_idx : Int,
  temp : Int,
  types : Array[@lib.ValType],
  param_count : Int,
) -> Int {
  if temp < param_count || temp >= types.length() {
    return -1
  }
  let mut idx = set_idx + 1
  while idx < instrs.length() {
    let instr = instrs[idx]
    match instr {
      @lib.LocalGet(read_idx) if cl_local_idx_raw(read_idx) == temp => {
        if idx + 1 >= instrs.length() {
          return -1
        }
        match instrs[idx + 1] {
          @lib.LocalSet(dest_idx) => {
            let dest = cl_local_idx_raw(dest_idx)
            if dest < 0 ||
              dest >= types.length() ||
              dest == temp ||
              types[temp] != types[dest] {
              return -1
            }
            for between = set_idx + 1; between < idx; between = between + 1 {
              if cl_instr_accesses_local(instrs[between], dest) {
                return -1
              }
            }
            return dest
          }
          _ => return -1
        }
      }
      @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) if cl_local_idx_raw(
          local_idx,
        ) ==
        temp => return -1
      _ => if cl_instr_blocks_loop_copy_through(instr) { return -1 }
    }
    idx += 1
  }
  -1
}

///|
fn cl_mark_loop_adjacent_copy_through_locals(
  instrs : Array[@lib.Instruction],
  passthrough_dest : Array[Int],
  gets : Array[Int],
  sets : Array[Int],
  tees : Array[Int],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_mark_loop_adjacent_copy_through_locals(
          body, passthrough_dest, gets, sets, tees, types, param_count,
        )
      @lib.If(_, then_body, else_body) => {
        cl_mark_loop_adjacent_copy_through_locals(
          then_body, passthrough_dest, gets, sets, tees, types, param_count,
        )
        match else_body {
          Some(body) =>
            cl_mark_loop_adjacent_copy_through_locals(
              body, passthrough_dest, gets, sets, tees, types, param_count,
            )
          None => ()
        }
      }
      _ => ()
    }
  }
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.LocalSet(temp_idx) => {
        let temp = cl_local_idx_raw(temp_idx)
        if temp >= param_count &&
          temp < types.length() &&
          gets[temp] == 1 &&
          sets[temp] == 1 &&
          tees[temp] == 0 {
          let dest = cl_loop_copy_through_dest_after_set(
            instrs, idx, temp, types, param_count,
          )
          if dest >= 0 {
            passthrough_dest[temp] = dest
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn cl_resolve_loop_passthrough_dest(
  local_idx : Int,
  passthrough_dest : Array[Int],
) -> Int {
  let mut current = local_idx
  let mut steps = 0
  while current >= 0 &&
        current < passthrough_dest.length() &&
        passthrough_dest[current] >= 0 &&
        steps < passthrough_dest.length() {
    let next = passthrough_dest[current]
    if next == current {
      return local_idx
    }
    current = next
    steps += 1
  }
  if steps >= passthrough_dest.length() {
    return local_idx
  }
  current
}

///|
fn cl_rewrite_loop_func_unused_locals(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> CLFuncRewrite {
  let @lib.Func(body_locals, body) = func
  let types = cl_all_local_types(params, body_locals)
  let total_locals = types.length()
  let @lib.Expr(original_instrs) = body
  let accessed = Array::make(total_locals, false)
  let read = Array::make(total_locals, false)
  let gets = Array::make(total_locals, 0)
  let sets = Array::make(total_locals, 0)
  let tees = Array::make(total_locals, 0)
  let passthrough_dest = Array::make(total_locals, -1)
  cl_mark_syntactic_local_accesses(original_instrs, accessed, read)
  cl_count_syntactic_local_accesses(original_instrs, gets, sets, tees)
  cl_mark_loop_adjacent_copy_through_locals(
    original_instrs,
    passthrough_dest,
    gets,
    sets,
    tees,
    types,
    params.length(),
  )
  let old_to_new = Array::make(total_locals, -1)
  let slot_types : Array[@lib.ValType] = []
  for idx = 0; idx < params.length(); idx = idx + 1 {
    old_to_new[idx] = idx
    slot_types.push(types[idx])
  }
  let mut changed = false
  for idx = params.length(); idx < total_locals; idx = idx + 1 {
    let ty = types[idx]
    let passthrough = cl_resolve_loop_passthrough_dest(idx, passthrough_dest)
    if passthrough != idx && types[passthrough] == ty {
      continue
    } else if read[idx] {
      let next_idx = slot_types.length()
      old_to_new[idx] = next_idx
      slot_types.push(ty)
      if next_idx != idx {
        changed = true
      }
    } else if accessed[idx] {
      // Loop/backedge liveness is intentionally conservative, but a local that
      // is written and never read from the local slot cannot carry a loop value.
      // Keep those dead writes away from params and read locals, while allowing
      // same-typed dead-write locals to share one scratch slot.
      let mut slot = -1
      for prior = params.length(); prior < idx; prior = prior + 1 {
        if accessed[prior] && !read[prior] && types[prior] == ty {
          slot = old_to_new[prior]
          break
        }
      }
      if slot < 0 {
        slot = slot_types.length()
        slot_types.push(ty)
      }
      old_to_new[idx] = slot
      if slot != idx {
        changed = true
      }
    } else {
      let mut slot = -1
      for candidate = 0
          candidate < slot_types.length()
          candidate = candidate + 1 {
        if slot_types[candidate] == ty {
          slot = candidate
          break
        }
      }
      if slot < 0 {
        slot = slot_types.length()
        slot_types.push(ty)
      }
      old_to_new[idx] = slot
      if slot != idx {
        changed = true
      }
    }
  }
  for idx = params.length(); idx < total_locals; idx = idx + 1 {
    if old_to_new[idx] >= 0 {
      continue
    }
    let passthrough = cl_resolve_loop_passthrough_dest(idx, passthrough_dest)
    if passthrough != idx &&
      types[passthrough] == types[idx] &&
      old_to_new[passthrough] >= 0 {
      // Adjacent `local.set tmp; local.get tmp; local.set dest` copy-through
      // chains do not carry values across loop backedges. Reusing the final
      // destination slot only moves the overwrite earlier by the immediately
      // following `local.get tmp`, and redundant self-copy cleanup removes the
      // resulting no-op pairs.
      old_to_new[idx] = old_to_new[passthrough]
      changed = true
    } else {
      let next_idx = slot_types.length()
      old_to_new[idx] = next_idx
      slot_types.push(types[idx])
      if next_idx != idx {
        changed = true
      }
    }
  }
  let body_slot_types : Array[@lib.ValType] = []
  for slot = params.length(); slot < slot_types.length(); slot = slot + 1 {
    body_slot_types.push(slot_types[slot])
  }
  let rewritten_locals = @lib.Locals::from_types(body_slot_types)
  if !changed && rewritten_locals == body_locals {
    return { func, changed: false }
  }
  let rewritten_instrs = original_instrs.copy()
  cl_rewrite_all_local_idxs_in_place(rewritten_instrs, old_to_new)
  let cleanup_changed = cl_remove_redundant_copy_pairs(rewritten_instrs)
  {
    func: @lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs)),
    changed: changed || cleanup_changed,
  }
}

///|
fn cl_rewrite_all_local_idxs_in_place(
  instrs : Array[@lib.Instruction],
  old_to_new : Array[Int],
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        cl_rewrite_all_local_idxs_in_place(body, old_to_new)
        instrs[idx] = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        cl_rewrite_all_local_idxs_in_place(body, old_to_new)
        instrs[idx] = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        cl_rewrite_all_local_idxs_in_place(then_body, old_to_new)
        match else_body {
          Some(else_instrs) =>
            cl_rewrite_all_local_idxs_in_place(else_instrs, old_to_new)
          None => ()
        }
        instrs[idx] = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        cl_rewrite_all_local_idxs_in_place(body, old_to_new)
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      @lib.LocalGet(local_idx) =>
        instrs[idx] = @lib.Instruction::local_get(
          cl_rewrite_local_idx(local_idx, old_to_new),
        )
      @lib.LocalSet(local_idx) =>
        instrs[idx] = @lib.Instruction::local_set(
          cl_rewrite_local_idx(local_idx, old_to_new),
        )
      @lib.LocalTee(local_idx) =>
        instrs[idx] = @lib.Instruction::local_tee(
          cl_rewrite_local_idx(local_idx, old_to_new),
        )
      _ => ()
    }
  }
}

///|
fn cl_rewrite_func_structured_conservative(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> CLFuncRewrite {
  let @lib.Func(body_locals, body) = func
  let body_local_count = body_locals.length()
  if body_local_count == 0 {
    return { func, changed: false }
  }
  let types = cl_all_local_types(params, body_locals)
  let total_locals = types.length()
  let actions : Array[CLAction] = []
  let @lib.Expr(original_instrs) = body
  cl_collect_instrs(original_instrs, actions, total_locals)
  let liveness = cl_compute_liveness(actions, total_locals)
  // Keep flattened liveness for Binaryen-shaped coloring/profitability, but use
  // branch-aware effective-write facts when rewriting structured cleanup so one
  // arm's live side-carrier write is not dropped by a sibling arm's later write
  // in flattened action order.
  let rewrite_liveness = cl_compute_structured_liveness(
    original_instrs, actions, total_locals,
  )
  let interferences = cl_compute_interferences(
    actions,
    liveness,
    types,
    params.length(),
  )
  cl_add_plain_live_interferences(actions, liveness, interferences)
  let weights = cl_copy_weights(
    actions,
    rewrite_liveness.effective,
    total_locals,
  )
  cl_remove_safe_copy_forward_interferences(
    original_instrs,
    types,
    params.length(),
    interferences,
    weights,
  )
  cl_remove_safe_consume_forward_interferences(
    original_instrs,
    types,
    params.length(),
    interferences,
    weights,
  )
  cl_add_source_write_dest_read_interferences(
    original_instrs,
    actions,
    rewrite_liveness.effective,
    types,
    params.length(),
    interferences,
  )
  cl_remove_tail_reuse_interferences(
    original_instrs,
    actions,
    rewrite_liveness.effective,
    types,
    params.length(),
    interferences,
  )
  cl_remove_path_disjoint_branch_result_interferences(
    original_instrs,
    types,
    params.length(),
    interferences,
  )
  let preferred = cl_preferred_compaction_flags(
    original_instrs, actions, total_locals,
  )
  let structured_scalar_preferred = cl_structured_scalar_compaction_flags(
    original_instrs,
    actions,
    types,
    params.length(),
  )
  let coloring = cl_pick_coloring(
    types,
    params.length(),
    interferences,
    weights,
    preferred,
    structured_scalar_preferred,
  )
  let rewritten_locals = @lib.Locals::from_types(coloring.slot_types)
  let rewritten_instrs = original_instrs.copy()
  cl_rewrite_instrs_in_place(
    rewritten_instrs,
    coloring.old_to_new,
    rewrite_liveness.effective,
    [0],
  )
  let flattened_terminal_blocks = cl_flatten_terminal_unbranched_void_blocks(
    rewritten_instrs,
  )
  let dead_tail_changed = if flattened_terminal_blocks {
    cl_truncate_dead_tails(rewritten_instrs)
  } else {
    false
  }
  let cleanup_changed = cl_remove_redundant_copy_pairs(rewritten_instrs)
  let changed = cleanup_changed ||
    flattened_terminal_blocks ||
    dead_tail_changed ||
    rewritten_instrs != original_instrs ||
    !cl_old_to_new_is_identity(coloring.old_to_new) ||
    rewritten_locals != body_locals
  if !changed {
    return { func, changed: false }
  }
  {
    func: @lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs)),
    changed: true,
  }
}

///|
fn cl_collect_instrs(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  total_locals : Int,
) -> Unit {
  let mut reachable = true
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    if !reachable {
      continue
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        cl_collect_instrs(body, actions, total_locals)
      @lib.If(_, then_body, else_body) => {
        cl_collect_instrs(then_body, actions, total_locals)
        match else_body {
          Some(body) => cl_collect_instrs(body, actions, total_locals)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_collect_instrs(body, actions, total_locals)
      @lib.LocalGet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Get,
            local_idx: raw,
            source: CLValueSource::Unique,
          })
        }
      }
      @lib.LocalSet(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Set,
            local_idx: raw,
            source: cl_value_source_before(instrs, idx),
          })
        }
      }
      @lib.LocalTee(local_idx) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          actions.push({
            kind: CLActionKind::Tee,
            local_idx: raw,
            source: cl_value_source_before(instrs, idx),
          })
        }
      }
      _ => ()
    }
    if cl_instr_makes_rest_unreachable(instr) {
      reachable = false
    }
  }
}

///|
fn cl_compute_liveness(
  actions : Array[CLAction],
  total_locals : Int,
) -> CLLiveness {
  let effective = Array::make(actions.length(), false)
  let live = Array::make(total_locals, false)
  let mut idx = actions.length() - 1
  while idx >= 0 {
    let action = actions[idx]
    match action.kind {
      CLActionKind::Get => live[action.local_idx] = true
      CLActionKind::Set | CLActionKind::Tee => {
        if live[action.local_idx] {
          effective[idx] = true
        }
        live[action.local_idx] = false
      }
    }
    idx -= 1
  }
  { effective, live_at_entry: live }
}

///|
fn cl_union_live(lhs : Array[Bool], rhs : Array[Bool]) -> Array[Bool] {
  let out = lhs.copy()
  for idx = 0; idx < out.length(); idx = idx + 1 {
    out[idx] = out[idx] || rhs[idx]
  }
  out
}

///|
fn cl_replace_live(live : Array[Bool], source : Array[Bool]) -> Unit {
  for idx = 0; idx < live.length(); idx = idx + 1 {
    live[idx] = idx < source.length() && source[idx]
  }
}

///|
fn cl_clear_live(live : Array[Bool]) -> Unit {
  for idx = 0; idx < live.length(); idx = idx + 1 {
    live[idx] = false
  }
}

///|
fn cl_union_live_in_place(live : Array[Bool], rhs : Array[Bool]) -> Unit {
  for idx = 0; idx < live.length(); idx = idx + 1 {
    if idx < rhs.length() {
      live[idx] = live[idx] || rhs[idx]
    }
  }
}

///|
fn cl_push_label_live(
  label_live : Array[Bool],
  label_lives : Array[Array[Bool]],
) -> Array[Array[Bool]] {
  let out : Array[Array[Bool]] = [label_live.copy()]
  for live in label_lives {
    out.push(live)
  }
  out
}

///|
fn cl_live_for_label(
  label_lives : Array[Array[Bool]],
  label_idx : @lib.LabelIdx,
  total_locals : Int,
) -> Array[Bool] {
  let depth = cl_label_idx_raw(label_idx)
  if depth >= 0 && depth < label_lives.length() {
    return label_lives[depth].copy()
  }
  Array::make(total_locals, false)
}

///|
fn cl_live_for_br_table(
  label_lives : Array[Array[Bool]],
  labels : Array[@lib.LabelIdx],
  default_label : @lib.LabelIdx,
  total_locals : Int,
) -> Array[Bool] {
  let out = cl_live_for_label(label_lives, default_label, total_locals)
  for label in labels {
    cl_union_live_in_place(
      out,
      cl_live_for_label(label_lives, label, total_locals),
    )
  }
  out
}

///|
fn cl_mark_structured_liveness_backward(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  live_after : Array[Bool],
  label_lives : Array[Array[Bool]],
  action_cursor : Array[Int],
) -> Array[Bool] {
  let live = live_after.copy()
  let reachable_len = cl_reachable_prefix_len(instrs)
  let mut idx = instrs.length() - 1
  while idx >= 0 {
    if idx >= reachable_len {
      idx -= 1
      continue
    }
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) => {
        let body_live = cl_mark_structured_liveness_backward(
          body,
          actions,
          effective,
          live,
          cl_push_label_live(live, label_lives),
          action_cursor,
        )
        cl_replace_live(live, body_live)
      }
      @lib.If(_, then_body, else_body) => {
        let live_after_if = live.copy()
        let child_label_lives = cl_push_label_live(live_after_if, label_lives)
        let else_live = match else_body {
          Some(body) =>
            cl_mark_structured_liveness_backward(
              body,
              actions,
              effective,
              live_after_if.copy(),
              child_label_lives,
              action_cursor,
            )
          None => live_after_if.copy()
        }
        let then_live = cl_mark_structured_liveness_backward(
          then_body, actions, effective, live_after_if, child_label_lives, action_cursor,
        )
        let merged_live = cl_union_live(then_live, else_live)
        cl_replace_live(live, merged_live)
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        let body_live = cl_mark_structured_liveness_backward(
          body,
          actions,
          effective,
          live,
          cl_push_label_live(live, label_lives),
          action_cursor,
        )
        cl_replace_live(live, body_live)
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        let body_live = cl_mark_structured_liveness_backward(
          body,
          actions,
          effective,
          live,
          cl_push_label_live(live, label_lives),
          action_cursor,
        )
        cl_replace_live(live, body_live)
      }
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) => {
        let action_idx = action_cursor[0]
        if action_idx >= 0 && action_idx < actions.length() {
          let action = actions[action_idx]
          match action.kind {
            CLActionKind::Get => live[action.local_idx] = true
            CLActionKind::Set | CLActionKind::Tee => {
              if live[action.local_idx] {
                effective[action_idx] = true
              }
              live[action.local_idx] = false
            }
          }
        }
        action_cursor[0] -= 1
      }
      @lib.Br(label_idx) =>
        cl_replace_live(
          live,
          cl_live_for_label(label_lives, label_idx, live.length()),
        )
      @lib.BrIf(label_idx) =>
        cl_union_live_in_place(
          live,
          cl_live_for_label(label_lives, label_idx, live.length()),
        )
      @lib.BrTable(labels, default_label) =>
        cl_replace_live(
          live,
          cl_live_for_br_table(
            label_lives,
            labels,
            default_label,
            live.length(),
          ),
        )
      instr => if cl_instr_is_terminal(instr) { cl_clear_live(live) }
    }
    idx -= 1
  }
  live
}

///|
fn cl_compute_structured_liveness(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  total_locals : Int,
) -> CLLiveness {
  let effective = Array::make(actions.length(), false)
  let live_after = Array::make(total_locals, false)
  let live_at_entry = cl_mark_structured_liveness_backward(
    instrs,
    actions,
    effective,
    live_after,
    [],
    [actions.length() - 1],
  )
  { effective, live_at_entry }
}

///|
fn cl_add_interference(
  interferences : Array[Array[Bool]],
  lhs : Int,
  rhs : Int,
) -> Unit {
  if lhs == rhs {
    return
  }
  interferences[lhs][rhs] = true
  interferences[rhs][lhs] = true
}

///|
priv struct CLCopyForwardScan {
  ok : Bool
  pending : Bool
}

///|
fn cl_instr_accesses_local(instr : @lib.Instruction, local_idx : Int) -> Bool {
  match instr {
    @lib.LocalGet(idx) | @lib.LocalSet(idx) | @lib.LocalTee(idx) =>
      cl_local_idx_raw(idx) == local_idx
    _ => false
  }
}

///|
fn cl_copy_forward_scan_failed() -> CLCopyForwardScan {
  { ok: false, pending: false }
}

///|
fn cl_copy_forward_target_reaches_dest(
  instrs : Array[@lib.Instruction],
  source : Int,
  target : Int,
  dest : Int,
  depth : Int,
) -> Bool {
  if target == dest {
    return true
  }
  target != source &&
  depth > 0 &&
  cl_copy_forward_pair_safe_depth(instrs, target, dest, depth - 1)
}

///|
fn cl_scan_copy_forward_instrs(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
  pending : Bool,
  depth : Int,
) -> CLCopyForwardScan {
  let mut has_pending = pending
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    match instr {
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        if has_pending {
          return cl_copy_forward_scan_failed()
        }
        has_pending = true
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == source => {
        if has_pending {
          return cl_copy_forward_scan_failed()
        }
        has_pending = true
      }
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        if !has_pending || idx + 1 >= instrs.length() {
          return cl_copy_forward_scan_failed()
        }
        match instrs[idx + 1] {
          @lib.LocalSet(next_idx) => {
            if !cl_copy_forward_target_reaches_dest(
                instrs,
                source,
                cl_local_idx_raw(next_idx),
                dest,
                depth,
              ) {
              return cl_copy_forward_scan_failed()
            }
            has_pending = false
            idx += 1
          }
          @lib.LocalTee(next_idx) => {
            if !cl_copy_forward_target_reaches_dest(
                instrs,
                source,
                cl_local_idx_raw(next_idx),
                dest,
                depth,
              ) {
              return cl_copy_forward_scan_failed()
            }
            has_pending = false
            idx += 1
          }
          _ => return cl_copy_forward_scan_failed()
        }
      }
      @lib.Block(_, @lib.Expr(body)) => {
        if has_pending {
          return cl_copy_forward_scan_failed()
        }
        let scanned = cl_scan_copy_forward_instrs(
          body, source, dest, false, depth,
        )
        if !scanned.ok || scanned.pending {
          return cl_copy_forward_scan_failed()
        }
      }
      @lib.If(_, then_body, else_body) => {
        if has_pending {
          return cl_copy_forward_scan_failed()
        }
        let then_scanned = cl_scan_copy_forward_instrs(
          then_body, source, dest, false, depth,
        )
        if !then_scanned.ok || then_scanned.pending {
          return cl_copy_forward_scan_failed()
        }
        match else_body {
          Some(body) => {
            let else_scanned = cl_scan_copy_forward_instrs(
              body, source, dest, false, depth,
            )
            if !else_scanned.ok || else_scanned.pending {
              return cl_copy_forward_scan_failed()
            }
          }
          None => ()
        }
      }
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) | @lib.Return =>
        return cl_copy_forward_scan_failed()
      @lib.Loop(_, _) | @lib.TryTable(_, _, _) =>
        return cl_copy_forward_scan_failed()
      _ =>
        if has_pending && cl_instr_accesses_local(instr, dest) {
          return cl_copy_forward_scan_failed()
        }
    }
    idx += 1
  }
  { ok: true, pending: has_pending }
}

///|
fn cl_copy_forward_pair_safe_depth(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
  depth : Int,
) -> Bool {
  let scanned = cl_scan_copy_forward_instrs(instrs, source, dest, false, depth)
  scanned.ok && !scanned.pending
}

///|
fn cl_copy_forward_pair_safe(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
) -> Bool {
  cl_copy_forward_pair_safe_depth(instrs, source, dest, 4)
}

///|
fn cl_copy_weight_reaches(
  weights : Array[Array[Int]],
  source : Int,
  dest : Int,
  depth : Int,
) -> Bool {
  if weights[source][dest] > 0 {
    return true
  }
  if depth <= 0 {
    return false
  }
  for mid = 0; mid < weights.length(); mid = mid + 1 {
    if mid != source &&
      mid != dest &&
      weights[source][mid] > 0 &&
      cl_copy_weight_reaches(weights, mid, dest, depth - 1) {
      return true
    }
  }
  false
}

///|
fn cl_remove_safe_copy_forward_interferences(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
  weights : Array[Array[Int]],
) -> Unit {
  for source = param_count; source < types.length(); source = source + 1 {
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if source != dest &&
        types[source] == types[dest] &&
        cl_copy_weight_reaches(weights, source, dest, 4) &&
        cl_copy_forward_pair_safe(instrs, source, dest) {
        interferences[source][dest] = false
        interferences[dest][source] = false
      }
    }
  }
}

///|
priv struct CLConsumeForwardScan {
  ok : Bool
  saw : Bool
  clobbered : Bool
  initialized : Bool
  source_written : Bool
}

///|
fn cl_consume_forward_scan_failed() -> CLConsumeForwardScan {
  {
    ok: false,
    saw: false,
    clobbered: false,
    initialized: false,
    source_written: false,
  }
}

///|
fn cl_scan_consume_forward_instrs(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
  seen_source : Bool,
  clobbered : Bool,
  initialized : Bool,
  source_written : Bool,
) -> CLConsumeForwardScan {
  let mut seen = seen_source
  let mut may_be_clobbered = clobbered
  let mut has_source_value = initialized
  let mut source_may_have_clobbered_dest = source_written
  let mut saw = false
  for instr in instrs {
    match instr {
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        if may_be_clobbered {
          return cl_consume_forward_scan_failed()
        }
        if has_source_value {
          seen = true
        }
      }
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == dest =>
        if source_may_have_clobbered_dest {
          return cl_consume_forward_scan_failed()
        }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        if seen {
          saw = true
          may_be_clobbered = true
          seen = false
        }
        source_may_have_clobbered_dest = false
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        if seen {
          saw = true
          may_be_clobbered = true
          seen = false
        }
        source_may_have_clobbered_dest = false
      }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        may_be_clobbered = false
        has_source_value = true
        source_may_have_clobbered_dest = true
        seen = false
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == source => {
        may_be_clobbered = false
        has_source_value = true
        source_may_have_clobbered_dest = true
        seen = false
      }
      @lib.Block(_, @lib.Expr(body)) => {
        let scanned = cl_scan_consume_forward_instrs(
          body, source, dest, false, may_be_clobbered, has_source_value, source_may_have_clobbered_dest,
        )
        if !scanned.ok {
          return cl_consume_forward_scan_failed()
        }
        if scanned.saw {
          saw = true
        }
        may_be_clobbered = scanned.clobbered
        has_source_value = scanned.initialized
        source_may_have_clobbered_dest = scanned.source_written
        seen = false
      }
      @lib.If(_, then_body, else_body) => {
        let then_scanned = cl_scan_consume_forward_instrs(
          then_body, source, dest, false, may_be_clobbered, has_source_value, source_may_have_clobbered_dest,
        )
        if !then_scanned.ok {
          return cl_consume_forward_scan_failed()
        }
        let mut else_clobbered = may_be_clobbered
        let mut else_initialized = has_source_value
        let mut else_source_written = source_may_have_clobbered_dest
        let mut else_saw = false
        match else_body {
          Some(body) => {
            let else_scanned = cl_scan_consume_forward_instrs(
              body, source, dest, false, may_be_clobbered, has_source_value, source_may_have_clobbered_dest,
            )
            if !else_scanned.ok {
              return cl_consume_forward_scan_failed()
            }
            else_clobbered = else_scanned.clobbered
            else_initialized = else_scanned.initialized
            else_source_written = else_scanned.source_written
            else_saw = else_scanned.saw
          }
          None => ()
        }
        if then_scanned.saw || else_saw {
          saw = true
        }
        may_be_clobbered = then_scanned.clobbered || else_clobbered
        has_source_value = then_scanned.initialized && else_initialized
        source_may_have_clobbered_dest = then_scanned.source_written ||
          else_source_written
        seen = false
      }
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) | @lib.Return =>
        return cl_consume_forward_scan_failed()
      @lib.Loop(_, _) | @lib.TryTable(_, _, _) =>
        return cl_consume_forward_scan_failed()
      _ => ()
    }
  }
  ignore(seen)
  {
    ok: true,
    saw,
    clobbered: may_be_clobbered,
    initialized: has_source_value,
    source_written: source_may_have_clobbered_dest,
  }
}

///|
fn cl_consume_forward_pair_safe(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
) -> Bool {
  let scanned = cl_scan_consume_forward_instrs(
    instrs, source, dest, false, false, false, false,
  )
  scanned.ok && scanned.saw
}

///|
priv struct CLSourceWriteDestReadScan {
  hazard : Bool
  source_written : Bool
}

///|
fn cl_source_write_is_dest_copy(
  instrs : Array[@lib.Instruction],
  idx : Int,
  dest : Int,
) -> Bool {
  if idx <= 0 {
    return false
  }
  match instrs[idx - 1] {
    @lib.LocalGet(local_idx) => cl_local_idx_raw(local_idx) == dest
    _ => false
  }
}

///|
fn cl_action_is_effective(effective : Array[Bool], action_idx : Int) -> Bool {
  action_idx >= 0 && action_idx < effective.length() && effective[action_idx]
}

///|
fn cl_scan_source_write_dest_read_instrs(
  instrs : Array[@lib.Instruction],
  effective : Array[Bool],
  source : Int,
  dest : Int,
  source_written : Bool,
  action_cursor : Array[Int],
) -> CLSourceWriteDestReadScan {
  let mut may_have_clobbered_dest = source_written
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    match instr {
      @lib.LocalGet(local_idx) => {
        action_cursor[0] += 1
        if cl_local_idx_raw(local_idx) == dest && may_have_clobbered_dest {
          return { hazard: true, source_written: may_have_clobbered_dest }
        }
      }
      @lib.LocalSet(local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        let raw = cl_local_idx_raw(local_idx)
        if raw == dest {
          if cl_action_is_effective(effective, action_idx) {
            may_have_clobbered_dest = false
          }
        } else if raw == source && cl_action_is_effective(effective, action_idx) {
          may_have_clobbered_dest = !cl_source_write_is_dest_copy(
            instrs, idx, dest,
          )
        }
      }
      @lib.LocalTee(local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        let raw = cl_local_idx_raw(local_idx)
        if raw == dest {
          if cl_action_is_effective(effective, action_idx) {
            may_have_clobbered_dest = false
          }
        } else if raw == source && cl_action_is_effective(effective, action_idx) {
          may_have_clobbered_dest = !cl_source_write_is_dest_copy(
            instrs, idx, dest,
          )
        }
      }
      @lib.Block(_, @lib.Expr(body)) => {
        let scanned = cl_scan_source_write_dest_read_instrs(
          body, effective, source, dest, may_have_clobbered_dest, action_cursor,
        )
        if scanned.hazard {
          return scanned
        }
        may_have_clobbered_dest = scanned.source_written
      }
      @lib.If(_, then_body, else_body) => {
        let then_scanned = cl_scan_source_write_dest_read_instrs(
          then_body, effective, source, dest, may_have_clobbered_dest, action_cursor,
        )
        if then_scanned.hazard {
          return then_scanned
        }
        let mut else_written = may_have_clobbered_dest
        match else_body {
          Some(body) => {
            let else_scanned = cl_scan_source_write_dest_read_instrs(
              body, effective, source, dest, may_have_clobbered_dest, action_cursor,
            )
            if else_scanned.hazard {
              return else_scanned
            }
            else_written = else_scanned.source_written
          }
          None => ()
        }
        may_have_clobbered_dest = then_scanned.source_written || else_written
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        cl_skip_source_write_dest_read_actions(body, effective, action_cursor)
        if may_have_clobbered_dest {
          return { hazard: true, source_written: may_have_clobbered_dest }
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        cl_skip_source_write_dest_read_actions(body, effective, action_cursor)
        if may_have_clobbered_dest {
          return { hazard: true, source_written: may_have_clobbered_dest }
        }
      }
      @lib.BrIf(_) | @lib.BrTable(_, _) =>
        if may_have_clobbered_dest {
          return { hazard: true, source_written: may_have_clobbered_dest }
        }
      @lib.Br(_) | @lib.Return => may_have_clobbered_dest = false
      _ => ()
    }
  }
  { hazard: false, source_written: may_have_clobbered_dest }
}

///|
fn cl_skip_source_write_dest_read_actions(
  instrs : Array[@lib.Instruction],
  effective : Array[Bool],
  action_cursor : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) =>
        action_cursor[0] += 1
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_skip_source_write_dest_read_actions(body, effective, action_cursor)
      @lib.If(_, then_body, else_body) => {
        cl_skip_source_write_dest_read_actions(
          then_body, effective, action_cursor,
        )
        match else_body {
          Some(body) =>
            cl_skip_source_write_dest_read_actions(
              body, effective, action_cursor,
            )
          None => ()
        }
      }
      _ => ()
    }
  }
  ignore(effective)
}

///|
fn cl_has_source_write_dest_read_hazard(
  instrs : Array[@lib.Instruction],
  effective : Array[Bool],
  source : Int,
  dest : Int,
) -> Bool {
  cl_scan_source_write_dest_read_instrs(
    instrs,
    effective,
    source,
    dest,
    false,
    [0],
  ).hazard
}

///|
fn cl_add_source_write_dest_read_interferences(
  instrs : Array[@lib.Instruction],
  _actions : Array[CLAction],
  effective : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
) -> Unit {
  for source = param_count; source < types.length(); source = source + 1 {
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if source != dest &&
        types[source] == types[dest] &&
        cl_has_source_write_dest_read_hazard(instrs, effective, source, dest) {
        cl_add_interference(interferences, source, dest)
      }
    }
  }
  ignore(_actions)
}

///|
fn cl_collect_action_depths(
  instrs : Array[@lib.Instruction],
  depths : Array[Int],
  depth : Int,
) -> Unit {
  let mut reachable = true
  for instr in instrs {
    if !reachable {
      continue
    }
    match instr {
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) =>
        depths.push(depth)
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_collect_action_depths(body, depths, depth + 1)
      @lib.If(_, then_body, else_body) => {
        cl_collect_action_depths(then_body, depths, depth + 1)
        match else_body {
          Some(body) => cl_collect_action_depths(body, depths, depth + 1)
          None => ()
        }
      }
      _ => ()
    }
    if cl_instr_makes_rest_unreachable(instr) {
      reachable = false
    }
  }
}

///|
fn cl_tail_reuse_pair_safe(
  actions : Array[CLAction],
  effective : Array[Bool],
  depths : Array[Int],
  source : Int,
  dest : Int,
) -> Bool {
  let mut last_dest_get = -1
  let mut first_effective_source_write = -1
  for idx = 0; idx < actions.length(); idx = idx + 1 {
    let action = actions[idx]
    if action.local_idx == dest {
      match action.kind {
        CLActionKind::Get => last_dest_get = idx
        _ => ()
      }
    }
    if action.local_idx == source && cl_action_is_effective(effective, idx) {
      match action.kind {
        CLActionKind::Set | CLActionKind::Tee =>
          if first_effective_source_write < 0 {
            first_effective_source_write = idx
          }
        _ => ()
      }
    }
  }
  if last_dest_get < 0 || first_effective_source_write <= last_dest_get {
    return false
  }
  let mut saw_source_read_after_write = false
  for idx = 0; idx < actions.length(); idx = idx + 1 {
    let action = actions[idx]
    if action.local_idx == source {
      match action.kind {
        CLActionKind::Get => {
          if idx < first_effective_source_write {
            return false
          }
          if idx > first_effective_source_write {
            saw_source_read_after_write = true
            if idx >= depths.length() || depths[idx] != 0 {
              return false
            }
          }
        }
        CLActionKind::Set | CLActionKind::Tee =>
          if cl_action_is_effective(effective, idx) {
            if idx < first_effective_source_write {
              return false
            }
            if idx >= depths.length() || depths[idx] != 0 {
              return false
            }
          }
      }
    }
  }
  saw_source_read_after_write
}

///|
fn cl_remove_tail_reuse_interferences(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
) -> Unit {
  let depths : Array[Int] = []
  cl_collect_action_depths(instrs, depths, 0)
  for source = param_count; source < types.length(); source = source + 1 {
    for dest = 0; dest < param_count; dest = dest + 1 {
      if source != dest &&
        types[source] == types[dest] &&
        cl_tail_reuse_pair_safe(actions, effective, depths, source, dest) {
        interferences[source][dest] = false
        interferences[dest][source] = false
      }
    }
  }
}

///|
priv struct CLPathDisjointScan {
  ok : Bool
  saw_source_write : Bool
  source_initialized : Bool
  source_clobbers_dest : Bool
  dest_clobbers_source : Bool
}

///|
fn cl_path_disjoint_scan_failed() -> CLPathDisjointScan {
  {
    ok: false,
    saw_source_write: false,
    source_initialized: false,
    source_clobbers_dest: false,
    dest_clobbers_source: false,
  }
}

///|
fn cl_dest_write_is_source_copy(
  instrs : Array[@lib.Instruction],
  idx : Int,
  source : Int,
) -> Bool {
  if idx <= 0 {
    return false
  }
  match instrs[idx - 1] {
    @lib.LocalGet(local_idx) => cl_local_idx_raw(local_idx) == source
    _ => false
  }
}

///|
fn cl_scan_path_disjoint_branch_result_instrs(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
  source_initialized : Bool,
  source_clobbers_dest : Bool,
  dest_clobbers_source : Bool,
) -> CLPathDisjointScan {
  let mut has_source_value = source_initialized
  let mut source_may_clobber_dest = source_clobbers_dest
  let mut dest_may_clobber_source = dest_clobbers_source
  let mut saw_source_write = false
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    match instr {
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == source =>
        if !has_source_value || dest_may_clobber_source {
          return cl_path_disjoint_scan_failed()
        }
      @lib.LocalGet(local_idx) if cl_local_idx_raw(local_idx) == dest =>
        if source_may_clobber_dest {
          return cl_path_disjoint_scan_failed()
        }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == source => {
        has_source_value = true
        saw_source_write = true
        source_may_clobber_dest = !cl_source_write_is_dest_copy(
          instrs, idx, dest,
        )
        dest_may_clobber_source = false
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == source => {
        has_source_value = true
        saw_source_write = true
        source_may_clobber_dest = !cl_source_write_is_dest_copy(
          instrs, idx, dest,
        )
        dest_may_clobber_source = false
      }
      @lib.LocalSet(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        source_may_clobber_dest = false
        dest_may_clobber_source = has_source_value &&
          !cl_dest_write_is_source_copy(instrs, idx, source)
      }
      @lib.LocalTee(local_idx) if cl_local_idx_raw(local_idx) == dest => {
        source_may_clobber_dest = false
        dest_may_clobber_source = has_source_value &&
          !cl_dest_write_is_source_copy(instrs, idx, source)
      }
      @lib.Block(_, @lib.Expr(body)) => {
        let scanned = cl_scan_path_disjoint_branch_result_instrs(
          body, source, dest, has_source_value, source_may_clobber_dest, dest_may_clobber_source,
        )
        if !scanned.ok {
          return cl_path_disjoint_scan_failed()
        }
        if scanned.saw_source_write {
          saw_source_write = true
        }
        has_source_value = scanned.source_initialized
        source_may_clobber_dest = scanned.source_clobbers_dest
        dest_may_clobber_source = scanned.dest_clobbers_source
      }
      @lib.If(_, then_body, else_body) => {
        let then_scanned = cl_scan_path_disjoint_branch_result_instrs(
          then_body, source, dest, has_source_value, source_may_clobber_dest, dest_may_clobber_source,
        )
        if !then_scanned.ok {
          return cl_path_disjoint_scan_failed()
        }
        let mut else_scanned : CLPathDisjointScan = {
          ok: true,
          saw_source_write: false,
          source_initialized: has_source_value,
          source_clobbers_dest: source_may_clobber_dest,
          dest_clobbers_source: dest_may_clobber_source,
        }
        match else_body {
          Some(body) => {
            else_scanned = cl_scan_path_disjoint_branch_result_instrs(
              body, source, dest, has_source_value, source_may_clobber_dest, dest_may_clobber_source,
            )
            if !else_scanned.ok {
              return cl_path_disjoint_scan_failed()
            }
          }
          None => ()
        }
        saw_source_write = saw_source_write ||
          then_scanned.saw_source_write ||
          else_scanned.saw_source_write
        has_source_value = then_scanned.source_initialized &&
          else_scanned.source_initialized
        source_may_clobber_dest = then_scanned.source_clobbers_dest ||
          else_scanned.source_clobbers_dest
        dest_may_clobber_source = then_scanned.dest_clobbers_source ||
          else_scanned.dest_clobbers_source
      }
      @lib.Br(_) | @lib.BrIf(_) | @lib.BrTable(_, _) | @lib.Return =>
        return cl_path_disjoint_scan_failed()
      @lib.Loop(_, _) | @lib.TryTable(_, _, _) =>
        return cl_path_disjoint_scan_failed()
      _ => ()
    }
  }
  {
    ok: true,
    saw_source_write,
    source_initialized: has_source_value,
    source_clobbers_dest: source_may_clobber_dest,
    dest_clobbers_source: dest_may_clobber_source,
  }
}

///|
fn cl_path_disjoint_branch_result_pair_safe(
  instrs : Array[@lib.Instruction],
  source : Int,
  dest : Int,
) -> Bool {
  let scanned = cl_scan_path_disjoint_branch_result_instrs(
    instrs, source, dest, false, false, false,
  )
  scanned.ok && scanned.saw_source_write
}

///|
fn cl_remove_path_disjoint_branch_result_interferences(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
) -> Unit {
  for source = param_count; source < types.length(); source = source + 1 {
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if source != dest &&
        types[source] == types[dest] &&
        cl_path_disjoint_branch_result_pair_safe(instrs, source, dest) {
        interferences[source][dest] = false
        interferences[dest][source] = false
      }
    }
  }
}

///|
fn cl_remove_safe_consume_forward_interferences(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
  weights : Array[Array[Int]],
) -> Unit {
  for source = param_count; source < types.length(); source = source + 1 {
    for dest = 0; dest < types.length(); dest = dest + 1 {
      if source != dest &&
        types[source] == types[dest] &&
        cl_consume_forward_pair_safe(instrs, source, dest) {
        interferences[source][dest] = false
        interferences[dest][source] = false
        for target = 0; target < types.length(); target = target + 1 {
          if source != target &&
            types[source] == types[target] &&
            cl_copy_weight_reaches(weights, dest, target, 4) {
            interferences[source][target] = false
            interferences[target][source] = false
          }
        }
      }
    }
  }
}

///|
fn cl_initial_value(
  interner : CLValueInterner,
  idx : Int,
  param_count : Int,
  ty : @lib.ValType,
) -> Int {
  if idx < param_count {
    interner.fresh()
  } else if @lib.has_default(ty) {
    interner.intern("default:\{@debug.to_string(ty)}")
  } else {
    interner.fresh()
  }
}

///|
fn cl_value_for_source(
  source : CLValueSource,
  current_values : Array[Int],
  interner : CLValueInterner,
) -> Int {
  match source {
    CLValueSource::Unique => interner.fresh()
    CLValueSource::Const(key) => interner.intern("const:\{key}")
    CLValueSource::Local(src_local) =>
      if src_local >= 0 && src_local < current_values.length() {
        current_values[src_local]
      } else {
        interner.fresh()
      }
  }
}

///|
fn cl_compute_interferences(
  actions : Array[CLAction],
  liveness : CLLiveness,
  types : Array[@lib.ValType],
  param_count : Int,
) -> Array[Array[Bool]] {
  let total_locals = types.length()
  let interferences : Array[Array[Bool]] = Array::new(capacity=total_locals)
  for _idx = 0; _idx < total_locals; _idx = _idx + 1 {
    interferences.push(Array::make(total_locals, false))
  }
  let interner = CLValueInterner::new()
  let current_values = Array::make(total_locals, -1)
  for idx = 0; idx < total_locals; idx = idx + 1 {
    current_values[idx] = cl_initial_value(
      interner,
      idx,
      param_count,
      types[idx],
    )
  }

  for lhs = 0; lhs < param_count; lhs = lhs + 1 {
    for rhs = lhs + 1; rhs < param_count; rhs = rhs + 1 {
      cl_add_interference(interferences, lhs, rhs)
    }
  }
  for local_idx = param_count
      local_idx < total_locals
      local_idx = local_idx + 1 {
    if liveness.live_at_entry[local_idx] {
      for param = 0; param < param_count; param = param + 1 {
        cl_add_interference(interferences, local_idx, param)
      }
      for other = param_count; other < local_idx; other = other + 1 {
        if liveness.live_at_entry[other] &&
          current_values[local_idx] != current_values[other] {
          cl_add_interference(interferences, local_idx, other)
        }
      }
    }
  }

  let remaining_gets = Array::make(total_locals, 0)
  for action in actions {
    match action.kind {
      CLActionKind::Get => remaining_gets[action.local_idx] += 1
      _ => ()
    }
  }
  let live = liveness.live_at_entry.copy()
  let mut live_count = 0
  for is_live in live {
    if is_live {
      live_count += 1
    }
  }
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => {
        if !live[action.local_idx] {
          live[action.local_idx] = true
          live_count += 1
        }
        if live_count > 1 {
          for other = 0; other < total_locals; other = other + 1 {
            if other != action.local_idx &&
              live[other] &&
              current_values[other] != current_values[action.local_idx] {
              cl_add_interference(interferences, action.local_idx, other)
            }
          }
        }
        remaining_gets[action.local_idx] -= 1
        if remaining_gets[action.local_idx] == 0 && live[action.local_idx] {
          live[action.local_idx] = false
          live_count -= 1
        }
      }
      CLActionKind::Set | CLActionKind::Tee => {
        let new_value = cl_value_for_source(
          action.source,
          current_values,
          interner,
        )
        if liveness.effective[action_idx] {
          if live_count > 0 {
            for other = 0; other < total_locals; other = other + 1 {
              if other != action.local_idx &&
                live[other] &&
                current_values[other] != new_value {
                cl_add_interference(interferences, action.local_idx, other)
              }
            }
          }
          if !live[action.local_idx] {
            live_count += 1
          }
          live[action.local_idx] = true
        } else {
          if live[action.local_idx] {
            live_count -= 1
          }
          live[action.local_idx] = false
        }
        current_values[action.local_idx] = new_value
      }
    }
  }
  interferences
}

///|
fn cl_add_plain_live_interferences(
  actions : Array[CLAction],
  liveness : CLLiveness,
  interferences : Array[Array[Bool]],
) -> Unit {
  let total_locals = interferences.length()
  let remaining_gets = Array::make(total_locals, 0)
  for action in actions {
    match action.kind {
      CLActionKind::Get => remaining_gets[action.local_idx] += 1
      _ => ()
    }
  }
  let live = liveness.live_at_entry.copy()
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    let action = actions[action_idx]
    match action.kind {
      CLActionKind::Get => {
        live[action.local_idx] = true
        for other = 0; other < total_locals; other = other + 1 {
          if other != action.local_idx && live[other] {
            cl_add_interference(interferences, action.local_idx, other)
          }
        }
        remaining_gets[action.local_idx] -= 1
        if remaining_gets[action.local_idx] == 0 {
          live[action.local_idx] = false
        }
      }
      CLActionKind::Set | CLActionKind::Tee => {
        for other = 0; other < total_locals; other = other + 1 {
          if other != action.local_idx && live[other] {
            cl_add_interference(interferences, action.local_idx, other)
          }
        }
        if liveness.effective[action_idx] {
          live[action.local_idx] = true
        } else {
          live[action.local_idx] = false
        }
      }
    }
  }
}

///|
fn cl_copy_weights(
  actions : Array[CLAction],
  effective : Array[Bool],
  total_locals : Int,
) -> Array[Array[Int]] {
  let weights : Array[Array[Int]] = Array::new(capacity=total_locals)
  for _idx = 0; _idx < total_locals; _idx = _idx + 1 {
    weights.push(Array::make(total_locals, 0))
  }
  for action_idx = 0; action_idx < actions.length(); action_idx = action_idx + 1 {
    if !effective[action_idx] {
      continue
    }
    let action = actions[action_idx]
    match action.source {
      CLValueSource::Local(src) =>
        if src >= 0 && src < total_locals && src != action.local_idx {
          weights[action.local_idx][src] += 1
          weights[src][action.local_idx] += 1
        }
      _ => ()
    }
  }
  weights
}

///|
fn cl_slot_interferes(
  members : Array[Int],
  local_idx : Int,
  interferences : Array[Array[Bool]],
) -> Bool {
  for slot_member in members {
    if interferences[local_idx][slot_member] {
      return true
    }
  }
  false
}

///|
fn cl_slot_copy_score(
  members : Array[Int],
  local_idx : Int,
  weights : Array[Array[Int]],
) -> Int {
  let mut score = 0
  for slot_member in members {
    score += weights[local_idx][slot_member]
  }
  score
}

///|
fn cl_color_with_order(
  order : Array[Int],
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
  weights : Array[Array[Int]],
) -> CLColoring {
  let total_locals = types.length()
  let old_to_new = Array::make(total_locals, -1)
  for idx = 0; idx < param_count; idx = idx + 1 {
    old_to_new[idx] = idx
  }
  let slot_types : Array[@lib.ValType] = []
  let slot_members : Array[Array[Int]] = []
  for idx = 0; idx < param_count; idx = idx + 1 {
    slot_types.push(types[idx])
    slot_members.push([idx])
  }
  for local_idx in order {
    let ty = types[local_idx]
    let mut best_slot = -1
    let mut best_score = -1
    for slot = 0; slot < slot_types.length(); slot = slot + 1 {
      if slot_types[slot] == ty &&
        !cl_slot_interferes(slot_members[slot], local_idx, interferences) {
        let score = cl_slot_copy_score(slot_members[slot], local_idx, weights)
        if score > best_score {
          best_score = score
          best_slot = slot
        }
      }
    }
    if best_slot < 0 {
      best_slot = slot_types.length()
      slot_types.push(ty)
      slot_members.push([])
    }
    old_to_new[local_idx] = best_slot
    slot_members[best_slot].push(local_idx)
  }

  let body_slot_types : Array[@lib.ValType] = []
  for slot = param_count; slot < slot_types.length(); slot = slot + 1 {
    body_slot_types.push(slot_types[slot])
  }

  let mut removed_copies = 0
  for lhs = 0; lhs < total_locals; lhs = lhs + 1 {
    for rhs = lhs + 1; rhs < total_locals; rhs = rhs + 1 {
      if old_to_new[lhs] == old_to_new[rhs] {
        removed_copies += weights[lhs][rhs]
      }
    }
  }
  { old_to_new, slot_types: body_slot_types, removed_copies }
}

///|
fn cl_accessed_compaction_type_eligible(ty : @lib.ValType) -> Bool {
  match ty {
    @lib.RefTypeValType(@lib.HeapTypeRefType(_, _, @lib.HeapType(_))) => true
    _ => false
  }
}

///|
fn cl_coloring_accessed_slot_score(
  coloring : CLColoring,
  preferred : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Int {
  let mut score = 0
  for idx = param_count; idx < preferred.length(); idx = idx + 1 {
    if preferred[idx] && cl_accessed_compaction_type_eligible(types[idx]) {
      score += coloring.old_to_new[idx]
    }
  }
  score
}

///|
fn cl_coloring_is_better(
  candidate : CLColoring,
  best : CLColoring,
  preferred : Array[Bool],
  structured_scalar_preferred : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Bool {
  if candidate.removed_copies != best.removed_copies {
    return candidate.removed_copies > best.removed_copies
  }
  if candidate.slot_types.length() != best.slot_types.length() {
    return candidate.slot_types.length() < best.slot_types.length()
  }
  let candidate_accessed = cl_coloring_accessed_slot_score(
    candidate, preferred, types, param_count,
  )
  let best_accessed = cl_coloring_accessed_slot_score(
    best, preferred, types, param_count,
  )
  if candidate_accessed != best_accessed {
    return candidate_accessed < best_accessed
  }
  cl_coloring_structured_scalar_slot_score(
    candidate, structured_scalar_preferred, param_count,
  ) <
  cl_coloring_structured_scalar_slot_score(
    best, structured_scalar_preferred, param_count,
  )
}

///|
fn cl_local_copy_degree(weights : Array[Array[Int]], local_idx : Int) -> Int {
  let mut degree = 0
  for other = 0; other < weights.length(); other = other + 1 {
    degree += weights[local_idx][other]
  }
  degree
}

///|
fn cl_push_copy_weighted_order_segment(
  out : Array[Int],
  weights : Array[Array[Int]],
  param_count : Int,
  copy_connected : Bool,
  reverse : Bool,
) -> Unit {
  if reverse {
    let mut idx = weights.length() - 1
    while idx >= param_count {
      if (cl_local_copy_degree(weights, idx) > 0) == copy_connected {
        out.push(idx)
      }
      idx -= 1
    }
  } else {
    for idx = param_count; idx < weights.length(); idx = idx + 1 {
      if (cl_local_copy_degree(weights, idx) > 0) == copy_connected {
        out.push(idx)
      }
    }
  }
}

///|
fn cl_copy_weighted_order(
  weights : Array[Array[Int]],
  param_count : Int,
  reverse : Bool,
) -> Array[Int] {
  let out : Array[Int] = []
  // Copy-connected locals are the main coalesce-locals profitability surface.
  // Let them claim compatible slots before unrelated scratch locals; otherwise
  // an unrelated post-branch local can occupy a branch-carrier source slot and
  // leave a size-losing cross-local copy that Binaryen removes.
  cl_push_copy_weighted_order_segment(out, weights, param_count, true, reverse)
  cl_push_copy_weighted_order_segment(out, weights, param_count, false, reverse)
  out
}

///|
fn cl_preferred_compaction_order(
  preferred : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  // Binaryen lets accessed concrete GC-ref locals claim the earliest body slots
  // even when unrelated unused ref/scalar locals appear before or after them.
  // Keep this order candidate narrow: the preferred flags already require a
  // direct struct.get use and multiple sets, and copy-count/slot-count scoring
  // must still tie before this order can win.
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    if preferred[idx] && cl_accessed_compaction_type_eligible(types[idx]) {
      out.push(idx)
    }
  }
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    if !preferred[idx] && cl_accessed_compaction_type_eligible(types[idx]) {
      out.push(idx)
    }
  }
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    if !cl_accessed_compaction_type_eligible(types[idx]) {
      out.push(idx)
    }
  }
  out
}

///|
fn cl_structured_scalar_compaction_order(
  preferred : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    if preferred[idx] {
      out.push(idx)
    }
  }
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    if !preferred[idx] {
      out.push(idx)
    }
  }
  out
}

///|
fn cl_preferred_compaction_flags(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  total_locals : Int,
) -> Array[Bool] {
  let preferred = Array::make(total_locals, false)
  for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
    match (instrs[idx], instrs[idx + 1]) {
      (@lib.LocalGet(local_idx), @lib.StructGet(_, _)) => {
        let raw = cl_local_idx_raw(local_idx)
        if raw >= 0 && raw < total_locals {
          preferred[raw] = true
        }
      }
      _ => ()
    }
  }
  let sets = cl_local_set_counts(actions, total_locals)
  for idx = 0; idx < total_locals; idx = idx + 1 {
    preferred[idx] = preferred[idx] && sets[idx] > 1
  }
  preferred
}

///|
fn cl_local_set_counts(
  actions : Array[CLAction],
  total_locals : Int,
) -> Array[Int] {
  let sets = Array::make(total_locals, 0)
  for action in actions {
    if action.local_idx >= 0 && action.local_idx < total_locals {
      match action.kind {
        CLActionKind::Set => sets[action.local_idx] += 1
        _ => ()
      }
    }
  }
  sets
}

///|
fn cl_local_write_counts(
  actions : Array[CLAction],
  total_locals : Int,
) -> Array[Int] {
  let writes = Array::make(total_locals, 0)
  for action in actions {
    if action.local_idx >= 0 && action.local_idx < total_locals {
      match action.kind {
        CLActionKind::Set | CLActionKind::Tee => writes[action.local_idx] += 1
        _ => ()
      }
    }
  }
  writes
}

///|
fn cl_structured_scalar_compaction_flags(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Array[Bool] {
  let preferred = Array::make(types.length(), false)
  cl_mark_structured_scalar_conditions(instrs, preferred, types, param_count)
  let writes = cl_local_write_counts(actions, types.length())
  for idx = 0; idx < types.length(); idx = idx + 1 {
    preferred[idx] = preferred[idx] && writes[idx] > 1
  }
  preferred
}

///|
fn cl_type_is_i32(ty : @lib.ValType) -> Bool {
  ty == @lib.ValType::i32()
}

///|
fn cl_mark_structured_scalar_conditions(
  instrs : Array[@lib.Instruction],
  preferred : Array[Bool],
  types : Array[@lib.ValType],
  param_count : Int,
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    if idx + 1 < instrs.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.LocalGet(local_idx), @lib.If(_, _, _))
        | (@lib.LocalGet(local_idx), @lib.BrIf(_)) => {
          let raw = cl_local_idx_raw(local_idx)
          if raw >= param_count &&
            raw < types.length() &&
            cl_type_is_i32(types[raw]) {
            preferred[raw] = true
          }
        }
        _ => ()
      }
    }
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        cl_mark_structured_scalar_conditions(
          body, preferred, types, param_count,
        )
      @lib.If(_, then_body, else_body) => {
        cl_mark_structured_scalar_conditions(
          then_body, preferred, types, param_count,
        )
        match else_body {
          Some(body) =>
            cl_mark_structured_scalar_conditions(
              body, preferred, types, param_count,
            )
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        cl_mark_structured_scalar_conditions(
          body, preferred, types, param_count,
        )
      _ => ()
    }
  }
}

///|
fn cl_coloring_structured_scalar_slot_score(
  coloring : CLColoring,
  preferred : Array[Bool],
  param_count : Int,
) -> Int {
  let mut score = 0
  for idx = param_count; idx < preferred.length(); idx = idx + 1 {
    if preferred[idx] {
      score += coloring.old_to_new[idx]
    }
  }
  score
}

///|
fn cl_pick_coloring(
  types : Array[@lib.ValType],
  param_count : Int,
  interferences : Array[Array[Bool]],
  weights : Array[Array[Int]],
  preferred : Array[Bool],
  structured_scalar_preferred : Array[Bool],
) -> CLColoring {
  let natural : Array[Int] = []
  for idx = param_count; idx < types.length(); idx = idx + 1 {
    natural.push(idx)
  }
  let reverse : Array[Int] = []
  let mut idx = types.length() - 1
  while idx >= param_count {
    reverse.push(idx)
    idx -= 1
  }
  let mut best = cl_color_with_order(
    natural, types, param_count, interferences, weights,
  )
  let other = cl_color_with_order(
    reverse, types, param_count, interferences, weights,
  )
  if cl_coloring_is_better(
      other, best, preferred, structured_scalar_preferred, types, param_count,
    ) {
    best = other
  }
  let copy_first = cl_color_with_order(
    cl_copy_weighted_order(weights, param_count, false),
    types,
    param_count,
    interferences,
    weights,
  )
  if cl_coloring_is_better(
      copy_first, best, preferred, structured_scalar_preferred, types, param_count,
    ) {
    best = copy_first
  }
  let copy_reverse = cl_color_with_order(
    cl_copy_weighted_order(weights, param_count, true),
    types,
    param_count,
    interferences,
    weights,
  )
  if cl_coloring_is_better(
      copy_reverse, best, preferred, structured_scalar_preferred, types, param_count,
    ) {
    best = copy_reverse
  }
  let preferred_first = cl_color_with_order(
    cl_preferred_compaction_order(preferred, types, param_count),
    types,
    param_count,
    interferences,
    weights,
  )
  if cl_coloring_is_better(
      preferred_first, best, preferred, structured_scalar_preferred, types, param_count,
    ) {
    best = preferred_first
  }
  let structured_scalar_first = cl_color_with_order(
    cl_structured_scalar_compaction_order(
      structured_scalar_preferred, types, param_count,
    ),
    types,
    param_count,
    interferences,
    weights,
  )
  if cl_coloring_is_better(
      structured_scalar_first, best, preferred, structured_scalar_preferred, types,
      param_count,
    ) {
    best = structured_scalar_first
  }
  best
}

///|
fn cl_rewrite_local_idx(
  idx : @lib.LocalIdx,
  old_to_new : Array[Int],
) -> @lib.LocalIdx {
  let raw = cl_local_idx_raw(idx)
  if raw < 0 || raw >= old_to_new.length() {
    abort("coalesce-locals local remap out of range")
  }
  cl_local_idx_from_int(old_to_new[raw])
}

///|
fn cl_rewrite_instrs_in_place(
  instrs : Array[@lib.Instruction],
  old_to_new : Array[Int],
  effective : Array[Bool],
  action_cursor : Array[Int],
) -> Unit {
  let mut reachable = true
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    if !reachable {
      match instr {
        @lib.LocalGet(local_idx) =>
          instrs[idx] = @lib.Instruction::local_get(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        @lib.LocalSet(local_idx) =>
          instrs[idx] = @lib.Instruction::local_set(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        @lib.LocalTee(local_idx) =>
          instrs[idx] = @lib.Instruction::local_tee(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        _ => ()
      }
      continue
    }
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        cl_rewrite_instrs_in_place(body, old_to_new, effective, action_cursor)
        instrs[idx] = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        cl_rewrite_instrs_in_place(body, old_to_new, effective, action_cursor)
        instrs[idx] = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        cl_rewrite_instrs_in_place(
          then_body, old_to_new, effective, action_cursor,
        )
        match else_body {
          Some(else_instrs) =>
            cl_rewrite_instrs_in_place(
              else_instrs, old_to_new, effective, action_cursor,
            )
          None => ()
        }
        instrs[idx] = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        cl_rewrite_instrs_in_place(body, old_to_new, effective, action_cursor)
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      @lib.LocalGet(local_idx) => {
        action_cursor[0] += 1
        instrs[idx] = @lib.Instruction::local_get(
          cl_rewrite_local_idx(local_idx, old_to_new),
        )
      }
      @lib.LocalSet(local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        let rewritten_idx = cl_rewrite_local_idx(local_idx, old_to_new)
        if action_idx < effective.length() && !effective[action_idx] {
          match idx > 0 {
            true =>
              match instrs[idx - 1] {
                @lib.LocalGet(prev_idx) if prev_idx == rewritten_idx =>
                  instrs[idx] = @lib.Instruction::local_set(rewritten_idx)
                _ => instrs[idx] = @lib.Instruction::drop()
              }
            false => instrs[idx] = @lib.Instruction::drop()
          }
        } else {
          instrs[idx] = @lib.Instruction::local_set(rewritten_idx)
        }
      }
      @lib.LocalTee(local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        if action_idx < effective.length() && !effective[action_idx] {
          instrs[idx] = @lib.Instruction::nop()
        } else {
          instrs[idx] = @lib.Instruction::local_tee(
            cl_rewrite_local_idx(local_idx, old_to_new),
          )
        }
      }
      _ => ()
    }
    if cl_instr_makes_rest_unreachable(instr) {
      reachable = false
    }
  }
}

///|
fn cl_instrs_reference_enclosing_label(
  instrs : Array[@lib.Instruction],
  depth : Int,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Br(label_idx)
      | @lib.BrIf(label_idx)
      | @lib.BrOnNull(label_idx)
      | @lib.BrOnNonNull(label_idx) =>
        if cl_label_idx_raw(label_idx) == depth {
          return true
        }
      @lib.BrOnCast(label_idx, _, _, _)
      | @lib.BrOnCastFail(label_idx, _, _, _) =>
        if cl_label_idx_raw(label_idx) == depth {
          return true
        }
      @lib.BrTable(labels, default_label) => {
        if cl_label_idx_raw(default_label) == depth {
          return true
        }
        for label in labels {
          if cl_label_idx_raw(label) == depth {
            return true
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if cl_instrs_reference_enclosing_label(body, depth + 1) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if cl_instrs_reference_enclosing_label(then_body, depth + 1) {
          return true
        }
        match else_body {
          Some(body) =>
            if cl_instrs_reference_enclosing_label(body, depth + 1) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn cl_flatten_terminal_unbranched_void_blocks(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    let mut rewritten = instr
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        if cl_flatten_terminal_unbranched_void_blocks(body) {
          changed = true
        }
        if block_type == @lib.BlockType::void_() &&
          cl_instrs_end_in_unreachable(body) &&
          !cl_instrs_reference_enclosing_label(body, 0) {
          out.append(body)
          changed = true
          continue
        }
        rewritten = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        if cl_flatten_terminal_unbranched_void_blocks(body) {
          changed = true
        }
        rewritten = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        if cl_flatten_terminal_unbranched_void_blocks(then_body) {
          changed = true
        }
        match else_body {
          Some(body) =>
            if cl_flatten_terminal_unbranched_void_blocks(body) {
              changed = true
            }
          None => ()
        }
        rewritten = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        if cl_flatten_terminal_unbranched_void_blocks(body) {
          changed = true
        }
        rewritten = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      _ => ()
    }
    out.push(rewritten)
  }
  if changed {
    instrs.clear()
    instrs.append(out)
  }
  changed
}

///|
fn cl_truncate_dead_tails(instrs : Array[@lib.Instruction]) -> Bool {
  let mut changed = false
  let out : Array[@lib.Instruction] = []
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let mut instr = instrs[idx]
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        if cl_truncate_dead_tails(body) {
          changed = true
        }
        instr = @lib.Instruction::block(block_type, @lib.Expr::new(body))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        if cl_truncate_dead_tails(body) {
          changed = true
        }
        instr = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.If(block_type, then_body, else_body) => {
        if cl_truncate_dead_tails(then_body) {
          changed = true
        }
        match else_body {
          Some(else_instrs) =>
            if cl_truncate_dead_tails(else_instrs) {
              changed = true
            }
          None => ()
        }
        instr = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        if cl_truncate_dead_tails(body) {
          changed = true
        }
        instr = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      _ => ()
    }
    out.push(instr)
    if cl_instr_makes_rest_unreachable(instr) && idx + 1 < instrs.length() {
      if !cl_instr_is_terminal(instr) {
        out.push(@lib.Instruction::unreachable_())
      }
      changed = true
      break
    }
  }
  if changed {
    instrs.clear()
    for instr in out {
      instrs.push(instr)
    }
  }
  changed
}

///|
fn cl_remove_redundant_copy_pairs(instrs : Array[@lib.Instruction]) -> Bool {
  let mut changed = false
  let out : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        if cl_remove_redundant_copy_pairs(body) {
          changed = true
        }
        out.push(@lib.Instruction::block(block_type, @lib.Expr::new(body)))
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        if cl_remove_redundant_copy_pairs(body) {
          changed = true
        }
        out.push(@lib.Instruction::loop_(block_type, @lib.Expr::new(body)))
      }
      @lib.If(block_type, then_body, else_body) => {
        if cl_remove_redundant_copy_pairs(then_body) {
          changed = true
        }
        match else_body {
          Some(else_instrs) =>
            if cl_remove_redundant_copy_pairs(else_instrs) {
              changed = true
            }
          None => ()
        }
        out.push(@lib.Instruction::if_(block_type, then_body, else_body))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        if cl_remove_redundant_copy_pairs(body) {
          changed = true
        }
        out.push(
          @lib.Instruction::try_table(block_type, catches, @lib.Expr::new(body)),
        )
      }
      @lib.LocalGet(local_idx) if idx + 1 < instrs.length() =>
        match instrs[idx + 1] {
          @lib.LocalSet(next_idx) if next_idx == local_idx => {
            out.push(@lib.Instruction::nop())
            changed = true
            idx += 1
          }
          @lib.LocalTee(next_idx) if next_idx == local_idx => {
            out.push(@lib.Instruction::local_get(local_idx))
            changed = true
            idx += 1
          }
          _ => out.push(instrs[idx])
        }
      @lib.Nop if idx + 1 < instrs.length() =>
        match instrs[idx + 1] {
          @lib.Drop => changed = true
          _ => out.push(instrs[idx])
        }
      _ => out.push(instrs[idx])
    }
    idx += 1
  }
  if changed {
    instrs.clear()
    for instr in out {
      instrs.push(instr)
    }
  }
  changed
}

///|
fn cl_old_to_new_is_identity(old_to_new : Array[Int]) -> Bool {
  for idx = 0; idx < old_to_new.length(); idx = idx + 1 {
    if old_to_new[idx] != idx {
      return false
    }
  }
  true
}

///|
fn cl_rewrite_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> CLFuncRewrite {
  let @lib.Func(body_locals, body) = func
  let body_local_count = body_locals.length()
  if body_local_count == 0 {
    return { func, changed: false }
  }
  let @lib.Expr(original_instrs) = body
  // The flattened conservative liveness model is not path/iteration-sensitive
  // enough for loops. Non-loop structured control uses an extra plain-liveness
  // interference pass, so local.tee branch values may still share proven-dead
  // compatible slots without admitting path-sensitive overlap.
  if cl_instrs_have_loop_control(original_instrs) {
    return cl_rewrite_loop_func_unused_locals(func, params)
  }
  if params.length() + body_local_count > cl_dense_coloring_local_limit() {
    return { func, changed: false }
  }
  let has_structured_control = cl_instrs_have_structured_control(
    original_instrs,
  )
  if has_structured_control {
    return cl_rewrite_func_structured_conservative(func, params)
  }
  let types = cl_all_local_types(params, body_locals)
  let total_locals = types.length()
  let actions : Array[CLAction] = []
  cl_collect_instrs(original_instrs, actions, total_locals)
  let liveness = cl_compute_liveness(actions, total_locals)
  let interferences = cl_compute_interferences(
    actions,
    liveness,
    types,
    params.length(),
  )
  let weights = cl_copy_weights(actions, liveness.effective, total_locals)
  let preferred = cl_preferred_compaction_flags(
    original_instrs, actions, total_locals,
  )
  let structured_scalar_preferred = cl_structured_scalar_compaction_flags(
    original_instrs,
    actions,
    types,
    params.length(),
  )
  let coloring = cl_pick_coloring(
    types,
    params.length(),
    interferences,
    weights,
    preferred,
    structured_scalar_preferred,
  )
  let rewritten_locals = @lib.Locals::from_types(coloring.slot_types)
  let rewritten_instrs = original_instrs.copy()
  cl_rewrite_instrs_in_place(
    rewritten_instrs,
    coloring.old_to_new,
    liveness.effective,
    [0],
  )
  let rewrite_changed = rewritten_instrs != original_instrs
  let dead_tail_changed = cl_truncate_dead_tails(rewritten_instrs)
  let cleanup_changed = cl_remove_redundant_copy_pairs(rewritten_instrs)
  let changed = rewrite_changed ||
    dead_tail_changed ||
    cleanup_changed ||
    !cl_old_to_new_is_identity(coloring.old_to_new) ||
    rewritten_locals != body_locals
  if !changed {
    return { func, changed: false }
  }
  {
    func: @lib.Func::new(rewritten_locals, @lib.Expr::new(rewritten_instrs)),
    changed: true,
  }
}

///|
fn cl_module_subtypes(mod_ : @lib.Module) -> Array[@lib.SubType] {
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
    None => abort("coalesce-locals missing type section")
  }
  subtypes
}

///|
fn cl_params_for_type_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Array[@lib.ValType] {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => abort("coalesce-locals missing function subtype")
      }
    @lib.RecIdx(_) =>
      // Function-section type references are module-global TypeIdx values after
      // decode/validation. A RecIdx here would mean a rec-group-local type
      // escaped into the module function declaration table, so keep this as an
      // invariant assertion instead of trying to reinterpret it.
      abort("coalesce-locals unsupported recursive function type index")
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => abort("coalesce-locals expected function type")
  }
}

///|
fn cl_defined_func_param_cache(
  mod_ : @lib.Module,
) -> Array[Array[@lib.ValType]] {
  let subtypes = cl_module_subtypes(mod_)
  let out : Array[Array[@lib.ValType]] = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => Array::new(capacity=type_idxs.length())
    None => []
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out.push(cl_params_for_type_idx(subtypes, type_idx))
      }
    None => abort("coalesce-locals missing function section")
  }
  out
}

///|
fn cl_name_sec_without_local_names(name_sec : @lib.NameSec?) -> @lib.NameSec? {
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
      Some(
        @lib.NameSec::new(
          module_name~,
          func_names~,
          local_names=None,
          label_names~,
          type_names~,
          table_names~,
          memory_names~,
          global_names~,
          elem_names~,
          data_names~,
          field_names~,
          tag_names~,
        ),
      )
    }
    None => None
  }
}

///|
fn cl_rebuild_module(
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
pub fn coalesce_locals_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  ignore(cl_imported_func_count(mod_))
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let defined_func_params = cl_defined_func_param_cache(mod_)
      let rewritten_funcs : Array[@lib.Func] = Array::new(
        capacity=funcs.length(),
      )
      let mut changed = false
      for code_idx = 0; code_idx < funcs.length(); code_idx = code_idx + 1 {
        let params = match defined_func_params.get(code_idx) {
          Some(params) => params
          None => abort("coalesce-locals missing defined function params")
        }
        let rewrite = cl_rewrite_func(funcs[code_idx], params)
        rewritten_funcs.push(rewrite.func)
        if rewrite.changed {
          changed = true
        }
      }
      if !changed {
        return mod_
      }
      cl_rebuild_module(
        mod_,
        Some(@lib.CodeSec::new(rewritten_funcs)),
        cl_name_sec_without_local_names(mod_.name_sec),
      )
    }
    None => mod_
  }
}
