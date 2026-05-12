///|
pub fn dae_summary() -> String {
  "Remove private dead scalar parameters across owned direct call boundaries."
}

///|
pub fn dae_optimizing_summary() -> String {
  "Run Binaryen-compatible dead argument elimination and nested cleanup on touched functions."
}

///|
priv struct DaeCallShape {
  start : Int
  end : Int
  pure : Bool
}

///|
priv struct DaeRewriteResult {
  instrs : Array[@lib.Instruction]
  calls_rewritten : Int
  ok : Bool
}

///|
priv struct DaeLocalUse {
  gets : Array[Bool]
  writes : Array[Bool]
}

///|
priv struct DaePassResult {
  mod_out : @lib.Module
  touched : Array[Bool]
  changed : Bool
  primary_def : Int
}

///|
fn dae_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn dae_defined_func_count(mod_ : @lib.Module) -> Int {
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn dae_func_idx_slot(idx : @lib.FuncIdx) -> Int {
  let @lib.FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn dae_local_idx_slot(idx : @lib.LocalIdx) -> Int {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn dae_rewrite_local_idx(raw : Int, local_map : Array[Int]) -> @lib.LocalIdx {
  @lib.LocalIdx::new(local_map[raw].reinterpret_as_uint())
}

///|
fn dae_collect_func_type_indices(mod_ : @lib.Module) -> Array[@lib.TypeIdx] {
  let out : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) => out.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => out.append(type_idxs)
    None => ()
  }
  out
}

///|
fn dae_type_sec_func_type(
  type_sec : @lib.TypeSec,
  type_idx : @lib.TypeIdx,
) -> @lib.FuncType? {
  match (type_sec, type_idx) {
    (@lib.TypeSec(rec_types), @lib.TypeIdx(raw)) => {
      let slot = raw.reinterpret_as_int()
      if slot < 0 || slot >= rec_types.length() {
        return None
      }
      match rec_types[slot] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, results) =>
              Some(@lib.FuncType::new(params, results))
            _ => None
          }
        @lib.GroupRecType(_) => None
      }
    }
    _ => None
  }
}

///|
fn dae_resolve_func_type(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_abs : Int,
) -> @lib.FuncType? {
  if func_abs < 0 || func_abs >= func_type_indices.length() {
    return None
  }
  match mod_.type_sec {
    Some(type_sec) =>
      dae_type_sec_func_type(type_sec, func_type_indices[func_abs])
    None => None
  }
}

///|
fn dae_collect_exported_funcs(
  mod_ : @lib.Module,
  total_funcs : Int,
) -> Array[Bool] {
  let escaped = Array::make(total_funcs, false)
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.FuncExternIdx(func_idx)) => {
            let slot = dae_func_idx_slot(func_idx)
            if slot >= 0 && slot < escaped.length() {
              escaped[slot] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) => {
      let slot = dae_func_idx_slot(func_idx)
      if slot >= 0 && slot < escaped.length() {
        escaped[slot] = true
      }
    }
    None => ()
  }
  escaped
}

///|
fn dae_mark_elem_escapes(kind : @lib.ElemKind, escaped : Array[Bool]) -> Unit {
  match kind {
    @lib.FuncsElemKind(funcs) =>
      for func_idx in funcs {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < escaped.length() {
          escaped[slot] = true
        }
      }
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        let @lib.Expr(instrs) = expr
        dae_scan_escapes_instrs(instrs, escaped)
      }
  }
}

///|
fn dae_scan_escapes_instrs(
  instrs : Array[@lib.Instruction],
  escaped : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.RefFunc(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < escaped.length() {
          escaped[slot] = true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_scan_escapes_instrs(body, escaped)
      @lib.If(_, then_body, Some(else_body)) => {
        dae_scan_escapes_instrs(then_body, escaped)
        dae_scan_escapes_instrs(else_body, escaped)
      }
      @lib.If(_, then_body, None) => dae_scan_escapes_instrs(then_body, escaped)
      _ => ()
    }
  }
}

///|
fn dae_collect_escapes(mod_ : @lib.Module, total_funcs : Int) -> Array[Bool] {
  let escaped = dae_collect_exported_funcs(mod_, total_funcs)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        dae_scan_escapes_instrs(body, escaped)
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(_, kind) = elem
        dae_mark_elem_escapes(kind, escaped)
      }
    None => ()
  }
  escaped
}

///|
fn dae_scan_calls_instrs(
  instrs : Array[@lib.Instruction],
  direct_calls : Array[Int],
  tail_calls : Array[Bool],
) -> Unit {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      break
    }
    match instrs[idx] {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < direct_calls.length() {
          direct_calls[slot] = direct_calls[slot] + 1
        }
      }
      @lib.ReturnCall(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < tail_calls.length() {
          tail_calls[slot] = true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_scan_calls_instrs(body, direct_calls, tail_calls)
      @lib.If(_, then_body, Some(else_body)) => {
        dae_scan_calls_instrs(then_body, direct_calls, tail_calls)
        dae_scan_calls_instrs(else_body, direct_calls, tail_calls)
      }
      @lib.If(_, then_body, None) =>
        dae_scan_calls_instrs(then_body, direct_calls, tail_calls)
      _ => ()
    }
    idx += 1
  }
}

///|
fn dae_collect_calls(
  mod_ : @lib.Module,
  total_funcs : Int,
) -> (Array[Int], Array[Bool]) {
  let direct_calls = Array::make(total_funcs, 0)
  let tail_calls = Array::make(total_funcs, false)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        dae_scan_calls_instrs(body, direct_calls, tail_calls)
      }
    None => ()
  }
  (direct_calls, tail_calls)
}

///|
fn dae_mark_self_forwarded_param_gets(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
  ignored : Array[Bool],
) -> Unit {
  if param_count == 0 {
    return
  }
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs => {
        let start = idx - param_count
        if start >= 0 {
          let mut ok = true
          let mut p = 0
          while p < param_count {
            match instrs[start + p] {
              @lib.LocalGet(local_idx) if dae_local_idx_slot(local_idx) == p =>
                ()
              _ => ok = false
            }
            p += 1
          }
          if ok {
            p = 0
            while p < param_count {
              ignored[start + p] = true
              p += 1
            }
          }
        }
      }
      _ => ()
    }
    idx += 1
  }
}

///|
fn dae_scan_local_use_ignoring_instrs(
  instrs : Array[@lib.Instruction],
  local_use : DaeLocalUse,
  callee_abs : Int,
  param_count : Int,
) -> Unit {
  let ignored = Array::make(instrs.length(), false)
  dae_mark_self_forwarded_param_gets(instrs, callee_abs, param_count, ignored)
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      break
    }
    if !ignored[idx] {
      match instrs[idx] {
        @lib.LocalGet(local_idx) => {
          let slot = dae_local_idx_slot(local_idx)
          if slot >= 0 && slot < local_use.gets.length() {
            local_use.gets[slot] = true
          }
        }
        @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) => {
          let slot = dae_local_idx_slot(local_idx)
          if slot >= 0 && slot < local_use.writes.length() {
            local_use.writes[slot] = true
          }
        }
        @lib.Block(_, @lib.Expr(body))
        | @lib.Loop(_, @lib.Expr(body))
        | @lib.TryTable(_, _, @lib.Expr(body)) =>
          dae_scan_local_use_ignoring_instrs(
            body, local_use, callee_abs, param_count,
          )
        @lib.If(_, then_body, Some(else_body)) => {
          dae_scan_local_use_ignoring_instrs(
            then_body, local_use, callee_abs, param_count,
          )
          dae_scan_local_use_ignoring_instrs(
            else_body, local_use, callee_abs, param_count,
          )
        }
        @lib.If(_, then_body, None) =>
          dae_scan_local_use_ignoring_instrs(
            then_body, local_use, callee_abs, param_count,
          )
        _ => ()
      }
    }
    idx += 1
  }
}

///|
fn dae_local_use_for_callee(
  func : @lib.Func,
  total_locals : Int,
  callee_abs : Int,
  param_count : Int,
) -> DaeLocalUse {
  let local_use = {
    gets: Array::make(total_locals, false),
    writes: Array::make(total_locals, false),
  }
  let @lib.Func(_, @lib.Expr(body)) = func
  dae_scan_local_use_ignoring_instrs(body, local_use, callee_abs, param_count)
  local_use
}

///|
fn dae_instr_result_arity_from_block_type(block_type : @lib.BlockType) -> Int? {
  match block_type {
    @lib.VoidBlockType => Some(0)
    @lib.ValTypeBlockType(_) => Some(1)
    @lib.TypeIdxBlockType(_) => None
  }
}

///|
fn dae_instr_stack_effect(
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Int, Int)? {
  match instr {
    @lib.Unreachable | @lib.Nop => Some((0, 0))
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_)
    | @lib.GlobalGet(_)
    | @lib.LocalGet(_)
    | @lib.TableSize(_)
    | @lib.MemorySize(_) => Some((0, 1))
    @lib.LocalSet(_) | @lib.GlobalSet(_) => Some((1, 0))
    @lib.LocalTee(_) => Some((1, 1))
    @lib.Drop => Some((1, 0))
    @lib.Select(_) => Some((3, 1))
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.RefIsNull
    | @lib.RefAsNonNull
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.I32WrapI64
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32ReinterpretF32
    | @lib.I64ReinterpretF64
    | @lib.F32ReinterpretI32
    | @lib.F64ReinterpretI64
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.RefEq
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.I32TruncSatF32S
    | @lib.I32TruncSatF32U
    | @lib.I32TruncSatF64S
    | @lib.I32TruncSatF64U
    | @lib.I64TruncSatF32S
    | @lib.I64TruncSatF32U
    | @lib.I64TruncSatF64S
    | @lib.I64TruncSatF64U => Some((1, 1))
    @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => Some((2, 1))
    @lib.Call(func_idx) | @lib.ReturnCall(func_idx) => {
      let slot = dae_func_idx_slot(func_idx)
      match dae_resolve_func_type(mod_, func_type_indices, slot) {
        Some(@lib.FuncType(params, results)) =>
          Some((params.length(), results.length()))
        None => None
      }
    }
    @lib.CallIndirect(type_idx, _) | @lib.ReturnCallIndirect(type_idx, _) =>
      match mod_.type_sec {
        Some(type_sec) =>
          match dae_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, results)) =>
              Some((params.length() + 1, results.length()))
            None => None
          }
        None => None
      }
    @lib.CallRef(type_idx) | @lib.ReturnCallRef(type_idx) =>
      match mod_.type_sec {
        Some(type_sec) =>
          match dae_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, results)) =>
              Some((params.length() + 1, results.length()))
            None => None
          }
        None => None
      }
    @lib.Block(block_type, _)
    | @lib.Loop(block_type, _)
    | @lib.TryTable(block_type, _, _) =>
      match dae_instr_result_arity_from_block_type(block_type) {
        Some(out) => Some((0, out))
        None => None
      }
    @lib.If(block_type, _, _) =>
      match dae_instr_result_arity_from_block_type(block_type) {
        Some(out) => Some((1, out))
        None => None
      }
    _ => None
  }
}

///|
fn dae_instr_is_trivially_droppable(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_)
    | @lib.LocalGet(_)
    | @lib.GlobalGet(_) => true
    _ => false
  }
}

///|
fn dae_slice_is_trivially_droppable(
  instrs : Array[@lib.Instruction],
  start : Int,
  end : Int,
) -> Bool {
  let mut idx = start
  while idx < end {
    if !dae_instr_is_trivially_droppable(instrs[idx]) {
      return false
    }
    idx += 1
  }
  true
}

///|
fn dae_find_value_slice(
  instrs : Array[@lib.Instruction],
  end : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> DaeCallShape? {
  let mut need = 1
  let mut idx = end - 1
  while idx >= 0 {
    let (ins, outs) = match
      dae_instr_stack_effect(instrs[idx], mod_, func_type_indices) {
      Some(effect) => effect
      None => return None
    }
    if outs == 0 && need > 0 {
      return None
    }
    need = need - outs + ins
    if need <= 0 {
      return Some({
        start: idx,
        end,
        pure: dae_slice_is_trivially_droppable(instrs, idx, end),
      })
    }
    idx -= 1
  }
  None
}

///|
fn dae_rewrite_instruction_locals(
  instr : @lib.Instruction,
  local_map : Array[Int],
) -> @lib.Instruction {
  match instr {
    @lib.LocalGet(idx) =>
      @lib.Instruction::local_get(
        dae_rewrite_local_idx(dae_local_idx_slot(idx), local_map),
      )
    @lib.LocalSet(idx) =>
      @lib.Instruction::local_set(
        dae_rewrite_local_idx(dae_local_idx_slot(idx), local_map),
      )
    @lib.LocalTee(idx) =>
      @lib.Instruction::local_tee(
        dae_rewrite_local_idx(dae_local_idx_slot(idx), local_map),
      )
    @lib.Block(block_type, @lib.Expr(body)) =>
      @lib.Instruction::block(
        block_type,
        @lib.Expr::new(dae_rewrite_locals_instrs(body, local_map)),
      )
    @lib.Loop(block_type, @lib.Expr(body)) =>
      @lib.Instruction::loop_(
        block_type,
        @lib.Expr::new(dae_rewrite_locals_instrs(body, local_map)),
      )
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        @lib.Expr::new(dae_rewrite_locals_instrs(body, local_map)),
      )
    @lib.If(block_type, then_body, else_body) =>
      @lib.Instruction::if_(
        block_type,
        dae_rewrite_locals_instrs(then_body, local_map),
        match else_body {
          Some(body) => Some(dae_rewrite_locals_instrs(body, local_map))
          None => None
        },
      )
    _ => instr
  }
}

///|
fn dae_rewrite_locals_instrs(
  instrs : Array[@lib.Instruction],
  local_map : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(dae_rewrite_instruction_locals(instr, local_map))
  }
  out
}

///|
fn dae_build_local_map(
  param_count : Int,
  body_local_count : Int,
  remove : Array[Bool],
  local_use : DaeLocalUse,
) -> Array[Int] {
  let local_map = Array::make(param_count + body_local_count, -1)
  let mut next_param = 0
  let mut removed_local_count = 0
  for idx = 0; idx < param_count; idx = idx + 1 {
    if remove[idx] {
      if local_use.writes[idx] {
        // The incoming value is dead, but writes to the old param slot still need
        // a valid local target until the nested cleanup removes them.
        local_map[idx] = -1 - removed_local_count
        removed_local_count += 1
      }
    } else {
      local_map[idx] = next_param
      next_param += 1
    }
  }
  let mut idx = 0
  while idx < param_count {
    if local_map[idx] < 0 {
      local_map[idx] = next_param + (-1 - local_map[idx])
    }
    idx += 1
  }
  let mut body_idx = 0
  while body_idx < body_local_count {
    local_map[param_count + body_idx] = next_param +
      removed_local_count +
      body_idx
    body_idx += 1
  }
  local_map
}

///|
fn dae_rewrite_callsite_at(
  instrs : Array[@lib.Instruction],
  call_idx : Int,
  remove : Array[Bool],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Array[@lib.Instruction], Bool) {
  let shapes = Array::make(remove.length(), { start: 0, end: 0, pure: false })
  let mut cursor = call_idx
  let mut arg_idx = remove.length() - 1
  while arg_idx >= 0 {
    match dae_find_value_slice(instrs, cursor, mod_, func_type_indices) {
      Some(shape) => {
        shapes[arg_idx] = shape
        cursor = shape.start
      }
      None => return ([], false)
    }
    arg_idx -= 1
  }
  let out : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < cursor {
    out.push(instrs[idx])
    idx += 1
  }
  let mut p = 0
  while p < remove.length() {
    let shape = shapes[p]
    if remove[p] {
      if !shape.pure {
        let mut j = shape.start
        while j < shape.end {
          out.push(instrs[j])
          j += 1
        }
        out.push(@lib.Instruction::drop())
      }
    } else {
      let mut j = shape.start
      while j < shape.end {
        out.push(instrs[j])
        j += 1
      }
    }
    p += 1
  }
  out.push(instrs[call_idx])
  idx = call_idx + 1
  while idx < instrs.length() {
    out.push(instrs[idx])
    idx += 1
  }
  (out, true)
}

