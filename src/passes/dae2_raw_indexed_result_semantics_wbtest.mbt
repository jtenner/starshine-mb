///|
test "DAE2 recursive indexed result loops consume the carried backedge value" {
  let input = pass_test_module_from_wat(
    "(module (type $in (func (param i32) (result i32))) (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i32) (result i32) local.get 0 global.set $g local.get 0) (func (export \"run\") (param i32 i32) (result i32) local.get 0 loop $again (type $in) i32.const 1 i32.add local.get 1 i32.const 3 i32.add call $h local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end))",
  )
  let expected = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::i32_const(1),
          @lib.Instruction::i32_add(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(1),
          @lib.Instruction::i32_sub(),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      stack_suffix_rewrite=false,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    @validate.validate_module(reference).unwrap()
    println("indexed-result world=\{closed_world} input \{saved}")
    println(
      "indexed-result world=\{closed_world} actual \{@binary.encode_module(actual).unwrap()}",
    )
    println(
      "indexed-result world=\{closed_world} reference \{@binary.encode_module(reference).unwrap()}",
    )
    println(
      "indexed-result world=\{closed_world} lifts \{analysis[0]} \{rewrite[0]}",
    )
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
    // The arithmetic consumes the loop's actual operand-stack parameter. A
    // fresh local.get 0 here would read the decreasing counter instead.
    let expected = if closed_world {
      // The private original control family can shrink. HOT preserves the
      // complete loop signature under a replacement type index; raw replay
      // must use that same header without retaining the unused type family.
      let @lib.Func(_, @lib.Expr(reference_body)) = reference.code_sec.unwrap().0[1]
      guard reference_body[1] is @lib.Loop(header, _) else {
        abort("expected indexed result loop")
      }
      let @lib.Func(locals, @lib.Expr(expected_body)) = expected
      guard expected_body[1] is @lib.Loop(_, child) else {
        abort("expected natural loop body")
      }
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          expected_body[0],
          @lib.Instruction::loop_(header, child),
        ]),
      )
    } else {
      expected
    }
    assert_eq(actual.type_sec, reference.type_sec)
    assert_eq(actual.func_sec, reference.func_sec)
    assert_eq(actual.code_sec.unwrap().0[1], expected)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 retained scalar loop keeps the call result on the stack across a conditional backedge" {
  let input = pass_test_module_from_wat(
    "(module (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i32) (result i32) local.get 0 global.set $g local.get 0) (func (export \"run\") (param i32 i32) (result i32) loop $again (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end))",
  )
  let expected = pass_test_module_from_wat(
      "(module (func (param i32) (result i32) local.get 0) (func (param i32 i32) (result i32) loop $again (result i32) local.get 0 call 0 local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end))",
    ).code_sec.unwrap().0[1]
  raw_structured_held_shape_compare(
    input,
    expected,
    "retained-loop",
    strict_gain=true,
    export_artifacts=true,
  )
}

///|
test "DAE2 recursive replay reuses the cloned type for repeated demanded indexed loops" {
  let input = pass_test_module_from_wat(
    "(module (type $in (func (param i32) (result i32))) (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) local.get 0 loop (type $in) i32.const 1 i32.add local.get 1 i32.const 3 i32.add call $h end global.set $g local.get 0 loop (type $in) i32.const 2 i32.add local.get 1 i32.const 4 i32.add call $h end))",
  )
  raw_structured_rewrite_compare(input, label="repeated indexed result header")
  let actual = dae2_run_module_pass(input, true, stack_suffix_rewrite=false).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = actual.code_sec.unwrap().0[1]
  guard body[1] is @lib.Loop(first, _) else {
    abort("expected first indexed loop")
  }
  guard body[4] is @lib.Loop(second, _) else {
    abort("expected second indexed loop")
  }
  assert_eq(first, second)
}

///|
test "DAE2 recursive replay intentionally delegates unused indexed loop entries atomically" {
  let input = pass_test_module_from_wat(
    "(module (type $in (func (param i32) (result i32))) (func (export \"run\") (param i32 i32) (result i32) local.get 0 loop (type $in) drop local.get 1 end))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let (graph, info, candidate) = raw_forward_resource_plan(input)
  let plan = candidate.unwrap()
  plan.commit(graph)
  info.raw_analysis = true
  info.raw_write_locations = plan.write_locations
  for location in info.param_locations {
    graph.observe(location)
  }
  graph.observe(info.result_location)
  graph.solve()
  let used = graph.used.copy()
  let edges = graph.edges.copy()
  let work = graph.work.copy()
  // This replay slice retains complete indexed entries. Removing this dead
  // stack slot belongs to general HOT normalization, not signature pinning.
  assert_true(
    dae2_rewrite_raw_structured_function(
      graph,
      [info],
      0,
      input.code_sec.unwrap().0[0],
      @ir.hot_module_context_from_module(input),
      info.params,
      [],
    )
    is None,
  )
  assert_eq(graph.used, used)
  assert_eq(graph.edges, edges)
  assert_eq(graph.work, work)
  for closed_world in [false, true] {
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      stack_suffix_rewrite=false,
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
