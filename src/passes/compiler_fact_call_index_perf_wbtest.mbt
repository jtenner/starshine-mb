///|
fn compiler_fact_call_index_perf_fixture(
  count : Int,
) -> (CompilerFactIndex, Array[@representation.CodeSite]) {
  let calls : Array[@representation.CallSiteFacts] = []
  let sites : Array[@representation.CodeSite] = []
  for idx in 0..<count {
    let site = @representation.CodeSite::new(0U, idx.to_uint())
    sites.push(site)
    calls.push(
      @representation.CallSiteFacts::new(
        site,
        direct_target=Some(idx.to_uint()),
      ),
    )
  }
  let facts = @representation.OptimizationFactsSec::new(bodies=[
    @representation.FunctionBodyFacts::new(0U, calls~),
  ])
  (CompilerFactIndex::new(facts), sites)
}

///|
test "compiler fact call index keeps first duplicate and containing function" {
  let site = @representation.CodeSite::new(0U, 7U)
  let other_function_site = @representation.CodeSite::new(1U, 7U)
  let facts = @representation.OptimizationFactsSec::new(bodies=[
    @representation.FunctionBodyFacts::new(0U, calls=[
      @representation.CallSiteFacts::new(site, direct_target=Some(3U)),
      @representation.CallSiteFacts::new(site, direct_target=Some(4U)),
      @representation.CallSiteFacts::new(
        other_function_site,
        direct_target=Some(5U),
      ),
    ]),
  ])
  let index = CompilerFactIndex::new(facts)
  assert_eq(index.call_facts(site).unwrap().direct_target, Some(3U))
  assert_true(index.call_facts(other_function_site) is None)
  assert_true(index.call_facts(@representation.CodeSite::new(0U, 8U)) is None)
}

///|
fn compiler_fact_call_index_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (index, sites) = compiler_fact_call_index_perf_fixture(count)
  if index.call_facts(sites[count - 1]).unwrap().direct_target !=
    Some((count - 1).to_uint()) {
    abort("compiler fact call index fixture lost its last site")
  }
  it.bench(fn() {
    let mut sum = 0U
    for site in sites {
      match index.call_facts(site) {
        Some(facts) =>
          match facts.direct_target {
            Some(target) => sum += target
            None => ()
          }
        None => ()
      }
    }
    it.keep(sum)
  })
}

///|
test "bench compiler fact call lookup sites=128" (it : @bench.T) {
  compiler_fact_call_index_perf_bench(it, 128)
}

///|
test "bench compiler fact call lookup sites=256" (it : @bench.T) {
  compiler_fact_call_index_perf_bench(it, 256)
}
