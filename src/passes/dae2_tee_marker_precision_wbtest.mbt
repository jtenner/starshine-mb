///|
fn dae2_tee_marker_precision_fixture(mode : Int32) -> @lib.Module {
  let copy = if mode == 7 { 130 } else { 128 }
  let wat = StringBuilder()
  wat.write_string(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local",
  )
  for _ in 0..<201 {
    wat.write_string(" i32")
  }
  wat.write_string(")")
  if mode == 0 || mode == 4 {
    wat.write_string(" i32.const 7 local.tee 0 drop")
  } else if mode == 5 {
    wat.write_string(
      " i32.const 7 local.tee 0 drop i32.const 8 local.tee 0 drop",
    )
  } else if mode == 6 {
    wat.write_string(" i32.const 7 local.set 0")
  } else if mode == 7 {
    wat.write_string(
      " i32.const 7 local.set 0 local.get 0 local.set 1 local.get 0 local.set 2",
    )
  } else if mode == 1 {
    wat.write_string(" i32.const 8 local.tee 1 drop")
    // The prior tee is 65 instructions before the independent root tee.
    for _ in 0..<62 {
      wat.write_string(" nop")
    }
    wat.write_string(" i32.const 7 local.tee 0 drop")
  } else if mode == 2 {
    wat.write_string(" i32.const 7 local.tee 1")
    // This carried source is exactly at the held-tee search boundary.
    for _ in 0..<63 {
      wat.write_string(" nop")
    }
    wat.write_string(" local.tee 0 drop")
  } else {
    wat.write_string(" i32.const 7 local.set 1 local.get 1 local.tee 0 drop")
  }
  for index in 1..<201 {
    if index != copy &&
      (mode != 7 || index > 2) &&
      (mode == 0 || mode >= 4 || index != 1) {
      wat.write_string(" i32.const \{index} local.set \{index}")
    }
  }
  for _ in 0..<2 {
    for index in 0..<201 {
      if index != copy && (mode < 4 || index != 0) && (mode != 7 || index > 2) {
        wat.write_string(" local.get \{index} call $consume")
      }
    }
  }
  wat.write_string(" local.get 200 local.set \{copy}")
  for _ in 0..<16 {
    wat.write_string(" local.get \{copy} call $consume")
  }
  wat.write_string("))")
  pass_test_module_from_wat(wat.to_string()).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("root")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("carried")),
              @lib.NameAssoc::new(
                copy.to_uint(),
                @lib.Name::from_string("copy"),
              ),
              @lib.NameAssoc::new(200U, @lib.Name::from_string("source")),
            ]),
          ),
        ]),
      ),
    ),
  )
}

///|
fn dae2_tee_marker_precision_output(
  input : @lib.Module,
  func : @lib.Func,
  indices : Array[Int32],
) -> @lib.Module {
  let output = input.with_code_sec(@lib.CodeSec::new([func]))
  match rl_rewrite_name_sec(input.name_sec, 1, [Some(indices)]) {
    Some(names) => output.with_name_sec(names)
    None => output.without_name_sec()
  }
}

///|
fn dae2_tee_marker_precision_check(mode : Int32) -> Unit raise {
  let input = dae2_tee_marker_precision_fixture(mode)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let (actual, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    [],
    stack_effects=Some(fn(instr) {
      dae2_capture_stack_effect(instr, input, context)
    }),
    propagate_parameter_aliases=true,
    // Keep the compactor's exact index order visible in this width proof.
    reorder_body_locals=false,
  )
  let retired = if mode < 2 { 128 } else { 0 }
  let expected_indices = Array::makei(201, fn(index) {
    if mode == 7 {
      if index <= 2 {
        -1
      } else {
        index - 3
      }
    } else if index == retired {
      -1
    } else if index > retired {
      index - 1
    } else {
      index
    }
  })
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected : Array[@lib.Instruction] = []
  for instr in body {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(index)) if mode == 7 &&
        (index == 1U || index == 2U) => {
        assert_true(expected.last() is Some(@lib.LocalGet(@lib.LocalIdx(0U))))
        ignore(expected.pop())
        continue
      }
      @lib.LocalSet(@lib.LocalIdx(128U)) if mode < 2 => {
        assert_true(expected.last() is Some(@lib.LocalGet(@lib.LocalIdx(200U))))
        ignore(expected.pop())
        continue
      }
      @lib.LocalGet(@lib.LocalIdx(128U)) if mode < 2 => {
        expected.push(@lib.Instruction::local_get(@lib.LocalIdx::new(200U)))
        continue
      }
      @lib.LocalTee(@lib.LocalIdx(0U)) if mode >= 2 => continue
      @lib.LocalGet(@lib.LocalIdx(0U)) if mode >= 2 && mode != 7 => {
        expected.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
        continue
      }
      _ => expected.push(instr)
    }
  }
  let reference = dae2_tee_marker_precision_output(
    input,
    @lib.Func::new(
      @lib.Locals::from_types(
        Array::make(if mode == 7 { 198 } else { 200 }, @lib.ValType::i32()),
      ),
      @lib.Expr::new(pass_lower_remap_locals(expected, expected_indices)),
    ),
    expected_indices,
  )
  let output = dae2_tee_marker_precision_output(input, actual, indices)
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let actual_bytes = @binary.encode_module(output).unwrap()
  let expected_bytes = @binary.encode_module(reference).unwrap()
  assert_true(
    actual_bytes.length() <= expected_bytes.length(),
    msg="actual=\{actual_bytes.length()} exact-reference=\{expected_bytes.length()}",
  )
  assert_eq(output.code_sec, reference.code_sec)
  assert_eq(output.name_sec, reference.name_sec)
  assert_eq(actual_bytes, expected_bytes)
  assert_eq(indices, expected_indices)
  assert_true(@binary.encode_module(output).unwrap().length() < saved.length())
}

///|
test "DAE2 width bounds keep nonalias tee roots before profitable wide copies" {
  for mode in [0, 1] {
    dae2_tee_marker_precision_check(mode)
  }
}

///|
test "DAE2 width bounds still exclude carried tees at distance64, adjacent aliases, and unread roots" {
  for mode in [2, 3, 4] {
    dae2_tee_marker_precision_check(mode)
  }
}

///|
test "DAE2 width bounds exclude unread ordinary stores and multiwriter tees from guaranteed survivors" {
  for mode in [5, 6] {
    dae2_tee_marker_precision_check(mode)
  }
}

///|
test "DAE2 width bounds exclude roots whose reads vanish with two unused set copies" {
  dae2_tee_marker_precision_check(7)
}
