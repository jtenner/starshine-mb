///|
test "fifth audit code folding preserves continuation handler scope" {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let ref_ = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let bt = @lib.BlockType::val_type(ref_)
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              bt,
              @lib.Expr::new([
                @lib.Instruction::block(
                  bt,
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::resume_(cont, [
                      @lib.ResumeHandler::on_label(
                        @lib.TagIdx::new(0U),
                        @lib.LabelIdx::new(0U),
                      ),
                    ]),
                    @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("continuation fixture: \{err}")
  }
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let outer = @ir.hot_child_get(func, drop, 0)
  let inner = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, outer), 0)
  let resume_node = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, inner),
    0,
  )
  let index = CodeFoldingExitIndex::new(@ir.hot_node_count(func), true, true)
  assert_false(code_folding_branch_targets_survive_hoist(func, resume_node, inner, resume_node, index))
  assert_true(code_folding_node_may_throw_for_eh_move(func, resume_node))
}

///|
test "fifth audit code folding preserves continuation exception scope" {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let ref_ = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let bt = @lib.BlockType::val_type(ref_)
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              bt,
              @lib.Expr::new([
                @lib.Instruction::block(
                  bt,
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::resume_(cont, [
                      @lib.ResumeHandler::on_label(
                        @lib.TagIdx::new(0U),
                        @lib.LabelIdx::new(0U),
                      ),
                    ]),
                    @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("continuation fixture: \{err}")
  }
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let outer = @ir.hot_child_get(func, drop, 0)
  let inner = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, outer), 0)
  let resume_node = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, inner),
    0,
  )
  let index = CodeFoldingExitIndex::new(@ir.hot_node_count(func), true, true)
  assert_true(code_folding_node_may_throw_for_eh_move(func, resume_node))
}
