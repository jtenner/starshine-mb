///|
test "campaign call topology profile emits valid distinct call routes" {
  let profile = gen_valid_profile_by_name("campaign-call-topology").unwrap()
  let config = GenValidConfig::for_profile(profile)
  let seen = Array::make(12, false)
  let topology_seen = Array::make(4, false)
  let table_orders_seen = Array::make(2, false)
  for seed = 0UL; seed < 96UL; seed = seed + 1UL {
    let mod_ = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    match validate_module(mod_) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    assert_true(mod_.import_sec is Some(_))
    assert_true(mod_.table_sec is Some(_))
    assert_true(mod_.elem_sec is Some(_))
    let CodeSec(funcs) = mod_.code_sec.unwrap()
    let Func(_, Expr(first_body)) = funcs[0]
    let Func(_, Expr(second_body)) = funcs[1]
    let topology = (seed / 12UL % 4UL).to_int()
    match topology {
      0 => {
        assert_true(!first_body.contains(Instruction::call(FuncIdx::new(0U))))
        assert_true(!second_body.contains(Instruction::call(FuncIdx::new(1U))))
      }
      1 => assert_true(first_body.contains(Instruction::call(FuncIdx::new(0U))))
      2 =>
        assert_true(second_body.contains(Instruction::call(FuncIdx::new(1U))))
      _ => {
        assert_true(first_body.contains(Instruction::call(FuncIdx::new(0U))))
        assert_true(second_body.contains(Instruction::call(FuncIdx::new(0U))))
        assert_true(second_body.contains(Instruction::call(FuncIdx::new(1U))))
      }
    }
    topology_seen[topology] = true
    let refs = match mod_.elem_sec.unwrap().0[0] {
      Elem(_, TypedExprsElemKind(_, refs)) => refs
      _ => fail("expected typed call-topology element segment")
    }
    let table_order = (seed / 48UL % 2UL).to_int()
    let expected_first = if table_order == 0 { 0U } else { 2U }
    assert_true(
      refs[0].0.contains(Instruction::ref_func(FuncIdx::new(expected_first))),
    )
    table_orders_seen[table_order] = true
    let Func(_, Expr(body)) = funcs[2]
    let variant = (seed % 12UL).to_int()
    match variant {
      0 => assert_true(body.contains(Instruction::call(FuncIdx::new(0U))))
      1 => assert_true(body.contains(Instruction::call(FuncIdx::new(1U))))
      2 => assert_true(body.contains(Instruction::call(FuncIdx::new(2U))))
      3 =>
        assert_true(body.contains(Instruction::return_call(FuncIdx::new(0U))))
      4 =>
        assert_true(body.contains(Instruction::return_call(FuncIdx::new(2U))))
      5 => {
        assert_true(body.contains(Instruction::i32_const(I32(0))))
        assert_true(
          body.contains(
            Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
          ),
        )
      }
      6 => {
        assert_true(body.contains(Instruction::i32_const(I32(2))))
        assert_true(
          body.contains(
            Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
          ),
        )
      }
      7 =>
        assert_true(
          body.contains(
            Instruction::return_call_indirect(
              TypeIdx::new(0U),
              TableIdx::new(0U),
            ),
          ),
        )
      8 => {
        assert_true(body.contains(Instruction::ref_func(FuncIdx::new(1U))))
        assert_true(body.contains(Instruction::call_ref(TypeIdx::new(0U))))
      }
      9 => {
        assert_true(body.contains(Instruction::ref_func(FuncIdx::new(2U))))
        assert_true(body.contains(Instruction::local_set(LocalIdx::new(1U))))
        assert_true(body.contains(Instruction::local_get(LocalIdx::new(1U))))
        assert_true(body.contains(Instruction::call_ref(TypeIdx::new(0U))))
      }
      10 => {
        assert_true(body.contains(Instruction::table_get(TableIdx::new(0U))))
        assert_true(
          body.contains(Instruction::return_call_ref(TypeIdx::new(0U))),
        )
      }
      _ => {
        assert_true(body.contains(Instruction::global_get(GlobalIdx::new(0U))))
        assert_true(body.contains(Instruction::call_ref(TypeIdx::new(0U))))
      }
    }
    seen[variant] = true
  }
  assert_true(seen.iter().all(fn(value) { value }))
  assert_true(topology_seen.iter().all(fn(value) { value }))
  assert_true(table_orders_seen.iter().all(fn(value) { value }))
}
