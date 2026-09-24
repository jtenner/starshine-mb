///|
test "SSA no-merge parameter-tee facts index reads and plain branches" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    local.tee 0
    #|    drop
    #|    local.get 0))
  let input = pass_test_module_from_wat(source)
  let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let facts = ssa_nomerge_param_tee_facts(hot)
  assert_false(facts.has_plain_br)
  assert_true(facts.has_local_get[0])
}
