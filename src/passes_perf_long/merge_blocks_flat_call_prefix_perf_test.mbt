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

///|
fn mb_flat_call_many_functions_fixture(functions : Int) -> @lib.Module {
  let base = mb_flat_call_prefix_fixture(1)
  let callee = match base.code_sec {
    Some(@lib.CodeSec([callee, _])) => callee
    _ => abort("MergeBlocks many-function fixture lacks its callee")
  }
  let caller = match base.code_sec {
    Some(@lib.CodeSec([_, caller])) => caller
    _ => abort("MergeBlocks many-function fixture lacks its caller")
  }
  let type_idxs : Array[@lib.TypeIdx] = [@lib.TypeIdx::new(1U)]
  let funcs : Array[@lib.Func] = [callee]
  for _ in 0..<functions {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(caller)
  }
  base
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn mb_flat_call_many_functions_bench(it : @bench.T, functions : Int) -> Unit {
  let fixture = mb_flat_call_many_functions_fixture(functions)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  let output = match
    @passes.run_hot_pipeline(fixture, options, ["merge-blocks"]) {
    Ok(output) => output
    Err(err) => abort("MergeBlocks many-function fixture failed: \{err}")
  }
  if output == fixture {
    abort("MergeBlocks many-function fixture did not rewrite")
  }
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["merge-blocks"]) {
      Ok(output) => it.keep(output)
      Err(err) => abort("MergeBlocks many-function benchmark failed: \{err}")
    }
  })
}

///|
test "bench merge-blocks flat calls functions=256" (it : @bench.T) {
  mb_flat_call_many_functions_bench(it, 256)
}

///|
test "bench merge-blocks flat calls functions=512" (it : @bench.T) {
  mb_flat_call_many_functions_bench(it, 512)
}
