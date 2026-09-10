///|
test "simplify-locals-nostructure merges branch copy facts before exit reads" {
  let input =
    #|(module (func (param i32) (result i32) (local i32 i32 i32)
    #|  i32.const 10 local.set 1
    #|  i32.const 20 local.set 2
    #|  block $exit
    #|    block $second
    #|      local.get 0 br_if $second
    #|      local.get 1 local.set 3 br $exit
    #|    end
    #|    local.get 2 local.set 3 br $exit
    #|  end
    #|  local.get 3))
  let optimized = pass_test_run_pipeline(input, ["simplify-locals-nostructure"]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  // Either branch writes local 3. The final read cannot use only the second
  // branch's source (local 2), even though it is the last textual assignment.
  @debug.assert_eq(
    body[body.length() - 1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  )
}
