///|
priv struct CLSourceHazardReaderIndex {
  types : Array[@lib.ValType]
  readers_by_group : Array[Array[Int32]]
}

///|
fn cl_source_reader_type_group(value : @lib.ValType) -> Int32 {
  match value {
    @lib.NumTypeValType(@lib.I32NumType) => 0
    @lib.NumTypeValType(@lib.I64NumType) => 1
    @lib.NumTypeValType(@lib.F32NumType) => 2
    @lib.NumTypeValType(@lib.F64NumType) => 3
    @lib.VecTypeValType => 4
    @lib.RefTypeValType(_) => 5
    @lib.BotValType => 6
  }
}

///|
fn cl_source_hazard_reader_index(
  types : Array[@lib.ValType],
  readers : Array[Bool],
  local_visits~ : Array[Int32]? = None,
) -> CLSourceHazardReaderIndex {
  let readers_by_group = Array::makei(7, fn(_) { [] })
  // RefType equality accepts shorthand and expanded references with different
  // derived hashes. Keep all references in one coarse bucket and retain the
  // old exact equality filter at lookup. Fixed kinds keep construction linear
  // even when every reference has a distinct heap type. The index lives only
  // through one read-only hazard analysis.
  for local in 0..<types.length() {
    match local_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    if local < readers.length() && readers[local] {
      // Appending in local order preserves the old destination order.
      let group = cl_source_reader_type_group(types[local])
      readers_by_group[group].push(local)
    }
  }
  { types, readers_by_group, }
}

///|
fn cl_source_write_dest_read_candidate_dests_indexed(
  source : Int32,
  index : CLSourceHazardReaderIndex,
  interferences : CLBitMatrix,
  first_effective_write : Array[Int32],
  latest_get : Array[Int32],
  candidate_visits~ : Array[Int32]? = None,
) -> Array[Int32] {
  let candidates : Array[Int32] = []
  if source < 0 ||
    source >= index.types.length() ||
    source >= interferences.length() ||
    source >= first_effective_write.length() ||
    first_effective_write[source] < 0 {
    return candidates
  }
  let group = cl_source_reader_type_group(index.types[source])
  for dest in index.readers_by_group[group] {
    match candidate_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    if source != dest &&
      dest < latest_get.length() &&
      latest_get[dest] > first_effective_write[source] &&
      index.types[source] == index.types[dest] &&
      !cl_bit_matrix_get(interferences, source, dest) {
      candidates.push(dest)
    }
  }
  candidates
}

///|
// The index filters readers and coarse type groups before the old exact test.
// A complete one-group reader row gives every source the full destination row.
// Sparse rows or a second group keep the existing index path.
fn cl_source_hazard_reader_index_can_filter(
  types : Array[@lib.ValType],
  readers : Array[Bool],
) -> Bool {
  if types.is_empty() {
    return false
  }
  if readers.is_empty() || !readers[0] {
    return true
  }
  let group = cl_source_reader_type_group(types[0])
  for local in 1..<types.length() {
    if local >= readers.length() || !readers[local] {
      return true
    }
    if cl_source_reader_type_group(types[local]) != group {
      return true
    }
  }
  false
}
