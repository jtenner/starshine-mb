///|
fn sl_balanced_tree_bench(
  it : @bench.T,
  width : Int,
  deep : Bool,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let fragment = match shape {
    0 => "call $produce call $consume"
    1 =>
      "call $produce local.set 0 local.get 0 call $consume local.get 0 call $consume"
    _ => "call $produce local.set 0 call $tick local.get 0 call $consume"
  }
  let (seed, env, leaf) = sl_balanced_range_fixture(fragment, "i32")
  let mut body : Array[@lib.Instruction] = []
  if deep {
    body = leaf
    for _ in 0..<width {
      body = [
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
      ]
    }
  } else {
    for _ in 0..<width {
      body.push(
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(leaf)),
      )
    }
  }
  let @lib.Func(locals, _) = seed.code_sec.unwrap().0[0]
  let input = seed.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets(
    body, env,
  )
  assert_eq(actual, sl_balanced_tree_reference(body, env))
  assert_eq(actual.1, if shape == 2 { if deep { 1 } else { width } } else { 0 })
  @validate.validate_module(
    seed.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_balanced_tree_reference(body, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets(
          body, env,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench balanced tree tiny no candidate original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 8, false, 0, true)
}

///|
test "bench balanced tree tiny no candidate ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 8, false, 0, false)
}

///|
test "bench balanced tree tiny blocked original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 8, false, 1, true)
}

///|
test "bench balanced tree tiny blocked ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 8, false, 1, false)
}

///|
test "bench balanced tree tiny active original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 8, false, 2, true)
}

///|
test "bench balanced tree tiny active ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 8, false, 2, false)
}

///|
test "bench balanced tree wide no candidate original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 128, false, 0, true)
}

///|
test "bench balanced tree wide no candidate ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 128, false, 0, false)
}

///|
test "bench balanced tree wide blocked original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 128, false, 1, true)
}

///|
test "bench balanced tree wide blocked ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 128, false, 1, false)
}

///|
test "bench balanced tree wide active original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 128, false, 2, true)
}

///|
test "bench balanced tree wide active ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 128, false, 2, false)
}

///|
test "bench balanced tree deep no candidate original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 32, true, 0, true)
}

///|
test "bench balanced tree deep no candidate ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 32, true, 0, false)
}

///|
test "bench balanced tree deep blocked original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 32, true, 1, true)
}

///|
test "bench balanced tree deep blocked ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 32, true, 1, false)
}

///|
test "bench balanced tree deep active original" (it : @bench.T) {
  sl_balanced_tree_bench(it, 32, true, 2, true)
}

///|
test "bench balanced tree deep active ranged" (it : @bench.T) {
  sl_balanced_tree_bench(it, 32, true, 2, false)
}
