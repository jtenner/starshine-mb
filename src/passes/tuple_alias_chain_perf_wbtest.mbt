///|
fn tuple_alias_chain_bench_fixture(
  depth : Int,
) -> (@ir.HotFunc, HotTupleOptimizationQuerySummary, Array[Int]) {
  let instrs : Array[@lib.Instruction] = []
  let locals : Array[@lib.ValType] = []
  for idx in 1..<=depth {
    locals.push(@lib.ValType::i32())
    instrs.push(
      @lib.Instruction::local_get(@lib.LocalIdx::new((idx - 1).to_uint())),
    )
    instrs.push(@lib.Instruction::local_set(@lib.LocalIdx::new(idx.to_uint())))
  }
  instrs.push(@lib.Instruction::local_get(@lib.LocalIdx::new(depth.to_uint())))
  instrs.push(@lib.Instruction::drop())
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(instrs)),
      ]),
    )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let use_def = @ir.use_def_build(func)
  let summary = tuple_optimization_build_query_summary(func, use_def)
  let group_ids = Array::make(depth + 1, -1)
  group_ids[0] = 0
  (func, summary, group_ids)
}

///|
fn tuple_alias_chain_bench(it : @bench.T, depth : Int) -> Unit {
  let (func, summary, group_ids) = tuple_alias_chain_bench_fixture(depth)
  match
    tuple_optimization_resolve_copy_payload_local(
      func, summary, group_ids, depth, 1,
    ) {
    Some((resolved, nodes)) if resolved == 0 && nodes.length() == depth => ()
    _ => abort("tuple alias chain did not resolve")
  }
  it.bench(fn() {
    summary.next_resolve_visit_mark += 1
    it.keep(
      tuple_optimization_resolve_copy_payload_local(
        func,
        summary,
        group_ids,
        depth,
        summary.next_resolve_visit_mark,
      ),
    )
  })
}

///|
test "TupleOptimization resolves alias reads in outer-to-inner order" {
  let (func, summary, group_ids) = tuple_alias_chain_bench_fixture(8)
  match
    tuple_optimization_resolve_copy_payload_local(
      func, summary, group_ids, 8, 1,
    ) {
    Some((resolved, nodes)) => {
      assert_eq(resolved, 0)
      assert_eq(nodes.length(), 8)
      for idx in 0..<8 {
        assert_eq(@ir.hot_node_get(func, nodes[idx]).imm0, 7 - idx)
      }
    }
    None => fail("expected alias chain to resolve")
  }
}

///|
test "bench tuple alias chain depth=128" (it : @bench.T) {
  tuple_alias_chain_bench(it, 128)
}

///|
test "bench tuple alias chain depth=256" (it : @bench.T) {
  tuple_alias_chain_bench(it, 256)
}
