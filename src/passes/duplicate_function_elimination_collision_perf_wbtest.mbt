///|
fn dfe_collision_perf_module(count : Int) -> @lib.Module {
  let imports : Array[@lib.Import] = []
  let types : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  for idx in 0..<count {
    imports.push(
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("target_\{idx}"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    )
    types.push(@lib.TypeIdx::new(0U))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(idx.reinterpret_as_uint())),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_import_sec(@lib.ImportSec::new(imports))
  .with_func_sec(@lib.FuncSec::new(types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dfe_collision_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dfe_collision_perf_module(count)
  let preflight = dfe_eliminate_duplicate_functions(fixture)
  if preflight.changed || preflight.mod_ != fixture {
    abort("DFE collision fixture unexpectedly merged distinct imported targets")
  }
  it.bench(fn() { it.keep(dfe_eliminate_duplicate_functions(fixture)) })
}

///|
test "bench DFE distinct import wrapper collisions=128" (it : @bench.T) {
  dfe_collision_perf_bench(it, 128)
}

///|
test "bench DFE distinct import wrapper collisions=256" (it : @bench.T) {
  dfe_collision_perf_bench(it, 256)
}

///|
test "DFE distinct import wrappers remain separate" {
  let fixture = dfe_collision_perf_module(8)
  assert_true(@validate.validate_module(fixture).is_ok())
  let result = dfe_eliminate_duplicate_functions(fixture)
  assert_false(result.changed)
  @debug.assert_eq(result.mod_, fixture)
}

///|
fn dfe_duplicate_perf_module(count : Int) -> @lib.Module {
  let fixture = dfe_collision_perf_module(count)
  let funcs : Array[@lib.Func] = []
  for _ in 0..<count {
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
    )
  }
  fixture.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dfe_duplicate_prefix_perf_module(count : Int) -> @lib.Module {
  let fixture = dfe_collision_perf_module(count)
  let funcs = match fixture.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => abort("DFE collision fixture lacks code")
  }
  for idx in 1..<8 {
    funcs[idx] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    )
  }
  fixture.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dfe_duplicate_prefix_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dfe_duplicate_prefix_perf_module(count)
  let result = dfe_eliminate_duplicate_functions(fixture)
  let survivors = match result.mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.length()
    None => abort("DFE duplicate-prefix fixture lost code")
  }
  if !result.changed ||
    survivors != count - 7 ||
    @validate.validate_module(result.mod_).is_err() {
    abort("DFE duplicate-prefix fixture did not retain distinct wrappers")
  }
  it.bench(fn() { it.keep(dfe_eliminate_duplicate_functions(fixture)) })
}

///|
test "DFE duplicate prefix keeps distinct imported-target wrappers" {
  let fixture = dfe_duplicate_prefix_perf_module(16)
  let result = dfe_eliminate_duplicate_functions(fixture)
  assert_true(result.changed)
  let funcs = match result.mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => abort("DFE duplicate-prefix result lacks code")
  }
  assert_eq(funcs.length(), 9)
  for idx in 0..<funcs.length() {
    let @lib.Func(_, @lib.Expr(instrs)) = funcs[idx]
    let target = if idx == 0 { 0 } else { idx + 7 }
    assert_eq(instrs, [
      @lib.Instruction::call(@lib.FuncIdx::new(target.reinterpret_as_uint())),
    ])
  }
}

///|
test "bench DFE duplicate-prefix collisions=128" (it : @bench.T) {
  dfe_duplicate_prefix_perf_bench(it, 128)
}

///|
test "bench DFE duplicate-prefix collisions=256" (it : @bench.T) {
  dfe_duplicate_prefix_perf_bench(it, 256)
}

///|
test "bench DFE duplicate import wrappers=128" (it : @bench.T) {
  let fixture = dfe_duplicate_perf_module(128)
  let preflight = dfe_eliminate_duplicate_functions(fixture)
  if !preflight.changed {
    abort("DFE duplicate fixture failed to merge wrappers")
  }
  it.bench(fn() { it.keep(dfe_eliminate_duplicate_functions(fixture)) })
}
