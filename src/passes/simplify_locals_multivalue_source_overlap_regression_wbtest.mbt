///|
// These fixtures use branch-free result blocks. Every instruction is executed
// once, and unsupported instructions fail instead of producing a false match.
fn sl_multivalue_source_execute(
  func : @lib.Func,
  argument : Int32,
) -> (Int32?, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 1, 0)
  locals[0] = argument
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
  fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
    for instr in instrs {
      match instr {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.I32Add => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(lhs + rhs)
        }
        @lib.I32DivS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          if rhs == 0 || (lhs == -2147483648 && rhs == -1) {
            return false
          }
          stack.push(lhs / rhs)
        }
        @lib.Call(@lib.FuncIdx(0U)) => events.push(stack[stack.length() - 1])
        @lib.Block(_, @lib.Expr(nested)) => if !execute(nested) { return false }
        _ => fail("unsupported multivalue source instruction: \{instr}")
      }
    }
    true
  }
  if !execute(body) {
    return (None, events)
  }
  assert_eq(stack.length(), 1)
  (Some(stack[0]), events)
}

///|
fn sl_multivalue_source_fixture(variant : Int32) -> @lib.Module {
  let first_lane = if variant == 1 {
    "block (result i32) local.get 1 i32.const 1 i32.add end"
  } else {
    "local.get 1 i32.const 1 i32.add"
  }
  let last_lane = if variant == 2 {
    "call $mark local.get 1 i32.const 2 i32.add local.get 0 i32.div_s"
  } else {
    "local.get 1 i32.const 2 i32.add"
  }
  pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32) " +
    "local.get 0 local.set 1 block (type $pair) " +
    first_lane +
    " " +
    last_lane +
    " end " +
    "local.set 1 local.set 2 local.get 2 local.get 1 i32.add))",
  )
}

///|
test "simplify-locals alone preserves source reads before overlapping tuple writes" {
  for variant in [0, 1] {
    let input = sl_multivalue_source_fixture(variant)
    ignore(@validate.validate_module(input).unwrap())
    for
      passes in [
        ["simplify-locals-nostructure"],
        ["simplify-locals-nostructure", "simplify-locals-nostructure"],
        ["simplify-locals"],
      ] {
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
      ignore(@validate.validate_module(output).unwrap())
      for argument in [0, 10, -7, 32767] {
        let expected = (Some(argument + argument + 3), [])
        assert_eq(
          sl_multivalue_source_execute(input.code_sec.unwrap().0[0], argument),
          expected,
        )
        assert_eq(
          sl_multivalue_source_execute(output.code_sec.unwrap().0[0], argument),
          expected,
        )
      }
    }
  }
}

///|
test "simplify-locals source overlap retains operand effects and division traps" {
  let input = sl_multivalue_source_fixture(2)
  ignore(@validate.validate_module(input).unwrap())
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals-nostructure",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for argument in [0, 10, -7] {
    let expected = if argument == 0 {
      (None, [1])
    } else {
      (Some(argument + 1 + (argument + 2) / argument), [argument + 1])
    }
    assert_eq(
      sl_multivalue_source_execute(input.code_sec.unwrap().0[0], argument),
      expected,
    )
    assert_eq(
      sl_multivalue_source_execute(output.code_sec.unwrap().0[0], argument),
      expected,
    )
  }
}

///|
fn sl_multivalue_source_nodes(func : @ir.HotFunc) -> Array[String] {
  let nodes : Array[String] = []
  for id = 0; id < @ir.hot_node_count(func); id = id + 1 {
    if @ir.hot_node_is_live(func, id) {
      let node = @ir.hot_node_get(func, id)
      let children : Array[Int32] = []
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        children.push(@ir.hot_child_get(func, id, slot))
      }
      nodes.push(
        "\{id}: \{node.op} local=\{node.imm0} order=\{node.order} inputs=\{children}",
      )
    }
  }
  nodes
}

///|
test "simplify-locals source overlap survives each main and cleanup phase" {
  let input = sl_multivalue_source_fixture(0)
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let ctx = simplify_locals_wbtest_ctx()
  let policy = SimplifyLocalsPolicy::new(false, true, true)
  for first_cycle in [true, false] {
    let detached : Array[Int32] = []
    ignore(
      simplify_locals_run_main_cycle(
        ctx, func, first_cycle, detached, policy, false,
      ),
    )
    simplify_locals_delete_detached_nodes(func, detached)
    assert_eq(
      sl_multivalue_source_execute(@ir.hot_lower_func(func), 10),
      (Some(23), []),
      msg="source value after main cycle first=\{first_cycle}",
    )
    let detached : Array[Int32] = []
    let rehomed : Array[SimplifyLocalsDetachedControlOwner] = []
    ignore(simplify_locals_run_dead_cleanup(ctx, func, detached, rehomed, true))
    simplify_locals_rehome_detached_control_owners(func, rehomed)
    simplify_locals_delete_detached_nodes(func, detached)
    assert_eq(
      sl_multivalue_source_execute(@ir.hot_lower_func(func), 10),
      (Some(23), []),
      msg="source value after cleanup first=\{first_cycle}",
    )
  }
  let before = sl_multivalue_source_nodes(func)
  ignore(simplify_locals_run_equivalent_cleanup(ctx, func))
  let after = sl_multivalue_source_nodes(func)
  assert_eq(
    sl_multivalue_source_execute(@ir.hot_lower_func(func), 10),
    (Some(23), []),
    msg="source value after equivalent cleanup; before=\{before}; after=\{after}",
  )
}
