///|
test "precompute raw tlsf prologue repair produces valid lowered function" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (local i32 i32 i32 i32 i32)
    #|    memory.size
    #|    i32.const 177263
    #|    i32.const -16
    #|    i32.and
    #|    local.tee 0
    #|    i32.const 67107
    #|    i32.add
    #|    i32.const -65536
    #|    i32.and
    #|    i32.const 16
    #|    i32.shr_u
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 3
    #|      local.get 4
    #|      i32.sub
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if
    #|      unreachable
    #|    end
    #|    loop
    #|      i32.const 0
    #|      local.tee 1
    #|      i32.const 23
    #|      i32.lt_u
    #|      if
    #|        loop
    #|          i32.const 0
    #|          local.tee 2
    #|          i32.const 16
    #|          i32.lt_u
    #|          if
    #|            br 1
    #|          end
    #|        end
    #|        br 1
    #|      end
    #|    end))
    #|)
  let mod_ = pass_test_module_from_wat(source)
  let func = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => defs[0]
    None => fail("expected code section")
  }
  let (rewritten, changed, reason) = match precompute_run_raw_func(func, None) {
    Some(result) => result
    None => fail("expected raw tlsf rewrite result")
  }
  assert_true(changed, msg=reason)
  let candidate = mod_.with_code_sec(@lib.CodeSec::new([rewritten]))
  match @validate.validate_module(candidate) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid raw tlsf rewrite, got \{err}; mod=\{candidate}")
  }
}

///|
test "precompute rejects multi-root constant-if chosen regions" {
  let func = @ir.HotFunc::new()
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(2)),
      @ir.hot_build_const_i32(func, @lib.I32(3)),
    ]),
  )
  let else_region = @ir.hot_region_else_ref(func, if_id).unwrap()

  assert_false(
    precompute_constant_if_chosen_region_can_inline(func, else_region),
  )
}

///|
test "precompute folds fresh valid WTF-16 arrays to string constants" {
  let (rewritten, changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::i32_const(@lib.I32(65)),
      @lib.Instruction::i32_const(@lib.I32(66)),
      @lib.Instruction::i32_const(@lib.I32(67)),
      @lib.Instruction::i32_const(@lib.I32(68)),
      @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(4U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::string_new_wtf16_array(),
    ],
    None,
  )
  assert_true(changed)
  match rewritten {
    [@lib.StringConst(bytes)] =>
      @debug.assert_eq(bytes, Bytes::from_array([65, 66, 67, 68]))
    _ => fail("expected one ABCD string.const, got \{rewritten}")
  }

  let (pair, pair_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::i32_const(@lib.I32(0xd800)),
      @lib.Instruction::i32_const(@lib.I32(0xdc00)),
      @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(2U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::string_new_wtf16_array(),
    ],
    None,
  )
  assert_true(pair_changed)
  match pair {
    [@lib.StringConst(bytes)] =>
      @debug.assert_eq(bytes, Bytes::from_array([0xf0, 0x90, 0x80, 0x80]))
    _ => fail("expected one supplementary string.const, got \{pair}")
  }

  let invalid = [
    @lib.Instruction::i32_const(@lib.I32(0xd800)),
    @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(1U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::string_new_wtf16_array(),
  ]
  let (retained, retained_changed) = precompute_raw_rewrite_instrs(
    invalid,
    None,
  )
  assert_false(retained_changed)
  @debug.assert_eq(retained, invalid)
}

///|
test "precompute recognizes fresh immutable array reads in HOT" {
  let array_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(1U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
      ]),
    )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let module_ctx = @ir.hot_module_context_from_module(input)
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(module_ctx),
  )
  let mut found = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.ArrayGet(_)) => {
          found = true
          assert_true(
            precompute_try_fold_fresh_array_get(ctx, func, node_id),
            msg="array.get children=\{@ir.hot_child_count(func, node_id)}",
          )
        }
        _ => ()
      }
    }
  }
  assert_true(found)
}
