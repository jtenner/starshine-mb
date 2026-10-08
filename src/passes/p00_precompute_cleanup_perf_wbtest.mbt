///|
fn p00_precompute_cleanup_fixture(width : Int) -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"value\" (func (result i32))) (func))",
  )
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
    )
    body.push(@lib.Instruction::drop())
  }
  input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn p00_precompute_cleanup_batch(input : @lib.Module) -> @ir.HotFunc {
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let labels = pass_compute_label_used(func)
  let counts = @ir.hot_node_use_counts_build(func)
  let cleanup = PrecomputeTransparentBlockCleanup::new()
  for slot in 0..<@ir.hot_root_count(func) {
    if !precompute_try_inline_transparent_value_block_child(
        ctx,
        func,
        @ir.hot_root_get(func, slot),
        labels,
        counts,
        cleanup=Some(cleanup),
      ) {
      abort("precompute cleanup fixture did not remove its transparent holder")
    }
  }
  precompute_finish_transparent_block_cleanup(func, cleanup)
  func
}

///|
fn p00_precompute_cleanup_bench(it : @bench.T, width : Int) -> Unit {
  let input = p00_precompute_cleanup_fixture(width)
  @validate.validate_module(input).unwrap()
  let func = p00_precompute_cleanup_batch(input)
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  let lowered = @ir.hot_lower_func(func)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  it.bench(fn() { it.keep(p00_precompute_cleanup_batch(input)) })
}

///|
#skip
test "bench precompute transparent cleanup width=1" (it : @bench.T) {
  p00_precompute_cleanup_bench(it, 1)
}

///|
#skip
test "bench precompute transparent cleanup width=128" (it : @bench.T) {
  p00_precompute_cleanup_bench(it, 128)
}

///|
#skip
test "bench precompute transparent cleanup width=1024" (it : @bench.T) {
  p00_precompute_cleanup_bench(it, 1024)
}
