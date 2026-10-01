///|
test "constant stores sink into first scalar read while preserving later observations" {
  for scalar in ["i32", "i64", "f32", "f64"] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"use\" (func $use (param \{scalar}))) (func (param \{scalar}) (result \{scalar}) (local i32) \{scalar}.const 5 local.set 0 i32.const 7 local.set 1 local.get 0 call $use local.get 0))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let (rewritten, count) = sl_sink_constant_stores_flat(body)
    assert_eq(count, 1)
    assert_eq(rewritten, [
      body[2],
      body[3],
      body[0],
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      body[5],
      body[6],
    ])
    let output = input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(rewritten))]),
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap().length(),
      saved.length() - 2,
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "guarded release cleanup sinks a constant without keeping a stale parameter snapshot" {
  let wat = "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32 i32) block (result i32) local.get 1 end local.set 3 i32.const 5 local.set 1 local.get 0 local.get 3 i32.ge_s local.set 4 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4))"
  let output = pass_test_run_pipeline(wat, ["dae2-optimizing"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  assert_eq(body[1], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_eq(body[2], @lib.Instruction::i32_ge_s())
  assert_true(
    body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U))),
  )
  assert_false(
    body.contains(@lib.Instruction::local_set(@lib.LocalIdx::new(1U))),
  )
}

///|
test "constant store sinking retains intentionally blocking traps throws and control" {
  for
    prefix in [
      "call $effect", "i32.const 1 i32.const 0 i32.div_s drop", "i32.const 0 i32.load drop",
      "f64.const 1e100 i32.trunc_f64_s drop", "block nop end", "unreachable",
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"effect\" (func $effect)) (memory 1) (func (param i32) (result i32) i32.const 5 local.set 0 \{prefix} local.get 0))",
    )
    @validate.validate_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let result = sl_sink_constant_stores_flat(body)
    assert_eq(result.1, 0)
    assert_true(physical_equal(result.0, body))
  }
}

///|
test "constant store sinking preserves clobbers repeated reads and independent siblings" {
  for
    tail in [
      "i32.const 9 local.set 0 local.get 0 local.get 0 i32.add", "i32.const 9 local.tee 0 local.get 0 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32) (result i32) i32.const 5 local.set 0 \{tail}))",
    )
    @validate.validate_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let (next, count) = sl_sink_constant_stores_flat(body)
    assert_eq(
      count,
      if tail.starts_with("i32.const 9 local.set") {
        1
      } else {
        0
      },
    )
    assert_eq(next[0], body[0])
    assert_eq(next[1], body[1])
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(next))]),
      ),
    ).unwrap()
  }
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 1 if i32.const 5 local.set 0 local.get 0 drop else i32.const 7 local.set 0 local.get 0 drop end local.get 0))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (next, count) = sl_sink_constant_stores(body)
  assert_eq(count, 2)
  assert_eq(next.last(), body.last())
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(next))]),
    ),
  ).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "constant store sinking visits wide pending rows and repeated barriers linearly" {
  for blocked in [false, true] {
    let body : Array[@lib.Instruction] = []
    for local in 0..<32 {
      body.push(@lib.Instruction::i32_const(@lib.I32(local + 1)))
      body.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())),
      )
    }
    if blocked {
      for _ in 0..<64 {
        body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
      }
    }
    for local in 0..<32 {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
    let saved = body.copy()
    let visits = [0]
    let (next, count) = sl_sink_constant_stores_flat(
      body,
      scan_visits=Some(visits),
    )
    assert_eq(count, if blocked { 0 } else { 32 })
    assert_eq(visits[0], body.length() * (if blocked { 1 } else { 2 }))
    assert_eq(
      next.filter(fn(instr) { instr is @lib.LocalTee(_) }).length(),
      count,
    )
    assert_eq(body, saved)
    if blocked {
      assert_true(physical_equal(next, body))
    }
  }
}
