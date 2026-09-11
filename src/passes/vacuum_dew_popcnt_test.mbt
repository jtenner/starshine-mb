///|
fn vacuum_dew_execute_popcnt(func : @lib.Func, input : UInt64) -> UInt64 raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length() + 1, 0UL)
  locals[0] = input
  let stack : Array[UInt64] = []
  for instr in body {
    match instr {
      @lib.Nop => ()
      @lib.Drop => ignore(stack.pop().unwrap())
      @lib.I64Const(@lib.I64(value)) =>
        stack.push(value.reinterpret_as_uint64())
      @lib.LocalGet(@lib.LocalIdx(index)) => stack.push(locals[index.to_int()])
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack.pop().unwrap()
      @lib.LocalTee(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack[stack.length() - 1]
      @lib.I64Add | @lib.I64Sub | @lib.I64And | @lib.I64ShrU => {
        let rhs = stack.pop().unwrap()
        let lhs = stack.pop().unwrap()
        stack.push(
          match instr {
            @lib.I64Add => lhs + rhs
            @lib.I64Sub => lhs - rhs
            @lib.I64And => lhs & rhs
            _ => lhs >> (rhs & 63UL).to_int()
          },
        )
      }
      _ => fail("unexpected popcnt instruction: \{instr}")
    }
  }
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "vacuum preserves tee writes when removing a dropped lane-popcount result" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (export "run") (param i64) (result i64)
      #|    (local i64)
      #|    local.get 0
      #|    i64.const 1
      #|    i64.shr_u
      #|    i64.const 6148914691236517205
      #|    i64.and
      #|    local.set 1
      #|    local.get 0
      #|    local.get 1
      #|    i64.sub
      #|    local.tee 0
      #|    i64.const 3689348814741910323
      #|    i64.and
      #|    local.tee 1
      #|    drop
      #|    local.get 1
      #|    local.get 0
      #|    i64.const 2
      #|    i64.shr_u
      #|    i64.const 3689348814741910323
      #|    i64.and
      #|    i64.add
      #|    local.tee 0
      #|    i64.const 4
      #|    i64.shr_u
      #|    local.set 1
      #|    local.get 0
      #|    local.get 1
      #|    i64.add
      #|    i64.const 1085102592571150095
      #|    i64.and
      #|  )
      #|)
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for
    bits in [
      0UL, 0x0f0f0f0f0f0f0f0fUL, 0xffffffffffffffffUL, 0x8001020408102040UL,
    ] {
    // Independent scalar reference: count individual bits in each byte.
    let mut expected = 0UL
    for lane in 0..<8 {
      let mut count = 0UL
      for bit in 0..<8 {
        count += (bits >> (lane * 8 + bit)) & 1UL
      }
      expected = expected | (count << (lane * 8))
    }
    for module_ in [input, output] {
      @debug.assert_eq(
        vacuum_dew_execute_popcnt(module_.code_sec.unwrap().0[0], bits),
        expected,
      )
    }
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  for instr in body {
    assert_false(instr is @lib.Drop)
  }
}
