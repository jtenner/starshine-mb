///|
// Retain the previous exhaustive search as an independent comparison oracle.
fn directize_arg_suffix_reference(
  out : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  info : DirectizeInfo,
) -> Int32? {
  let end = out.length() - 1
  let lower = directize_removable_suffix_lower_bound(out, end)
  for start = end; start >= lower; start = start - 1 {
    let suffix : Array[@lib.Instruction] = []
    for idx = start; idx < end; idx = idx + 1 {
      suffix.push(out[idx])
    }
    if directize_suffix_produces_params(suffix, params, info) {
      return Some(start)
    }
  }
  None
}

///|
fn directize_arg_suffix_info() -> DirectizeInfo {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 7)) (func $f (param i32 i64 f32 f64 funcref)) (elem declare func $f))",
  )
  directize_context_for_func(
    directize_build_info(input),
    @lib.FuncIdx::new(0U),
    @lib.Locals::empty(),
  ).info
}

///|
test "directize removable arguments keep exact arity and validator type matching" {
  let info = directize_arg_suffix_info()
  let producers = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i64_const(@lib.I64(2L)),
    @lib.Instruction::f32_const(@lib.F32(3.0)),
    @lib.Instruction::f64_const(@lib.F64(4.0)),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
  ]
  let params = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f32(),
    @lib.ValType::f64(),
    @lib.ValType::funcref(),
  ]
  for prefix in [0, 1, 8, 32] {
    let out = Array::make(prefix, @lib.Instruction::i64_const(@lib.I64(77L)))
    out.append(producers)
    out.push(@lib.Instruction::i32_const(@lib.I32(0)))
    let original = out.copy()
    assert_eq(
      directize_find_removable_arg_suffix(out, params, info),
      Some(prefix),
    )
    assert_eq(
      directize_find_removable_arg_suffix(out, [], info),
      Some(prefix + 5),
    )
    let wrong_types = params.copy()
    wrong_types[3] = @lib.ValType::f32()
    assert_eq(directize_find_removable_arg_suffix(out, wrong_types, info), None)
    for expected in [params, wrong_types, []] {
      assert_eq(
        directize_find_removable_arg_suffix(out, expected, info),
        directize_arg_suffix_reference(out, expected, info),
      )
    }
    assert_eq(out, original)
  }
  let reads = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
  ]
  assert_eq(directize_find_removable_arg_suffix(reads, params, info), Some(0))
  assert_eq(
    directize_find_removable_arg_suffix(reads, params, info),
    directize_arg_suffix_reference(reads, params, info),
  )
}

///|
test "directize removable suffix stops at effects and insufficient producers" {
  let info = directize_arg_suffix_info()
  for width in [1, 2, 8, 32] {
    let params = Array::make(width, @lib.ValType::i32())
    for trailing in [0, width - 1, width, width + 1] {
      let out = [
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
      ]
      for _ in 0..<trailing {
        out.push(@lib.Instruction::i32_const(@lib.I32(1)))
      }
      out.push(@lib.Instruction::i32_const(@lib.I32(0)))
      let expected = if trailing >= width {
        Some(2 + trailing - width)
      } else {
        None
      }
      assert_eq(
        directize_find_removable_arg_suffix(out, params, info),
        expected,
      )
      assert_eq(directize_arg_suffix_reference(out, params, info), expected)
      let replacement = out.copy()
      directize_push_trap_replacement(replacement, params, info)
      assert_eq(replacement[0], out[0])
      assert_eq(replacement[1], out[1])
      assert_eq(
        replacement[replacement.length() - 1],
        @lib.Instruction::unreachable_(),
      )
      if trailing >= width {
        assert_eq(replacement.length(), 3 + trailing - width)
      } else {
        assert_eq(replacement.length(), 3 + trailing + width)
        for i in (2 + trailing)..<(2 + trailing + width) {
          assert_eq(replacement[i], @lib.Instruction::drop())
        }
      }
    }
  }
}

///|
test "directize trap removes only its typed pure arguments and keeps stack prefix" {
  let input = pass_test_module_from_wat(
    "(module (type $call (func (param i32 i64 f32 f64 funcref))) (table 1 funcref) (func (result i64) i64.const 77 i32.const 1 i64.const 2 f32.const 3 f64.const 4 ref.null func i32.const 0 call_indirect (type $call)))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [
    @lib.Instruction::i64_const(@lib.I64(77L)),
    @lib.Instruction::unreachable_(),
  ])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(
    @validate.validate_module(
      @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
    )
    is Ok(_),
  )
}

///|
test "directize trap keeps argument call effects before dropping all arguments" {
  for tail in [false, true] {
    let opcode = if tail { "return_call_indirect" } else { "call_indirect" }
    let input = pass_test_module_from_wat(
      "(module (type $call (func (param i32 i64))) (global $g (mut i32) (i32.const 0)) (table 1 funcref) (func $effect (result i32) (global.set $g (i32.add (global.get $g) (i32.const 1))) (i32.const 9)) (func (call $effect) (i64.const 2) (i32.const 0) \{opcode} (type $call)))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "directize",
    ]).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    @debug.assert_eq(body, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::i64_const(@lib.I64(2L)),
      @lib.Instruction::drop(),
      @lib.Instruction::drop(),
      @lib.Instruction::unreachable_(),
    ])
    assert_eq(output.code_sec.unwrap().0[0], input.code_sec.unwrap().0[0])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "directize one constant candidate preserves surrounding dynamic calls and effects" {
  let source = StringBuilder()
  source.write_string(
    "(module (type $call (func (param i32))) (table 1 funcref) (func $target (param i32)) (elem (i32.const 0) $target) (func (param i32) ",
  )
  for index in 0..<33 {
    source.write_string("i32.const \{index} ")
    source.write_string(
      if index == 16 {
        "i32.const 0 "
      } else {
        "local.get 0 "
      },
    )
    source.write_string("call_indirect (type $call) ")
  }
  source.write_string("))")
  let input = pass_test_module_from_wat(source.to_string())
  let saved = @binary.encode_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]).unwrap()
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[1]
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[1]
  assert_eq(after.length(), before.length() - 1)
  assert_eq(after[48], @lib.Instruction::i32_const(@lib.I32(16)))
  assert_eq(after[49], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
  @debug.assert_eq(after[0:48].to_array(), before[0:48].to_array())
  @debug.assert_eq(after[50:].to_array(), before[51:].to_array())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
