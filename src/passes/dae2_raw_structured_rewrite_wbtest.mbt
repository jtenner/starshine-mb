///|
fn raw_structured_rewrite_compare(
  input : @lib.Module,
  label~ : String = "",
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
      stack_suffix_rewrite=false,
    ).unwrap()
    let expected = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(actual.type_sec, expected.type_sec, msg=label)
    assert_eq(actual.func_sec, expected.func_sec, msg=label)
    let actual_bodies = actual.code_sec.unwrap().0
    let expected_bodies = expected.code_sec.unwrap().0
    assert_eq(actual_bodies.length(), expected_bodies.length(), msg=label)
    for index in 0..<actual_bodies.length() {
      if actual_bodies[index] != expected_bodies[index] {
        println("function \{index}: \{label}")
      }
      assert_eq(actual_bodies[index], expected_bodies[index])
    }
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
      msg=label,
    )
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 recursive scalar replay removes nonliteral middle arguments in void loops and branches" {
  for
    region in [
      "loop $again local.get 0 local.get 1 i32.const 3 i32.add local.get 2 i64.const 9 call $h local.set 3 local.get 0 br_if $again end",
      "block $out local.get 0 br_if $out local.get 0 local.get 1 i32.const 3 i32.add local.get 2 i64.const 9 call $h local.set 3 end",
      "local.get 0 if local.get 0 local.get 1 i32.const 3 i32.add local.get 2 i64.const 9 call $h local.set 3 else local.get 0 local.get 1 i32.const 4 i32.mul local.get 2 i64.const 9 call $h local.set 3 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) \{region} local.get 3))",
    )
    raw_structured_rewrite_compare(input, label=region)
  }
}

///|
test "DAE2 recursive scalar replay projects arbitrary direct argument masks with ordered effects" {
  for
    dead in [
      "local.get 1 i32.const 3 i32.add", "local.get 1 i32.load", "call $value", "local.get 1 i32.const 0 i32.div_s",
    ] {
    for
      result in [
        "local.get 0", "local.get 1", "local.get 2", "local.get 0 local.get 2 i32.add",
      ] {
      let input = pass_test_module_from_wat(
        "(module (import \"env\" \"value\" (func $value (result i32))) (memory 1) (func $h (param i32 i32 i32) (result i32) \{result}) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) loop $again local.get 0 \{dead} local.get 2 call $h local.set 3 local.get 0 br_if $again end local.get 3))",
      )
      raw_structured_rewrite_compare(input, label="\{dead} -> \{result}")
    }
  }
}

///|
test "DAE2 recursive scalar replay uses exact source write demand across arms and backedges" {
  for
    writes in [
      "local.get 1 local.set 2 local.get 0 if local.get 1 i32.const 2 i32.add local.set 2 else local.get 1 i32.const 3 i32.add local.set 2 end",
      "local.get 1 local.tee 2 drop i32.const 7 local.set 2", "local.get 1 local.set 2 local.get 0 if local.get 2 i32.const 1 i32.add local.set 2 end",
      "local.get 1 local.set 2 local.get 2 local.tee 2 drop",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i64) (result i32) local.get 1) (func (export \"run\") (param i32 i32) (result i32) (local i32) loop $again \{writes} i32.const 9 local.get 2 i32.const 4 i32.add i64.const 9 call $h local.tee 2 drop local.get 0 br_if $again end local.get 2))",
    )
    raw_structured_rewrite_compare(input, label=writes)
  }
}

///|
test "DAE2 recursive scalar replay preserves indexed loop entry payloads and parent stack prefixes" {
  for
    body in [
      "local.get 1 loop $again (type $one) local.set 3 local.get 0 local.get 1 i32.const 1 i32.add local.get 3 i64.const 9 call $h local.set 3 local.get 3 local.get 0 br_if $again drop end local.get 3",
      "local.get 1 i32.const 10 i32.add block local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 end local.get 3 i32.add",
      "local.get 1 i32.const 10 i32.add loop $again local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 local.get 0 br_if $again end local.get 3 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $one (func (param i32))) (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) \{body}))",
    )
    raw_structured_rewrite_compare(input, label=body)
  }
}

///|
test "DAE2 recursive scalar replay keeps demanded tee storage and removes dead local dependencies" {
  for
    body in [
      "loop $again local.get 1 local.tee 2 i32.const 0 i32.div_s drop local.get 0 br_if $again end i32.const 9 local.get 2 i64.const 9 call $h",
      "loop $again local.get 1 local.tee 2 i32.const 0 i32.div_s drop i32.const 7 local.set 2 local.get 0 br_if $again end i32.const 9 local.get 2 i64.const 9 call $h",
      "loop $again local.get 1 local.set 2 i32.const 9 local.get 2 i32.const 3 i32.add i64.const 9 call $h drop local.get 0 br_if $again end local.get 1",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i64) (result i32) local.get 1) (func (export \"run\") (param i32 i32) (result i32) (local i32) \{body}))",
    )
    raw_structured_rewrite_compare(input, label=body)
  }
}

///|
test "DAE2 recursive scalar replay removes dead plain control results without graph or input mutation" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let (graph, info, plan) = raw_forward_resource_plan(input)
  let plan = plan.unwrap()
  info.raw_analysis = true
  info.raw_write_locations = plan.write_locations
  plan.commit(graph)
  graph.solve()
  let used = graph.used.copy()
  let edges = graph.edges.copy()
  let work = graph.work.copy()
  let result = dae2_rewrite_raw_function(
    graph,
    [info],
    0,
    input.code_sec.unwrap().0[0],
    @ir.hot_module_context_from_module(input),
    [@lib.ValType::i32()],
    [],
  )
  let (rewritten, local_map) = result.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = rewritten
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(@lib.BlockType::void_(), [], Some([])),
  ])
  assert_eq(local_map, [0])
  assert_eq(graph.used, used)
  assert_eq(graph.edges, edges)
  assert_eq(graph.work, work)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
