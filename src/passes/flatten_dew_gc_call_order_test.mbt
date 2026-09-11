///|
fn flatten_dew_gc_call_execute(
  func : @lib.Func,
  initial : Int,
  condition : Int,
  helper_delta : Int,
) -> (Int, Int, Array[Int]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 2, 0)
  locals[1] = condition
  let stack : Array[Int] = []
  let events : Array[Int] = []
  let mut field = initial
  let mut fuel = 300
  fn execute(instrs : Array[@lib.Instruction]) -> Bool raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel >= 0, msg="flatten GC call exceeded 300 instructions")
      match instr {
        @lib.Nop => ()
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
        @lib.Call(@lib.FuncIdx(0U)) => {
          // The only helper reads the supplied box. Reference 0 is that box.
          @debug.assert_eq(stack.pop().unwrap(), 0)
          events.append([0, field])
          stack.push(field)
          field += helper_delta
        }
        @lib.StructGet(@lib.TypeIdx(0U), @lib.U32(0U)) => {
          @debug.assert_eq(stack.pop().unwrap(), 0)
          stack.push(field)
        }
        @lib.StructSet(@lib.TypeIdx(0U), @lib.U32(0U)) => {
          let value = stack.pop().unwrap()
          @debug.assert_eq(stack.pop().unwrap(), 0)
          field = value
          events.append([1, field])
        }
        @lib.If(_, then_body, else_body) => {
          let condition = stack.pop().unwrap()
          if execute(if condition != 0 { then_body } else { else_body.or([]) }) {
            return true
          }
        }
        @lib.Block(_, @lib.Expr(nested)) => if execute(nested) { return true }
        @lib.Return => return true
        _ => fail("unexpected flatten GC call instruction or trap: \{instr}")
      }
    }
    false
  }
  ignore(execute(body))
  @debug.assert_eq(stack.length(), 1)
  (stack[0], field, events)
}

///|
test "flatten spills a carried call before a GC field write" {
  // Flat and conditional variants of:
  //   1; call read(box); box.field += 1; add
  // The call result must be captured before the field write.
  // A helper that also writes the box must precede the later field read.
  for
    fixture in [
      (
        false, 0, b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x12\x03\x5f\x01\x7f\x01\x60\x01\x64\x00\x01\x7f\x60\x02\x64\x00\x7f\x01\x7f\x03\x03\x02\x01\x02\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x23\x02\x08\x00\x20\x00\xfb\x02\x00\x00\x0b\x18\x00\x41\x01\x20\x00\x10\x00\x20\x00\x20\x00\xfb\x02\x00\x00\x41\x01\x6a\xfb\x05\x00\x00\x6a\x0b\x00\x16\x04\x6e\x61\x6d\x65\x01\x07\x01\x00\x04\x72\x65\x61\x64\x04\x06\x01\x00\x03\x62\x6f\x78",
      ),
      (
        false, 10, b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x12\x03\x5f\x01\x7f\x01\x60\x01\x64\x00\x01\x7f\x60\x02\x64\x00\x7f\x01\x7f\x03\x03\x02\x01\x02\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x32\x02\x17\x00\x20\x00\xfb\x02\x00\x00\x20\x00\x20\x00\xfb\x02\x00\x00\x41\x0a\x6a\xfb\x05\x00\x00\x0b\x18\x00\x41\x01\x20\x00\x10\x00\x20\x00\x20\x00\xfb\x02\x00\x00\x41\x01\x6a\xfb\x05\x00\x00\x6a\x0b\x00\x16\x04\x6e\x61\x6d\x65\x01\x07\x01\x00\x04\x72\x65\x61\x64\x04\x06\x01\x00\x03\x62\x6f\x78",
      ),
      (
        true, 0, b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x12\x03\x5f\x01\x7f\x01\x60\x01\x64\x00\x01\x7f\x60\x02\x64\x00\x7f\x01\x7f\x03\x03\x02\x01\x02\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x2b\x02\x08\x00\x20\x00\xfb\x02\x00\x00\x0b\x20\x00\x20\x01\x04\x7f\x41\x01\x20\x00\x10\x00\x20\x00\x20\x00\xfb\x02\x00\x00\x41\x01\x6a\xfb\x05\x00\x00\x6a\x05\x41\x00\x0b\x0b\x00\x16\x04\x6e\x61\x6d\x65\x01\x07\x01\x00\x04\x72\x65\x61\x64\x04\x06\x01\x00\x03\x62\x6f\x78",
      ),
      (
        true, 10, b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x12\x03\x5f\x01\x7f\x01\x60\x01\x64\x00\x01\x7f\x60\x02\x64\x00\x7f\x01\x7f\x03\x03\x02\x01\x02\x07\x07\x01\x03\x72\x75\x6e\x00\x01\x0a\x3a\x02\x17\x00\x20\x00\xfb\x02\x00\x00\x20\x00\x20\x00\xfb\x02\x00\x00\x41\x0a\x6a\xfb\x05\x00\x00\x0b\x20\x00\x20\x01\x04\x7f\x41\x01\x20\x00\x10\x00\x20\x00\x20\x00\xfb\x02\x00\x00\x41\x01\x6a\xfb\x05\x00\x00\x6a\x05\x41\x00\x0b\x0b\x00\x16\x04\x6e\x61\x6d\x65\x01\x07\x01\x00\x04\x72\x65\x61\x64\x04\x06\x01\x00\x03\x62\x6f\x78",
      ),
    ] {
    let (nested, helper_delta, bytes) = fixture
    let input = @binary.decode_module(bytes).unwrap()
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let before = input.code_sec.unwrap().0[1]
    let after = output.code_sec.unwrap().0[1]
    let @lib.Func(before_locals, _) = before
    let @lib.Func(after_locals, _) = after
    assert_true(after_locals.length() > before_locals.length())
    for initial in [-5, 0, 41] {
      for condition in [0, 1] {
        let expected = if !nested || condition != 0 {
          (
            initial + 1,
            initial + helper_delta + 1,
            [0, initial, 1, initial + helper_delta + 1],
          )
        } else {
          (0, initial, [])
        }
        @debug.assert_eq(
          flatten_dew_gc_call_execute(before, initial, condition, helper_delta),
          expected,
        )
        @debug.assert_eq(
          flatten_dew_gc_call_execute(after, initial, condition, helper_delta),
          expected,
        )
      }
    }
  }
}

