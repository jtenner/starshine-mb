///|
fn vacuum_pr9155_fixture(result_type : String) -> @lib.Module {
  pass_test_module_from_wat(
    "(module (type $S (struct (field i32))) (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"left\" (func $left (result \{result_type}))) (import \"e\" \"right\" (func $right (result \{result_type}))) (func (export \"run\") (drop (if (result \{result_type}) (call $cond) (then (call $left)) (else (call $right))))))",
  )
}

///|
fn vacuum_pr9155_body(module_ : @lib.Module) -> Array[@lib.Instruction] {
  let @lib.Func(_, @lib.Expr(body)) = module_.code_sec.unwrap().0[0]
  body
}

///|
fn vacuum_pr9155_assert_sunk(body : Array[@lib.Instruction]) -> Unit raise {
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::call(@lib.FuncIdx::new(1U)), @lib.Instruction::drop()],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::drop(),
      ]),
    ),
  ])
}

///|
test "vacuum HOT sinks dropped concrete i32 f64 and GC if arms" {
  for result_type in ["i32", "f64", "(ref null $S)"] {
    let input = vacuum_pr9155_fixture(result_type)
    let saved = @binary.encode_module(input).unwrap()
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(3U))
    let roots = @ir.HotRegionRef::root()
    let drop = @ir.hot_region_get(func, roots, 0)
    let if_id = @ir.hot_child_get(func, drop, 0)
    let ctx = HotPassContext::new(
      @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
      @ir.HotAnalysisCache::new(),
      HotPipelineVerifyPolicy::after_each_pass(),
      false,
      fn(_) { () },
    )
    assert_true(
      hot_pass_vacuum_sink_drop_into_if_arms(ctx, func, roots, 0, if_id),
    )
    @ir.hot_verify_all_or_abort(func)
    let @lib.Func(_, @lib.Expr(body)) = @ir.hot_lower_func(func)
    vacuum_pr9155_assert_sunk(body)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "vacuum raw preclean sinks dropped concrete i32 f64 and GC if arms" {
  for result_type in ["i32", "f64", "(ref null $S)"] {
    let input = vacuum_pr9155_fixture(result_type)
    let saved = @binary.encode_module(input).unwrap()
    let (body, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
      vacuum_pr9155_body(input),
      Some(@ir.hot_module_context_from_module(input)),
    )
    assert_true(changed)
    vacuum_pr9155_assert_sunk(body)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "vacuum guarded raw admission resolves an indexed single-result if after nop cleanup" {
  let input = pass_test_module_from_wat(
    "(module (type $arm (func (result i32))) (import \"e\" \"cond\" (func $cond (type $arm))) (import \"e\" \"left\" (func $left (type $arm))) (import \"e\" \"right\" (func $right (type $arm))) (func (export \"run\") (local i32) nop i32.const 7 local.set 0 call $cond if (type $arm) call $left else call $right end drop))",
  )
  assert_true(
    vacuum_pr9155_body(input)[4] is @lib.If(@lib.TypeIdxBlockType(_), _, _),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
  @validate.validate_module(output).unwrap()
  let body = vacuum_pr9155_body(output)
  assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(7)))
  assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  let tail : Array[@lib.Instruction] = []
  for idx in 2..<body.length() {
    tail.push(body[idx])
  }
  vacuum_pr9155_assert_sunk(tail)
}

///|
test "vacuum public pipeline keeps concrete arm drops sunk after cleanup" {
  for result_type in ["i32", "f64", "(ref null $S)"] {
    let input = vacuum_pr9155_fixture(result_type)
    let saved = @binary.encode_module(input).unwrap()
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
    @validate.validate_module(output).unwrap()
    vacuum_pr9155_assert_sunk(vacuum_pr9155_body(output))
    let again = run_hot_pipeline(output, HotPipelineOptions::new(), ["vacuum"]).unwrap()
    assert_eq(
      @binary.encode_module(again).unwrap(),
      @binary.encode_module(output).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "vacuum sinks drops after each arm's ordered side effects" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"tick\" (func $tick)) (import \"e\" \"left\" (func $left (result i32))) (import \"e\" \"right\" (func $right (result i32))) (func (export \"run\") (drop (if (result i32) (call $cond) (then (call $tick) (call $left)) (else (call $tick) (call $right))))))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(4U))
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let roots = @ir.HotRegionRef::root()
  let drop = @ir.hot_region_get(func, roots, 0)
  assert_true(
    hot_pass_vacuum_sink_drop_into_if_arms(
      ctx,
      func,
      roots,
      0,
      @ir.hot_child_get(func, drop, 0),
    ),
  )
  @ir.hot_verify_all_or_abort(func)
  let @lib.Func(_, @lib.Expr(direct_body)) = @ir.hot_lower_func(func)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
  @validate.validate_module(output).unwrap()
  let expected = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::drop(),
      ],
      Some([
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::drop(),
      ]),
    ),
  ]
  assert_eq(direct_body, expected)
  assert_eq(vacuum_pr9155_body(output), expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "vacuum preserves potentially trapping dropped concrete arm expressions" {
  let output = pass_test_run_pipeline(
    "(module (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"left\" (func $left (result i32))) (import \"e\" \"right\" (func $right (result i32))) (func (export \"run\") (drop (if (result i32) (call $cond) (then (i32.div_s (call $left) (call $right))) (else (call $right))))))",
    ["vacuum"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let body = vacuum_pr9155_body(output)
  match body[1] {
    @lib.If(@lib.VoidBlockType, then_body, Some(else_body)) => {
      assert_eq(then_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
      ])
      assert_eq(else_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::drop(),
      ])
    }
    _ => fail("expected a void conditional retaining the trapping division")
  }
}

///|
test "vacuum preserves null traps in dropped non-null GC if arms" {
  let output = pass_test_run_pipeline(
    "(module (type $S (struct (field i32))) (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"left\" (func $left (result (ref null $S)))) (import \"e\" \"right\" (func $right (result (ref null $S)))) (func (export \"run\") (drop (if (result (ref $S)) (call $cond) (then (ref.as_non_null (call $left))) (else (ref.as_non_null (call $right)))))))",
    ["vacuum"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  match vacuum_pr9155_body(output)[1] {
    @lib.If(@lib.VoidBlockType, then_body, Some(else_body)) => {
      assert_eq(then_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
      ])
      assert_eq(else_body, [
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
      ])
    }
    _ => fail("expected a void conditional retaining both GC null checks")
  }
}

///|
test "vacuum sunk drops expose nested conditional and pure-arm cleanup" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"probe\" (func $probe (result i32))) (import \"e\" \"right\" (func $right (result i32))) (func (export \"run\") (drop (if (result i32) (call $cond) (then (if (result i32) (call $probe) (then (i32.const 10)) (else (i32.const 20)))) (else (call $right))))))",
  )
  let (raw, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    vacuum_pr9155_body(input),
    Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(changed)
  vacuum_pr9155_assert_sunk(raw)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
  @validate.validate_module(output).unwrap()
  vacuum_pr9155_assert_sunk(vacuum_pr9155_body(output))
}

///|
test "vacuum direct HOT cleanup revisits drops sunk into nested concrete arms" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"probe\" (func $probe (result i32))) (import \"e\" \"right\" (func $right (result i32))) (func (export \"run\") (drop (if (result i32) (call $cond) (then (if (result i32) (call $probe) (then (i32.const 10)) (else (i32.const 20)))) (else (call $right))))))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(3U))
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum", requires=[], invalidates=[]),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  assert_true(
    hot_pass_remove_region_nops(
      ctx,
      func,
      @ir.HotRegionRef::root(),
      Array::make(@ir.hot_node_count(func), false),
    ),
  )
  @ir.hot_verify_all_or_abort(func)
  let @lib.Func(_, @lib.Expr(body)) = @ir.hot_lower_func(func)
  vacuum_pr9155_assert_sunk(body)
}

///|
test "vacuum preserves the unreachable arm when sinking a concrete arm drop" {
  for unreachable_then in [false, true] {
    let then_wat = if unreachable_then { "unreachable" } else { "call $value" }
    let else_wat = if unreachable_then { "call $value" } else { "unreachable" }
    let output = pass_test_run_pipeline(
      "(module (import \"e\" \"cond\" (func $cond (result i32))) (import \"e\" \"value\" (func $value (result i32))) (func (export \"run\") call $cond if (result i32) \{then_wat} else \{else_wat} end drop))",
      ["vacuum"],
    ).unwrap()
    @validate.validate_module(output).unwrap()
    match vacuum_pr9155_body(output)[1] {
      @lib.If(@lib.VoidBlockType, then_body, Some(else_body)) => {
        let unreachable_body = if unreachable_then {
          then_body
        } else {
          else_body
        }
        let concrete_body = if unreachable_then { else_body } else { then_body }
        assert_eq(unreachable_body, [@lib.Instruction::unreachable_()])
        assert_eq(concrete_body, [
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::drop(),
        ])
      }
      _ => fail("expected a void conditional with its unreachable arm intact")
    }
  }
}
