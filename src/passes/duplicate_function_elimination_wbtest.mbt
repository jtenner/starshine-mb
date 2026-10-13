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
  @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x18\x05\x5f\x01\x7f\x00\x5f\x01\x7f\x00\x60\x00\x01\x64\x01\x60\x01\x64\x00\x01\x7f\x60\x00\x01\x7f\x03\x04\x03\x02\x03\x04\x07\x16\x03\x04\x6d\x61\x6b\x65\x00\x00\x04\x72\x65\x61\x64\x00\x01\x04\x74\x65\x73\x74\x00\x02\x0a\x1d\x03\x07\x00\x41\x07\xfb\x00\x01\x0b\x08\x00\x20\x00\xfb\x02\x00\x00\x0b\x0a\x00\x41\x07\xfb\x00\x01\xfb\x14\x00\x0b\x00\x0e\x04\x6e\x61\x6d\x65\x04\x07\x02\x00\x01\x41\x01\x01\x42",
  )
  .unwrap()
  .without_name_sec()
}

///|
test "explicit DFE cleanup replaces redundant primitive GC roots without shifting other types" {
  let input = dfe_test_canonical_primitive_module()
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  let output = dfe_run_module_pass(input)
  @debug.assert_eq(
    output.type_sec.unwrap().0.length(),
    input.type_sec.unwrap().0.length(),
  )
  @debug.assert_eq(output.func_sec, input.func_sec)
  @debug.assert_eq(
    output.type_sec.unwrap().0[1],
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
  let (before, after) = @binary.encoded_module_sizes(input, output).unwrap()
  assert_true(after < before)
  match output.code_sec.unwrap().0[0] {
    @lib.Func(_, @lib.Expr(body)) =>
      @debug.assert_eq(
        body[1],
        @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
      )
  }
}

///|
test "standard shrink final cleanup removes redundant GC roots across public typed exports" {
  let input = dfe_test_canonical_primitive_module()
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(shrink_level=1),
    ["shrink"],
  ).unwrap()
  @debug.assert_eq(
    output.type_sec.unwrap().0[1],
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  @debug.assert_eq(output.func_sec, input.func_sec)
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}

///|
test "canonical GC cleanup intentionally preserves distinguishable recursive group members" {
  let input = @binary.decode_module(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x13\x03\x5f\x01\x7f\x00\x4e\x02\x5f\x01\x7f\x00\x5f\x01\x7e\x00\x60\x00\x01\x7f\x03\x02\x01\x03\x07\x08\x01\x04\x74\x65\x73\x74\x00\x00\x0a\x0c\x01\x0a\x00\x41\x07\xfb\x00\x01\xfb\x14\x00\x0b\x00\x15\x04\x6e\x61\x6d\x65\x04\x0e\x03\x00\x01\x41\x01\x01\x42\x02\x05\x62\x72\x61\x6e\x64",
    )
    .unwrap()
    .without_name_sec()
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  let output = dfe_cleanup_raw_encoding(input)
  @debug.assert_eq(output.type_sec, input.type_sec)
  @debug.assert_eq(output.code_sec, input.code_sec)
}

///|
test "canonical GC cleanup intentionally rejects unsupported array memory type carriers" {
  let base = dfe_test_canonical_primitive_module()
  let types = base.type_sec.unwrap().0[0:2].to_array()
  let array_index = @lib.TypeIdx::new(2U)
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(
          @lib.FieldType::new(
            @lib.StorageType::val_type(@lib.ValType::i32()),
            @lib.Var,
          ),
        ),
      ),
    ),
  )
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [
            @lib.ValType::ref_type(
              @lib.RefType::new(false, @lib.HeapType::new(array_index)),
            ),
          ],
          [@lib.ValType::i32()],
        ),
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(types))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(3U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(9),
            @lib.Instruction::array_store(
              @lib.StoreOp::i32_store(),
              array_index,
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::array_load(@lib.LoadOp::i32_load(), array_index),
          ]),
        ),
      ]),
    )
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  assert_false(dfe_primitive_type_rewrite_supported(input))
  assert_true(
    physical_equal(dfe_cleanup_canonical_primitive_types(input), input),
  )
}

///|
test "fast optimize intentionally leaves GC encoding work to shrinking profiles" {
  let input = dfe_test_canonical_primitive_module()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize"]).unwrap()
  @debug.assert_eq(output.type_sec, input.type_sec)
}

///|
test "shared raw cleanup intentionally defers primitive GC encoding to the size pipeline" {
  let input = dfe_test_canonical_primitive_module()
  @debug.assert_eq(dfe_cleanup_raw_encoding(input).type_sec, input.type_sec)
}