///|
fn dae_rewrite_calls_instr(
  instr : @lib.Instruction,
  callee_abs : Int,
  remove : Array[Bool],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (@lib.Instruction, Int, Bool) {
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let result = dae_rewrite_calls_instrs(
        body, callee_abs, remove, mod_, func_type_indices,
      )
      (
        @lib.Instruction::block(block_type, @lib.Expr::new(result.instrs)),
        result.calls_rewritten,
        result.ok,
      )
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let result = dae_rewrite_calls_instrs(
        body, callee_abs, remove, mod_, func_type_indices,
      )
      (
        @lib.Instruction::loop_(block_type, @lib.Expr::new(result.instrs)),
        result.calls_rewritten,
        result.ok,
      )
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let result = dae_rewrite_calls_instrs(
        body, callee_abs, remove, mod_, func_type_indices,
      )
      (
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(result.instrs),
        ),
        result.calls_rewritten,
        result.ok,
      )
    }
    @lib.If(block_type, then_body, else_body) => {
      let then_result = dae_rewrite_calls_instrs(
        then_body, callee_abs, remove, mod_, func_type_indices,
      )
      if !then_result.ok {
        return (instr, then_result.calls_rewritten, false)
      }
      let mut calls = then_result.calls_rewritten
      let rewritten_else = match else_body {
        Some(body) => {
          let else_result = dae_rewrite_calls_instrs(
            body, callee_abs, remove, mod_, func_type_indices,
          )
          calls += else_result.calls_rewritten
          if !else_result.ok {
            return (instr, calls, false)
          }
          Some(else_result.instrs)
        }
        None => None
      }
      (
        @lib.Instruction::if_(block_type, then_result.instrs, rewritten_else),
        calls,
        true,
      )
    }
    _ => (instr, 0, true)
  }
}

///|
fn dae_find_next_direct_call(
  instrs : Array[@lib.Instruction],
  start : Int,
  callee_abs : Int,
) -> Int? {
  let mut idx = start
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        return Some(idx)
      _ => ()
    }
    idx += 1
  }
  None
}

///|
fn dae_rewrite_calls_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  remove : Array[Bool],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> DaeRewriteResult {
  let out : Array[@lib.Instruction] = []
  let mut idx = 0
  let mut calls = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      out.push(@lib.Instruction::unreachable_())
      break
    }
    match instrs[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs => {
        let prefix = out
        let suffix : Array[@lib.Instruction] = []
        let mut tail = idx
        while tail < instrs.length() {
          suffix.push(instrs[tail])
          tail += 1
        }
        let joined : Array[@lib.Instruction] = []
        joined.append(prefix)
        joined.append(suffix)
        let (rewritten, ok) = dae_rewrite_callsite_at(
          joined,
          prefix.length(),
          remove,
          mod_,
          func_type_indices,
        )
        if !ok {
          return { instrs: [], calls_rewritten: calls, ok: false }
        }
        let next_start = match
          dae_find_next_direct_call(rewritten, prefix.length(), callee_abs) {
          Some(call_pos) => call_pos + 1
          None => prefix.length() + 1
        }
        return dae_rewrite_calls_instrs_after_rewritten(
          rewritten,
          next_start,
          callee_abs,
          remove,
          mod_,
          func_type_indices,
          calls + 1,
        )
      }
      _ => {
        let (rewritten, nested_calls, ok) = dae_rewrite_calls_instr(
          instrs[idx],
          callee_abs,
          remove,
          mod_,
          func_type_indices,
        )
        if !ok {
          return {
            instrs: [],
            calls_rewritten: calls + nested_calls,
            ok: false,
          }
        }
        calls += nested_calls
        out.push(rewritten)
      }
    }
    idx += 1
  }
  { instrs: out, calls_rewritten: calls, ok: true }
}

///|
fn dae_rewrite_calls_instrs_after_rewritten(
  instrs : Array[@lib.Instruction],
  start_idx : Int,
  callee_abs : Int,
  remove : Array[Bool],
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  calls_so_far : Int,
) -> DaeRewriteResult {
  let prefix : Array[@lib.Instruction] = []
  let mut i = 0
  while i < start_idx && i < instrs.length() {
    prefix.push(instrs[i])
    i += 1
  }
  let tail : Array[@lib.Instruction] = []
  while i < instrs.length() {
    tail.push(instrs[i])
    i += 1
  }
  let tail_result = dae_rewrite_calls_instrs(
    tail, callee_abs, remove, mod_, func_type_indices,
  )
  if !tail_result.ok {
    return {
      instrs: [],
      calls_rewritten: calls_so_far + tail_result.calls_rewritten,
      ok: false,
    }
  }
  prefix.append(tail_result.instrs)
  {
    instrs: prefix,
    calls_rewritten: calls_so_far + tail_result.calls_rewritten,
    ok: true,
  }
}

///|
fn dae_type_idx_slot(idx : @lib.TypeIdx) -> Int? {
  match idx {
    @lib.TypeIdx(raw) => Some(raw.reinterpret_as_int())
    @lib.RecIdx(_) => None
  }
}

///|
fn dae_simple_func_type_section(rec_types : Array[@lib.RecType]) -> Bool {
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(subtype) => {
        if subtype.super_types().length() > 0 ||
          subtype.describes_type() is Some(_) ||
          subtype.descriptor_type() is Some(_) {
          return false
        }
        match subtype.get_comptype() {
          @lib.FuncCompType(_, _) => ()
          _ => return false
        }
      }
      @lib.GroupRecType(_) => return false
    }
  }
  true
}

///|
fn dae_mark_used_type_idx(idx : @lib.TypeIdx, used : Array[Bool]) -> Unit {
  match dae_type_idx_slot(idx) {
    Some(slot) => if slot >= 0 && slot < used.length() { used[slot] = true }
    None => ()
  }
}

///|
fn dae_collect_used_type_idx_instrs(
  instrs : Array[@lib.Instruction],
  used : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Block(@lib.TypeIdxBlockType(type_idx), @lib.Expr(body))
      | @lib.Loop(@lib.TypeIdxBlockType(type_idx), @lib.Expr(body))
      | @lib.TryTable(@lib.TypeIdxBlockType(type_idx), _, @lib.Expr(body)) => {
        dae_mark_used_type_idx(type_idx, used)
        dae_collect_used_type_idx_instrs(body, used)
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_collect_used_type_idx_instrs(body, used)
      @lib.If(@lib.TypeIdxBlockType(type_idx), then_body, else_body) => {
        dae_mark_used_type_idx(type_idx, used)
        dae_collect_used_type_idx_instrs(then_body, used)
        match else_body {
          Some(body) => dae_collect_used_type_idx_instrs(body, used)
          None => ()
        }
      }
      @lib.If(_, then_body, else_body) => {
        dae_collect_used_type_idx_instrs(then_body, used)
        match else_body {
          Some(body) => dae_collect_used_type_idx_instrs(body, used)
          None => ()
        }
      }
      @lib.CallIndirect(type_idx, _)
      | @lib.ReturnCallIndirect(type_idx, _)
      | @lib.CallRef(type_idx)
      | @lib.ReturnCallRef(type_idx)
      | @lib.StructNew(type_idx)
      | @lib.StructNewDefault(type_idx)
      | @lib.StructNewDesc(type_idx)
      | @lib.StructNewDefaultDesc(type_idx)
      | @lib.ArrayNew(type_idx)
      | @lib.ArrayNewDefault(type_idx)
      | @lib.ArrayNewFixed(type_idx, _)
      | @lib.ArrayNewData(type_idx, _)
      | @lib.ArrayNewElem(type_idx, _)
      | @lib.ArrayGet(type_idx)
      | @lib.ArrayGetS(type_idx)
      | @lib.ArrayGetU(type_idx)
      | @lib.ArraySet(type_idx)
      | @lib.ArrayFill(type_idx)
      | @lib.ArrayInitData(type_idx, _)
      | @lib.ArrayInitElem(type_idx, _)
      | @lib.RefGetDesc(type_idx) => dae_mark_used_type_idx(type_idx, used)
      @lib.StructGet(type_idx, _)
      | @lib.StructGetS(type_idx, _)
      | @lib.StructGetU(type_idx, _)
      | @lib.StructSet(type_idx, _) => dae_mark_used_type_idx(type_idx, used)
      _ => ()
    }
  }
}

///|
fn dae_rewrite_pruned_type_idx(
  idx : @lib.TypeIdx,
  remap : Array[Int],
) -> @lib.TypeIdx {
  match idx {
    @lib.TypeIdx(raw) => {
      let slot = raw.reinterpret_as_int()
      if slot >= 0 && slot < remap.length() && remap[slot] >= 0 {
        @lib.TypeIdx::new(remap[slot].reinterpret_as_uint())
      } else {
        idx
      }
    }
    @lib.RecIdx(_) => idx
  }
}

///|
fn dae_rewrite_pruned_type_idx_instr(
  instr : @lib.Instruction,
  remap : Array[Int],
) -> @lib.Instruction {
  let rewrite_block_type = fn(block_type : @lib.BlockType) -> @lib.BlockType {
    match block_type {
      @lib.TypeIdxBlockType(type_idx) =>
        @lib.BlockType::type_idx(dae_rewrite_pruned_type_idx(type_idx, remap))
      _ => block_type
    }
  }
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) =>
      @lib.Instruction::block(
        rewrite_block_type(block_type),
        @lib.Expr::new(dae_rewrite_pruned_type_idx_instrs(body, remap)),
      )
    @lib.Loop(block_type, @lib.Expr(body)) =>
      @lib.Instruction::loop_(
        rewrite_block_type(block_type),
        @lib.Expr::new(dae_rewrite_pruned_type_idx_instrs(body, remap)),
      )
    @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(
        rewrite_block_type(block_type),
        catches,
        @lib.Expr::new(dae_rewrite_pruned_type_idx_instrs(body, remap)),
      )
    @lib.If(block_type, then_body, else_body) =>
      @lib.Instruction::if_(
        rewrite_block_type(block_type),
        dae_rewrite_pruned_type_idx_instrs(then_body, remap),
        match else_body {
          Some(body) => Some(dae_rewrite_pruned_type_idx_instrs(body, remap))
          None => None
        },
      )
    @lib.CallIndirect(type_idx, table_idx) =>
      @lib.Instruction::call_indirect(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      @lib.Instruction::return_call_indirect(
        dae_rewrite_pruned_type_idx(type_idx, remap),
        table_idx,
      )
    @lib.CallRef(type_idx) =>
      @lib.Instruction::call_ref(dae_rewrite_pruned_type_idx(type_idx, remap))
    @lib.ReturnCallRef(type_idx) =>
      @lib.Instruction::return_call_ref(
        dae_rewrite_pruned_type_idx(type_idx, remap),
      )
    _ => instr
  }
}

///|
fn dae_rewrite_pruned_type_idx_instrs(
  instrs : Array[@lib.Instruction],
  remap : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(dae_rewrite_pruned_type_idx_instr(instr, remap))
  }
  out
}

///|
fn dae_prune_unused_simple_func_types(mod_ : @lib.Module) -> @lib.Module {
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types
    None => return mod_
  }
  if !dae_simple_func_type_section(rec_types) {
    return mod_
  }
  let used = Array::make(rec_types.length(), false)
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            dae_mark_used_type_idx(type_idx, used)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        dae_mark_used_type_idx(type_idx, used)
      }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) =>
      for tag in tags {
        let @lib.TagType(type_idx) = tag
        dae_mark_used_type_idx(type_idx, used)
      }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        dae_collect_used_type_idx_instrs(body, used)
      }
    None => ()
  }
  let remap = Array::make(rec_types.length(), -1)
  let next_types : Array[@lib.RecType] = []
  let mut old_idx = 0
  while old_idx < rec_types.length() {
    if used[old_idx] {
      remap[old_idx] = next_types.length()
      next_types.push(rec_types[old_idx])
    }
    old_idx += 1
  }
  if next_types.length() == rec_types.length() {
    return mod_
  }
  let mut next = mod_
    .with_type_sec(@lib.TypeSec::new(next_types))
    .without_name_sec()
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let rewritten : Array[@lib.Import] = []
      for import_ in imports {
        match import_ {
          @lib.Import(module_name, base_name, @lib.FuncExternType(type_idx)) =>
            rewritten.push(
              @lib.Import::new(
                module_name,
                base_name,
                @lib.ExternType::func(
                  dae_rewrite_pruned_type_idx(type_idx, remap),
                ),
              ),
            )
          _ => rewritten.push(import_)
        }
      }
      next = next.with_import_sec(@lib.ImportSec::new(rewritten))
    }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      let rewritten : Array[@lib.TypeIdx] = []
      for type_idx in type_idxs {
        rewritten.push(dae_rewrite_pruned_type_idx(type_idx, remap))
      }
      next = next.with_func_sec(@lib.FuncSec::new(rewritten))
    }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) => {
      let rewritten : Array[@lib.TagType] = []
      for tag in tags {
        let @lib.TagType(type_idx) = tag
        rewritten.push(
          @lib.TagType::new(dae_rewrite_pruned_type_idx(type_idx, remap)),
        )
      }
      next = next.with_tag_sec(@lib.TagSec::new(rewritten))
    }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let rewritten : Array[@lib.Func] = []
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(body)) = func
        rewritten.push(
          @lib.Func::new(
            locals,
            @lib.Expr::new(dae_rewrite_pruned_type_idx_instrs(body, remap)),
          ),
        )
      }
      next = next.with_code_sec(@lib.CodeSec::new(rewritten))
    }
    None => ()
  }
  next
}

///|
fn dae_append_new_func_type(
  type_sec : @lib.TypeSec,
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> (@lib.TypeSec, @lib.TypeIdx) {
  let @lib.TypeSec(rec_types) = type_sec
  let next = rec_types.copy()
  let idx = @lib.TypeIdx::new(next.length().reinterpret_as_uint())
  next.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func(params, results)),
    ),
  )
  (@lib.TypeSec::new(next), idx)
}

///|
fn dae_try_rewrite_candidate(
  mod_ : @lib.Module,
  callee_abs : Int,
  remove : Array[Bool],
  local_use : DaeLocalUse,
  direct_call_count : Int,
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let def_idx = callee_abs - imported
  let type_indices = dae_collect_func_type_indices(mod_)
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, results) = func_type
  let (func_types, funcs) = match
    (mod_.func_sec, mod_.code_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(_)) =>
      (type_idxs.copy(), funcs.copy())
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let rewritten_funcs = funcs.copy()
  let mut rewritten_calls = 0
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(locals, @lib.Expr(body)) = rewritten_funcs[caller_def]
    let result = dae_rewrite_calls_instrs(
      body, callee_abs, remove, mod_, type_indices,
    )
    if !result.ok {
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
    }
    if result.calls_rewritten > 0 {
      rewritten_funcs[caller_def] = @lib.Func::new(
        locals,
        @lib.Expr::new(result.instrs),
      )
      rewritten_calls += result.calls_rewritten
    }
    caller_def += 1
  }
  if rewritten_calls != direct_call_count {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let kept_params : Array[@lib.ValType] = []
  let removed_written_types : Array[@lib.ValType] = []
  let mut p = 0
  while p < params.length() {
    if remove[p] {
      if local_use.writes[p] {
        removed_written_types.push(params[p])
      }
    } else {
      kept_params.push(params[p])
    }
    p += 1
  }
  let @lib.Func(old_locals, @lib.Expr(old_body)) = rewritten_funcs[def_idx]
  let body_local_count = old_locals.length()
  let local_map = dae_build_local_map(
    params.length(),
    body_local_count,
    remove,
    local_use,
  )
  let new_body = dae_rewrite_locals_instrs(old_body, local_map)
  let new_locals = @lib.Locals::from_types(removed_written_types)
  new_locals.append(old_locals)
  rewritten_funcs[def_idx] = dae_simplify_to_unreachable_when_prefix_unobservable(
    @lib.Func::new(new_locals, @lib.Expr::new(new_body)),
  )

  let (next_type_sec, new_type_idx) = match mod_.type_sec {
    Some(type_sec) => dae_append_new_func_type(type_sec, kept_params, results)
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  func_types[def_idx] = new_type_idx
  let next_mod = mod_
    .with_type_sec(next_type_sec)
    .with_func_sec(@lib.FuncSec::new(func_types))
    .with_code_sec(@lib.CodeSec::new(rewritten_funcs))
    .without_name_sec()
  let touched = Array::make(funcs.length(), false)
  touched[def_idx] = true
  caller_def = 0
  while caller_def < funcs.length() {
    let before = funcs[caller_def]
    let after = match next_mod.code_sec {
      Some(@lib.CodeSec(next_funcs)) => next_funcs[caller_def]
      None => before
    }
    if before != after {
      touched[caller_def] = true
    }
    caller_def += 1
  }
  { mod_out: next_mod, touched, changed: true, primary_def: def_idx }
}

///|
fn dae_instr_has_observable_effect(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Call(_)
    | @lib.CallIndirect(_, _)
    | @lib.CallRef(_)
    | @lib.ReturnCall(_)
    | @lib.ReturnCallIndirect(_, _)
    | @lib.ReturnCallRef(_)
    | @lib.GlobalSet(_)
    | @lib.TableSet(_)
    | @lib.MemoryGrow(_)
    | @lib.I32Store(_)
    | @lib.I64Store(_)
    | @lib.F32Store(_)
    | @lib.F64Store(_)
    | @lib.I32Store8(_)
    | @lib.I32Store16(_)
    | @lib.I64Store8(_)
    | @lib.I64Store16(_)
    | @lib.I64Store32(_)
    | @lib.Throw(_)
    | @lib.ThrowRef
    | @lib.AtomicFence
    | @lib.MemoryAtomicNotify(_)
    | @lib.MemoryAtomicWait32(_)
    | @lib.MemoryAtomicWait64(_)
    | @lib.I32AtomicStore(_)
    | @lib.I64AtomicStore(_)
    | @lib.I32AtomicStore8(_)
    | @lib.I32AtomicStore16(_)
    | @lib.I64AtomicStore8(_)
    | @lib.I64AtomicStore16(_)
    | @lib.I64AtomicStore32(_)
    | @lib.AtomicRmw(_, _)
    | @lib.AtomicCmpxchg(_, _) => true
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      body.any(fn(child) { dae_instr_has_observable_effect(child) })
    @lib.If(_, then_body, Some(else_body)) =>
      then_body.any(fn(child) { dae_instr_has_observable_effect(child) }) ||
      else_body.any(fn(child) { dae_instr_has_observable_effect(child) })
    @lib.If(_, then_body, None) =>
      then_body.any(fn(child) { dae_instr_has_observable_effect(child) })
    _ => false
  }
}

