///|
fn mass_audit_locals_context(
  descriptor : @ir.HotPassDescriptor,
) -> HotPassContext {
  HotPassContext::new(
    descriptor,
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn mass_audit_locals_typed_block(
  func : @ir.HotFunc,
  effect : Int,
  value : Int,
  body : Int,
) -> Int {
  let block = @ir.hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32()],
    [@lib.ValType::i32()],
    [effect, value, body],
  )
  let node = @ir.hot_node_get(func, block)
  @ir.hot_node_set(
    func,
    block,
    @ir.hot_make_simple_node(node.op, node.ty, node.flags, node.imm0, 2, []),
  )
  ignore(@ir.hot_replace_child_span(func, block, [effect, value, body]))
  block
}

///|
fn mass_audit_locals_add(func : @ir.HotFunc, lhs : Int, rhs : Int) -> Int {
  let node = @ir.hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
  @ir.hot_node_exact_instr_set(func, node, @lib.Instruction::i32_add())
  node
}

///|
// Confirm the failing result before a source change.
test "mass audit RSE keeps a reset after a typed block prefix writes the local" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let initial = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let prefix_write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let entry = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body = mass_audit_locals_add(
    func,
    entry,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let block = mass_audit_locals_typed_block(func, prefix_write, entry, body)
  let reset = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  for
    root in [
      initial,
      @ir.hot_build_drop(func, block),
      reset,
      @ir.hot_build_local_get(func, 0),
    ] {
    @ir.hot_root_append(func, root)
  }
  @ir.hot_verify_all_or_abort(func)
  let module_ = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))) (func (result i32) (local i32) i32.const 0))",
  )
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()

  ignore(
    hot_pass_run(mass_audit_locals_context(rse_descriptor()), func).unwrap(),
  )

  assert_true(@ir.hot_node_get(func, prefix_write).op is @ir.HotOp::LocalSet)
  assert_true(@ir.hot_node_get(func, reset).op is @ir.HotOp::LocalSet)
  assert_eq(@ir.hot_node_get(func, reset).imm0, 0)
  @ir.hot_verify_all_or_abort(func)
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}

///|
// the value root reads local 0 before its later write.
test "mass audit RSE keeps a write of an older stack captured local value" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let initial_x = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let initial_y = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let captured = @ir.hot_build_local_get(func, 0)
  let overwrite_x = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let write_y = @ir.hot_build_local_set(func, 1, captured)
  for
    root in [
      initial_x,
      initial_y,
      captured,
      overwrite_x,
      write_y,
      @ir.hot_build_local_get(func, 1),
    ] {
    @ir.hot_root_append(func, root)
  }
  @ir.hot_verify_all_or_abort(func)
  let module_ = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32) i32.const 0))",
  )
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()

  ignore(
    hot_pass_run(mass_audit_locals_context(rse_descriptor()), func).unwrap(),
  )

  assert_true(@ir.hot_node_get(func, write_y).op is @ir.HotOp::LocalSet)
  assert_eq(@ir.hot_node_get(func, write_y).imm0, 1)
  assert_eq(@ir.hot_child_get(func, write_y, 0), captured)
  @ir.hot_verify_all_or_abort(func)
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}

///|
// the entry write must end the old x/y value equivalence.
test "mass audit SimplifyLocals sees typed block prefix alias writes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let copy = @ir.hot_build_local_set(func, 1, @ir.hot_build_local_get(func, 0))
  let prefix_write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  let entry = @ir.hot_build_const_i32(func, @lib.I32(7))
  let old_value_read = @ir.hot_build_local_get(func, 1)
  let body = mass_audit_locals_add(
    func,
    entry,
    mass_audit_locals_add(
      func,
      old_value_read,
      @ir.hot_build_local_get(func, 0),
    ),
  )
  let block = mass_audit_locals_typed_block(func, prefix_write, entry, body)
  @ir.hot_root_append(func, copy)
  @ir.hot_root_append(func, block)
  @ir.hot_verify_all_or_abort(func)
  let module_ = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))) (func (param i32) (result i32) (local i32) i32.const 0))",
  )
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()

  ignore(
    simplify_locals_run_equivalent_cleanup(
      mass_audit_locals_context(simplify_locals_descriptor()),
      func,
    ),
  )

  assert_true(@ir.hot_node_get(func, old_value_read).op is @ir.HotOp::LocalGet)
  assert_eq(@ir.hot_node_get(func, old_value_read).imm0, 1)
  @ir.hot_verify_all_or_abort(func)
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}

