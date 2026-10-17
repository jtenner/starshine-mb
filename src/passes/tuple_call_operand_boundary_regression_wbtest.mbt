///|
// This executor covers only the branch-free prefix fixtures. A zero divisor
// records a wasm trap, and unsupported instructions fail within a fixed bound.
fn tuple_call_boundary_execute(
  func : @lib.Func,
) -> (Int32?, Array[Array[Int32]]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  let stack : Array[Int32] = []
  let events : Array[Array[Int32]] = []
  let mut fuel = 512
  fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
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
        @lib.I32Add | @lib.I32DivS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          if instr is @lib.I32DivS {
            if rhs == 0 || (lhs == -2147483648 && rhs == -1) {
              return true
            }
            stack.push(lhs / rhs)
          } else {
            stack.push(lhs + rhs)
          }
        }
        @lib.Call(index) =>
          if index == @lib.FuncIdx::new(0U) {
            events.push([0, stack[stack.length() - 1]])
          } else {
            assert_eq(index, @lib.FuncIdx::new(1U))
            let rhs = stack.pop().unwrap()
            let lhs = stack.pop().unwrap()
            events.push([1, lhs, rhs])
            stack.push(rhs)
          }
        @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
          if execute(nested) {
            return true
          }
        @lib.Unreachable => return true
        _ => fail("unsupported tuple prefix fixture instruction: \{instr}")
      }
    }
    false
  }
  let trapped = execute(body)
  let value = if trapped {
    None
  } else {
    assert_eq(stack.length(), 1)
    Some(stack[0])
  }
  (value, events)
}

///|
fn tuple_call_boundary_check(
  trapping : Bool,
  control : String,
  reduced : Bool,
) -> Unit raise {
  let before = if trapping {
    "i32.const 1 i32.const 0 i32.div_s "
  } else {
    "i32.const 77 call $mark "
  }
  let open_control = if reduced && control == "block" {
    ""
  } else {
    control + " (result i32) "
  }
  let close_control = if reduced && control == "block" { "" } else { "end " }
  let host_write = if reduced {
    "local.set $a local.get $a "
  } else {
    "local.tee $a "
  }
  let text = "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(import \"env\" \"observe\" (func $observe (param i32 i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) " +
    "(local $a i32) (local $b i32) (local $observed i32) " +
    open_control +
    before +
    "block (type $pair) i32.const 11 call $mark i32.const 100 call $mark end " +
    "local.set $b " +
    host_write +
    "call $observe drop local.get $b call $mark " +
    close_control +
    "))"
  let input = pass_test_module_from_wat(text)
  ignore(@validate.validate_module(input).unwrap())
  let expected : (Int32?, Array[Array[Int32]]) = if trapping {
    (None, [])
  } else {
    (Some(100), [[0, 77], [0, 11], [0, 100], [1, 77, 11], [0, 100]])
  }
  assert_eq(tuple_call_boundary_execute(input.code_sec.unwrap().0[0]), expected)
  for
    passes in [
      ["tuple-optimization"],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization",
      ],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_call_boundary_execute(decoded.code_sec.unwrap().0[0]),
      expected,
    )
  }
}

///|
test "tuple block later Call operand keeps earlier effects before producer after cleanup" {
  tuple_call_boundary_check(false, "block", false)
}

///|
test "tuple loop later Call operand keeps earlier effects before producer after cleanup" {
  tuple_call_boundary_check(false, "loop", false)
}

///|
test "tuple block trap before producer remains before producer after repeated cleanup" {
  tuple_call_boundary_check(true, "block", false)
}

///|
test "tuple loop trap before producer remains before producer after repeated cleanup" {
  tuple_call_boundary_check(true, "loop", false)
}

///|
test "tuple reduced block earlier Call operand precedes producer effects" {
  tuple_call_boundary_check(false, "block", true)
}

///|
test "tuple reduced loop earlier Call operand precedes producer effects" {
  tuple_call_boundary_check(false, "loop", true)
}

///|
test "tuple reduced block earlier trap prevents producer effects" {
  tuple_call_boundary_check(true, "block", true)
}

///|
test "tuple reduced loop earlier trap prevents producer effects" {
  tuple_call_boundary_check(true, "loop", true)
}
