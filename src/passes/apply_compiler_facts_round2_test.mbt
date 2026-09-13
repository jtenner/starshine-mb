///|
test "round2 compiler facts follow legacy try body before catches" {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"get\" (func $get (result i32))) (tag $e) (func (export \"run\") (result i32) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::try_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              @lib.Instruction::throw_(@lib.TagIdx::new(0U)),
            ]),
            [
              @lib.LegacyCatch::all(
                @lib.Expr::new([
                  @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                  @lib.Instruction::i32_eqz(),
                ]),
              ),
            ],
          ),
        ]),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  let sites = @binary.compiler_fact_module_opcode_sites(input).unwrap()[0]
  let facts : Array[@representation.ExpressionFact] = []
  for site in sites {
    if site.1 is @lib.Call(_) {
      facts.push(
        @representation.ExpressionFact::new(
          @representation.ValueSite::new(
            @representation.CodeSite::new(1U, site.0),
          ),
          compiler_fact_test_i32_exact(facts.length().to_uint64()),
        ),
      )
    }
  }
  assert_eq(facts.length(), 2)
  let input = input.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(1U, sites=facts),
      ]),
    ),
  )
  let output = apply_compiler_facts(
      input,
      CompilerFactUsePolicy::trust_assertions(),
    ).unwrap().module_
  let catches = match audit_body(output)[0] {
    @lib.Try(_, _, catches, _) => catches
    _ => fail("expected try")
  }
  let body = match catches[0] {
    @lib.LegacyCatchAll(@lib.Expr(body)) => body
    _ => fail("expected catch")
  }
  assert_eq(body.last(), Some(@lib.Instruction::i32_const(@lib.I32(0))))
}
