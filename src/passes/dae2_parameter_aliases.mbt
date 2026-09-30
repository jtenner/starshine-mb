///|
priv struct Dae2ParameterAliases {
  start : Int
  params : Int
  reads : Array[Int]
  writes : Array[Int]
  active : Array[@lib.Instruction?]
  targets : Array[Int64]
  undo : Array[Int]
}

///|
fn Dae2ParameterAliases::new(
  start : Int,
  params : Int,
  reads : Array[Int],
  writes : Array[Int],
) -> Dae2ParameterAliases {
  {
    start,
    params,
    reads,
    writes,
    active: Array::make(reads.length(), None),
    targets: Array::make(reads.length(), -1L),
    undo: [],
  }
}

///|
// Every target has one static write. A lexical child inherits dominating
// aliases but restores its own definitions on exit; no local-array copies or
// joins are needed. Source parameters have no writes anywhere in the function.
fn Dae2ParameterAliases::replace_reads(
  self : Dae2ParameterAliases,
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
              _ => abort("invalid parameter alias")
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
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if raw.to_int() >=
        self.start &&
        self.writes[raw.to_int()] == 1 =>
        match out.last() {
          Some(source) if source is @lib.LocalGet(@lib.LocalIdx(base)) &&
            base.to_int() < self.params &&
            self.writes[base.to_int()] == 0 => {
            self.active[raw.to_int()] = Some(source)
            // Pack the source index and write kind in one unboxed row.
            let kind = if instr is @lib.LocalTee(_) { 1L } else { 0L }
            self.targets[raw.to_int()] = base.to_int().to_int64() * 2L + kind
            self.undo.push(raw.to_int())
          }
          _ => ()
        }
      _ => ()
    }
    out.push(instr)
  }
  while self.undo.length() > mark {
    self.active[self.undo.pop().unwrap()] = None
  }
  out
}

///|
fn dae2_has_parameter_alias(
  instrs : Array[@lib.Instruction],
  start : Int,
  params : Int,
  writes : Array[Int],
) -> Bool {
  for position in 0..<instrs.length() {
    match instrs[position] {
      @lib.LocalSet(@lib.LocalIdx(target))
      | @lib.LocalTee(@lib.LocalIdx(target)) if position > 0 &&
        target.to_int() >= start &&
        writes[target.to_int()] == 1 =>
        match instrs[position - 1] {
          @lib.LocalGet(@lib.LocalIdx(source)) if source.to_int() < params &&
            writes[source.to_int()] == 0 => return true
          _ => ()
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae2_has_parameter_alias(body, start, params, writes) {
          return true
        }
      @lib.If(_, yes, no) => {
        if dae2_has_parameter_alias(yes, start, params, writes) {
          return true
        }
        match no {
          Some(body) =>
            if dae2_has_parameter_alias(body, start, params, writes) {
              return true
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if dae2_has_parameter_alias(body, start, params, writes) {
          return true
        }
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          if dae2_has_parameter_alias(body, start, params, writes) {
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
  params : Int,
  reads : Array[Int],
  writes : Array[Int],
) -> (Array[@lib.Instruction], Array[Int64]?) {
  if params == 0 || !dae2_has_parameter_alias(instrs, start, params, writes) {
    return (instrs, None)
  }
  let aliases = Dae2ParameterAliases::new(start, params, reads, writes)
  let body = aliases.replace_reads(instrs)
  let mut unread = false
  for local in start..<reads.length() {
    let definition = aliases.targets[local]
    if definition < 0L {
      continue
    }
    if reads[local] == 0 {
      writes[local] = 0
      if (definition & 1L) == 0L {
        reads[(definition >> 1).to_int()] -= 1
      }
      unread = true
    } else {
      aliases.targets[local] = -1L
    }
  }
  (body, if unread { Some(aliases.targets) } else { None })
}

///|
// Remove dead alias writes while performing the already-required local remap.
// Other producers retain their order and position. The no-alias path continues
// to use the original exact-sized map without allocating this visitor/output.
fn dae2_parameter_aliases_remap(
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
  aliases : Array[Int64],
) -> Array[@lib.Instruction] {
  let out = Array::new(capacity=instrs.length())
  let visit_body = fn(body) {
    dae2_parameter_aliases_remap(body, indices, aliases)
  }
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) if aliases[raw.to_int()] >= 0L => {
        match out.pop() {
          Some(@lib.LocalGet(_)) => ()
          _ => abort("missing immutable parameter alias producer")
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