///|
fn mass_audit_locals_cse_tree() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_mul(),
  ]
}

///|
// a prefix write must stop the older definition from sinking into the body.
test "mass audit SimplifyLocals main cycle keeps the value written by a typed prefix" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let initial = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let prefix_write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let entry = @ir.hot_build_const_i32(func, @lib.I32(9))
  let read = @ir.hot_build_local_get(func, 0)
  let body = mass_audit_locals_add(func, entry, read)
  let block = mass_audit_locals_typed_block(func, prefix_write, entry, body)
  @ir.hot_root_append(func, initial)
  @ir.hot_root_append(func, block)
  @ir.hot_verify_all_or_abort(func)
  let module_ = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))) (func (result i32) (local i32) i32.const 0))",
  )
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
  let detached : Array[Int] = []
  ignore(
    simplify_locals_run_main_cycle(
      mass_audit_locals_context(simplify_locals_descriptor()),
      func,
      true,
      detached,
      SimplifyLocalsPolicy::new(false, true, true),
      false,
    ),
  )
  simplify_locals_delete_detached_nodes(func, detached)
  let read_node = @ir.hot_node_get(func, read)
  match read_node.op {
    @ir.HotOp::LocalGet => assert_eq(read_node.imm0, 0)
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, read_node.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(value)) => assert_eq(value, 2)
        _ => fail("expected the prefix's i32 value")
      }
    _ => fail("expected the prefix local or its constant value")
  }
  @ir.hot_verify_all_or_abort(func)
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}

///|
// verified v133 shares this tree at 17 raw instructions (60 -> 55 bytes).
test "mass audit LocalCSE covers a repeated tree in a 17 instruction region" {
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
  ]
  for _ in 0..<2 {
    for instr in mass_audit_locals_cse_tree() {
      body.push(instr)
    }
  }
  body.push(@lib.Instruction::i32_mul())
  assert_eq(body.length(), 17)
  let (output, changed) = local_cse_run_raw_func_with_params(
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    [@lib.ValType::i32()],
  )
  assert_true(changed)
  let @lib.Func(_, @lib.Expr(instrs)) = output
  let mut add_count = 0
  let mut sub_count = 0
  let mut mul_count = 0
  for instr in instrs {
    match instr {
      @lib.I32Add => add_count += 1
      @lib.I32Sub => sub_count += 1
      @lib.I32Mul => mul_count += 1
      _ => ()
    }
  }
  assert_eq(add_count, 1)
  assert_eq(sub_count, 1)
  assert_eq(mul_count, 2)
  let module_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 0))",
  ).with_code_sec(@lib.CodeSec::new([output]))
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(module_).unwrap()).unwrap(),
  ).unwrap()
}

///|
// the entry tee writes x=2 before the second x-1 condition runs.
test "mass audit HOT LocalCSE sees typed If entry writes before the condition" {
  let module_ = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 i32.const 1 i32.sub drop i32.const 2 local.tee 0 local.get 0 i32.const 1 i32.sub if (type 0) drop i32.const 7 else drop i32.const 9 end))",
  )
  @validate.validate_module(module_).unwrap()
  // Build this valid HOT form directly. The lifter captures the pending tee
  // before the condition's source local.get, which would remove this hazard
  // from the header and test the lift policy instead of the pass traversal.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, earlier, @lib.Instruction::i32_sub())
  @ir.hot_root_append(func, @ir.hot_build_drop(func, earlier))
  let entry = @ir.hot_build_local_tee(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  let condition = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, condition, @lib.Instruction::i32_sub())
  let conditional = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition,
    [
      @ir.hot_build_drop(func, entry),
      @ir.hot_build_const_i32(func, @lib.I32(7)),
    ],
    else_body=Some([
      @ir.hot_build_drop(func, entry),
      @ir.hot_build_const_i32(func, @lib.I32(9)),
    ]),
  )
  let signature = @ir.hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  @ir.hot_control_result_type_set(func, conditional, signature)
  let then_region = @ir.hot_child_get(func, conditional, 1)
  let else_region = @ir.hot_child_get(func, conditional, 2)
  ignore(
    @ir.hot_replace_child_span(func, conditional, [
      condition, then_region, else_region, entry,
    ]),
  )
  @ir.hot_root_append(func, conditional)
  assert_true(@ir.hot_node_get(func, conditional).op is @ir.HotOp::If)
  assert_eq(@ir.hot_child_get(func, conditional, 0), condition)
  assert_eq(@ir.hot_child_get(func, conditional, 3), entry)
  assert_true(@ir.hot_node_get(func, condition).op is @ir.HotOp::Binary)
  assert_true(@ir.hot_node_get(func, entry).op is @ir.HotOp::LocalTee)
  assert_eq(@ir.hot_node_get(func, entry).imm0, 0)
  @ir.hot_verify_all_or_abort(func)
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()

  ignore(
    hot_pass_run(mass_audit_locals_context(local_cse_descriptor()), func).unwrap(),
  )

  // The earlier x-1 value is zero at input x=1. The condition now has x=2.
  assert_eq(@ir.hot_child_get(func, conditional, 0), condition)
  assert_true(@ir.hot_node_get(func, condition).op is @ir.HotOp::Binary)
  assert_eq(
    @ir.hot_node_exact_instr(func, condition),
    Some(@lib.Instruction::i32_sub()),
  )
  assert_eq(@ir.hot_child_get(func, conditional, 3), entry)
  assert_true(@ir.hot_node_get(func, entry).op is @ir.HotOp::LocalTee)
  assert_eq(@ir.hot_node_get(func, entry).imm0, 0)
  @ir.hot_verify_all_or_abort(func)
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}

