///|
fn mass_audit_ir_repeated_entry_fixture() -> (@ir.HotFunc, @ir.NodeId) {
  let input = @wast.wast_to_binary_module(
    "(module (type $pair (func (result i32 i32))) (type $entry (func (param i32 i32 i32 i32))) (func (result i32) (local i32) i32.const 1 i32.const 2 i32.const 3 i32.const 4 loop (type $entry) drop drop drop drop end local.get 0))",
  ).unwrap()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let loop_id = @ir.hot_root_get(func, 0)
  let read = @ir.hot_build_local_get(func, 0)
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    read,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let write = @ir.hot_build_local_tee(func, 0, add)
  let tuple = @ir.hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [],
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [write, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  let body : Array[@ir.NodeId] = []
  for slot in 4..<8 {
    let drop = @ir.hot_child_get(func, loop_id, slot)
    @ir.hot_child_set(func, drop, 0, tuple)
    body.push(drop)
  }
  let children = [tuple, tuple, tuple, tuple]
  children.append(body)
  ignore(@ir.hot_replace_child_span(func, loop_id, children))
  (func, read)
}

///|
test "mass audit IR intentionally unsupported repeated-entry full SSA retains the dynamic read" {
  let (func, read) = mass_audit_ir_repeated_entry_fixture()
  let ctx = HotPassContext::new(
    ssa_full_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(ssa_full_run(ctx, func))
  // A node-indexed rewrite cannot select default on the first evaluation and
  // the preceding tee on the second. Retain this valid dynamic producer.
  assert_true(@ir.hot_node_get(func, read).op is @ir.HotOp::LocalGet)
  assert_eq(@ir.hot_node_get(func, read).imm0, 0)
  assert_eq(@ir.hot_local_count(func), 1)
  @ir.hot_verify_all(func).unwrap()
}

///|
test "mass audit IR cast reuse uses nullable storage across a value block" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let heap_type = @lib.RecType::new(
    @lib.SubType::new(false, [], @lib.CompType::struct_([])),
  )
  let function_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
  )
  let module_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([heap_type, function_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_cast(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32(7)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  @validate.validate_module(module_).unwrap()
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    optimize_casts_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(module_)),
  )
  ignore(optimize_casts_run(ctx, func))
  assert_eq(@ir.hot_local_count(func), 2)
  let nullable_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let non_null_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  assert_eq(@ir.hot_local_type(func, 1), Some(nullable_type))
  let mut casts = 0
  let mut capture_checks = 0
  let mut read_checks = 0
  for node_id in 0..<@ir.hot_node_count(func) {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_exact_instr(func, node_id) {
      Some(@lib.Instruction::RefCast(_, _, _)) => casts += 1
      Some(@lib.Instruction::RefAsNonNull) => {
        assert_eq(
          @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)),
          [non_null_type],
        )
        let child = @ir.hot_node_get(func, @ir.hot_child_get(func, node_id, 0))
        if child.imm0 == 1 {
          match child.op {
            @ir.HotOp::LocalTee => capture_checks += 1
            @ir.HotOp::LocalGet => read_checks += 1
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  assert_eq(casts, 1)
  assert_eq(capture_checks, 1)
  assert_eq(read_checks, 1)
  @ir.hot_verify_all_or_abort(func)
  let output = module_.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  @validate.validate_module(output).unwrap()
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
}
