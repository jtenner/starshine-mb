///|
fn extract_reference_fixture(expressions : Bool) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([1U, 0U, 0U].map(fn(i) { @lib.TypeIdx::new(i) })),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::call_indirect(
            @lib.TypeIdx::new(0U),
            @lib.TableIdx::new(0U),
          ),
        ]),
      ),
    ]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(2U, None),
        ),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        if expressions {
          @lib.ElemKind::func_exprs(
            [0U, 1U].map(fn(i) {
              @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(i))])
            }),
          )
        } else {
          @lib.ElemKind::funcs([0U, 1U].map(fn(i) { @lib.FuncIdx::new(i) }))
        },
      ),
    ]),
  )
}

///|
test "extract retains reference-only active element functions through final root ordering" {
  for expressions in [false, true] {
    let input = extract_reference_fixture(expressions)
    @validate.validate_module(input).unwrap()
    let output = rume_extract_functions(input, [@lib.FuncIdx::new(2U)]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.CodeSec(funcs) = output.code_sec.unwrap()
    assert_eq(funcs.length(), 3)
    assert_eq(funcs[0], input.code_sec.unwrap().0[2])
    // Preserve the existing extraction contract: an uncallable signature's
    // reference remains declared, but its unobservable body is nullified.
    let @lib.Func(_, reference_body) = funcs[1]
    assert_eq(
      reference_body,
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    )
    let @lib.ElemSec(elems) = output.elem_sec.unwrap()
    assert_eq(
      match elems[0] {
        @lib.Elem(_, kind) => kind
      },
      if expressions {
        @lib.ElemKind::func_exprs(
          [1U, 2U].map(fn(i) {
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(i))])
          }),
        )
      } else {
        @lib.ElemKind::funcs([1U, 2U].map(fn(i) { @lib.FuncIdx::new(i) }))
      },
    )
  }
}
