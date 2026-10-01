///|
// One original continuation owns each mutable ordered read set. Siblings borrow
// it only during their recursive visit; suffix/loop accumulation copies first.
priv struct SlCleanupReadSet {
  reads : Array[Int]
  mut word : Int
  mut bits : UInt64
  mut members : Map[Int, UInt64]?
}

///|
fn SlCleanupReadSet::new(reads : Array[Int]) -> SlCleanupReadSet {
  { reads, word: 0, bits: 0UL, members: None, }
}

///|
fn SlCleanupReadSet::copy(self : SlCleanupReadSet) -> SlCleanupReadSet {
  SlCleanupReadSet::new(self.reads.copy())
}

///|
fn SlCleanupReadSet::contains(
  self : SlCleanupReadSet,
  local_id : Int,
  membership_probes? : Array[Int]? = None,
) -> Bool {
  // Zero bits mean no index: a nonempty indexed set never loses its first bit.
  // Cache the first 64-local word without a map; only other words need entries.
  if self.bits == 0UL && self.reads.length() > 8 {
    self.word = self.reads[0] >> 6
    for read in self.reads {
      self.index_read(read)
    }
  }
  if self.bits != 0UL {
    match membership_probes {
      Some(probes) => probes[0] += 1
      None => ()
    }
    let word = local_id >> 6
    let bit = 1UL << (local_id & 63)
    if word == self.word {
      return (self.bits & bit) != 0UL
    }
    return match self.members {
      Some(members) => (members.get(word).unwrap_or(0UL) & bit) != 0UL
      None => false
    }
  }
  // Keep the ordinary tiny path identical to Array::contains. Optional work
  // accounting must not put an extra branch in every production comparison.
  match membership_probes {
    None => self.reads.contains(local_id)
    Some(probes) => {
      for read in self.reads {
        probes[0] += 1
        if read == local_id {
          return true
        }
      }
      false
    }
  }
}

///|
fn SlCleanupReadSet::index_read(
  self : SlCleanupReadSet,
  local_id : Int,
) -> Unit {
  let word = local_id >> 6
  let bit = 1UL << (local_id & 63)
  if word == self.word {
    self.bits = self.bits | bit
  } else {
    let members = match self.members {
      Some(members) => members
      None => {
        let members : Map[Int, UInt64] = Map([])
        self.members = Some(members)
        members
      }
    }
    members[word] = members.get(word).unwrap_or(0UL) | bit
  }
}

///|
fn SlCleanupReadSet::insert(
  self : SlCleanupReadSet,
  local_id : Int,
  membership_probes? : Array[Int]? = None,
) -> Unit {
  if !self.contains(local_id, membership_probes~) {
    self.reads.push(local_id)
    if self.bits != 0UL {
      self.index_read(local_id)
    }
  }
}

///|
fn SlCleanupReadSet::collect(
  self : SlCleanupReadSet,
  instrs : Array[@lib.Instruction],
  membership_probes? : Array[Int]? = None,
) -> Unit {
  for instr in instrs {
    self.collect_instr(instr, membership_probes~)
  }
}

///|
fn SlCleanupReadSet::collect_instr(
  self : SlCleanupReadSet,
  instr : @lib.Instruction,
  membership_probes? : Array[Int]? = None,
) -> Unit {
  match instr {
    @lib.LocalGet(@lib.LocalIdx(raw)) =>
      self.insert(raw.reinterpret_as_int(), membership_probes~)
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      self.collect(body, membership_probes~)
    @lib.If(_, then_body, else_body) => {
      self.collect(then_body, membership_probes~)
      if else_body is Some(body) {
        self.collect(body, membership_probes~)
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      self.collect(body, membership_probes~)
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(body))
          | @lib.LegacyCatchAll(@lib.Expr(body)) =>
            self.collect(body, membership_probes~)
        }
      }
    }
    _ => ()
  }
}
