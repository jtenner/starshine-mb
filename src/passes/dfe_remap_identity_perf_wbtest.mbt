///|
fn dfe_remap_identity_bench(
  it : @bench.T,
  width : Int,
  nested : Bool,
  pattern : Int,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for index = 0; index < width; index = index + 1 {
    let leaf = if pattern == 2 || (pattern == 1 && index + 1 == width) {
      @lib.Instruction::call(@lib.FuncIdx::new(1U))
    } else {
      @lib.Instruction::nop()
    }
    body.push(
      if nested {
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([leaf]))
      } else {
        leaf
      },
    )
  }
  let func = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  let remap = [0U, 0U]
  let before = dfe_remap_before_func(func, remap)
  let after = dfe_rewrite_func_func_idxs(func, remap)
  if before != after {
    abort("DFE remap changed instruction order or call targets")
  }
  if pattern == 0 && !physical_equal(func, after) {
    abort("DFE unchanged remap rebuilt its function")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dfe_remap_before_func(func, remap)
      } else {
        dfe_rewrite_func_func_idxs(func, remap)
      },
    )
  })
  let @lib.Func(_, @lib.Expr(original_body)) = func
  if !physical_equal(body, original_body) {
    abort("DFE remap modified its input storage")
  }
}

///|
test "bench DFE remap width=4 flat unchanged reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, false, 0, true)
}

///|
test "bench DFE remap width=4 flat unchanged lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, false, 0, false)
}

///|
test "bench DFE remap width=4 flat last-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, false, 1, true)
}

///|
test "bench DFE remap width=4 flat last-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, false, 1, false)
}

///|
test "bench DFE remap width=4 flat dense-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, false, 2, true)
}

///|
test "bench DFE remap width=4 flat dense-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, false, 2, false)
}

///|
test "bench DFE remap width=4 nested unchanged reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, true, 0, true)
}

///|
test "bench DFE remap width=4 nested unchanged lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, true, 0, false)
}

///|
test "bench DFE remap width=4 nested last-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, true, 1, true)
}

///|
test "bench DFE remap width=4 nested last-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, true, 1, false)
}

///|
test "bench DFE remap width=4 nested dense-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, true, 2, true)
}

///|
test "bench DFE remap width=4 nested dense-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4, true, 2, false)
}

///|
test "bench DFE remap width=128 flat unchanged reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, false, 0, true)
}

///|
test "bench DFE remap width=128 flat unchanged lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, false, 0, false)
}

///|
test "bench DFE remap width=128 flat last-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, false, 1, true)
}

///|
test "bench DFE remap width=128 flat last-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, false, 1, false)
}

///|
test "bench DFE remap width=128 flat dense-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, false, 2, true)
}

///|
test "bench DFE remap width=128 flat dense-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, false, 2, false)
}

///|
test "bench DFE remap width=128 nested unchanged reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, true, 0, true)
}

///|
test "bench DFE remap width=128 nested unchanged lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, true, 0, false)
}

///|
test "bench DFE remap width=128 nested last-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, true, 1, true)
}

///|
test "bench DFE remap width=128 nested last-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, true, 1, false)
}

///|
test "bench DFE remap width=128 nested dense-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, true, 2, true)
}

///|
test "bench DFE remap width=128 nested dense-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 128, true, 2, false)
}

///|
test "bench DFE remap width=4096 flat unchanged reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, false, 0, true)
}

///|
test "bench DFE remap width=4096 flat unchanged lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, false, 0, false)
}

///|
test "bench DFE remap width=4096 flat last-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, false, 1, true)
}

///|
test "bench DFE remap width=4096 flat last-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, false, 1, false)
}

///|
test "bench DFE remap width=4096 flat dense-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, false, 2, true)
}

///|
test "bench DFE remap width=4096 flat dense-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, false, 2, false)
}

///|
test "bench DFE remap width=4096 nested unchanged reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, true, 0, true)
}

///|
test "bench DFE remap width=4096 nested unchanged lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, true, 0, false)
}

///|
test "bench DFE remap width=4096 nested last-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, true, 1, true)
}

///|
test "bench DFE remap width=4096 nested last-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, true, 1, false)
}

///|
test "bench DFE remap width=4096 nested dense-change reference" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, true, 2, true)
}

///|
test "bench DFE remap width=4096 nested dense-change lazy" (it : @bench.T) {
  dfe_remap_identity_bench(it, 4096, true, 2, false)
}
