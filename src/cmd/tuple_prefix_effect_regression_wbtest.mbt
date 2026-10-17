///|
// This executor covers only the branch-free prefix fixtures. A zero divisor
// records a wasm trap, and unsupported instructions fail within a fixed bound.
fn tuple_prefix_cmd_execute(
  func : @lib.Func,
  arguments~ : Array[Int32] = [0],
) -> (Int32?, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(arguments.length() + body_locals.length(), 0)
  for index = 0; index < arguments.length(); index = index + 1 {
    locals[index] = arguments[index]
  }
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
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
        @lib.Call(index) => {
          assert_eq(index, @lib.FuncIdx::new(0U))
          events.push(stack[stack.length() - 1])
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
fn tuple_prefix_cmd_check(trapping : Bool) -> Unit raise {
  let trap_code = if trapping {
    "i32.const 1 i32.const 0 i32.div_s drop "
  } else {
    ""
  }
  let prefix = "i32.const 9 call $mark drop " + trap_code
  for
    copy in [
      "block (type $pair) " +
      prefix +
      "local.get $a local.get $b end local.set $ob local.set $oa ",
      "block (result i32) local.get $b local.set $ob block (result i32) " +
      prefix +
      "local.get $a end end local.set $oa ",
      "block (result i32) " +
      prefix +
      "local.get $a local.get $b local.set $ob end local.set $oa ",
    ] {
    let text = "(module (type $pair (func (result i32 i32))) " +
      "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
      "(func (export \"run\") (param i32) (result i32) " +
      "(local $a i32) (local $b i32) (local $oa i32) (local $ob i32) " +
      "block (type $pair) i32.const 11 i32.const 100 end local.set $b local.set $a " +
      copy +
      "local.get $oa local.get $ob i32.add))"
    let input = @passes.pass_test_module_from_wat(text)
    let expected = (if trapping { None } else { Some(111) }, [9])
    assert_eq(tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0]), expected)
    for
      passes in [
        ["tuple-optimization"],
        ["tuple-optimization", "tuple-optimization"],
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
        tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0]),
        expected,
      )
    }
  }
}

///|
test "tuple dispatcher copy prefixes preserve calls" {
  tuple_prefix_cmd_check(false)
}

///|
test "tuple dispatcher copy prefixes preserve intentional division traps" {
  tuple_prefix_cmd_check(true)
}
