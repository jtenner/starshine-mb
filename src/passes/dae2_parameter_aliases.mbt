///|
priv struct Dae2ParameterAliases {
  start : Int32
  mut established : Array[Bool]?
  reads : Array[Int32]
  writes : Array[Int32]
  active : Array[Int32]
  mut forwarded : Bool
  targets : Array[Int64]
  undo : Array[Int32]
  mut width_body : Array[@lib.Instruction]?
  mut index_bounds : Array[Int64]?
  stack_effects : ((@lib.Instruction) -> (Int32, Int32)?)?
}

///|
fn Dae2ParameterAliases::new(
  start : Int32,
  reads : Array[Int32],
  writes : Array[Int32],
  width_body~ : Array[@lib.Instruction]? = None,
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
) -> Dae2ParameterAliases {
  {
    start,
    established: None,
    reads,
    writes,
    active: Array::make(reads.length(), -1),
    forwarded: false,
    targets: Array::make(reads.length(), -1L),
    undo: [],
    width_body,
    index_bounds: None,
    stack_effects,
  }
}

///|
fn dae2_alias_source_is_nonwidening(source : Int32, target : Int32) -> Bool {
  // Compaction never increases indices. A reverse edge is safe only when both
  // indices already fit in one byte; equal wider LEB widths may later diverge.
  source != target && (source < target || source < 128)
}

///|
// Find the local.get consumed by a writer through a small packet of leaf
// producers and local.sets. Other instructions end the proof. Both discovery
// and remapping use the same bound; deleting earlier pairs only shortens it.
fn dae2_alias_packet_get_position(
  instrs : Array[@lib.Instruction],
  end : Int32,
) -> Int32 {
  let mut needed = 1
  for position = end - 1
      position >= 0 && position >= end - 64
      position = position - 1 {
    match instrs[position] {
      @lib.LocalGet(_) => {
        needed -= 1
        if needed == 0 {
          return position
        }
      }
      @lib.LocalSet(_) => needed += 1
      leaf if dae2_stack_suffix_discardable_leaf(leaf) => {
        needed -= 1
        if needed == 0 {
          return -1
        }
      }
      _ => return -1
    }
  }
  -1
}

///|
fn dae2_alias_packet_source(
  instrs : Array[@lib.Instruction],
  end : Int32,
  writes : Array[Int32],
) -> Int32 {
  let position = dae2_alias_packet_get_position(instrs, end)
  if position < 0 {
    return -1
  }
  match instrs[position] {
    @lib.LocalGet(@lib.LocalIdx(source)) if writes[source.to_int()] <= 1 => {
      // Discovery also requires the single ordinary writer to dominate this
      // copy. Do not confuse a write inside the packet with a definition that
      // already preceded the captured read.
      if writes[source.to_int()] == 1 {
        for scan in (position + 1)..<end {
          match instrs[scan] {
            @lib.LocalSet(@lib.LocalIdx(written)) if written == source =>
              return -1
            _ => ()
          }
        }
      }
      source.to_int()
    }
    _ => -1
  }
}

///|
// Every target has one static write. A lexical child inherits dominating
// aliases but restores its own definitions on exit; no local-array copies or
// joins are needed. A source is unwritten or its single writer dominates the
// alias in the current lexical scope. A static writer may repeat in a loop,
// so its definition must precede the alias in that same active iteration.
fn Dae2ParameterAliases::discover(
  self : Dae2ParameterAliases,
  instrs : Array[@lib.Instruction],
) -> Unit {
  let mark = self.undo.length()
  let mut previous_get = -1
  for position in 0..<instrs.length() {
    let instr = instrs[position]
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        let local_id = raw.to_int()
        let source = self.active[local_id]
        if source >= 0 {
          self.reads[local_id] -= 1
          self.reads[source] += 1
          self.forwarded = true
          previous_get = source
        } else {
          previous_get = local_id
        }
        continue
      }
      _ => self.discover_children(instr)
    }
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if self.writes[raw.to_int()] ==
        1 => {
        let local_id = raw.to_int()
        let source = if previous_get >= 0 {
          previous_get
        } else if local_id >= self.start && instr is @lib.LocalSet(_) {
          // Held reads need an unchanged source through the packet as well as
          // the ordinary dominance proof used by adjacent local copies.
          dae2_alias_packet_source(instrs, position, self.writes)
        } else if local_id >= self.start && instr is @lib.LocalTee(_) {
          dae2_alias_held_tee_source(
            instrs,
            position,
            self.writes,
            self.stack_effects,
          )
        } else {
          -1
        }
        let is_alias = local_id >= self.start &&
          source >= 0 &&
          (
            self.writes[source] == 0 ||
            (self.writes[source] == 1 && self.is_established(source))
          ) &&
          (
            dae2_alias_source_is_nonwidening(source, local_id) ||
            self.source_is_profitable(
              source,
              local_id,
              instr is @lib.LocalTee(_),
            )
          )
        if is_alias {
          self.active[local_id] = source
          let kind = if instr is @lib.LocalTee(_) { 1L } else { 0L }
          self.targets[local_id] = source.to_int64() * 2L + kind
          // Roots are flattened before this writer; alias writers do not
          // establish ordinary source definitions.
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
    previous_get = -1
  }
  while self.undo.length() > mark {
    let entry = self.undo.pop().unwrap()
    if entry >= 0 {
      self.active[entry] = -1
    } else {
      self.established.unwrap()[-entry - 1] = false
    }
  }
}

