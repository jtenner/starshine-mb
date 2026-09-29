///|
fn cl_control_nested_fixture(depth : Int) -> @lib.Instruction {
  let mut instr = @lib.Instruction::return_()
  for index = 0; index < depth; index = index + 1 {
    instr = @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([instr]),
    )
  }
  instr
}

///|
test "coalesce nested control queries visit each instruction once" {
  let instr = cl_control_nested_fixture(24)
  let visits = [0]
  assert_true(
    cl_instr_never_falls_through(instr, instruction_visits=Some(visits)),
  )
  assert_true(visits[0] <= 25)
  assert_eq(instr, cl_control_nested_fixture(24))
}

///|
test "coalesce control summary preserves branch depths sentinels and catch targets" {
  let fixtures = [
    "(module (func block block return end end))", "(module (func block block br 1 unreachable end unreachable end))",
    "(module (func block block br 0 unreachable end unreachable end))", "(module (func (param i32) block local.get 0 if return else br 1 end end))",
    "(module (func (param i32) block local.get 0 if br 0 else return end unreachable end))",
    "(module (func block block i32.const 0 br_table 0 1 end end))", "(module (tag) (func block try_table (catch_all 0) return end end))",
    "(module (tag) (func (block (try (do (return)) (catch_all (br 1))))))", "(module (func block loop br 0 end end))",
  ]
  for wat in fixtures {
    let mod_ = match
      @wast.wast_to_binary_module(wat, filename="control-summary.wat") {
      Ok(module_) => module_
      Err(error) => fail("parse: \{wat}: \{error}")
    }
    match @validate.validate_module(mod_) {
      Ok(_) => ()
      Err(error) => fail("validate: \{wat}: \{error}")
    }
    let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    for instr in body {
      assert_eq(
        cl_instr_never_falls_through(instr),
        cl_instr_never_falls_through_reference(instr),
      )
      for boundary = 0; boundary < 4; boundary = boundary + 1 {
        assert_eq(
          cl_instr_escapes_past_depth(instr, boundary),
          cl_instr_escapes_past_depth_reference(instr, boundary),
        )
      }
    }
    let original = @binary.encode_module(mod_)
    let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), [
      "coalesce-locals",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(mod_), original)
  }
}

///|
test "coalesce action collection builds control facts once for the entire body" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    cl_control_nested_fixture(24),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let actions : Array[CLAction] = []
  let visits = [0]
  cl_collect_instrs(body, actions, 2, control_visits=Some(visits))
  assert_eq(actions.length(), 1)
  assert_eq(actions[0].local_idx, 0)
  assert_true(actions[0].kind is CLActionKind::Get)
  assert_true(visits[0] <= 58)
  assert_eq(body[3], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
}
