// R1-01 fixtures and assertions from 6422a44b155026bdbadfac86289c20958fdc21d3.
// Only the two Result checks were adapted for the current compiler.

///|
fn hunt_r1_callback_module(via_helper : Bool) -> @lib.Module {
  let callback = @lib.TypeIdx::new(0U)
  let getter = @lib.TypeIdx::new(1U)
  let callback_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(callback)),
  )
  let types = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [callback_ref])),
    ),
  ])
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
    ),
  ]
  let signatures = [callback]
  if via_helper {
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
      ),
    )
    signatures.push(getter)
  }
  funcs.push(
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        if via_helper {
          @lib.Instruction::call(@lib.FuncIdx::new(1U))
        } else {
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U))
        },
      ]),
    ),
  )
  signatures.push(getter)
  @lib.Module::new()
  .with_type_sec(types)
  .with_func_sec(@lib.FuncSec::new(signatures))
  .with_code_sec(@lib.CodeSec::new(funcs))
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(callback_ref, false),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::new("get"),
        @lib.ExternIdx::func(
          @lib.FuncIdx::new(if via_helper { 2U } else { 1U }),
        ),
      ),
    ]),
  )
}

///|
fn hunt_r1_assert_callback_retained(via_helper : Bool) -> Unit raise {
  let input = hunt_r1_callback_module(via_helper)
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = rume_run_module_pass(input, closed_world=true)
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(42))])
}

///|
test "hunt r1 RUME retains a callback returned through a private global" {
  hunt_r1_assert_callback_retained(false)
}

///|
test "hunt r1 RUME retains a callback returned through a private helper" {
  hunt_r1_assert_callback_retained(true)
}

///|
test "R1-01 closed-world dropped callback remains reference-only" {
  let original = hunt_r1_callback_module(false)
  let input = original
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        original.code_sec.unwrap().0[0],
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  @validate.validate_module(input).unwrap()
  let output = rume_run_module_pass(input, closed_world=true)
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::unreachable_()])
}
