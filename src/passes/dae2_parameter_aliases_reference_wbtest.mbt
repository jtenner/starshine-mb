///|
fn parameter_alias_reference_pass_lower_count_locals(
  instrs : Array[@lib.Instruction],
  gets : Array[Int],
  writes : Array[Int],
) -> Unit {
  let visit_body = fn(body) {
    parameter_alias_reference_pass_lower_count_locals(body, gets, writes)
    body
  }
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) => gets[index.to_int()] += 1
      @lib.LocalSet(@lib.LocalIdx(index))
      | @lib.LocalTee(@lib.LocalIdx(index)) => writes[index.to_int()] += 1
      _ => ignore(pass_lower_map_children(instr, visit_body))
    }
  }
}

///|
fn parameter_alias_reference_pass_lower_remove_balanced_captures(
  instrs : Array[@lib.Instruction],
  start : Int,
  gets : Array[Int],
  writes : Array[Int],
  stack_effects? : ((@lib.Instruction) -> (Int, Int)?)? = None,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let removed = Array::make(instrs.length(), false)
  let visit_body = fn(body) {
    parameter_alias_reference_pass_lower_remove_balanced_captures(
      body,
      start,
      gets,
      writes,
      stack_effects~,
    )
  }
  let mut i = 0
  while i < instrs.length() {
    if removed[i] {
      i += 1
      continue
    }
    match instrs[i] {
      @lib.LocalSet(@lib.LocalIdx(index)) if index.to_int() >= start &&
        gets[index.to_int()] == 1 &&
        writes[index.to_int()] == 1 => {
        let mut height = 0
        let mut read_slot = -1
        // Keep this local cleanup bounded. Longer or structured intervals keep
        // their capture; their producer may throw or observe mutable state.
        for j = i + 1; j < instrs.length() && j <= i + 256; j = j + 1 {
          if removed[j] {
            continue
          }
          if instrs[j] is @lib.LocalGet(@lib.LocalIdx(read)) && read == index {
            if height == 0 {
              read_slot = j
            }
            break
          }
          match stack_effects {
            Some(query) => {
              match query(instrs[j]) {
                Some((inputs, outputs)) if inputs >= 0 &&
                  outputs >= 0 &&
                  inputs <= height => height = height - inputs + outputs
                _ => break
              }
              continue
            }
            None => ()
          }
          match instrs[j] {
            @lib.LocalGet(_)
            | @lib.GlobalGet(_)
            | @lib.I32Const(_)
            | @lib.I64Const(_)
            | @lib.F32Const(_)
            | @lib.F64Const(_)
            | @lib.RefNull(_)
            | @lib.RefFunc(_) => height += 1
            @lib.LocalSet(_) => {
              if height == 0 {
                break
              }
              height -= 1
            }
            @lib.Drop => {
              if height == 0 {
                break
              }
              height -= 1
            }
            @lib.LocalTee(_) => if height == 0 { break }
            @lib.Nop => ()
            _ => break
          }
        }
        if read_slot >= 0 {
          gets[index.to_int()] = 0
          writes[index.to_int()] = 0
          removed[read_slot] = true
          i += 1
          continue
        }
      }
      _ => ()
    }
    out.push(pass_lower_map_children(instrs[i], visit_body))
    i += 1
  }
  out
}

///|
fn parameter_alias_reference_pass_lower_remap_locals(
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
) -> Array[@lib.Instruction] {
  let visit_body = fn(body) {
    parameter_alias_reference_pass_lower_remap_locals(body, indices)
  }
  instrs.map(fn(instr) {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) =>
        @lib.Instruction::local_get(
          @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
        )
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        @lib.Instruction::local_set(
          @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
        )
      @lib.LocalTee(@lib.LocalIdx(index)) =>
        @lib.Instruction::local_tee(
          @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
        )
      _ => pass_lower_map_children(instr, visit_body)
    }
  })
}

