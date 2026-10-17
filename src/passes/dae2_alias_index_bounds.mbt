// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
fn dae2_local_index_width(index : Int32) -> Int32 {
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
// Mark possible copy writers and the Get sources of removable Set packets.
// A held tee needs another tee within the same array's preceding 64 slots.
// Set retirement can also remove a root's last reads through unused copies.
fn dae2_mark_possible_alias_writers(
  instrs : Array[@lib.Instruction],
  possible : Array[Bool],
) -> Unit {
  let mut previous_get = false
  let mut previous_tee = -65
  for position in 0..<instrs.length() {
    let instr = instrs[position]
    match instr {
      @lib.LocalSet(@lib.LocalIdx(target)) => {
        let producer = if previous_get {
          position - 1
        } else {
          dae2_alias_packet_get_position(instrs, position)
        }
        if producer >= 0 {
          match instrs[producer] {
            @lib.LocalGet(@lib.LocalIdx(source)) => {
              possible[target.to_int()] = true
              possible[source.to_int()] = true
            }
            _ => ()
          }
        }
      }
      @lib.LocalTee(@lib.LocalIdx(target)) => {
        if previous_get || previous_tee >= position - 64 {
          possible[target.to_int()] = true
        }
        previous_tee = position
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
  source : Int32,
  target : Int32,
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
        // Unread writes can retire. A possible Set feeder can also lose its
        // last reads after unused copy retirement. Multiwriters with reads
        // cannot be alias sources or targets and retain those reads.
        if i < self.start ||
          (
            self.reads[i] > 0 &&
            (self.writes[i] > 1 || (self.writes[i] == 1 && !possible[i]))
          ) {
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
  source_upper : Int32,
  target_lower : Int32,
  reads : Int32,
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
  source : Int32,
  target : Int32,
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