///|
// unknown values and interned constants need disjoint identities.
test "mass audit CoalesceLocals keeps fresh and constant source identities distinct" {
  let interner = CLValueInterner::new()
  let parameter = interner.fresh()
  let constant = interner.intern("const:i32:7")
  let unknown_write = interner.fresh()
  let second_constant = interner.intern("const:i32:9")
  assert_true(parameter != constant)
  assert_true(parameter != unknown_write)
  assert_true(constant != unknown_write)
  assert_true(second_constant != parameter)
  assert_true(second_constant != unknown_write)
  assert_eq(interner.intern("const:i32:7"), constant)
}

///|
// the constant 7 cannot share an unknown incoming parameter value.
test "mass audit CoalesceLocals records interference despite source identity number overlap" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ]
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 3)
  let matrix = cl_compute_interferences(
    actions,
    cl_compute_liveness(actions, 3),
    Array::make(3, @lib.ValType::i32()),
    2,
  )
  assert_true(cl_bit_matrix_get(matrix, 1, 2))
  let module_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32 i32) (local i32) i32.const 0 i32.const 0))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::single(1U, @lib.ValType::i32()),
        @lib.Expr::new(body),
      ),
    ]),
  )
  @validate.validate_module(module_).unwrap()
}

///|
test "mass repair LocalCSE leaf roots do not consume profitable availability" {
  for write_local in [false, true] {
    let body = mass_audit_locals_cse_tree()
    body.push(@lib.Instruction::drop())
    for value in 0..<65 {
      body.push(@lib.Instruction::i32_const(@lib.I32(value)))
      body.push(@lib.Instruction::drop())
    }
    if write_local {
      body.push(@lib.Instruction::i32_const(@lib.I32(1)))
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
    }
    for instr in mass_audit_locals_cse_tree() {
      body.push(instr)
    }
    let input = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
    let seed = pass_test_module_from_wat(
      "(module (func (param i32) (result i32) i32.const 0))",
    )
    @validate.validate_module(seed.with_code_sec(@lib.CodeSec::new([input]))).unwrap()
    let input_bytes = @binary.encode_module(
      seed.with_code_sec(@lib.CodeSec::new([input])),
    ).unwrap()
    let (output, _) = local_cse_run_raw_func_with_params(input, [
      @lib.ValType::i32(),
    ])
    let @lib.Func(_, @lib.Expr(result)) = output
    assert_eq(
      result.filter(fn(instr) { instr is @lib.I32Mul }).length(),
      if write_local {
        2
      } else {
        1
      },
    )
    let output_bytes = @binary.encode_module(
      seed.with_code_sec(@lib.CodeSec::new([output])),
    ).unwrap()
    if !write_local {
      assert_true(output_bytes.length() < input_bytes.length())
    }
    @validate.validate_module(@binary.decode_module(output_bytes).unwrap()).unwrap()
  }
}
