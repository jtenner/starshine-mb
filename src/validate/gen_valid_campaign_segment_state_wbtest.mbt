///|
test "campaign segment state profile covers segment lifetimes and bulk operations" {
  let profile = match gen_valid_profile_by_name("campaign-segment-state") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let config = GenValidConfig::for_profile(profile)
  let mut saw_active_data = false
  let mut saw_passive_data = false
  let mut saw_active_elem = false
  let mut saw_passive_elem = false
  let mut saw_declarative_elem = false
  let mut saw_second_data = false
  let mut saw_second_elem = false
  let mut saw_memory_init = false
  let mut saw_data_drop = false
  let mut saw_table_init = false
  let mut saw_elem_drop = false
  let mut saw_distinct_modules = false
  let mut first_module : Module? = None
  for seed = 0; seed < 64; seed = seed + 1 {
    let generated = match
      gen_valid_module_result_from_seed(seed.to_uint64(), config) {
      Ok(value) => value
      Err(error) => fail(error.validation_error_message)
    }
    let mod_ = generated.wasm_module
    match validate_module(mod_) {
      Ok(_) => ()
      Err(error) => fail(validation_error_message(error))
    }
    @debug.assert_eq(generated.config_label, "campaign-segment-state")
    if first_module is Some(first) && mod_ != first {
      saw_distinct_modules = true
    }
    if first_module is None {
      first_module = Some(mod_)
    }
    let DataSec(datas) = mod_.data_sec.unwrap()
    let ElemSec(elems) = mod_.elem_sec.unwrap()
    @debug.assert_eq(datas.length(), 4)
    @debug.assert_eq(elems.length(), 5)
    @debug.assert_eq(mod_.data_cnt_sec, Some(DataCntSec::new(U32(4U))))
    let Elem(first_mode, _) = elems[0]
    let Elem(second_mode, _) = elems[1]
    let Elem(third_mode, _) = elems[2]
    let Elem(fourth_mode, _) = elems[3]
    let Elem(fifth_mode, _) = elems[4]
    assert_true(first_mode is Passive)
    assert_true(second_mode is Passive)
    assert_true(third_mode is Active(_, _))
    assert_true(fourth_mode is Active(_, _))
    assert_true(fifth_mode is Declarative)
    let data_offset = 8 + ((seed.to_uint64() * 7UL + 3UL) % 9UL).to_int()
    let elem_offset = 1 + (seed.to_uint64() / 3UL % 2UL).to_int()
    let mut active_data_count = 0
    let mut passive_data_count = 0
    let mut saw_first_active_data_offset = false
    let mut saw_overlapping_active_data_offset = false
    for data in datas {
      let Data(mode, _) = data
      match mode {
        Active(_, offset) => {
          saw_active_data = true
          active_data_count += 1
          if offset == Expr::new([Instruction::i32_const(I32(data_offset))]) {
            saw_first_active_data_offset = true
          }
          if offset == Expr::new([Instruction::i32_const(I32(data_offset + 3))]) {
            saw_overlapping_active_data_offset = true
          }
        }
        Passive => {
          saw_passive_data = true
          passive_data_count += 1
        }
      }
    }
    @debug.assert_eq(active_data_count, 2)
    @debug.assert_eq(passive_data_count, 2)
    assert_true(
      saw_first_active_data_offset && saw_overlapping_active_data_offset,
    )
    let mut active_elem_count = 0
    let mut passive_elem_count = 0
    let mut declarative_elem_count = 0
    let mut saw_first_active_elem_offset = false
    let mut saw_overlapping_active_elem_offset = false
    for elem in elems {
      let Elem(mode, _) = elem
      match mode {
        Active(_, offset) => {
          saw_active_elem = true
          active_elem_count += 1
          if offset == Expr::new([Instruction::i32_const(I32(elem_offset))]) {
            saw_first_active_elem_offset = true
          }
          if offset == Expr::new([Instruction::i32_const(I32(elem_offset + 1))]) {
            saw_overlapping_active_elem_offset = true
          }
        }
        Passive => {
          saw_passive_elem = true
          passive_elem_count += 1
        }
        Declarative => {
          saw_declarative_elem = true
          declarative_elem_count += 1
        }
      }
    }
    @debug.assert_eq(active_elem_count, 2)
    @debug.assert_eq(passive_elem_count, 2)
    @debug.assert_eq(declarative_elem_count, 1)
    assert_true(
      saw_first_active_elem_offset && saw_overlapping_active_elem_offset,
    )
    let CodeSec(funcs) = mod_.code_sec.unwrap()
    for func in funcs {
      let Func(_, Expr(body)) = func
      for instruction in body {
        match instruction {
          MemoryInit(data, _) => {
            saw_memory_init = true
            if data == DataIdx::new(1U) || data == DataIdx::new(2U) {
              saw_second_data = true
            }
          }
          DataDrop(data) => {
            saw_data_drop = true
            if data == DataIdx::new(1U) || data == DataIdx::new(2U) {
              saw_second_data = true
            }
          }
          TableInit(elem, _) => {
            saw_table_init = true
            if elem == ElemIdx::new(1U) || elem == ElemIdx::new(2U) {
              saw_second_elem = true
            }
            let mut passive_target = false
            for index = 0; index < elems.length(); index = index + 1 {
              if elem == ElemIdx::new(index.to_uint()) {
                let Elem(mode, _) = elems[index]
                passive_target = mode is Passive
              }
            }
            assert_true(passive_target)
          }
          ElemDrop(elem) => {
            saw_elem_drop = true
            if elem == ElemIdx::new(1U) || elem == ElemIdx::new(2U) {
              saw_second_elem = true
            }
            let mut passive_target = false
            for index = 0; index < elems.length(); index = index + 1 {
              if elem == ElemIdx::new(index.to_uint()) {
                let Elem(mode, _) = elems[index]
                passive_target = mode is Passive
              }
            }
            assert_true(passive_target)
          }
          _ => ()
        }
      }
    }
  }
  assert_true(saw_active_data && saw_passive_data)
  assert_true(saw_active_elem && saw_passive_elem && saw_declarative_elem)
  assert_true(saw_second_data && saw_second_elem)
  assert_true(saw_memory_init && saw_data_drop)
  assert_true(saw_table_init && saw_elem_drop)
  assert_true(saw_distinct_modules)
}
