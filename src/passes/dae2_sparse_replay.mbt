///|
// One workspace per module. Only own results and called parameter/result
// boundaries can consume expression edges in dae2_analyze_function. The
// original raw call summary is complete before any rewrite or HOT capture.
// Keep this contract beside solve_function; normal Graph.edge stays unchanged.
priv struct Dae2RawReplayState {
  graph : Dae2Graph
  source : Dae2Graph
  boundary_count : Int
  sparse : Bool
  epochs : Array[Int]
  touched : Array[Int]
  mut epoch : Int
  mut failed : Bool
}

///|
fn Dae2Graph::raw_rewrite_boundary_snapshot(
  self : Dae2Graph,
  boundary_count : Int,
) -> Dae2Graph {
  // The module's solved expression mask can be large. The reusable state
  // outlives rewriting, so it must not keep that mask alive in finalization.
  {
    edges: [],
    next_edge: [],
    first_edge: [],
    last_edge: [],
    used: Array::makei(boundary_count, fn(location) { self.used[location] }),
    work: [],
    cursor: 0,
  }
}

///|
fn Dae2RawReplayState::new(
  source : Dae2Graph,
  boundary_count : Int,
  sparse? : Bool = true,
) -> Dae2RawReplayState {
  let source = source.raw_rewrite_boundary_snapshot(boundary_count)
  let graph = if sparse {
    let graph = Dae2Graph::new()
    ignore(graph.locations(boundary_count))
    // Copy the solved prefix once without allocating a queue of every live
    // module boundary. Subsequent successful resets retain these exact bits.
    for location in 0..<boundary_count {
      graph.used[location] = source.used[location]
    }
    graph
  } else {
    source.for_raw_rewrite(boundary_count)
  }
  {
    graph,
    source,
    boundary_count,
    sparse,
    epochs: if sparse {
      Array::make(boundary_count, 0)
    } else {
      []
    },
    touched: [],
    epoch: 1,
    failed: false,
  }
}

///|
fn Dae2RawReplayState::reset(self : Dae2RawReplayState) -> Unit {
  let graph = self.graph
  if !self.sparse || self.failed {
    // Failed qualification may have observed previously dead boundaries or
    // incomplete metadata. Restore every row only on this uncommon path.
    graph.reset_for_raw_rewrite(self.source, self.boundary_count)
    if self.sparse {
      graph.work.clear()
    }
  } else {
    for location in self.touched {
      graph.first_edge[location] = -1
      graph.last_edge[location] = -1
    }
    graph.used.resize(self.boundary_count, false)
    graph.first_edge.resize(self.boundary_count, -1)
    graph.last_edge.resize(self.boundary_count, -1)
    graph.edges.clear()
    graph.next_edge.clear()
    graph.work.clear()
    graph.cursor = 0
  }
  self.touched.clear()
  self.failed = false
  if self.epoch == 2147483647 {
    for location in 0..<self.epochs.length() {
      self.epochs[location] = 0
    }
    self.epoch = 1
  } else {
    self.epoch += 1
  }
}

///|
fn Dae2RawReplayState::register(
  self : Dae2RawReplayState,
  location : Int,
) -> Unit {
  if !self.sparse {
    return
  }
  if location < 0 || location >= self.boundary_count {
    self.failed = true
    return
  }
  if self.epochs[location] != self.epoch {
    self.epochs[location] = self.epoch
    self.touched.push(location)
  }
}

///|
fn Dae2RawReplayState::solve(self : Dae2RawReplayState) -> Bool {
  if self.failed {
    return false
  }
  if self.sparse {
    for location in self.touched {
      // Previously live boundaries never enter observe's queue again. Dead
      // boundaries newly observed by this body are already in the worklist.
      if self.source.used[location] && self.graph.first_edge[location] >= 0 {
        self.graph.work.push(location)
      }
    }
  }
  self.graph.solve()
  if self.sparse {
    // False-to-true changes must enter observe's queue. Original true bits
    // remain true, so checking this body's queue proves the same prefix mask
    // without scanning every function/type boundary again.
    for location in self.graph.work {
      if location < self.boundary_count && !self.source.used[location] {
        self.failed = true
        return false
      }
    }
  } else {
    for location in 0..<self.boundary_count {
      if self.graph.used[location] != self.source.used[location] {
        self.failed = true
        return false
      }
    }
  }
  true
}

///|
fn Dae2RawReplayState::solve_function(
  self : Dae2RawReplayState,
  info : Dae2Function,
  infos : Array[Dae2Function],
) -> Bool {
  if self.sparse {
    if !info.call_infos_ready {
      self.failed = true
      return false
    }
    self.register(info.result_location)
    for index in info.call_infos {
      if index < 0 || index >= infos.length() {
        self.failed = true
        return false
      }
      let callee = infos[index]
      for location in callee.param_locations {
        self.register(location)
      }
      // ReturnCall adds the reverse result edge. Registering ordinary call
      // results too is cheap and keeps all call forms under one contract.
      self.register(callee.result_location)
    }
  }
  self.solve()
}
