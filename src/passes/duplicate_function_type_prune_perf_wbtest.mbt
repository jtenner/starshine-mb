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
test "DFE type pruning still removes an unused trailing simple type" {
  let fixture = dfe_type_prune_perf_fixture(16, true)
  let pruned = dfe_prune_unused_simple_types(fixture)
  match pruned.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 16)
    None => fail("DFE pruning removed the complete type section")
  }
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
