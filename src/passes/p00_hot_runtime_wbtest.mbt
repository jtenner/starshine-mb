///|
// Dedicated native lane: the TypeScript runner supplies exact WAT fixtures,
// then executes these raw outputs to check effects and traps across processes.
#skip
test "forced HOT DAE2 typed entry runtime fixtures remain valid and prune unused params" {
  for mode in ["dae2", "dae2-optimizing"] {
    for
      name in [
        "typed-discard", "typed-live-branch", "typed-partial-tuple", "typed-mixed-prefix",
        "typed-div-trap", "typed-carried-argument",
      ] {
      let stem = ".tmp/p00-hot-fallback-runtime/" + name + "-" + mode
      let input = pass_test_module_from_wat(
        @sfs.read_file_sync(stem + ".wat").unwrap(),
      )
      let imported = dae_imported_func_count(input)
      let @lib.FuncType(before, _) = @validate.Env::new()
        .with_module(input)
        .get_functype_by_funcidx(@lib.FuncIdx::new(imported.to_uint()))
        .unwrap()
      let output = dae2_run_module_pass(
        input,
        mode == "dae2-optimizing",
        raw_analysis=false,
        raw_conditionals=false,
        raw_rewrite=false,
        stack_suffix_rewrite=false,
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let @lib.FuncType(after, _) = @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(imported.to_uint()))
        .unwrap()
      assert_true(after.length() < before.length())
      let bytes = @binary.encode_module(output).unwrap()
      @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      @sfs.write_file_bytes(stem + ".wasm", bytes).unwrap()
    }
  }
}

///|
#skip
test "direct HOT and direct pass runtime fixtures validate without print repair" {
  let dir = ".tmp/p00-hot-fallback-runtime/"
  for name in ["oi-order", "merge-blocks"] {
    let input = pass_test_module_from_wat(
      @sfs.read_file_sync(dir + name + ".wat").unwrap(),
    )
    let imported = dae_imported_func_count(input)
    let module_ctx = @ir.hot_module_context_from_module(input)
    let before : Array[@lib.Func] = []
    let after : Array[@lib.Func] = []
    let count = input.code_sec.unwrap().0.length()
    for index in 0..<count {
      let func = @ir.hot_lift_func(
        input,
        @lib.FuncIdx::new((imported + index).to_uint()),
      )
      before.push(@ir.hot_lower_func(func))
      let descriptor = if name == "oi-order" {
        optimize_instructions_descriptor()
      } else {
        merge_blocks_descriptor()
      }
      let ctx = HotPassContext::new(
        descriptor,
        @ir.HotAnalysisCache::new(),
        HotPipelineVerifyPolicy::after_each_pass(),
        false,
        fn(_) { () },
        module_ctx=Some(module_ctx),
      )
      ignore(
        if name == "oi-order" {
          optimize_instructions_run(ctx, func)
        } else {
          merge_blocks_run(ctx, func)
        },
      )
      @ir.hot_verify_core(func).unwrap()
      @ir.hot_verify_control(func).unwrap()
      if name == "oi-order" {
        for node in 0..<@ir.hot_node_count(func) {
          if @ir.hot_node_is_live(func, node) {
            assert_true(
              @ir.hot_node_exact_instr(func, node) !=
              Some(@lib.Instruction::i32_and()),
            )
          }
        }
      }
      after.push(@ir.hot_lower_func(func))
    }
    for (stage, bodies) in [("before", before), ("after", after)] {
      let output = input.with_code_sec(@lib.CodeSec::new(bodies))
      @validate.validate_module(output).unwrap()
      let bytes = @binary.encode_module(output).unwrap()
      @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      @sfs.write_file_bytes(dir + name + "." + stage + ".wasm", bytes).unwrap()
    }
  }
  for
    (name, source) in [
      ("typed-live", "typed-live-branch-dae2"),
      ("typed-mixed-suffix", "typed-mixed-suffix"),
      ("typed-mixed-suffix-triple", "typed-mixed-suffix-triple"),
    ] {
    let input = pass_test_module_from_wat(
      @sfs.read_file_sync(dir + source + ".wat").unwrap(),
    )
    let imported = dae_imported_func_count(input)
    for captures in [false, true] {
      let bodies : Array[@lib.Func] = []
      for index in 0..<input.code_sec.unwrap().0.length() {
        let func = @ir.hot_lift_func_with_context_result(
          input,
          @lib.FuncIdx::new((imported + index).to_uint()),
          @ir.hot_module_context_from_module(input),
          capture_stack_locals=captures,
          materialize_multi_values=captures,
        ).unwrap()
        bodies.push(@ir.hot_lower_func(func))
      }
      let output = input.with_code_sec(@lib.CodeSec::new(bodies))
      @validate.validate_module(output).unwrap()
      let bytes = @binary.encode_module(output).unwrap()
      @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      @sfs.write_file_bytes(
        dir + name + ".direct-" + captures.to_string() + ".wasm",
        bytes,
      ).unwrap()
    }
  }
}

///|
#skip
test "direct SSA no-merge branch operand runtime fixture" {
  let (func, _, _, _, _, _) = p00_ssa_branch_operand_fixture()
  let shell = pass_test_module_from_wat(
    "(module (func (export \"f\") (param i32) (result i32) (local i32 i32) i32.const 0))",
  )
  let before = @ir.hot_lower_func(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  @ir.hot_verify_all_or_abort(func)
  for (stage, body) in [("before", before), ("after", @ir.hot_lower_func(func))] {
    let output = shell.with_code_sec(@lib.CodeSec::new([body]))
    @validate.validate_module(output).unwrap()
    let bytes = @binary.encode_module(output).unwrap()
    @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
    @sfs.write_file_bytes(
      ".tmp/p00-hot-fallback-runtime/ssa-branch-operand." + stage + ".wasm",
      bytes,
    ).unwrap()
  }
}

///|
#skip
test "direct raw scratch runtime fixtures retain appended locals" {
  let dir = ".tmp/p00-hot-fallback-runtime/"
  for
    (name, appended) in [
      ("scratch-appended-block", 1),
      ("scratch-appended-loop", 2),
    ] {
    let input = pass_test_module_from_wat(
      @sfs.read_file_sync(dir + name + ".wat").unwrap(),
    )
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let locals = @lib.Locals::from_types([@lib.ValType::i32()])
    let extra = Array::make(appended, @lib.ValType::i32())
    let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
      body,
      [],
      locals,
      extra,
    )
    let output = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()] + extra),
          @lib.Expr::new(rewritten),
        ),
      ]),
    )
    for (stage, module) in [("before", input), ("after", output)] {
      @validate.validate_module(module).unwrap()
      let bytes = @binary.encode_module(module).unwrap()
      @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      @sfs.write_file_bytes(dir + name + "." + stage + ".wasm", bytes).unwrap()
    }
  }
}
