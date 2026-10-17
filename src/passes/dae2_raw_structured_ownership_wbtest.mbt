///|
fn raw_structured_table_targets(
  body : Array[@lib.Instruction],
) -> Array[@lib.LabelIdx]? {
  for instr in body {
    match instr {
      @lib.BrTable(targets, _) => return Some(targets)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match raw_structured_table_targets(child) {
          Some(targets) => return Some(targets)
          None => ()
        }
      @lib.If(_, yes, no) => {
        match raw_structured_table_targets(yes) {
          Some(targets) => return Some(targets)
          None => ()
        }
        match no {
          Some(child) =>
            match raw_structured_table_targets(child) {
              Some(targets) => return Some(targets)
              None => ()
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
test "DAE2 recursive scalar replay schedules a pure parent prefix after block effects directly" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) local.get 1 i32.const 10 i32.add block local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 end local.get 3 i32.add))",
  )
  let context = @ir.hot_module_context_from_module(input)
  let graph = Dae2Graph::new()
  let infos = Array::makei(2, fn(index) {
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    Dae2Function::new(graph, params, results)
  })
  for index in 0..<2 {
    let plan = dae2_raw_dependency_plan(
      graph,
      infos,
      index,
      [],
      input.code_sec.unwrap().0[index],
      None,
      module_context=Some(context),
    ).unwrap()
    plan.commit(graph)
    infos[index].raw_analysis = true
    infos[index].raw_write_locations = plan.write_locations
  }
  for location in infos[1].param_locations {
    graph.observe(location)
  }
  graph.observe(infos[1].result_location)
  graph.solve()
  let candidate = dae2_rewrite_raw_structured_function(
    graph,
    infos,
    1,
    input.code_sec.unwrap().0[1],
    context,
    infos[1].params,
    [],
  )
  assert_true(
    candidate is Some(_),
    msg="recursive replay rejected a flat-analyzed source write",
  )
  let (output, _) = candidate.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output
  assert_true(body[0] is @lib.Block(_, _))
}

///|
test "DAE2 recursive scalar replay owns emitted branch table targets" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) (local i32) block $outer block $inner local.get 0 local.get 1 i32.const 3 i32.add call $h local.set 2 local.get 0 br_table $inner $outer end end local.get 2))",
  )
  raw_structured_rewrite_compare(input)
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    stack_suffix_rewrite=false,
    rewrite_lifts=Some(lifts),
  ).unwrap()
  assert_eq(lifts[0], 0)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let targets = raw_structured_table_targets(body).unwrap()
  assert_eq(targets[0], @lib.LabelIdx::new(0U))
  targets[0] = @lib.LabelIdx::new(1U)
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
fn raw_structured_select_types(
  body : Array[@lib.Instruction],
) -> Array[@lib.ValType]? {
  for instr in body {
    match instr {
      @lib.Select(Some(types)) => return Some(types)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match raw_structured_select_types(child) {
          Some(types) => return Some(types)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
test "DAE2 recursive scalar replay owns emitted typed select declarations" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) (local i32) block local.get 0 local.get 1 local.get 0 select (result i32) local.get 1 i32.const 3 i32.add call $h local.set 2 end local.get 2))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    stack_suffix_rewrite=false,
    rewrite_lifts=Some(lifts),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let types = raw_structured_select_types(body).unwrap()
  assert_eq(types[0], @lib.ValType::i32())
  types[0] = @lib.ValType::i64()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 recursive scalar replay preserves mutable parent prefixes and retained returns" {
  for prefix in ["local.get 1", "local.get 1 i32.const 10 i32.add"] {
    for live_write in [false, true] {
      for tail in ["", " return"] {
        let read = if live_write { "local.get 1 i32.add " } else { "" }
        let body = "\{prefix} block local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 i32.const 7 local.set 1 end \{read}local.get 3 i32.add\{tail}"
        let input = pass_test_module_from_wat(
          "(module (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) \{body}))",
        )
        raw_structured_rewrite_compare(input, label=body)
      }
    }
  }
}

///|
test "DAE2 recursive scalar replay preserves trapping parent prefixes with a measured size gain" {
  for tail in ["", " return"] {
    let body = "local.get 1 i32.load block local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 end local.get 3 i32.add\{tail}"
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) \{body}))",
    )
    let expected = pass_test_module_from_wat(
        "(module (memory 1) (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add) (func (param i32 i32 i32) (result i32) (local i32) local.get 1 i32.load local.get 0 local.get 2 call 0 local.set 3 local.get 3 i32.add\{tail}))",
      ).code_sec.unwrap().0[1]
    raw_structured_held_shape_compare(input, expected, body, strict_gain=true)
  }
}

///|
test "DAE2 recursive scalar replay removes overwritten tee storage with separate live writes" {
  for value in ["local.get 1", "local.get 1 i32.const 2 i32.add"] {
    let body = "loop $again \{value} local.tee 2 i32.const 0 i32.div_s drop i32.const 7 local.set 2 i32.const 9 local.get 2 i32.const 3 i32.add i64.const 9 call $h local.set 2 local.get 0 br_if $again end local.get 2"
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i64) (result i32) local.get 1) (func (export \"run\") (param i32 i32) (result i32) (local i32) \{body}))",
    )
    raw_structured_rewrite_compare(input, label=body)
  }
}
