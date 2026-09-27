///|
// Tuple evaluation belongs to one transfer path. Scalar nodes need no entries;
// forks copy only encountered tuple producers, and joins retain their intersection.
priv struct LocalGraphTupleState {
  mut evaluated : @set.Set[NodeId]?
  slots : Array[Int]?
}

///|
fn LocalGraphTupleState::new(slots : Array[Int]?) -> LocalGraphTupleState {
  { evaluated: None, slots, }
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
  let copied = LocalGraphTupleState::new(self.slots)
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
