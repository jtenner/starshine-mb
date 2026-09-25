///|
fn or_throw_chain_fixture(count : Int) -> Array[@lib.Func] {
  let funcs : Array[@lib.Func] = []
  for idx in 0..<count {
    let callee = if idx == count - 1 { 0 } else { idx + 2 }
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(callee.to_uint())),
        ]),
      ),
    )
  }
  funcs
}

///|
fn or_throw_chain_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = or_throw_chain_fixture(count)
  let result = or_collect_throwing_funcs(fixture, 1, count + 1)
  for throws in result {
    if !throws {
      abort("OnceReduction throw-chain fixture did not propagate")
    }
  }
  it.bench(fn() { it.keep(or_collect_throwing_funcs(fixture, 1, count + 1)) })
}

///|
fn or_no_throw_bench(it : @bench.T, count : Int) -> Unit {
  let funcs : Array[@lib.Func] = []
  for _ in 0..<count {
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    )
  }
  let result = or_collect_throwing_funcs(funcs, 0, count)
  for throws in result {
    if throws {
      abort("OnceReduction no-throw fixture became throwing")
    }
  }
  it.bench(fn() { it.keep(or_collect_throwing_funcs(funcs, 0, count)) })
}

///|
test "OnceReduction throw summary follows nested direct calls" {
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
      ]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    ),
  ]
  assert_eq(or_collect_throwing_funcs(funcs, 1, 3), [true, true, true])
}

///|
test "OnceReduction throw summary leaves a closed nonthrowing cycle clear" {
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    ),
  ]
  assert_eq(or_collect_throwing_funcs(funcs, 0, 2), [false, false])
}

///|
test "OnceReduction throw summary propagates an out-of-range callee" {
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(99U))]),
    ),
  ]
  assert_eq(or_collect_throwing_funcs(funcs, 0, 2), [true, true])
}

///|
test "bench OnceReduction reverse throw chain count=128" (it : @bench.T) {
  or_throw_chain_bench(it, 128)
}

///|
test "bench OnceReduction reverse throw chain count=256" (it : @bench.T) {
  or_throw_chain_bench(it, 256)
}

///|
test "bench OnceReduction no-throw functions count=256" (it : @bench.T) {
  or_no_throw_bench(it, 256)
}
