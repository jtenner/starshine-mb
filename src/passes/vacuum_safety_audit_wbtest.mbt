///|
test "vacuum preserves dropped array allocation with dynamic length" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array (mut i32))) (func (param i32) (drop (array.new_default $a (local.get 0)))))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.any(fn(instr) { instr is @lib.ArrayNewDefault(_) }),
    msg="a dynamic negative length must still trap after Vacuum",
  )
}

///|
fn vacuum_continuation_label_test_input() -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let null_cont = fn() {
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::no_cont()))
  }
  let if_ = @lib.Instruction::if_(
    @lib.BlockType::val_type(cont_ref),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::resume_(cont, [
        @lib.ResumeHandler::on_label(
          @lib.TagIdx::new(0U),
          @lib.LabelIdx::new(0U),
        ),
      ]),
      null_cont(),
    ],
    Some([null_cont()]),
  )
  let candidate = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            if_,
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(candidate) {
    Ok(_) => candidate
    Err(err) => abort("invalid Vacuum continuation fixture: \{err}")
  }
}

///|
test "vacuum counts continuation handlers as label uses" {
  let input = vacuum_continuation_label_test_input()
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop_id = @ir.hot_root_get(func, 0)
  let if_id = @ir.hot_child_get(func, drop_id, 0)
  assert_true(@ir.hot_node_get(func, if_id).op is @ir.HotOp::If)
  assert_true(
    hot_pass_vacuum_label_is_used(func, @ir.hot_control_node_label(func, if_id)),
    msg="continuation handler target must keep its owner live",
  )
}
