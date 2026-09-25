///|
fn rg_name_sort_fixture(half : Int) -> @lib.Module {
  let globals : Array[@lib.Global] = []
  let names : Array[@lib.NameAssoc] = []
  let body : Array[@lib.Instruction] = []
  for idx in 0..<(half * 2) {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(idx))]),
      ),
    )
    names.push(
      @lib.NameAssoc::new(
        idx.reinterpret_as_uint(),
        @lib.Name::from_string("g\{idx}"),
      ),
    )
    if idx >= half {
      body.push(
        @lib.Instruction::global_get(
          @lib.GlobalIdx::new(idx.reinterpret_as_uint()),
        ),
      )
      body.push(@lib.Instruction::drop())
    }
  }
  @lib.Module::new()
  .with_type_sec(rg_perf_void_type_sec())
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
  .with_name_sec(@lib.NameSec::new(global_names=Some(@lib.NameMap::new(names))))
}

///|
fn rg_name_sort_bench(it : @bench.T, half : Int) -> Unit {
  let fixture = rg_name_sort_fixture(half)
  ignore(opportunity_run(fixture, "reorder-globals", true))
  let optimized = @passes.reorder_globals_run_module_pass(fixture)
  if optimized == fixture {
    abort("ReorderGlobals name-sort fixture did not reorder")
  }
  let entries = optimized.name_sec.unwrap().global_names.unwrap().0
  if entries.length() != half * 2 {
    abort("ReorderGlobals name-sort fixture lost names")
  }
  for idx in 0..<entries.length() {
    let @lib.NameAssoc(new_idx, _) = entries[idx]
    if new_idx.to_int() != idx {
      abort("ReorderGlobals name map is not sorted by remapped index")
    }
  }
  it.bench(fn() { it.keep(@passes.reorder_globals_run_module_pass(fixture)) })
}

///|
test "bench reorder-globals inverted names half=512" (it : @bench.T) {
  rg_name_sort_bench(it, 512)
}

///|
test "bench reorder-globals inverted names half=1024" (it : @bench.T) {
  rg_name_sort_bench(it, 1024)
}
