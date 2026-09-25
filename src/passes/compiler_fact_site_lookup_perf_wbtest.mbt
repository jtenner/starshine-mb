///|
fn compiler_fact_site_lookup_fixture(count : Int) -> CompilerFactQuery {
  let entries : Array[(UInt, @lib.Instruction)] = []
  for idx in 0..<count {
    entries.push(
      ((idx * 2).to_uint(), @lib.Instruction::i32_const(@lib.I32(idx))),
    )
  }
  CompilerFactQuery::new(
    @lib.Module::new(),
    1U,
    CompilerFactUsePolicy::trust_assertions(),
    CompilerFactIndex::new(@representation.OptimizationFactsSec::new()),
    [entries],
    CompilerFactMaterializationStats::new(),
  )
}

///|
fn compiler_fact_site_lookup_bench(it : @bench.T, count : Int) -> Unit {
  let query = compiler_fact_site_lookup_fixture(count)
  for idx in 0..<count {
    if !query.site_resolves(
        @representation.CodeSite::new(0U, (idx * 2).to_uint()),
        @lib.Instruction::i32_const(@lib.I32(idx)),
      ) {
      abort("compiler-fact site fixture did not resolve")
    }
  }
  it.bench(fn() {
    for idx in 0..<count {
      it.keep(
        query.site_resolves(
          @representation.CodeSite::new(0U, (idx * 2).to_uint()),
          @lib.Instruction::i32_const(@lib.I32(idx)),
        ),
      )
    }
  })
}

///|
test "CompilerFactQuery site lookup keeps first duplicate and rejects stale sites" {
  let stats = CompilerFactMaterializationStats::new()
  let query = CompilerFactQuery::new(
    @lib.Module::new(),
    1U,
    CompilerFactUsePolicy::trust_assertions(),
    CompilerFactIndex::new(@representation.OptimizationFactsSec::new()),
    [
      [
        (2U, @lib.Instruction::i32_const(@lib.I32(1))),
        (2U, @lib.Instruction::i32_const(@lib.I32(2))),
      ],
    ],
    stats,
  )
  assert_true(
    query.site_resolves(
      @representation.CodeSite::new(0U, 2U),
      @lib.Instruction::i32_const(@lib.I32(1)),
    ),
  )
  assert_false(
    query.site_resolves(
      @representation.CodeSite::new(0U, 2U),
      @lib.Instruction::i32_const(@lib.I32(2)),
    ),
  )
  assert_false(
    query.site_resolves(
      @representation.CodeSite::new(0U, 3U),
      @lib.Instruction::i32_const(@lib.I32(1)),
    ),
  )
  assert_eq(stats.stale_or_unresolved_sites, 2)
}

///|
test "bench compiler-fact site lookup count=2048" (it : @bench.T) {
  compiler_fact_site_lookup_bench(it, 2048)
}

///|
test "bench compiler-fact site lookup count=4096" (it : @bench.T) {
  compiler_fact_site_lookup_bench(it, 4096)
}