///|
test "preset DFE cleanup intentionally defers primitive GC encoding to the size pipeline" {
  let input = dfe_test_canonical_primitive_module().with_export_sec(
    @lib.ExportSec::new([]),
  )
  let output = dfe_run_module_pass_with_perf(input, None)
  @debug.assert_eq(output.type_sec, input.type_sec)
}

///|
test "canonical GC admission bounds declaration entries together with instructions" {
  let input = dfe_test_canonical_primitive_module()
  assert_false(dfe_primitive_type_rewrite_supported(input, work_limit=12))
  assert_true(dfe_primitive_type_rewrite_supported(input, work_limit=13))
}

///|
test "canonical GC admission includes local runs in its work budget" {
  let input = dfe_test_canonical_primitive_module()
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(_, expr) = funcs[0]
  funcs[0] = @lib.Func::new(@lib.Locals::single(1U, @lib.ValType::i32()), expr)
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  assert_false(dfe_primitive_type_rewrite_supported(input, work_limit=13))
  assert_true(dfe_primitive_type_rewrite_supported(input, work_limit=14))
}

///|
test "canonical GC cleanup repairs typed carriers and retains recursive group identity" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x3d\x08\x5f\x04\x78\x00\x7e\x00\x7d\x00\x7b\x00\x5f\x04\x78\x00\x7e\x00\x7d\x00\x7b\x00\x60\x00\x01\x7f\x5e\x63\x01\x01\x60\x01\x64\x01\x00\x60\x00\x01\x64\x01\x60\x01\x64\x00\x01\x7f\x4e\x02\x5f\x04\x78\x00\x7e\x00\x7d\x00\x7b\x00\x5f\x01\x7e\x00\x03\x08\x07\x05\x06\x02\x02\x02\x02\x02\x04\x05\x01\x63\x01\x00\x01\x0d\x03\x01\x00\x04\x06\x07\x01\x63\x01\x00\xd0\x71\x0b\x07\x5b\x0a\x05\x74\x61\x62\x6c\x65\x01\x00\x0a\x6e\x75\x6c\x6c\x47\x6c\x6f\x62\x61\x6c\x03\x00\x03\x74\x61\x67\x04\x00\x04\x6d\x61\x6b\x65\x00\x00\x04\x72\x65\x61\x64\x00\x01\x03\x72\x75\x6e\x00\x02\x08\x64\x69\x73\x74\x69\x6e\x63\x74\x00\x03\x05\x62\x72\x61\x6e\x64\x00\x04\x09\x61\x72\x72\x61\x79\x4e\x75\x6c\x6c\x00\x05\x09\x74\x61\x62\x6c\x65\x4e\x75\x6c\x6c\x00\x06\x09\x08\x01\x05\x63\x01\x01\xd0\x71\x0b\x0a\x9e\x01\x07\x21\x00\x41\xff\x01\x42\x2a\x43\x45\x23\xc1\x7f\xfd\x0c\x01\x00\x00\x00\x02\x00\x00\x00\x03\x00\x00\x00\x04\x00\x00\x00\xfb\x00\x01\x0b\x22\x00\x20\x00\xfb\x03\x00\x00\x20\x00\xfb\x02\x00\x01\xa7\x73\x20\x00\xfb\x02\x00\x02\xbc\x73\x20\x00\xfb\x02\x00\x03\xfd\x1b\x03\x73\x0b\x11\x01\x01\x63\x01\x02\x05\x10\x00\x0b\x22\x00\xfb\x16\x00\x10\x01\x0b\x07\x00\x10\x00\x10\x00\xd3\x0b\x24\x00\x41\xff\x01\x42\x2a\x43\x45\x23\xc1\x7f\xfd\x0c\x01\x00\x00\x00\x02\x00\x00\x00\x03\x00\x00\x00\x04\x00\x00\x00\xfb\x00\x07\xfb\x14\x00\x0b\x10\x00\x41\x00\x41\x01\xfb\x0a\x03\x00\x41\x00\xfb\x0b\x03\xd1\x0b\x07\x00\x41\x00\x25\x00\xd1\x0b",
  ).unwrap()
  @debug.assert_eq(@validate.validate_module(input), Ok(()))
  let output = dfe_run_module_pass(input)
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
  @debug.assert_eq(output.func_sec, input.func_sec)
  @debug.assert_eq(output.export_sec, input.export_sec)
  let old_types = input.type_sec.unwrap().0
  let new_types = output.type_sec.unwrap().0
  @debug.assert_eq(new_types.length(), old_types.length())
  @debug.assert_eq(
    new_types[1],
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  @debug.assert_eq(new_types[7], old_types[7])
  let (before, after) = @binary.encoded_module_sizes(input, output).unwrap()
  @debug.assert_eq(before - after, 7)
  let @lib.Func(_, @lib.Expr(make)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(make[4], @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)))
}
