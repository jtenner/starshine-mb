///|
fn dealign_noop_fixture(function_count : Int) -> @lib.Module {
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let body = Array::make(64, @lib.Instruction::nop())
  for _ in 0..<function_count {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dealign_noop_bench(it : @bench.T, function_count : Int) -> Unit {
  let fixture = dealign_noop_fixture(function_count)
  if dealign_run_module_pass(fixture) != fixture {
    abort("no-op dealign fixture changed")
  }
  it.bench(fn() { it.keep(dealign_run_module_pass(fixture)) })
}

///|
fn dealign_changed_fixture(function_count : Int, sparse : Bool) -> @lib.Module {
  let base = dealign_noop_fixture(function_count)
  let funcs : Array[@lib.Func] = []
  let changed_instrs : Array[@lib.Instruction] = []
  for _ in 0..<16 {
    changed_instrs.push(@lib.Instruction::i32_const(@lib.I32(0)))
    changed_instrs.push(
      @lib.Instruction::i32_load(@lib.MemArg::new(2U, None, 0UL)),
    )
    changed_instrs.push(@lib.Instruction::drop())
  }
  for idx in 0..<function_count {
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new(
          if !sparse || idx == function_count - 1 {
            changed_instrs
          } else {
            Array::make(48, @lib.Instruction::nop())
          },
        ),
      ),
    )
  }
  base
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dealign_changed_bench(
  it : @bench.T,
  function_count : Int,
  sparse : Bool,
) -> Unit {
  let fixture = dealign_changed_fixture(function_count, sparse)
  if dealign_run_module_pass(fixture) == fixture {
    abort("changed dealign fixture was not rewritten")
  }
  it.bench(fn() { it.keep(dealign_run_module_pass(fixture)) })
}

///|
test "Dealign no-op guard still rewrites nested unaligned loads" {
  let nested = fn(align : UInt) {
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_load(@lib.MemArg::new(align, None, 0UL)),
          @lib.Instruction::drop(),
        ]),
      ),
    ])
  }
  assert_true(dealign_expr_has_work(nested(2U)))
  assert_false(dealign_expr_has_work(nested(0U)))
  let fixture = dealign_noop_fixture(1)
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), nested(2U))]),
    )
  let rewritten = dealign_run_module_pass(fixture)
  assert_eq(
    rewritten.code_sec,
    Some(@lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), nested(0U))])),
  )
}

///|
test "bench dealign no-op funcs=256" (it : @bench.T) {
  dealign_noop_bench(it, 256)
}

///|
test "bench dealign no-op funcs=512" (it : @bench.T) {
  dealign_noop_bench(it, 512)
}

///|
test "bench dealign sparse changed funcs=256" (it : @bench.T) {
  dealign_changed_bench(it, 256, true)
}

///|
test "bench dealign dense changed funcs=256" (it : @bench.T) {
  dealign_changed_bench(it, 256, false)
}
