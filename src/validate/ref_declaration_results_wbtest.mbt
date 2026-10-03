///|
fn ref_declaration_results_module(body : Array[Instruction]) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new(body)),
      Func::new(Locals::empty(), Expr::new([])),
    ]),
  )
}

///|
test "reference declaration scan retains first error across every control arm" {
  let env = Env::new().with_module(ref_declaration_results_module([]))
  let declared = @bitset.BitSet::new(2)
  let first = Instruction::ref_func(FuncIdx::new(0U))
  let second = Instruction::ref_func(FuncIdx::new(1U))
  let void_ = BlockType::void_()
  // These deliberately undeclared references must be visited in source order.
  for
    (instruction, expected) in [
      (Instruction::block(void_, Expr::new([second, first])), 1U),
      (Instruction::loop_(void_, Expr::new([first, second])), 0U),
      (Instruction::if_(void_, [second], Some([first])), 1U),
      (Instruction::if_(void_, [Instruction::nop()], Some([first])), 0U),
      (
        Instruction::try_(void_, Expr::new([first]), [
          @lib.LegacyCatch::all(Expr::new([second])),
        ]),
        0U,
      ),
      (
        Instruction::try_(void_, Expr::new([Instruction::nop()]), [
          @lib.LegacyCatch::all(Expr::new([second])),
        ]),
        1U,
      ),
      (Instruction::try_table(void_, [], Expr::new([second, first])), 1U),
    ] {
    assert_eq(
      validate_ref_func_declarations_in_expr(
        Expr::new([instruction]),
        env,
        declared,
      ).unwrap_err(),
      "undeclared function reference: \{FuncIdx::new(expected)}",
    )
  }
}

///|
test "reference declaration scan observes fresh declaration membership" {
  let env = Env::new().with_module(ref_declaration_results_module([]))
  let declared = @bitset.BitSet::new(2)
  let expression = Expr::new([
    Instruction::ref_func(FuncIdx::new(0U)),
    Instruction::ref_func(FuncIdx::new(1U)),
  ])
  declared.set(0, true)
  declared.set(1, true)
  assert_true(
    validate_ref_func_declarations_in_expr(expression, env, declared).is_ok(),
  )
  declared.set(1, false)
  assert_eq(
    validate_ref_func_declarations_in_expr(expression, env, declared).unwrap_err(),
    "undeclared function reference: \{FuncIdx::new(1U)}",
  )
  declared.set(1, true)
  assert_true(
    validate_ref_func_declarations_in_expr(expression, env, declared).is_ok(),
  )
}

///|
test "module validation rejects invalid indices delegated by declaration scan" {
  let expression = Expr::new([
    Instruction::ref_func(FuncIdx::new(99U)),
    Instruction::drop(),
  ])
  let Expr(body) = expression
  let module_ = ref_declaration_results_module(body)
  let env = Env::new().with_module(module_)
  // This worker only checks declarations of existing functions. The mandatory
  // module/type validation must still reject an invalid function index.
  assert_true(
    validate_ref_func_declarations_in_expr(
      expression,
      env,
      @bitset.BitSet::new(2),
    ).is_ok(),
  )
  assert_true(validate_module(module_).is_err())
}
