///|
test "DAE dead suffix evidence retains the source body and explicit boundary" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
  ]
  let evidence = dae_dead_suffix_evidence(body).unwrap()
  assert_eq(evidence.root_idx, 2)
  assert_eq(evidence.suffix_start, 3)
  assert_true(physical_equal(evidence.body, body))
  assert_eq(evidence.body[3], @lib.Instruction::call(@lib.FuncIdx::new(1U)))
  assert_eq(body.length(), 6)
}

///|
test "DAE dead suffix queries start after the trap and preserve dropped-call counts" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
    ),
  ]
  assert_eq(dae_count_dead_suffix_direct_call_to(body, 1), 1)
  assert_eq(dae_count_dead_suffix_direct_call_to(body, 2), 1)
  assert_true(dae_dead_suffix_has_other_call(body, 1))
  assert_false(dae_dead_suffix_has_dropped_direct_call_to(body, 1))
  assert_true(dae_dead_suffix_has_undropped_direct_call_to(body, 1))
  assert_true(dae_dead_suffix_has_dropped_direct_call_to(body, 2))
  assert_false(dae_dead_suffix_has_undropped_direct_call_to(body, 2))
  assert_true(dae_dead_suffix_evidence([@lib.Instruction::nop()]) is None)
  let at_end = dae_dead_suffix_evidence([@lib.Instruction::unreachable_()]).unwrap()
  assert_eq(at_end.suffix_start, 1)
  assert_eq(dae_count_dead_suffix_direct_call_to(at_end.body, 1), 0)
}

///|
test "DAE borrowed suffix keeps empty operand origins and nested call classifications" {
  let mod_ = pass_test_module_from_wat(
    "(module (func $callee (param i32) (result i32) local.get 0) (func $side (param i32) (result i32) local.get 0) (func (param i32) local.get 0 drop unreachable local.get 0 call $side call $callee block local.get 0 call $callee drop end drop))",
  )
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[2]
  let copied = dae_dead_suffix_before_borrow(body).unwrap().body
  let types = mod_.func_sec.unwrap().0
  for escaped in [[false, false, true], [false, true, true]] {
    assert_eq(
      dae_dead_suffix_has_undropped_self_call_param_operand(
        body, 0, 1, mod_, types,
      ),
      dae_instrs_have_undropped_call_to_with_param_operand(
        copied, 0, 1, mod_, types,
      ),
    )
    assert_eq(
      dae_dead_suffix_has_private_result_call_other_than(
        body, 0, mod_, types, escaped,
      ),
      dae_instrs_have_private_result_direct_call_other_than(
        copied, 0, mod_, types, escaped,
      ),
    )
    let preserve = [false]
    dae_collect_self_call_operand_param_gets(
      copied, 0, 1, mod_, types, escaped, preserve, true,
    )
    assert_eq(
      dae_collect_dead_suffix_self_operand_params(
        mod_.code_sec.unwrap().0[2],
        0,
        1,
        mod_,
        types,
        escaped,
        true,
      ),
      preserve,
    )
    let lhs = dae_dead_suffix_escaped_result_direct_call_evidence(
      body, mod_, types, escaped,
    ).unwrap()
    let rhs = dae_escaped_result_direct_call_evidence(
      copied, mod_, types, escaped,
    )
    assert_eq(
      lhs.has_dropped_escaped_result_call,
      rhs.has_dropped_escaped_result_call,
    )
    assert_eq(
      lhs.has_undropped_escaped_result_call,
      rhs.has_undropped_escaped_result_call,
    )
  }
  let original = @binary.encode_module(mod_).unwrap()
  for pass in ["dae", "dae-optimizing"] {
    let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
  }
  assert_eq(@binary.encode_module(mod_).unwrap(), original)
}
