///|
fn dfe_type_prune_perf_fixture(count : Int, add_unused : Bool) -> @lib.Module {
  let types : Array[@lib.RecType] = []
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let body = Array::make(64, @lib.Instruction::nop())
  for idx in 0..<count {
    let params : Array[@lib.ValType] = []
    for bit in 0..<8 {
      params.push(
        if (idx & (1 << bit)) != 0 {
          @lib.ValType::i64()
        } else {
          @lib.ValType::i32()
        },
      )
    }
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func(params, [])),
      ),
    )
    type_idxs.push(@lib.TypeIdx::new(idx.to_uint()))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
  }
  if add_unused {
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dfe_type_prune_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dfe_type_prune_perf_fixture(count, false)
  if dfe_prune_unused_simple_types(fixture) != fixture {
    abort("DFE live-type fixture was unexpectedly pruned")
  }
  it.bench(fn() { it.keep(dfe_prune_unused_simple_types(fixture)) })
}

///|
fn dfe_imported_type_prune_perf_fixture(count : Int) -> @lib.Module {
  let fixture = dfe_type_prune_perf_fixture(count, true)
  let imports : Array[@lib.Import] = []
  for idx in 0..<count {
    imports.push(
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("sig_\{idx}"),
        @lib.ExternType::func(@lib.TypeIdx::new(idx.to_uint())),
      ),
    )
  }
  let funcs = match fixture.code_sec {
    Some(@lib.CodeSec(funcs)) => [funcs[0]]
    None => abort("DFE type fixture lacks code")
  }
  fixture
  .with_import_sec(@lib.ImportSec::new(imports))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dfe_imported_type_prune_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dfe_imported_type_prune_perf_fixture(count)
  let result = dfe_prune_unused_simple_types(fixture)
  match result.type_sec {
    Some(@lib.TypeSec(types)) if types.length() == count => ()
    _ => abort("DFE import-heavy fixture did not retain imported signatures")
  }
  if @validate.validate_module(result).is_err() {
    abort("DFE import-heavy fixture produced an invalid module")
  }
  it.bench(fn() { it.keep(dfe_prune_unused_simple_types(fixture)) })
}

///|
test "DFE type pruning retains imported signatures and removes unused tail" {
  let fixture = dfe_imported_type_prune_perf_fixture(16)
  let result = dfe_prune_unused_simple_types(fixture)
  match result.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 16)
    None => fail("DFE type pruning removed imported signatures")
  }
  assert_true(@validate.validate_module(result).is_ok())
}

///|
test "DFE type pruning still removes an unused trailing simple type" {
  let fixture = dfe_type_prune_perf_fixture(16, true)
  let pruned = dfe_prune_unused_simple_types(fixture)
  match pruned.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 16)
    None => fail("DFE pruning removed the complete type section")
  }
}

///|
test "DFE type pruning retains imported tag signatures" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::f64()], []),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("tag"),
          @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(0U))),
        ),
      ]),
    )
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = dfe_prune_unused_simple_types(input)
  match output.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 1)
    None => fail("DFE removed the imported tag signature")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "bench DFE live simple types count=64" (it : @bench.T) {
  dfe_type_prune_perf_bench(it, 64)
}

///|
test "bench DFE live simple types count=128" (it : @bench.T) {
  dfe_type_prune_perf_bench(it, 128)
}

///|
test "bench DFE live types plus one unused count=128" (it : @bench.T) {
  let fixture = dfe_type_prune_perf_fixture(128, true)
  let result = dfe_prune_unused_simple_types(fixture)
  match result.type_sec {
    Some(@lib.TypeSec(types)) if types.length() == 128 => ()
    _ => abort("DFE mixed-type benchmark did not prune one signature")
  }
  it.bench(fn() { it.keep(dfe_prune_unused_simple_types(fixture)) })
}

