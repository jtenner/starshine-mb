// Private WB-only counters. Strip the two exact seams and reverse
// row_probe_ names to recover the four normal c17 function blocks.

///|
fn row_probe_dae_mark_dead_suffix_escaped_result_operand_targets(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
  imported : Int32,
  defined : Int32,
  caller_stamps : Array[Int32],
  caller_def : Int32,
  counts : Array[Int32],
  dropped_calls : Array[Bool],
  require_dropped : Bool,
) -> Unit {
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
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        let def_idx = slot - imported
        if def_idx >= 0 && def_idx < defined && def_idx < caller_stamps.length() {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(params, _)) =>
              if dae_stack_bool_has_true_operand(
                  stack_from_escaped_call,
                  params.length(),
                ) {
                if caller_stamps[def_idx] != caller_def {
                  caller_stamps[def_idx] = caller_def
                  if def_idx != caller_def &&
                    (
                      !require_dropped ||
                      (
                        def_idx < dropped_calls.length() &&
                        dropped_calls[def_idx]
                      )
                    ) {
                    counts[def_idx] = counts[def_idx] + 1
                  }
                }
              }
            None => ()
          }
        }
        let from_escaped = slot >= 0 && slot < escaped.length() && escaped[slot]
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, from_escaped,
          ),
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        row_probe_dae_mark_dead_suffix_escaped_result_operand_targets(
          body, mod_, type_indices, escaped, imported, defined, caller_stamps, caller_def,
          counts, dropped_calls, require_dropped,
        )
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        row_probe_dae_mark_dead_suffix_escaped_result_operand_targets(
          then_body, mod_, type_indices, escaped, imported, defined, caller_stamps,
          caller_def, counts, dropped_calls, require_dropped,
        )
        row_probe_dae_mark_dead_suffix_escaped_result_operand_targets(
          else_body, mod_, type_indices, escaped, imported, defined, caller_stamps,
          caller_def, counts, dropped_calls, require_dropped,
        )
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        row_probe_dae_mark_dead_suffix_escaped_result_operand_targets(
          then_body, mod_, type_indices, escaped, imported, defined, caller_stamps,
          caller_def, counts, dropped_calls, require_dropped,
        )
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      _ =>
        ignore(
          dae_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
    }
    idx += 1
  }
}

///|
fn row_probe_dae_mark_dead_suffix_same_result_operand_targets(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  imported : Int32,
  defined : Int32,
  caller_stamps : Array[Int32],
  caller_def : Int32,
  counts : Array[Int32],
) -> Unit {
  let stack_sources : Array[Int32] = []
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
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        let def_idx = slot - imported
        let source = if slot >= imported && def_idx >= 0 && def_idx < defined {
          def_idx
        } else {
          -1
        }
        if source >= 0 && source < caller_stamps.length() {
          match dae_resolve_func_type(mod_, type_indices, slot) {
            Some(@lib.FuncType(params, _)) =>
              if dae_stack_int_has_operand_value(
                  stack_sources,
                  params.length(),
                  source,
                ) {
                if caller_stamps[source] != caller_def {
                  caller_stamps[source] = caller_def
                  if source != caller_def {
                    counts[source] = counts[source] + 1
                  }
                }
              }
            None => ()
          }
        }
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, source,
          ),
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        row_probe_dae_mark_dead_suffix_same_result_operand_targets(
          body, mod_, type_indices, imported, defined, caller_stamps, caller_def,
          counts,
        )
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        row_probe_dae_mark_dead_suffix_same_result_operand_targets(
          then_body, mod_, type_indices, imported, defined, caller_stamps, caller_def,
          counts,
        )
        row_probe_dae_mark_dead_suffix_same_result_operand_targets(
          else_body, mod_, type_indices, imported, defined, caller_stamps, caller_def,
          counts,
        )
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        row_probe_dae_mark_dead_suffix_same_result_operand_targets(
          then_body, mod_, type_indices, imported, defined, caller_stamps, caller_def,
          counts,
        )
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      _ =>
        ignore(
          dae_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
    }
    idx += 1
  }
}

///|
fn row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
  row_work~ : Array[Int32]? = None,
) -> Array[Int32] {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  // A defined caller index is a unique nonnegative stamp in this invocation.
  // Allocate only at the first eligible caller; no row clear is needed later.
  let mut caller_stamps : Array[Int32]? = None
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
      let stamps = match caller_stamps {
        Some(row) => row
        None => {
          let row = Array::make(defined, -1)
          caller_stamps = Some(row)
          match row_work {
            Some(work) => {
              work[0] += 1
              work[1] += row.length()
            }
            None => ()
          }
          row
        }
      }
      row_probe_dae_mark_dead_suffix_same_result_operand_targets(
        body, mod_, type_indices, imported, defined, stamps, caller_def, counts,
      )
    }
    caller_def += 1
  }
  counts
}

///|
fn row_probe_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
  dead_suffix_escaped_result_calls : DaeOriginalDeadSuffixEscapedResultCallFacts,
  row_work~ : Array[Int32]? = None,
) -> DaeOriginalEscapedResultOperandCallFacts {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let dead_suffix_escaped_result_operand_call_counts = Array::make(defined, 0)
  let private_result_escaped_operand_call_counts = Array::make(defined, 0)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return {
        dead_suffix_escaped_result_operand_call_counts,
        private_result_escaped_operand_call_counts,
      }
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  // A defined caller index is a unique nonnegative stamp in this invocation.
  // Allocate only at the first eligible caller; no row clear is needed later.
  let mut caller_stamps : Array[Int32]? = None
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_escaped = escaped[caller_abs]
    let caller_has_result = match
      dae_resolve_func_type(mod_, type_indices, caller_abs) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    let caller_is_private_result = !caller_is_escaped && caller_has_result
    if caller_is_escaped || caller_is_private_result {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let stamps = match caller_stamps {
        Some(row) => row
        None => {
          let row = Array::make(defined, -1)
          caller_stamps = Some(row)
          match row_work {
            Some(work) => {
              work[0] += 1
              work[1] += row.length()
            }
            None => ()
          }
          row
        }
      }
      // These caller roles are exclusive, so only one output row is selected.
      let counts = if caller_is_escaped {
        dead_suffix_escaped_result_operand_call_counts
      } else {
        private_result_escaped_operand_call_counts
      }
      row_probe_dae_mark_dead_suffix_escaped_result_operand_targets(
        body,
        mod_,
        type_indices,
        escaped,
        imported,
        defined,
        stamps,
        caller_def,
        counts,
        dead_suffix_escaped_result_calls.dropped_calls,
        caller_is_private_result,
      )
    }
    caller_def += 1
  }
  {
    dead_suffix_escaped_result_operand_call_counts,
    private_result_escaped_operand_call_counts,
  }
}
