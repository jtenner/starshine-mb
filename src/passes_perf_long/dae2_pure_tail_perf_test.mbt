///|
fn perf_long_dae2_pure_tail(count : Int) -> @lib.Module {
  let prototype = perf_long_dae2_joined_readers(1)
  let funcs = prototype.code_sec.unwrap().0
  let (locals, body) = match funcs[0] {
    @lib.Func(locals, @lib.Expr(body)) => (locals, body.copy())
  }
  ignore(body.pop())
  for _ in 0..<32 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(2U)))
  }
  fn append_sum(start : Int, length : Int) -> Unit {
    if length == 1 {
      body.push(@lib.Instruction::i32_const(@lib.I32(start % 8)))
    } else {
      let left = length / 2
      append_sum(start, left)
      append_sum(start + left, length - left)
      body.push(@lib.Instruction::i32_add())
    }
  }
  append_sum(0, count)
  body.push(@lib.Instruction::drop())
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  let types = prototype.type_sec.unwrap().0.copy()
  types.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  let exports = prototype.export_sec.unwrap().0.copy()
  exports.push(
    @lib.Export::new(
      @lib.Name::from_string("ticks"),
      @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
    ),
  )
  prototype
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(
    @lib.FuncSec::new([
      @lib.TypeIdx::new(0U),
      @lib.TypeIdx::new(1U),
      @lib.TypeIdx::new(2U),
    ]),
  )
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(locals, @lib.Expr::new(body)),
      funcs[1],
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_export_sec(@lib.ExportSec::new(exports))
}

///|
test "DAE2 pure-tail fixture actively removes its unused argument" {
  let fixture = perf_long_dae2_pure_tail(8)
  for pass in ["dae2", "dae2-optimizing"] {
    let output = opportunity_run(fixture, pass, true)
    assert_eq(perf_long_dae2_joined_params(output), [@lib.ValType::i32()])
    assert_eq(perf_long_dae2_joined_params(fixture), [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ])
  }
}

///|
fn perf_long_dae2_pure_tail_bench(
  it : @bench.T,
  count : Int,
  pass : String,
) -> Unit {
  // Fewer than 64 statement roots exercise the direct dependency scan. A
  // balanced pure tail avoids conflating repeated traversal with deep stacks.
  let fixture = perf_long_dae2_pure_tail(count)
  let output = opportunity_run(fixture, pass, true)
  if perf_long_dae2_joined_params(output) != [@lib.ValType::i32()] {
    abort("pure-tail benchmark failed to eliminate its unused argument")
  }
  it.bench(fn() { it.keep(opportunity_run(fixture, pass, false)) })
}

///|
test "bench dae2 pure tail leaves=512" (it : @bench.T) {
  perf_long_dae2_pure_tail_bench(it, 512, "dae2")
}

///|
test "bench dae2-optimizing pure tail leaves=512" (it : @bench.T) {
  perf_long_dae2_pure_tail_bench(it, 512, "dae2-optimizing")
}

///|
test "bench dae2 pure tail leaves=8192" (it : @bench.T) {
  perf_long_dae2_pure_tail_bench(it, 8192, "dae2")
}

///|
test "bench dae2-optimizing pure tail leaves=8192" (it : @bench.T) {
  perf_long_dae2_pure_tail_bench(it, 8192, "dae2-optimizing")
}
