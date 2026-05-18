///|
pub fn simplify_globals_optimizing_summary() -> String {
  "Simplify private global state and rerun default function cleanup on changed functions."
}

///|
priv struct SgoGlobalInfo {
  imported : Bool
  mut exported : Bool
  mut mutable_ : Bool
  value_type : @lib.ValType
  mut init : @lib.Expr?
  mut read_count : Int
  mut write_count : Int
}

///|
priv struct SgoRewriteState {
  consts : Array[@lib.Instruction?]
  aliases : Array[@lib.GlobalIdx?]
  remove_sets : Array[Bool]
  mut changed : Bool
}

///|
priv struct SgoGlobalInitRewriteState {
  consts : Array[@lib.Instruction?]
  aliases : Array[@lib.GlobalIdx?]
  inlines : Array[@lib.Expr?]
  mut changed : Bool
}

///|
priv struct SgoPassResult {
  mod_out : @lib.Module
  touched : Array[Bool]
}

///|
fn sgo_global_idx_slot(idx : @lib.GlobalIdx) -> Int {
  let @lib.GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sgo_defined_global_abs_idx(imported_globals : Int, defined_idx : Int) -> Int {
  imported_globals + defined_idx
}

///|
fn sgo_const_instr(instr : @lib.Instruction) -> @lib.Instruction? {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_) => Some(instr)
    _ => None
  }
}

///|
fn sgo_expr_single_const(expr : @lib.Expr) -> @lib.Instruction? {
  match expr {
    @lib.Expr([instr]) => sgo_const_instr(instr)
    _ => None
  }
}

///|
fn sgo_empty_const_array(length : Int) -> Array[@lib.Instruction?] {
  Array::make(length, None)
}

///|
fn sgo_empty_expr_array(length : Int) -> Array[@lib.Expr?] {
  Array::make(length, None)
}

///|
fn sgo_empty_global_idx_array(length : Int) -> Array[@lib.GlobalIdx?] {
  Array::make(length, None)
}

///|
fn sgo_scan_global_idx(
  infos : Array[SgoGlobalInfo],
  idx : @lib.GlobalIdx,
  read : Bool,
) -> Unit {
  let slot = sgo_global_idx_slot(idx)
  if slot < 0 || slot >= infos.length() {
    return
  }
  if read {
    infos[slot].read_count = infos[slot].read_count + 1
  } else {
    infos[slot].write_count = infos[slot].write_count + 1
  }
}

///|
fn sgo_scan_instr(
  instr : @lib.Instruction,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match instr {
    @lib.GlobalGet(idx) => sgo_scan_global_idx(infos, idx, true)
    @lib.GlobalSet(idx) => sgo_scan_global_idx(infos, idx, false)
    @lib.Block(_, body) | @lib.Loop(_, body) => sgo_scan_expr(body, infos)
    @lib.If(_, then_body, else_body) => {
      sgo_scan_instrs(then_body, infos)
      match else_body {
        Some(body) => sgo_scan_instrs(body, infos)
        None => ()
      }
    }
    @lib.TryTable(_, _, body) => sgo_scan_expr(body, infos)
    _ => ()
  }
}

///|
fn sgo_scan_instrs(
  instrs : Array[@lib.Instruction],
  infos : Array[SgoGlobalInfo],
) -> Unit {
  for instr in instrs {
    sgo_scan_instr(instr, infos)
  }
}

///|
fn sgo_scan_expr(expr : @lib.Expr, infos : Array[SgoGlobalInfo]) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_scan_instrs(instrs, infos)
}

