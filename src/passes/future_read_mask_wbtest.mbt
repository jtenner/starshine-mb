///|
test "adjacent cleanup preserves exact transforms with bounded future-read work" {
  let width = 32
  let locals = Array::make(width, "i32").join(" ")
  let captures = Array::makei(width, fn(local) {
    "i32.const 7 local.set \{local} local.get \{local} drop"
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (local \{locals}) \{captures}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let visits = [0]
  let actual = sl_cleanup_drop_dead_pairs_with_reads(
    body,
    SlCleanupReadSet::new([]),
    future_read_visits=Some(visits),
  )
  assert_eq(
    actual,
    sl_cleanup_future_reference(body, SlCleanupReadSet::new([])),
  )
  assert_eq(actual.length(), width * 2)
  for pair in 0..<width {
    assert_eq(actual[pair * 2], @lib.Instruction::i32_const(@lib.I32(7)))
    assert_eq(actual[pair * 2 + 1], @lib.Instruction::drop())
  }
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual))]),
    ),
  ).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(
    visits[0] <= body.length() * 12,
    msg="future-read work: \{visits[0]}",
  )
}

///|
test "future-read masks match direct queries through terminators siblings and legacy catches" {
  let fixtures = [
    "(module (func (param i32 i32) local.get 0 drop local.get 1 drop local.get 0 drop))",
    "(module (func (param i32 i32) local.get 0 drop return local.get 0 drop local.get 1 drop))",
    "(module (func (param i32 i32) local.get 0 drop block local.get 1 drop return local.get 0 drop end local.get 0 drop))",
    "(module (func (param i32 i32) local.get 0 drop local.get 0 if local.get 1 drop unreachable local.get 0 drop else local.get 0 drop end local.get 1 drop))",
    "(module (tag $e) (func (param i32 i32) local.get 0 drop (try (do local.get 1 drop throw $e local.get 0 drop) (catch $e local.get 0 drop return local.get 1 drop) (catch_all local.get 1 drop)) local.get 0 drop))",
    "(module (func (param i32 i32) local.get 0 drop loop local.get 1 drop br 0 local.get 0 drop end local.get 0 drop))",
    "(module (func (param i32 i32) local.get 0 local.tee 1 drop block local.get 1 drop end local.get 0 local.tee 1 drop))",
    "(module (type $t (struct (field i32))) (func (param (ref $t)) local.get 0 drop block local.get 0 drop end local.get 0 drop))",
  ]
  for wat in fixtures {
    let input = pass_test_module_from_wat(wat)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(local_types, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    let body = original.copy()
    for _ in 0..<32 {
      body.push(@lib.Instruction::nop())
    }
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(body))]),
      ),
    ).unwrap()
    for force in [false, true] {
      let mask = if force {
        Some(sl_cleanup_build_future_read_mask(body, None))
      } else {
        None
      }
      for idx in 0..<body.length() {
        let (local, start) = match body[idx] {
          @lib.LocalGet(@lib.LocalIdx(raw)) =>
            (raw.reinterpret_as_int(), idx + 1)
          @lib.LocalTee(@lib.LocalIdx(raw)) if idx + 1 < body.length() &&
            body[idx + 1] is @lib.Drop => (raw.reinterpret_as_int(), idx + 2)
          _ => continue
        }
        assert_eq(
          sl_cleanup_future_read_query(body, idx, start, local, mask, None),
          run_hot_pipeline_raw_instrs_have_later_local_read(body, start, local),
        )
      }
      if force {
        assert_true(mask is Some(_), msg="forced query did not publish a mask")
      }
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "cached future-read queries retain published facts and source instructions" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) local.get 0 drop))",
  )
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  let body = original.copy()
  for _ in 0..<32 {
    body.push(@lib.Instruction::nop())
  }
  let published = Some(sl_cleanup_build_future_read_mask(body, None))
  let held = published.unwrap()
  let snapshot = held.copy()
  let saved = @binary.encode_module(input).unwrap()
  assert_false(sl_cleanup_future_read_query(body, 0, 1, 0, published, None))
  assert_eq(held, snapshot)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "same-local root reads stay linear and dropped tees still receive suffix facts" {
  for tee in [false, true] {
    let width = 32
    let text = Array::make(
      width,
      if tee {
        "i32.const 7 local.tee 0 drop"
      } else {
        "i32.const 7 local.set 0 local.get 0 drop"
      },
    ).join(" ")
    let input = pass_test_module_from_wat("(module (func (local i32) \{text}))")
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let visits = [0]
    let actual = sl_cleanup_drop_dead_pairs_with_reads(
      body,
      SlCleanupReadSet::new([]),
      future_read_visits=Some(visits),
    )
    assert_eq(
      actual,
      sl_cleanup_future_reference(body, SlCleanupReadSet::new([])),
    )
    assert_true(
      visits[0] <= body.length() * (if tee { 12 } else { 2 }),
      msg="future-read work: \{visits[0]}",
    )
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
