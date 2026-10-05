///|
fn compiler_fact_value_lookup_fixture(count : Int) -> CompilerFactIndex {
  let sites : Array[@representation.ExpressionFact] = []
  for idx in 0..<count {
    sites.push(
      @representation.ExpressionFact::new(
        @representation.ValueSite::new(
          @representation.CodeSite::new(0U, (idx * 2).to_uint()),
        ),
        @representation.ValueFacts::exact_value(
          @representation.FactValue::integer(
            @representation.IntConstant::new(
              @representation.IntWidth::i32(),
              idx.to_uint64(),
            ),
          ),
        ),
      ),
    )
  }
  CompilerFactIndex::new(
    @representation.OptimizationFactsSec::new(bodies=[
      @representation.FunctionBodyFacts::new(0U, sites~),
    ]),
  )
}

///|
fn compiler_fact_value_lookup_bench(it : @bench.T, count : Int) -> Unit {
  let index = compiler_fact_value_lookup_fixture(count)
  for idx in 0..<count {
    let site = @representation.ValueSite::new(
      @representation.CodeSite::new(0U, (idx * 2).to_uint()),
    )
    if index.value_facts(site) is None {
      abort("dense value fact fixture did not resolve")
    }
  }
  it.bench(fn() {
    for idx in 0..<count {
      it.keep(
        index.value_facts(
          @representation.ValueSite::new(
            @representation.CodeSite::new(0U, (idx * 2).to_uint()),
          ),
        ),
      )
    }
  })
}

///|
test "CompilerFactIndex value map keeps selected body and first matching site" {
  let site = @representation.ValueSite::new(
    @representation.CodeSite::new(0U, 2U),
  )
  let wrong_owner = @representation.ValueSite::new(
    @representation.CodeSite::new(1U, 4U),
  )
  let first = @representation.ValueFacts::exact_ref_func(0U)
  let later = @representation.ValueFacts::exact_ref_func(1U)
  let index = CompilerFactIndex::new(
    @representation.OptimizationFactsSec::new(bodies=[
      @representation.FunctionBodyFacts::new(0U, sites=[
        @representation.ExpressionFact::new(site, later),
      ]),
      @representation.FunctionBodyFacts::new(0U, sites=[
        @representation.ExpressionFact::new(site, first),
        @representation.ExpressionFact::new(site, later),
        @representation.ExpressionFact::new(wrong_owner, later),
      ]),
    ]),
  )
  assert_eq(index.value_facts(site), Some(first))
  assert_eq(index.value_facts(wrong_owner), None)
}

///|
test "CompilerFactIndex safely indexes sparse and high-bit function ids" {
  let sparse = @representation.FunctionFacts::new(1000000U)
  let high = @representation.FunctionFacts::new(0xffffffffU)
  let index = CompilerFactIndex::new(
    @representation.OptimizationFactsSec::new(functions=[sparse, high]),
  )
  assert_eq(index.function_facts(@lib.FuncIdx::new(1000000U)), Some(sparse))
  assert_eq(index.function_facts(@lib.FuncIdx::new(0xffffffffU)), Some(high))
}

///|
test "bench compiler-fact value lookup count=2048" (it : @bench.T) {
  compiler_fact_value_lookup_bench(it, 2048)
}

///|
test "bench compiler-fact value lookup count=4096" (it : @bench.T) {
  compiler_fact_value_lookup_bench(it, 4096)
}
