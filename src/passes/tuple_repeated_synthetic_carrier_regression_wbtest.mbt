///|
fn tuple_repeat_synthetic_source(control : String) -> String {
  "(module (type $pair (func (result i32 i32))) " +
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
}

///|
test "tuple repeated synthetic carrier writes precede interleaved lane reads" {
  // The arithmetic tuple is an opaque producer to the simple-lane cloner.
  // Its first rewrite introduces a scratch lane read between the two writes.
  for control in ["loop", "block"] {
    let input = pass_test_module_from_wat(
      tuple_repeat_synthetic_source(control),
    )
    assert_eq(tuple_alias_capture_execute(input.code_sec.unwrap().0[0]), 111)
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
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
      ignore(@validate.validate_module(output).unwrap())
      let decoded = @binary.decode_module(
        @binary.encode_module(output).unwrap(),
      ).unwrap()
      ignore(@validate.validate_module(decoded).unwrap())
      assert_eq(
        tuple_alias_capture_execute(decoded.code_sec.unwrap().0[0]),
        111,
      )
    }
  }
}

///|
test "tuple partial lane publication preserves intervening calls and tee values" {
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
      let input = pass_test_module_from_wat(text)
      let expected = (
        100,
        if write == "local.tee $b call $mark drop" {
          [11, 100, 100, 100]
        } else {
          [11, 100, 100]
        },
      )
      assert_eq(
        tuple_nested_overlap_effect_execute(input.code_sec.unwrap().0[0], 0),
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
        let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
        let decoded = @binary.decode_module(
          @binary.encode_module(output).unwrap(),
        ).unwrap()
        ignore(@validate.validate_module(decoded).unwrap())
        assert_eq(
          tuple_nested_overlap_effect_execute(decoded.code_sec.unwrap().0[0], 0),
          expected,
        )
      }
    }
  }
}

///|
// Branch-free fixture executor with one parameter and one identity import.
fn tuple_partial_call_execute(func : @lib.Func) -> (Int32, Array[Int32]) raise {
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
test "tuple first Call operand tee precedes later operand effects" {
  let text = "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(import \"env\" \"observe\" (func $observe (param i32 i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) " +
    "(local $a i32) (local $b i32) (local $observed i32) " +
    "loop block (type $pair) i32.const 11 call $mark i32.const 100 call $mark end " +
    "local.tee $b i32.const 77 call $mark call $observe drop " +
    "local.get $b call $mark local.set $observed local.set $a " +
    "end local.get $observed))"
  let input = pass_test_module_from_wat(text)
  let expected = (100, [11, 100, 77, 100, 77, 100])
  assert_eq(tuple_partial_call_execute(input.code_sec.unwrap().0[0]), expected)
  for
    passes in [
      ["tuple-optimization"],
      ["tuple-optimization", "tuple-optimization"],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_partial_call_execute(decoded.code_sec.unwrap().0[0]),
      expected,
    )
  }
}
