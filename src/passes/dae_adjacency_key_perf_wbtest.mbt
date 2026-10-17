///|
fn dae_adjacency_key_reference(
  rows : Array[Array[Int32]],
  row : Int32,
  value : Int32,
  kind : Int32,
  membership : @hashmap.HashMap[(Int32, Int32, Int32), Bool],
) -> Unit {
  if row < 0 || row >= rows.length() {
    return
  }
  let key = (kind, row, value)
  if membership.get(key) is None {
    membership.set(key, true)
    rows[row].push(value)
  }
}

///|
fn dae_adjacency_key_reference_workload(repeats : Int32) -> Array[Array[Int32]] {
  let rows : Array[Array[Int32]] = Array::makei(64, fn(_) { [] })
  let membership : @hashmap.HashMap[(Int32, Int32, Int32), Bool] = @hashmap.new()
  for row in 0..<64 {
    for value in 0..<64 {
      for _ in 0..<repeats {
        dae_adjacency_key_reference(rows, row, value, row % 6, membership)
      }
    }
  }
  rows
}

///|
fn dae_adjacency_key_selected_workload(repeats : Int32) -> Array[Array[Int32]] {
  let rows : Array[Array[Int32]] = Array::makei(64, fn(_) { [] })
  let membership = @hashmap.new()
  for row in 0..<64 {
    for value in 0..<64 {
      for _ in 0..<repeats {
        dae_adjacency_add_unique(rows, row, value, row % 6, membership)
      }
    }
  }
  rows
}

///|
fn dae_adjacency_key_bench(
  it : @bench.T,
  repeats : Int32,
  reference : Bool,
) -> Unit raise {
  assert_eq(
    dae_adjacency_key_selected_workload(repeats),
    dae_adjacency_key_reference_workload(repeats),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        dae_adjacency_key_reference_workload(repeats)
      } else {
        dae_adjacency_key_selected_workload(repeats)
      },
    )
  })
}

///|
#skip("paired native adjacency key cost; dedicated performance lane")
test "bench DAE adjacency keys unique reference" (it : @bench.T) {
  dae_adjacency_key_bench(it, 1, true)
}

///|
#skip("paired native adjacency key cost; dedicated performance lane")
test "bench DAE adjacency keys unique value" (it : @bench.T) {
  dae_adjacency_key_bench(it, 1, false)
}

///|
#skip("paired native adjacency key cost; dedicated performance lane")
test "bench DAE adjacency keys repeated reference" (it : @bench.T) {
  dae_adjacency_key_bench(it, 12, true)
}

///|
#skip("paired native adjacency key cost; dedicated performance lane")
test "bench DAE adjacency keys repeated value" (it : @bench.T) {
  dae_adjacency_key_bench(it, 12, false)
}