///|
fn sgo_collect_global_infos(mod_ : @lib.Module) -> (Array[SgoGlobalInfo], Int) {
  let infos : Array[SgoGlobalInfo] = []
  let mut imported_globals = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(
            _,
            _,
            @lib.GlobalExternType(@lib.GlobalType(value_type, mutable_))
          ) => {
            infos.push({
              imported: true,
              exported: false,
              mutable_,
              value_type,
              init: None,
              read_count: 0,
              write_count: 0,
            })
            imported_globals += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global_ in globals {
        let @lib.Global(@lib.GlobalType(value_type, mutable_), init) = global_
        infos.push({
          imported: false,
          exported: false,
          mutable_,
          value_type,
          init: Some(init),
          read_count: 0,
          write_count: 0,
        })
      }
    None => ()
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        let @lib.Export(_, idx) = export_
        match idx {
          @lib.GlobalExternIdx(global_idx) => {
            let slot = sgo_global_idx_slot(global_idx)
            if slot >= 0 && slot < infos.length() {
              infos[slot].exported = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  sgo_scan_table_sec(mod_.table_sec, infos)
  sgo_scan_global_sec(mod_.global_sec, infos)
  sgo_scan_elem_sec(mod_.elem_sec, infos)
  sgo_scan_data_sec(mod_.data_sec, infos)
  sgo_scan_code_sec(mod_.code_sec, infos)
  (infos, imported_globals)
}

///|
fn sgo_scan_table_sec(
  table_sec : @lib.TableSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        match table {
          @lib.Table(_, Some(init)) => sgo_scan_expr(init, infos)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sgo_scan_global_sec(
  global_sec : @lib.GlobalSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global_ in globals {
        let @lib.Global(_, init) = global_
        sgo_scan_expr(init, infos)
      }
    None => ()
  }
}

///|
fn sgo_scan_elem_mode(
  mode : @lib.ElemMode,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match mode {
    @lib.Active(_, offset) => sgo_scan_expr(offset, infos)
    _ => ()
  }
}

///|
fn sgo_scan_elem_kind(
  kind : @lib.ElemKind,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match kind {
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        sgo_scan_expr(expr, infos)
      }
    _ => ()
  }
}

///|
fn sgo_scan_elem_sec(
  elem_sec : @lib.ElemSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        sgo_scan_elem_mode(mode, infos)
        sgo_scan_elem_kind(kind, infos)
      }
    None => ()
  }
}

///|
fn sgo_scan_data_sec(
  data_sec : @lib.DataSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        match mode {
          @lib.Active(_, offset) => sgo_scan_expr(offset, infos)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sgo_scan_code_sec(
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
) -> Unit {
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        sgo_scan_expr(body, infos)
      }
    None => ()
  }
}

///|
fn sgo_same_init_write_flags(
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
) -> Array[Bool] {
  let init_consts = sgo_build_initial_startup_consts(infos)
  let flags = Array::make(infos.length(), true)
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        sgo_mark_same_init_writes_expr(body, init_consts, flags)
      }
    None => ()
  }
  flags
}

///|
fn sgo_mark_same_init_writes_expr(
  expr : @lib.Expr,
  init_consts : Array[@lib.Instruction?],
  flags : Array[Bool],
) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_mark_same_init_writes_instrs(instrs, init_consts, flags)
}

///|
fn sgo_mark_same_init_writes_instrs(
  instrs : Array[@lib.Instruction],
  init_consts : Array[@lib.Instruction?],
  flags : Array[Bool],
) -> Unit {
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalSet(idx) =>
        sgo_mark_same_init_write(idx, pos, instrs, init_consts, flags)
      @lib.Block(_, body) | @lib.Loop(_, body) =>
        sgo_mark_same_init_writes_expr(body, init_consts, flags)
      @lib.If(_, then_body, else_body) => {
        sgo_mark_same_init_writes_instrs(then_body, init_consts, flags)
        match else_body {
          Some(body) =>
            sgo_mark_same_init_writes_instrs(body, init_consts, flags)
          None => ()
        }
      }
      @lib.TryTable(_, _, body) =>
        sgo_mark_same_init_writes_expr(body, init_consts, flags)
      _ => ()
    }
  }
}

///|
fn sgo_mark_same_init_write(
  idx : @lib.GlobalIdx,
  pos : Int,
  instrs : Array[@lib.Instruction],
  init_consts : Array[@lib.Instruction?],
  flags : Array[Bool],
) -> Unit {
  let slot = sgo_global_idx_slot(idx)
  if slot < 0 || slot >= flags.length() || slot >= init_consts.length() {
    return
  }
  let mut matches_init = false
  if pos > 0 {
    match (sgo_const_instr(instrs[pos - 1]), init_consts[slot]) {
      (Some(actual), Some(expected)) if actual == expected =>
        matches_init = true
      _ => ()
    }
  }
  if !matches_init {
    flags[slot] = false
  }
}

///|
fn sgo_read_only_to_write_flags(
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
) -> Array[Bool] {
  let safe_reads = Array::make(infos.length(), 0)
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func_ in funcs {
        let @lib.Func(_, body) = func_
        sgo_count_read_only_to_write_expr(body, safe_reads)
      }
    None => ()
  }
  let flags = Array::make(infos.length(), false)
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    flags[idx] = infos[idx].read_count > 0 &&
      safe_reads[idx] == infos[idx].read_count
  }
  flags
}

