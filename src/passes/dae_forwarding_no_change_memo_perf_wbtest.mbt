///|
fn dae_forwarding_memo_bench(
  it : @bench.T,
  siblings : Int32,
  use_memo : Bool,
) -> Unit raise {
  let input = dae_forwarding_memo_blocked_fixture()
  let funcs = input.code_sec.unwrap().0.copy()
  let indices = input.func_sec.unwrap().0.copy()
  for _index in 0..<siblings {
    indices.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
  }
  let input = input
    .with_func_sec(@lib.FuncSec::new(indices))
    .with_code_sec(@lib.CodeSec::new(funcs))
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let first = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  let second = dae_work_item_new(graph, dependencies, 1, DaeForwardingWork)
  let items = [first, second]
  let diagnostics = dae_diagnostics_new()
  let memo = DaeForwardingNoChangeMemo::new()
  for item in items {
    match
      dae_process_forwarding_work_item_with_memo(
        original,
        input,
        [],
        false,
        graph,
        dependencies,
        item,
        diagnostics,
        memo,
      ) {
      DaeWorkNoChange(DaeNoStrictImprovement) => ()
      _ => fail("the paired workload must retain the blocked component")
    }
  }
  assert_eq(diagnostics.boundaries_analyzed, 2)
  assert_eq(memo.entries.get(first.component_id), Some([0, 1]))
  it.bench(fn() {
    let diagnostics = dae_diagnostics_new()
    if use_memo {
      let memo = DaeForwardingNoChangeMemo::new()
      for item in items {
        it.keep(
          dae_process_forwarding_work_item_with_memo(
            original,
            input,
            [],
            false,
            graph,
            dependencies,
            item,
            diagnostics,
            memo,
          ),
        )
      }
    } else {
      for item in items {
        it.keep(
          dae_process_work_item(
            original,
            input,
            [],
            false,
            graph,
            dependencies,
            item,
            diagnostics,
          ),
        )
      }
    }
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native forwarding memo cost; dedicated performance lane")
test "bench DAE forwarding memo siblings=0 reference" (it : @bench.T) {
  dae_forwarding_memo_bench(it, 0, false)
}

///|
#skip("paired native forwarding memo cost; dedicated performance lane")
test "bench DAE forwarding memo siblings=0 memo" (it : @bench.T) {
  dae_forwarding_memo_bench(it, 0, true)
}

///|
#skip("paired native forwarding memo cost; dedicated performance lane")
test "bench DAE forwarding memo siblings=128 reference" (it : @bench.T) {
  dae_forwarding_memo_bench(it, 128, false)
}

///|
#skip("paired native forwarding memo cost; dedicated performance lane")
test "bench DAE forwarding memo siblings=128 memo" (it : @bench.T) {
  dae_forwarding_memo_bench(it, 128, true)
}

///|
#skip("paired native forwarding memo cost; dedicated performance lane")
test "bench DAE forwarding memo siblings=13000 reference" (it : @bench.T) {
  dae_forwarding_memo_bench(it, 13000, false)
}

///|
#skip("paired native forwarding memo cost; dedicated performance lane")
test "bench DAE forwarding memo siblings=13000 memo" (it : @bench.T) {
  dae_forwarding_memo_bench(it, 13000, true)
}
