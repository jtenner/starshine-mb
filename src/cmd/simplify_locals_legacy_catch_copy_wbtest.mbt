///|
test "seven-pass dispatcher removes saved case 17 legacy catch copy" {
  let wat =
    #|(module
    #|  (type $empty (func))
    #|  (tag $e (type $empty))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (try (result i32)
    #|      (do (throw $e))
    #|      (catch $e
    #|        (local.set 1 (local.get 0))
    #|        (drop (local.get 0))
    #|        (local.get 1)))))
  let input = @passes.pass_test_module_from_wat(wat)
  let optimized = optimize_module_with_pass_flags(
    input,
    [
      "optimize-instructions", "precompute", "vacuum", "local-cse", "simplify-locals",
      "remove-unused-brs", "dead-code-elimination",
    ],
    OptimizeOptions::new(),
  ).unwrap()

  let catch_body = match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [@lib.Try(_, _, [@lib.LegacyCatch(_, @lib.Expr(catch_body))], _)]
            )
          ),
        ]
      )
    ) => catch_body
    other =>
      fail(
        "expected one legacy try/catch function, got \{@debug.to_string(other)}",
      )
  }
  @debug.assert_eq(catch_body, [
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}