///|
fn sgo_count_read_only_to_write_expr(
  expr : @lib.Expr,
  safe_reads : Array[Int],
) -> Unit {
  let @lib.Expr(instrs) = expr
  sgo_count_read_only_to_write_instrs(instrs, safe_reads)
}

///|
fn sgo_count_read_only_to_write_safe_read(
  idx : @lib.GlobalIdx,
  safe_reads : Array[Int],
) -> Unit {
  let slot = sgo_global_idx_slot(idx)
  if slot >= 0 && slot < safe_reads.length() {
    safe_reads[slot] = safe_reads[slot] + 1
  }
}

///|
fn sgo_count_read_only_to_write_instrs(
  instrs : Array[@lib.Instruction],
  safe_reads : Array[Int],
) -> Unit {
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalGet(idx) if sgo_read_only_to_write_read_at(instrs, pos, idx) =>
        sgo_count_read_only_to_write_safe_read(idx, safe_reads)
      @lib.Block(_, body) => {
        if pos + 1 < instrs.length() {
          sgo_count_block_condition_read_only_to_write_read(
            instr,
            instrs[pos + 1],
            safe_reads,
          )
        }
        sgo_count_read_only_to_write_expr(body, safe_reads)
      }
      @lib.Loop(_, body) => sgo_count_read_only_to_write_expr(body, safe_reads)
      @lib.If(_, then_body, else_body) => {
        sgo_count_read_only_to_write_instrs(then_body, safe_reads)
        match else_body {
          Some(body) => sgo_count_read_only_to_write_instrs(body, safe_reads)
          None => ()
        }
      }
      @lib.TryTable(_, _, body) =>
        sgo_count_read_only_to_write_expr(body, safe_reads)
      _ => ()
    }
  }
}

///|
fn sgo_if_is_read_only_to_write_set(
  instr : @lib.Instruction,
  idx : @lib.GlobalIdx,
) -> Bool {
  match instr {
    @lib.If(_, then_body, None) =>
      sgo_instrs_are_single_const_global_set(then_body, idx)
    _ => false
  }
}

///|
fn sgo_read_only_to_write_read_at(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  sgo_is_exact_if_return_set(instrs, pos, idx) ||
  (
    pos + 1 < instrs.length() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 1], idx)
  ) ||
  (
    pos + 2 < instrs.length() &&
    instrs[pos + 1] == @lib.Instruction::i32_eqz() &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 2], idx)
  ) ||
  (
    pos + 3 < instrs.length() &&
    sgo_const_instr(instrs[pos + 1]) != None &&
    (
      instrs[pos + 2] == @lib.Instruction::i32_eq() ||
      instrs[pos + 2] == @lib.Instruction::i32_ne()
    ) &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 3], idx)
  ) ||
  (
    pos > 0 &&
    pos + 2 < instrs.length() &&
    sgo_const_instr(instrs[pos - 1]) != None &&
    (
      instrs[pos + 1] == @lib.Instruction::i32_eq() ||
      instrs[pos + 1] == @lib.Instruction::i32_ne()
    ) &&
    sgo_if_is_read_only_to_write_set(instrs[pos + 2], idx)
  )
}

///|
fn sgo_is_return_guard(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.If(_, [@lib.Return], None) => true
    _ => false
  }
}

///|
fn sgo_is_exact_if_return_set(
  instrs : Array[@lib.Instruction],
  pos : Int,
  idx : @lib.GlobalIdx,
) -> Bool {
  if pos != 0 || instrs.length() != 4 {
    return false
  }
  match instrs {
    [@lib.GlobalGet(get_idx), if_instr, value, @lib.GlobalSet(set_idx)] =>
      get_idx == idx &&
      set_idx == idx &&
      sgo_is_return_guard(if_instr) &&
      sgo_const_instr(value) != None
    _ => false
  }
}

///|
fn sgo_collect_read_only_to_write_body(
  instrs : Array[@lib.Instruction],
  out : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Nop => ()
      @lib.Block(@lib.VoidBlockType, body) => {
        let @lib.Expr(body_instrs) = body
        if !sgo_collect_read_only_to_write_body(body_instrs, out) {
          return false
        }
      }
      _ => out.push(instr)
    }
  }
  true
}

