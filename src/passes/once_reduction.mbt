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
fn or_bool_array_copy(values : @bitset.BitSet) -> @bitset.BitSet {
  values.copy()
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
fn or_bool_array_equal(left : @bitset.BitSet, right : @bitset.BitSet) -> Bool {
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
fn or_bool_array_union_into(
  target : @bitset.BitSet,
  source : @bitset.BitSet,
) -> Unit {
  let limit = or_min_int(target.length(), source.length())
  for i = 0; i < limit; i = i + 1 {
    if source[i] {
      target[i] = true
    }
  }
}

///|
fn or_bool_array_is_singleton(values : @bitset.BitSet, slot : Int) -> Bool {
  if slot < 0 || slot >= values.length() || !values[slot] {
    return false
  }
  for i = 0; i < values.length(); i = i + 1 {
    if i != slot && values[i] {
      return false
    }
  }
  true
}

///|
fn or_initial_func_summary_singletons(
  once_func_slots : Array[Int],
) -> @bitset.BitSet {
  let singletons = @bitset.BitSet::new(once_func_slots.length())
  for func_idx = 0; func_idx < once_func_slots.length(); func_idx = func_idx + 1 {
    singletons[func_idx] = once_func_slots[func_idx] >= 0
  }
  singletons
}

///|
fn or_initial_func_set(
  total_once_globals : Int,
  once_global_slot : Int,
) -> @bitset.BitSet {
  let globals = @bitset.BitSet::new(total_once_globals)
  if once_global_slot >= 0 && once_global_slot < total_once_globals {
    globals[once_global_slot] = true
  }
  globals
}

///|
fn or_slot_for_abs_idx(slots : Array[Int], abs_idx : UInt) -> Int {
  let slot = abs_idx.reinterpret_as_int()
  if slot < 0 || slot >= slots.length() {
    -1
  } else {
    slots[slot]
  }
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
fn or_prev_positive_integer_const(
  instrs : Array[@lib.Instruction],
  idx : Int,
) -> Bool {
  if idx <= 0 {
    return false
  }
  match instrs[idx - 1] {
    @lib.I32Const(@lib.I32(value)) => value > 0
    @lib.I64Const(@lib.I64(value)) => value > 0L
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
fn or_instrs_once_global(instrs : Array[@lib.Instruction]) -> Int {
  if instrs.length() < 4 {
    return -1
  }
  match (instrs[0], instrs[1], instrs[2], instrs[3]) {
    (
      @lib.GlobalGet(@lib.GlobalIdx(get_idx)),
      @lib.If(_, [@lib.Return], None),
      @lib.I32Const(@lib.I32(value)),
      @lib.GlobalSet(@lib.GlobalIdx(set_idx)),
    ) if get_idx == set_idx && value > 0 => get_idx.reinterpret_as_int()
    (
      @lib.GlobalGet(@lib.GlobalIdx(get_idx)),
      @lib.If(_, [@lib.Return], None),
      @lib.I64Const(@lib.I64(value)),
      @lib.GlobalSet(@lib.GlobalIdx(set_idx)),
    ) if get_idx == set_idx && value > 0L => get_idx.reinterpret_as_int()
    _ => -1
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
  let direct = or_instrs_once_global(instrs)
  if direct >= 0 {
    return direct
  }
  match instrs {
    [@lib.Block(_, @lib.Expr(body))] => or_instrs_once_global(body)
    _ => -1
  }
}

///|
fn or_is_empty_once_wrapper(func : @lib.Func) -> Bool {
  let @lib.Func(_, @lib.Expr(instrs)) = func
  if instrs.length() == 4 && or_instrs_once_global(instrs) >= 0 {
    return true
  }
  match instrs {
    [@lib.Block(_, @lib.Expr(body))] =>
      body.length() == 4 && or_instrs_once_global(body) >= 0
    _ => false
  }
}

///|
fn or_idempotent_func_flags(
  mod_ : @lib.Module,
  total_funcs : Int,
) -> @bitset.BitSet {
  let flags = @bitset.BitSet::new(total_funcs)
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(raw_idx, annotations) = entry
        let slot = raw_idx.reinterpret_as_int()
        if slot >= 0 && slot < flags.length() {
          for annotation in annotations {
            if annotation.name == "binaryen.idempotent" {
              flags[slot] = true
            }
          }
        }
      }
    None => ()
  }
  flags
}

///|
fn or_scan_instrs(
  instrs : Array[@lib.Instruction],
  read_counts : Array[Int],
  once_global_slots : Array[Int],
) -> Bool {
  let mut needs_dataflow = false
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.GlobalGet(@lib.GlobalIdx(global_idx)) => {
        let slot = or_slot_for_abs_idx(once_global_slots, global_idx)
        if slot >= 0 && slot < read_counts.length() {
          read_counts[slot] += 1
        }
      }
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = or_slot_for_abs_idx(once_global_slots, global_idx)
        if slot >= 0 &&
          slot < once_global_slots.length() &&
          !or_prev_positive_integer_const(instrs, idx) {
          once_global_slots[global_idx.reinterpret_as_int()] = -1
        }
        if slot >= 0 {
          needs_dataflow = true
        }
      }
      @lib.Block(_, @lib.Expr(body)) =>
        needs_dataflow = or_scan_instrs(body, read_counts, once_global_slots) ||
          needs_dataflow
      @lib.Loop(_, @lib.Expr(body)) =>
        needs_dataflow = or_scan_instrs(body, read_counts, once_global_slots) ||
          needs_dataflow
      @lib.If(_, then_body, else_body) => {
        needs_dataflow = or_scan_instrs(
            then_body, read_counts, once_global_slots,
          ) ||
          needs_dataflow
        match else_body {
          Some(else_body) =>
            needs_dataflow = or_scan_instrs(
                else_body, read_counts, once_global_slots,
              ) ||
              needs_dataflow
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        needs_dataflow = or_scan_instrs(body, read_counts, once_global_slots) ||
          needs_dataflow
      @lib.Call(_) => needs_dataflow = true
      @lib.ReturnCall(_) | @lib.Return | @lib.Br(_) | @lib.Unreachable =>
        return needs_dataflow
      _ => ()
    }
  }
  needs_dataflow
}

///|
fn or_analyze_instrs(
  instrs : Array[@lib.Instruction],
  incoming : @bitset.BitSet,
  once_global_slots : Array[Int],
  once_func_slots : Array[Int],
  func_once_sets : Array[@bitset.BitSet],
  func_once_set_singletons : @bitset.BitSet,
  allow_transitive_call_summaries : Bool,
) -> @bitset.BitSet {
  let current = or_bool_array_copy(incoming)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) => {
        let next = or_analyze_instrs(
          body, current, once_global_slots, once_func_slots, func_once_sets, func_once_set_singletons,
          allow_transitive_call_summaries,
        )
        or_bool_array_union_into(current, next)
      }
      @lib.If(_, then_body, else_body) => {
        ignore(
          or_analyze_instrs(
            then_body, current, once_global_slots, once_func_slots, func_once_sets,
            func_once_set_singletons, allow_transitive_call_summaries,
          ),
        )
        match else_body {
          Some(else_body) =>
            ignore(
              or_analyze_instrs(
                else_body, current, once_global_slots, once_func_slots, func_once_sets,
                func_once_set_singletons, allow_transitive_call_summaries,
              ),
            )
          None => ()
        }
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        let next = or_analyze_instrs(
          body, current, once_global_slots, once_func_slots, func_once_sets, func_once_set_singletons,
          allow_transitive_call_summaries,
        )
        or_bool_array_union_into(current, next)
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        let next = or_analyze_instrs(
          body, current, once_global_slots, once_func_slots, func_once_sets, func_once_set_singletons,
          allow_transitive_call_summaries,
        )
        or_bool_array_union_into(current, next)
      }
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = or_slot_for_abs_idx(once_global_slots, global_idx)
        if slot >= 0 && or_prev_positive_integer_const(instrs, idx) {
          current[slot] = true
        }
      }
      @lib.Call(@lib.FuncIdx(func_idx)) => {
        let func_slot = func_idx.reinterpret_as_int()
        let mut direct_singleton = false
        if func_slot < once_func_slots.length() {
          let once_global = once_func_slots[func_slot]
          if once_global >= 0 {
            current[once_global] = true
            direct_singleton = func_slot < func_once_set_singletons.length() &&
              func_once_set_singletons[func_slot]
          }
        }
        if allow_transitive_call_summaries &&
          func_slot < func_once_sets.length() &&
          !direct_singleton {
          or_bool_array_union_into(current, func_once_sets[func_slot])
        }
      }
      @lib.ReturnCall(_) | @lib.Return | @lib.Br(_) | @lib.Unreachable =>
        return current
      _ => ()
    }
  }
  current
}

