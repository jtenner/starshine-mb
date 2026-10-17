///|
fn tuple_shared_outer_observe(func : @lib.Func) -> (Int32, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  locals[0] = 10
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
  let mut fuel = 256
  fn execute(instructions : Array[@lib.Instruction]) -> Unit raise {
    for instruction in instructions {
      fuel -= 1
      assert_true(fuel > 0)
      match instruction {
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
          let right = stack.pop().unwrap()
          let left = stack.pop().unwrap()
          stack.push(left + right)
        }
        @lib.Call(index) => {
          assert_eq(index, @lib.FuncIdx::new(0U))
          let argument = stack.pop().unwrap()
          // This deterministic import returns a different pair each time the
          // source executes. Call arguments alone do not expose a stale copy.
          let result = argument + events.length() / 2 * 10
          events.push(argument)
          stack.push(result)
        }
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        _ =>
          fail("unsupported shared-outer fixture instruction: \{instruction}")
      }
    }
  }
  execute(body)
  assert_eq(stack.length(), 1)
  (stack[0], events)
}

///|
fn tuple_shared_outer_fixture(
  independent~ : Bool = false,
) -> (@lib.Module, @ir.HotFunc, Int32) raise {
  let input = pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) " +
    (if independent {
      "(local i32 i32 i32 i32 i32 i32 i32 i32) "
    } else {
      "(local i32 i32 i32 i32) "
    }) +
    "block (type $pair) local.get 0 i32.const 1 i32.add call $mark " +
    "local.get 0 i32.const 2 i32.add call $mark end local.set 2 local.set 1 " +
    "block (result i32) local.get 2 local.set 4 local.get 1 end local.set 3 " +
    (if independent {
      "block (type $pair) local.get 0 i32.const 3 i32.add " +
      "local.get 0 i32.const 4 i32.add end local.set 6 local.set 5 " +
      "block (result i32) local.get 6 local.set 8 local.get 5 end local.set 7 " +
      "local.get 7 local.get 8 i32.add drop "
    } else {
      ""
    }) +
    "local.get 3 local.get 4 i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let use_def = @ir.use_def_build(func)
  let groups = tuple_optimization_analyze(func, use_def).groups
  let mut copy_id = -1
  for index in 0..<groups.length() {
    if groups[index].copy_source is Some(_) && groups[index].producer >= 0 {
      copy_id = index
      break
    }
  }
  assert_true(copy_id >= 0)
  let copy = groups[copy_id]
  let source = groups[copy.copy_source.unwrap()]
  assert_eq(source.defining_nodes.length(), 2)
  let outer = copy.defining_nodes[0]
  let roots = @ir.hot_region_root_count(func, @ir.HotRegionRef::root())
  // Shared, acyclic HOT is valid. Repeat the same source stores and outer
  // store at a second root site; do not duplicate their node identities.
  @ir.hot_region_insert(func, @ir.HotRegionRef::root(), roots - 1, [
    source.defining_nodes[1],
    source.defining_nodes[0],
    outer,
  ])
  ignore(@ir.hot_verify_core(func).unwrap())
  ignore(@ir.hot_verify_control(func).unwrap())
  (input, func, copy.producer)
}

///|
fn tuple_shared_outer_lower(
  input : @lib.Module,
  func : @ir.HotFunc,
) -> @lib.Func raise {
  let lowered = @ir.hot_lower_func(func)
  let module_ = input.with_code_sec(@lib.CodeSec::new([lowered]))
  ignore(@validate.validate_module(module_).unwrap())
  let decoded = @binary.decode_module(@binary.encode_module(module_).unwrap()).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
  decoded.code_sec.unwrap().0[0]
}

///|
test "tuple direct copy requires one outer-store site on valid shared HOT" {
  let (input, func, producer) = tuple_shared_outer_fixture()
  let lowered = tuple_shared_outer_lower(input, func)
  assert_eq(tuple_shared_outer_observe(lowered), (43, [11, 12, 11, 12]))
  let use_def = @ir.use_def_build(func)
  let groups = tuple_optimization_analyze(func, use_def).groups
  let mut checked = false
  for group in groups {
    if group.producer != producer {
      continue
    }
    assert_false(group.bad)
    let sites = @ir.node_use_sites_borrowed(use_def, group.defining_nodes[0])
    assert_eq(sites.length(), 2)
    assert_true(
      sites.all(fn(site) { site.kind is @ir.HotUseSlotKind::RootUseSlot }),
    )
    // This direct move owns exactly one publication site. Shared stores stay
    // valid input, but need a different rewrite or unchanged component.
    assert_eq(
      tuple_optimization_direct_scalar_copy_payload_nodes(func, use_def, group),
      None,
    )
    checked = true
  }
  assert_true(checked)
}

