///|
fn sl_zero_read_identity_bench(
  it : @bench.T,
  width : Int,
  nested : Bool,
  active : Bool,
  reference : Bool,
) -> Unit {
  let mut body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  }
  if !active {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  if nested {
    for _ in 0..<4 {
      body = [
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
      ]
    }
  }
  let counts = [if active { 0 } else { 1 }]
  let expected = sl_zero_read_before_identity(body, counts)
  let actual = run_hot_pipeline_simplify_locals_lowered_drop_zero_read_sets_body(
    body, counts,
  )
  if actual != expected {
    abort("zero-read cleanup changed output")
  }
  let before = body.copy()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_zero_read_before_identity(body, counts)
      } else {
        run_hot_pipeline_simplify_locals_lowered_drop_zero_read_sets_body(
          body, counts,
        )
      },
    )
  })
  if body != before {
    abort("zero-read cleanup changed source")
  }
}

///|
test "bench SL zero-read width=4 flat unchanged reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, false, false, true)
}

///|
test "bench SL zero-read width=4 flat unchanged borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, false, false, false)
}

///|
test "bench SL zero-read width=4 flat active reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, false, true, true)
}

///|
test "bench SL zero-read width=4 flat active borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, false, true, false)
}

///|
test "bench SL zero-read width=4 nested unchanged reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, true, false, true)
}

///|
test "bench SL zero-read width=4 nested unchanged borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, true, false, false)
}

///|
test "bench SL zero-read width=4 nested active reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, true, true, true)
}

///|
test "bench SL zero-read width=4 nested active borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4, true, true, false)
}

///|
test "bench SL zero-read width=128 flat unchanged reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, false, false, true)
}

///|
test "bench SL zero-read width=128 flat unchanged borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, false, false, false)
}

///|
test "bench SL zero-read width=128 flat active reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, false, true, true)
}

///|
test "bench SL zero-read width=128 flat active borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, false, true, false)
}

///|
test "bench SL zero-read width=128 nested unchanged reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, true, false, true)
}

///|
test "bench SL zero-read width=128 nested unchanged borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, true, false, false)
}

///|
test "bench SL zero-read width=128 nested active reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, true, true, true)
}

///|
test "bench SL zero-read width=128 nested active borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 128, true, true, false)
}

///|
test "bench SL zero-read width=4096 flat unchanged reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, false, false, true)
}

///|
test "bench SL zero-read width=4096 flat unchanged borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, false, false, false)
}

///|
test "bench SL zero-read width=4096 flat active reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, false, true, true)
}

///|
test "bench SL zero-read width=4096 flat active borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, false, true, false)
}

///|
test "bench SL zero-read width=4096 nested unchanged reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, true, false, true)
}

///|
test "bench SL zero-read width=4096 nested unchanged borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, true, false, false)
}

///|
test "bench SL zero-read width=4096 nested active reference" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, true, true, true)
}

///|
test "bench SL zero-read width=4096 nested active borrow" (it : @bench.T) {
  sl_zero_read_identity_bench(it, 4096, true, true, false)
}
