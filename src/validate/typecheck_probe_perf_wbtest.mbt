///|
fn typecheck_probe_bench(it : @bench.T, width : Int, invalid : Bool) -> Unit {
  let body : Array[Instruction] = []
  for _ in 0..<width {
    body.push(Instruction::nop())
  }
  if invalid {
    body.push(Instruction::i32_add())
  } else {
    body.push(Instruction::i32_const(@lib.I32::new(7)))
    body.push(Instruction::drop())
  }
  let expr = Expr::new([Instruction::block(BlockType::void_(), Expr::new(body))])
  let env = Env::new()
  it.bench(fn() {
    let result = typecheck_expr_for_probe(expr, make_state_owned(env, []))
    match result {
      Ok(state) => it.keep(state.stack.length())
      Err(error) => it.keep(error.length())
    }
  })
}

///|
test "bench expression probe valid width=1" (it : @bench.T) {
  typecheck_probe_bench(it, 1, false)
}

///|
test "bench expression probe valid width=1024" (it : @bench.T) {
  typecheck_probe_bench(it, 1024, false)
}

///|
test "bench expression probe failed width=1" (it : @bench.T) {
  typecheck_probe_bench(it, 1, true)
}

///|
test "bench expression probe failed width=64" (it : @bench.T) {
  typecheck_probe_bench(it, 64, true)
}

///|
test "bench expression probe failed width=1024" (it : @bench.T) {
  typecheck_probe_bench(it, 1024, true)
}
