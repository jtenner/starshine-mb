///|
fn dae_result_edge_sparse_bench(
  it : @bench.T,
  width : Int32,
  mode : Int32,
  route : Int32,
) -> Unit raise {
  let input = dae_result_edge_sparse_fixture(width, mode)
  let saved = @binary.encode_module(input).unwrap()
  dae_result_edge_sparse_check(input)
  {
    let actual = dae_result_edge_sparse_round(input, false)
    let expected = dae_result_edge_sparse_round(input, true)
    assert_true(actual.changed)
    assert_eq(actual.touched, expected.touched)
    assert_eq(actual.effects, expected.effects)
    assert_eq(
      @binary.encode_module(actual.mod_out).unwrap(),
      @binary.encode_module(expected.mod_out).unwrap(),
    )
    @validate.validate_module(actual.mod_out).unwrap()
  }
  let graph = dae_current_boundary_graph_new(input)
  let expected = dae_result_edge_sparse_reference(graph)
  dae_result_edge_sparse_assert_equal(
    dae_result_edge_sparse_array_reference(graph),
    expected,
  )
  // Select one direct closure outside timing; recorder is None on all routes.
  if route == 0 {
    it.bench(fn() { it.keep(dae_result_edge_sparse_reference(graph)) })
  } else if route == 1 {
    it.bench(fn() { it.keep(dae_result_edge_sparse_array_reference(graph)) })
  } else {
    it.bench(fn() { it.keep(dae_boundary_dependency_graph_build(graph)) })
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=16 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 0, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=16 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 0, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=16 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 0, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=128 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 0, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=128 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 0, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=128 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 0, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=1024 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 0, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=1024 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 0, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges cold width=1024 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 0, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=16 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 1, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=16 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 1, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=16 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 1, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=128 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 1, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=128 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 1, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=128 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 1, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=1024 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 1, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=1024 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 1, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges active width=1024 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 1, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=16 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 2, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=16 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 2, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=16 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 16, 2, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=128 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 2, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=128 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 2, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=128 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 2, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=1024 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 2, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=1024 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 2, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges mixed width=1024 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 1024, 2, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges sparse width=128 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 3, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges sparse width=128 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 3, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges sparse width=128 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 128, 3, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges sparse width=4096 frozen" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 4096, 3, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges sparse width=4096 arrays" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 4096, 3, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges sparse width=4096 intmap" (it : @bench.T) {
  dae_result_edge_sparse_bench(it, 4096, 3, 2)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges many-callees width=128 frozen" (
  it : @bench.T,
) {
  dae_result_edge_sparse_bench(it, 128, 4, 0)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges many-callees width=128 arrays" (
  it : @bench.T,
) {
  dae_result_edge_sparse_bench(it, 128, 4, 1)
}

///|
#skip("three-way native residual graph cost; dedicated performance lane")
test "bench DAE sparse result edges many-callees width=128 intmap" (
  it : @bench.T,
) {
  dae_result_edge_sparse_bench(it, 128, 4, 2)
}

///|
fn dae_result_edge_sparse_switch_bench(
  it : @bench.T,
  route : Int32,
) -> Unit raise {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1) (func) (func))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  for index in 0..<1024 {
    graph.snapshot.function_infos[0].calls.push({
      caller_def: 1 + index % 2,
      path: DaeStablePath::empty(),
      callee_abs: 0,
      active: true,
      dropped: false,
      tail: index % 4 < 2,
    })
  }
  let expected = dae_result_edge_sparse_reference(graph)
  dae_result_edge_sparse_assert_equal(
    dae_boundary_dependency_graph_build(graph),
    expected,
  )
  dae_result_edge_sparse_assert_equal(
    dae_result_edge_sparse_array_reference(graph),
    expected,
  )
  if route == 0 {
    it.bench(fn() { it.keep(dae_result_edge_sparse_reference(graph)) })
  } else if route == 1 {
    it.bench(fn() { it.keep(dae_result_edge_sparse_array_reference(graph)) })
  } else {
    it.bench(fn() { it.keep(dae_boundary_dependency_graph_build(graph)) })
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("three-way interleaved private journal cost; dedicated performance lane")
test "bench DAE sparse result edges alternating1024 frozen" (it : @bench.T) {
  dae_result_edge_sparse_switch_bench(it, 0)
}

///|
#skip("three-way interleaved private journal cost; dedicated performance lane")
test "bench DAE sparse result edges alternating1024 arrays" (it : @bench.T) {
  dae_result_edge_sparse_switch_bench(it, 1)
}

///|
#skip("three-way interleaved private journal cost; dedicated performance lane")
test "bench DAE sparse result edges alternating1024 intmap" (it : @bench.T) {
  dae_result_edge_sparse_switch_bench(it, 2)
}
