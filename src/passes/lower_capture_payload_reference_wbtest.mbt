///|
// Lift captures local values before writes so analysis observes stack order.
// A capture can remain on the stack if the intervening instructions form a
// balanced prefix without consuming that value. Evaluation itself never moves.
fn payload_ownership_reference_pass_lower_map_children(
  instr : @lib.Instruction,
  transform : (Array[@lib.Instruction]) -> Array[@lib.Instruction],
) -> @lib.Instruction {
  match instr {
    @lib.Block(bt, @lib.Expr(body)) =>
      @lib.Instruction::block(bt, @lib.Expr::new(transform(body)))
    @lib.Loop(bt, @lib.Expr(body)) =>
      @lib.Instruction::loop_(bt, @lib.Expr::new(transform(body)))
    @lib.If(bt, yes, no) =>
      @lib.Instruction::if_(bt, transform(yes), no.map(transform))
    @lib.TryTable(bt, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(bt, catches, @lib.Expr::new(transform(body)))
    @lib.Try(bt, @lib.Expr(body), catches, delegate) =>
      @lib.Instruction::try_(
        bt,
        @lib.Expr::new(transform(body)),
        catches.map(fn(catch_) {
          match catch_ {
            @lib.LegacyCatch(tag, @lib.Expr(body)) =>
              @lib.LegacyCatch::tagged(tag, @lib.Expr::new(transform(body)))
            @lib.LegacyCatchAll(@lib.Expr(body)) =>
              @lib.LegacyCatch::all(@lib.Expr::new(transform(body)))
          }
        }),
        delegate~,
      )
    _ => instr
  }
}

///|
fn payload_ownership_reference_pass_lower_count_locals(
  instrs : Array[@lib.Instruction],
  gets : Array[Int32],
  writes : Array[Int32],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) => gets[index.to_int()] += 1
      @lib.LocalSet(@lib.LocalIdx(index))
      | @lib.LocalTee(@lib.LocalIdx(index)) => writes[index.to_int()] += 1
      _ =>
        payload_ownership_reference_pass_lower_count_child_locals(
          instr, gets, writes,
        )
    }
  }
}

///|
fn payload_ownership_reference_pass_lower_count_child_locals(
  instr : @lib.Instruction,
  gets : Array[Int32],
  writes : Array[Int32],
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      payload_ownership_reference_pass_lower_count_locals(body, gets, writes)
    @lib.If(_, yes, no) => {
      payload_ownership_reference_pass_lower_count_locals(yes, gets, writes)
      match no {
        Some(body) =>
          payload_ownership_reference_pass_lower_count_locals(
            body, gets, writes,
          )
        None => ()
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      payload_ownership_reference_pass_lower_count_locals(body, gets, writes)
      for catch_ in catches {
        let body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(body))
          | @lib.LegacyCatchAll(@lib.Expr(body)) => body
        }
        payload_ownership_reference_pass_lower_count_locals(body, gets, writes)
      }
    }
    _ => ()
  }
}

///|
fn payload_ownership_reference_pass_lower_remove_balanced_captures(
  instrs : Array[@lib.Instruction],
  start : Int32,
  gets : Array[Int32],
  writes : Array[Int32],
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let removed = Array::make(instrs.length(), false)
  let visit_body = fn(body) {
    payload_ownership_reference_pass_lower_remove_balanced_captures(
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
    out.push(
      payload_ownership_reference_pass_lower_map_children(instrs[i], visit_body),
    )
    i += 1
  }
  out
}

///|
fn payload_ownership_reference_pass_lower_remap_locals(
  instrs : Array[@lib.Instruction],
  indices : Array[Int32],
) -> Array[@lib.Instruction] {
  let visit_body = fn(body) {
    payload_ownership_reference_pass_lower_remap_locals(body, indices)
  }
  let out = Array::new(capacity=instrs.length())
  for instr in instrs {
    match instr {
      @lib.LocalTee(@lib.LocalIdx(index)) if indices[index.to_int()] < 0 =>
        continue
      _ => ()
    }
    out.push(
      match instr {
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
          )
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          if indices[index.to_int()] < 0 {
            @lib.Instruction::drop()
          } else {
            @lib.Instruction::local_set(
              @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
            )
          }
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          @lib.Instruction::local_tee(
            @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
          )
        _ =>
          payload_ownership_reference_pass_lower_map_children(instr, visit_body)
      },
    )
  }
  out
}