///|
test "tuple pass preserves repeated shared outer-store publications and calls" {
  let (input, func, _) = tuple_shared_outer_fixture()
  let expected = tuple_shared_outer_observe(
    tuple_shared_outer_lower(input, func),
  )
  assert_eq(expected, (43, [11, 12, 11, 12]))
  let ctx = HotPassContext::new(
    tuple_optimization_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  ignore(@ir.hot_verify_core(func).unwrap())
  ignore(@ir.hot_verify_control(func).unwrap())
  assert_eq(
    tuple_shared_outer_observe(tuple_shared_outer_lower(input, func)),
    expected,
  )
}

///|
fn tuple_shared_outer_counts(
  instructions : Array[@lib.Instruction],
) -> (Int32, Int32, Int32) {
  let mut blocks = 0
  let mut local_ops = 0
  let mut all_ops = 0
  for instruction in instructions {
    all_ops += 1
    match instruction {
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) => local_ops += 1
      @lib.Block(_, @lib.Expr(nested)) => {
        let (nested_blocks, nested_locals, nested_ops) = tuple_shared_outer_counts(
          nested,
        )
        blocks += 1 + nested_blocks
        local_ops += nested_locals
        all_ops += nested_ops
      }
      _ => ()
    }
  }
  (blocks, local_ops, all_ops)
}

///|
test "tuple shared publication retention still removes an independent copy component" {
  let (input, func, shared_producer) = tuple_shared_outer_fixture(
    independent=true,
  )
  let before = tuple_shared_outer_lower(input, func)
  let @lib.Func(before_locals, @lib.Expr(before_body)) = before
  let before_bytes = @binary.encode_module(
    input.with_code_sec(@lib.CodeSec::new([before])),
  ).unwrap()
  assert_eq(tuple_shared_outer_observe(before), (43, [11, 12, 11, 12]))
  let (before_blocks, before_local_ops, before_ops) = tuple_shared_outer_counts(
    before_body,
  )
  let use_def = @ir.use_def_build(func)
  let groups = tuple_optimization_analyze(func, use_def).groups
  let mut independent_producer = -1
  for group in groups {
    if group.copy_source is Some(_) && group.lane_locals == [7, 8] {
      assert_false(group.bad)
      assert_true(
        tuple_optimization_direct_scalar_copy_payload_nodes(
          func, use_def, group,
        )
        is Some(_),
      )
      independent_producer = group.producer
    }
  }
  assert_true(independent_producer >= 0)
  let ctx = HotPassContext::new(
    tuple_optimization_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  ignore(@ir.hot_verify_core(func).unwrap())
  ignore(@ir.hot_verify_control(func).unwrap())
  assert_true(@ir.hot_node_is_live(func, shared_producer))
  // Require this particular independent wrapper to disappear. A whole-pass
  // no-op or a mask that retains every component cannot meet this contract.
  assert_false(@ir.hot_node_is_live(func, independent_producer))
  let after = tuple_shared_outer_lower(input, func)
  assert_eq(tuple_shared_outer_observe(after), (43, [11, 12, 11, 12]))
  let @lib.Func(after_locals, @lib.Expr(after_body)) = after
  let after_bytes = @binary.encode_module(
    input.with_code_sec(@lib.CodeSec::new([after])),
  ).unwrap()
  let (after_blocks, after_local_ops, after_ops) = tuple_shared_outer_counts(
    after_body,
  )
  assert_true(after_blocks < before_blocks)
  assert_true(after_ops < before_ops)
  assert_true(after_local_ops <= before_local_ops)
  assert_true(after_locals.length() <= before_locals.length())
  assert_true(after_bytes.length() < before_bytes.length())
}
