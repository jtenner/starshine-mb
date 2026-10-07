///|
test "dispatcher precompute keeps try-table catch depth after constant if" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func (export "run")
    #|    (block
    #|      (i32.const 1)
    #|      (if (then
    #|        (try_table (catch_all 0) (throw $e))))
    #|      (global.set $g (i32.const 1))))
    #|  (func (export "get") (result i32) (global.get $g)))
  let input = @passes.pass_test_module_from_wat(source)
  let output = optimize_module_with_pass_flags(
    input,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  let body = match output.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body)), _])) => body
    _ => fail("expected two function bodies")
  }
  match body[0] {
    @lib.Block(_, @lib.Expr(outer)) =>
      assert_true(
        outer.any(fn(instr) {
          match instr {
            @lib.Block(_, @lib.Expr(inner)) =>
              inner.any(fn(child) {
                match child {
                  @lib.TryTable(_, _, _) => true
                  _ => false
                }
              })
            _ => false
          }
        }),
      )
    _ => fail("expected the outer catch target block")
  }
}