///|
fn sgo_single_const_global_set_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_body(instrs, flat) {
    return None
  }
  let mut start = 0
  while start + 1 < flat.length() &&
        sgo_const_instr(flat[start]) != None &&
        flat[start + 1] == @lib.Instruction::drop() {
    start = start + 2
  }
  if start + 2 != flat.length() {
    return None
  }
  match (flat[start], flat[start + 1]) {
    (value, @lib.GlobalSet(set_idx)) if sgo_const_instr(value) != None =>
      Some(set_idx)
    _ => None
  }
}

///|
fn sgo_instrs_are_single_const_global_set(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  match sgo_single_const_global_set_idx(instrs) {
    Some(set_idx) => set_idx == idx
    None => false
  }
}

///|
fn sgo_block_condition_single_read_idx(
  instrs : Array[@lib.Instruction],
) -> @lib.GlobalIdx? {
  let flat : Array[@lib.Instruction] = []
  if !sgo_collect_read_only_to_write_body(instrs, flat) {
    return None
  }
  match flat {
    [@lib.GlobalGet(idx)] => Some(idx)
    [@lib.GlobalGet(idx), instr] if instr == @lib.Instruction::i32_eqz() =>
      Some(idx)
    _ => None
  }
}

///|
fn sgo_block_condition_final_read_matches(
  instrs : Array[@lib.Instruction],
  idx : @lib.GlobalIdx,
) -> Bool {
  let len = instrs.length()
  if len < 3 {
    return false
  }
  let cmp = instrs[len - 1]
  if cmp != @lib.Instruction::i32_eq() && cmp != @lib.Instruction::i32_ne() {
    return false
  }
  match (instrs[len - 3], instrs[len - 2]) {
    (@lib.GlobalGet(get_idx), const_instr) =>
      get_idx == idx && sgo_const_instr(const_instr) != None
    (const_instr, @lib.GlobalGet(get_idx)) =>
      get_idx == idx && sgo_const_instr(const_instr) != None
    _ => false
  }
}