///|
fn dae_instr_is_unreachable_root(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable => true
    @lib.Block(_, @lib.Expr(body)) =>
      body.length() == 1 && dae_instr_is_unreachable_root(body[0])
    _ => false
  }
}

///|
fn dae_simplify_to_unreachable_when_prefix_unobservable(
  func : @lib.Func,
) -> @lib.Func {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let mut idx = 0
  while idx < body.length() {
    if dae_instr_is_unreachable_root(body[idx]) {
      let mut prefix_idx = 0
      while prefix_idx < idx {
        if dae_instr_has_observable_effect(body[prefix_idx]) {
          return func
        }
        prefix_idx += 1
      }
      ignore(locals)
      return @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      )
    }
    idx += 1
  }
  func
}

///|
fn dae_rewrite_dropped_result_calls_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> (Array[@lib.Instruction], Int) {
  let out : Array[@lib.Instruction] = []
  let mut rewrites = 0
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      out.push(@lib.Instruction::unreachable_())
      break
    }
    if idx + 1 < instrs.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.Call(func_idx), @lib.Drop) if dae_func_idx_slot(func_idx) ==
          callee_abs => {
          out.push(instrs[idx])
          rewrites += 1
          idx += 2
          continue
        }
        _ => ()
      }
    }
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (rewritten, nested) = dae_rewrite_dropped_result_calls_instrs(
          body, callee_abs,
        )
        out.push(@lib.Instruction::block(block_type, @lib.Expr::new(rewritten)))
        rewrites += nested
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (rewritten, nested) = dae_rewrite_dropped_result_calls_instrs(
          body, callee_abs,
        )
        out.push(@lib.Instruction::loop_(block_type, @lib.Expr::new(rewritten)))
        rewrites += nested
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (rewritten, nested) = dae_rewrite_dropped_result_calls_instrs(
          body, callee_abs,
        )
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(rewritten),
          ),
        )
        rewrites += nested
      }
      @lib.If(block_type, then_body, else_body) => {
        let (then_rewritten, then_nested) = dae_rewrite_dropped_result_calls_instrs(
          then_body, callee_abs,
        )
        rewrites += then_nested
        let rewritten_else = match else_body {
          Some(body) => {
            let (else_rewritten, else_nested) = dae_rewrite_dropped_result_calls_instrs(
              body, callee_abs,
            )
            rewrites += else_nested
            Some(else_rewritten)
          }
          None => None
        }
        out.push(
          @lib.Instruction::if_(block_type, then_rewritten, rewritten_else),
        )
      }
      _ => out.push(instrs[idx])
    }
    idx += 1
  }
  (out, rewrites)
}

///|
fn dae_count_dropped_direct_calls_instrs(
  instrs : Array[@lib.Instruction],
  dropped_calls : Array[Int],
) -> Unit {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      break
    }
    if idx + 1 < instrs.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.Call(func_idx), @lib.Drop) => {
          let slot = dae_func_idx_slot(func_idx)
          if slot >= 0 && slot < dropped_calls.length() {
            dropped_calls[slot] = dropped_calls[slot] + 1
          }
        }
        _ => ()
      }
    }
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_count_dropped_direct_calls_instrs(body, dropped_calls)
      @lib.If(_, then_body, Some(else_body)) => {
        dae_count_dropped_direct_calls_instrs(then_body, dropped_calls)
        dae_count_dropped_direct_calls_instrs(else_body, dropped_calls)
      }
      @lib.If(_, then_body, None) =>
        dae_count_dropped_direct_calls_instrs(then_body, dropped_calls)
      _ => ()
    }
    idx += 1
  }
}

///|
fn dae_collect_dropped_direct_calls(
  mod_ : @lib.Module,
  total_funcs : Int,
) -> Array[Int] {
  let dropped_calls = Array::make(total_funcs, 0)
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        dae_count_dropped_direct_calls_instrs(body, dropped_calls)
      }
    None => ()
  }
  dropped_calls
}

///|
fn dae_try_remove_dropped_results(
  mod_ : @lib.Module,
  callee_abs : Int,
  direct_call_count : Int,
  dropped_call_count : Int,
) -> DaePassResult {
  if direct_call_count == 0 || dropped_call_count != direct_call_count {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let imported = dae_imported_func_count(mod_)
  let def_idx = callee_abs - imported
  let type_indices = dae_collect_func_type_indices(mod_)
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, results) = func_type
  if results.length() != 1 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let (type_idxs, funcs, type_sec) = match
    (mod_.func_sec, mod_.code_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(type_sec)) =>
      (type_idxs.copy(), funcs.copy(), type_sec)
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  if direct_call_count == dae_count_self_calls(funcs[def_idx], callee_abs) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let rewritten_funcs = funcs.copy()
  let mut rewritten_call_count = 0
  let mut caller_def = 0
  while caller_def < rewritten_funcs.length() {
    let @lib.Func(locals, @lib.Expr(body)) = rewritten_funcs[caller_def]
    let (rewritten_body, rewrites) = dae_rewrite_dropped_result_calls_instrs(
      body, callee_abs,
    )
    if rewrites > 0 {
      rewritten_funcs[caller_def] = @lib.Func::new(
        locals,
        @lib.Expr::new(rewritten_body),
      )
      rewritten_call_count += rewrites
    }
    caller_def += 1
  }
  if rewritten_call_count != direct_call_count {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.Func(callee_locals, @lib.Expr(callee_body)) = rewritten_funcs[def_idx]
  let next_callee_body = callee_body.copy()
  next_callee_body.push(@lib.Instruction::drop())
  rewritten_funcs[def_idx] = dae_simplify_to_unreachable_when_prefix_unobservable(
    @lib.Func::new(callee_locals, @lib.Expr::new(next_callee_body)),
  )
  let (next_type_sec, new_type_idx) = dae_append_new_func_type(
    type_sec,
    params,
    [],
  )
  type_idxs[def_idx] = new_type_idx
  let touched = Array::make(funcs.length(), false)
  touched[def_idx] = true
  caller_def = 0
  while caller_def < funcs.length() {
    if funcs[caller_def] != rewritten_funcs[caller_def] {
      touched[caller_def] = true
    }
    caller_def += 1
  }
  {
    mod_out: mod_
    .with_type_sec(next_type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(rewritten_funcs))
    .without_name_sec(),
    touched,
    changed: true,
    primary_def: def_idx,
  }
}

///|
fn dae_func_is_unreachable_only(func : @lib.Func) -> Bool {
  let @lib.Func(_, @lib.Expr(body)) = func
  body.length() == 1 && dae_instr_is_unreachable_root(body[0])
}

///|
fn dae_instrs_contain_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae_instrs_contain_direct_call_to(body, callee_abs) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if dae_instrs_contain_direct_call_to(then_body, callee_abs) ||
          dae_instrs_contain_direct_call_to(else_body, callee_abs) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if dae_instrs_contain_direct_call_to(then_body, callee_abs) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn dae_repair_dead_suffix_calls_instr(
  instr : @lib.Instruction,
  callee_abs : Int,
) -> (@lib.Instruction, Bool) {
  match instr {
    @lib.Block(block_type, @lib.Expr(body)) => {
      let (rewritten, changed) = dae_repair_dead_suffix_calls_instrs(
        body, callee_abs,
      )
      (@lib.Instruction::block(block_type, @lib.Expr::new(rewritten)), changed)
    }
    @lib.Loop(block_type, @lib.Expr(body)) => {
      let (rewritten, changed) = dae_repair_dead_suffix_calls_instrs(
        body, callee_abs,
      )
      (@lib.Instruction::loop_(block_type, @lib.Expr::new(rewritten)), changed)
    }
    @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
      let (rewritten, changed) = dae_repair_dead_suffix_calls_instrs(
        body, callee_abs,
      )
      (
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(rewritten),
        ),
        changed,
      )
    }
    @lib.If(block_type, then_body, else_body) => {
      let (then_rewritten, then_changed) = dae_repair_dead_suffix_calls_instrs(
        then_body, callee_abs,
      )
      let mut changed = then_changed
      let rewritten_else = match else_body {
        Some(body) => {
          let (else_rewritten, else_changed) = dae_repair_dead_suffix_calls_instrs(
            body, callee_abs,
          )
          changed = changed || else_changed
          Some(else_rewritten)
        }
        None => None
      }
      (
        @lib.Instruction::if_(block_type, then_rewritten, rewritten_else),
        changed,
      )
    }
    _ => (instr, false)
  }
}

///|
fn dae_repair_dead_suffix_calls_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      if dae_instrs_contain_direct_call_to(suffix, callee_abs) {
        out.push(@lib.Instruction::unreachable_())
        return (out, true)
      }
    }
    let (rewritten, nested_changed) = dae_repair_dead_suffix_calls_instr(
      instrs[idx],
      callee_abs,
    )
    changed = changed || nested_changed
    out.push(rewritten)
    idx += 1
  }
  (out, changed)
}

///|
fn dae_repair_dead_suffix_calls_func(
  func : @lib.Func,
  callee_abs : Int,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let (rewritten, changed) = dae_repair_dead_suffix_calls_instrs(
    body, callee_abs,
  )
  (@lib.Func::new(locals, @lib.Expr::new(rewritten)), changed)
}

///|
fn dae_count_self_calls(func : @lib.Func, callee_abs : Int) -> Int {
  let direct_calls = Array::make(callee_abs + 1, 0)
  let tail_calls = Array::make(callee_abs + 1, false)
  let @lib.Func(_, @lib.Expr(body)) = func
  dae_scan_calls_instrs(body, direct_calls, tail_calls)
  direct_calls[callee_abs]
}

///|
fn dae_count_direct_call_anywhere_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        count += 1
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        count += dae_count_direct_call_anywhere_to(body, callee_abs)
      @lib.If(_, then_body, Some(else_body)) => {
        count += dae_count_direct_call_anywhere_to(then_body, callee_abs)
        count += dae_count_direct_call_anywhere_to(else_body, callee_abs)
      }
      @lib.If(_, then_body, None) =>
        count += dae_count_direct_call_anywhere_to(then_body, callee_abs)
      _ => ()
    }
  }
  count
}

///|
fn dae_count_self_calls_anywhere(func : @lib.Func, callee_abs : Int) -> Int {
  let @lib.Func(_, @lib.Expr(body)) = func
  dae_count_direct_call_anywhere_to(body, callee_abs)
}

///|
fn dae_count_module_calls_anywhere_to(
  funcs : Array[@lib.Func],
  callee_abs : Int,
) -> Int {
  let mut count = 0
  for func in funcs {
    let @lib.Func(_, @lib.Expr(body)) = func
    count += dae_count_direct_call_anywhere_to(body, callee_abs)
  }
  count
}

///|
fn dae_has_undropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        if idx + 1 >= instrs.length() ||
          instrs[idx + 1] != @lib.Instruction::drop() {
          return true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae_has_undropped_direct_call_to(body, callee_abs) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if dae_has_undropped_direct_call_to(then_body, callee_abs) ||
          dae_has_undropped_direct_call_to(else_body, callee_abs) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if dae_has_undropped_direct_call_to(then_body, callee_abs) {
          return true
        }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_has_other_call(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        match instrs[suffix_idx] {
          @lib.Call(func_idx) if dae_func_idx_slot(func_idx) != callee_abs =>
            return true
          _ => ()
        }
        suffix_idx += 1
      }
      return false
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_has_dropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let mut suffix_idx = idx + 1
      while suffix_idx + 1 < instrs.length() {
        match (instrs[suffix_idx], instrs[suffix_idx + 1]) {
          (@lib.Call(func_idx), @lib.Drop) if dae_func_idx_slot(func_idx) ==
            callee_abs => return true
          _ => ()
        }
        suffix_idx += 1
      }
      return false
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_has_undropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return dae_has_undropped_direct_call_to(suffix, callee_abs)
    }
    idx += 1
  }
  false
}

///|
fn dae_self_call_has_adjacent_param_forward(
  instrs : Array[@lib.Instruction],
  call_idx : Int,
  param_count : Int,
) -> Bool {
  let start = call_idx - param_count
  if start < 0 {
    return false
  }
  let mut p = 0
  while p < param_count {
    match instrs[start + p] {
      @lib.LocalGet(local_idx) if dae_local_idx_slot(local_idx) == p => ()
      _ => return false
    }
    p += 1
  }
  true
}

///|
fn dae_collect_self_call_operand_param_gets(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  preserve : Array[Bool],
) -> Unit {
  let stack : Array[Int] = []
  let stack_from_call : Array[Bool] = []
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.LocalGet(local_idx) => {
        let slot = dae_local_idx_slot(local_idx)
        if slot >= 0 && slot < param_count {
          stack.push(slot)
        } else {
          stack.push(-1)
        }
        stack_from_call.push(false)
      }
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs => {
        let mut has_call_operand = false
        let mut p = 0
        while p < param_count {
          let stack_idx = stack.length() - param_count + p
          if stack_idx >= 0 && stack_idx < stack_from_call.length() {
            has_call_operand = has_call_operand || stack_from_call[stack_idx]
          }
          p += 1
        }
        // Binaryen preserves the original param that is stranded beneath a
        // side-call result used by a dead-suffix self call, but still prunes
        // adjacent forwarding and constant/duplicate-local self operands.
        if has_call_operand &&
          !dae_self_call_has_adjacent_param_forward(instrs, idx, param_count) {
          p = 0
          while p < param_count {
            let stack_idx = stack.length() - param_count + p
            if stack_idx >= 0 && stack_idx < stack.length() {
              let origin = stack[stack_idx]
              if origin >= 0 && origin < preserve.length() {
                preserve[origin] = true
              }
            }
            p += 1
          }
        }
        let mut pop = 0
        while pop < param_count && stack.length() > 0 {
          ignore(stack.pop())
          ignore(stack_from_call.pop())
          pop += 1
        }
        match dae_resolve_func_type(mod_, type_indices, callee_abs) {
          Some(@lib.FuncType(_, results)) => {
            let mut r = 0
            while r < results.length() {
              stack.push(-1)
              stack_from_call.push(true)
              r += 1
            }
          }
          None => ()
        }
      }
      @lib.Call(_) =>
        match dae_instr_stack_effect(instrs[idx], mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack.length() > 0 {
              ignore(stack.pop())
              ignore(stack_from_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack.push(-1)
              stack_from_call.push(true)
              push += 1
            }
          }
          None => ()
        }
      _ =>
        match dae_instr_stack_effect(instrs[idx], mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack.length() > 0 {
              ignore(stack.pop())
              ignore(stack_from_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack.push(-1)
              stack_from_call.push(false)
              push += 1
            }
          }
          None => ()
        }
    }
    idx += 1
  }
}