///|
fn flatten_dew_tee_prerequisite_execute(
  func : @lib.Func,
  field : Int,
) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  // -1 represents a null reference. Parameter 0 is the non-null box.
  let locals = Array::make(body_locals.length() + 1, -1)
  locals[0] = 0
  let stack : Array[Int] = []
  let mut fuel = 300
  for instr in body {
    fuel -= 1
    assert_true(
      fuel >= 0,
      msg="flatten tee prerequisite exceeded 300 instructions",
    )
    match instr {
      @lib.Nop => ()
      @lib.LocalGet(@lib.LocalIdx(index)) => stack.push(locals[index.to_int()])
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack.pop().unwrap()
      @lib.LocalTee(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack[stack.length() - 1]
      @lib.RefCast(_) =>
        @debug.assert_eq(
          stack[stack.length() - 1],
          0,
          msg="cast before reference-local initialization",
        )
      @lib.StructGet(@lib.TypeIdx(0U), @lib.U32(0U)) => {
        @debug.assert_eq(stack.pop().unwrap(), 0)
        stack.push(field)
      }
      @lib.Call(@lib.FuncIdx(index)) if index == 0U || index == 1U => {
        let count = if index == 0U { 2 } else { 3 }
        let mut sum = 0
        for i = 0; i < count; i = i + 1 {
          sum += stack.pop().unwrap()
        }
        stack.push(sum)
      }
      @lib.Return => break
      _ => fail("unexpected flatten tee prerequisite instruction: \{instr}")
    }
  }
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "flatten moves a split tee initialization with its carried cast" {
  // A first box field is carried across a nested call whose arguments split
  // another tee. Both casts must remain after their own tee initialization.
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x1a\x05\x5f\x01\x7f\x00\x60\x02\x7f\x7f\x01\x7f\x60\x03\x7f\x7f\x7f\x01\x7f\x60\x01\x6d\x01\x7f\x60\x00\x00\x03\x05\x04\x01\x02\x03\x04\x07\x08\x01\x04\x6d\x61\x69\x6e\x00\x03\x0a\x57\x04\x07\x00\x20\x00\x20\x01\x6a\x0b\x0a\x00\x20\x00\x20\x01\x6a\x20\x02\x6a\x0b\x30\x01\x02\x6d\x20\x00\x22\x02\xfb\x16\x00\xfb\x02\x00\x00\x20\x00\x22\x01\xfb\x16\x00\xfb\x02\x00\x00\x20\x01\xfb\x16\x00\xfb\x02\x00\x00\x10\x00\x20\x02\xfb\x16\x00\xfb\x02\x00\x00\x10\x01\x0b\x11\x00\x41\x11\xfb\x00\x00\x10\x02\x41\xc4\x00\x47\x04\x40\x00\x0b\x0b\x00\x21\x04\x6e\x61\x6d\x65\x01\x12\x03\x00\x04\x61\x64\x64\x32\x01\x04\x61\x64\x64\x33\x02\x03\x72\x75\x6e\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let before = input.code_sec.unwrap().0[2]
  let after = output.code_sec.unwrap().0[2]
  let @lib.Func(before_locals, _) = before
  let @lib.Func(after_locals, _) = after
  assert_true(after_locals.length() > before_locals.length())
  for field in [17, 41] {
    @debug.assert_eq(
      flatten_dew_tee_prerequisite_execute(before, field),
      field * 4,
    )
    @debug.assert_eq(
      flatten_dew_tee_prerequisite_execute(after, field),
      field * 4,
    )
  }
}
