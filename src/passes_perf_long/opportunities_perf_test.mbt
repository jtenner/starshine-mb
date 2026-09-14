// Pass-local measurements exclude repeated final validation. Setup validates
// every fixture and checks transformation and reuse before calibrated timing.

///|
fn opportunity_module(
  body : Array[@lib.Instruction],
  locals : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], results)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn opportunity_run(
  fixture : @lib.Module,
  pass : String,
  validate : Bool,
) -> @lib.Module {
  match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(validate_final_module=validate),
      [pass],
    ) {
    Ok(result) => result
    Err(err) => abort("opportunity fixture failed: \{err}")
  }
}

///|
fn opportunity_padding(count : Int) -> Array[@lib.Instruction] {
  let body = []
  for _ in 0..<count {
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    body.push(@lib.Instruction::drop())
  }
  body
}

///|
fn opportunity_imports(count : Int, imports : Int) -> @lib.Module {
  let fixture = opportunity_module([], [], [])
  let import_list = []
  for _ in 0..<imports {
    import_list.push(
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("same"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    )
  }
  fixture
  .with_import_sec(@lib.ImportSec::new(import_list))
  .with_func_sec(@lib.FuncSec::new(Array::make(count, @lib.TypeIdx::new(0U))))
  .with_code_sec(
    @lib.CodeSec::new(
      Array::make(
        count,
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ),
    ),
  )
}

///|
fn opportunity_locals(count : Int, dense : Bool) -> @lib.Module {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  for _ in 0..<count {
    body.push(
      if dense {
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
      } else {
        @lib.Instruction::i32_const(@lib.I32(7))
      },
    )
    body.push(@lib.Instruction::drop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  body.push(@lib.Instruction::i32_add())
  opportunity_module(body, [@lib.ValType::i32(), @lib.ValType::i32()], [
    @lib.ValType::i32(),
  ])
}

///|
fn opportunity_blocks(count : Int, has_local : Bool) -> @lib.Module {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new(opportunity_padding(count)),
    ),
  ]
  opportunity_module(body, if has_local { [@lib.ValType::i32()] } else { [] }, [])
}

///|
test "bench opportunity labels empty pairs=128" (it : @bench.T) {
  let fixture = opportunity_module(opportunity_padding(128), [], [])
  assert_true(
    opportunity_run(fixture, "duplicate-import-elimination", true) == fixture,
  )
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_eq(hot.labels.length(), 0)
  let before = @ir.hot_node_count(hot)
  assert_eq(@passes.pass_compute_label_used(hot).length(), hot.labels.length())
  it.bench(fn() { it.keep(@passes.pass_compute_label_used(hot)) })
  assert_eq(@ir.hot_node_count(hot), before)
}

///|
test "bench opportunity labels empty pairs=2048" (it : @bench.T) {
  let fixture = opportunity_module(opportunity_padding(2048), [], [])
  assert_true(
    opportunity_run(fixture, "duplicate-import-elimination", true) == fixture,
  )
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_eq(hot.labels.length(), 0)
  let before = @ir.hot_node_count(hot)
  assert_eq(@passes.pass_compute_label_used(hot).length(), hot.labels.length())
  it.bench(fn() { it.keep(@passes.pass_compute_label_used(hot)) })
  assert_eq(@ir.hot_node_count(hot), before)
}

///|
test "bench opportunity labels structured pairs=2048" (it : @bench.T) {
  let fixture = opportunity_module(
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new(opportunity_padding(2048)),
      ),
    ],
    [],
    [],
  )
  assert_true(
    opportunity_run(fixture, "duplicate-import-elimination", true) == fixture,
  )
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_eq(hot.labels.length(), 1)
  let before = @ir.hot_node_count(hot)
  assert_eq(@passes.pass_compute_label_used(hot).length(), hot.labels.length())
  it.bench(fn() { it.keep(@passes.pass_compute_label_used(hot)) })
  assert_eq(@ir.hot_node_count(hot), before)
}

///|
test "bench opportunity labels empty pairs=32768" (it : @bench.T) {
  let fixture = opportunity_module(opportunity_padding(32768), [], [])
  assert_true(
    opportunity_run(fixture, "duplicate-import-elimination", true) == fixture,
  )
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  assert_eq(hot.labels.length(), 0)
  let before = @ir.hot_node_count(hot)
  assert_eq(@passes.pass_compute_label_used(hot).length(), hot.labels.length())
  it.bench(fn() { it.keep(@passes.pass_compute_label_used(hot)) })
  assert_eq(@ir.hot_node_count(hot), before)
}

