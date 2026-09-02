///|
fn dead_code_elimination_perf_scalar_drop_module(
  function_count : Int,
) -> @lib.Module {
  let func_types : Array[@lib.TypeIdx] = Array::new(capacity=function_count)
  let funcs : Array[@lib.Func] = Array::new(capacity=function_count)
  for func_idx in 0..<function_count {
    func_types.push(@lib.TypeIdx::new(0U))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(func_idx)),
          @lib.Instruction::drop(),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(func_types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "bench dead-code-elimination branch-free scalar drops functions=2000" (
  it : @bench.T,
) {
  let function_count = 2000
  let fixture = dead_code_elimination_perf_scalar_drop_module(function_count)
  let trace : Array[String] = []
  let preflight = match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected scalar-drop DCE benchmark preflight success, got \{err}")
  }
  let mut no_candidate_skip_count = 0
  for line in trace {
    if line.contains(
        "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
      ) {
      no_candidate_skip_count += 1
    }
  }
  assert_eq(no_candidate_skip_count, function_count)
  match preflight.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), function_count)
    None => abort("expected scalar-drop DCE benchmark code section")
  }
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match
      @passes.run_hot_pipeline(fixture, options, ["dead-code-elimination"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) =>
        abort("expected scalar-drop DCE benchmark success, got \{err}")
    }
  })
}
