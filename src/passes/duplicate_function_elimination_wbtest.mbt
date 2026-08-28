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
  @debug.assert_eq(normalization_visits[0], 6)
  match result.mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 67)
    None => fail("expected compacted code section")
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
