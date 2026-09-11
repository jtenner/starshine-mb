///|
test "vacuum admits a void function containing only a conditional return" {
  let output = pass_test_run_pipeline(
    "(module (func (param i32) (if (local.get 0) (then (return)))))",
    ["vacuum"],
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.all(fn(instr) { instr is @lib.Nop }))
}

///|
test "vacuum drops an empty else while retaining a conditional global write" {
  let output = pass_test_run_pipeline(
    "(module (global (mut i32) (i32.const 0)) (func (param i32) (if (local.get 0) (then (global.set 0 (i32.const 7))) (else))))",
    ["vacuum"],
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let mut found = false
  for instr in body {
    if instr is @lib.If(_, yes, no) {
      found = true
      @debug.assert_eq(no, None)
      assert_true(
        yes.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U))),
      )
    }
  }
  assert_true(found)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "DAE2 optimizing cleans control left after removing the result" {
  let output = pass_test_run_pipeline(
    "(module (func $produce (param i32 i32) (result i32) (if (result i32) (local.get 0) (then (return (local.get 1))) (else (i32.const 7)))) (func $consume (param i32)) (func (export \"run\") (param i32) (call $consume (call $produce (local.get 0) (i32.const 9)))))",
    ["dae2-optimizing"],
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.all(fn(instr) { instr is @lib.Nop }))
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "DAE2 optimizing removes empty else carriers from recursive calls" {
  // Preserve the generated binary carrier; WAST adaptation already drops an
  // explicit empty else in some input shapes.
  let input = @binary.decode_module(
    Bytes::from_array([
      0, 97, 115, 109, 1, 0, 0, 0, 1, 16, 3, 96, 2, 127, 127, 1, 127, 96, 2, 127,
      127, 1, 127, 96, 0, 0, 3, 4, 3, 0, 1, 2, 7, 7, 1, 3, 114, 117, 110, 0, 2, 10,
      69, 3, 26, 0, 32, 0, 4, 127, 32, 0, 65, 1, 107, 32, 1, 65, 174, 236, 214, 212,
      126, 106, 16, 1, 5, 32, 1, 11, 11, 26, 0, 32, 0, 4, 127, 32, 0, 65, 1, 107,
      32, 1, 65, 174, 236, 214, 212, 126, 106, 16, 0, 5, 32, 1, 11, 11, 13, 0, 65,
      5, 65, 174, 236, 214, 212, 126, 16, 0, 26, 11,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae2-optimizing",
  ]).unwrap()
  for index in [0U, 1U] {
    let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(index))
    let mut found = false
    for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
      if @ir.hot_node_get(hot, node).op is @ir.HotOp::If {
        found = true
        assert_true(@ir.hot_region_else_ref(hot, node) is None)
      }
    }
    assert_true(found)
  }
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "vacuum removes dropped call without effects while preserving its effectful arguments" {
  for module_name in ["binaryen-intrinsics", "env"] {
    let source = "(module (type $target (func (param i32) (result i32))) (import \"\{module_name}\" \"call.without.effects\" (func $invoke (param i32 funcref) (result i32))) (import \"env\" \"argument\" (func $argument (result i32))) (func $target (type $target) (local.get 0)) (elem declare func $target) (func (export \"run\") (drop (call $invoke (call $argument) (ref.func $target)))))"
    let output = pass_test_run_pipeline(source, ["vacuum"]).unwrap()
    let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(3U))
    let calls : Array[Int] = []
    for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
      let data = @ir.hot_node_get(hot, node)
      if data.op is @ir.HotOp::Call {
        calls.push(data.imm0)
      }
    }
    calls.sort()
    @debug.assert_eq(
      calls,
      if module_name == "binaryen-intrinsics" {
        [1]
      } else {
        [0, 1]
      },
    )
    if module_name == "binaryen-intrinsics" {
      @debug.assert_eq(output.elem_sec, None)
    } else {
      assert_true(output.elem_sec is Some(_))
    }
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}

///|
test "vacuum retains declarations used by references or element-index instructions" {
  for
    source in [
      "(module (func $target) (elem declare func $target) (func (export \"run\") (result funcref) (ref.func $target)))",
      "(module (func $target) (elem declare func $target) (func (export \"run\") (elem.drop 0)))",
      "(module (func $target) (elem declare func $target) (global (export \"target\") funcref (ref.func $target)))",
      "(module (table 1 funcref) (func $target) (elem (i32.const 0) func $target))",
    ] {
    let output = pass_test_run_pipeline(source, ["vacuum"]).unwrap()
    assert_true(output.elem_sec is Some(_))
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}

///|
test "simplify locals removes unread result-if writes and preserves observable arm writes" {
  for
    passes in [
      ["simplify-locals"],
      ["simplify-locals", "vacuum"],
      ["dae2-optimizing"],
    ] {
    let output = pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) (local.set 2 (if (result i32) (local.get 0) (then (local.set 1 (i32.const 40)) (i32.const 0)) (else (local.set 1 (i32.const 41)) (i32.const 1)))) (local.get 1)))",
      passes,
    ).unwrap()
    let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
    let mut writes = 0
    for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
      let data = @ir.hot_node_get(hot, node)
      if data.op is @ir.HotOp::LocalSet && data.imm0 == 2 {
        writes += 1
      }
    }
    assert_eq(writes, 0)
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}

///|
test "optimize instructions keeps unequal local values across conditional writes" {
  let input = "(module (memory 1) (func (param i32 i32 i32) (local i32) (local.set 3 (local.get 0)) local.get 0 (if (local.get 2) (then (local.set 3 (i32.add (local.get 0) (i32.const 4))))) local.get 3 local.get 1 memory.copy))"
  let output = pass_test_run_pipeline(
    input,
    ["optimize-instructions"],
    options=HotPipelineOptions::new(traps_never_happen=true),
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.MemoryCopy(_, _) }))
}
