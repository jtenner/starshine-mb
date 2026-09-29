///|
fn local_graph_record_sources_before_borrow(
  local_count : Int,
  get_id : NodeId,
  sources : Array[Int],
  get_sources : Array[Array[Int]]?,
  write_influences : Array[Array[NodeId]]?,
) -> Unit {
  match get_sources {
    Some(sources_by_node) =>
      ignore(local_graph_union_into(sources_by_node[get_id], sources))
    None => ()
  }
  match write_influences {
    Some(influences_by_node) =>
      for source_id in sources {
        if source_id >= local_count {
          let set_id = source_id - local_count
          if set_id >= 0 && set_id < influences_by_node.length() {
            if !local_graph_node_array_contains(
                influences_by_node[set_id],
                get_id,
              ) {
              influences_by_node[set_id].push(get_id)
            }
          }
        }
      }
    None => ()
  }
}

///|
fn local_graph_read_source_bench(
  it : @bench.T,
  width : Int,
  reads : Int,
  merges : Int,
  reference : Bool,
  recorder_reference? : Bool = false,
) -> Unit {
  let sources = Array::makei(merges, fn(round) {
    Array::makei(width, fn(index) { index + round })
  })
  let build = fn() {
    let gets : Array[Array[Int]] = if reference {
      Array::makei(reads, fn(_) { [] })
    } else {
      Array::make(reads, [])
    }
    let recorder = if reference {
      None
    } else {
      Some(LocalGraphSourceRecorder::new(gets))
    }
    for source in sources {
      for read in 0..<reads {
        if reference {
          if recorder_reference {
            local_graph_record_sources_before_borrow(
              width + merges,
              read,
              source,
              Some(gets),
              None,
            )
          } else {
            ignore(local_graph_union_into(gets[read], source))
          }
        } else {
          local_graph_record_get_sources(
            width + merges,
            read,
            source,
            recorder,
            None,
          )
        }
      }
    }
    gets
  }
  let expected = Array::makei(width + merges - 1, fn(index) { index })
  for row in build() {
    if row != expected {
      abort("recorded source union changed")
    }
  }
  it.bench(fn() { it.keep(build()) })
  for round in 0..<merges {
    if sources[round] != Array::makei(width, fn(index) { index + round }) {
      abort("recording mutated a source snapshot")
    }
  }
}

///|
test "bench local source rows width=1 reads=1 merges=1 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 1, 1, true)
}

///|
test "bench local source rows width=1 reads=1 merges=1 shared" (it : @bench.T) {
  local_graph_read_source_bench(it, 1, 1, 1, false)
}

///|
test "bench local source rows width=1 reads=1 merges=4 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 1, 4, true)
}

///|
test "bench local source rows width=1 reads=1 merges=4 shared" (it : @bench.T) {
  local_graph_read_source_bench(it, 1, 1, 4, false)
}

///|
test "bench local source rows width=1 reads=128 merges=1 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 128, 1, true)
}

///|
test "bench local source rows width=1 reads=128 merges=1 shared" (it : @bench.T) {
  local_graph_read_source_bench(it, 1, 128, 1, false)
}

///|
test "bench local source rows width=1 reads=128 merges=4 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 128, 4, true)
}

///|
test "bench local source rows width=1 reads=128 merges=4 shared" (it : @bench.T) {
  local_graph_read_source_bench(it, 1, 128, 4, false)
}

///|
test "bench local source rows width=32 reads=1 merges=1 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 1, 1, true)
}

///|
test "bench local source rows width=32 reads=1 merges=1 shared" (it : @bench.T) {
  local_graph_read_source_bench(it, 32, 1, 1, false)
}

///|
test "bench local source rows width=32 reads=1 merges=4 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 1, 4, true)
}

///|
test "bench local source rows width=32 reads=1 merges=4 shared" (it : @bench.T) {
  local_graph_read_source_bench(it, 32, 1, 4, false)
}

///|
test "bench local source rows width=32 reads=128 merges=1 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 128, 1, true)
}

///|
test "bench local source rows width=32 reads=128 merges=1 shared" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 128, 1, false)
}

///|
test "bench local source rows width=32 reads=128 merges=4 reference" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 128, 4, true)
}

///|
test "bench local source rows width=32 reads=128 merges=4 shared" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 128, 4, false)
}

///|
test "bench local source rows width=1 reads=1 merges=1 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 1, 1, true, recorder_reference=true)
}

///|
test "bench local source rows width=1 reads=1 merges=4 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 1, 4, true, recorder_reference=true)
}

///|
test "bench local source rows width=1 reads=128 merges=1 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 128, 1, true, recorder_reference=true)
}

///|
test "bench local source rows width=1 reads=128 merges=4 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 1, 128, 4, true, recorder_reference=true)
}

///|
test "bench local source rows width=32 reads=1 merges=1 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 1, 1, true, recorder_reference=true)
}

///|
test "bench local source rows width=32 reads=1 merges=4 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 1, 4, true, recorder_reference=true)
}

///|
test "bench local source rows width=32 reads=128 merges=1 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 128, 1, true, recorder_reference=true)
}

///|
test "bench local source rows width=32 reads=128 merges=4 original recorder" (
  it : @bench.T,
) {
  local_graph_read_source_bench(it, 32, 128, 4, true, recorder_reference=true)
}
