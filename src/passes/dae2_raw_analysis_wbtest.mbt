///|
test "DAE2 analyzes readonly flat void argument dependencies without an initial HOT arena" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func $store (param i32 i32 i32) local.get 0 local.get 1 i32.const 7 i32.add i32.store local.get 2 drop) (func (export \"keep\") (param i32 i32) local.get 0 local.get 1 i32.const 9 call $store))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 prunes parameters used only by dropped flat pure expressions" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) local.get 0 local.get 1 i32.add drop) (func (export \"run\") i32.const 7 i32.const 9 call $h))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([], [])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
}

///|
test "DAE2 analyzes flat writes and trapping producers and fallthrough ifs with HOT fallback for loops" {
  for
    (body, expected_lifts) in [
      ("i32.const 11 local.set 0 local.get 0 global.set $g", 0),
      ("i32.const 8 local.get 0 i32.div_s drop", 0),
      ("local.get 0 if i32.const 11 global.set $g end", 0),
      ("local.get 0 if loop i32.const 11 global.set $g end end", 1),
    ] {
    let input = pass_test_module_from_wat(
      "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32) \{body}) (func (export \"run\") (param i32) local.get 0 call $h))",
    )
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(lifts[0], expected_lifts)
  }
}

///|
fn dae2_raw_analysis_compare_fixture(wat : String) -> @lib.Module raise {
  let input = pass_test_module_from_wat(wat)
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  output
}

///|
test "DAE2 raw result dependencies replay the same exact rewrite as HOT analysis" {
  for
    wat in [
      "(module (func $h (param i32 i32) (result i32) local.get 1 i32.const 7 i32.add return) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32) (result i32 i32) call $v local.get 1) (func (export \"run\") i32.const 7 i32.const 9 call $h drop drop))",
      "(module (func $h (param i32 i32) (result i32 i32) local.get 1 local.get 0) (func (export \"run\") (param i32) (result i32 i32) local.get 0 i32.const 9 call $h))",
      "(module (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h drop i32.const 7 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) (local i32) local.get 2 local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
    ] {
    ignore(dae2_raw_analysis_compare_fixture(wat))
  }
}

///|
test "DAE2 raw forwarding cycles retain the least fixed point" {
  let output = dae2_raw_analysis_compare_fixture(
    "(module (func $a (param i32 i32) local.get 1 local.get 0 call $b) (func $b (param i32 i32) local.get 1 local.get 0 call $a) (func (export \"run\") i32.const 7 i32.const 9 call $a))",
  )
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<2 {
    assert_eq(
      @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new(index.to_uint()),
      ),
      Some(@lib.FuncType::new([], [])),
    )
  }
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[2]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
}

///|
test "DAE2 raw indirect and reference calls observe their target and type family" {
  for
    wat in [
      "(module (type $sig (func (param i32 i32) (result i32))) (table 1 funcref) (func $h (type $sig) local.get 1) (elem (i32.const 0) $h) (func (export \"run\") (param i32 i32) (result i32) i32.const 7 local.get 0 local.get 1 call_indirect (type $sig)))",
      "(module (type $sig (func (param i32 i32) (result i32))) (func $h (type $sig) local.get 1) (elem declare func $h) (func (export \"run\") (param i32) (result i32) i32.const 7 local.get 0 ref.func $h call_ref $sig))",
      "(module (type $sig (func (param i32) (result i32))) (table (export \"table\") 1 funcref) (func $h (param i32) (result i32) i32.const 7) (func (export \"run\") (param i32) (result i32) i32.const 9 call $h drop i32.const 11 local.get 0 call_indirect (type $sig)))",
    ] {
    ignore(dae2_raw_analysis_compare_fixture(wat))
  }
}

///|
test "DAE2 raw dependencies cover parameter indices above 64 and shared symbolic joins" {
  let params = Array::make(96, "i32").join(" ")
  let args = Array::make(96, "i32.const 9").join(" ")
  let output = dae2_raw_analysis_compare_fixture(
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param \{params}) local.get 65 local.get 65 i32.add local.get 95 i32.add global.set $g) (func (export \"run\") \{args} call $h))",
  )
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
  )
}

///|
test "DAE2 raw admission rejects intentionally invalid types despite matching stack arity" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 9 call $h))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  body[0] = @lib.Instruction::f32_const(@lib.F32(9.0))
  assert_true(dae2_run_module_pass(input, false).is_err())
}

///|
test "DAE2 raw dependency plans commit atomically and preserve graph seeds and adjacency" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func (param i32 i32 i32) local.get 0 local.get 1 i32.add global.set $g local.get 2 drop))",
  )
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  let body = input.code_sec.unwrap().0[0]
  let used = graph.used.copy()
  let plan = dae2_raw_dependency_plan(graph, [info], 0, [], body, None).unwrap()
  assert_eq(graph.used, used)
  assert_true(graph.edges.is_empty())
  assert_true(graph.work.is_empty())
  plan.commit(graph)
  graph.solve()
  assert_eq(graph.used[info.param_locations[0]], true)
  assert_eq(graph.used[info.param_locations[1]], true)
  assert_eq(graph.used[info.param_locations[2]], false)
  let saved_used = graph.used.copy()
  let saved_edges = graph.edges.copy()
  let saved_work = graph.work.copy()
  let @lib.Func(locals, @lib.Expr(instructions)) = body
  let unsupported = instructions.copy()
  // A branchless scalar block is supported; loops intentionally retain HOT.
  unsupported.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
  )
  assert_true(
    dae2_raw_dependency_plan(
      graph,
      [info],
      0,
      [],
      @lib.Func::new(locals, @lib.Expr::new(unsupported)),
      None,
    )
    is None,
  )
  assert_eq(graph.used, saved_used)
  assert_eq(graph.edges, saved_edges)
  assert_eq(graph.work, saved_work)
}