///|
fn dae_collect_dead_suffix_self_operand_params(
  func : @lib.Func,
  callee_abs : Int,
  param_count : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Array[Bool] {
  let preserve = Array::make(param_count, false)
  let @lib.Func(_, @lib.Expr(body)) = func
  let mut idx = 0
  while idx < body.length() {
    if dae_instr_is_unreachable_root(body[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < body.length() {
        suffix.push(body[suffix_idx])
        suffix_idx += 1
      }
      dae_collect_self_call_operand_param_gets(
        suffix, callee_abs, param_count, mod_, type_indices, preserve,
      )
      return preserve
    }
    idx += 1
  }
  preserve
}

///|
fn dae_filter_params(
  params : Array[@lib.ValType],
  keep : Array[Bool],
) -> Array[@lib.ValType] {
  let out : Array[@lib.ValType] = []
  let mut idx = 0
  while idx < params.length() {
    if idx < keep.length() && keep[idx] {
      out.push(params[idx])
    }
    idx += 1
  }
  out
}

///|
fn dae_try_remove_dead_suffix_only_unreachable_params(
  mod_ : @lib.Module,
  callee_abs : Int,
  original_call_count : Int,
  allow_unreachable_only_cleanup : Bool,
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let def_idx = callee_abs - imported
  let type_indices = dae_collect_func_type_indices(mod_)
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, results) = func_type
  if params.length() == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let (type_idxs, funcs, type_sec) = match
    (mod_.func_sec, mod_.code_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(type_sec)) =>
      (type_idxs.copy(), funcs.copy(), type_sec)
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let current_calls_anywhere = dae_count_module_calls_anywhere_to(
    funcs, callee_abs,
  )
  if current_calls_anywhere == 0 && original_call_count == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  if current_calls_anywhere == 0 &&
    dae_func_is_unreachable_only(funcs[def_idx]) &&
    !allow_unreachable_only_cleanup {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let simplified = dae_simplify_to_unreachable_when_prefix_unobservable(
    funcs[def_idx],
  )
  if !dae_func_is_unreachable_only(simplified) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let mut func_idx = 0
  while func_idx < funcs.length() {
    if func_idx != def_idx {
      let (repaired, _) = dae_repair_dead_suffix_calls_func(
        funcs[func_idx],
        callee_abs,
      )
      funcs[func_idx] = repaired
    }
    func_idx += 1
  }
  let keep_params = dae_collect_dead_suffix_self_operand_params(
    funcs[def_idx],
    callee_abs,
    params.length(),
    mod_,
    type_indices,
  )
  let next_params = dae_filter_params(params, keep_params)
  funcs[def_idx] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  let (next_type_sec, new_type_idx) = dae_append_new_func_type(
    type_sec, next_params, results,
  )
  type_idxs[def_idx] = new_type_idx
  let touched = Array::make(funcs.length(), false)
  touched[def_idx] = true
  {
    mod_out: mod_
    .with_type_sec(next_type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs))
    .without_name_sec(),
    touched,
    changed: true,
    primary_def: def_idx,
  }
}

///|
fn dae_try_remove_unobserved_unreachable_function(
  mod_ : @lib.Module,
  callee_abs : Int,
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let def_idx = callee_abs - imported
  let type_indices = dae_collect_func_type_indices(mod_)
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, results) = func_type
  if params.length() == 0 && results.length() == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let (type_idxs, funcs, type_sec) = match
    (mod_.func_sec, mod_.code_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(type_sec)) =>
      (type_idxs.copy(), funcs.copy(), type_sec)
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.Func(_, @lib.Expr(callee_body)) = funcs[def_idx]
  let module_calls_anywhere = dae_count_module_calls_anywhere_to(
    funcs, callee_abs,
  )
  if module_calls_anywhere == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  if results.length() > 0 &&
    dae_dead_suffix_has_other_call(callee_body, callee_abs) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  if params.length() == 0 &&
    results.length() > 0 &&
    dae_dead_suffix_has_undropped_direct_call_to(callee_body, callee_abs) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let simplified = dae_simplify_to_unreachable_when_prefix_unobservable(
    funcs[def_idx],
  )
  if !dae_func_is_unreachable_only(simplified) ||
    (
      results.length() > 0 &&
      !dae_dead_suffix_has_undropped_direct_call_to(callee_body, callee_abs)
    ) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let mut func_idx = 0
  while func_idx < funcs.length() {
    if func_idx != def_idx {
      let (repaired, _) = dae_repair_dead_suffix_calls_func(
        funcs[func_idx],
        callee_abs,
      )
      funcs[func_idx] = repaired
    }
    func_idx += 1
  }
  funcs[def_idx] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  let (next_type_sec, new_type_idx) = dae_append_new_func_type(type_sec, [], [])
  type_idxs[def_idx] = new_type_idx
  let touched = Array::make(funcs.length(), false)
  touched[def_idx] = true
  {
    mod_out: mod_
    .with_type_sec(next_type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs))
    .without_name_sec(),
    touched,
    changed: true,
    primary_def: def_idx,
  }
}

///|
fn dae_try_remove_dead_self_suffix_result(
  mod_ : @lib.Module,
  callee_abs : Int,
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let def_idx = callee_abs - imported
  let type_indices = dae_collect_func_type_indices(mod_)
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, results) = func_type
  if params.length() != 0 || results.length() != 1 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let (type_idxs, funcs, type_sec) = match
    (mod_.func_sec, mod_.code_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(type_sec)) =>
      (type_idxs.copy(), funcs.copy(), type_sec)
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
  if dae_func_is_unreachable_only(funcs[def_idx]) ||
    !dae_dead_suffix_has_dropped_direct_call_to(body, callee_abs) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  funcs[def_idx] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  let (next_type_sec, new_type_idx) = dae_append_new_func_type(type_sec, [], [])
  type_idxs[def_idx] = new_type_idx
  let touched = Array::make(funcs.length(), false)
  touched[def_idx] = true
  {
    mod_out: mod_
    .with_type_sec(next_type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs))
    .without_name_sec(),
    touched,
    changed: true,
    primary_def: def_idx,
  }
}

///|
fn dae_try_remove_uncalled_results(
  mod_ : @lib.Module,
  callee_abs : Int,
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let def_idx = callee_abs - imported
  let type_indices = dae_collect_func_type_indices(mod_)
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, results) = func_type
  if params.length() != 0 || results.length() == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let (type_idxs, funcs, type_sec) = match
    (mod_.func_sec, mod_.code_sec, mod_.type_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs)), Some(type_sec)) =>
      (type_idxs.copy(), funcs.copy(), type_sec)
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let simplified = dae_simplify_to_unreachable_when_prefix_unobservable(
    funcs[def_idx],
  )
  if !dae_func_is_unreachable_only(simplified) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  funcs[def_idx] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  let (next_type_sec, new_type_idx) = dae_append_new_func_type(
    type_sec,
    params,
    [],
  )
  type_idxs[def_idx] = new_type_idx
  let touched = Array::make(funcs.length(), false)
  touched[def_idx] = true
  {
    mod_out: mod_
    .with_type_sec(next_type_sec)
    .with_func_sec(@lib.FuncSec::new(type_idxs))
    .with_code_sec(@lib.CodeSec::new(funcs))
    .without_name_sec(),
    touched,
    changed: true,
    primary_def: def_idx,
  }
}

///|
fn dae_collect_original_param_counts(mod_ : @lib.Module) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts : Array[Int] = []
  let mut def_idx = 0
  while def_idx < defined {
    match dae_resolve_func_type(mod_, type_indices, imported + def_idx) {
      Some(@lib.FuncType(params, _)) => counts.push(params.length())
      None => counts.push(0)
    }
    def_idx += 1
  }
  counts
}

///|
fn dae_collect_original_call_counts(mod_ : @lib.Module) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts : Array[Int] = []
  let mut def_idx = 0
  while def_idx < defined {
    counts.push(dae_count_module_calls_anywhere_to(funcs, imported + def_idx))
    def_idx += 1
  }
  counts
}

///|
fn dae_collect_original_prior_call_counts(mod_ : @lib.Module) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let mut callee_def = caller_def + 1
    while callee_def < defined {
      counts[callee_def] = counts[callee_def] +
        dae_count_direct_call_anywhere_to(body, imported + callee_def)
      callee_def += 1
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_nonself_undropped_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let mut callee_def = 0
    while callee_def < defined {
      if callee_def != caller_def &&
        dae_has_undropped_direct_call_to(body, imported + callee_def) {
        counts[callee_def] = counts[callee_def] + 1
      }
      callee_def += 1
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_active_nonself_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_active = escaped[caller_abs] ||
      dae_count_module_calls_anywhere_to(funcs, caller_abs) > 0
    if caller_is_active {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_direct_call_anywhere_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_active_parameterized_nonself_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_active = escaped[caller_abs] ||
      dae_count_module_calls_anywhere_to(funcs, caller_abs) > 0
    let caller_has_params = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, _)) => params.length() > 0
      None => false
    }
    if caller_is_active && caller_has_params {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_direct_call_anywhere_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_active_parameterized_result_nonself_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_active = escaped[caller_abs] ||
      dae_count_module_calls_anywhere_to(funcs, caller_abs) > 0
    let caller_has_params_and_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    if caller_is_active && caller_has_params_and_result {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_direct_call_anywhere_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_prior_undropped_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let mut callee_def = caller_def + 1
    while callee_def < defined {
      if dae_has_undropped_direct_call_to(body, imported + callee_def) {
        counts[callee_def] = counts[callee_def] + 1
      }
      callee_def += 1
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_self_call_counts(mod_ : @lib.Module) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let counts : Array[Int] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    counts.push(
      dae_count_self_calls_anywhere(funcs[def_idx], imported + def_idx),
    )
    def_idx += 1
  }
  counts
}

///|
fn dae_count_dead_suffix_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
) -> Int {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return dae_count_direct_call_anywhere_to(suffix, callee_abs)
    }
    idx += 1
  }
  0
}

