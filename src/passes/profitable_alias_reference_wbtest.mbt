///|
// Frozen V61 discovery: identical workspace/traversal, strict nonwidening admission.
fn Dae2ParameterAliases::profitable_reference_discover(
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
      _ => self.profitable_reference_discover_children(instr)
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
          self.source_is_nonwidening(source, local_id)
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
fn Dae2ParameterAliases::profitable_reference_discover_children(
  self : Dae2ParameterAliases,
  instr : @lib.Instruction,
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      self.profitable_reference_discover(body)
    @lib.If(_, yes, no) => {
      self.profitable_reference_discover(yes)
      match no {
        Some(body) => self.profitable_reference_discover(body)
        None => ()
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      self.profitable_reference_discover(body)
      for catch_ in catches {
        let body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(body))
          | @lib.LegacyCatchAll(@lib.Expr(body)) => body
        }
        self.profitable_reference_discover(body)
      }
    }
    _ => ()
  }
}
