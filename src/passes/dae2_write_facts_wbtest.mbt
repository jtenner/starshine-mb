///|
fn dae2_writefacts_graph(
  func : @ir.HotFunc,
  reference : Bool,
  census_visits? : Array[Int]? = None,
) -> Dae2Graph {
  let graph = Dae2Graph::new()
  let params = Array::makei(@ir.hot_local_param_count(func), fn(local) {
    @ir.hot_local_type(func, local).unwrap()
  })
  let info = Dae2Function::new(graph, params, [@lib.ValType::i32()])
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  if reference {
    dae2_writefacts_reference_analyze(graph, [info], 0, [], func)
  } else {
    dae2_analyze_function(
      graph,
      [info],
      0,
      [],
      func,
      write_census_visits=census_visits,
    )
  }
  graph.observe(info.result_location)
  graph.solve()
  graph
}

///|
fn dae2_writefacts_assert_same(
  actual : Dae2Graph,
  expected : Dae2Graph,
) -> Unit raise {
  assert_eq(actual.edges, expected.edges)
  assert_eq(actual.next_edge, expected.next_edge)
  assert_eq(actual.first_edge, expected.first_edge)
  assert_eq(actual.last_edge, expected.last_edge)
  assert_eq(actual.used, expected.used)
  assert_eq(actual.work, expected.work)
  assert_eq(actual.cursor, expected.cursor)
}

///|
test "DAE2 shares one complete write census between read admission and entry proofs" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 1 i32.const 1 i32.add local.set 1 local.get 1))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let before = @ir.hot_lower_func(func)
  let revision = @ir.hot_revision_current(func)
  let visits = [0]
  let actual = dae2_writefacts_graph(func, false, census_visits=Some(visits))
  dae2_writefacts_assert_same(actual, dae2_writefacts_graph(func, true))
  assert_true(
    visits[0] <= @ir.hot_node_count(func),
    msg="duplicated write census: \{visits[0]}",
  )
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(@ir.hot_lower_func(func), before)
}

///|
test "shared DAE2 write facts preserve branching loops exceptions and default reads" {
  for
    body in [
      "local.get 0", "i32.const 1 local.set 0 i32.const 2 local.set 1 local.get 0 local.get 1 i32.add",
      "local.get 1 if i32.const 11 local.set 0 end local.get 0", "i32.const 11 local.set 0 loop (result i32) local.get 0 end",
      "i32.const 11 local.set 0 try_table (result i32) local.get 0 end", "local.get 2",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32 i32) (result i32) (local i32) \{body}))",
    )
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
    let before = @ir.hot_lower_func(func)
    dae2_writefacts_assert_same(
      dae2_writefacts_graph(func, false),
      dae2_writefacts_graph(func, true),
    )
    assert_eq(@ir.hot_lower_func(func), before)
  }
}

///|
test "shared DAE2 write census preserves intentionally unrepresented and repeated-root fallback" {
  for mode in 0..<3 {
    let func = @ir.HotFunc::new(
      locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
    )
    let write = @ir.hot_build_local_set(
      func,
      0,
      @ir.hot_build_const_i32(func, @lib.I32(11)),
    )
    let read = @ir.hot_build_local_get(func, 0)
    if mode != 0 {
      @ir.hot_root_append(func, write)
      if mode == 1 {
        @ir.hot_root_append(func, write)
      } else {
        @ir.hot_root_append(
          func,
          @ir.hot_build_block(func, @lib.BlockType::void_(), [write]),
        )
      }
      @ir.hot_root_append(func, read)
    }
    dae2_writefacts_assert_same(
      dae2_writefacts_graph(func, false),
      dae2_writefacts_graph(func, true),
    )
  }
}

///|
test "shared DAE2 census retains GC parameter dependencies and avoids scanning functions without reads" {
  let input = pass_test_module_from_wat(
    "(module (type $t (struct (field i32))) (func (param (ref null $t) i32) (result i32) local.get 0 drop local.get 1))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  dae2_writefacts_assert_same(
    dae2_writefacts_graph(func, false),
    dae2_writefacts_graph(func, true),
  )
  let no_reads = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_root_append(no_reads, @ir.hot_build_const_i32(no_reads, @lib.I32(7)))
  let visits = [0]
  dae2_writefacts_assert_same(
    dae2_writefacts_graph(no_reads, false, census_visits=Some(visits)),
    dae2_writefacts_graph(no_reads, true),
  )
  assert_eq(visits[0], 0)
}
