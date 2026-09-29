///|
fn sl_value_suffix_bench(
  it : @bench.T,
  width : Int,
  kind : Int,
  reference : Bool,
) -> Unit {
  let body = if kind == 0 {
    sl_value_suffix_fixture(width)
  } else {
    let body : Array[@lib.Instruction] = []
    for _ in 0..<width {
      body.push(@lib.Instruction::i32_const(@lib.I32(1)))
      body.push(@lib.Instruction::drop())
    }
    if kind == 2 {
      body.push(
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
        ),
      )
    }
    body
  }
  let env = @validate.Env::new()
  let expected = sl_value_suffix_reference(body, 1, env)
  if run_hot_pipeline_raw_simplify_locals_take_value_suffix(body, 1, env) !=
    expected {
    abort("suffix precheck changed split")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        sl_value_suffix_reference(body, 1, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_take_value_suffix(body, 1, env)
      },
    )
  })
}

///|
test "bench value suffix width=4 chain reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 4, 0, true)
}

///|
test "bench value suffix width=4 chain prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 4, 0, false)
}

///|
test "bench value suffix width=4 empty reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 4, 1, true)
}

///|
test "bench value suffix width=4 empty prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 4, 1, false)
}

///|
test "bench value suffix width=4 nested reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 4, 2, true)
}

///|
test "bench value suffix width=4 nested prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 4, 2, false)
}

///|
test "bench value suffix width=32 chain reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 32, 0, true)
}

///|
test "bench value suffix width=32 chain prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 32, 0, false)
}

///|
test "bench value suffix width=32 empty reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 32, 1, true)
}

///|
test "bench value suffix width=32 empty prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 32, 1, false)
}

///|
test "bench value suffix width=32 nested reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 32, 2, true)
}

///|
test "bench value suffix width=32 nested prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 32, 2, false)
}

///|
test "bench value suffix width=256 chain reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 256, 0, true)
}

///|
test "bench value suffix width=256 chain prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 256, 0, false)
}

///|
test "bench value suffix width=256 empty reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 256, 1, true)
}

///|
test "bench value suffix width=256 empty prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 256, 1, false)
}

///|
test "bench value suffix width=256 nested reference" (it : @bench.T) {
  sl_value_suffix_bench(it, 256, 2, true)
}

///|
test "bench value suffix width=256 nested prechecked" (it : @bench.T) {
  sl_value_suffix_bench(it, 256, 2, false)
}
