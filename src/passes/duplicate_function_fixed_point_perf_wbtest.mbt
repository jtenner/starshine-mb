///|
fn dfe_fixed_point_perf_fixture(depth : Int, wrappers : Int) -> @lib.Module {
  let imports : Array[@lib.Import] = []
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  for idx in 0..<wrappers {
    imports.push(
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("target_\{idx}"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    )
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::nop(),
          @lib.Instruction::call(@lib.FuncIdx::new(idx.to_uint())),
        ]),
      ),
    )
  }
  for level in 0..<depth {
    for side in 0..<2 {
      type_idxs.push(@lib.TypeIdx::new(0U))
      let body = if level == 0 {
        [@lib.Instruction::nop()]
      } else {
        [
          @lib.Instruction::call(
            @lib.FuncIdx::new(
              (wrappers + wrappers + (level - 1) * 2 + side).to_uint(),
            ),
          ),
        ]
      }
      funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
    }
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_import_sec(@lib.ImportSec::new(imports))
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dfe_fixed_point_perf_bench(it : @bench.T, depth : Int) -> Unit {
  let wrappers = 128
  let fixture = dfe_fixed_point_perf_fixture(depth, wrappers)
  if @validate.validate_module(fixture).is_err() {
    abort("DFE fixed-point benchmark input is invalid")
  }
  let result = dfe_eliminate_duplicate_functions(fixture)
  let survivors = match result.mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.length()
    None => abort("DFE fixed-point benchmark lost code")
  }
  if !result.changed ||
    survivors != wrappers + depth ||
    @validate.validate_module(result.mod_).is_err() {
    abort("DFE fixed-point benchmark did not merge each chain pair")
  }
  it.bench(fn() { it.keep(dfe_eliminate_duplicate_functions(fixture)) })
}

///|
test "bench DFE fixed-point chains depth=16 wrappers=128" (it : @bench.T) {
  dfe_fixed_point_perf_bench(it, 16)
}

///|
test "bench DFE fixed-point chains depth=32 wrappers=128" (it : @bench.T) {
  dfe_fixed_point_perf_bench(it, 32)
}

///|
test "DFE fixed-point chain revisits only changed target groups" {
  let input = dfe_fixed_point_perf_fixture(4, 4)
  assert_true(@validate.validate_module(input).is_ok())
  let result = dfe_eliminate_duplicate_functions(input)
  assert_true(result.changed)
  assert_eq(result.iteration_count, 4)
  match result.mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 8)
    None => fail("DFE fixed-point chain lost its code section")
  }
  assert_true(@validate.validate_module(result.mod_).is_ok())
}