///|
fn sgo_count_block_condition_read_only_to_write_read(
  instr : @lib.Instruction,
  next : @lib.Instruction,
  safe_reads : Array[Int],
) -> Unit {
  match (instr, next) {
    (@lib.Block(_, @lib.Expr(body)), @lib.If(_, then_body, None)) =>
      match sgo_single_const_global_set_idx(then_body) {
        Some(idx) if sgo_block_condition_final_read_matches(body, idx) =>
          sgo_count_read_only_to_write_safe_read(idx, safe_reads)
        Some(idx) =>
          match sgo_block_condition_single_read_idx(body) {
            Some(read_idx) if read_idx == idx =>
              sgo_count_read_only_to_write_safe_read(idx, safe_reads)
            _ => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn sgo_plan_remove_sets(
  infos : Array[SgoGlobalInfo],
  same_init_writes : Array[Bool],
  read_only_to_write : Array[Bool],
) -> Array[Bool] {
  let remove_sets = Array::make(infos.length(), false)
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if !info.imported &&
      !info.exported &&
      info.write_count > 0 &&
      (info.read_count == 0 || same_init_writes[idx] || read_only_to_write[idx]) {
      remove_sets[idx] = true
    }
  }
  remove_sets
}

///|
fn sgo_apply_practical_immutability(
  infos : Array[SgoGlobalInfo],
  remove_sets : Array[Bool],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if info.imported || info.exported || !info.mutable_ {
      continue
    }
    if info.write_count == 0 || remove_sets[idx] {
      infos[idx].mutable_ = false
      changed = true
    }
  }
  changed
}

///|
fn sgo_rewrite_instr_with_state(
  instr : @lib.Instruction,
  state : SgoRewriteState,
  rewrite_sets : Bool,
) -> @lib.Instruction {
  match instr {
    @lib.GlobalGet(idx) => {
      let slot = sgo_global_idx_slot(idx)
      if slot >= 0 && slot < state.consts.length() {
        match state.consts[slot] {
          Some(replacement) => {
            state.changed = true
            return replacement
          }
          None => ()
        }
      }
      if slot >= 0 && slot < state.aliases.length() {
        match state.aliases[slot] {
          Some(target_idx) => {
            state.changed = true
            return @lib.Instruction::global_get(target_idx)
          }
          None => ()
        }
      }
      instr
    }
    @lib.GlobalSet(idx) if rewrite_sets => {
      let slot = sgo_global_idx_slot(idx)
      if slot >= 0 &&
        slot < state.remove_sets.length() &&
        state.remove_sets[slot] {
        state.changed = true
        return @lib.Instruction::drop()
      }
      instr
    }
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(
        block_type,
        sgo_rewrite_expr_with_state(body, state, rewrite_sets),
      )
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(
        block_type,
        sgo_rewrite_expr_with_state(body, state, rewrite_sets),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then = sgo_rewrite_instrs_with_state(
        then_body, state, rewrite_sets,
      )
      let rewritten_else = match else_body {
        Some(body) =>
          Some(sgo_rewrite_instrs_with_state(body, state, rewrite_sets))
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        sgo_rewrite_expr_with_state(body, state, rewrite_sets),
      )
    _ => instr
  }
}

///|
fn sgo_rewrite_instrs_with_state(
  instrs : Array[@lib.Instruction],
  state : SgoRewriteState,
  rewrite_sets : Bool,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(sgo_rewrite_instr_with_state(instr, state, rewrite_sets))
  }
  out
}

///|
fn sgo_rewrite_expr_with_state(
  expr : @lib.Expr,
  state : SgoRewriteState,
  rewrite_sets : Bool,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  @lib.Expr::new(sgo_rewrite_instrs_with_state(instrs, state, rewrite_sets))
}

///|
fn sgo_rewrite_expr(
  expr : @lib.Expr,
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  remove_sets : Array[Bool],
  rewrite_sets : Bool,
) -> (@lib.Expr, Bool) {
  let state = { consts, aliases, remove_sets, changed: false }
  let rewritten = sgo_rewrite_expr_with_state(expr, state, rewrite_sets)
  (rewritten, state.changed)
}

///|
fn sgo_rewrite_global_init_instr_into(
  instr : @lib.Instruction,
  state : SgoGlobalInitRewriteState,
  out : Array[@lib.Instruction],
) -> Unit {
  match instr {
    @lib.GlobalGet(idx) => {
      let slot = sgo_global_idx_slot(idx)
      if slot >= 0 && slot < state.inlines.length() {
        match state.inlines[slot] {
          Some(@lib.Expr(replacement)) => {
            for item in replacement {
              out.push(item)
            }
            state.changed = true
            return
          }
          None => ()
        }
      }
      if slot >= 0 && slot < state.consts.length() {
        match state.consts[slot] {
          Some(replacement) => {
            out.push(replacement)
            state.changed = true
            return
          }
          None => ()
        }
      }
      if slot >= 0 && slot < state.aliases.length() {
        match state.aliases[slot] {
          Some(target_idx) => {
            out.push(@lib.Instruction::global_get(target_idx))
            state.changed = true
            return
          }
          None => ()
        }
      }
      out.push(instr)
    }
    @lib.Block(block_type, body) =>
      out.push(
        @lib.Instruction::block(
          block_type,
          sgo_rewrite_global_init_expr_with_state(body, state),
        ),
      )
    @lib.Loop(block_type, body) =>
      out.push(
        @lib.Instruction::loop_(
          block_type,
          sgo_rewrite_global_init_expr_with_state(body, state),
        ),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then = sgo_rewrite_global_init_instrs_with_state(
        then_body, state,
      )
      let rewritten_else = match else_body {
        Some(body) =>
          Some(sgo_rewrite_global_init_instrs_with_state(body, state))
        None => None
      }
      out.push(
        @lib.Instruction::if_(block_type, rewritten_then, rewritten_else),
      )
    }
    @lib.TryTable(block_type, catches, body) =>
      out.push(
        @lib.Instruction::try_table(
          block_type,
          catches,
          sgo_rewrite_global_init_expr_with_state(body, state),
        ),
      )
    _ => out.push(instr)
  }
}

///|
fn sgo_rewrite_global_init_instrs_with_state(
  instrs : Array[@lib.Instruction],
  state : SgoGlobalInitRewriteState,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    sgo_rewrite_global_init_instr_into(instr, state, out)
  }
  out
}

///|
fn sgo_rewrite_global_init_expr_with_state(
  expr : @lib.Expr,
  state : SgoGlobalInitRewriteState,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  @lib.Expr::new(sgo_rewrite_global_init_instrs_with_state(instrs, state))
}

///|
fn sgo_rewrite_global_init_expr(
  expr : @lib.Expr,
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  inlines : Array[@lib.Expr?],
) -> (@lib.Expr, Bool) {
  let state = { consts, aliases, inlines, changed: false }
  let rewritten = sgo_rewrite_global_init_expr_with_state(expr, state)
  (rewritten, state.changed)
}

///|
fn sgo_build_initial_startup_consts(
  infos : Array[SgoGlobalInfo],
) -> Array[@lib.Instruction?] {
  let consts = sgo_empty_const_array(infos.length())
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if info.imported {
      continue
    }
    match info.init {
      Some(expr) => consts[idx] = sgo_expr_single_const(expr)
      None => ()
    }
  }
  consts
}