///|
fn payload_ownership_reference_pass_lower_compact_captures_with_map(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
  propagate_parameter_aliases~ : Bool = false,
  reorder_body_locals~ : Bool = false,
  local_name_sec~ : @lib.NameSec? = None,
  function_abs~ : Int32 = -1,
) -> (@lib.Func, Array[Int32]) {
  let @lib.Func(original_locals, _) = original
  let @lib.Func(locals, @lib.Expr(body)) = func
  if locals.length() <= original_locals.length() {
    return (func, Array::makei(params.length() + locals.length(), fn(i) { i }))
  }
  let count = params.length() + locals.length()
  let start = params.length() + original_locals.length()
  let gets = Array::make(count, 0)
  let writes = Array::make(count, 0)
  payload_ownership_reference_pass_lower_count_locals(body, gets, writes)
  let mut has_capture = !propagate_parameter_aliases
  let mut has_unused = false
  let mut has_single_write = false
  // The plain lowerer keeps its existing path. Optimizing cleanup can also
  // remove aliases, so prove whether either cleanup family has work here.
  if propagate_parameter_aliases {
    for local_id in start..<count {
      let reads = gets[local_id]
      let write_count = writes[local_id]
      if reads == 1 && write_count == 1 {
        has_capture = true
        break
      }
      has_single_write = has_single_write || write_count == 1
      has_unused = has_unused || reads == 0
    }
  }
  if !has_capture &&
    !has_unused &&
    (
      !has_single_write ||
      !dae2_has_parameter_alias(body, start, writes, stack_effects~)
    ) {
    // Capture removal needs single-read, single-write locals. With
    // no such pair, no dead declaration and no alias, the exact map is identity.
    let runs = locals.runs
    let mut normalize = false
    for index in 0..<runs.length() {
      if runs[index].count == 0U ||
        (index > 0 && runs[index - 1].vt == runs[index].vt) {
        normalize = true
        break
      }
    }
    let func = if normalize {
      @lib.Func::new(@lib.Locals::new(runs), @lib.Expr::new(body))
    } else {
      func
    }
    return (func, Array::makei(count, fn(i) { i }))
  }
  // Keep the existing leaf plan first: an earlier effect-spanning capture can
  // otherwise block several smaller overlapping captures. The second pass
  // only deletes additional pairs from that already valid stack plan.
  let body = if has_capture {
    payload_ownership_reference_pass_lower_remove_balanced_captures(
      body, start, gets, writes,
    )
  } else {
    body
  }
  let body = match stack_effects {
    Some(_) if has_capture => {
      let mut remaining = false
      for local_id in start..<count {
        if gets[local_id] == 1 && writes[local_id] == 1 {
          remaining = true
          break
        }
      }
      if remaining {
        payload_ownership_reference_pass_lower_remove_balanced_captures(
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
    _ => body
  }
  // Preserve the complete legacy capture plan before alias propagation.
  // Moving even a pure parameter read can otherwise obstruct a smaller stack
  // plan chosen for an overlapping computed value.
  let (body, unread_aliases) = if propagate_parameter_aliases &&
    (!has_unused || gets.any(fn(reads) { reads > 0 })) {
    payload_ownership_reference_cleanup_parameter_aliases(
      body,
      start,
      gets,
      writes,
      stack_effects~,
    )
  } else {
    (body, None)
  }
  if propagate_parameter_aliases {
    // The complete census and alias demand transfers include every nested and
    // legacy handler read. Retire only body-local writes with no remaining read;
    // remapping preserves the produced value (tee) or consumes it (set/drop).
    for local_id in start..<count {
      if gets[local_id] == 0 {
        writes[local_id] = 0
      }
    }
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
  if reorder_body_locals && start == params.length() {
    ignore(
      dae2_order_compacted_local_indices(
        indices,
        gets,
        writes,
        params.length(),
        retained,
        local_name_sec,
        function_abs,
      ),
    )
  }
  (
    @lib.Func::new(
      @lib.Locals::from_types(retained),
      @lib.Expr::new(
        match unread_aliases {
          Some(aliases) =>
            payload_ownership_reference_alias_remap(aliases, body, indices)
          None =>
            payload_ownership_reference_pass_lower_remap_locals(body, indices)
        },
      ),
    ),
    indices,
  )
}

///|
// The optimizing variant removes redundant capture pairs after its cleanup
// pipeline as well: SimplifyLocals may itself lift and materialize a stack
// value. Compact source and generated locals together to make reruns bounded.
fn payload_ownership_reference_dae2_cleanup_captures(
  mod_ : @lib.Module,
) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let params = rl_defined_func_param_cache(mod_)
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let candidates = Array::make(funcs.length(), false)
  let mut may_change = false
  for index = 0; index < funcs.length(); index = index + 1 {
    if dae2_cleanup_func_may_change(funcs[index], params[index], module_ctx) {
      candidates[index] = true
      may_change = true
    }
  }
  if !may_change {
    return mod_
  }
  let mut module_env : @validate.Env? = None
  let stack_effects = Some(fn(instr) {
    dae2_capture_stack_effect(instr, mod_, module_ctx)
  })
  let remaps : Array[Array[Int32]?] = []
  let changed_labels : Array[Bool] = []
  let bodies : Array[@lib.Func] = []
  let imported = rl_imported_func_count(mod_)
  for index = 0; index < funcs.length(); index = index + 1 {
    if !candidates[index] {
      bodies.push(funcs[index])
      remaps.push(None)
      changed_labels.push(false)
      continue
    }
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
    let (body, mapping) = payload_ownership_reference_pass_lower_compact_captures_with_map(
      input,
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      params[index],
      stack_effects~,
      propagate_parameter_aliases=true,
      reorder_body_locals=true,
      local_name_sec=mod_.name_sec,
      function_abs=imported + index,
    )
    bodies.push(body)
    remaps.push(Some(mapping))
  }
  let next = mod_.with_code_sec(@lib.CodeSec::new(bodies))
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

///|
// Frozen pre-change alias discovery entry; it returns the old replay workspace.
fn payload_ownership_reference_cleanup_parameter_aliases(
  instrs : Array[@lib.Instruction],
  start : Int32,
  reads : Array[Int32],
  writes : Array[Int32],
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
) -> (Array[@lib.Instruction], Dae2ParameterAliases?) {
  if !dae2_has_parameter_alias(instrs, start, writes, stack_effects~) {
    return (instrs, None)
  }
  let aliases = Dae2ParameterAliases::new(
    start,
    reads,
    writes,
    width_body=Some(instrs),
    stack_effects~,
  )
  aliases.discover(instrs)
  let mut unread = false
  // Active reads are flattened before copy recognition. An admitted source is
  // unwritten or has an ordinary dominating writer: alias writers never enter
  // established. Thus targets refer to nonalias roots, including reverse edges,
  // and retirement does not depend on index order or require a graph traversal.
  for local_id = reads.length() - 1; local_id >= start; local_id = local_id - 1 {
    let definition = aliases.targets[local_id]
    if definition < 0L {
      continue
    }
    if reads[local_id] == 0 {
      writes[local_id] = 0
      if (definition & 1L) == 0L {
        reads[(definition >> 1).to_int()] -= 1
      }
      unread = true
    }
  }
  // Reuse the restored active/undo workspace in the required final remap.
  // Keep metadata for partial aliases too: their writes stay, but later reads
  // still need forwarding. Discovery never constructs instruction storage.
  aliases.established = None
  aliases.width_body = None
  aliases.index_bounds = None
  (instrs, if unread || aliases.forwarded { Some(aliases) } else { None })
}

///|
// Frozen pre-change final alias replay. Recursion and child mapping remain
// inside this reference; no candidate aliases.remap method is called.
fn payload_ownership_reference_alias_remap(
  aliases : Dae2ParameterAliases,
  instrs : Array[@lib.Instruction],
  indices : Array[Int32],
) -> Array[@lib.Instruction] {
  let mark = aliases.undo.length()
  let out = Array::new(capacity=instrs.length())
  let visit_body = fn(body) {
    payload_ownership_reference_alias_remap(aliases, body, indices)
  }
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if aliases.targets[raw.to_int()] >=
        0L => {
        let local_id = raw.to_int()
        aliases.active[local_id] = (aliases.targets[local_id] >> 1).to_int()
        aliases.undo.push(local_id)
        if indices[local_id] < 0 {
          if instr is @lib.LocalSet(_) {
            match out.last() {
              Some(@lib.LocalGet(_)) => ignore(out.pop())
              _ => {
                let producer = dae2_alias_packet_get_position(out, out.length())
                if producer < 0 {
                  abort("missing local alias producer")
                }
                ignore(out.remove(producer))
              }
            }
          }
          continue
        }
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) if indices[raw.to_int()] < 0 => continue
      _ => ()
    }
    out.push(
      match instr {
        @lib.LocalGet(@lib.LocalIdx(raw)) => {
          let local_id = raw.to_int()
          let source = if aliases.active[local_id] >= 0 {
            aliases.active[local_id]
          } else {
            local_id
          }
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(indices[source].to_uint()),
          )
        }
        @lib.LocalSet(@lib.LocalIdx(raw)) =>
          if indices[raw.to_int()] < 0 {
            @lib.Instruction::drop()
          } else {
            @lib.Instruction::local_set(
              @lib.LocalIdx::new(indices[raw.to_int()].to_uint()),
            )
          }
        @lib.LocalTee(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_tee(
            @lib.LocalIdx::new(indices[raw.to_int()].to_uint()),
          )
        _ =>
          payload_ownership_reference_pass_lower_map_children(instr, visit_body)
      },
    )
  }
  while aliases.undo.length() > mark {
    aliases.active[aliases.undo.pop().unwrap()] = -1
  }
  out
}
