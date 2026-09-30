///|
// Frozen V34 traversal, including its instruction-scoped callback.
fn callback_reference_pass_lower_count_locals(
  instrs : Array[@lib.Instruction],
  gets : Array[Int],
  writes : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) => gets[index.to_int()] += 1
      @lib.LocalSet(@lib.LocalIdx(index))
      | @lib.LocalTee(@lib.LocalIdx(index)) => writes[index.to_int()] += 1
      _ =>
        ignore(
          pass_lower_map_children(instr, fn(body) {
            callback_reference_pass_lower_count_locals(body, gets, writes)
            body
          }),
        )
    }
  }
}

///|
// Frozen V34 traversal, including its instruction-scoped callback.
fn callback_reference_pass_lower_remove_balanced_captures(
  instrs : Array[@lib.Instruction],
  start : Int,
  gets : Array[Int],
  writes : Array[Int],
  stack_effects? : ((@lib.Instruction) -> (Int, Int)?)? = None,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let removed = Array::make(instrs.length(), false)
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
      pass_lower_map_children(instrs[i], fn(body) {
        callback_reference_pass_lower_remove_balanced_captures(
          body,
          start,
          gets,
          writes,
          stack_effects~,
        )
      }),
    )
    i += 1
  }
  out
}

///|
// Frozen V34 traversal, including its instruction-scoped callback.
fn callback_reference_pass_lower_remap_locals(
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
) -> Array[@lib.Instruction] {
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
      _ =>
        pass_lower_map_children(instr, fn(body) {
          callback_reference_pass_lower_remap_locals(body, indices)
        })
    }
  })
}

///|
// Frozen V34 traversal, including its instruction-scoped callback.
fn callback_reference_pass_lower_compact_captures_with_map(
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
  callback_reference_pass_lower_count_locals(body, gets, writes)
  // Keep the existing leaf plan first: an earlier effect-spanning capture can
  // otherwise block several smaller overlapping captures. The second pass
  // only deletes additional pairs from that already valid stack plan.
  let body = callback_reference_pass_lower_remove_balanced_captures(
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
        callback_reference_pass_lower_remove_balanced_captures(
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
      @lib.Expr::new(callback_reference_pass_lower_remap_locals(body, indices)),
    ),
    indices,
  )
}

///|
// Frozen V34 traversal, including its instruction-scoped callback.
fn callback_reference_dae2_cleanup_forwarding(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext,
) -> (Array[@lib.Instruction], Bool, Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut scalar = false
  for instr in instrs {
    let instr = pass_lower_map_children(instr, fn(body) {
      let (body, nested_changed, nested_scalar) = callback_reference_dae2_cleanup_forwarding(
        body, module_ctx,
      )
      changed = changed || nested_changed
      scalar = scalar || nested_scalar
      body
    })
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) if !body.is_empty() &&
        body.all(fn(instr) { instr is @lib.LocalGet(_) }) => {
        let results = match block_type {
          @lib.ValTypeBlockType(_) => 1
          @lib.TypeIdxBlockType(index) =>
            match @ir.hot_module_resolve_type_func_type(module_ctx, index) {
              Some(@lib.FuncType([], results)) => results.length()
              _ => -1
            }
          _ => -1
        }
        if results == body.length() {
          out.append(body)
          changed = true
          scalar = scalar || results == 1
          continue
        }
      }
      _ => ()
    }
    out.push(instr)
  }
  (out, changed, scalar)
}

///|
// Frozen V34 branchless traversal.
fn callback_reference_pass_lower_flatten_branchless_blocks_into(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  out : Array[@lib.Instruction],
  label_keep? : Array[Bool]? = None,
) -> (Bool, Bool) {
  let mut changed = false
  let mut branchless = true
  for instr in instrs {
    let label_slot = match (label_keep, instr) {
      (
        Some(keep),
        @lib.Block(_, _)
        | @lib.Loop(_, _)
        | @lib.If(_, _, _)
        | @lib.TryTable(_, _, _)
        | @lib.Try(_, _, _, _),
      ) => {
        let slot = keep.length()
        keep.push(true)
        Some(slot)
      }
      _ => None
    }
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let body_start = out.length()
        let (body_changed, body_branchless) = callback_reference_pass_lower_flatten_branchless_blocks_into(
          body,
          env,
          out,
          label_keep~,
        )
        changed = changed || body_changed
        branchless = branchless && body_branchless
        let mut flatten = false
        if body_branchless {
          match env.expand_blocktype(block_type) {
            Ok((params, _)) if params.is_empty() => flatten = true
            _ => ()
          }
        }
        if flatten {
          // The body is already in the parent's output; no growing array copy.
          match (label_keep, label_slot) {
            (Some(keep), Some(slot)) => keep[slot] = false
            _ => ()
          }
          changed = true
          continue
        }
        let next_body : Array[@lib.Instruction] = []
        if body_changed {
          for idx = body_start; idx < out.length(); idx = idx + 1 {
            next_body.push(out[idx])
          }
        }
        while out.length() > body_start {
          ignore(out.pop())
        }
        out.push(
          if body_changed {
            @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
          } else {
            instr
          },
        )
        continue
      }
      _ => ()
    }
    let mut children_branchless = true
    let instr = pass_lower_map_children(instr, fn(body) {
      let (next, child_changed, child_branchless) = callback_reference_pass_lower_flatten_branchless_blocks(
        body,
        env,
        label_keep~,
      )
      changed = changed || child_changed
      children_branchless = children_branchless && child_branchless
      next
    })
    let transfers_control = match instr {
      @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.BrOnNull(_)
      | @lib.BrOnNonNull(_)
      | @lib.BrOnCast(_, _, _, _)
      | @lib.BrOnCastFail(_, _, _, _)
      | @lib.BrOnCastDescEq(_, _, _)
      | @lib.BrOnCastDescEqFail(_, _, _)
      | @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Unreachable
      | @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Rethrow(_)
      | @lib.Suspend(_)
      | @lib.Resume(_, _)
      | @lib.ResumeThrow(_, _, _)
      | @lib.ResumeThrowRef(_, _)
      | @lib.StackSwitch(_, _) => true
      _ => false
    }
    branchless = branchless && children_branchless && !transfers_control
    out.push(instr)
  }
  (changed, branchless)
}

///|
fn callback_reference_pass_lower_flatten_branchless_blocks(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  label_keep? : Array[Bool]? = None,
) -> (Array[@lib.Instruction], Bool, Bool) {
  let out : Array[@lib.Instruction] = []
  let (changed, branchless) = callback_reference_pass_lower_flatten_branchless_blocks_into(
    instrs,
    env,
    out,
    label_keep~,
  )
  (out, changed, branchless)
}