///|
fn sgo_build_code_consts(
  infos : Array[SgoGlobalInfo],
) -> Array[@lib.Instruction?] {
  let consts = sgo_empty_const_array(infos.length())
  for idx = 0; idx < infos.length(); idx = idx + 1 {
    let info = infos[idx]
    if info.imported || info.mutable_ {
      continue
    }
    match info.init {
      Some(expr) => consts[idx] = sgo_expr_single_const(expr)
      None => ()
    }
  }
  consts
}

///|
fn sgo_record_alias_for_global(
  aliases : Array[@lib.GlobalIdx?],
  infos : Array[SgoGlobalInfo],
  abs_idx : Int,
  init : @lib.Expr,
) -> Unit {
  if abs_idx < 0 || abs_idx >= infos.length() || infos[abs_idx].mutable_ {
    return
  }
  match init {
    @lib.Expr([@lib.GlobalGet(dep)]) => {
      let dep_slot = sgo_global_idx_slot(dep)
      if dep_slot < 0 || dep_slot >= infos.length() || infos[dep_slot].mutable_ {
        return
      }
      if infos[dep_slot].value_type != infos[abs_idx].value_type {
        return
      }
      aliases[abs_idx] = match aliases[dep_slot] {
        Some(target_idx) => Some(target_idx)
        None => Some(dep)
      }
    }
    _ => ()
  }
}

///|
fn sgo_rewrite_global_sec(
  global_sec : @lib.GlobalSec?,
  infos : Array[SgoGlobalInfo],
  imported_globals : Int,
) -> (@lib.GlobalSec?, Array[@lib.Instruction?], Array[@lib.GlobalIdx?], Bool) {
  let startup_consts = sgo_build_initial_startup_consts(infos)
  let aliases = sgo_empty_global_idx_array(infos.length())
  let init_inlines = sgo_empty_expr_array(infos.length())
  let mut changed = false
  match global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let out : Array[@lib.Global] = []
      for defined_idx = 0
          defined_idx < globals.length()
          defined_idx = defined_idx + 1 {
        let abs_idx = sgo_defined_global_abs_idx(imported_globals, defined_idx)
        let @lib.Global(@lib.GlobalType(_, original_mutable), init) = globals[defined_idx]
        let (rewritten_init, init_changed) = sgo_rewrite_global_init_expr(
          init, startup_consts, aliases, init_inlines,
        )
        if init_changed {
          changed = true
        }
        let info = infos[abs_idx]
        if original_mutable != info.mutable_ {
          changed = true
        }
        infos[abs_idx].init = Some(rewritten_init)
        startup_consts[abs_idx] = sgo_expr_single_const(rewritten_init)
        sgo_record_alias_for_global(aliases, infos, abs_idx, rewritten_init)
        if !info.imported && !info.mutable_ && info.read_count == 1 {
          init_inlines[abs_idx] = Some(rewritten_init)
        }
        out.push(
          @lib.Global::new(
            @lib.GlobalType::new(info.value_type, info.mutable_),
            rewritten_init,
          ),
        )
      }
      (Some(@lib.GlobalSec::new(out)), startup_consts, aliases, changed)
    }
    None => (None, startup_consts, aliases, false)
  }
}

///|
fn sgo_rewrite_table_sec(
  table_sec : @lib.TableSec?,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.TableSec?, Bool) {
  match table_sec {
    Some(@lib.TableSec(tables)) => {
      let out : Array[@lib.Table] = []
      let mut changed = false
      for table in tables {
        match table {
          @lib.Table(table_type, Some(init)) => {
            let (rewritten, init_changed) = sgo_rewrite_expr(
              init,
              consts,
              sgo_empty_global_idx_array(consts.length()),
              remove_sets,
              false,
            )
            if init_changed {
              changed = true
            }
            out.push(@lib.Table::new(table_type, Some(rewritten)))
          }
          @lib.Table(_, _) => out.push(table)
        }
      }
      (Some(@lib.TableSec::new(out)), changed)
    }
    None => (None, false)
  }
}

