///|
fn dae2_local_index_width(index : Int) -> Int {
  if index < 128 {
    1
  } else if index < 16384 {
    2
  } else if index < 2097152 {
    3
  } else if index < 268435456 {
    4
  } else {
    5
  }
}

///|
// Mark every syntactic copy, including ones that dominance or source-write
// checks will reject. Such a writer is not guaranteed to retain its declaration.
fn dae2_mark_possible_alias_writers(
  instrs : Array[@lib.Instruction],
  possible : Array[Bool],
) -> Unit {
  let mut previous_get = false
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(target))
      | @lib.LocalTee(@lib.LocalIdx(target)) =>
        if previous_get {
          possible[target.to_int()] = true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae2_mark_possible_alias_writers(body, possible)
      @lib.If(_, yes, no) => {
        dae2_mark_possible_alias_writers(yes, possible)
        match no {
          Some(body) => dae2_mark_possible_alias_writers(body, possible)
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        dae2_mark_possible_alias_writers(body, possible)
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          dae2_mark_possible_alias_writers(body, possible)
        }
      }
      _ => ()
    }
    previous_get = instr is @lib.LocalGet(_)
  }
}

///|
fn Dae2ParameterAliases::source_is_nonwidening(
  self : Dae2ParameterAliases,
  source : Int,
  target : Int,
) -> Bool {
  if dae2_alias_source_is_nonwidening(source, target) {
    return true
  }
  if source == target {
    return false
  }
  let bounds = match self.index_bounds {
    Some(bounds) => bounds
    None => {
      let body = match self.width_body {
        Some(body) => body
        // The legacy benchmark control deliberately omits final-index facts.
        None => return false
      }
      let possible = Array::make(self.reads.length(), false)
      dae2_mark_possible_alias_writers(body, possible)
      let mut upper = 0
      let mut lower = 0
      let bounds = Array::makei(self.reads.length(), fn(i) {
        let packed = (upper.to_int64() << 32) | lower.to_int64()
        // Discovery redirects reads but does not retire writes. Alias targets
        // still have their writer; roots already had a producer read or write.
        // Thus the initially retained set remains an upper bound until the
        // retirement pass, even if these facts are built during discovery.
        if i < self.start || self.reads[i] > 0 || self.writes[i] > 0 {
          upper += 1
        }
        // Protected slots and noncopy writers survive alias retirement. Copy
        // candidates are excluded regardless of whether they will be admitted.
        if i < self.start ||
          self.writes[i] > 1 ||
          (self.writes[i] == 1 && !possible[i]) {
          lower += 1
        }
        packed
      })
      self.width_body = None
      self.index_bounds = Some(bounds)
      bounds
    }
  }
  let source_upper = (bounds[source] >> 32).to_int()
  let target_lower = (bounds[target] & 0xffffffffL).to_int()
  dae2_local_index_width(source_upper) <= dae2_local_index_width(target_lower)
}

///|
fn dae2_alias_copy_pays_for_widening(
  source_upper : Int,
  target_lower : Int,
  reads : Int,
  tee : Bool,
) -> Bool {
  // One syntactic read can be forwarded or remain before/outside the alias.
  // In the latter case there is no widening and the writer remains. Multiple
  // reads are deliberately outside this new admission contract.
  if reads < 0 || reads > 1 {
    return false
  }
  let growth = dae2_local_index_width(source_upper) -
    dae2_local_index_width(target_lower)
  let removed = if tee { 2 } else { 4 }
  // A set removes get+set (>=4 bytes); a tee removes only tee (>=2).
  // Strict inequality requires a byte win even at the worst index bounds.
  reads * growth < removed
}

///|
fn Dae2ParameterAliases::source_is_profitable(
  self : Dae2ParameterAliases,
  source : Int,
  target : Int,
  tee : Bool,
) -> Bool {
  if self.source_is_nonwidening(source, target) {
    return true
  }
  if source == target || self.reads[target] > 1 {
    return false
  }
  let bounds = match self.index_bounds {
    Some(bounds) => bounds
    // Preserve the legacy control with no body/final-index proof.
    None => return false
  }
  dae2_alias_copy_pays_for_widening(
    (bounds[source] >> 32).to_int(),
    (bounds[target] & 0xffffffffL).to_int(),
    self.reads[target],
    tee,
  )
}
