///|
// Tuple evaluation belongs to one transfer path. Scalar nodes need no entries;
// forks copy only encountered tuple producers, and joins retain their intersection.
priv struct LocalGraphTupleState {
  mut evaluated : @set.Set[NodeId]?
  slots : Array[Int]?
  join_visits : Array[Int]?
  local_count : Int
  mut write_journal : LocalGraphWriteJournal?
}

///|
fn LocalGraphTupleState::new(
  slots : Array[Int]?,
  join_visits? : Array[Int]? = None,
  local_count? : Int = 0,
) -> LocalGraphTupleState {
  { evaluated: None, slots, join_visits, local_count, write_journal: None, }
}

///|
fn LocalGraphTupleState::count_slots(
  self : LocalGraphTupleState,
  count : Int,
) -> Unit {
  match self.slots {
    Some(slots) => slots[0] += count
    None => ()
  }
}

///|
fn LocalGraphTupleState::already_evaluated(
  self : LocalGraphTupleState,
  node : NodeId,
) -> Bool {
  let entries = match self.evaluated {
    Some(entries) => entries
    None => {
      let entries : @set.Set[NodeId] = @set.Set([])
      self.evaluated = Some(entries)
      entries
    }
  }
  if entries.contains(node) {
    return true
  }
  entries.add(node)
  self.count_slots(1)
  false
}

///|
fn LocalGraphTupleState::copy(
  self : LocalGraphTupleState,
) -> LocalGraphTupleState {
  let copied = LocalGraphTupleState::new(
    self.slots,
    join_visits=self.join_visits,
    local_count=self.local_count,
  )
  copied.write_journal = self.write_journal
  match self.evaluated {
    Some(entries) => {
      copied.evaluated = Some(entries.copy())
      self.count_slots(entries.length())
    }
    None => ()
  }
  copied
}

///|
fn LocalGraphTupleState::intersect_paths(
  self : LocalGraphTupleState,
  yes : LocalGraphTupleState,
  no : LocalGraphTupleState,
) -> Unit {
  self.evaluated = match (yes.evaluated, no.evaluated) {
    (Some(yes), Some(no)) => {
      let common = yes.intersection(no)
      self.count_slots(common.length())
      Some(common)
    }
    _ => None
  }
}

///|
// A journal belongs to one recursive block transfer. Forks share it because
// writes are observations, while source arrays remain owned by each path.
priv struct LocalGraphWriteJournal {
  locals : Array[Int]
  seen : Array[Bool]
}

///|
fn LocalGraphWriteJournal::new(count : Int) -> LocalGraphWriteJournal {
  { locals: [], seen: Array::make(count, false), }
}

///|
fn LocalGraphTupleState::prepare_write_journal(
  self : LocalGraphTupleState,
) -> LocalGraphWriteJournal? {
  if self.local_count < 128 {
    return None
  }
  if self.write_journal is Some(journal) {
    return Some(journal)
  }
  let journal = LocalGraphWriteJournal::new(self.local_count)
  self.write_journal = Some(journal)
  Some(journal)
}
