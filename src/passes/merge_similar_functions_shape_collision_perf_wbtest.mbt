///|
fn msf_shape_collision_perf_fixture(
  count : Int,
) -> (Array[@lib.Func], Array[MsfFunctionSummary], Array[@lib.TypeIdx?]) {
  let type_idxs = Array::make(count, @lib.TypeIdx::new(0U))
  let signatures : Array[@lib.FuncType?] = []
  let call_types : Array[@lib.TypeIdx?] = []
  let funcs : Array[@lib.Func] = []
  for idx in 0..<count {
    signatures.push(Some(@lib.FuncType::new([], [])))
    call_types.push(Some(@lib.TypeIdx::new(idx.reinterpret_as_uint())))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(idx.reinterpret_as_uint())),
        ]),
      ),
    )
  }
  let summaries = msf_build_function_summaries(
    type_idxs, funcs, signatures, call_types,
  )
  (funcs, summaries, call_types)
}

///|
fn msf_shape_collision_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (funcs, summaries, call_types) = msf_shape_collision_perf_fixture(count)
  if !msf_collect_classes(funcs, summaries, call_types).is_empty() {
    abort("MergeSimilar collision fixture unexpectedly formed a class")
  }
  it.bench(fn() { it.keep(msf_collect_classes(funcs, summaries, call_types)) })
}

///|
test "bench MergeSimilar incompatible call types count=128" (it : @bench.T) {
  msf_shape_collision_perf_bench(it, 128)
}

///|
test "bench MergeSimilar incompatible call types count=256" (it : @bench.T) {
  msf_shape_collision_perf_bench(it, 256)
}

///|
test "MergeSimilar shape hash keeps same-type call targets mergeable" {
  let (funcs, _, _) = msf_shape_collision_perf_fixture(2)
  let type_idxs = Array::make(2, @lib.TypeIdx::new(0U))
  let signatures : Array[@lib.FuncType?] = [Some(@lib.FuncType::new([], []))]
  let call_types : Array[@lib.TypeIdx?] = [
    Some(@lib.TypeIdx::new(0U)),
    Some(@lib.TypeIdx::new(0U)),
  ]
  let summaries = msf_build_function_summaries(
    type_idxs, funcs, signatures, call_types,
  )
  @debug.assert_eq(summaries[0].shape_hash, summaries[1].shape_hash)
  let classes = msf_collect_classes(funcs, summaries, call_types)
  @debug.assert_eq(classes.length(), 1)
  @debug.assert_eq(classes[0].members, [0, 1])
}
