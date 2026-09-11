///|
test "Binaryen 132 descriptor bottom inputs remain valid through type and cleanup passes" {
  // Adapted from v132 test/lit/passes/local-subtyping-desc.wast (#8975).
  let source =
    #|(module
    #| (rec
    #|  (type $s (sub (descriptor $d) (struct)))
    #|  (type $d (sub (describes $s) (struct (field i32)))))
    #| (func (result (ref null $s))
    #|  (local $value (ref $s))
    #|  (unreachable)))
  // Keep the direct core fixture as a separate check from descriptor text
  // parsing, which is supported by the Binaryen 132 adapter.
  let original = pass_test_module_from_wat(source)
  let source_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let descriptor_ref = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  let descriptor = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::ref_type(descriptor_ref)),
    @lib.Expr::new([
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::ref_as_non_null(),
    ]),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::ref_type(source_ref)),
      @lib.Expr::new([
        @lib.Instruction::ref_null(source_ref.get_heap_type()),
        descriptor,
        @lib.Instruction::br_on_cast_desc_eq(
          @lib.LabelIdx::new(0U),
          source_ref,
          source_ref,
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ])
  let original = match original.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) =>
      original.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, body)]))
    _ => fail("expected one descriptor fixture function")
  }
  for
    passes in [
      ["local-subtyping"],
      ["vacuum"],
      ["optimize-casts"],
      ["local-subtyping", "vacuum", "dead-code-elimination"],
    ] {
    let optimized = match
      run_hot_pipeline(original, HotPipelineOptions::new(), passes) {
      Ok(value) => value
      Err(err) => fail("expected descriptor branch pipeline validity: \{err}")
    }
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) => fail("descriptor result refinement must validate: \{err}")
    }
    if passes == ["local-subtyping"] {
      let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
      @debug.assert_eq(
        locals.at(0),
        Some(
          @lib.ValType::ref_type(
            @lib.RefType::new(
              false,
              @lib.HeapType::abs(@lib.AbsHeapType::none()),
            ),
          ),
        ),
      )
      assert_true(
        body[0]
        is @lib.Block(@lib.ValTypeBlockType(@lib.RefTypeValType(result_ref)), _) &&
        !result_ref.is_nullable() &&
        result_ref.get_heap_type() ==
        @lib.HeapType::abs(@lib.AbsHeapType::none()),
      )
    }
  }
}

///|
test "descriptor GenValid bottom locals validate through refinement and cleanup" {
  let profile = @validate.gen_valid_profile_by_name(
    "binaryen132-descriptor-branches",
  ).unwrap()
  for seed in [32UL, 33UL, 34UL, 35UL, 48UL, 49UL, 50UL, 51UL] {
    let original = @validate.gen_valid_module_from_seed(
        seed,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    for
      passes in [
        ["local-subtyping"],
        ["local-subtyping", "vacuum", "dead-code-elimination"],
        ["dae2"],
        ["optimize-casts"],
      ] {
      let output = run_hot_pipeline(original, HotPipelineOptions::new(), passes).unwrap()
      assert_true(@validate.validate_module(output) is Ok(_))
      if passes == ["local-subtyping"] && seed < 48UL {
        let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
        @debug.assert_eq(
          locals.at(0),
          Some(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                false,
                @lib.HeapType::abs(@lib.AbsHeapType::none()),
              ),
            ),
          ),
        )
      }
    }
  }
}

///|
test "descriptor bottom recomputation preserves multivalue payload and operand calls" {
  for operation in ["br_on_cast_desc_eq", "br_on_cast_desc_eq_fail"] {
    let source = "(module (rec (type $s (sub (descriptor $d) (struct))) (type $d (sub (describes $s) (struct)))) (import \"env\" \"payload\" (func $payload (result i32))) (import \"env\" \"source\" (func $source (result (ref null $s)))) (import \"env\" \"descriptor\" (func $descriptor)) (func (result i32 (ref null $s)) (block $exit (result i32 (ref null $s)) (call $payload) (call $source) (block (result (ref $d)) (call $descriptor) (ref.as_non_null (ref.null none))) (\{operation} $exit (ref null $s) (ref $s)))))"
    let output = pass_test_run_pipeline(source, ["local-subtyping"]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(3U))
    let calls : Array[Int] = []
    for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
      let data = @ir.hot_node_get(hot, node)
      if data.op is @ir.HotOp::Call {
        calls.push(data.imm0)
      }
    }
    @debug.assert_eq(calls, [0, 1, 2])
  }
}

///|
test "descriptor recomputation retains reachable branches through a descriptor block exit" {
  let source =
    #|(module
    #| (rec (type $s (sub (descriptor $d) (struct)))
    #|      (type $d (sub (describes $s) (struct))))
    #| (func (param (ref null $s) (ref $d)) (result (ref null $s))
    #|  (block $exit (result (ref null $s))
    #|   (br_on_cast_desc_eq $exit (ref null $s) (ref $s)
    #|    (local.get 0)
    #|    (block $desc (result (ref $d))
    #|      (br $desc (local.get 1))
    #|      (unreachable))))))
  let output = pass_test_run_pipeline(source, ["local-subtyping"]).unwrap()
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let mut branches = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    if @ir.hot_node_exact_instr(hot, node) is Some(@lib.BrOnCastDescEq(_, _, _)) {
      branches += 1
    }
  }
  assert_eq(branches, 1)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "nested descriptor GenValid labels validate through active control and local passes" {
  let profile = @validate.gen_valid_profile_by_name(
    "binaryen132-descriptor-branches",
  ).unwrap()
  for seed in [64UL, 65UL, 96UL, 97UL] {
    let input = @validate.gen_valid_module_from_seed(
        seed,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    for
      pass in [
        "ssa", "ssa-nomerge", "vacuum", "local-subtyping", "optimize-casts", "optimize-instructions",
        "constraint-analysis", "dae2",
      ] {
      let output = match
        run_hot_pipeline(input, HotPipelineOptions::new(), [pass]) {
        Ok(output) => output
        Err(err) => fail("nested descriptor seed=\{seed} pass=\{pass}: \{err}")
      }
      assert_true(@validate.validate_module(output) is Ok(_))
      let decoded = @binary.decode_module(
        @binary.encode_module(output).unwrap(),
      ).unwrap()
      assert_true(@validate.validate_module(decoded) is Ok(_))
    }
  }
}

///|
test "descriptor unreachable source retains a non-null bottom after local subtyping" {
  let profile = @validate.gen_valid_profile_by_name(
    "binaryen132-descriptor-branches",
  ).unwrap()
  for
    seed in [
      16UL, 17UL, 18UL, 19UL, 24UL, 25UL, 26UL, 27UL, 80UL, 81UL, 82UL, 83UL, 88UL,
      89UL, 90UL, 91UL,
    ] {
    let original = @validate.gen_valid_module_from_seed(
        seed,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    let output = match
      run_hot_pipeline(original, HotPipelineOptions::new(), ["local-subtyping"]) {
      Ok(output) => output
      Err(err) => fail("seed \{seed}: \{err}")
    }
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}
