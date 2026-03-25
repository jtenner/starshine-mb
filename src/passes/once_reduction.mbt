///|
pub fn once_reduction_summary() -> String {
  "Reduce repeated calls to run-once functions guarded by monotonic once globals."
}

///|
fn or_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn or_imported_global_count(mod_ : @lib.Module) -> Int {
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
fn or_bool_array_copy(values : Array[Bool]) -> Array[Bool] {
  let copied = Array::make(values.length(), false)
  for i = 0; i < values.length(); i = i + 1 {
    copied[i] = values[i]
  }
  copied
}

///|
fn or_min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn or_bool_array_equal(left : Array[Bool], right : Array[Bool]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i = 0; i < left.length(); i = i + 1 {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
fn or_bool_array_union_into(target : Array[Bool], source : Array[Bool]) -> Unit {
  let limit = or_min_int(target.length(), source.length())
  for i = 0; i < limit; i = i + 1 {
    if source[i] {
      target[i] = true
    }
  }
}

///|
fn or_bool_array_intersection(
  left : Array[Bool],
  right : Array[Bool],
) -> Array[Bool] {
  let limit = or_min_int(left.length(), right.length())
  let out = Array::make(limit, false)
  for i = 0; i < limit; i = i + 1 {
    out[i] = left[i] && right[i]
  }
  out
}

///|
fn or_initial_func_set(total_globals : Int, once_global : Int) -> Array[Bool] {
  let globals = Array::make(total_globals, false)
  if once_global >= 0 && once_global < total_globals {
    globals[once_global] = true
  }
  globals
}

///|
fn or_global_type_is_integer(global_type : @lib.GlobalType) -> Bool {
  match global_type {
    @lib.GlobalType(@lib.NumTypeValType(@lib.I32NumType), _) => true
    @lib.GlobalType(@lib.NumTypeValType(@lib.I64NumType), _) => true
    _ => false
  }
}

///|
fn or_prev_nonzero_integer_const(
  instrs : Array[@lib.Instruction],
  idx : Int,
) -> Bool {
  if idx <= 0 {
    return false
  }
  match instrs[idx - 1] {
    @lib.I32Const(@lib.I32(value)) => value != 0
    @lib.I64Const(@lib.I64(value)) => value != 0L
    _ => false
  }
}

///|
fn or_func_has_no_params_or_results(
  env : @validate.Env,
  abs_func_idx : Int,
) -> Bool {
  match
    env.get_functype_by_funcidx(
      @lib.FuncIdx::new(abs_func_idx.reinterpret_as_uint()),
    ) {
    Some(@lib.FuncType(params, results)) =>
      params.length() == 0 && results.length() == 0
    None => false
  }
}

///|
fn or_find_once_global(
  env : @validate.Env,
  abs_func_idx : Int,
  func : @lib.Func,
) -> Int {
  if !or_func_has_no_params_or_results(env, abs_func_idx) {
    return -1
  }
  let @lib.Func(_, @lib.Expr(instrs)) = func
  if instrs.length() < 4 {
    return -1
  }
  match (instrs[0], instrs[1], instrs[2], instrs[3]) {
    (
      @lib.GlobalGet(@lib.GlobalIdx(get_idx)),
      @lib.If(_, [@lib.Return], None),
      @lib.I32Const(@lib.I32(value)),
      @lib.GlobalSet(@lib.GlobalIdx(set_idx)),
    ) if get_idx == set_idx && value != 0 => get_idx.reinterpret_as_int()
    (
      @lib.GlobalGet(@lib.GlobalIdx(get_idx)),
      @lib.If(_, [@lib.Return], None),
      @lib.I64Const(@lib.I64(value)),
      @lib.GlobalSet(@lib.GlobalIdx(set_idx)),
    ) if get_idx == set_idx && value != 0L => get_idx.reinterpret_as_int()
    _ => -1
  }
}

///|
fn or_scan_instrs(
  instrs : Array[@lib.Instruction],
  read_counts : Array[Int],
  once_globals : Array[Bool],
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.GlobalGet(@lib.GlobalIdx(global_idx)) => {
        let slot = global_idx.reinterpret_as_int()
        if slot < read_counts.length() {
          read_counts[slot] += 1
        }
      }
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = global_idx.reinterpret_as_int()
        if slot < once_globals.length() &&
          once_globals[slot] &&
          !or_prev_nonzero_integer_const(instrs, idx) {
          once_globals[slot] = false
        }
      }
      @lib.Block(_, @lib.Expr(body)) =>
        or_scan_instrs(body, read_counts, once_globals)
      @lib.Loop(_, @lib.Expr(body)) =>
        or_scan_instrs(body, read_counts, once_globals)
      @lib.If(_, then_body, else_body) => {
        or_scan_instrs(then_body, read_counts, once_globals)
        match else_body {
          Some(else_body) =>
            or_scan_instrs(else_body, read_counts, once_globals)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        or_scan_instrs(body, read_counts, once_globals)
      _ => ()
    }
  }
}

///|
fn or_analyze_instrs(
  instrs : Array[@lib.Instruction],
  incoming : Array[Bool],
  once_globals : Array[Bool],
  once_func_globals : Array[Int],
  func_once_sets : Array[Array[Bool]],
) -> Array[Bool] {
  let current = or_bool_array_copy(incoming)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) => {
        let next = or_analyze_instrs(
          body, current, once_globals, once_func_globals, func_once_sets,
        )
        or_bool_array_union_into(current, next)
      }
      @lib.If(_, then_body, else_body) => {
        let then_set = or_analyze_instrs(
          then_body, current, once_globals, once_func_globals, func_once_sets,
        )
        let else_set = match else_body {
          Some(else_body) =>
            or_analyze_instrs(
              else_body, current, once_globals, once_func_globals, func_once_sets,
            )
          None => current
        }
        let next = or_bool_array_intersection(then_set, else_set)
        for i = 0; i < next.length(); i = i + 1 {
          current[i] = next[i]
        }
      }
      @lib.Loop(_, _) => ()
      @lib.TryTable(_, _, _) => ()
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = global_idx.reinterpret_as_int()
        if slot < once_globals.length() &&
          once_globals[slot] &&
          or_prev_nonzero_integer_const(instrs, idx) {
          current[slot] = true
        }
      }
      @lib.Call(@lib.FuncIdx(func_idx))
      | @lib.ReturnCall(@lib.FuncIdx(func_idx)) => {
        let func_slot = func_idx.reinterpret_as_int()
        if func_slot < once_func_globals.length() {
          let once_global = once_func_globals[func_slot]
          if once_global >= 0 {
            current[once_global] = true
          }
        }
        if func_slot < func_once_sets.length() {
          or_bool_array_union_into(current, func_once_sets[func_slot])
        }
      }
      _ => ()
    }
  }
  current
}