///|
fn sgo_rewrite_elem_mode(
  mode : @lib.ElemMode,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.ElemMode, Bool) {
  match mode {
    @lib.Active(table_idx, offset) => {
      let (rewritten, changed) = sgo_rewrite_expr(
        offset,
        consts,
        sgo_empty_global_idx_array(consts.length()),
        remove_sets,
        false,
      )
      (@lib.ElemMode::active(table_idx, rewritten), changed)
    }
    _ => (mode, false)
  }
}

///|
fn sgo_rewrite_elem_kind(kind : @lib.ElemKind) -> (@lib.ElemKind, Bool) {
  // Element item expressions are reference-typed and need exact type/refinalize
  // care. Keep them unchanged in the first SGO slice; element offsets are still
  // rewritten through sgo_rewrite_elem_mode.
  (kind, false)
}

///|
fn sgo_rewrite_elem_sec(
  elem_sec : @lib.ElemSec?,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.ElemSec?, Bool) {
  match elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let out : Array[@lib.Elem] = []
      let mut changed = false
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        let (next_mode, mode_changed) = sgo_rewrite_elem_mode(
          mode, consts, remove_sets,
        )
        let (next_kind, kind_changed) = sgo_rewrite_elem_kind(kind)
        if mode_changed || kind_changed {
          changed = true
        }
        out.push(@lib.Elem::new(next_mode, next_kind))
      }
      (Some(@lib.ElemSec::new(out)), changed)
    }
    None => (None, false)
  }
}

///|
fn sgo_rewrite_data_sec(
  data_sec : @lib.DataSec?,
  consts : Array[@lib.Instruction?],
  remove_sets : Array[Bool],
) -> (@lib.DataSec?, Bool) {
  match data_sec {
    Some(@lib.DataSec(datas)) => {
      let out : Array[@lib.Data] = []
      let mut changed = false
      for data in datas {
        let @lib.Data(mode, bytes) = data
        let next_mode = match mode {
          @lib.Active(mem_idx, offset) => {
            let (rewritten, offset_changed) = sgo_rewrite_expr(
              offset,
              consts,
              sgo_empty_global_idx_array(consts.length()),
              remove_sets,
              false,
            )
            if offset_changed {
              changed = true
            }
            @lib.DataMode::active(mem_idx, rewritten)
          }
          @lib.Passive => mode
        }
        out.push(@lib.Data::new(next_mode, bytes))
      }
      (Some(@lib.DataSec::new(out)), changed)
    }
    None => (None, false)
  }
}

///|
fn sgo_runtime_trace_clear(facts : Array[@lib.Instruction?]) -> Unit {
  for idx = 0; idx < facts.length(); idx = idx + 1 {
    facts[idx] = None
  }
}

///|
fn sgo_runtime_trace_barrier(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Call(_)
    | @lib.CallIndirect(_, _)
    | @lib.CallRef(_)
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.Block(_, _)
    | @lib.Loop(_, _)
    | @lib.If(_, _, _)
    | @lib.TryTable(_, _, _)
    | @lib.Br(_)
    | @lib.BrIf(_)
    | @lib.BrTable(_, _)
    | @lib.Return
    | @lib.Throw(_)
    | @lib.ThrowRef => true
    _ => false
  }
}

///|
fn sgo_runtime_trace_trackable(
  infos : Array[SgoGlobalInfo],
  slot : Int,
) -> Bool {
  slot >= 0 &&
  slot < infos.length() &&
  !infos[slot].imported &&
  !infos[slot].exported
}