///|
fn parameter_alias_reference_pass_lower_compact_captures_with_map(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
  stack_effects? : ((@lib.Instruction) -> (Int, Int)?)? = None,
) -> (@lib.Func, Array[Int]) {
  let @lib.Func(original_locals, _) = original
  let @lib.Func(locals, @lib.Expr(body)) = func
  if locals.length() <= original_locals.length() {
    return (func, Array::makei(params.length() + locals.length(), fn(i) { i }))
  }
  let count = params.length() + locals.length()
  let start = params.length() + original_locals.length()
  let gets = Array::make(count, 0)
  let writes = Array::make(count, 0)
  parameter_alias_reference_pass_lower_count_locals(body, gets, writes)
  // Keep the existing leaf plan first: an earlier effect-spanning capture can
  // otherwise block several smaller overlapping captures. The second pass
  // only deletes additional pairs from that already valid stack plan.
  let body = parameter_alias_reference_pass_lower_remove_balanced_captures(
    body, start, gets, writes,
  )
  let body = match stack_effects {
    Some(_) => {
      let mut remaining = false
      for local in start..<count {
        if gets[local] == 1 && writes[local] == 1 {
          remaining = true
          break
        }
      }
      if remaining {
        parameter_alias_reference_pass_lower_remove_balanced_captures(
          body,
          start,
          gets,
          writes,
          stack_effects~,
        )
      } else {
        body
      }
    }
    None => body
  }
  let indices = Array::makei(count, fn(i) { i })
  let retained : Array[@lib.ValType] = []
  for i = 0; i < locals.length(); i = i + 1 {
    let index = params.length() + i
    if index < start || gets[index] > 0 || writes[index] > 0 {
      indices[index] = params.length() + retained.length()
      retained.push(locals.get(i))
    } else {
      indices[index] = -1
    }
  }
  (
    @lib.Func::new(
      @lib.Locals::from_types(retained),
      @lib.Expr::new(
        parameter_alias_reference_pass_lower_remap_locals(body, indices),
      ),
    ),
    indices,
  )
}

///|
// The optimizing variant removes redundant capture pairs after its cleanup
// pipeline as well: SimplifyLocals may itself lift and materialize a stack
// value. Compact source and generated locals together to make reruns bounded.
fn dae2_parameter_aliases_reference_cleanup(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let params = rl_defined_func_param_cache(mod_)
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let mut module_env : @validate.Env? = None
  let stack_effects = Some(fn(instr) {
    dae2_capture_stack_effect(instr, mod_, module_ctx)
  })
  let remaps : Array[Array[Int]?] = []
  let changed_labels : Array[Bool] = []
  let bodies : Array[@lib.Func] = []
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[index]
    let (instrs, forwarding_changed, scalar) = dae2_cleanup_forwarding(
      instrs, module_ctx,
    )
    let input = @lib.Func::new(locals, @lib.Expr::new(instrs))
    let (input, labels_changed) = if scalar {
      let env = match module_env {
        Some(env) => env
        None => {
          let env = @validate.Env::new().with_module(mod_)
          module_env = Some(env)
          env
        }
      }
      let (input, blocks_changed) = pass_lower_cleanup_branchless_blocks(
        input,
        mod_,
        module_env=Some(env),
      )
      (input, forwarding_changed || blocks_changed)
    } else {
      (input, forwarding_changed)
    }
    changed_labels.push(labels_changed)
    let (body, mapping) = parameter_alias_reference_pass_lower_compact_captures_with_map(
      input,
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      params[index],
      stack_effects~,
    )
    bodies.push(body)
    remaps.push(Some(mapping))
  }
  let next = mod_.with_code_sec(@lib.CodeSec::new(bodies))
  let imported = rl_imported_func_count(mod_)
  match rl_rewrite_name_sec(mod_.name_sec, imported, remaps) {
    Some(names) => {
      // Removing a control label changes the ordinal of later labels. Keep
      // metadata for unchanged functions; changed functions have no label map.
      let label_names = match names.label_names {
        Some(@lib.IndirectNameMap(entries)) => {
          let retained = entries.filter(fn(entry) {
            let @lib.IndirectNameAssoc(index, _) = entry
            let defined = index.to_int() - imported
            defined < 0 ||
            defined >= changed_labels.length() ||
            !changed_labels[defined]
          })
          if retained.is_empty() {
            None
          } else {
            Some(@lib.IndirectNameMap::new(retained))
          }
        }
        None => None
      }
      next.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names~,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => next.without_name_sec()
  }
}
