///|
fn sl_group_writeback_fixture() -> @lib.Module raise {
  let named = sl_local_groups_named_fixture()
  let maps = named.name_sec.unwrap().local_names.unwrap().0
  let @lib.IndirectNameAssoc(_, second_names) = maps[1]
  sl_local_groups_roundtrip(
    pass_test_module_from_wat(
      "(module (import \"host\" \"mark\" (func (param i32) (result i32))) " +
      "(func (export \"first\") (param i32 i64) (result i32) (local i32 f64 i32 f64) " +
      "local.get 0 call 0 local.set 4 local.get 4 local.get 4 i32.add) " +
      "(func (export \"second\") (param i32 i64) (result i32) (local i32 f64 i32 f64) " +
      "local.get 0 call 0 local.set 4 local.get 4 local.get 4 i32.add))",
    ).with_name_sec(
      @lib.NameSec::new(
        local_names=Some(
          @lib.IndirectNameMap::new([
            maps[0],
            maps[1],
            @lib.IndirectNameAssoc::new(2U, second_names),
          ]),
        ),
      ),
    ),
  )
}

///|
fn sl_group_writeback_check(
  input : @lib.Module,
  output : @lib.Module,
  selected : Array[Bool],
) -> Unit raise {
  ignore(@validate.validate_module(output).unwrap())
  let old_funcs = input.code_sec.unwrap().0
  let funcs = output.code_sec.unwrap().0
  let old_maps = input.name_sec.unwrap().local_names.unwrap().0
  let maps = output.name_sec.unwrap().local_names.unwrap().0
  assert_eq(funcs.length(), old_funcs.length())
  assert_eq(maps[0], old_maps[0])
  for index in 0..<funcs.length() {
    if selected[index] {
      let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
      assert_eq(locals.run_count(), 2)
      assert_eq(Array::makei(locals.length(), fn(i) { locals.get(i) }), [
        @lib.ValType::i32(),
        @lib.ValType::i32(),
        @lib.ValType::f64(),
        @lib.ValType::f64(),
      ])
      let accesses = sl_local_groups_accesses(body)
      assert_true(accesses.any(fn(access) { access.1 == 3U }))
      assert_true(accesses.all(fn(access) { access.1 == 0U || access.1 == 3U }))
      let @lib.IndirectNameAssoc(function_index, @lib.NameMap(names)) = maps[index +
        1]
      let old_names = old_maps[index + 1].1.0
      assert_eq(function_index, (index + 1).to_uint())
      assert_eq(names, [
        old_names[0],
        old_names[1],
        old_names[2],
        @lib.NameAssoc::new(3U, old_names[4].1),
        @lib.NameAssoc::new(4U, old_names[3].1),
        old_names[5],
      ])
    } else {
      assert_true(physical_equal(funcs[index], old_funcs[index]))
      assert_eq(funcs[index], old_funcs[index])
      assert_eq(maps[index + 1], old_maps[index + 1])
    }
    for value in [-7, 0, 11] {
      assert_eq(
        sl_local_groups_observe(funcs[index], 2, value),
        (value + value, [value]),
      )
    }
  }
  let before_bytes = @binary.encode_module(input).unwrap()
  let after_bytes = @binary.encode_module(output).unwrap()
  if selected.any(fn(value) { value }) {
    assert_true(after_bytes.length() < before_bytes.length())
  } else {
    assert_true(physical_equal(output, input))
    assert_eq(after_bytes, before_bytes)
  }
  ignore(sl_local_groups_roundtrip(output))
}

///|
test "simplify-locals local group writeback generic deferred and immediate preserve typed values and names" {
  let input = sl_group_writeback_fixture()
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let entry = pass_registry_lookup(pass_name).unwrap()
    for deferred in [false, true] {
      let output = run_hot_pipeline_apply_hot_pass(
        input,
        entry,
        HotPipelineOptions::new(),
        defer_simplify_locals_writeback_guard=deferred,
      ).unwrap()
      sl_group_writeback_check(input, output, [true, true])
    }
  }
}

