///|
fn tuple_retirement_ctx() -> HotPassContext {
  HotPassContext::new(
    tuple_optimization_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn tuple_retirement_fixture(shared : Bool) -> (@lib.Module, @ir.HotFunc) raise {
  let input = pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (param i32) (result i32) " +
    "(local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) " +
    "block (type $pair) local.get 0 i32.const 1 i32.add call $mark " +
    "local.get 0 i32.const 2 i32.add call $mark end local.set 2 local.set 1 " +
    "block (result i32) local.get 2 local.set 4 local.get 1 end local.set 3 " +
    "block (result i32) local.get 1 local.get 2 local.set 6 end local.set 5 " +
    "block (type $pair) local.get 0 i32.const 3 i32.add call $mark " +
    "local.get 0 i32.const 4 i32.add call $mark end local.set 8 local.set 7 " +
    "block (result i32) local.get 8 local.set 10 local.get 7 end local.set 9 " +
    "block (result i32) local.get 9 local.get 10 local.set 12 end local.set 11 " +
    "block (type $pair) local.get 0 i32.const 5 i32.add call $mark " +
    "local.get 0 i32.const 6 i32.add call $mark end local.set 14 local.set 13 " +
    "block (result i32) local.get 14 local.set 16 local.get 13 end local.set 15 " +
    "local.get 3 local.get 4 i32.add " +
    "local.get 5 local.get 6 i32.add i32.add " +
    "local.get 9 local.get 10 i32.add i32.add " +
    "local.get 11 local.get 12 i32.add i32.add " +
    "local.get 15 local.get 16 i32.add i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  if shared {
    let groups = tuple_optimization_analyze(func, @ir.use_def_build(func)).groups
    let mut repeated = false
    for group in groups {
      if group.lane_locals != [3, 4] || group.copy_source is None {
        continue
      }
      let source = groups[group.copy_source.unwrap()]
      @ir.hot_region_insert(
        func,
        @ir.HotRegionRef::root(),
        @ir.hot_root_count(func) - 1,
        [
          source.defining_nodes[1],
          source.defining_nodes[0],
          group.defining_nodes[0],
        ],
      )
      repeated = true
      break
    }
    assert_true(repeated)
  }
  ignore(@ir.hot_verify_core(func).unwrap())
  ignore(@ir.hot_verify_control(func).unwrap())
  (input, func)
}

///|
test "tuple retirement preserves sibling and linked copies across independent sources" {
  for shared in [false, true] {
    let (input, func) = tuple_retirement_fixture(shared)
    let before = tuple_shared_outer_lower(input, func)
    let expected = if shared {
      (271, [11, 12, 13, 14, 15, 16, 11, 12])
    } else {
      (211, [11, 12, 13, 14, 15, 16])
    }
    assert_eq(tuple_shared_outer_observe(before), expected)
    let before_bytes = @binary.encode_module(
      input.with_code_sec(@lib.CodeSec::new([before])),
    ).unwrap()
    let @lib.Func(before_locals, @lib.Expr(before_body)) = before
    let (_, before_local_ops, _) = tuple_shared_outer_counts(before_body)
    let use_def = @ir.use_def_build(func)
    let groups = tuple_optimization_analyze(func, use_def).groups
    let retired : Array[(Int32, Int32)] = []
    let retained : Array[(Int32, Int32)] = []
    let payload_reads : Array[(Int32, Int32)] = []
    for group in groups {
      if group.copy_source is None || group.producer < 0 {
        continue
      }
      let label = @ir.hot_control_node_label(func, group.producer)
      if shared && (group.lane_locals == [3, 4] || group.lane_locals == [5, 6]) {
        retained.push((group.producer, label))
        continue
      }
      if group.lane_locals == [3, 4] ||
        group.lane_locals == [5, 6] ||
        group.lane_locals == [9, 10] ||
        group.lane_locals == [15, 16] {
        let reads = tuple_optimization_direct_scalar_copy_payload_nodes(
          func, use_def, group,
        ).unwrap()
        retired.push((group.producer, label))
        for lane in 0..<reads.length() {
          payload_reads.push((reads[lane], group.lane_locals[lane]))
        }
      }
    }
    assert_eq(retired.length(), if shared { 2 } else { 4 })
    assert_eq(retained.length(), if shared { 2 } else { 0 })
    let ctx = tuple_retirement_ctx()
    ignore(hot_pass_run(ctx, func).unwrap())
    for (producer, label) in retired {
      assert_false(@ir.hot_node_is_live(func, producer))
      assert_false(@ir.hot_label_is_live(func, label))
    }
    for (producer, label) in retained {
      assert_true(@ir.hot_node_is_live(func, producer))
      assert_true(@ir.hot_label_is_live(func, label))
    }
    let fresh = @ir.use_def_build(func)
    for (read, destination) in payload_reads {
      assert_true(@ir.hot_node_is_live(func, read))
      let sites = @ir.node_use_sites_borrowed(fresh, read)
      assert_eq(sites.length(), 1)
      assert_true(sites[0].kind is @ir.HotUseSlotKind::ChildUseSlot)
      let publication = @ir.hot_node_get(func, sites[0].user)
      assert_true(publication.op is @ir.HotOp::LocalSet)
      assert_eq(publication.imm0, destination)
    }
    let after = tuple_shared_outer_lower(input, func)
    assert_eq(tuple_shared_outer_observe(after), expected)
    let after_bytes = @binary.encode_module(
      input.with_code_sec(@lib.CodeSec::new([after])),
    ).unwrap()
    let @lib.Func(after_locals, @lib.Expr(after_body)) = after
    let (_, after_local_ops, _) = tuple_shared_outer_counts(after_body)
    assert_eq(after_locals.length(), before_locals.length())
    assert_eq(after_local_ops, before_local_ops)
    assert_true(after_bytes.length() < before_bytes.length())
    // A later pass resolves the linked copy through the publications moved by
    // the first pass. Its source values and call count must remain unchanged.
    for _ in 0..<2 {
      ignore(hot_pass_run(ctx, func).unwrap())
      assert_eq(
        tuple_shared_outer_observe(tuple_shared_outer_lower(input, func)),
        expected,
      )
    }
  }
}

///|
test "tuple retirement removes two pure source controls and their labels" {
  let input = pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(func (param i32) (result i32) (local i32 i32 i32 i32) " +
    "block (type $pair) local.get 0 i32.const 1 i32.add " +
    "local.get 0 i32.const 2 i32.add end local.set 2 local.set 1 " +
    "block (type $pair) local.get 0 i32.const 3 i32.add " +
    "local.get 0 i32.const 4 i32.add end local.set 4 local.set 3 " +
    "local.get 1 local.get 2 i32.add local.get 3 i32.add local.get 4 i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let groups = tuple_optimization_analyze(func, @ir.use_def_build(func)).groups
  assert_eq(groups.length(), 2)
  let retired = groups.map(fn(group) {
    (group.producer, @ir.hot_control_node_label(func, group.producer))
  })
  let ctx = tuple_retirement_ctx()
  ignore(hot_pass_run(ctx, func).unwrap())
  ignore(@ir.hot_verify_core(func).unwrap())
  ignore(@ir.hot_verify_control(func).unwrap())
  for (producer, label) in retired {
    assert_false(@ir.hot_node_is_live(func, producer))
    assert_false(@ir.hot_label_is_live(func, label))
  }
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  let encoded = @binary.encode_module(output).unwrap()
  let decoded = @binary.decode_module(encoded).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
  assert_eq(
    tuple_shared_outer_observe(decoded.code_sec.unwrap().0[0]),
    (50, []),
  )
  assert_true(encoded.length() < @binary.encode_module(input).unwrap().length())
}
