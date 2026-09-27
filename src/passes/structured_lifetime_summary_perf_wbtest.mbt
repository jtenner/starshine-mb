///|
fn structured_lifetime_summary_bench(it : @bench.T, count : Int) -> Unit {
  let body = structured_lifetime_summary_fixture(count)
  if run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
    ) {
    abort("unrelated structured reads must not block cleanup")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
        body,
      ),
    )
  })
}

///|
test "bench structured lifetime candidate prefixes=128" (it : @bench.T) {
  structured_lifetime_summary_bench(it, 128)
}

///|
test "bench structured lifetime candidate prefixes=256" (it : @bench.T) {
  structured_lifetime_summary_bench(it, 256)
}

///|
fn structured_lifetime_candidate_free_bench(it : @bench.T, count : Int) -> Unit {
  let body = structured_lifetime_candidate_free_fixture(count)
  if run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
    ) {
    abort("uncaptured structured reads must not block cleanup")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
        body,
      ),
    )
  })
}

///|
test "bench structured lifetime without captures=128" (it : @bench.T) {
  structured_lifetime_candidate_free_bench(it, 128)
}

///|
test "bench structured lifetime without captures=512" (it : @bench.T) {
  structured_lifetime_candidate_free_bench(it, 512)
}

///|
fn structured_lifetime_late_hazard_bench(
  it : @bench.T,
  selective : Bool,
) -> Unit {
  let body = structured_lifetime_candidate_free_fixture(512)
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
  )
  if !run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
    ) ||
    !raw_structured_lifetime_summarize(body, body.length(), None).hazard {
    abort("late nested capture must remain guarded")
  }
  it.bench(fn() {
    it.keep(
      if selective {
        run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
          body,
        )
      } else {
        let last = raw_structured_lifetime_last_structured(body, None)
        raw_structured_lifetime_summarize(body, last + 1, None).hazard
      },
    )
  })
}

///|
test "bench structured lifetime late hazard summary control" (it : @bench.T) {
  structured_lifetime_late_hazard_bench(it, false)
}

///|
test "bench structured lifetime late hazard selective summaries" (it : @bench.T) {
  structured_lifetime_late_hazard_bench(it, true)
}
