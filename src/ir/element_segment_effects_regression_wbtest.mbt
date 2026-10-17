///|
fn element_effects_fixture(init : Bool) -> IrTestHotFixture {
  let ty = @lib.TypeIdx::new(0U)
  let elem = @lib.ElemIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(ty)),
  )
  let body = if init {
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::array_init_elem(ty, elem),
    ]
  } else {
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::array_new_elem(ty, elem),
      @lib.Instruction::drop(),
    ]
  }
  body.push(@lib.Instruction::elem_drop(elem))
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::externref()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([array_ref], [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(
            @lib.RefType::abs(@lib.AbsHeapType::extern_()),
            [
              @lib.Expr::new([
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
                ),
              ]),
            ],
          ),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("invalid constructed element effects fixture: \{err}")
  }
  let hot_func = hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  match hot_verify_core(hot_func) {
    Ok(_) => ()
    Err(err) => abort("invalid constructed hot element effects fixture: \{err}")
  }
  { mod_, code_idx: 0, hot_func, }
}

///|
test "element segment heap operations retain exact instructions and trap flags" {
  for init in [false, true] {
    let fixture = element_effects_fixture(init)
    let func = fixture.hot_func
    let root = hot_root_get(func, 0)
    let heap = if init { root } else { hot_child_get(func, root, 0) }
    let expected = if init {
      @lib.Instruction::array_init_elem(
        @lib.TypeIdx::new(0U),
        @lib.ElemIdx::new(0U),
      )
    } else {
      @lib.Instruction::array_new_elem(
        @lib.TypeIdx::new(0U),
        @lib.ElemIdx::new(0U),
      )
    }
    assert_eq(hot_node_get(func, heap).op, HotOp::Heap)
    assert_eq(hot_node_exact_instr(func, heap), Some(expected))
    assert_true(hot_verify_node_exact_instr_payload(func, heap))
    assert_true(hot_may_trap(func, heap))
    assert_true(hot_has_side_effect(func, heap))
    let mask = effects_for_node(func, heap)
    assert_true((mask & EFFECT_MASK_TRAP) != 0U)
    assert_true((mask & EFFECT_MASK_MEMORY_WRITE) != 0U)
    let drop = hot_root_get(func, 1)
    assert_eq(hot_node_get(func, drop).op, HotOp::ElemDrop)
    assert_true((effects_for_node(func, drop) & EFFECT_MASK_TABLE_WRITE) != 0U)
    assert_false(hot_may_trap(func, drop))
    let lowered = ir_test_assert_verify_and_lower(fixture)
    let @lib.Func(_, @lib.Expr(body)) = lowered.code_sec.unwrap().0[0]
    assert_true(body.contains(expected))
    assert_true(
      body.contains(@lib.Instruction::elem_drop(@lib.ElemIdx::new(0U))),
    )
  }
}

///|
test "invalid element heap payload indexes are rejected before exact instruction access" {
  // These indexes deliberately violate the hot IR payload table contract.
  for init in [false, true] {
    for bad_index in [-1, 1000000] {
      let fixture = element_effects_fixture(init)
      let func = fixture.hot_func
      let root = hot_root_get(func, 0)
      let heap = if init { root } else { hot_child_get(func, root, 0) }
      hot_node_set(func, heap, { ..hot_node_get(func, heap), imm0: bad_index, })
      assert_false(hot_verify_node_exact_instr_payload(func, heap))
      assert_true(hot_verify_core(func) is Err(_))
      // The shared effect accessor must remain conservative and must not read
      // an invalid payload entry while verification reports the bad index.
      assert_true((effects_for_node(func, heap) & EFFECT_MASK_TRAP) != 0U)
    }
  }
}

///|
test "invalid element heap trap flags are rejected by core verification" {
  // Clear a required flag directly to simulate deliberately malformed IR.
  // Public node setters restore the opcode flags and cannot create this state.
  for init in [false, true] {
    let fixture = element_effects_fixture(init)
    let func = fixture.hot_func
    let root = hot_root_get(func, 0)
    let heap = if init { root } else { hot_child_get(func, root, 0) }
    let node = hot_node_get(func, heap)
    func.nodes[heap] = {
      ..node,
      flags: node.flags & (0xffffffffU ^ HOT_FLAG_MAY_TRAP),
    }
    assert_true(
      hot_verify_core(func) is Err(HotVerifyError::InvalidNodeFlags(_, _, _)),
    )
    hot_node_set(func, heap, hot_node_get(func, heap))
    assert_true(hot_may_trap(func, heap))
    ignore(ir_test_assert_verify_and_lower(fixture))
  }
}
