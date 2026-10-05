///|
test "dae2 embedded definition type closure stays linear" {
  let count = 64
  let graph = Dae2Graph::new()
  for _ in 0..<count {
    ignore(graph.location())
  }
  let embedded = @lib.HeapType::def_type(
    @lib.DefType::new(
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      0U,
    ),
  )
  let value = @lib.ValType::ref_type(@lib.RefType::new(true, embedded))
  let embedded_types_root = [-1]
  for owner in 0..<count {
    dae2_type_ref_edges(graph, owner, value, 0, embedded_types_root)
  }
  assert_true(graph.edges.length() <= count * 2)
}
