///|
priv struct Dae2ParameterAliases {
  start : Int
  mut established : Array[Bool]?
  reads : Array[Int]
  writes : Array[Int]
  active : Array[Int]
  mut forwarded : Bool
  targets : Array[Int64]
  undo : Array[Int]
  mut width_body : Array[@lib.Instruction]?
  mut index_bounds : Array[Int64]?
}

///|
fn Dae2ParameterAliases::new(
  start : Int,
  reads : Array[Int],
  writes : Array[Int],
  width_body? : Array[@lib.Instruction]? = None,
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
  }
}

///|
fn dae2_alias_source_is_nonwidening(source : Int, target : Int) -> Bool {
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
fn Dae2ParameterAliases::discover(
  self : Dae2ParameterAliases,
  instrs : Array[@lib.Instruction],
) -> Unit {
  let mark = self.undo.length()
  let mut previous_get = -1
  for instr in instrs {
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
        let source = previous_get
        let is_alias = local_id >= self.start &&
          source >= 0 &&
          (
            self.writes[source] == 0 ||
            (self.writes[source] == 1 && self.is_established(source))
          ) &&
          self.source_is_profitable(source, local_id, instr is @lib.LocalTee(_))
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
  local_id : Int,
) -> Bool {
  match self.established {
    Some(facts) => facts[local_id]
    None => false
  }
}

///|
fn dae2_has_parameter_alias(
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
          @lib.LocalGet(@lib.LocalIdx(source)) if source != target &&
            writes[source.to_int()] <= 1 => return true
          _ => ()
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae2_has_parameter_alias(body, start, writes) {
          return true
        }
      @lib.If(_, yes, no) => {
        if dae2_has_parameter_alias(yes, start, writes) {
          return true
        }
        match no {
          Some(body) =>
            if dae2_has_parameter_alias(body, start, writes) {
              return true
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if dae2_has_parameter_alias(body, start, writes) {
          return true
        }
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          if dae2_has_parameter_alias(body, start, writes) {
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
  start : Int,
  reads : Array[Int],
  writes : Array[Int],
) -> (Array[@lib.Instruction], Dae2ParameterAliases?) {
  if !dae2_has_parameter_alias(instrs, start, writes) {
    return (instrs, None)
  }
  let aliases = Dae2ParameterAliases::new(
    start,
    reads,
    writes,
    width_body=Some(instrs),
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
  indices : Array[Int],
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