///|
fn dae_instrs_have_dropped_escaped_result_direct_call(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 &&
          slot < escaped.length() &&
          escaped[slot] &&
          idx + 1 < instrs.length() &&
          instrs[idx + 1] == @lib.Instruction::drop() {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(_, results)) if results.length() > 0 =>
              return true
            _ => ()
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae_instrs_have_dropped_escaped_result_direct_call(
            body, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if dae_instrs_have_dropped_escaped_result_direct_call(
            then_body, mod_, type_indices, escaped,
          ) ||
          dae_instrs_have_dropped_escaped_result_direct_call(
            else_body, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if dae_instrs_have_dropped_escaped_result_direct_call(
            then_body, mod_, type_indices, escaped,
          ) {
          return true
        }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
fn dae_instrs_have_undropped_escaped_result_direct_call(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 &&
          slot < escaped.length() &&
          escaped[slot] &&
          !(idx + 1 < instrs.length() &&
          instrs[idx + 1] == @lib.Instruction::drop()) {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(_, results)) if results.length() > 0 =>
              return true
            _ => ()
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae_instrs_have_undropped_escaped_result_direct_call(
            body, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if dae_instrs_have_undropped_escaped_result_direct_call(
            then_body, mod_, type_indices, escaped,
          ) ||
          dae_instrs_have_undropped_escaped_result_direct_call(
            else_body, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if dae_instrs_have_undropped_escaped_result_direct_call(
            then_body, mod_, type_indices, escaped,
          ) {
          return true
        }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_has_undropped_escaped_result_call(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return dae_instrs_have_undropped_escaped_result_direct_call(
        suffix, mod_, type_indices, escaped,
      )
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_has_dropped_escaped_result_call(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return dae_instrs_have_dropped_escaped_result_direct_call(
        suffix, mod_, type_indices, escaped,
      )
    }
    idx += 1
  }
  false
}

///|
fn dae_collect_original_dead_suffix_undropped_escaped_result_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < defined {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags[def_idx] = dae_dead_suffix_has_undropped_escaped_result_call(
      body, mod_, type_indices, escaped,
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_original_dead_suffix_dropped_escaped_result_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < defined {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags[def_idx] = dae_dead_suffix_has_dropped_escaped_result_call(
      body, mod_, type_indices, escaped,
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_dead_suffix_call_to_has_escaped_result_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  let param_count = match
    dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(@lib.FuncType(params, _)) => params.length()
    None => return false
  }
  let stack_from_escaped_call : Array[Bool] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs => {
        let mut has_escaped_operand = false
        let mut p = 0
        while p < param_count {
          let stack_idx = stack_from_escaped_call.length() - param_count + p
          if stack_idx >= 0 && stack_idx < stack_from_escaped_call.length() {
            has_escaped_operand = has_escaped_operand ||
              stack_from_escaped_call[stack_idx]
          }
          p += 1
        }
        if has_escaped_operand {
          return true
        }
        let mut pop = 0
        while pop < param_count && stack_from_escaped_call.length() > 0 {
          ignore(stack_from_escaped_call.pop())
          pop += 1
        }
        match dae_resolve_func_type(mod_, type_indices, callee_abs) {
          Some(@lib.FuncType(_, results)) => {
            let mut r = 0
            while r < results.length() {
              stack_from_escaped_call.push(false)
              r += 1
            }
          }
          None => ()
        }
      }
      @lib.Call(func_idx) =>
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_escaped_call.length() > 0 {
              ignore(stack_from_escaped_call.pop())
              pop += 1
            }
            let slot = dae_func_idx_slot(func_idx)
            let from_escaped = slot >= 0 &&
              slot < escaped.length() &&
              escaped[slot]
            let mut push = 0
            while push < outputs {
              stack_from_escaped_call.push(from_escaped)
              push += 1
            }
          }
          None => ()
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        if dae_dead_suffix_call_to_has_escaped_result_operand(
            body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_escaped_call.length() > 0 {
              ignore(stack_from_escaped_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_escaped_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      }
      @lib.If(_, then_body, Some(else_body)) => {
        if dae_dead_suffix_call_to_has_escaped_result_operand(
            then_body, callee_abs, mod_, type_indices, escaped,
          ) ||
          dae_dead_suffix_call_to_has_escaped_result_operand(
            else_body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_escaped_call.length() > 0 {
              ignore(stack_from_escaped_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_escaped_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      }
      @lib.If(_, then_body, None) => {
        if dae_dead_suffix_call_to_has_escaped_result_operand(
            then_body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_escaped_call.length() > 0 {
              ignore(stack_from_escaped_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_escaped_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      }
      _ =>
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_escaped_call.length() > 0 {
              ignore(stack_from_escaped_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_escaped_call.push(false)
              push += 1
            }
          }
          None => ()
        }
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_call_to_has_same_result_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Bool {
  let param_count = match
    dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(@lib.FuncType(params, _)) => params.length()
    None => return false
  }
  let stack_from_target_call : Array[Bool] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs => {
        let mut has_target_operand = false
        let mut p = 0
        while p < param_count {
          let stack_idx = stack_from_target_call.length() - param_count + p
          if stack_idx >= 0 && stack_idx < stack_from_target_call.length() {
            has_target_operand = has_target_operand ||
              stack_from_target_call[stack_idx]
          }
          p += 1
        }
        if has_target_operand {
          return true
        }
        let mut pop = 0
        while pop < param_count && stack_from_target_call.length() > 0 {
          ignore(stack_from_target_call.pop())
          pop += 1
        }
        match dae_resolve_func_type(mod_, type_indices, callee_abs) {
          Some(@lib.FuncType(_, results)) => {
            let mut r = 0
            while r < results.length() {
              stack_from_target_call.push(true)
              r += 1
            }
          }
          None => ()
        }
      }
      @lib.Call(_) =>
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_target_call.length() > 0 {
              ignore(stack_from_target_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_target_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        if dae_dead_suffix_call_to_has_same_result_operand(
            body, callee_abs, mod_, type_indices,
          ) {
          return true
        }
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_target_call.length() > 0 {
              ignore(stack_from_target_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_target_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      }
      @lib.If(_, then_body, Some(else_body)) => {
        if dae_dead_suffix_call_to_has_same_result_operand(
            then_body, callee_abs, mod_, type_indices,
          ) ||
          dae_dead_suffix_call_to_has_same_result_operand(
            else_body, callee_abs, mod_, type_indices,
          ) {
          return true
        }
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_target_call.length() > 0 {
              ignore(stack_from_target_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_target_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      }
      @lib.If(_, then_body, None) => {
        if dae_dead_suffix_call_to_has_same_result_operand(
            then_body, callee_abs, mod_, type_indices,
          ) {
          return true
        }
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_target_call.length() > 0 {
              ignore(stack_from_target_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_target_call.push(false)
              push += 1
            }
          }
          None => ()
        }
      }
      _ =>
        match dae_instr_stack_effect(instr, mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack_from_target_call.length() > 0 {
              ignore(stack_from_target_call.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack_from_target_call.push(false)
              push += 1
            }
          }
          None => ()
        }
    }
    idx += 1
  }
  false
}

///|
fn dae_collect_original_private_result_same_operand_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_private_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    if caller_is_private_result && !escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def &&
          dae_dead_suffix_call_to_has_same_result_operand(
            body,
            imported + callee_def,
            mod_,
            type_indices,
          ) {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let caller_has_undropped_self_suffix = dae_dead_suffix_has_undropped_direct_call_to(
      body, caller_abs,
    )
    let caller_has_dropped_escaped_result_suffix = dae_dead_suffix_has_dropped_escaped_result_call(
      body, mod_, type_indices, escaped,
    )
    let mut caller_has_undropped_nonself_caller = false
    let mut incoming_def = 0
    while incoming_def < funcs.length() {
      if incoming_def != caller_def {
        let @lib.Func(_, @lib.Expr(incoming_body)) = funcs[incoming_def]
        if dae_has_undropped_direct_call_to(incoming_body, caller_abs) {
          caller_has_undropped_nonself_caller = true
        }
      }
      incoming_def += 1
    }
    if caller_has_params_and_result &&
      caller_has_undropped_self_suffix &&
      caller_has_undropped_nonself_caller &&
      !caller_has_dropped_escaped_result_suffix &&
      !escaped[caller_abs] {
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_dead_suffix_direct_call_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_no_param_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() == 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_is_no_param_result &&
      dae_dead_suffix_has_undropped_direct_call_to(body, caller_abs) {
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_dead_suffix_direct_call_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_has_params_and_result &&
      dae_dead_suffix_has_dropped_direct_call_to(body, caller_abs) {
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def &&
          dae_dead_suffix_has_undropped_direct_call_to(
            body,
            imported + callee_def,
          ) {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_dropped_earlier_result_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let mut callee_def = 0
    while callee_def < caller_def {
      let callee_abs = imported + callee_def
      let callee_has_result = match
        dae_resolve_func_type(mod_, type_indices, callee_abs) {
        Some(@lib.FuncType(_, results)) => results.length() > 0
        None => false
      }
      if callee_has_result &&
        dae_dead_suffix_has_dropped_direct_call_to(body, callee_abs) {
        flags[caller_def] = true
      }
      callee_def += 1
    }
    caller_def += 1
  }
  flags
}

///|
fn dae_collect_original_later_dead_suffix_dropped_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut callee_def = 0
  while callee_def < defined {
    let mut caller_def = callee_def + 1
    while caller_def < funcs.length() {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      if dae_dead_suffix_has_dropped_direct_call_to(body, imported + callee_def) {
        counts[callee_def] = counts[callee_def] + 1
      }
      caller_def += 1
    }
    callee_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_has_params_and_result &&
      dae_dead_suffix_has_undropped_direct_call_to(body, caller_abs) {
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def &&
          dae_dead_suffix_has_dropped_direct_call_to(
            body,
            imported + callee_def,
          ) {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_escaped_result_operand_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    if escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def &&
          dae_dead_suffix_call_to_has_escaped_result_operand(
            body,
            imported + callee_def,
            mod_,
            type_indices,
            escaped,
          ) {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
  mod_ : @lib.Module,
  escaped_operand_counts : Array[Int],
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    if caller_has_params_and_result &&
      caller_def < escaped_operand_counts.length() &&
      escaped_operand_counts[caller_def] > 0 {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_dead_suffix_direct_call_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_same_self_result_operand_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags[def_idx] = dae_dead_suffix_call_to_has_same_result_operand(
      body, callee_abs, mod_, type_indices,
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_original_private_result_escaped_operand_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_private_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    if caller_is_private_result && !escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        let @lib.Func(_, @lib.Expr(callee_body)) = funcs[callee_def]
        if callee_def != caller_def &&
          dae_dead_suffix_has_dropped_escaped_result_call(
            callee_body, mod_, type_indices, escaped,
          ) &&
          dae_dead_suffix_call_to_has_escaped_result_operand(
            body,
            imported + callee_def,
            mod_,
            type_indices,
            escaped,
          ) {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_private_result_dead_suffix_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let caller_has_undropped_self_suffix = dae_dead_suffix_has_undropped_direct_call_to(
      body, caller_abs,
    )
    let caller_has_dropped_escaped_result_suffix = dae_dead_suffix_has_dropped_escaped_result_call(
      body, mod_, type_indices, escaped,
    )
    if caller_has_params_and_result &&
      !caller_has_undropped_self_suffix &&
      !caller_has_dropped_escaped_result_suffix &&
      !escaped[caller_abs] &&
      dae_count_module_calls_anywhere_to(funcs, caller_abs) > 0 {
      let mut callee_def = 0
      while callee_def < defined {
        counts[callee_def] = counts[callee_def] +
          dae_count_dead_suffix_direct_call_to(body, imported + callee_def)
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_escaped_dead_suffix_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    if escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        counts[callee_def] = counts[callee_def] +
          dae_count_dead_suffix_direct_call_to(body, imported + callee_def)
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_escaped_undropped_dead_suffix_call_counts(
  mod_ : @lib.Module,
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let escaped = dae_collect_escapes(mod_, total)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    if escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if dae_dead_suffix_has_undropped_direct_call_to(
            body,
            imported + callee_def,
          ) {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_collect_original_dead_suffix_other_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(dae_dead_suffix_has_other_call(body, imported + def_idx))
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_original_dead_suffix_undropped_self_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_dead_suffix_has_undropped_direct_call_to(body, imported + def_idx),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_instrs_have_undropped_call_to_with_param_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Bool {
  let stack : Array[Int] = []
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.LocalGet(local_idx) => {
        let slot = dae_local_idx_slot(local_idx)
        if slot >= 0 && slot < param_count {
          stack.push(slot)
        } else {
          stack.push(-1)
        }
      }
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs => {
        let mut has_param_operand = false
        let mut p = 0
        while p < param_count {
          let stack_idx = stack.length() - param_count + p
          if stack_idx >= 0 && stack_idx < stack.length() {
            has_param_operand = has_param_operand || stack[stack_idx] >= 0
          }
          p += 1
        }
        if has_param_operand &&
          !(idx + 1 < instrs.length() &&
          instrs[idx + 1] == @lib.Instruction::drop()) {
          return true
        }
        let mut pop = 0
        while pop < param_count && stack.length() > 0 {
          ignore(stack.pop())
          pop += 1
        }
        match dae_resolve_func_type(mod_, type_indices, callee_abs) {
          Some(@lib.FuncType(_, results)) => {
            let mut r = 0
            while r < results.length() {
              stack.push(-1)
              r += 1
            }
          }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        if dae_instrs_have_undropped_call_to_with_param_operand(
            body, callee_abs, param_count, mod_, type_indices,
          ) {
          return true
        }
        match dae_instr_stack_effect(instrs[idx], mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack.length() > 0 {
              ignore(stack.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack.push(-1)
              push += 1
            }
          }
          None => ()
        }
      }
      @lib.If(_, then_body, Some(else_body)) => {
        if dae_instrs_have_undropped_call_to_with_param_operand(
            then_body, callee_abs, param_count, mod_, type_indices,
          ) ||
          dae_instrs_have_undropped_call_to_with_param_operand(
            else_body, callee_abs, param_count, mod_, type_indices,
          ) {
          return true
        }
        match dae_instr_stack_effect(instrs[idx], mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack.length() > 0 {
              ignore(stack.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack.push(-1)
              push += 1
            }
          }
          None => ()
        }
      }
      @lib.If(_, then_body, None) => {
        if dae_instrs_have_undropped_call_to_with_param_operand(
            then_body, callee_abs, param_count, mod_, type_indices,
          ) {
          return true
        }
        match dae_instr_stack_effect(instrs[idx], mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack.length() > 0 {
              ignore(stack.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack.push(-1)
              push += 1
            }
          }
          None => ()
        }
      }
      _ =>
        match dae_instr_stack_effect(instrs[idx], mod_, type_indices) {
          Some((inputs, outputs)) => {
            let mut pop = 0
            while pop < inputs && stack.length() > 0 {
              ignore(stack.pop())
              pop += 1
            }
            let mut push = 0
            while push < outputs {
              stack.push(-1)
              push += 1
            }
          }
          None => ()
        }
    }
    idx += 1
  }
  false
}

///|
fn dae_dead_suffix_has_undropped_self_call_param_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return dae_instrs_have_undropped_call_to_with_param_operand(
        suffix, callee_abs, param_count, mod_, type_indices,
      )
    }
    idx += 1
  }
  false
}

///|
fn dae_collect_original_dead_suffix_undropped_self_call_param_operands(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let param_count = match
      dae_resolve_func_type(mod_, type_indices, callee_abs) {
      Some(@lib.FuncType(params, _)) => params.length()
      None => 0
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      param_count > 0 &&
      dae_dead_suffix_has_undropped_self_call_param_operand(
        body, callee_abs, param_count, mod_, type_indices,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_original_dead_suffix_dropped_self_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_dead_suffix_has_dropped_direct_call_to(body, imported + def_idx),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_dead_suffix_has_dropped_self_call_full_param_forward(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
) -> Bool {
  if param_count == 0 {
    return false
  }
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let mut suffix_idx = idx + 1
      while suffix_idx + 1 < instrs.length() {
        match (instrs[suffix_idx], instrs[suffix_idx + 1]) {
          (@lib.Call(func_idx), @lib.Drop) if dae_func_idx_slot(func_idx) ==
            callee_abs => {
            let start = suffix_idx - param_count
            if start >= idx + 1 {
              let mut ok = true
              let mut p = 0
              while p < param_count {
                match instrs[start + p] {
                  @lib.LocalGet(local_idx) if dae_local_idx_slot(local_idx) == p =>
                    ()
                  _ => ok = false
                }
                p += 1
              }
              if ok {
                return true
              }
            }
          }
          _ => ()
        }
        suffix_idx += 1
      }
      return false
    }
    idx += 1
  }
  false
}

///|
fn dae_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let param_count = match
      dae_resolve_func_type(mod_, type_indices, callee_abs) {
      Some(@lib.FuncType(params, _)) => params.length()
      None => 0
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_dead_suffix_has_dropped_self_call_full_param_forward(
        body, callee_abs, param_count,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_instrs_have_private_result_direct_call_other_than(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot != callee_abs &&
          slot >= 0 &&
          slot < escaped.length() &&
          !escaped[slot] {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(_, results)) if results.length() > 0 =>
              return true
            _ => ()
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae_instrs_have_private_result_direct_call_other_than(
            body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if dae_instrs_have_private_result_direct_call_other_than(
            then_body, callee_abs, mod_, type_indices, escaped,
          ) ||
          dae_instrs_have_private_result_direct_call_other_than(
            else_body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if dae_instrs_have_private_result_direct_call_other_than(
            then_body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn dae_dead_suffix_has_private_result_call_other_than(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      return dae_instrs_have_private_result_direct_call_other_than(
        suffix, callee_abs, mod_, type_indices, escaped,
      )
    }
    idx += 1
  }
  false
}

///|
fn dae_collect_original_dead_suffix_self_recursive_result_side_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let callees = Array::make(total, false)
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    dae_collect_dead_suffix_other_callees(body, callee_abs, callees)
    let mut other_abs = imported
    while other_abs < total {
      if callees[other_abs] && other_abs < callee_abs {
        let other_def = other_abs - imported
        if other_def >= 0 && other_def < funcs.length() {
          let @lib.Func(_, @lib.Expr(other_body)) = funcs[other_def]
          if dae_dead_suffix_has_undropped_direct_call_to(other_body, other_abs) {
            match dae_resolve_func_type(mod_, type_indices, other_abs) {
              Some(@lib.FuncType(_, results)) if results.length() > 0 =>
                flags[def_idx] = true
              _ => ()
            }
          }
        }
      }
      other_abs += 1
    }
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_original_dead_suffix_self_recursive_void_side_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let original_self_calls = dae_collect_original_self_call_counts(mod_)
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let callees = Array::make(total, false)
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    dae_collect_dead_suffix_other_callees(body, callee_abs, callees)
    let mut other_abs = imported
    while other_abs < total {
      if callees[other_abs] {
        let other_def = other_abs - imported
        if other_def >= 0 &&
          other_def < funcs.length() &&
          other_def < original_self_calls.length() &&
          original_self_calls[other_def] > 0 {
          match dae_resolve_func_type(mod_, type_indices, other_abs) {
            Some(@lib.FuncType(_, results)) if results.length() == 0 =>
              flags[def_idx] = true
            _ => ()
          }
        }
      }
      other_abs += 1
    }
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_original_dead_suffix_result_other_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let type_indices = dae_collect_func_type_indices(mod_)
  let escaped = dae_collect_escapes(mod_, total)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_dead_suffix_has_private_result_call_other_than(
        body,
        imported + def_idx,
        mod_,
        type_indices,
        escaped,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_collect_other_callees_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  callees : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < callees.length() && slot != callee_abs {
          callees[slot] = true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_collect_other_callees_instrs(body, callee_abs, callees)
      @lib.If(_, then_body, Some(else_body)) => {
        dae_collect_other_callees_instrs(then_body, callee_abs, callees)
        dae_collect_other_callees_instrs(else_body, callee_abs, callees)
      }
      @lib.If(_, then_body, None) =>
        dae_collect_other_callees_instrs(then_body, callee_abs, callees)
      _ => ()
    }
  }
}

///|
fn dae_collect_dead_suffix_other_callees(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  callees : Array[Bool],
) -> Unit {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_instr_is_unreachable_root(instrs[idx]) {
      let suffix : Array[@lib.Instruction] = []
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        suffix.push(instrs[suffix_idx])
        suffix_idx += 1
      }
      dae_collect_other_callees_instrs(suffix, callee_abs, callees)
      return
    }
    idx += 1
  }
}

///|
fn dae_collect_original_dead_suffix_mutual_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let callees = Array::make(total, false)
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    dae_collect_dead_suffix_other_callees(body, callee_abs, callees)
    let mut other_abs = imported
    while other_abs < total {
      if callees[other_abs] {
        let other_def = other_abs - imported
        if other_def >= 0 && other_def < funcs.length() {
          let @lib.Func(_, @lib.Expr(other_body)) = funcs[other_def]
          if dae_count_direct_call_anywhere_to(other_body, callee_abs) > 0 {
            flags[def_idx] = true
          }
        }
      }
      other_abs += 1
    }
    def_idx += 1
  }
  flags
}

///|
fn dae_should_prune_later_mutual_dropped_result(
  def_idx : Int,
  original_param_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_escaped_result_calls : Array[Bool],
  original_dead_suffix_dropped_earlier_result_calls : Array[Bool],
  original_later_dead_suffix_dropped_call_counts : Array[Int],
) -> Bool {
  def_idx < original_param_counts.length() &&
  original_param_counts[def_idx] > 0 &&
  def_idx < original_self_call_counts.length() &&
  original_self_call_counts[def_idx] == 0 &&
  def_idx < original_nonself_undropped_call_counts.length() &&
  original_nonself_undropped_call_counts[def_idx] == 0 &&
  def_idx < original_escaped_dead_suffix_call_counts.length() &&
  original_escaped_dead_suffix_call_counts[def_idx] == 0 &&
  def_idx < original_dead_suffix_undropped_self_calls.length() &&
  !original_dead_suffix_undropped_self_calls[def_idx] &&
  def_idx < original_dead_suffix_dropped_escaped_result_calls.length() &&
  !original_dead_suffix_dropped_escaped_result_calls[def_idx] &&
  def_idx < original_dead_suffix_dropped_earlier_result_calls.length() &&
  original_dead_suffix_dropped_earlier_result_calls[def_idx] &&
  def_idx < original_later_dead_suffix_dropped_call_counts.length() &&
  original_later_dead_suffix_dropped_call_counts[def_idx] > 0
}

///|
fn dae_should_prune_dropped_self_result_with_void_side_callers(
  def_idx : Int,
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_active_nonself_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_active_parameterized_result_nonself_call_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_call_full_param_forwards : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> Bool {
  def_idx < original_param_counts.length() &&
  original_param_counts[def_idx] > 0 &&
  def_idx < original_self_call_counts.length() &&
  original_self_call_counts[def_idx] > 0 &&
  def_idx < original_call_counts.length() &&
  original_call_counts[def_idx] > original_self_call_counts[def_idx] &&
  def_idx < original_active_nonself_call_counts.length() &&
  original_active_nonself_call_counts[def_idx] > 0 &&
  def_idx < original_active_parameterized_nonself_call_counts.length() &&
  original_active_parameterized_nonself_call_counts[def_idx] > 0 &&
  def_idx < original_active_parameterized_result_nonself_call_counts.length() &&
  original_active_parameterized_result_nonself_call_counts[def_idx] == 0 &&
  def_idx < original_nonself_undropped_call_counts.length() &&
  original_nonself_undropped_call_counts[def_idx] == 0 &&
  def_idx < original_escaped_dead_suffix_call_counts.length() &&
  original_escaped_dead_suffix_call_counts[def_idx] == 0 &&
  def_idx < original_dead_suffix_undropped_self_calls.length() &&
  !original_dead_suffix_undropped_self_calls[def_idx] &&
  def_idx < original_dead_suffix_dropped_self_calls.length() &&
  original_dead_suffix_dropped_self_calls[def_idx] &&
  def_idx < original_dead_suffix_dropped_self_call_full_param_forwards.length() &&
  !original_dead_suffix_dropped_self_call_full_param_forwards[def_idx] &&
  def_idx < original_dead_suffix_mutual_calls.length() &&
  !original_dead_suffix_mutual_calls[def_idx]
}

///|
fn dae_should_preserve_parameterized_undropped_self_side_chain(
  def_idx : Int,
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
) -> Bool {
  def_idx < original_param_counts.length() &&
  original_param_counts[def_idx] > 0 &&
  def_idx < original_call_counts.length() &&
  def_idx < original_self_call_counts.length() &&
  original_self_call_counts[def_idx] > 0 &&
  original_call_counts[def_idx] > original_self_call_counts[def_idx] &&
  def_idx < original_active_parameterized_nonself_call_counts.length() &&
  original_active_parameterized_nonself_call_counts[def_idx] > 0 &&
  def_idx < original_dead_suffix_undropped_self_calls.length() &&
  original_dead_suffix_undropped_self_calls[def_idx] &&
  def_idx < original_dead_suffix_result_other_calls.length() &&
  original_dead_suffix_result_other_calls[def_idx] &&
  def_idx < original_escaped_dead_suffix_call_counts.length() &&
  original_escaped_dead_suffix_call_counts[def_idx] == 0
}

///|
fn dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
  def_idx : Int,
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_active_nonself_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> Bool {
  def_idx < original_param_counts.length() &&
  original_param_counts[def_idx] > 0 &&
  def_idx < original_call_counts.length() &&
  def_idx < original_self_call_counts.length() &&
  original_self_call_counts[def_idx] > 0 &&
  original_call_counts[def_idx] > original_self_call_counts[def_idx] &&
  def_idx < original_dead_suffix_undropped_self_calls.length() &&
  original_dead_suffix_undropped_self_calls[def_idx] &&
  def_idx < original_dead_suffix_undropped_self_call_param_operands.length() &&
  original_dead_suffix_undropped_self_call_param_operands[def_idx] &&
  def_idx < original_dead_suffix_result_other_calls.length() &&
  original_dead_suffix_result_other_calls[def_idx] &&
  def_idx < original_active_nonself_call_counts.length() &&
  original_active_nonself_call_counts[def_idx] > 0 &&
  def_idx < original_active_parameterized_nonself_call_counts.length() &&
  original_active_parameterized_nonself_call_counts[def_idx] == 0 &&
  def_idx < original_nonself_undropped_call_counts.length() &&
  original_nonself_undropped_call_counts[def_idx] == 0 &&
  def_idx < original_escaped_dead_suffix_call_counts.length() &&
  original_escaped_dead_suffix_call_counts[def_idx] == 0 &&
  def_idx < original_dead_suffix_mutual_calls.length() &&
  !original_dead_suffix_mutual_calls[def_idx]
}

///|
fn dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
  mod_ : @lib.Module,
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_active_nonself_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> Array[Int] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    if dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
        caller_def, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
        original_dead_suffix_mutual_calls,
      ) {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_count_dead_suffix_direct_call_to(body, imported + callee_def)
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_run_core_once(
  mod_ : @lib.Module,
  already_rewritten_defs : Array[Bool],
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_prior_call_counts : Array[Int],
  original_prior_undropped_call_counts : Array[Int],
  original_active_nonself_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_active_parameterized_result_nonself_call_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_private_result_dead_suffix_call_counts : Array[Int],
  original_private_result_same_operand_call_counts : Array[Int],
  original_private_result_escaped_operand_call_counts : Array[Int],
  original_dead_suffix_escaped_result_operand_call_counts : Array[Int],
  original_private_result_dead_suffix_calls_from_escaped_operand_callees : Array[
    Int,
  ],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_escaped_undropped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_other_calls : Array[Bool],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_call_full_param_forwards : Array[Bool],
  original_dead_suffix_result_calls_from_undropped_self_callers : Array[Int],
  original_dead_suffix_result_calls_from_no_param_undropped_self_callers : Array[
    Int,
  ],
  original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers : Array[
    Int,
  ],
  original_dead_suffix_dropped_calls_from_parameterized_self_callers : Array[
    Int,
  ],
  original_dead_suffix_dropped_earlier_result_calls : Array[Bool],
  original_later_dead_suffix_dropped_call_counts : Array[Int],
  original_dead_suffix_same_self_result_operand_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_calls_from_param_operand_self_result_callers : Array[Int],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_self_recursive_void_side_calls : Array[Bool],
  original_dead_suffix_self_recursive_result_side_calls : Array[Bool],
  original_dead_suffix_undropped_escaped_result_calls : Array[Bool],
  original_dead_suffix_dropped_escaped_result_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let escaped = dae_collect_escapes(mod_, total)
  let (direct_calls, tail_calls) = dae_collect_calls(mod_, total)
  let dropped_calls = dae_collect_dropped_direct_calls(mod_, total)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let mut def_idx = 0
  while def_idx < defined {
    let callee_abs = imported + def_idx
    if def_idx < already_rewritten_defs.length() &&
      already_rewritten_defs[def_idx] {
      def_idx += 1
      continue
    }
    if escaped[callee_abs] || tail_calls[callee_abs] {
      def_idx += 1
      continue
    }
    let self_calls = dae_count_self_calls(funcs[def_idx], callee_abs)
    let self_calls_anywhere = dae_count_self_calls_anywhere(
      funcs[def_idx],
      callee_abs,
    )
    let original_escaped_dead_suffix_calls_for_unobserved = if def_idx <
      original_escaped_dead_suffix_call_counts.length() {
      original_escaped_dead_suffix_call_counts[def_idx]
    } else {
      0
    }
    let original_private_result_escaped_operand_calls_for_unobserved = if def_idx <
      original_private_result_escaped_operand_call_counts.length() {
      original_private_result_escaped_operand_call_counts[def_idx]
    } else {
      0
    }
    let original_dead_suffix_escaped_result_operand_calls_for_unobserved = if def_idx <
      original_dead_suffix_escaped_result_operand_call_counts.length() {
      original_dead_suffix_escaped_result_operand_call_counts[def_idx]
    } else {
      0
    }
    let original_private_result_dead_suffix_calls_from_escaped_operand_callees_for_unobserved = if def_idx <
      original_private_result_dead_suffix_calls_from_escaped_operand_callees.length() {
      original_private_result_dead_suffix_calls_from_escaped_operand_callees[def_idx]
    } else {
      0
    }
    let original_active_nonself_calls_for_unobserved = if def_idx <
      original_active_nonself_call_counts.length() {
      original_active_nonself_call_counts[def_idx]
    } else {
      0
    }
    let original_nonself_undropped_calls_for_unobserved = if def_idx <
      original_nonself_undropped_call_counts.length() {
      original_nonself_undropped_call_counts[def_idx]
    } else {
      0
    }
    let original_call_count_for_unobserved = if def_idx <
      original_call_counts.length() {
      original_call_counts[def_idx]
    } else {
      0
    }
    let original_self_calls_for_unobserved = if def_idx <
      original_self_call_counts.length() {
      original_self_call_counts[def_idx]
    } else {
      0
    }
    let original_mixed_self_suffix_for_unobserved = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      def_idx < original_dead_suffix_undropped_self_calls.length() &&
      original_dead_suffix_undropped_self_calls[def_idx] &&
      def_idx < original_dead_suffix_dropped_self_calls.length() &&
      original_dead_suffix_dropped_self_calls[def_idx] &&
      original_escaped_dead_suffix_calls_for_unobserved == 0 &&
      (
        original_call_count_for_unobserved == original_self_calls_for_unobserved ||
        original_active_nonself_calls_for_unobserved > 0 ||
        original_nonself_undropped_calls_for_unobserved > 0
      )
    let original_dead_suffix_undropped_escaped_result_call_for_unobserved = def_idx <
      original_dead_suffix_undropped_escaped_result_calls.length() &&
      original_dead_suffix_undropped_escaped_result_calls[def_idx]
    let original_dead_suffix_dropped_escaped_result_call_for_unobserved = def_idx <
      original_dead_suffix_dropped_escaped_result_calls.length() &&
      original_dead_suffix_dropped_escaped_result_calls[def_idx]
    let original_dead_suffix_result_calls_from_undropped_self_callers_for_unobserved = if def_idx <
      original_dead_suffix_result_calls_from_undropped_self_callers.length() {
      original_dead_suffix_result_calls_from_undropped_self_callers[def_idx]
    } else {
      0
    }
    let original_dead_suffix_result_calls_from_no_param_undropped_self_callers_for_unobserved = if def_idx <
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers.length() {
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers[def_idx]
    } else {
      0
    }
    let original_dead_suffix_dropped_calls_from_parameterized_self_callers_for_unobserved = if def_idx <
      original_dead_suffix_dropped_calls_from_parameterized_self_callers.length() {
      original_dead_suffix_dropped_calls_from_parameterized_self_callers[def_idx]
    } else {
      0
    }
    let original_dead_suffix_calls_from_param_operand_self_result_callers_for_unobserved = if def_idx <
      original_dead_suffix_calls_from_param_operand_self_result_callers.length() {
      original_dead_suffix_calls_from_param_operand_self_result_callers[def_idx]
    } else {
      0
    }
    let original_same_self_result_operand_for_unobserved = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      def_idx < original_dead_suffix_same_self_result_operand_calls.length() &&
      original_dead_suffix_same_self_result_operand_calls[def_idx] &&
      original_nonself_undropped_calls_for_unobserved > 0
    let original_undropped_self_result_from_no_param_dropped_caller_for_unobserved = dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
      def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
      original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
      original_dead_suffix_mutual_calls,
    )
    let original_dropped_escaped_result_under_self_caller_for_unobserved = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      original_self_calls_for_unobserved == 0 &&
      original_dead_suffix_dropped_escaped_result_call_for_unobserved &&
      original_dead_suffix_dropped_calls_from_parameterized_self_callers_for_unobserved >
      0 &&
      original_escaped_dead_suffix_calls_for_unobserved == 0
    let original_parameterized_undropped_self_side_chain_for_unobserved = dae_should_preserve_parameterized_undropped_self_side_chain(
      def_idx, original_param_counts, original_call_counts, original_active_parameterized_nonself_call_counts,
      original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_result_other_calls,
    )
    if direct_calls[callee_abs] == self_calls &&
      !original_mixed_self_suffix_for_unobserved &&
      !original_same_self_result_operand_for_unobserved &&
      !original_undropped_self_result_from_no_param_dropped_caller_for_unobserved &&
      !original_dropped_escaped_result_under_self_caller_for_unobserved &&
      !original_parameterized_undropped_self_side_chain_for_unobserved &&
      (
        original_dead_suffix_result_calls_from_undropped_self_callers_for_unobserved ==
        0 ||
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers_for_unobserved >
        0
      ) &&
      original_dead_suffix_calls_from_param_operand_self_result_callers_for_unobserved ==
      0 &&
      original_dead_suffix_escaped_result_operand_calls_for_unobserved == 0 &&
      original_private_result_dead_suffix_calls_from_escaped_operand_callees_for_unobserved ==
      0 &&
      original_private_result_escaped_operand_calls_for_unobserved == 0 &&
      !(original_dead_suffix_undropped_escaped_result_call_for_unobserved &&
      original_escaped_dead_suffix_calls_for_unobserved == 0) {
      let unobserved = dae_try_remove_unobserved_unreachable_function(
        mod_, callee_abs,
      )
      if unobserved.changed {
        return unobserved
      }
    }
    if direct_calls[callee_abs] == 0 {
      let original_self_calls = if def_idx < original_self_call_counts.length() {
        original_self_call_counts[def_idx]
      } else {
        0
      }
      let originally_had_params = def_idx < original_param_counts.length() &&
        original_param_counts[def_idx] > 0
      let original_call_count = if def_idx < original_call_counts.length() {
        original_call_counts[def_idx]
      } else {
        0
      }
      let original_prior_calls = if def_idx <
        original_prior_call_counts.length() {
        original_prior_call_counts[def_idx]
      } else {
        0
      }
      let original_prior_undropped_calls = if def_idx <
        original_prior_undropped_call_counts.length() {
        original_prior_undropped_call_counts[def_idx]
      } else {
        0
      }
      let original_active_nonself_calls = if def_idx <
        original_active_nonself_call_counts.length() {
        original_active_nonself_call_counts[def_idx]
      } else {
        0
      }
      let original_active_parameterized_nonself_calls = if def_idx <
        original_active_parameterized_nonself_call_counts.length() {
        original_active_parameterized_nonself_call_counts[def_idx]
      } else {
        0
      }
      let original_active_parameterized_result_nonself_calls = if def_idx <
        original_active_parameterized_result_nonself_call_counts.length() {
        original_active_parameterized_result_nonself_call_counts[def_idx]
      } else {
        0
      }
      let original_nonself_undropped_calls = if def_idx <
        original_nonself_undropped_call_counts.length() {
        original_nonself_undropped_call_counts[def_idx]
      } else {
        0
      }
      let original_private_result_dead_suffix_calls = if def_idx <
        original_private_result_dead_suffix_call_counts.length() {
        original_private_result_dead_suffix_call_counts[def_idx]
      } else {
        0
      }
      let original_private_result_same_operand_calls = if def_idx <
        original_private_result_same_operand_call_counts.length() {
        original_private_result_same_operand_call_counts[def_idx]
      } else {
        0
      }
      let original_private_result_escaped_operand_calls = if def_idx <
        original_private_result_escaped_operand_call_counts.length() {
        original_private_result_escaped_operand_call_counts[def_idx]
      } else {
        0
      }
      let original_dead_suffix_escaped_result_operand_calls = if def_idx <
        original_dead_suffix_escaped_result_operand_call_counts.length() {
        original_dead_suffix_escaped_result_operand_call_counts[def_idx]
      } else {
        0
      }
      let original_private_result_dead_suffix_calls_from_escaped_operand_callees = if def_idx <
        original_private_result_dead_suffix_calls_from_escaped_operand_callees.length() {
        original_private_result_dead_suffix_calls_from_escaped_operand_callees[def_idx]
      } else {
        0
      }
      let original_escaped_dead_suffix_calls = if def_idx <
        original_escaped_dead_suffix_call_counts.length() {
        original_escaped_dead_suffix_call_counts[def_idx]
      } else {
        0
      }
      let original_escaped_undropped_dead_suffix_calls = if def_idx <
        original_escaped_undropped_dead_suffix_call_counts.length() {
        original_escaped_undropped_dead_suffix_call_counts[def_idx]
      } else {
        0
      }
      let original_dead_suffix_other_call = def_idx <
        original_dead_suffix_other_calls.length() &&
        original_dead_suffix_other_calls[def_idx]
      let original_mixed_self_suffix = def_idx <
        original_dead_suffix_undropped_self_calls.length() &&
        original_dead_suffix_undropped_self_calls[def_idx] &&
        def_idx < original_dead_suffix_dropped_self_calls.length() &&
        original_dead_suffix_dropped_self_calls[def_idx] &&
        original_escaped_dead_suffix_calls == 0 &&
        (
          original_call_count == original_self_calls ||
          original_active_nonself_calls > 0 ||
          original_nonself_undropped_calls > 0
        )
      let original_dead_suffix_result_calls_from_undropped_self_callers = if def_idx <
        original_dead_suffix_result_calls_from_undropped_self_callers.length() {
        original_dead_suffix_result_calls_from_undropped_self_callers[def_idx]
      } else {
        0
      }
      let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = if def_idx <
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers.length() {
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers[def_idx]
      } else {
        0
      }
      let original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = if def_idx <
        original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers.length() {
        original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers[def_idx]
      } else {
        0
      }
      let original_dead_suffix_dropped_calls_from_parameterized_self_callers = if def_idx <
        original_dead_suffix_dropped_calls_from_parameterized_self_callers.length() {
        original_dead_suffix_dropped_calls_from_parameterized_self_callers[def_idx]
      } else {
        0
      }
      let original_dead_suffix_calls_from_param_operand_self_result_callers = if def_idx <
        original_dead_suffix_calls_from_param_operand_self_result_callers.length() {
        original_dead_suffix_calls_from_param_operand_self_result_callers[def_idx]
      } else {
        0
      }
      let original_later_mutual_dropped_result = dae_should_prune_later_mutual_dropped_result(
        def_idx, original_param_counts, original_nonself_undropped_call_counts, original_self_call_counts,
        original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_dropped_escaped_result_calls, original_dead_suffix_dropped_earlier_result_calls,
        original_later_dead_suffix_dropped_call_counts,
      )
      let original_dead_suffix_same_self_result_operand_call = def_idx <
        original_dead_suffix_same_self_result_operand_calls.length() &&
        original_dead_suffix_same_self_result_operand_calls[def_idx]
      let original_dead_suffix_result_other_call = def_idx <
        original_dead_suffix_result_other_calls.length() &&
        original_dead_suffix_result_other_calls[def_idx]
      let original_dead_suffix_undropped_self_call = def_idx <
        original_dead_suffix_undropped_self_calls.length() &&
        original_dead_suffix_undropped_self_calls[def_idx]
      let original_dead_suffix_self_recursive_void_side_call = def_idx <
        original_dead_suffix_self_recursive_void_side_calls.length() &&
        original_dead_suffix_self_recursive_void_side_calls[def_idx]
      let original_dead_suffix_self_recursive_result_side_call = def_idx <
        original_dead_suffix_self_recursive_result_side_calls.length() &&
        original_dead_suffix_self_recursive_result_side_calls[def_idx]
      let original_dead_suffix_undropped_escaped_result_call = def_idx <
        original_dead_suffix_undropped_escaped_result_calls.length() &&
        original_dead_suffix_undropped_escaped_result_calls[def_idx]
      let original_dead_suffix_dropped_escaped_result_call = def_idx <
        original_dead_suffix_dropped_escaped_result_calls.length() &&
        original_dead_suffix_dropped_escaped_result_calls[def_idx]
      let original_dead_suffix_mutual_call = def_idx <
        original_dead_suffix_mutual_calls.length() &&
        original_dead_suffix_mutual_calls[def_idx]
      let original_undropped_self_result_from_no_param_dropped_caller = dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
        def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
        original_dead_suffix_mutual_calls,
      )
      let original_parameterized_undropped_self_side_chain = dae_should_preserve_parameterized_undropped_self_side_chain(
        def_idx, original_param_counts, original_call_counts, original_active_parameterized_nonself_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_result_other_calls,
      )
      let original_dropped_escaped_result_under_self_caller = originally_had_params &&
        original_self_calls == 0 &&
        original_dead_suffix_dropped_escaped_result_call &&
        original_dead_suffix_dropped_calls_from_parameterized_self_callers > 0 &&
        original_escaped_dead_suffix_calls == 0
      let original_dropped_self_result_with_void_side_callers = dae_should_prune_dropped_self_result_with_void_side_callers(
        def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_active_parameterized_result_nonself_call_counts,
        original_nonself_undropped_call_counts, original_self_call_counts, original_escaped_dead_suffix_call_counts,
        original_dead_suffix_undropped_self_calls, original_dead_suffix_dropped_self_calls,
        original_dead_suffix_dropped_self_call_full_param_forwards, original_dead_suffix_mutual_calls,
      )
      let original_void_dead_suffix_side_call = original_dead_suffix_other_call &&
        !original_dead_suffix_result_other_call
      let allow_unreachable_only_param_cleanup = (
          original_dead_suffix_undropped_escaped_result_call_for_unobserved &&
          original_escaped_dead_suffix_calls_for_unobserved == 0
        ) ||
        (
          originally_had_params &&
          original_self_calls == 0 &&
          original_void_dead_suffix_side_call &&
          original_dead_suffix_self_recursive_void_side_call &&
          original_escaped_dead_suffix_calls == 0 &&
          original_call_count > 0 &&
          original_active_nonself_calls > 0 &&
          original_nonself_undropped_calls == 0
        ) ||
        (
          originally_had_params &&
          original_self_calls > 0 &&
          original_dead_suffix_undropped_self_call &&
          original_dead_suffix_mutual_call &&
          original_dead_suffix_self_recursive_result_side_call &&
          original_call_count > original_self_calls
        ) ||
        (
          originally_had_params &&
          original_self_calls > 0 &&
          original_dead_suffix_same_self_result_operand_call &&
          original_nonself_undropped_calls > 0 &&
          original_call_count >= original_self_calls
        ) ||
        original_undropped_self_result_from_no_param_dropped_caller ||
        original_parameterized_undropped_self_side_chain ||
        original_dropped_escaped_result_under_self_caller
      let dead_suffix_params = dae_try_remove_dead_suffix_only_unreachable_params(
        mod_, callee_abs, original_call_count, allow_unreachable_only_param_cleanup,
      )
      if dead_suffix_params.changed {
        return dead_suffix_params
      }
      let @lib.Func(_, @lib.Expr(current_body)) = funcs[def_idx]
      let has_undropped_self_suffix = self_calls_anywhere > 0 &&
        dae_dead_suffix_has_undropped_direct_call_to(current_body, callee_abs)
      let no_self_nonmutual_side_call = original_prior_calls == 0 &&
        original_self_calls == 0 &&
        original_dead_suffix_other_call &&
        !original_dead_suffix_mutual_call
      let prune_private_result_side_chain = originally_had_params &&
        original_self_calls == 0 &&
        original_private_result_dead_suffix_calls > 0 &&
        original_dead_suffix_other_call &&
        original_private_result_same_operand_calls > 0 &&
        original_active_nonself_calls > original_nonself_undropped_calls &&
        original_nonself_undropped_calls > 0
      let skip_uncalled_after_param_cleanup = !prune_private_result_side_chain &&
        !original_dropped_self_result_with_void_side_callers &&
        !original_later_mutual_dropped_result &&
        dae_func_is_unreachable_only(
          dae_simplify_to_unreachable_when_prefix_unobservable(funcs[def_idx]),
        ) &&
        (
          has_undropped_self_suffix ||
          (originally_had_params && original_mixed_self_suffix) ||
          (
            originally_had_params &&
            original_self_calls > 0 &&
            original_dead_suffix_same_self_result_operand_call &&
            original_nonself_undropped_calls > 0 &&
            original_call_count >= original_self_calls
          ) ||
          original_undropped_self_result_from_no_param_dropped_caller ||
          original_parameterized_undropped_self_side_chain ||
          original_dropped_escaped_result_under_self_caller ||
          (
            originally_had_params &&
            original_self_calls > 0 &&
            original_dead_suffix_undropped_self_call &&
            original_dead_suffix_mutual_call &&
            original_dead_suffix_self_recursive_result_side_call &&
            original_call_count > original_self_calls
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_private_result_dead_suffix_calls > 0 &&
            original_dead_suffix_result_calls_from_no_param_undropped_self_callers ==
            0 &&
            original_escaped_dead_suffix_calls == 0
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_dead_suffix_escaped_result_operand_calls > 0
          ) ||
          (
            !originally_had_params &&
            original_private_result_dead_suffix_calls_from_escaped_operand_callees >
            0
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_dead_suffix_result_calls_from_undropped_self_callers > 0 &&
            original_dead_suffix_result_calls_from_no_param_undropped_self_callers ==
            0 &&
            original_escaped_dead_suffix_calls == 0 &&
            original_active_nonself_calls > 0
          ) ||
          original_dead_suffix_calls_from_param_operand_self_result_callers > 0 ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_private_result_escaped_operand_calls > 0
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_dead_suffix_undropped_escaped_result_call &&
            original_escaped_dead_suffix_calls == 0 &&
            original_call_count > 0 &&
            original_nonself_undropped_calls == 0
          ) ||
          (
            originally_had_params &&
            original_self_calls > 0 &&
            def_idx < original_dead_suffix_dropped_self_calls.length() &&
            original_dead_suffix_dropped_self_calls[def_idx] &&
            !original_dead_suffix_undropped_self_call &&
            original_call_count > original_self_calls &&
            original_active_nonself_calls > 0 &&
            original_active_parameterized_result_nonself_calls > 0 &&
            original_escaped_dead_suffix_calls == 0 &&
            !original_dead_suffix_mutual_call
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_dead_suffix_result_other_call &&
            original_escaped_dead_suffix_calls == 0 &&
            !original_dead_suffix_mutual_call &&
            (
              original_active_nonself_calls > 0 ||
              original_nonself_undropped_calls > 0
            )
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_void_dead_suffix_side_call &&
            original_dead_suffix_self_recursive_void_side_call &&
            original_escaped_dead_suffix_calls == 0 &&
            original_call_count > 0 &&
            original_active_nonself_calls > 0 &&
            original_nonself_undropped_calls == 0
          ) ||
          (
            originally_had_params &&
            original_dead_suffix_result_calls_from_no_param_undropped_self_callers ==
            0 &&
            (
              original_call_count == original_self_calls ||
              original_active_nonself_calls > 0 ||
              original_nonself_undropped_calls > 0
            ) &&
            (original_prior_calls == 0 || original_prior_undropped_calls > 0) &&
            !no_self_nonmutual_side_call &&
            !(original_self_calls > 0 &&
            original_call_count > original_self_calls &&
            original_active_parameterized_nonself_calls == 0 &&
            original_nonself_undropped_calls == 0)
          ) ||
          (
            !originally_had_params &&
            original_prior_undropped_calls > 0 &&
            (
              original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers ==
              0 ||
              original_escaped_undropped_dead_suffix_calls > 0
            )
          ) ||
          (
            !originally_had_params &&
            original_nonself_undropped_calls > 0 &&
            original_escaped_dead_suffix_calls == 0 &&
            original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers ==
            0
          ) ||
          (
            !originally_had_params &&
            original_dead_suffix_undropped_self_call &&
            original_call_count > original_self_calls
          )
        )
      let skip_self_suffix_result = original_self_calls > 0 &&
        skip_uncalled_after_param_cleanup
      if self_calls_anywhere > 0 &&
        !skip_self_suffix_result &&
        original_call_count == original_self_calls {
        let self_suffix = dae_try_remove_dead_self_suffix_result(
          mod_, callee_abs,
        )
        if self_suffix.changed {
          return self_suffix
        }
      }
      if !skip_uncalled_after_param_cleanup &&
        original_call_count > 0 &&
        (
          self_calls_anywhere == 0 ||
          dae_count_module_calls_anywhere_to(funcs, callee_abs) !=
          self_calls_anywhere
        ) {
        let result = dae_try_remove_uncalled_results(mod_, callee_abs)
        if result.changed {
          return result
        }
      }
      if self_calls_anywhere == 0 {
        let func_type = match
          dae_resolve_func_type(mod_, type_indices, callee_abs) {
          Some(ft) => ft
          None => {
            def_idx += 1
            continue
          }
        }
        let @lib.FuncType(params, _) = func_type
        if params.length() > 0 &&
          original_parameterized_undropped_self_side_chain &&
          dae_func_is_unreachable_only(funcs[def_idx]) {
          let @lib.Func(locals, _) = funcs[def_idx]
          let local_use = dae_local_use_for_callee(
            funcs[def_idx],
            params.length() + locals.length(),
            callee_abs,
            params.length(),
          )
          let remove = Array::make(params.length(), false)
          let mut any = false
          let mut p = 0
          while p < params.length() {
            if !local_use.gets[p] {
              remove[p] = true
              any = true
            }
            p += 1
          }
          if any {
            let result = dae_try_rewrite_candidate(
              mod_,
              callee_abs,
              remove,
              local_use,
              direct_calls[callee_abs],
            )
            if result.changed {
              return result
            }
          }
        }
        def_idx += 1
        continue
      }
    }
    let func_type = match
      dae_resolve_func_type(mod_, type_indices, callee_abs) {
      Some(ft) => ft
      None => {
        def_idx += 1
        continue
      }
    }
    let @lib.FuncType(params, _) = func_type
    if params.length() == 0 {
      let preserve_original_same_self_result_operand = def_idx <
        original_param_counts.length() &&
        original_param_counts[def_idx] > 0 &&
        def_idx < original_self_call_counts.length() &&
        original_self_call_counts[def_idx] > 0 &&
        def_idx < original_call_counts.length() &&
        original_call_counts[def_idx] >= original_self_call_counts[def_idx] &&
        def_idx < original_dead_suffix_same_self_result_operand_calls.length() &&
        original_dead_suffix_same_self_result_operand_calls[def_idx] &&
        def_idx < original_nonself_undropped_call_counts.length() &&
        original_nonself_undropped_call_counts[def_idx] > 0
      let preserve_original_result_from_undropped_self_caller = def_idx <
        original_param_counts.length() &&
        original_param_counts[def_idx] > 0 &&
        def_idx < original_self_call_counts.length() &&
        original_self_call_counts[def_idx] == 0 &&
        def_idx <
        original_dead_suffix_result_calls_from_undropped_self_callers.length() &&
        original_dead_suffix_result_calls_from_undropped_self_callers[def_idx] >
        0 &&
        def_idx <
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers.length() &&
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers[def_idx] ==
        0 &&
        def_idx < original_escaped_dead_suffix_call_counts.length() &&
        original_escaped_dead_suffix_call_counts[def_idx] == 0 &&
        def_idx < original_active_nonself_call_counts.length() &&
        original_active_nonself_call_counts[def_idx] > 0
      let preserve_original_escaped_result_operand_chain = (
          def_idx < original_param_counts.length() &&
          original_param_counts[def_idx] > 0 &&
          def_idx <
          original_dead_suffix_escaped_result_operand_call_counts.length() &&
          original_dead_suffix_escaped_result_operand_call_counts[def_idx] > 0
        ) ||
        (
          def_idx < original_param_counts.length() &&
          original_param_counts[def_idx] == 0 &&
          def_idx <
          original_private_result_dead_suffix_calls_from_escaped_operand_callees.length() &&
          original_private_result_dead_suffix_calls_from_escaped_operand_callees[def_idx] >
          0
        )
      let preserve_original_mixed_self_result = def_idx <
        original_param_counts.length() &&
        original_param_counts[def_idx] > 0 &&
        def_idx < original_dead_suffix_undropped_self_calls.length() &&
        original_dead_suffix_undropped_self_calls[def_idx] &&
        def_idx < original_dead_suffix_dropped_self_calls.length() &&
        original_dead_suffix_dropped_self_calls[def_idx] &&
        def_idx < original_escaped_dead_suffix_call_counts.length() &&
        original_escaped_dead_suffix_call_counts[def_idx] == 0
      let preserve_original_param_operand_self_result_side_callee = def_idx <
        original_dead_suffix_calls_from_param_operand_self_result_callers.length() &&
        original_dead_suffix_calls_from_param_operand_self_result_callers[def_idx] >
        0
      let prune_original_dropped_self_result_with_void_side_callers = dae_should_prune_dropped_self_result_with_void_side_callers(
        def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_active_parameterized_result_nonself_call_counts,
        original_nonself_undropped_call_counts, original_self_call_counts, original_escaped_dead_suffix_call_counts,
        original_dead_suffix_undropped_self_calls, original_dead_suffix_dropped_self_calls,
        original_dead_suffix_dropped_self_call_full_param_forwards, original_dead_suffix_mutual_calls,
      )
      if prune_original_dropped_self_result_with_void_side_callers {
        let dropped_result = dae_try_remove_dropped_results(
          mod_,
          callee_abs,
          direct_calls[callee_abs],
          dropped_calls[callee_abs],
        )
        if dropped_result.changed {
          return dropped_result
        }
      }
      let prune_original_later_mutual_dropped_result = dae_should_prune_later_mutual_dropped_result(
        def_idx, original_param_counts, original_nonself_undropped_call_counts, original_self_call_counts,
        original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_dropped_escaped_result_calls, original_dead_suffix_dropped_earlier_result_calls,
        original_later_dead_suffix_dropped_call_counts,
      )
      if prune_original_later_mutual_dropped_result {
        let dropped_result = dae_try_remove_dropped_results(
          mod_,
          callee_abs,
          direct_calls[callee_abs],
          dropped_calls[callee_abs],
        )
        if dropped_result.changed {
          return dropped_result
        }
      }
      let preserve_original_undropped_self_result_from_no_param_dropped_caller = dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
        def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
        original_dead_suffix_mutual_calls,
      )
      let preserve_original_dropped_escaped_result_under_self_caller = def_idx <
        original_param_counts.length() &&
        original_param_counts[def_idx] > 0 &&
        def_idx < original_self_call_counts.length() &&
        original_self_call_counts[def_idx] == 0 &&
        def_idx < original_dead_suffix_dropped_escaped_result_calls.length() &&
        original_dead_suffix_dropped_escaped_result_calls[def_idx] &&
        def_idx <
        original_dead_suffix_dropped_calls_from_parameterized_self_callers.length() &&
        original_dead_suffix_dropped_calls_from_parameterized_self_callers[def_idx] >
        0 &&
        def_idx < original_escaped_dead_suffix_call_counts.length() &&
        original_escaped_dead_suffix_call_counts[def_idx] == 0
      let preserve_original_parameterized_undropped_self_side_chain = dae_should_preserve_parameterized_undropped_self_side_chain(
        def_idx, original_param_counts, original_call_counts, original_active_parameterized_nonself_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_result_other_calls,
      )
      if !preserve_original_same_self_result_operand &&
        !preserve_original_result_from_undropped_self_caller &&
        !preserve_original_escaped_result_operand_chain &&
        !preserve_original_mixed_self_result &&
        !preserve_original_param_operand_self_result_side_callee &&
        !preserve_original_undropped_self_result_from_no_param_dropped_caller &&
        !preserve_original_dropped_escaped_result_under_self_caller &&
        !preserve_original_parameterized_undropped_self_side_chain {
        let dropped_result = dae_try_remove_dropped_results(
          mod_,
          callee_abs,
          direct_calls[callee_abs],
          dropped_calls[callee_abs],
        )
        if dropped_result.changed {
          return dropped_result
        }
      }
      def_idx += 1
      continue
    }
    let @lib.Func(locals, _) = funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let remove = Array::make(params.length(), false)
    let mut any = false
    let mut p = 0
    while p < params.length() {
      if !local_use.gets[p] {
        remove[p] = true
        any = true
      }
      p += 1
    }
    let preserve_current_same_self_result_operand = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      def_idx < original_self_call_counts.length() &&
      original_self_call_counts[def_idx] > 0 &&
      def_idx < original_call_counts.length() &&
      original_call_counts[def_idx] >= original_self_call_counts[def_idx] &&
      def_idx < original_dead_suffix_same_self_result_operand_calls.length() &&
      original_dead_suffix_same_self_result_operand_calls[def_idx] &&
      def_idx < original_nonself_undropped_call_counts.length() &&
      original_nonself_undropped_call_counts[def_idx] > 0
    let preserve_current_result_from_undropped_self_caller = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      def_idx < original_self_call_counts.length() &&
      original_self_call_counts[def_idx] == 0 &&
      def_idx <
      original_dead_suffix_result_calls_from_undropped_self_callers.length() &&
      original_dead_suffix_result_calls_from_undropped_self_callers[def_idx] > 0 &&
      def_idx <
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers.length() &&
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers[def_idx] ==
      0 &&
      def_idx < original_escaped_dead_suffix_call_counts.length() &&
      original_escaped_dead_suffix_call_counts[def_idx] == 0 &&
      def_idx < original_active_nonself_call_counts.length() &&
      original_active_nonself_call_counts[def_idx] > 0
    let preserve_current_escaped_result_operand_chain = (
        def_idx < original_param_counts.length() &&
        original_param_counts[def_idx] > 0 &&
        def_idx <
        original_dead_suffix_escaped_result_operand_call_counts.length() &&
        original_dead_suffix_escaped_result_operand_call_counts[def_idx] > 0
      ) ||
      (
        def_idx < original_param_counts.length() &&
        original_param_counts[def_idx] == 0 &&
        def_idx <
        original_private_result_dead_suffix_calls_from_escaped_operand_callees.length() &&
        original_private_result_dead_suffix_calls_from_escaped_operand_callees[def_idx] >
        0
      )
    let preserve_current_mixed_self_result = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      def_idx < original_dead_suffix_undropped_self_calls.length() &&
      original_dead_suffix_undropped_self_calls[def_idx] &&
      def_idx < original_dead_suffix_dropped_self_calls.length() &&
      original_dead_suffix_dropped_self_calls[def_idx] &&
      def_idx < original_escaped_dead_suffix_call_counts.length() &&
      original_escaped_dead_suffix_call_counts[def_idx] == 0
    let preserve_current_undropped_self_result_from_no_param_dropped_caller = dae_should_preserve_undropped_self_result_from_no_param_dropped_caller(
      def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
      original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
      original_dead_suffix_mutual_calls,
    )
    let preserve_current_dropped_escaped_result_under_self_caller = def_idx <
      original_param_counts.length() &&
      original_param_counts[def_idx] > 0 &&
      def_idx < original_self_call_counts.length() &&
      original_self_call_counts[def_idx] == 0 &&
      def_idx < original_dead_suffix_dropped_escaped_result_calls.length() &&
      original_dead_suffix_dropped_escaped_result_calls[def_idx] &&
      def_idx <
      original_dead_suffix_dropped_calls_from_parameterized_self_callers.length() &&
      original_dead_suffix_dropped_calls_from_parameterized_self_callers[def_idx] >
      0 &&
      def_idx < original_escaped_dead_suffix_call_counts.length() &&
      original_escaped_dead_suffix_call_counts[def_idx] == 0
    let preserve_current_parameterized_undropped_self_side_chain = dae_should_preserve_parameterized_undropped_self_side_chain(
      def_idx, original_param_counts, original_call_counts, original_active_parameterized_nonself_call_counts,
      original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_result_other_calls,
    )
    if any {
      let result = dae_try_rewrite_candidate(
        mod_,
        callee_abs,
        remove,
        local_use,
        direct_calls[callee_abs],
      )
      if result.changed {
        return result
      }
    } else if !preserve_current_same_self_result_operand &&
      !preserve_current_result_from_undropped_self_caller &&
      !preserve_current_escaped_result_operand_chain &&
      !preserve_current_mixed_self_result &&
      !preserve_current_undropped_self_result_from_no_param_dropped_caller &&
      !preserve_current_dropped_escaped_result_under_self_caller &&
      !preserve_current_parameterized_undropped_self_side_chain {
      let dropped_result = dae_try_remove_dropped_results(
        mod_,
        callee_abs,
        direct_calls[callee_abs],
        dropped_calls[callee_abs],
      )
      if dropped_result.changed {
        return dropped_result
      }
    }
    def_idx += 1
  }
  { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
}

///|
fn dae_merge_touched(dst : Array[Bool], src : Array[Bool]) -> Array[Bool] {
  if dst.length() == 0 {
    return src.copy()
  }
  let out = dst.copy()
  let mut idx = 0
  while idx < src.length() && idx < out.length() {
    out[idx] = out[idx] || src[idx]
    idx += 1
  }
  out
}

///|
fn dae_run_core(mod_ : @lib.Module) -> DaePassResult {
  let mut current = mod_
  let mut touched : Array[Bool] = []
  let mut changed = false
  let original_param_counts = dae_collect_original_param_counts(mod_)
  let original_call_counts = dae_collect_original_call_counts(mod_)
  let original_prior_call_counts = dae_collect_original_prior_call_counts(mod_)
  let original_prior_undropped_call_counts = dae_collect_original_prior_undropped_call_counts(
    mod_,
  )
  let original_active_nonself_call_counts = dae_collect_original_active_nonself_call_counts(
    mod_,
  )
  let original_active_parameterized_nonself_call_counts = dae_collect_original_active_parameterized_nonself_call_counts(
    mod_,
  )
  let original_active_parameterized_result_nonself_call_counts = dae_collect_original_active_parameterized_result_nonself_call_counts(
    mod_,
  )
  let original_nonself_undropped_call_counts = dae_collect_original_nonself_undropped_call_counts(
    mod_,
  )
  let original_self_call_counts = dae_collect_original_self_call_counts(mod_)
  let original_private_result_dead_suffix_call_counts = dae_collect_original_private_result_dead_suffix_call_counts(
    mod_,
  )
  let original_private_result_same_operand_call_counts = dae_collect_original_private_result_same_operand_call_counts(
    mod_,
  )
  let original_private_result_escaped_operand_call_counts = dae_collect_original_private_result_escaped_operand_call_counts(
    mod_,
  )
  let original_dead_suffix_escaped_result_operand_call_counts = dae_collect_original_dead_suffix_escaped_result_operand_call_counts(
    mod_,
  )
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_, original_dead_suffix_escaped_result_operand_call_counts,
  )
  let original_escaped_dead_suffix_call_counts = dae_collect_original_escaped_dead_suffix_call_counts(
    mod_,
  )
  let original_escaped_undropped_dead_suffix_call_counts = dae_collect_original_escaped_undropped_dead_suffix_call_counts(
    mod_,
  )
  let original_dead_suffix_other_calls = dae_collect_original_dead_suffix_other_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_calls = dae_collect_original_dead_suffix_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_calls = dae_collect_original_dead_suffix_dropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_call_full_param_forwards = dae_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
    mod_,
  )
  let original_dead_suffix_result_calls_from_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers(
    mod_,
  )
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
  )
  let original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = dae_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
    mod_,
  )
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
    mod_,
  )
  let original_dead_suffix_dropped_earlier_result_calls = dae_collect_original_dead_suffix_dropped_earlier_result_calls(
    mod_,
  )
  let original_later_dead_suffix_dropped_call_counts = dae_collect_original_later_dead_suffix_dropped_call_counts(
    mod_,
  )
  let original_dead_suffix_same_self_result_operand_calls = dae_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_call_param_operands = dae_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
  )
  let original_dead_suffix_result_other_calls = dae_collect_original_dead_suffix_result_other_calls(
    mod_,
  )
  let original_dead_suffix_self_recursive_void_side_calls = dae_collect_original_dead_suffix_self_recursive_void_side_calls(
    mod_,
  )
  let original_dead_suffix_self_recursive_result_side_calls = dae_collect_original_dead_suffix_self_recursive_result_side_calls(
    mod_,
  )
  let original_dead_suffix_undropped_escaped_result_calls = dae_collect_original_dead_suffix_undropped_escaped_result_calls(
    mod_,
  )
  let original_dead_suffix_dropped_escaped_result_calls = dae_collect_original_dead_suffix_dropped_escaped_result_calls(
    mod_,
  )
  let original_dead_suffix_mutual_calls = dae_collect_original_dead_suffix_mutual_calls(
    mod_,
  )
  let original_dead_suffix_calls_from_param_operand_self_result_callers = dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
    mod_, original_param_counts, original_call_counts, original_active_nonself_call_counts,
    original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
    original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
    original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
    original_dead_suffix_mutual_calls,
  )
  let mut iter = 0
  while iter < 8 {
    let already_rewritten_defs = Array::make(
      dae_defined_func_count(current),
      false,
    )
    let result = dae_run_core_once(
      current, already_rewritten_defs, original_param_counts, original_call_counts,
      original_prior_call_counts, original_prior_undropped_call_counts, original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts, original_active_parameterized_result_nonself_call_counts,
      original_nonself_undropped_call_counts, original_self_call_counts, original_private_result_dead_suffix_call_counts,
      original_private_result_same_operand_call_counts, original_private_result_escaped_operand_call_counts,
      original_dead_suffix_escaped_result_operand_call_counts, original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts, original_escaped_undropped_dead_suffix_call_counts,
      original_dead_suffix_other_calls, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls, original_dead_suffix_dropped_self_call_full_param_forwards,
      original_dead_suffix_result_calls_from_undropped_self_callers, original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
      original_dead_suffix_dropped_calls_from_parameterized_self_callers, original_dead_suffix_dropped_earlier_result_calls,
      original_later_dead_suffix_dropped_call_counts, original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_result_other_calls, original_dead_suffix_self_recursive_void_side_calls,
      original_dead_suffix_self_recursive_result_side_calls, original_dead_suffix_undropped_escaped_result_calls,
      original_dead_suffix_dropped_escaped_result_calls, original_dead_suffix_mutual_calls,
    )
    if !result.changed {
      break
    }
    current = result.mod_out
    touched = dae_merge_touched(touched, result.touched)
    ignore(result.primary_def)
    changed = true
    iter += 1
  }
  { mod_out: current, touched, changed, primary_def: -1 }
}

///|
fn dae_count_touched(touched : Array[Bool]) -> Int {
  let mut count = 0
  for item in touched {
    if item {
      count += 1
    }
  }
  count
}

///|
fn dae_repair_dead_suffix_calls_to_touched(
  mod_ : @lib.Module,
  touched : Array[Bool],
) -> @lib.Module {
  if touched.length() == 0 {
    return mod_
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => return mod_
  }
  let imported = dae_imported_func_count(mod_)
  let mut any = false
  let mut def_idx = 0
  while def_idx < touched.length() {
    if touched[def_idx] {
      let callee_abs = imported + def_idx
      let mut func_idx = 0
      while func_idx < funcs.length() {
        let (repaired, changed) = dae_repair_dead_suffix_calls_func(
          funcs[func_idx],
          callee_abs,
        )
        if changed {
          funcs[func_idx] = repaired
          any = true
        }
        func_idx += 1
      }
    }
    def_idx += 1
  }
  if any {
    mod_.with_code_sec(@lib.CodeSec::new(funcs)).without_name_sec()
  } else {
    mod_
  }
}

///|
fn dae_run_nested_cleanup(
  mod_ : @lib.Module,
  touched : Array[Bool],
  trace : (String) -> Unit,
  optimize : Bool,
) -> @lib.Module {
  if !optimize || dae_count_touched(touched) == 0 {
    return mod_
  }
  trace(
    "pass[dae-optimizing]:nested-cleanup touched=\{dae_count_touched(touched)} prefix=precompute-propagate",
  )
  // The active hot-pipeline runner is whole-module; Binaryen's helper is
  // touched-function filtered. Until the filtered scheduler is available, keep
  // the boundary rewrite output valid and record the required nested lane without
  // applying unrelated cleanup to untouched functions.
  mod_
}

///|
pub fn dae_run_module_pass(
  mod_ : @lib.Module,
  optimize? : Bool = false,
  trace? : ((String) -> Unit)? = None,
) -> @lib.Module {
  let result = dae_run_core(mod_)
  let repaired = dae_repair_dead_suffix_calls_to_touched(
    result.mod_out,
    result.touched,
  )
  let trace_fn = match trace {
    Some(cb) => cb
    None => fn(_line : String) { () }
  }
  dae_prune_unused_simple_func_types(
    dae_run_nested_cleanup(repaired, result.touched, trace_fn, optimize),
  )
}
