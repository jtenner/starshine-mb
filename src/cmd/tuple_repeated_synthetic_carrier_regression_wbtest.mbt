///|
test "tuple dispatcher repeated synthetic carriers preserve both captured lanes" {
  for control in ["loop", "block"] {
    let text = "(module (type $pair (func (result i32 i32))) " +
      "(func (export \"run\") (result i32) " +
      "(local $a i32) (local $b i32) (local $sa i32) (local $sb i32) " +
      "(local $oa i32) (local $ob i32) (local $i i32) " +
      control +
      " " +
      "block (type $pair) local.get $i i32.const 11 i32.add " +
      "local.get $i i32.const 100 i32.add end local.set $b local.set $a " +
      "i32.const 1 if local.get $a local.set $sa local.get $b local.set $sb end " +
      "block (result i32) local.get $sb local.set $ob local.get $sa end local.set $oa " +
      "end local.get $oa local.get $ob i32.add))"
    let input = @passes.pass_test_module_from_wat(text)
    assert_eq(tuple_alias_cmd_execute(input.code_sec.unwrap().0[0]), 111)
    for
      passes in [
        ["tuple-optimization"],
        ["tuple-optimization", "tuple-optimization"],
        ["tuple-optimization", "tuple-optimization", "tuple-optimization"],
        [
          "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum", "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum",
        ],
      ] {
      let output = optimize_module_with_pass_flags(
        input,
        passes,
        OptimizeOptions::new(),
      ).unwrap()
      let decoded = decode_module_bytes(encode_module_bytes(output))
      ignore(@validate.validate_module(decoded).unwrap())
      assert_eq(tuple_alias_cmd_execute(decoded.code_sec.unwrap().0[0]), 111)
    }
  }
}

///|
// Branch-free fixture executor with one parameter and one identity import.
fn tuple_partial_cmd_execute(func : @lib.Func) -> (Int32, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
  let mut fuel = 512
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel > 0)
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
        @lib.Call(index) =>
          if index == @lib.FuncIdx::new(0U) {
            events.push(stack[stack.length() - 1])
          } else {
            assert_eq(index, @lib.FuncIdx::new(1U))
            let rhs = stack.pop().unwrap()
            let lhs = stack.pop().unwrap()
            events.push(lhs)
            events.push(rhs)
            stack.push(lhs)
          }
        @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
          execute(nested)
        _ => fail("unsupported partial tuple fixture instruction: \{instr}")
      }
    }
  }
  execute(body)
  assert_eq(stack.length(), 1)
  (stack[0], events)
}

///|
test "tuple dispatcher first Call operand tee precedes later operand effects" {
  let text = "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(import \"env\" \"observe\" (func $observe (param i32 i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) " +
    "(local $a i32) (local $b i32) (local $observed i32) " +
    "loop block (type $pair) i32.const 11 call $mark i32.const 100 call $mark end " +
    "local.tee $b i32.const 77 call $mark call $observe drop " +
    "local.get $b call $mark local.set $observed local.set $a " +
    "end local.get $observed))"
  let input = @passes.pass_test_module_from_wat(text)
  let expected = (100, [11, 100, 77, 100, 77, 100])
  assert_eq(tuple_partial_cmd_execute(input.code_sec.unwrap().0[0]), expected)
  for
    passes in [
      ["tuple-optimization"],
      ["tuple-optimization", "tuple-optimization"],
    ] {
    let output = optimize_module_with_pass_flags(
      input,
      passes,
      OptimizeOptions::new(),
    ).unwrap()
    let decoded = decode_module_bytes(encode_module_bytes(output))
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_partial_cmd_execute(decoded.code_sec.unwrap().0[0]),
      expected,
    )
  }
}

///|
test "tuple dispatcher partial publication preserves calls between lane writes" {
  for control in ["loop", "block"] {
    for
      write in [
        "local.set $b", "local.tee $b drop", "local.tee $b call $mark drop",
      ] {
      let text = "(module (type $pair (func (result i32 i32))) " +
        "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
        "(func (export \"run\") (param i32) (result i32) " +
        "(local $a i32) (local $b i32) (local $observed i32) " +
        control +
        " " +
        "block (type $pair) i32.const 11 call $mark i32.const 100 call $mark end " +
        write +
        " local.get $b call $mark local.set $observed local.set $a " +
        "end local.get $observed))"
      let input = @passes.pass_test_module_from_wat(text)
      let expected = (
        100,
        if write == "local.tee $b call $mark drop" {
          [11, 100, 100, 100]
        } else {
          [11, 100, 100]
        },
      )
      assert_eq(
        tuple_partial_cmd_execute(input.code_sec.unwrap().0[0]),
        expected,
      )
      for
        passes in [
          ["tuple-optimization"],
          ["tuple-optimization", "tuple-optimization", "tuple-optimization"],
          [
            "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
            "vacuum", "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
            "vacuum",
          ],
        ] {
        let output = optimize_module_with_pass_flags(
          input,
          passes,
          OptimizeOptions::new(),
        ).unwrap()
        let decoded = decode_module_bytes(encode_module_bytes(output))
        ignore(@validate.validate_module(decoded).unwrap())
        assert_eq(
          tuple_partial_cmd_execute(decoded.code_sec.unwrap().0[0]),
          expected,
        )
      }
    }
  }
}

///|
fn tuple_cmd_host_tee_execute(
  func : @lib.Func,
  tri_lanes : Array[Int32],
) -> Int32 raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length(), 0)
  let stack : Array[Int32] = []
  let calls : Array[Int32] = []
  assert_true(body.length() < 64)
  for instr in body {
    match instr {
      @lib.I32Const(@lib.I32(value)) => stack.push(value)
      @lib.Drop => ignore(stack.pop().unwrap())
      @lib.LocalGet(@lib.LocalIdx(index)) => stack.push(locals[index.to_int()])
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack.pop().unwrap()
      @lib.LocalTee(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack[stack.length() - 1]
      @lib.Call(index) =>
        if index == @lib.FuncIdx::new(0U) {
          assert_eq(stack.pop().unwrap(), 10000)
          assert_eq(stack.pop().unwrap(), 42)
          for value in tri_lanes {
            stack.push(value)
          }
          calls.push(0)
        } else {
          assert_eq(index, @lib.FuncIdx::new(1U))
          let lane2 = stack.pop().unwrap()
          let lane1 = stack.pop().unwrap()
          let lane0 = stack.pop().unwrap()
          assert_eq([lane0, lane1, lane2], tri_lanes)
          stack.push(lane0 + lane1 + lane2)
          calls.push(1)
        }
      _ => fail("unsupported host tee fixture instruction: \{instr}")
    }
  }
  assert_eq(calls, [0, 1])
  assert_eq(stack.length(), 1)
  stack[0]
}
