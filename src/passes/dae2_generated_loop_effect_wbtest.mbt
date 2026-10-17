///|
fn dae2_generated_loop_loads(body : Array[@lib.Instruction]) -> Int32 {
  let mut loads = 0
  for instr in body {
    match instr {
      @lib.I32Load(_) => loads += 1
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        loads += dae2_generated_loop_loads(child)
      _ => ()
    }
  }
  loads
}

///|
test "DAE2 generated loop effects and trapping prefixes reach optimizing cleanup" {
  let profile = @validate.gen_valid_profile_by_name("dae2-control-flow").unwrap()
  for seed in [0UL, 8UL, 16UL, 24UL] {
    let input = @validate.gen_valid_module_from_seed(
        seed,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    assert_true(
      input.global_sec is Some(_),
      msg="missing generated observable call effect",
    )
    let saved = @binary.encode_module(input).unwrap()
    let source = input.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(source_body)) = source[source.length() - 1]
    assert_true(
      source_body.any(fn(op) { op is @lib.Loop(@lib.VoidBlockType, _) }),
    )
    let loads = dae2_generated_loop_loads(source_body)
    assert_true(loads > 0)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "dae2-optimizing",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .resolve_functype(output.func_sec.unwrap().0[0])
      .unwrap(),
      @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    )
    let bodies = output.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(body)) = bodies[bodies.length() - 1]
    assert_eq(
      dae2_loop_effect_call_count(body),
      1,
      msg="generated seed=\{seed}",
    )
    assert_eq(
      dae2_generated_loop_loads(body),
      loads,
      msg="generated traps seed=\{seed}",
    )
    assert_eq(output.global_sec, input.global_sec)
    assert_eq(output.mem_sec, input.mem_sec)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