///|
test "bench DFE imported types plus one unused count=64" (it : @bench.T) {
  dfe_imported_type_prune_perf_bench(it, 64)
}

///|
test "bench DFE imported types plus one unused count=128" (it : @bench.T) {
  dfe_imported_type_prune_perf_bench(it, 128)
}

///|
fn dfe_tag_type_prune_perf_fixture(count : Int) -> @lib.Module {
  let types : Array[@lib.RecType] = [
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ]
  let tags : Array[@lib.TagType] = []
  for idx in 0..<count {
    let params : Array[@lib.ValType] = []
    for bit in 0..<8 {
      params.push(
        if (idx & (1 << bit)) != 0 {
          @lib.ValType::i64()
        } else {
          @lib.ValType::i32()
        },
      )
    }
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func(params, [])),
      ),
    )
    tags.push(@lib.TagType::new(@lib.TypeIdx::new((idx + 1).to_uint())))
  }
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::f64()], [])),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new(Array::make(512, @lib.Instruction::nop())),
      ),
    ]),
  )
  .with_tag_sec(@lib.TagSec::new(tags))
}

///|
fn dfe_tag_type_prune_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dfe_tag_type_prune_perf_fixture(count)
  if @validate.validate_module(fixture).is_err() {
    abort("DFE tag signature benchmark input is invalid")
  }
  let output = dfe_prune_unused_simple_types(fixture)
  match output.type_sec {
    Some(@lib.TypeSec(types)) if types.length() == count + 1 => ()
    _ => abort("DFE tag signature benchmark did not prune only the tail")
  }
  if @validate.validate_module(output).is_err() {
    abort("DFE tag signature benchmark output is invalid")
  }
  it.bench(fn() { it.keep(dfe_prune_unused_simple_types(fixture)) })
}

///|
test "bench DFE defined tag signatures count=64" (it : @bench.T) {
  dfe_tag_type_prune_perf_bench(it, 64)
}

///|
test "bench DFE defined tag signatures count=128" (it : @bench.T) {
  dfe_tag_type_prune_perf_bench(it, 128)
}

///|
fn dfe_unused_type_probe_fixture(count : Int) -> @lib.Module {
  let types : Array[@lib.RecType] = [
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ]
  for idx in 0..<count {
    let params : Array[@lib.ValType] = []
    for bit in 0..<8 {
      params.push(
        if (idx & (1 << bit)) != 0 {
          @lib.ValType::i64()
        } else {
          @lib.ValType::i32()
        },
      )
    }
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func(params, [])),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new(Array::make(1024, @lib.Instruction::nop())),
      ),
    ]),
  )
}

///|
fn dfe_unused_type_probe_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dfe_unused_type_probe_fixture(count)
  if @validate.validate_module(fixture).is_err() {
    abort("DFE unused-type probe fixture is invalid")
  }
  let output = dfe_prune_unused_simple_types(fixture)
  match output.type_sec {
    Some(@lib.TypeSec(types)) if types.length() == 1 => ()
    _ => abort("DFE unused-type probe fixture did not prune unused types")
  }
  if @validate.validate_module(output).is_err() {
    abort("DFE unused-type probe output is invalid")
  }
  it.bench(fn() { it.keep(dfe_prune_unused_simple_types(fixture)) })
}

///|
test "bench DFE unused simple signatures count=64" (it : @bench.T) {
  dfe_unused_type_probe_bench(it, 64)
}

///|
test "bench DFE unused simple signatures count=128" (it : @bench.T) {
  dfe_unused_type_probe_bench(it, 128)
}

///|
test "DFE unused-type bulk probe retains a block-only signature" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
              @lib.Expr::new([]),
            ),
          ]),
        ),
      ]),
    )
  assert_true(@validate.validate_module(input).is_ok())
  let output = dfe_prune_unused_simple_types(input)
  match output.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 2)
    None => fail("DFE pruned the block-only signature")
  }
  assert_true(@validate.validate_module(output).is_ok())
}