///|
fn or_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  incoming : @bitset.BitSet,
  once_global_slots : Array[Int],
  once_func_slots : Array[Int],
  func_once_sets : Array[@bitset.BitSet],
  func_once_set_singletons : @bitset.BitSet,
  allow_transitive_call_summaries : Bool,
) -> @bitset.BitSet {
  let current = or_bool_array_copy(incoming)
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let next = or_rewrite_instrs(
          body, current, once_global_slots, once_func_slots, func_once_sets, func_once_set_singletons,
          allow_transitive_call_summaries,
        )
        instrs[idx] = @lib.Instruction::block(block_type, @lib.Expr::new(body))
        or_bool_array_union_into(current, next)
      }
      @lib.If(block_type, then_body, else_body) => {
        ignore(
          or_rewrite_instrs(
            then_body, current, once_global_slots, once_func_slots, func_once_sets,
            func_once_set_singletons, allow_transitive_call_summaries,
          ),
        )
        match else_body {
          Some(else_body) =>
            ignore(
              or_rewrite_instrs(
                else_body, current, once_global_slots, once_func_slots, func_once_sets,
                func_once_set_singletons, allow_transitive_call_summaries,
              ),
            )
          None => ()
        }
        instrs[idx] = @lib.Instruction::if_(block_type, then_body, else_body)
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let next = or_rewrite_instrs(
          body, current, once_global_slots, once_func_slots, func_once_sets, func_once_set_singletons,
          allow_transitive_call_summaries,
        )
        instrs[idx] = @lib.Instruction::loop_(block_type, @lib.Expr::new(body))
        or_bool_array_union_into(current, next)
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let next = or_rewrite_instrs(
          body, current, once_global_slots, once_func_slots, func_once_sets, func_once_set_singletons,
          allow_transitive_call_summaries,
        )
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(body),
        )
        or_bool_array_union_into(current, next)
      }
      @lib.GlobalSet(@lib.GlobalIdx(global_idx)) => {
        let slot = or_slot_for_abs_idx(once_global_slots, global_idx)
        if slot >= 0 && or_prev_positive_integer_const(instrs, idx) {
          if current[slot] {
            instrs[idx - 1] = @lib.Instruction::nop()
            instrs[idx] = @lib.Instruction::nop()
          }
          current[slot] = true
        }
      }
      @lib.Call(@lib.FuncIdx(func_idx)) => {
        let func_slot = func_idx.reinterpret_as_int()
        let mut direct_singleton = false
        if func_slot < once_func_slots.length() {
          let once_global = once_func_slots[func_slot]
          if once_global >= 0 {
            if current[once_global] {
              instrs[idx] = @lib.Instruction::nop()
            } else {
              current[once_global] = true
            }
            direct_singleton = func_slot < func_once_set_singletons.length() &&
              func_once_set_singletons[func_slot]
          }
        }
        if allow_transitive_call_summaries &&
          func_slot < func_once_sets.length() &&
          !direct_singleton {
          or_bool_array_union_into(current, func_once_sets[func_slot])
        }
      }
      @lib.ReturnCall(_) | @lib.Return | @lib.Br(_) | @lib.Unreachable =>
        return current
      _ => ()
    }
  }
  current
}

