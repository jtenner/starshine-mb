///|
test "pass review coalescing distinguishes exact floating constant bits" {
  let pairs = [
    (
      @lib.Instruction::f32_const(
        @lib.F32::new(Float::reinterpret_from_int(0x7fc00001)),
      ),
      @lib.Instruction::f32_const(
        @lib.F32::new(Float::reinterpret_from_int(0x7fc00002)),
      ),
    ),
    (
      @lib.Instruction::f64_const(
        @lib.F64::new(0x7ff8000000000001L.reinterpret_as_double()),
      ),
      @lib.Instruction::f64_const(
        @lib.F64::new(0x7ff8000000000002L.reinterpret_as_double()),
      ),
    ),
    (
      @lib.Instruction::f32_const(@lib.F32::new(0.0)),
      @lib.Instruction::f32_const(@lib.F32::new(-0.0)),
    ),
    (
      @lib.Instruction::f64_const(@lib.F64::new(0.0)),
      @lib.Instruction::f64_const(@lib.F64::new(-0.0)),
    ),
  ]
  for pair in pairs {
    let (left, right) = pair
    let interner = CLValueInterner::new()
    let first = cl_value_for_source(
      cl_simple_const_source(left).unwrap(),
      [],
      interner,
    )
    let second = cl_value_for_source(
      cl_simple_const_source(right).unwrap(),
      [],
      interner,
    )
    assert_true(
      first != second,
      msg="distinct float bits must not share a local value identity",
    )
    let actions : Array[CLAction] = [
      {
        kind: CLActionKind::Set,
        local_idx: 0,
        source: cl_simple_const_source(left).unwrap(),
      },
      {
        kind: CLActionKind::Set,
        local_idx: 1,
        source: cl_simple_const_source(right).unwrap(),
      },
      { kind: CLActionKind::Get, local_idx: 0, source: CLValueSource::Unique, },
      { kind: CLActionKind::Get, local_idx: 1, source: CLValueSource::Unique, },
    ]
    let ty = match left {
      @lib.F32Const(_) => @lib.ValType::f32()
      _ => @lib.ValType::f64()
    }
    let interference = cl_compute_interferences(
      actions,
      cl_compute_liveness(actions, 2),
      [ty, ty],
      0,
    )
    assert_true(
      cl_bit_matrix_get(interference, 0, 1),
      msg="distinct live float values require distinct slots",
    )
  }
}

///|
test "pass review coalescing keeps negative zero separate from default initialization" {
  for ty in [@lib.ValType::f32(), @lib.ValType::f64()] {
    let negative_zero = if ty == @lib.ValType::f32() {
      @lib.Instruction::f32_const(@lib.F32::new(-0.0))
    } else {
      @lib.Instruction::f64_const(@lib.F64::new(-0.0))
    }
    assert_false(
      cl_source_is_explicit_default(
        cl_simple_const_source(negative_zero).unwrap(),
        ty,
      ),
    )
    let positive_zero = if ty == @lib.ValType::f32() {
      @lib.Instruction::f32_const(@lib.F32::new(0.0))
    } else {
      @lib.Instruction::f64_const(@lib.F64::new(0.0))
    }
    assert_true(
      cl_source_is_explicit_default(
        cl_simple_const_source(positive_zero).unwrap(),
        ty,
      ),
    )
  }
}

///|
test "pass review inlining local compaction remaps names of retained locals" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i64 i32) local.get 2))",
  ).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("argument")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("unused")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("retained")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = inl_compact_unused_locals(input, [true])
  assert_eq(
    output.name_sec.unwrap().local_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("argument")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("retained")),
          ]),
        ),
      ]),
    ),
  )
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
}

///|
fn cl_review_eval_float_bits(mod_ : @lib.Module) -> Int64 {
  let @lib.Func(body_locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  let locals = Array::make(body_locals.length(), 0L)
  let stack : Array[Int64] = []
  for instr in body {
    match instr {
      @lib.F32Const(@lib.F32(value)) =>
        stack.push(value.reinterpret_as_int().to_int64())
      @lib.F64Const(@lib.F64(value)) => stack.push(value.reinterpret_as_int64())
      @lib.LocalGet(@lib.LocalIdx(idx)) => stack.push(locals[idx.to_int()])
      @lib.LocalSet(@lib.LocalIdx(idx)) =>
        locals[idx.to_int()] = stack.pop().unwrap()
      @lib.LocalTee(@lib.LocalIdx(idx)) =>
        locals[idx.to_int()] = stack[stack.length() - 1]
      @lib.I32ReinterpretF32 | @lib.I64ReinterpretF64 | @lib.Nop => ()
      @lib.I32Xor | @lib.I64Xor => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(left ^ right)
      }
      _ =>
        abort("unexpected instruction in flat floating-bit fixture: \{instr}")
    }
  }
  if stack.length() != 1 {
    abort("floating-bit fixture did not return one value")
  }
  stack[0]
}

///|
test "coalesce public pipeline preserves negative zero and distinct NaN payloads" {
  let cases : Array[(String, Int64)] = [
    (
      "(module (func (export \"run\") (result i32) (local f32 f32) f32.const -0 local.set 0 local.get 1 i32.reinterpret_f32 local.get 0 i32.reinterpret_f32 i32.xor))",
      -2147483648L,
    ),
    (
      "(module (func (export \"run\") (result i64) (local f64 f64) f64.const -0 local.set 0 local.get 1 i64.reinterpret_f64 local.get 0 i64.reinterpret_f64 i64.xor))",
      0x8000000000000000UL.reinterpret_as_int64(),
    ),
    (
      "(module (func (export \"run\") (result i32) (local f32 f32) f32.const nan:0x400001 local.set 0 f32.const nan:0x400002 local.set 1 local.get 0 i32.reinterpret_f32 local.get 1 i32.reinterpret_f32 i32.xor))",
      3L,
    ),
    (
      "(module (func (export \"run\") (result i64) (local f64 f64) f64.const nan:0x8000000000001 local.set 0 f64.const nan:0x8000000000002 local.set 1 local.get 0 i64.reinterpret_f64 local.get 1 i64.reinterpret_f64 i64.xor))",
      3L,
    ),
  ]
  for case in cases {
    let (wat, expected) = case
    let input = pass_test_module_from_wat(wat)
    assert_eq(cl_review_eval_float_bits(input), expected)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "coalesce-locals",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(cl_review_eval_float_bits(output), expected)
  }
}
