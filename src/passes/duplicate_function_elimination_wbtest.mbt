///|
fn dfe_wbtest_sparse_sample_func(unique : Bool) -> @lib.Func {
  let instrs : Array[@lib.Instruction] = Array::make(
    24,
    @lib.Instruction::nop(),
  )
  if unique {
    instrs[4] = @lib.Instruction::unreachable_()
  }
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(instrs))
}

///|
test "duplicate-function-elimination hashes transitive candidates once" {
  let source = StringBuilder::new()
  let prefix =
    #|(module
    #|  (func $leaf0 (result i32) i32.const 1)
    #|  (func $leaf1 (result i32) i32.const 1)
    #|  (func $mid0 (result i32) call $leaf0)
    #|  (func $mid1 (result i32) call $leaf1)
    #|  (func $top0 (result i32) call $mid0)
    #|  (func $top1 (result i32) call $mid1)
  source.write_string(prefix)
  for value in 2..<66 {
    source.write_string(" (func i32.const \{value} drop)")
  }
  let suffix =
    #|  (export "top0" (func $top0))
    #|  (export "top1" (func $top1))
    #|)
  source.write_string(suffix)
  let mod_ = pass_test_module_from_wat(source.to_string())
  let hash_visits = [0]
  let normalization_visits = [0]
  let result = dfe_eliminate_duplicate_functions(
    mod_,
    hash_visits=Some(hash_visits),
    normalization_visits=Some(normalization_visits),
  )
  assert_true(result.changed)
  @debug.assert_eq(hash_visits[0], 70)
  @debug.assert_eq(normalization_visits[0], 4)
  // The leaf and mid pairs merge transitively. The top pair stays distinct:
  // both functions are exported, so merging them would collapse two
  // host-observable function identities.
  match result.mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 68)
    None => fail("expected compacted code section")
  }
  match result.mod_.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(first))),
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(second))),
        ]
      )
    ) => assert_true(first != second)
    _ => fail("expected two distinct exported transitive tops")
  }
}

///|
test "duplicate-function-elimination preflights unreachable debris" {
  assert_true(
    dfe_instrs_need_unreachable_debris_cleanup([
      @lib.Instruction::unreachable_(),
      @lib.Instruction::drop(),
      @lib.Instruction::unreachable_(),
    ]),
  )
  assert_true(
    dfe_instrs_need_unreachable_debris_cleanup([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::unreachable_(),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  assert_false(
    dfe_instrs_need_unreachable_debris_cleanup([
      @lib.Instruction::i32_const(@lib.I32::new(1)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "duplicate-function-elimination shape hash ignores only remappable targets" {
  let call0 = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
  )
  let call1 = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
  )
  let trap = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  let max_func_target = [-1]
  @debug.assert_eq(
    dfe_function_shape_hash_no_annotations(
      0,
      call0,
      max_func_target=Some(max_func_target),
    ),
    dfe_function_shape_hash_no_annotations(0, call1),
  )
  @debug.assert_eq(max_func_target[0], 0)
  assert_true(
    dfe_function_shape_hash_no_annotations(0, call0) !=
    dfe_function_shape_hash_no_annotations(0, trap),
  )
  let type_flags = [false]
  ignore(
    dfe_function_shape_hash_no_annotations(
      0,
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
            @lib.Expr::new([]),
          ),
        ]),
      ),
      mentions_type_idxs=Some(type_flags),
    ),
  )
  assert_true(type_flags[0])
  let cleanup_flags = [false]
  ignore(
    dfe_function_shape_hash_no_annotations(
      0,
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::unreachable_(),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
      needs_debris_cleanup=Some(cleanup_flags),
    ),
  )
  assert_true(cleanup_flags[0])
}

///|
test "duplicate-function-elimination hashes full function bodies, not only sampled instructions" {
  let left = dfe_wbtest_sparse_sample_func(false)
  let right = dfe_wbtest_sparse_sample_func(true)
  assert_false(left == right)
  assert_true(
    dfe_function_shape_hash_no_annotations(0, left) !=
    dfe_function_shape_hash_no_annotations(0, right),
  )
}

///|
fn dfe_test_canonical_primitive_module() -> @lib.Module {
  @binary.decode_module(b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x18\x05\x5f\x01\x7f\x00\x5f\x01\x7f\x00\x60\x00\x01\x64\x01\x60\x01\x64\x00\x01\x7f\x60\x00\x01\x7f\x03\x04\x03\x02\x03\x04\x07\x16\x03\x04\x6d\x61\x6b\x65\x00\x00\x04\x72\x65\x61\x64\x00\x01\x04\x74\x65\x73\x74\x00\x02\x0a\x1d\x03\x07\x00\x41\x07\xfb\x00\x01\x0b\x08\x00\x20\x00\xfb\x02\x00\x00\x0b\x0a\x00\x41\x07\xfb\x00\x01\xfb\x14\x00\x0b\x00\x0e\x04\x6e\x61\x6d\x65\x04\x07\x02\x00\x01\x41\x01\x01\x42").unwrap().without_name_sec()
}

///|
test "raw encoding cleanup compacts canonical equal primitive GC singleton declarations" {
  let input = dfe_test_canonical_primitive_module()
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  let output = dfe_cleanup_raw_encoding(input)
  @debug.assert_eq(output.type_sec.unwrap().0.length(), input.type_sec.unwrap().0.length() - 1)
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
  let (before, after) = @binary.encoded_module_sizes(input, output).unwrap()
  assert_true(after < before)
  match output.code_sec.unwrap().0[0] {
    @lib.Func(_, @lib.Expr(body)) => @debug.assert_eq(body[1], @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)))
  }
}

///|
test "standard optimize final cleanup compacts canonical equal GC types across public typed exports" {
  let input = dfe_test_canonical_primitive_module()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize"]).unwrap()
  assert_true(output.type_sec.unwrap().0.length() < input.type_sec.unwrap().0.length())
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}

///|
test "canonical GC cleanup intentionally preserves distinguishable recursive group members" {
  let input = @binary.decode_module(b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x13\x03\x5f\x01\x7f\x00\x4e\x02\x5f\x01\x7f\x00\x5f\x01\x7e\x00\x60\x00\x01\x7f\x03\x02\x01\x03\x07\x08\x01\x04\x74\x65\x73\x74\x00\x00\x0a\x0c\x01\x0a\x00\x41\x07\xfb\x00\x01\xfb\x14\x00\x0b\x00\x15\x04\x6e\x61\x6d\x65\x04\x0e\x03\x00\x01\x41\x01\x01\x42\x02\x05\x62\x72\x61\x6e\x64").unwrap().without_name_sec()
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  let output = dfe_cleanup_raw_encoding(input)
  @debug.assert_eq(output.type_sec, input.type_sec)
  @debug.assert_eq(output.code_sec, input.code_sec)
}
