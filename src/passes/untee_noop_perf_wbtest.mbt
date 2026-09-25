///|
fn untee_noop_perf_fixture(function_count : Int, sparse : Bool) -> @lib.Module {
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let unchanged = Array::make(64, @lib.Instruction::nop())
  let changed = Array::make(60, @lib.Instruction::nop())
  changed.push(@lib.Instruction::i32_const(@lib.I32(7)))
  changed.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(0U)))
  changed.push(@lib.Instruction::drop())
  for idx in 0..<function_count {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(
          if sparse && idx == function_count - 1 {
            changed
          } else {
            unchanged
          },
        ),
      ),
    )
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
fn untee_noop_perf_bench(it : @bench.T, count : Int, sparse : Bool) -> Unit {
  let fixture = untee_noop_perf_fixture(count, sparse)
  let result = untee_run_module_pass(fixture)
  if (result == fixture) == sparse {
    abort("untee benchmark fixture has wrong rewrite state")
  }
  it.bench(fn() { it.keep(untee_run_module_pass(fixture)) })
}

///|
test "bench untee no-op funcs=256" (it : @bench.T) {
  untee_noop_perf_bench(it, 256, false)
}

///|
test "bench untee no-op funcs=512" (it : @bench.T) {
  untee_noop_perf_bench(it, 512, false)
}

///|
test "bench untee sparse funcs=256" (it : @bench.T) {
  untee_noop_perf_bench(it, 256, true)
}