///|
fn Dae2ParameterAliases::discover_children(
  self : Dae2ParameterAliases,
  instr : @lib.Instruction,
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) => self.discover(body)
    @lib.If(_, yes, no) => {
      self.discover(yes)
      match no {
        Some(body) => self.discover(body)
        None => ()
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      self.discover(body)
      for catch_ in catches {
        let body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(body))
          | @lib.LegacyCatchAll(@lib.Expr(body)) => body
        }
        self.discover(body)
      }
    }
    _ => ()
  }
}

///|
fn Dae2ParameterAliases::is_established(
  self : Dae2ParameterAliases,
  local_id : Int32,
) -> Bool {
  match self.established {
    Some(facts) => facts[local_id]
    None => false
  }
}

///|
fn dae2_has_parameter_alias(
  instrs : Array[@lib.Instruction],
  start : Int32,
  writes : Array[Int32],
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
) -> Bool {
  for position in 0..<instrs.length() {
    match instrs[position] {
      @lib.LocalSet(@lib.LocalIdx(target))
      | @lib.LocalTee(@lib.LocalIdx(target)) if position > 0 &&
        target.to_int() >= start &&
        writes[target.to_int()] == 1 => {
        match instrs[position - 1] {
          @lib.LocalGet(@lib.LocalIdx(source)) if source != target &&
            writes[source.to_int()] <= 1 => return true
          _ => ()
        }
        if instrs[position] is @lib.LocalSet(_) &&
          dae2_alias_packet_source(instrs, position, writes) >= 0 {
          return true
        }
        if instrs[position] is @lib.LocalTee(_) &&
          dae2_alias_held_tee_source(instrs, position, writes, stack_effects) >=
          0 {
          return true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae2_has_parameter_alias(body, start, writes, stack_effects~) {
          return true
        }
      @lib.If(_, yes, no) => {
        if dae2_has_parameter_alias(yes, start, writes, stack_effects~) {
          return true
        }
        match no {
          Some(body) =>
            if dae2_has_parameter_alias(body, start, writes, stack_effects~) {
              return true
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if dae2_has_parameter_alias(body, start, writes, stack_effects~) {
          return true
        }
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          if dae2_has_parameter_alias(body, start, writes, stack_effects~) {
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
fn dae2_cleanup_parameter_aliases(
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
// Replay only proved aliases while performing the already-required local remap.
// Discovery's active/undo workspace has been restored to its entry state. Each
// original writer activates its resolved root only in that lexical scope.
fn Dae2ParameterAliases::remap(
  self : Dae2ParameterAliases,
  instrs : Array[@lib.Instruction],
  indices : Array[Int32],
) -> Array[@lib.Instruction] {
  let mark = self.undo.length()
  let out = Array::new(capacity=instrs.length())
  let visit_body = fn(body) { self.remap(body, indices) }
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if self.targets[raw.to_int()] >=
        0L => {
        let local_id = raw.to_int()
        self.active[local_id] = (self.targets[local_id] >> 1).to_int()
        self.undo.push(local_id)
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
        @lib.Select(Some(types)) =>
          @lib.Instruction::select(types=Some(types.copy()))
        @lib.BrTable(targets, fallback) =>
          @lib.Instruction::br_table(targets.copy(), fallback)
        @lib.TryTable(bt, catches, @lib.Expr(body)) =>
          @lib.Instruction::try_table(
            bt,
            catches.copy(),
            @lib.Expr::new(visit_body(body)),
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
