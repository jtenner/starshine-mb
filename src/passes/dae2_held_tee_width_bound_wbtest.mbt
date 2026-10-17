///|
fn dae2_held_tee_width_fixture(stable_writers : Bool) -> @lib.Module {
  let source = StringBuilder::new()
  source.write_string(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local",
  )
  for _ in 0..<201 {
    source.write_string(" i32")
  }
  source.write_string(
    ") i32.const 7 local.tee 1 i32.const 0 local.set 2 local.tee 0 drop local.get 0 call $consume",
  )
  if stable_writers {
    source.write_string(
      " i32.const 8 local.set 0 local.get 0 call $consume i32.const 9 local.set 1",
    )
  }
  for index in 3..<201 {
    if index != 128 {
      source.write_string(" i32.const \{index} local.set \{index}")
    }
  }
  for _ in 0..<2 {
    for index in 1..<201 {
      if index != 128 {
        source.write_string(" local.get \{index} call $consume")
      }
    }
  }
  source.write_string(" local.get 200 local.set 128")
  for _ in 0..<16 {
    source.write_string(" local.get 128 call $consume")
  }
  source.write_string("))")
  pass_test_module_from_wat(source.to_string()).without_name_sec()
}

///|
fn dae2_held_tee_width_reference(
  input : @lib.Module,
  stable_writers : Bool,
) -> @lib.Module raise {
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected : Array[@lib.Instruction] = []
  for instr in body {
    if !stable_writers {
      match instr {
        @lib.LocalTee(@lib.LocalIdx(0U)) => continue
        @lib.LocalGet(@lib.LocalIdx(0U)) => {
          expected.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
          continue
        }
        _ => ()
      }
    } else {
      match instr {
        @lib.LocalSet(@lib.LocalIdx(128U)) => {
          assert_true(
            expected.last() is Some(@lib.LocalGet(@lib.LocalIdx(200U))),
          )
          ignore(expected.pop())
          continue
        }
        @lib.LocalGet(@lib.LocalIdx(128U)) => {
          expected.push(@lib.Instruction::local_get(@lib.LocalIdx::new(200U)))
          continue
        }
        _ => ()
      }
    }
    expected.push(instr)
  }
  let retired = if stable_writers { 128 } else { 0 }
  let indices = Array::makei(201, fn(index) {
    if index == retired {
      -1
    } else if index > retired {
      index - 1
    } else {
      index
    }
  })
  input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(Array::make(200, @lib.ValType::i32())),
        @lib.Expr::new(pass_lower_remap_locals(expected, indices)),
      ),
    ]),
  )
}

///|
test "DAE2 width bounds exclude held tee retirement before a heavily read wide alias" {
  let input = dae2_held_tee_width_fixture(false)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let (func, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    [],
    stack_effects=Some(fn(instr) {
      dae2_capture_stack_effect(instr, input, context)
    }),
    propagate_parameter_aliases=true,
    // Disable frequency ordering so it cannot hide the width-bound error.
    reorder_body_locals=false,
  )
  let output = input.with_code_sec(@lib.CodeSec::new([func]))
  let reference = dae2_held_tee_width_reference(input, false)
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  let actual = @binary.encode_module(output).unwrap()
  let expected = @binary.encode_module(reference).unwrap()
  assert_true(
    actual.length() <= expected.length(),
    msg="actual=\{actual.length()} held-tee-only=\{expected.length()}",
  )
  assert_eq(actual, expected)
  assert_eq(indices[0], -1)
  assert_true(indices[128] >= 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 width bounds retain multiwriter tee slots as guaranteed survivors" {
  let input = dae2_held_tee_width_fixture(true)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let (func, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    [],
    stack_effects=Some(fn(instr) {
      dae2_capture_stack_effect(instr, input, context)
    }),
    propagate_parameter_aliases=true,
    reorder_body_locals=false,
  )
  let output = input.with_code_sec(@lib.CodeSec::new([func]))
  let reference = dae2_held_tee_width_reference(input, true)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_true(indices[0] >= 0 && indices[1] >= 0)
  assert_eq(indices[128], -1)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