///|
fn or_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  incoming : Array[Bool],
  once_globals : Array[Bool],
  once_func_globals : Array[Int],
  func_once_sets : Array[Array[Bool]],
) -> Array[Bool] {
  let current = or_bool_array_copy(incoming)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let next = or_rewrite_instrs(
          body, current, once_globals, once_func_globals, func_once_sets,
        )
        instrs[idx] = @lib.Instruction::block(block_type, @lib.Expr::new(body))
        or_bool_array_union_into(current, next)
      }
      @lib.If(block_type, then_body, else_body) => {
        let then_set = or_rewrite_instrs(
          then_body, current, once_globals, once_func_globals, func_once_sets,
        )
        let else_set = match else_body {
          Some(else_body) =>
            or_rewrite_instrs(
              else_body, current, once_globals, once_func_globals, func_once_sets,
            )
          None => current
        }
        instrs[idx] = @lib.Instruction::if_(block_type, then_body, else_body)
        let next = or_bool_array_intersection(then_set, else_set)
        for i = 0; i < next.length(); i = i + 1 {
          current[i] = next[i]
        }
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        ignore(
          or_rewrite_instrs(
            body, current, once_globals, once_func_globals, func_once_sets,
          ),
        )
        instrs[idx] = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        ignore(
          or_rewrite_instrs(
            body, current, once_globals, once_func_globals, func_once_sets,
          ),
        )
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
      }
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = global_idx.reinterpret_as_int()
        if slot < once_globals.length() &&
          once_globals[slot] &&
          or_prev_nonzero_integer_const(instrs, idx) {
          if current[slot] {
            instrs[idx - 1] = @lib.Instruction::nop()
            instrs[idx] = @lib.Instruction::nop()
          }
          current[slot] = true
        }
      }
      @lib.Call(@lib.FuncIdx(func_idx)) => {
        let func_slot = func_idx.reinterpret_as_int()
        if func_slot < once_func_globals.length() {
          let once_global = once_func_globals[func_slot]
          if once_global >= 0 {
            if current[once_global] {
              instrs[idx] = @lib.Instruction::nop()
            } else {
              current[once_global] = true
            }
          }
        }
        if func_slot < func_once_sets.length() {
          or_bool_array_union_into(current, func_once_sets[func_slot])
        }
      }
      @lib.ReturnCall(@lib.FuncIdx(func_idx)) => {
        let func_slot = func_idx.reinterpret_as_int()
        if func_slot < once_func_globals.length() {
          let once_global = once_func_globals[func_slot]
          if once_global >= 0 {
            current[once_global] = true
          }
        }
        if func_slot < func_once_sets.length() {
          or_bool_array_union_into(current, func_once_sets[func_slot])
        }
      }
      _ => ()
    }
  }
  current
}

