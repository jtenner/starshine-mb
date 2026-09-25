///|
fn mb_flat_call_prefix_fixture(groups : Int) -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for idx in 0..<groups {
    body.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    body.push(@lib.Instruction::i32_const(@lib.I32(idx + 1)))
    body.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
    body.push(@lib.Instruction::i32_const(@lib.I32(idx + 2)))
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
        ),
      ),
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
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(1U), @lib.TypeIdx::new(0U)]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn mb_flat_call_prefix_bench(it : @bench.T, groups : Int) -> Unit {
  let fixture = mb_flat_call_prefix_fixture(groups)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  let output = match
    @passes.run_hot_pipeline(fixture, options, ["merge-blocks"]) {
    Ok(output) => output
    Err(err) => abort("MergeBlocks flat-call fixture failed: \{err}")
  }
  if output == fixture {
    abort("MergeBlocks flat-call fixture did not rewrite")
  }
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["merge-blocks"]) {
      Ok(output) => it.keep(output)
      Err(err) => abort("MergeBlocks flat-call benchmark failed: \{err}")
    }
  })
}

///|
test "bench merge-blocks flat call prefixes groups=128" (it : @bench.T) {
  mb_flat_call_prefix_bench(it, 128)
}

///|
test "bench merge-blocks flat call prefixes groups=256" (it : @bench.T) {
  mb_flat_call_prefix_bench(it, 256)
}
