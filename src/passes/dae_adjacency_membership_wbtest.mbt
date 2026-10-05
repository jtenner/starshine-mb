///|
test "dae adjacency membership deduplicates wide rows in encounter order" {
  let rows : Array[Array[Int]] = [[]]
  let membership : @hashmap.HashMap[(Int, Int, Int), Bool] = @hashmap.new()
  for value in 0..<512 {
    dae_adjacency_add_unique(rows, 0, value, 7, membership)
    dae_adjacency_add_unique(rows, 0, value, 7, membership)
  }
  assert_eq(rows[0].length(), 512)
  for value in 0..<512 {
    assert_eq(rows[0][value], value)
  }
}