///|
fn sgo_rewrite_runtime_trace_expr(
  expr : @lib.Expr,
  infos : Array[SgoGlobalInfo],
) -> (@lib.Expr, Bool) {
  let @lib.Expr(instrs) = expr
  let facts = sgo_empty_const_array(infos.length())
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for pos = 0; pos < instrs.length(); pos = pos + 1 {
    let instr = instrs[pos]
    match instr {
      @lib.GlobalGet(idx) => {
        let slot = sgo_global_idx_slot(idx)
        if sgo_runtime_trace_trackable(infos, slot) {
          match facts[slot] {
            Some(replacement) => {
              out.push(replacement)
              changed = true
              continue
            }
            None => ()
          }
        }
        out.push(instr)
      }
      @lib.GlobalSet(idx) => {
        out.push(instr)
        let slot = sgo_global_idx_slot(idx)
        if sgo_runtime_trace_trackable(infos, slot) {
          facts[slot] = if pos > 0 {
            sgo_const_instr(instrs[pos - 1])
          } else {
            None
          }
        }
      }
      _ => {
        out.push(instr)
        if sgo_runtime_trace_barrier(instr) {
          sgo_runtime_trace_clear(facts)
        }
      }
    }
  }
  (@lib.Expr::new(out), changed)
}

///|
fn sgo_rewrite_code_sec(
  code_sec : @lib.CodeSec?,
  infos : Array[SgoGlobalInfo],
  consts : Array[@lib.Instruction?],
  aliases : Array[@lib.GlobalIdx?],
  remove_sets : Array[Bool],
) -> (@lib.CodeSec?, Array[Bool], Bool) {
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      let touched = Array::make(funcs.length(), false)
      let mut changed = false
      for idx = 0; idx < funcs.length(); idx = idx + 1 {
        let @lib.Func(locals, body) = funcs[idx]
        let (rewritten, func_changed) = sgo_rewrite_expr(
          body, consts, aliases, remove_sets, true,
        )
        let (runtime_rewritten, runtime_changed) = sgo_rewrite_runtime_trace_expr(
          rewritten, infos,
        )
        if func_changed || runtime_changed {
          touched[idx] = true
          changed = true
          out.push(@lib.Func::new(locals, runtime_rewritten))
        } else {
          out.push(funcs[idx])
        }
      }
      (Some(@lib.CodeSec::new(out)), touched, changed)
    }
    None => (None, [], false)
  }
}

///|
fn sgo_build_module(
  mod_ : @lib.Module,
  global_sec : @lib.GlobalSec?,
  table_sec : @lib.TableSec?,
  elem_sec : @lib.ElemSec?,
  data_sec : @lib.DataSec?,
  code_sec : @lib.CodeSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec~,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec~,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec~,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec~,
    data_sec~,
    name_sec=mod_.name_sec,
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}

///|
fn sgo_run_core(mod_ : @lib.Module, trace : (String) -> Unit) -> SgoPassResult {
  let (infos, imported_globals) = sgo_collect_global_infos(mod_)
  let same_init_writes = sgo_same_init_write_flags(mod_.code_sec, infos)
  let read_only_to_write = sgo_read_only_to_write_flags(mod_.code_sec, infos)
  let remove_sets = sgo_plan_remove_sets(
    infos, same_init_writes, read_only_to_write,
  )
  let mut changed = sgo_apply_practical_immutability(infos, remove_sets)
  let (next_global_sec, startup_consts, aliases, global_changed) = sgo_rewrite_global_sec(
    mod_.global_sec,
    infos,
    imported_globals,
  )
  changed = changed || global_changed
  let code_consts = sgo_build_code_consts(infos)
  let (next_table_sec, table_changed) = sgo_rewrite_table_sec(
    mod_.table_sec,
    startup_consts,
    remove_sets,
  )
  let (next_elem_sec, elem_changed) = sgo_rewrite_elem_sec(
    mod_.elem_sec,
    startup_consts,
    remove_sets,
  )
  let (next_data_sec, data_changed) = sgo_rewrite_data_sec(
    mod_.data_sec,
    startup_consts,
    remove_sets,
  )
  let (next_code_sec, touched, code_changed) = sgo_rewrite_code_sec(
    mod_.code_sec,
    infos,
    code_consts,
    aliases,
    remove_sets,
  )
  changed = changed ||
    table_changed ||
    elem_changed ||
    data_changed ||
    code_changed
  if code_changed {
    trace(
      "pass[simplify-globals-optimizing]:rewrite touched=\{sgo_count_touched(touched)}",
    )
  }
  if !changed {
    return { mod_out: mod_, touched }
  }
  {
    mod_out: sgo_build_module(
      mod_, next_global_sec, next_table_sec, next_elem_sec, next_data_sec, next_code_sec,
    ),
    touched,
  }
}

///|
fn sgo_count_touched(touched : Array[Bool]) -> Int {
  let mut count = 0
  for item in touched {
    if item {
      count += 1
    }
  }
  count
}
