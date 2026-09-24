///|
fn directize_suffix_boundary_fixture(prefix : Int) -> @lib.Module {
  let base = directize_perf_module(0, 0)
  let @lib.CodeSec(funcs) = base.code_sec.unwrap()
  let body : Array[@lib.Instruction] = []
  for _ in 0..<prefix {
    body.push(@lib.Instruction::nop())
  }
  body.push(@lib.Instruction::i32_const(@lib.I32(1)))
  body.push(@lib.Instruction::i32_const(@lib.I32(2)))
  body.push(@lib.Instruction::i32_add())
  body.push(@lib.Instruction::i32_const(@lib.I32(100)))
  body.push(
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(0U),
    ),
  )
  body.push(@lib.Instruction::drop())
  let next = funcs.copy()
  next[2] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  base.with_code_sec(@lib.CodeSec::new(next))
}

///|
fn directize_suffix_boundary_bench(it : @bench.T, prefix : Int) -> Unit {
  let fixture = directize_suffix_boundary_fixture(prefix)
  let expected = opportunity_run(fixture, "directize", true)
  if expected == fixture {
    abort("directize suffix fixture did not trigger")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["directize"]) {
      Ok(result) => it.keep(result)
      Err(err) => abort("directize suffix fixture failed: \{err}")
    }
  })
}

///|
test "bench directize blocked suffix prefix=256" (it : @bench.T) {
  directize_suffix_boundary_bench(it, 256)
}

///|
test "bench directize blocked suffix prefix=512" (it : @bench.T) {
  directize_suffix_boundary_bench(it, 512)
}
