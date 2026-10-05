///|
fn pls_analysis_bench_fixture(
  count : Int,
) -> (@ir.HotFunc, @ir.HotUseDef, Array[PLSCandidateLoad]) {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<count {
    body.push(@lib.Instruction::i32_const(@lib.I32(0)))
    body.push(@lib.Instruction::i64_load32u(@lib.MemArg::new(0U, None, 0UL)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::i64_extend32s())
    body.push(@lib.Instruction::drop())
  }
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i64()]),
          @lib.Expr::new(body),
        ),
      ]),
    )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let use_def = @ir.use_def_build(func)
  (func, use_def, pls_scan_candidate_loads(func, use_def))
}

///|
fn pls_analysis_bench(it : @bench.T, count : Int) -> Unit {
  let (func, use_def, candidates) = pls_analysis_bench_fixture(count)
  let expected = pls_analyze_candidates(func, candidates.copy(), use_def)
  if expected.rewritable_candidates != count ||
    expected.elidable_uses.length() != count {
    abort("PickLoadSigns analysis fixture missed candidates")
  }
  it.bench(fn() {
    it.keep(pls_analyze_candidates(func, candidates.copy(), use_def))
  })
}

///|
test "bench pick-load-signs analysis count=128" (it : @bench.T) {
  pls_analysis_bench(it, 128)
}

///|
test "bench pick-load-signs analysis count=256" (it : @bench.T) {
  pls_analysis_bench(it, 256)
}

///|
fn pls_sparse_analysis_bench_fixture(
  unrelated : Int,
) -> (@ir.HotFunc, @ir.HotUseDef, Array[PLSCandidateLoad]) {
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i64_load32u(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i64_extend32s(),
    @lib.Instruction::drop(),
  ]
  for _ in 0..<unrelated {
    body.push(@lib.Instruction::nop())
  }
  let locals = Array::make(unrelated + 1, @lib.ValType::i64())
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body)),
      ]),
    )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let use_def = @ir.use_def_build(func)
  (func, use_def, pls_scan_candidate_loads(func, use_def))
}

///|
fn pls_sparse_analysis_bench(it : @bench.T, unrelated : Int) -> Unit {
  let (func, use_def, candidates) = pls_sparse_analysis_bench_fixture(unrelated)
  let expected = pls_analyze_candidates(func, candidates.copy(), use_def)
  if expected.rewritable_candidates != 1 || expected.elidable_uses.length() != 1 {
    abort("sparse PickLoadSigns analysis fixture missed its candidate")
  }
  it.bench(fn() {
    it.keep(pls_analyze_candidates(func, candidates.copy(), use_def))
  })
}

///|
test "bench pick-load-signs sparse unrelated=128" (it : @bench.T) {
  pls_sparse_analysis_bench(it, 128)
}

///|
test "bench pick-load-signs sparse unrelated=8192" (it : @bench.T) {
  pls_sparse_analysis_bench(it, 8192)
}
