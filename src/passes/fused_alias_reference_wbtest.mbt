///|
// Frozen V54 discovery/forwarding and complete compaction.

///|
priv struct FusedAliasReference {
  start : Int
  mut established : Array[Bool]?
  reads : Array[Int]
  writes : Array[Int]
  active : Array[@lib.Instruction?]
  targets : Array[Int64]
  undo : Array[Int]
}

///|
fn FusedAliasReference::new(
  start : Int,
  reads : Array[Int],
  writes : Array[Int],
) -> FusedAliasReference {
  {
    start,
    established: None,
    reads,
    writes,
    active: Array::make(reads.length(), None),
    targets: Array::make(reads.length(), -1L),
    undo: [],
  }
}

///|
fn fused_alias_reference_alias_source_is_nonwidening(
  source : Int,
  target : Int,
) -> Bool {
  // Compaction never increases indices. A reverse edge is safe only when both
  // indices already fit in one byte; equal wider LEB widths may later diverge.
  source != target && (source < target || source < 128)
}

///|
// Every target has one static write. A lexical child inherits dominating
// aliases but restores its own definitions on exit; no local-array copies or
// joins are needed. A source is unwritten or its single writer dominates the
// alias in the current lexical scope. A static writer may repeat in a loop,
// so its definition must precede the alias in that same active iteration.
fn FusedAliasReference::replace_reads(
  self : FusedAliasReference,
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let mark = self.undo.length()
  let out = Array::new(capacity=instrs.length())
  let visit_body = fn(body) { self.replace_reads(body) }
  for instr in instrs {
    let instr = match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        match self.active[raw.to_int()] {
          Some(source) => {
            let base = match source {
              @lib.LocalGet(@lib.LocalIdx(base)) => base
              _ => abort("invalid local alias")
            }
            self.reads[raw.to_int()] -= 1
            self.reads[base.to_int()] += 1
            source
          }
          None => instr
        }
      _ => pass_lower_map_children(instr, visit_body)
    }
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if self.writes[raw.to_int()] ==
        1 => {
        let local_id = raw.to_int()
        let mut is_alias = false
        if local_id >= self.start {
          match out.last() {
            Some(source) if source is @lib.LocalGet(@lib.LocalIdx(base)) &&
              fused_alias_reference_alias_source_is_nonwidening(
                base.to_int(),
                local_id,
              ) &&
              (
                self.writes[base.to_int()] == 0 ||
                (
                  self.writes[base.to_int()] == 1 &&
                  self.is_established(base.to_int())
                )
              ) => {
              self.active[local_id] = Some(source)
              // The width guard also covers partial forwarding when an
              // earlier/default read retains the alias declaration.
              let kind = if instr is @lib.LocalTee(_) { 1L } else { 0L }
              self.targets[local_id] = base.to_int().to_int64() * 2L + kind
              is_alias = true
            }
            _ => ()
          }
        }
        if is_alias {
          // Reads through active aliases are already resolved to their source,
          // so alias targets need no separate established-definition entry.
          self.undo.push(local_id)
        } else if self.reads[local_id] > 0 {
          let established = match self.established {
            Some(facts) => facts
            None => {
              let facts = Array::make(self.reads.length(), false)
              self.established = Some(facts)
              facts
            }
          }
          established[local_id] = true
          self.undo.push(-local_id - 1)
        }
      }
      _ => ()
    }
    out.push(instr)
  }
  while self.undo.length() > mark {
    let entry = self.undo.pop().unwrap()
    if entry >= 0 {
      self.active[entry] = None
    } else {
      self.established.unwrap()[-entry - 1] = false
    }
  }
  out
}

///|
fn FusedAliasReference::is_established(
  self : FusedAliasReference,
  local_id : Int,
) -> Bool {
  match self.established {
    Some(facts) => facts[local_id]
    None => false
  }
}

///|
fn fused_alias_reference_has_parameter_alias(
  instrs : Array[@lib.Instruction],
  start : Int,
  writes : Array[Int],
) -> Bool {
  for position in 0..<instrs.length() {
    match instrs[position] {
      @lib.LocalSet(@lib.LocalIdx(target))
      | @lib.LocalTee(@lib.LocalIdx(target)) if position > 0 &&
        target.to_int() >= start &&
        writes[target.to_int()] == 1 =>
        match instrs[position - 1] {
          @lib.LocalGet(@lib.LocalIdx(source)) if fused_alias_reference_alias_source_is_nonwidening(
              source.to_int(),
              target.to_int(),
            ) &&
            writes[source.to_int()] <= 1 => return true
          _ => ()
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if fused_alias_reference_has_parameter_alias(body, start, writes) {
          return true
        }
      @lib.If(_, yes, no) => {
        if fused_alias_reference_has_parameter_alias(yes, start, writes) {
          return true
        }
        match no {
          Some(body) =>
            if fused_alias_reference_has_parameter_alias(body, start, writes) {
              return true
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if fused_alias_reference_has_parameter_alias(body, start, writes) {
          return true
        }
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          if fused_alias_reference_has_parameter_alias(body, start, writes) {
            return true
          }
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn fused_alias_reference_cleanup_parameter_aliases(
  instrs : Array[@lib.Instruction],
  start : Int,
  reads : Array[Int],
  writes : Array[Int],
) -> (Array[@lib.Instruction], Array[Int64]?) {
  if !fused_alias_reference_has_parameter_alias(instrs, start, writes) {
    return (instrs, None)
  }
  let aliases = FusedAliasReference::new(start, reads, writes)
  let body = aliases.replace_reads(instrs)
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
    } else {
      aliases.targets[local_id] = -1L
    }
  }
  (body, if unread { Some(aliases.targets) } else { None })
}

///|
// Remove dead alias writes while performing the already-required local remap.
// Other producers retain their order and position. The no-alias path continues
// to use the original exact-sized map without allocating this visitor/output.
fn fused_alias_reference_parameter_aliases_remap(
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
  aliases : Array[Int64],
) -> Array[@lib.Instruction] {
  let out = Array::new(capacity=instrs.length())
  let visit_body = fn(body) {
    fused_alias_reference_parameter_aliases_remap(body, indices, aliases)
  }
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) if aliases[raw.to_int()] >= 0L => {
        match out.pop() {
          Some(@lib.LocalGet(_)) => ()
          _ => abort("missing local alias producer")
        }
        continue
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) if aliases[raw.to_int()] >= 0L =>
        continue
      _ => ()
    }
    out.push(
      match instr {
        @lib.LocalGet(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(indices[raw.to_int()].to_uint()),
          )
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
  out
}

///|
fn fused_alias_reference_compact(
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
    (
      !has_single_write ||
      !fused_alias_reference_has_parameter_alias(body, start, writes)
    ) {
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
    fused_alias_reference_cleanup_parameter_aliases(body, start, gets, writes)
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
          Some(aliases) =>
            fused_alias_reference_parameter_aliases_remap(
              body, indices, aliases,
            )
          None => pass_lower_remap_locals(body, indices)
        },
      ),
    ),
    indices,
  )
}
