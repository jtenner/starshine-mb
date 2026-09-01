///|
fn rg_perf_void_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn rg_perf_hot_body(global_idx : UInt, uses : Int) -> @lib.Expr {
  let body : Array[@lib.Instruction] = Array::new(capacity=uses * 2)
  for _ in 0..<uses {
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(global_idx)))
    body.push(@lib.Instruction::drop())
  }
  @lib.Expr::new(body)
}

///|
fn rg_perf_import_heavy_module(global_count : Int, uses : Int) -> @lib.Module {
  let imports : Array[@lib.Import] = Array::new(capacity=global_count)
  for idx in 0..<global_count {
    imports.push(
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("g\{idx}"),
        @lib.ExternType::global(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
        ),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(rg_perf_void_type_sec())
  .with_import_sec(@lib.ImportSec::new(imports))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        rg_perf_hot_body((global_count - 1).reinterpret_as_uint(), uses),
      ),
    ]),
  )
}

///|
fn rg_perf_dependency_heavy_module(
  global_count : Int,
  uses : Int,
) -> @lib.Module {
  let globals : Array[@lib.Global] = Array::new(capacity=global_count)
  globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::i32(), false),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
  )
  for idx = 1; idx < global_count; idx = idx + 1 {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([
          @lib.Instruction::global_get(
            @lib.GlobalIdx::new((idx - 1).reinterpret_as_uint()),
          ),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(rg_perf_void_type_sec())
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        rg_perf_hot_body((global_count - 1).reinterpret_as_uint(), uses),
      ),
    ]),
  )
}

///|
fn rg_perf_measure(make_fixture : () -> @lib.Module) -> UInt64 {
  for _ in 0..<2 {
    ignore(@passes.reorder_globals_run_module_pass(make_fixture()))
  }
  let samples : Array[UInt64] = []
  for _ in 0..<9 {
    let fixture = make_fixture()
    let start = @lib.trace_now_us()
    ignore(@passes.reorder_globals_run_module_pass(fixture))
    samples.push(@lib.trace_elapsed_us_since(start))
  }
  samples.sort()
  samples[samples.length() / 2]
}

///|
#skip("manual native-release reorder-globals ready-heap benchmark")
test "reorder-globals perf lane bounds unconstrained and dependency-heavy ordering" {
  let global_count = 2000
  let uses = 20000
  let import_median_us = rg_perf_measure(fn() {
    rg_perf_import_heavy_module(global_count, uses)
  })
  let dependency_median_us = rg_perf_measure(fn() {
    rg_perf_dependency_heavy_module(global_count, uses)
  })
  println(
    "reorder_globals globals=\{global_count} uses=\{uses} import_median_us=\{import_median_us} dependency_median_us=\{dependency_median_us}",
  )
  assert_true(
    import_median_us < 20000UL,
    msg="expected import-heavy ordering below 20ms, got \{import_median_us}us",
  )
  assert_true(
    dependency_median_us < 20000UL,
    msg="expected dependency-heavy ordering below 20ms, got \{dependency_median_us}us",
  )
}

///|
test "bench reorder-globals pass imported globals=2000 uses=20000" (
  it : @bench.T,
) {
  let fixture = rg_perf_import_heavy_module(2000, 20000)
  ignore(@passes.reorder_globals_run_module_pass(fixture))
  it.bench(fn() {
    let optimized = @passes.reorder_globals_run_module_pass(fixture)
    ignore(optimized.global_sec)
  })
}

///|
test "bench reorder-globals pass dependency chain globals=2000 uses=20000" (
  it : @bench.T,
) {
  let fixture = rg_perf_dependency_heavy_module(2000, 20000)
  ignore(@passes.reorder_globals_run_module_pass(fixture))
  it.bench(fn() {
    let optimized = @passes.reorder_globals_run_module_pass(fixture)
    ignore(optimized.global_sec)
  })
}
