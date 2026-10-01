///|
fn unread_write_reference_remap_locals(
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
) -> Array[@lib.Instruction] {
  let visit_body = fn(body) {
    unread_write_reference_remap_locals(body, indices)
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
fn unread_write_reference_compact(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
  stack_effects? : ((@lib.Instruction) -> (Int, Int)?)? = None,
  propagate_parameter_aliases? : Bool = false,
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
  pass_lower_count_locals(body, gets, writes)
  let mut has_capture = !propagate_parameter_aliases
  let mut has_unused = false
  let mut has_single_write = false
  // The plain lowerer keeps its existing path. Optimizing cleanup can also
  // remove aliases, so prove whether either cleanup family has work here.
  if propagate_parameter_aliases {
    for local_id in start..<count {
      if gets[local_id] == 1 && writes[local_id] == 1 {
        has_capture = true
        break
      }
      has_single_write = has_single_write || writes[local_id] == 1
      has_unused = has_unused || (gets[local_id] == 0 && writes[local_id] == 0)
    }
  }
  if !has_capture &&
    !has_unused &&
    (!has_single_write || !dae2_has_parameter_alias(body, start, writes)) {
    // Both capture passes only remove single-read, single-write locals. With
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
    pass_lower_remove_balanced_captures(body, start, gets, writes)
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
        pass_lower_remove_balanced_captures(
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
  let (body, unread_aliases) = if propagate_parameter_aliases {
    dae2_cleanup_parameter_aliases(body, start, gets, writes)
  } else {
    (body, None)
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
        match unread_aliases {
          Some(aliases) => aliases.unread_write_reference_remap(body, indices)
          None => unread_write_reference_remap_locals(body, indices)
        },
      ),
    ),
    indices,
  )
}

///|
// Replay only proved aliases while performing the already-required local remap.
// Discovery's active/undo workspace has been restored to its entry state. Each
// original writer activates its resolved root only in that lexical scope.
fn Dae2ParameterAliases::unread_write_reference_remap(
  self : Dae2ParameterAliases,
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
) -> Array[@lib.Instruction] {
  let mark = self.undo.length()
  let out = Array::new(capacity=instrs.length())
  let visit_body = fn(body) { self.unread_write_reference_remap(body, indices) }
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if self.targets[raw.to_int()] >=
        0L => {
        let local_id = raw.to_int()
        self.active[local_id] = (self.targets[local_id] >> 1).to_int()
        self.undo.push(local_id)
        if indices[local_id] < 0 {
          if instr is @lib.LocalSet(_) {
            match out.pop() {
              Some(@lib.LocalGet(_)) => ()
              _ => abort("missing local alias producer")
            }
          }
          continue
        }
      }
      _ => ()
    }
    out.push(
      match instr {
        @lib.LocalGet(@lib.LocalIdx(raw)) => {
          let local_id = raw.to_int()
          let source = if self.active[local_id] >= 0 {
            self.active[local_id]
          } else {
            local_id
          }
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(indices[source].to_uint()),
          )
        }
        @lib.LocalSet(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_set(
            @lib.LocalIdx::new(indices[raw.to_int()].to_uint()),
          )
        @lib.LocalTee(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_tee(
            @lib.LocalIdx::new(indices[raw.to_int()].to_uint()),
          )
        _ => pass_lower_map_children(instr, visit_body)
      },
    )
  }
  while self.undo.length() > mark {
    self.active[self.undo.pop().unwrap()] = -1
  }
  out
}
