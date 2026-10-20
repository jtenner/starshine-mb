///|
fn dae_review_callsite_bench(it : @bench.T, reference : Bool) -> Unit raise {
  let calls = Array::make(256, "i32.const 7 call $target").join(" ")
  let input = pass_test_module_from_wat(
    "(module (func $target (param i32)) (func (export \"run\") \{calls}))",
  )
  let graph = dae_current_boundary_graph_new(input)
  let info = graph.snapshot.function_infos[0]
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let paths = info.calls.map(fn(callsite) { callsite.path })
  let selection = dae_stable_rewrite_selection(paths).unwrap()
  let localization : DaeCallsiteLocalizationContext = {
    first_scratch_local: 0,
    param_types: [@lib.ValType::i32()],
    scratch_local_types: [],
    localized_params: [false],
  }
  let expected = dae_review_callsite_reference(
    body,
    -1,
    selection,
    0,
    [true],
    0,
    input,
    graph.snapshot.type_indices,
    localization,
    false,
    false,
  )
  let actual = dae_rewrite_calls_from_stable_selection_scope(
    body,
    -1,
    selection,
    0,
    [true],
    0,
    input,
    graph.snapshot.type_indices,
    localization,
    false,
    false,
  )
  assert_true(expected.ok && actual.ok)
  assert_eq(actual.instrs, expected.instrs)
  assert_eq(actual.calls_rewritten, 256)
  assert_eq(actual.instrs.length(), 256)
  it.bench(fn() {
    it.keep(
      if reference {
        dae_review_callsite_reference(
          body,
          -1,
          selection,
          0,
          [true],
          0,
          input,
          graph.snapshot.type_indices,
          localization,
          false,
          false,
        )
      } else {
        dae_rewrite_calls_from_stable_selection_scope(
          body,
          -1,
          selection,
          0,
          [true],
          0,
          input,
          graph.snapshot.type_indices,
          localization,
          false,
          false,
        )
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE 256 independent calls pre-review reference" (it : @bench.T) {
  dae_review_callsite_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE 256 independent calls batched fragments" (it : @bench.T) {
  dae_review_callsite_bench(it, false)
}
