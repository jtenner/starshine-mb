///|
test "lower stripping retains unchanged rows including explicitly preserved nop and tee options" {
  let local = @lib.LocalIdx::new(0U)
  let unchanged = [
    Instruction::i32_const(I32(7)),
    Instruction::local_set(local),
    Instruction::local_get(local),
    Instruction::drop(),
  ]
  for
    body in [
      [],
      unchanged,
      [Instruction::unreachable_()],
      [Instruction::block(@lib.BlockType::void_(), Expr::new(unchanged))],
    ] {
    let saved = body.copy()
    let output = hot_lower_impl_strip_redundant_nops_and_dead_local_tee_drops(
      body,
      HotLowerOptions::new(),
    )
    assert_eq(output, saved)
    assert_true(physical_equal(output, body))
  }
  let preserved = [
    Instruction::nop(),
    Instruction::i32_const(I32(7)),
    Instruction::local_tee(local),
    Instruction::drop(),
    Instruction::nop(),
  ]
  let options = HotLowerOptions::new(
    preserve_nontrailing_nops=true,
    preserve_trailing_nops=true,
    preserve_dead_local_tee_drops=true,
  )
  let output = hot_lower_impl_strip_redundant_nops_and_dead_local_tee_drops(
    preserved, options,
  )
  assert_eq(output, preserved)
  assert_true(physical_equal(output, preserved))
}

///|
test "lowered conditional arm storage stays independent of input and later lowering" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"tick\" (func $tick)) (global (export \"state\") (mut i32) (i32.const 0)) (func (export \"run\") (param i32) local.get 0 if i32.const 7 global.set 0 call $tick else i32.const 9 global.set 0 call $tick end))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let lifted = hot_lift_func(input, @lib.FuncIdx::new(1U))
  let first = hot_lower_func(lifted)
  let expected = @binary.encode_module(
    input.with_code_sec(@lib.CodeSec::new([first])),
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = first
  let mut changed = false
  for instr in body {
    match instr {
      @lib.If(_, then_, _) => {
        assert_true(then_.length() > 0)
        then_[0] = Instruction::nop()
        changed = true
      }
      _ => ()
    }
  }
  assert_true(changed)
  let second = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(lifted)]))
  @validate.validate_module(second).unwrap()
  assert_eq(@binary.encode_module(second).unwrap(), expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "lower cleanup storage remains owned across repeated scalar trap and GC lowering" {
  for
    wat in [
      "(module (import \"host\" \"tick\" (func $tick)) (global (export \"state\") (mut i32) (i32.const 0)) (func (export \"run\") (param i32) (local i32 i64) i32.const 17 global.set 0 call $tick block i32.const 7 local.tee 1 drop nop i64.const 9 local.tee 2 drop end call $tick))",
      "(module (import \"host\" \"tick\" (func $tick)) (global (export \"state\") (mut i32) (i32.const 0)) (func (export \"run\") (param i32) (local i32) i32.const 17 global.set 0 call $tick i32.const 1 local.get 0 i32.div_s local.tee 1 drop nop call $tick))",
      "(module (type $s (struct (field i32))) (import \"host\" \"tick\" (func $tick)) (global (export \"state\") (mut i32) (i32.const 0)) (func (export \"run\") (param i32) (local (ref null $s)) call $tick i32.const 7 struct.new $s local.tee 1 drop nop local.get 1 struct.get $s 0 global.set 0 call $tick))",
    ] {
    let input = @wast.wast_to_binary_module(wat).unwrap()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let lifted = hot_lift_func(input, @lib.FuncIdx::new(1U))
    let first = hot_lower_func(lifted)
    let output = input.with_code_sec(@lib.CodeSec::new([first]))
    @validate.validate_module(output).unwrap()
    let expected = @binary.encode_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = first
    assert_true(body.length() > 0)
    body[0] = Instruction::nop()
    let second = input.with_code_sec(
      @lib.CodeSec::new([hot_lower_func(lifted)]),
    )
    @validate.validate_module(second).unwrap()
    assert_eq(@binary.encode_module(second).unwrap(), expected)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "lower stripping owns changed rows and preserves exact nop tee and unreachable rewrites" {
  let local = @lib.LocalIdx::new(0U)
  for
    body in [
      [Instruction::nop()],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_tee(local),
        Instruction::drop(),
      ],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_tee(local),
        Instruction::drop(),
        Instruction::local_get(local),
        Instruction::drop(),
      ],
      [
        Instruction::unreachable_(),
        Instruction::nop(),
        Instruction::drop(),
        Instruction::block(@lib.BlockType::void_(), Expr::new([])),
        Instruction::i32_const(I32(7)),
        Instruction::drop(),
      ],
      [
        Instruction::nop(),
        Instruction::i32_const(I32(7)),
        Instruction::local_tee(local),
        Instruction::drop(),
        Instruction::nop(),
        Instruction::unreachable_(),
        Instruction::nop(),
        Instruction::drop(),
      ],
    ] {
    let saved = body.copy()
    for
      options in [
        HotLowerOptions::new(),
        HotLowerOptions::new(preserve_nontrailing_nops=true),
        HotLowerOptions::new(preserve_trailing_nops=true),
        HotLowerOptions::new(preserve_dead_local_tee_drops=true),
      ] {
      let output = hot_lower_impl_strip_redundant_nops_and_dead_local_tee_drops(
        body, options,
      )
      assert_eq(output, hot_lower_strip_storage_reference(body, options))
      assert_eq(body, saved)
      if output != body && output.length() > 0 {
        assert_false(physical_equal(output, body))
        output[0] = Instruction::nop()
        assert_eq(body, saved)
      }
    }
  }
}
