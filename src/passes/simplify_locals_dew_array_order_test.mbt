///|
enum SimplifyLocalsDewArrayValue {
  Scalar(Int)
  Elements(Array[Int])
  Fields(Array[SimplifyLocalsDewArrayValue])
}

///|
fn simplify_locals_dew_array_int(
  value : SimplifyLocalsDewArrayValue,
) -> Int raise {
  match value {
    Scalar(value) => value
    _ => fail("expected scalar in array-pop execution")
  }
}

///|
fn simplify_locals_dew_array_execute(
  func : @lib.Func,
  elements : Array[Int],
) -> (Int, Array[Int]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 1, Scalar(0))
  locals[0] = Fields([Elements(elements), Scalar(elements.length())])
  let stack : Array[SimplifyLocalsDewArrayValue] = []
  let events : Array[Int] = []
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      match instr {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(Scalar(value))
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.I32Eq | @lib.I32Sub => {
          let rhs = simplify_locals_dew_array_int(stack.pop().unwrap())
          let lhs = simplify_locals_dew_array_int(stack.pop().unwrap())
          stack.push(
            Scalar(
              match instr {
                @lib.I32Eq => if lhs == rhs { 1 } else { 0 }
                _ => lhs - rhs
              },
            ),
          )
        }
        @lib.If(_, then_body, else_body) => {
          let condition = simplify_locals_dew_array_int(stack.pop().unwrap())
          execute(if condition != 0 { then_body } else { else_body.or([]) })
        }
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        @lib.RefCast(_) => ()
        @lib.StructGet(_, @lib.U32(field)) =>
          match stack.pop().unwrap() {
            Fields(values) => stack.push(values[field.to_int()])
            _ => fail("expected struct for array-pop field read")
          }
        @lib.StructNew(@lib.TypeIdx(type_id)) => {
          let count = match type_id {
            1U => 1
            2U => 2
            _ => fail("unexpected array-pop struct type")
          }
          let fields = Array::make(count, Scalar(0))
          for index = count - 1; index >= 0; index = index - 1 {
            fields[index] = stack.pop().unwrap()
          }
          stack.push(Fields(fields))
        }
        @lib.ArrayGet(@lib.TypeIdx(0U)) => {
          let index = simplify_locals_dew_array_int(stack.pop().unwrap())
          match stack.pop().unwrap() {
            Elements(values) => {
              assert_true(
                index >= 0 && index < values.length(),
                msg="array-pop read out of bounds",
              )
              events.push(0)
              events.push(index)
              events.push(values[index])
              stack.push(Scalar(values[index]))
            }
            _ => fail("expected array for array-pop element read")
          }
        }
        @lib.Call(@lib.FuncIdx(0U)) => {
          let index = simplify_locals_dew_array_int(stack.pop().unwrap())
          match stack.pop().unwrap() {
            Fields([Elements(values), _]) => {
              assert_true(
                index >= 0 && index < values.length(),
                msg="array-pop mutation out of bounds",
              )
              events.push(1)
              events.push(index)
              events.push(99)
              values[index] = 99
            }
            _ => fail("expected state for array-pop mutation")
          }
        }
        _ => fail("unexpected array-pop instruction: \{instr}")
      }
    }
  }
  execute(body)
  @debug.assert_eq(stack.length(), 1)
  let payload = match stack[0] {
    Fields([Scalar(0)]) => 0
    Fields([Scalar(1), Scalar(value)]) => value
    _ => fail("unexpected array-pop result")
  }
  (payload, events)
}

///|
test "simplify-locals retains an array read and index write before mutation" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x2a\x07\x5e\x7f\x01\x50\x00\x5f\x01\x7f\x00\x50\x01\x01\x5f\x02\x7f\x00\x7f\x00\x5f\x02\x64\x00\x00\x7f\x00\x60\x02\x64\x03\x7f\x00\x60\x01\x64\x03\x01\x64\x01\x60\x00\x00\x03\x04\x03\x04\x05\x06\x07\x0e\x02\x03\x72\x75\x6e\x00\x01\x04\x6d\x61\x69\x6e\x00\x02\x0a\x85\x01\x03\x19\x00\x20\x01\x41\x01\x47\x04\x40\x00\x0b\x20\x00\xfb\x02\x03\x00\x20\x01\x41\xe3\x00\xfb\x0e\x00\x0b\x49\x02\x01\x6b\x01\x7f\x20\x00\xfb\x02\x03\x01\x41\x00\x46\x04\x40\x41\x00\xfb\x00\x01\x21\x01\x05\x20\x00\xfb\x02\x03\x01\x41\x01\x6b\x21\x02\x20\x00\xfb\x02\x03\x00\xfb\x16\x00\x20\x02\xfb\x0b\x00\x20\x00\x20\x02\x10\x00\x21\x02\x41\x01\x20\x02\xfb\x00\x02\x21\x01\x0b\x20\x01\xfb\x16\x01\x0b\x1f\x00\x41\x29\x41\x2a\xfb\x08\x00\x02\x41\x02\xfb\x00\x03\x10\x01\xfb\x16\x02\xfb\x02\x02\x01\x41\x2a\x47\x04\x40\x00\x0b\x0b",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for initial in [[], [42], [41, 42], [7, 11, 42]] {
    for module_ in [input, output] {
      let elements = initial.copy()
      let (value, events) = simplify_locals_dew_array_execute(
        module_.code_sec.unwrap().0[1],
        elements,
      )
      if initial.is_empty() {
        @debug.assert_eq(value, 0)
        @debug.assert_eq(events, [])
      } else {
        @debug.assert_eq(value, 42)
        let index = initial.length() - 1
        @debug.assert_eq(events, [0, index, 42, 1, index, 99])
        let expected = initial.copy()
        expected[index] = 99
        @debug.assert_eq(elements, expected)
      }
    }
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(
    body.any(fn(instr) { instr is @lib.If(@lib.ValTypeBlockType(_), _, _) }),
    msg="the conditional must still produce the result directly",
  )
}
