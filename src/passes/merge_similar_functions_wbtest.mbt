///|
test "merge-similar-functions admits a profitable 255-parameter helper" {
  assert_true(msf_has_merge_benefit_for_count(1100, 0, 2, 255))
}

///|
test "merge-similar-functions rejects a 256-parameter helper" {
  assert_false(msf_has_merge_benefit_for_count(2000, 0, 2, 256))
}

///|
test "merge-similar-functions fused summaries cache body and call facts" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $callee (func (param i32)))
      #|  (type $body (func (param i32)))
      #|  (import "env" "sink" (func $sink (type $callee)))
      #|  (func (type $body) (local i64)
      #|    local.get 0 drop
      #|    local.get 1 drop
      #|    i32.const 7
      #|    call $sink))
      #|
    ),
  )
  let call_types = msf_build_call_type_cache(mod_)
  @debug.assert_eq(call_types.length(), 2)
  @debug.assert_eq(call_types[0], Some(@lib.TypeIdx::new(0U)))
  let (type_idx, func) = match (mod_.func_sec, mod_.code_sec) {
    (Some(@lib.FuncSec([type_idx])), Some(@lib.CodeSec([func]))) =>
      (type_idx, func)
    _ => fail("expected one defined function")
  }
  let summaries = msf_build_function_summaries(
    [type_idx],
    [func],
    msf_build_type_signature_cache(mod_),
  )
  let summary = summaries[0]
  @debug.assert_eq(summary.instruction_count, 6)
  @debug.assert_eq(
    summary.signature,
    Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
  )
}

///|
test "merge-similar-functions incremental validation rejects an invalid changed body" {
  let original = pass_test_module_from_wat("(module (func))")
  let candidate = original.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(9U))]),
      ),
    ]),
  )
  assert_true(
    msf_validate_append_only_candidate_detail(original, candidate) is Err(_),
  )
}

///|
test "merge-similar-functions append-only validation rejects existing element mutation" {
  let original = pass_test_module_from_wat(
    "(module (func) (func) (elem declare func 0))",
  )
  let candidate = pass_test_module_from_wat(
    "(module (func) (func) (elem declare func 1))",
  )
  assert_true(
    msf_validate_append_only_candidate_detail(original, candidate) is Err(_),
  )
}

///|
test "merge-similar-functions reports analysis rewrite and validation timings" {
  let trace : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { trace.push(line) },
    dump_options=HotPerfDumpOptions::new(),
  )
  match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i32)
        #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop
        #|    i32.const 42)
        #|  (func (result i32)
        #|    nop nop nop nop nop nop nop nop nop nop nop nop nop nop
        #|    i32.const 43))
        #|
      ),
      ["merge-similar-functions"],
      options=HotPipelineOptions::new(perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected perf-traced MSF success, got \{err}")
  }
  for
    timer in [
      "detail:msf:build-analysis", "detail:msf:collect-classes", "detail:msf:plan-and-rewrite",
      "detail:msf:validate-candidate",
    ] {
    assert_true(
      trace.any(fn(line) { line.contains("perf:timer name=\{timer}") }),
      msg="missing MSF perf timer \{timer}",
    )
  }
}