///|
fn or_optimize_once_bodies(
  funcs : Array[@lib.Func],
  imported_func_count : Int,
  once_func_globals : Array[Int],
) -> Bool {
  let removed_exit_logic = Array::make(once_func_globals.length(), false)
  let mut changed = false
  for defined_idx = 0
      defined_idx < funcs.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_func_count + defined_idx
    if abs_idx >= once_func_globals.length() || once_func_globals[abs_idx] < 0 {
      continue
    }
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[defined_idx]
    if instrs.length() == 4 {
      funcs[defined_idx] = @lib.Func::new(
        locals,
        @lib.Expr::new([@lib.Instruction::nop()]),
      )
      changed = true
      continue
    }
    if instrs.length() != 5 {
      continue
    }
    match instrs[4] {
      @lib.Call(@lib.FuncIdx(target)) => {
        let target_idx = target.reinterpret_as_int()
        if target_idx >= removed_exit_logic.length() ||
          once_func_globals[target_idx] < 0 ||
          removed_exit_logic[target_idx] {
          continue
        }
        funcs[defined_idx] = @lib.Func::new(
          locals,
          @lib.Expr::new([
            @lib.Instruction::nop(),
            @lib.Instruction::nop(),
            @lib.Instruction::nop(),
            @lib.Instruction::nop(),
            instrs[4],
          ]),
        )
        removed_exit_logic[abs_idx] = true
        changed = true
      }
      _ => ()
    }
  }
  changed
}

///|
pub fn once_reduction_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let env = @validate.Env::new().with_module(mod_)
  let total_globals = env.globals.length()
  let total_funcs = env.funcs.length()
  let imported_global_count = or_imported_global_count(mod_)
  let imported_func_count = or_imported_func_count(mod_)

  let once_globals = Array::make(total_globals, false)
  for global_idx = imported_global_count
      global_idx < total_globals
      global_idx = global_idx + 1 {
    once_globals[global_idx] = or_global_type_is_integer(
      env.globals[global_idx],
    )
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(global_idx))) => {
            let slot = global_idx.reinterpret_as_int()
            if slot < once_globals.length() {
              once_globals[slot] = false
            }
          }
          _ => ()
        }
      }
    None => ()
  }

  let once_func_globals = Array::make(total_funcs, -1)
  let read_counts = Array::make(total_globals, 0)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  for defined_idx = 0
      defined_idx < funcs.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_func_count + defined_idx
    let once_global = or_find_once_global(env, abs_idx, funcs[defined_idx])
    if once_global >= 0 {
      once_func_globals[abs_idx] = once_global
    }
    let @lib.Func(_, @lib.Expr(instrs)) = funcs[defined_idx]
    or_scan_instrs(instrs, read_counts, once_globals)
    if once_global >= 0 && once_global < read_counts.length() {
      read_counts[once_global] -= 1
    }
  }
  for global_idx = 0
      global_idx < read_counts.length()
      global_idx = global_idx + 1 {
    if read_counts[global_idx] > 0 {
      once_globals[global_idx] = false
    }
  }
  let mut found_once = false
  for func_idx = 0
      func_idx < once_func_globals.length()
      func_idx = func_idx + 1 {
    let once_global = once_func_globals[func_idx]
    if once_global >= 0 && !once_globals[once_global] {
      once_func_globals[func_idx] = -1
    }
    if once_func_globals[func_idx] >= 0 {
      found_once = true
    }
  }
  if !found_once {
    return mod_
  }

  let func_once_sets : Array[Array[Bool]] = []
  for func_idx = 0; func_idx < total_funcs; func_idx = func_idx + 1 {
    func_once_sets.push(
      or_initial_func_set(total_globals, once_func_globals[func_idx]),
    )
  }
  let mut changed_sets = true
  while changed_sets {
    changed_sets = false
    for defined_idx = 0
        defined_idx < funcs.length()
        defined_idx = defined_idx + 1 {
      let abs_idx = imported_func_count + defined_idx
      let @lib.Func(_, @lib.Expr(instrs)) = funcs[defined_idx]
      let next = or_analyze_instrs(
        instrs,
        or_initial_func_set(total_globals, once_func_globals[abs_idx]),
        once_globals,
        once_func_globals,
        func_once_sets,
      )
      if !or_bool_array_equal(next, func_once_sets[abs_idx]) {
        func_once_sets[abs_idx] = next
        changed_sets = true
      }
    }
  }

  let rewritten_funcs : Array[@lib.Func] = []
  let mut changed = false
  for defined_idx = 0
      defined_idx < funcs.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_func_count + defined_idx
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[defined_idx]
    let next_instrs : Array[@lib.Instruction] = []
    for instr in instrs {
      next_instrs.push(instr)
    }
    ignore(
      or_rewrite_instrs(
        next_instrs,
        or_initial_func_set(total_globals, once_func_globals[abs_idx]),
        once_globals,
        once_func_globals,
        func_once_sets,
      ),
    )
    let next_func = @lib.Func::new(locals, @lib.Expr::new(next_instrs))
    if next_func != funcs[defined_idx] {
      changed = true
    }
    rewritten_funcs.push(next_func)
  }
  if or_optimize_once_bodies(
      rewritten_funcs, imported_func_count, once_func_globals,
    ) {
    changed = true
  }
  if !changed {
    return mod_
  }
  mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
}