///|
test "simplify-locals local group writeback fused precompute stack retains profitable remapping" {
  let input = sl_group_writeback_fixture()
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = run_hot_pipeline_apply_hot_pass_stack(
      input,
      [
        pass_registry_lookup(pass_name).unwrap(),
        pass_registry_lookup("precompute").unwrap(),
      ],
      HotPipelineOptions::new(),
    ).unwrap()
    sl_group_writeback_check(input, output, [true, true])
  }
}

///|
test "simplify-locals local group writeback touched stack groups only selected functions" {
  let input = sl_group_writeback_fixture()
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let descriptors = [
      pass_registry_lookup(pass_name).unwrap().descriptor.unwrap(),
      pass_registry_lookup("precompute").unwrap().descriptor.unwrap(),
    ]
    for selected in [[true, false], [false, true], [false, false]] {
      let output = run_hot_pipeline_apply_hot_pass_stack_to_touched(
        input,
        descriptors,
        selected,
        HotPipelineOptions::new(),
      ).unwrap()
      sl_group_writeback_check(input, output, selected)
    }
  }
}

///|
test "simplify-locals local group writeback touched single groups only selected functions" {
  let input = sl_group_writeback_fixture()
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let descriptor = pass_registry_lookup(pass_name).unwrap().descriptor.unwrap()
    for selected in [[true, false], [false, true], [false, false]] {
      let output = run_hot_pipeline_apply_hot_pass_to_touched(
        input,
        descriptor,
        selected,
        HotPipelineOptions::new(),
      ).unwrap()
      sl_group_writeback_check(input, output, selected)
    }
  }
}

///|
test "simplify-locals local group writeback no code and unchanged bodies retain identity" {
  let options = HotPipelineOptions::new()
  let entry = pass_registry_lookup("simplify-locals").unwrap()
  let descriptor = entry.descriptor.unwrap()
  let empty = pass_test_module_from_wat("(module)")
  assert_true(
    physical_equal(
      empty,
      run_hot_pipeline_apply_hot_pass(empty, entry, options).unwrap(),
    ),
  )
  assert_true(
    physical_equal(
      empty,
      run_hot_pipeline_apply_hot_pass_stack(empty, [entry], options).unwrap(),
    ),
  )
  assert_true(
    physical_equal(
      empty,
      run_hot_pipeline_apply_hot_pass_stack_to_touched(
        empty,
        [descriptor],
        [],
        options,
      ).unwrap(),
    ),
  )
  assert_true(
    physical_equal(
      empty,
      run_hot_pipeline_apply_hot_pass_to_touched(empty, descriptor, [], options).unwrap(),
    ),
  )
  let input = sl_group_writeback_fixture()
  assert_true(
    physical_equal(
      input,
      simplify_locals_group_numeric_locals_if_smaller(input, input),
    ),
  )
  let same_bodies = input.with_code_sec(input.code_sec.unwrap())
  assert_true(
    physical_equal(
      same_bodies,
      simplify_locals_group_numeric_locals_if_smaller(input, same_bodies),
    ),
  )
  assert_eq(@binary.encode_module(same_bodies), @binary.encode_module(input))
}

///|
test "simplify-locals local group writeback intentionally excludes other modes consistently" {
  // Numeric grouping is admitted only for simplify-locals and nostructure.
  // Other existing modes must keep that boundary across deferred writeback.
  let input = sl_local_groups_roundtrip(sl_local_groups_structure_fixture(true))
  let @lib.Func(original_locals, _) = input.code_sec.unwrap().0[0]
  for name in ["simplify-locals-notee", "simplify-locals-notee-nostructure"] {
    let entry = pass_registry_lookup_cached(name).unwrap()
    for deferred in [true, false] {
      let output = run_hot_pipeline_apply_hot_pass(
        input,
        entry,
        HotPipelineOptions::new(),
        defer_simplify_locals_writeback_guard=deferred,
      ).unwrap()
      ignore(@validate.validate_module(output).unwrap())
      let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
      assert_eq(locals.run_count(), original_locals.run_count())
    }
  }
}
