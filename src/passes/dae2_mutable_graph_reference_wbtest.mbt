///|
// Frozen V12 mutable-field graph for matched construction/solve controls.

///|
// Binaryen 132 DAE2: parameter and whole-result liveness share a least fixed
// point. All locations start unused. Observable uses seed a backwards worklist;
// a forwarding cycle does not become live merely because it contains a cycle.
// Flat insertion-ordered adjacency avoids an empty heap array per location.
// first/last link only actual edges; solve preserves the original queue order.
priv struct Dae2MutableGraphReference {
  mut edges : Array[Int]
  mut next_edge : Array[Int]
  mut first_edge : Array[Int]
  mut last_edge : Array[Int]
  used : Array[Bool]
  mut work : Array[Int]
  mut cursor : Int
}

///|
fn Dae2MutableGraphReference::release_solved_edges(
  self : Dae2MutableGraphReference,
) -> Unit {
  // Rewrite reads only solved values. Its body graphs are independent, so
  // retaining this adjacency capacity merely overlaps it with their arenas.
  self.edges = []
  self.next_edge = []
  self.first_edge = []
  self.last_edge = []
  self.work = []
}

///|
fn Dae2MutableGraphReference::for_solved_rewrite(
  self : Dae2MutableGraphReference,
) -> Dae2MutableGraphReference {
  self.release_solved_edges()
  self
}

///|
fn Dae2MutableGraphReference::new() -> Dae2MutableGraphReference {
  {
    edges: [],
    next_edge: [],
    first_edge: [],
    last_edge: [],
    used: [],
    work: [],
    cursor: 0,
  }
}

///|
fn Dae2MutableGraphReference::location(self : Dae2MutableGraphReference) -> Int {
  let id = self.used.length()
  self.first_edge.push(-1)
  self.last_edge.push(-1)
  self.used.push(false)
  id
}

///|
fn Dae2MutableGraphReference::locations(
  self : Dae2MutableGraphReference,
  count : Int,
) -> Int {
  let base = self.used.length()
  let end = base + count
  if count < 0 || end < base {
    abort("DAE2 graph location count is out of range")
  }
  if end > self.used.capacity() {
    // Array.resize grows to the exact requested size. Preserve the scalar
    // allocator's amortized growth across many adjacent function ranges.
    let doubled = self.used.capacity() * 2
    let capacity = if doubled > end { doubled } else { end }
    self.first_edge.reserve_capacity(capacity)
    self.last_edge.reserve_capacity(capacity)
    self.used.reserve_capacity(capacity)
  }
  self.first_edge.resize(end, -1)
  self.last_edge.resize(end, -1)
  self.used.resize(end, false)
  base
}

///|
fn Dae2MutableGraphReference::edge(
  self : Dae2MutableGraphReference,
  consumer : Int,
  source : Int,
) -> Unit {
  if self.cursor != 0 {
    abort("DAE2 graph edges must be complete before solving")
  }
  if consumer >= 0 && source >= 0 {
    let edge = self.edges.length()
    self.edges.push(source)
    self.next_edge.push(-1)
    let previous = self.last_edge[consumer]
    if previous < 0 {
      self.first_edge[consumer] = edge
    } else {
      self.next_edge[previous] = edge
    }
    self.last_edge[consumer] = edge
  }
}

///|
fn Dae2MutableGraphReference::observe(
  self : Dae2MutableGraphReference,
  location : Int,
) -> Unit {
  if location >= 0 && !self.used[location] {
    self.used[location] = true
    self.work.push(location)
  }
}

///|
fn Dae2MutableGraphReference::solve(self : Dae2MutableGraphReference) -> Unit {
  // Each location enters the queue once, so convergence is bounded by the
  // graph size, including recursive call and result dependencies.
  while self.cursor < self.work.length() {
    let consumer = self.work[self.cursor]
    self.cursor = self.cursor + 1
    let mut edge = self.first_edge[consumer]
    while edge >= 0 {
      self.observe(self.edges[edge])
      edge = self.next_edge[edge]
    }
  }
}
