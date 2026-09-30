///|
fn sl_terminal_bench(
  it : @bench.T,
  width : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let (env, replacement) = sl_terminal_fixture("i32", "i32.const 7")
  let body : Array[@lib.Instruction] = []
  if shape == 2 {
    body.push(replacement)
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  }
  for _ in 0..<width {
    body.push(@lib.Instruction::nop())
  }
  if shape == 1 {
    body.push(replacement)
    body.push(@lib.Instruction::drop())
  } else {
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new(if shape == 3 { 1U } else { 0U }),
      ),
    )
  }
  let saved = body.copy()
  let sources = [1]
  ignore(
    @validate.Typecheck::typecheck(
      @lib.Expr::new(body),
      @validate.make_state(env, []),
    ).unwrap(),
  )
  let actual = run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
    body, 0, replacement, sources, env,
  )
  assert_eq(
    actual,
    sl_terminal_reference_terminal_value_suffix(
      body, 0, replacement, sources, env,
    ),
  )
  assert_eq(actual is Some(_), shape == 0)
  match actual {
    Some((output, count)) => {
      assert_eq(count, body.length())
      ignore(
        @validate.Typecheck::typecheck(
          @lib.Expr::new(output),
          @validate.make_state(env, []),
        ).unwrap(),
      )
    }
    None => ()
  }
  it.bench(fn() {
    it.keep(
      if reference {
        sl_terminal_reference_terminal_value_suffix(
          body, 0, replacement, sources, env,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_terminal_value_suffix(
          body, 0, replacement, sources, env,
        )
      },
    )
  })
  assert_eq(body, saved)
}

///|
test "bench terminal ranges 8 accepted original" (it : @bench.T) {
  sl_terminal_bench(it, 8, 0, true)
}

///|
test "bench terminal ranges 8 accepted ranged" (it : @bench.T) {
  sl_terminal_bench(it, 8, 0, false)
}

///|
test "bench terminal ranges 8 final drop original" (it : @bench.T) {
  sl_terminal_bench(it, 8, 1, true)
}

///|
test "bench terminal ranges 8 final drop ranged" (it : @bench.T) {
  sl_terminal_bench(it, 8, 1, false)
}

///|
test "bench terminal ranges 8 early source write original" (it : @bench.T) {
  sl_terminal_bench(it, 8, 2, true)
}

///|
test "bench terminal ranges 8 early source write ranged" (it : @bench.T) {
  sl_terminal_bench(it, 8, 2, false)
}

///|
test "bench terminal ranges 8 wrong final local original" (it : @bench.T) {
  sl_terminal_bench(it, 8, 3, true)
}

///|
test "bench terminal ranges 8 wrong final local ranged" (it : @bench.T) {
  sl_terminal_bench(it, 8, 3, false)
}

///|
test "bench terminal ranges 512 accepted original" (it : @bench.T) {
  sl_terminal_bench(it, 512, 0, true)
}

///|
test "bench terminal ranges 512 accepted ranged" (it : @bench.T) {
  sl_terminal_bench(it, 512, 0, false)
}

///|
test "bench terminal ranges 512 final drop original" (it : @bench.T) {
  sl_terminal_bench(it, 512, 1, true)
}

///|
test "bench terminal ranges 512 final drop ranged" (it : @bench.T) {
  sl_terminal_bench(it, 512, 1, false)
}

///|
test "bench terminal ranges 512 early source write original" (it : @bench.T) {
  sl_terminal_bench(it, 512, 2, true)
}

///|
test "bench terminal ranges 512 early source write ranged" (it : @bench.T) {
  sl_terminal_bench(it, 512, 2, false)
}

///|
test "bench terminal ranges 512 wrong final local original" (it : @bench.T) {
  sl_terminal_bench(it, 512, 3, true)
}

///|
test "bench terminal ranges 512 wrong final local ranged" (it : @bench.T) {
  sl_terminal_bench(it, 512, 3, false)
}

///|
test "bench terminal ranges 4096 accepted original" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 0, true)
}

///|
test "bench terminal ranges 4096 accepted ranged" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 0, false)
}

///|
test "bench terminal ranges 4096 final drop original" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 1, true)
}

///|
test "bench terminal ranges 4096 final drop ranged" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 1, false)
}

///|
test "bench terminal ranges 4096 early source write original" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 2, true)
}

///|
test "bench terminal ranges 4096 early source write ranged" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 2, false)
}

///|
test "bench terminal ranges 4096 wrong final local original" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 3, true)
}

///|
test "bench terminal ranges 4096 wrong final local ranged" (it : @bench.T) {
  sl_terminal_bench(it, 4096, 3, false)
}
