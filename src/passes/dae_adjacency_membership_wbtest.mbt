///|
test "dae adjacency membership deduplicates wide rows in encounter order" {
  let rows : Array[Array[Int32]] = [[]]
  let membership : @hashmap.HashMap[DaeAdjacencyKey, Bool] = @hashmap.new()
  for value in 0..<512 {
    dae_adjacency_add_unique(rows, 0, value, 7, membership)
    dae_adjacency_add_unique(rows, 0, value, 7, membership)
  }
  assert_eq(rows[0].length(), 512)
  for value in 0..<512 {
    assert_eq(rows[0][value], value)
  }
}

///|
test "dae adjacency membership retains exact signed values and independent edge kinds" {
  let rows : Array[Array[Int32]] = [[], []]
  let membership : @hashmap.HashMap[DaeAdjacencyKey, Bool] = @hashmap.new()
  for kind in [-2147483648, -1, 0, 2147483647] {
    for value in [-2147483648, -1, 0, 2147483647] {
      for row in 0..<2 {
        dae_adjacency_add_unique(rows, row, value, kind, membership)
        dae_adjacency_add_unique(rows, row, value, kind, membership)
      }
    }
  }
  for row in rows {
    assert_eq(row, [
      -2147483648, -1, 0, 2147483647, -2147483648, -1, 0, 2147483647, -2147483648,
      -1, 0, 2147483647, -2147483648, -1, 0, 2147483647,
    ])
  }
  dae_adjacency_add_unique(rows, -1, 3, 0, membership)
  dae_adjacency_add_unique(rows, 2, 3, 0, membership)
  assert_eq(rows[0].length(), 16)
  assert_eq(rows[1].length(), 16)
}