///|
fn or_cleanup_unreachable_debris(
  funcs : Array[@lib.Func],
) -> (Array[@lib.Func], Bool) {
  let out : Array[@lib.Func] = []
  let mut changed = false
  for idx = 0; idx < funcs.length(); idx = idx + 1 {
    let func = funcs[idx]
    let @lib.Func(locals, @lib.Expr(instrs)) = func
    let (next_instrs, func_changed) = pass_raw_remove_dropped_unreachable_debris(
      instrs,
    )
    if func_changed {
      out.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
      changed = true
    } else {
      out.push(func)
    }
  }
  (out, changed)
}

///|
fn or_optimize_once_bodies(
  funcs : Array[@lib.Func],
  imported_func_count : Int,
  once_func_globals : Array[Int],
  once_func_slots : Array[Int],
) -> Bool {
  let removed_exit_logic = @bitset.BitSet::new(once_func_globals.length())
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
    if instrs.length() == 1 {
      match instrs[0] {
        @lib.Block(_, @lib.Expr(body)) => {
          if body.length() == 4 {
            funcs[defined_idx] = @lib.Func::new(
              locals,
              @lib.Expr::new([@lib.Instruction::nop()]),
            )
            changed = true
            continue
          }
          if body.length() == 5 {
            match body[4] {
              @lib.Call(@lib.FuncIdx(target)) => {
                let target_idx = target.reinterpret_as_int()
                if target_idx < removed_exit_logic.length() &&
                  target_idx < once_func_slots.length() &&
                  once_func_slots[target_idx] >= 0 &&
                  !removed_exit_logic[target_idx] {
                  funcs[defined_idx] = @lib.Func::new(
                    locals,
                    @lib.Expr::new([
                      @lib.Instruction::nop(),
                      @lib.Instruction::nop(),
                      @lib.Instruction::nop(),
                      @lib.Instruction::nop(),
                      body[4],
                    ]),
                  )
                  removed_exit_logic[abs_idx] = true
                  changed = true
                }
              }
              _ => ()
            }
          }
        }
        _ => ()
      }
      continue
    }
    if instrs.length() != 5 {
      continue
    }
    match instrs[4] {
      @lib.Call(@lib.FuncIdx(target)) => {
        let target_idx = target.reinterpret_as_int()
        if target_idx >= removed_exit_logic.length() ||
          target_idx >= once_func_slots.length() ||
          once_func_slots[target_idx] < 0 ||
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
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }

  let exported_globals = @bitset.BitSet::new(total_globals)
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(global_idx))) => {
            let slot = global_idx.reinterpret_as_int()
            if slot < exported_globals.length() {
              exported_globals[slot] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  let candidate_global_slots = Array::make(total_globals, -1)
  let mut candidate_global_count = 0
  for global_idx = imported_global_count
      global_idx < total_globals
      global_idx = global_idx + 1 {
    if !exported_globals[global_idx] &&
      or_global_type_is_integer(env.globals[global_idx]) {
      candidate_global_slots[global_idx] = candidate_global_count
      candidate_global_count += 1
    }
  }
  let idempotent_funcs = or_idempotent_func_flags(mod_, total_funcs)

  let once_func_globals = Array::make(total_funcs, -1)
  let func_needs_dataflow = @bitset.BitSet::new(funcs.length())
  let read_counts = Array::make(candidate_global_count, 0)
  for defined_idx = 0
      defined_idx < funcs.length()
      defined_idx = defined_idx + 1 {
    let abs_idx = imported_func_count + defined_idx
    let once_global = or_find_once_global(env, abs_idx, funcs[defined_idx])
    if once_global >= 0 &&
      once_global < candidate_global_slots.length() &&
      candidate_global_slots[once_global] >= 0 {
      once_func_globals[abs_idx] = once_global
    }
    let @lib.Func(_, @lib.Expr(instrs)) = funcs[defined_idx]
    let needs_dataflow = or_scan_instrs(
      instrs, read_counts, candidate_global_slots,
    )
    func_needs_dataflow[defined_idx] = needs_dataflow &&
      !(once_global >= 0 && or_is_empty_once_wrapper(funcs[defined_idx]))
    if once_global >= 0 && once_global < candidate_global_slots.length() {
      let once_slot = candidate_global_slots[once_global]
      if once_slot >= 0 && once_slot < read_counts.length() {
        read_counts[once_slot] -= 1
      }
    }
  }

  let active_global_slots = Array::make(total_globals, -1)
  let mut active_global_count = 0
  for global_idx = 0; global_idx < total_globals; global_idx = global_idx + 1 {
    let candidate_slot = candidate_global_slots[global_idx]
    if candidate_slot >= 0 &&
      read_counts[candidate_slot] <= 0 &&
      candidate_global_slots[global_idx] >= 0 {
      active_global_slots[global_idx] = active_global_count
      active_global_count += 1
    }
  }
  let once_func_slots = Array::make(total_funcs, -1)
  let mut found_once = false
  for func_idx = 0
      func_idx < once_func_globals.length()
      func_idx = func_idx + 1 {
    let once_global = once_func_globals[func_idx]
    if once_global >= 0 && once_global < active_global_slots.length() {
      let once_slot = active_global_slots[once_global]
      if once_slot >= 0 {
        once_func_slots[func_idx] = once_slot
        found_once = true
      }
    }
  }
  let mut total_once_slots = active_global_count
  for func_idx = 0; func_idx < total_funcs; func_idx = func_idx + 1 {
    if once_func_slots[func_idx] < 0 &&
      idempotent_funcs[func_idx] &&
      or_func_has_no_params_or_results(env, func_idx) {
      once_func_slots[func_idx] = total_once_slots
      total_once_slots += 1
      found_once = true
    }
  }
  if !found_once {
    let (cleaned_funcs, cleanup_changed) = or_cleanup_unreachable_debris(funcs)
    if cleanup_changed {
      return mod_.with_code_sec(@lib.CodeSec::new(cleaned_funcs))
    }
    return mod_
  }

  let func_initial_once_sets : Array[@bitset.BitSet] = []
  let func_once_sets : Array[@bitset.BitSet] = []
  for func_idx = 0; func_idx < total_funcs; func_idx = func_idx + 1 {
    let initial = or_initial_func_set(
      total_once_slots,
      once_func_slots[func_idx],
    )
    func_initial_once_sets.push(initial)
    func_once_sets.push(initial)
  }
  let func_once_set_singletons = or_initial_func_summary_singletons(
    once_func_slots,
  )
  let mut changed_sets = true
  while changed_sets {
    changed_sets = false
    for defined_idx = 0
        defined_idx < funcs.length()
        defined_idx = defined_idx + 1 {
      if !func_needs_dataflow[defined_idx] {
        continue
      }
      let abs_idx = imported_func_count + defined_idx
      let @lib.Func(_, @lib.Expr(instrs)) = funcs[defined_idx]
      let next = or_analyze_instrs(
        instrs,
        @bitset.BitSet::new(total_once_slots),
        active_global_slots,
        once_func_slots,
        func_once_sets,
        func_once_set_singletons,
        once_func_slots[abs_idx] < 0,
      )
      if !or_bool_array_equal(next, func_once_sets[abs_idx]) {
        func_once_sets[abs_idx] = next
        func_once_set_singletons[abs_idx] = or_bool_array_is_singleton(
          next,
          once_func_slots[abs_idx],
        )
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
    if !func_needs_dataflow[defined_idx] {
      rewritten_funcs.push(funcs[defined_idx])
      continue
    }
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[defined_idx]
    let next_instrs : Array[@lib.Instruction] = []
    for instr in instrs {
      next_instrs.push(instr)
    }
    ignore(
      or_rewrite_instrs(
        next_instrs,
        @bitset.BitSet::new(total_once_slots),
        active_global_slots,
        once_func_slots,
        func_once_sets,
        func_once_set_singletons,
        once_func_slots[abs_idx] < 0,
      ),
    )
    let next_func = @lib.Func::new(locals, @lib.Expr::new(next_instrs))
    if next_func != funcs[defined_idx] {
      changed = true
    }
    rewritten_funcs.push(next_func)
  }
  if or_optimize_once_bodies(
      rewritten_funcs, imported_func_count, once_func_globals, once_func_slots,
    ) {
    changed = true
  }
  let (cleaned_funcs, cleanup_changed) = or_cleanup_unreachable_debris(
    rewritten_funcs,
  )
  if cleanup_changed {
    changed = true
  }
  if !changed {
    return mod_
  }
  mod_.with_code_sec(@lib.CodeSec::new(cleaned_funcs))
}
