///|
fn tuple_publication_loop_fixture(width : Int32) -> @lib.Module raise {
  let mut text = "(module (type $pair (func (result i32 i32))) " +
    "(type $entry (func (param i32) (result i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (param i32) (result i32) (local "
  for _ in 0..<(1 + 4 * width) {
    text += "i32 "
  }
  text += ") local.get 0 loop (type $entry) local.set 1 "
  for group in 0..<width {
    let a = 2 + 4 * group
    let b = a + 1
    let oa = a + 2
    let ob = a + 3
    text += "block (type $pair) local.get 0 i32.const " +
      (2 * group + 1).to_string() +
      " i32.add call $mark local.get 0 i32.const " +
      (2 * group + 2).to_string() +
      " i32.add call $mark end local.set " +
      b.to_string() +
      " local.set " +
      a.to_string() +
      " " +
      "block (result i32) local.get " +
      b.to_string() +
      " local.set " +
      ob.to_string() +
      " local.get " +
      a.to_string() +
      " end local.set " +
      oa.to_string() +
      " " +
      "local.get 1 local.get " +
      oa.to_string() +
      " i32.add local.get " +
      ob.to_string() +
      " i32.add local.get " +
      ob.to_string() +
      " i32.add local.set 1 "
  }
  text += "local.get 1 end))"
  pass_test_module_from_wat(text)
}

///|
test "tuple loop copy publications preserve entry values with linear retained spans" {
  // Two small widths exercise real copy rewriting, not a long stress loop.
  for width in [8, 16] {
    let input = tuple_publication_loop_fixture(width)
    ignore(@validate.validate_module(input).unwrap())
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
    let before_children = func.children.length()
    let copies = tuple_optimization_analyze(func, @ir.use_def_build(func)).groups
      .filter(fn(group) { group.copy_source is Some(_) && group.producer >= 0 })
      .map(fn(group) {
        (group.producer, @ir.hot_control_node_label(func, group.producer))
      })
    assert_eq(copies.length(), width)
    let @lib.Func(before_locals, _) = input.code_sec.unwrap().0[0]
    ignore(hot_pass_run(tuple_retirement_ctx(), func).unwrap())
    ignore(@ir.hot_verify_core(func).unwrap())
    ignore(@ir.hot_verify_control(func).unwrap())
    for (producer, label) in copies {
      assert_false(@ir.hot_node_is_live(func, producer))
      assert_false(@ir.hot_label_is_live(func, label))
    }
    // Repeated nested insertion must not retain every old expanded root span.
    assert_true(
      func.children.length() <= 2 * before_children + 16,
      msg="retained children before=\{before_children} after=\{func.children.length()} width=\{width}".view(),
    )
    let output = input.with_code_sec(
      @lib.CodeSec::new([@ir.hot_lower_func(func)]),
    )
    let encoded = @binary.encode_module(output).unwrap()
    let decoded = @binary.decode_module(encoded).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_true(
      encoded.length() < @binary.encode_module(input).unwrap().length(),
    )
    let @lib.Func(after_locals, _) = decoded.code_sec.unwrap().0[0]
    assert_eq(after_locals.length(), before_locals.length())
    for argument in [-1, 0, 10] {
      let events = Array::makei(2 * width, fn(lane) { argument + lane + 1 })
      let expected = (
        Some((1 + 3 * width) * argument + 3 * width * width + 2 * width),
        events,
      )
      assert_eq(
        tuple_prefix_execute(input.code_sec.unwrap().0[0], arguments=[argument]),
        expected,
      )
      assert_eq(
        tuple_prefix_execute(decoded.code_sec.unwrap().0[0], arguments=[
          argument,
        ]),
        expected,
      )
    }
  }
}

///|
test "tuple root and loop publication batches retain their original effect order" {
  let input = pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32) " +
    "block (type $pair) local.get 0 i32.const 1 i32.add call $mark local.get 0 i32.const 2 i32.add call $mark end local.set 2 local.set 1 " +
    "block (result i32) local.get 2 local.set 4 local.get 1 end local.set 3 " +
    "loop block (type $pair) local.get 0 i32.const 3 i32.add call $mark local.get 0 i32.const 4 i32.add call $mark end local.set 6 local.set 5 " +
    "block (result i32) local.get 5 local.get 6 local.set 8 end local.set 7 end " +
    "local.get 3 local.get 4 i32.add local.get 4 i32.add " +
    "local.get 7 i32.add local.get 7 i32.add local.get 7 i32.add " +
    "local.get 8 i32.add local.get 8 i32.add local.get 8 i32.add local.get 8 i32.add))",
  )
  ignore(@validate.validate_module(input).unwrap())
  for
    passes in [
      ["tuple-optimization"],
      ["tuple-optimization", "tuple-optimization"],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    let bytes = @binary.encode_module(output).unwrap()
    let decoded = @binary.decode_module(bytes).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_true(bytes.length() < @binary.encode_module(input).unwrap().length())
    if passes.length() <= 2 {
      let @lib.Func(_, @lib.Expr(body)) = decoded.code_sec.unwrap().0[0]
      assert_eq(tuple_opaque_growth_counts(body).0, 2)
    }
    for argument in [-2147483648, -1, 0, 10, 2147483647] {
      let expected = (
        Some(10 * argument + 30),
        [argument + 1, argument + 2, argument + 3, argument + 4],
      )
      assert_eq(
        tuple_prefix_execute(input.code_sec.unwrap().0[0], arguments=[argument]),
        expected,
      )
      assert_eq(
        tuple_prefix_execute(decoded.code_sec.unwrap().0[0], arguments=[
          argument,
        ]),
        expected,
      )
    }
  }
}
