// Fixtures are constructed outside timing. Module-pass timing excludes final
// validation; preflight validates via public dispatch and checks input reuse.

///|
fn review2_module(
  body : Array[@lib.Instruction],
  locals : @lib.Locals,
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
}

///|
fn review2_preflight(fixture : @lib.Module, pass : String) -> @lib.Module {
  match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [pass]) {
    Ok(result) => result
    Err(err) => abort("review2 preflight: \{err}")
  }
}

///|
fn review2_untee(count : Int, grouped : Bool) -> @lib.Module {
  let runs = []
  if grouped {
    runs.push(@lib.LocalRun::new(count.to_uint(), @lib.ValType::i32()))
  } else {
    for idx in 0..<count {
      runs.push(
        @lib.LocalRun::new(
          1U,
          if idx % 2 == 0 {
            @lib.ValType::i32()
          } else {
            @lib.ValType::i64()
          },
        ),
      )
    }
  }
  review2_module(
    [
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ],
    @lib.Locals::from_decl_runs_preserving_groups(runs),
  )
}

///|
fn review2_memory(count : Int) -> @lib.Module {
  let types = []
  for _ in 0..<count {
    types.push(
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    )
  }
  review2_module([], @lib.Locals::empty())
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(
    @lib.FuncSec::new(
      Array::make(count, @lib.TypeIdx::new((count - 1).to_uint())),
    ),
  )
  .with_code_sec(
    @lib.CodeSec::new(
      Array::make(
        count,
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::data_drop(@lib.DataIdx::new(0U))]),
        ),
      ),
    ),
  )
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
  .with_data_sec(
    @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"abc")]),
  )
}

///|
fn review2_cse(count : Int) -> @lib.Module {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
  ]
  let fixture = review2_module(
    body,
    @lib.Locals::single(2U, @lib.ValType::i32()),
  )
  let funcs = match fixture.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => abort("expected code")
  }
  fixture
  .with_func_sec(@lib.FuncSec::new(Array::make(count, @lib.TypeIdx::new(0U))))
  .with_code_sec(@lib.CodeSec::new(Array::make(count, funcs[0])))
}

///|
fn review2_vacuum(count : Int) -> @lib.Module {
  let body = []
  for _ in 0..<count {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
        None,
      ),
    )
  }
  review2_module(body, @lib.Locals::single(1U, @lib.ValType::i32()))
}

///|
test "bench review2 untee runs count=16 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_untee(16, false)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "untee")
  assert_false(expected == fixture)
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.untee_run_module_pass(fixture)) })
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 untee runs count=1024 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_untee(1024, false)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "untee")
  assert_false(expected == fixture)
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.untee_run_module_pass(fixture)) })
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 untee runs count=4096 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_untee(4096, false)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "untee")
  assert_false(expected == fixture)
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.untee_run_module_pass(fixture)) })
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 untee grouped count=100000 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_untee(100000, true)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "untee")
  assert_false(expected == fixture)
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.untee_run_module_pass(fixture)) })
  assert_true(@passes.untee_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 memory-packing count=16 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_memory(16)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "memory-packing")
  assert_false(expected == fixture)
  assert_true(@passes.memory_packing_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.memory_packing_run_module_pass(fixture)) })
  assert_true(@passes.memory_packing_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 memory-packing count=1024 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_memory(1024)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "memory-packing")
  assert_false(expected == fixture)
  assert_true(@passes.memory_packing_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.memory_packing_run_module_pass(fixture)) })
  assert_true(@passes.memory_packing_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 memory-packing count=4096 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_memory(4096)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "memory-packing")
  assert_false(expected == fixture)
  assert_true(@passes.memory_packing_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.memory_packing_run_module_pass(fixture)) })
  assert_true(@passes.memory_packing_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 local-cse count=16 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_cse(16)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "local-cse")
  assert_false(expected == fixture)
  assert_true(@passes.local_cse_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.local_cse_run_module_pass(fixture)) })
  assert_true(@passes.local_cse_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 local-cse count=128 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_cse(128)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "local-cse")
  assert_false(expected == fixture)
  assert_true(@passes.local_cse_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.local_cse_run_module_pass(fixture)) })
  assert_true(@passes.local_cse_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 local-cse count=512 excluding final validation" (
  it : @bench.T,
) {
  let fixture = review2_cse(512)
  let before = fixture.code_sec
  let expected = review2_preflight(fixture, "local-cse")
  assert_false(expected == fixture)
  assert_true(@passes.local_cse_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(@passes.local_cse_run_module_pass(fixture)) })
  assert_true(@passes.local_cse_run_module_pass(fixture) == expected)
  assert_true(fixture.code_sec == before)
}

///|
test "bench review2 vacuum dynamic ifs=16 direct HOT pass" (it : @bench.T) {
  let fixture = review2_vacuum(16)
  assert_true(review2_preflight(fixture, "vacuum") == fixture)
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let ctx = @passes.HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  assert_true(@passes.hot_pass_run(ctx, hot).is_ok())
  let before = @ir.hot_lower_func_unverified(hot)
  it.bench(fn() { it.keep(@passes.hot_pass_run(ctx, hot)) })
  assert_true(@ir.hot_lower_func_unverified(hot) == before)
}

///|
test "bench review2 vacuum dynamic ifs=128 direct HOT pass" (it : @bench.T) {
  let fixture = review2_vacuum(128)
  assert_true(review2_preflight(fixture, "vacuum") == fixture)
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let ctx = @passes.HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  assert_true(@passes.hot_pass_run(ctx, hot).is_ok())
  let before = @ir.hot_lower_func_unverified(hot)
  it.bench(fn() { it.keep(@passes.hot_pass_run(ctx, hot)) })
  assert_true(@ir.hot_lower_func_unverified(hot) == before)
}

///|
test "bench review2 vacuum dynamic ifs=512 direct HOT pass" (it : @bench.T) {
  let fixture = review2_vacuum(512)
  assert_true(review2_preflight(fixture, "vacuum") == fixture)
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let ctx = @passes.HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  assert_true(@passes.hot_pass_run(ctx, hot).is_ok())
  let before = @ir.hot_lower_func_unverified(hot)
  it.bench(fn() { it.keep(@passes.hot_pass_run(ctx, hot)) })
  assert_true(@ir.hot_lower_func_unverified(hot) == before)
}