///|
test "bench opportunity duplicate imports=0 functions=32" (it : @bench.T) {
  let fixture = opportunity_imports(32, 0)
  let expected = opportunity_run(fixture, "duplicate-import-elimination", true)
  assert_true(@passes.die_run_module_pass(fixture) == expected)
  let before = fixture.code_sec
  it.bench(fn() { it.keep(@passes.die_run_module_pass(fixture)) })
  assert_true(fixture.code_sec == before)
}

///|
test "bench opportunity duplicate imports=0 functions=512" (it : @bench.T) {
  let fixture = opportunity_imports(512, 0)
  let expected = opportunity_run(fixture, "duplicate-import-elimination", true)
  assert_true(@passes.die_run_module_pass(fixture) == expected)
  let before = fixture.code_sec
  it.bench(fn() { it.keep(@passes.die_run_module_pass(fixture)) })
  assert_true(fixture.code_sec == before)
}

///|
test "bench opportunity duplicate imports=0 functions=4096" (it : @bench.T) {
  let fixture = opportunity_imports(4096, 0)
  let expected = opportunity_run(fixture, "duplicate-import-elimination", true)
  assert_true(@passes.die_run_module_pass(fixture) == expected)
  let before = fixture.code_sec
  it.bench(fn() { it.keep(@passes.die_run_module_pass(fixture)) })
  assert_true(fixture.code_sec == before)
}

///|
test "bench opportunity duplicate imports=1 functions=4096" (it : @bench.T) {
  let fixture = opportunity_imports(4096, 1)
  let expected = opportunity_run(fixture, "duplicate-import-elimination", true)
  assert_true(@passes.die_run_module_pass(fixture) == expected)
  let before = fixture.code_sec
  it.bench(fn() { it.keep(@passes.die_run_module_pass(fixture)) })
  assert_true(fixture.code_sec == before)
}

///|
test "bench opportunity duplicate imports=2 functions=4096" (it : @bench.T) {
  let fixture = opportunity_imports(4096, 2)
  let expected = opportunity_run(fixture, "duplicate-import-elimination", true)
  assert_true(@passes.die_run_module_pass(fixture) == expected)
  let before = fixture.code_sec
  it.bench(fn() { it.keep(@passes.die_run_module_pass(fixture)) })
  assert_true(fixture.code_sec == before)
}

///|
test "bench opportunity merge-locals count=100 control=false" (it : @bench.T) {
  let fixture = opportunity_locals(100, false)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-locals", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-locals", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-locals", false)) })
}

///|
test "bench opportunity merge-locals count=1000 control=false" (it : @bench.T) {
  let fixture = opportunity_locals(1000, false)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-locals", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-locals", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-locals", false)) })
}

///|
test "bench opportunity merge-locals count=1000 control=true" (it : @bench.T) {
  let fixture = opportunity_locals(1000, true)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-locals", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-locals", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-locals", false)) })
}

///|
test "bench opportunity merge-locals count=10000 control=false" (it : @bench.T) {
  let fixture = opportunity_locals(10000, false)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-locals", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-locals", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-locals", false)) })
}

///|
test "bench opportunity merge-blocks count=100 control=false" (it : @bench.T) {
  let fixture = opportunity_blocks(100, false)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-blocks", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-blocks", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-blocks", false)) })
}

///|
test "bench opportunity merge-blocks count=1000 control=false" (it : @bench.T) {
  let fixture = opportunity_blocks(1000, false)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-blocks", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-blocks", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-blocks", false)) })
}

///|
test "bench opportunity merge-blocks count=1000 control=true" (it : @bench.T) {
  let fixture = opportunity_blocks(1000, true)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-blocks", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-blocks", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-blocks", false)) })
}

///|
test "bench opportunity merge-blocks count=4000 control=false" (it : @bench.T) {
  let fixture = opportunity_blocks(4000, false)
  let before = fixture.code_sec
  let expected = opportunity_run(fixture, "merge-blocks", true)
  assert_false(expected == fixture)
  assert_true(opportunity_run(fixture, "merge-blocks", true) == expected)
  assert_true(fixture.code_sec == before)
  it.bench(fn() { it.keep(opportunity_run(fixture, "merge-blocks", false)) })
}
