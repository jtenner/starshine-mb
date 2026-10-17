///|
fn dae2_signature_reuse_fixture() -> (
  @lib.TypeSec,
  Dae2Graph,
  Array[Dae2Function],
  Array[Int32],
) {
  let wide = Array::make(64, @lib.ValType::i32())
  let types = @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func(wide, []))),
    @lib.RecType::group([
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
          @lib.ValType::i32(),
        ]),
        metadata=@lib.TypeMetadata::new(shared=true),
      ),
      @lib.SubType::comp_type(@lib.CompType::struct_([])),
      @lib.SubType::comp_type(@lib.CompType::func(wide, [])),
    ]),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
  let graph = Dae2Graph::new()
  let infos = [
    Dae2Function::new(graph, wide, []),
    Dae2Function::new(graph, [@lib.ValType::i32(), @lib.ValType::i64()], [
      @lib.ValType::i32(),
    ]),
    Dae2Function::new(graph, wide, []),
    Dae2Function::new(graph, [], []),
  ]
  for info in infos {
    for location in info.param_locations {
      graph.observe(location)
    }
    graph.observe(info.result_location)
  }
  (types, graph, infos, [0, 1, -1, 2, 3])
}

///|
test "DAE2 unchanged wide signatures retain type section and recursive groups" {
  let (types, graph, infos, type_infos) = dae2_signature_reuse_fixture()
  graph.solve()
  let rewritten = dae2_rewrite_type_section(types, graph, infos, type_infos)
  assert_eq(rewritten, types)
  assert_true(physical_equal(rewritten, types))
}

///|
test "DAE2 changed signature retains untouched groups and sibling subtypes" {
  let (types, graph, infos, type_infos) = dae2_signature_reuse_fixture()
  let @lib.TypeSec(before) = types
  let before_members = match before[1] {
    @lib.GroupRecType(members) => members
    _ => fail("expected recursive group")
  }
  graph.used[infos[1].param_locations[1]] = false
  graph.used[infos[1].result_location] = false
  let @lib.TypeSec(after) = dae2_rewrite_type_section(
    types, graph, infos, type_infos,
  )
  let after_members = match after[1] {
    @lib.GroupRecType(members) => members
    _ => fail("expected recursive group")
  }
  assert_eq(
    after_members[0].get_comptype(),
    @lib.CompType::func([@lib.ValType::i32()], []),
  )
  assert_eq(after_members[0].metadata(), before_members[0].metadata())
  assert_eq(
    before_members[0].get_comptype(),
    @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
      @lib.ValType::i32(),
    ]),
  )
  assert_false(physical_equal(after, before))
  assert_true(physical_equal(after[0], before[0]))
  assert_true(physical_equal(after[2], before[2]))
  assert_true(physical_equal(after_members[1], before_members[1]))
  assert_true(physical_equal(after_members[2], before_members[2]))
}

///|
test "DAE2 identity closure restores parameter before final signature decisions" {
  let types = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
  let graph = Dae2Graph::new()
  let infos = [
    Dae2Function::new(graph, [@lib.ValType::i32()], []),
    Dae2Function::new(graph, [], []),
  ]
  assert_true(dae2_signature_changes(graph, infos[0]))
  dae2_preserve_type_identity(types, graph, infos, [0, 1])
  assert_true(graph.used[infos[0].param_locations[0]])
  assert_false(dae2_signature_changes(graph, infos[0]))
  assert_true(
    physical_equal(
      dae2_rewrite_type_section(types, graph, infos, [0, 1]),
      types,
    ),
  )
}

///|
test "DAE2 changed result-only subtype owns its surviving parameter array" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32) (result i32))))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let types = input.type_sec.unwrap()
  let @lib.TypeSec(groups) = types
  guard groups[0].get_subtype(0U).unwrap().get_comptype()
    is @lib.FuncCompType(params, results) else {
    fail("expected function type")
  }
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, params, results)
  graph.observe(info.param_locations[0])
  let output = input.with_type_sec(
    dae2_rewrite_type_section(types, graph, [info], [0]),
  )
  @validate.validate_module(output).unwrap()
  let @lib.TypeSec(rewritten) = output.type_sec.unwrap()
  guard rewritten[0].get_subtype(0U).unwrap().get_comptype()
    is @lib.FuncCompType(kept, next_results) else {
    fail("expected rewritten function type")
  }
  assert_eq(kept, [@lib.ValType::i32()])
  assert_true(next_results.is_empty())
  kept[0] = @lib.ValType::i64()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 appended result-only function signature owns surviving parameters" {
  let input = pass_test_module_from_wat(
    "(module (global $sink (mut i32) (i32.const 0)) (func $target (param i32) (result i32) local.get 0 global.set $sink i32.const 1) (func (export \"run\") i32.const 7 call $target drop))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.FuncType(kept, results) = dae_resolve_func_type(
    output,
    dae_collect_func_type_indices(output),
    0,
  ).unwrap()
  assert_eq(kept, [@lib.ValType::i32()])
  assert_true(results.is_empty())
  kept[0] = @lib.ValType::i64()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 shared subtype family keeps each member's surviving parameter types" {
  let input = pass_test_module_from_wat(
    "(module (type $root (sub (func (param eqref i32) (result i32)))) (type $child (sub $root (func (param anyref i32) (result i32)))))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let types = input.type_sec.unwrap()
  let @lib.TypeSec(groups) = types
  guard groups[0].get_subtype(0U).unwrap().get_comptype()
    is @lib.FuncCompType(params, results) else {
    fail("expected root function type")
  }
  let graph = Dae2Graph::new()
  let family = Dae2Function::new(graph, params, results)
  graph.observe(family.param_locations[0])
  let output = input.with_type_sec(
    dae2_rewrite_type_section(types, graph, [family], [0, 0]),
  )
  @validate.validate_module(output).unwrap()
  let @lib.TypeSec(after) = output.type_sec.unwrap()
  guard after[1].get_subtype(0U).unwrap().get_comptype()
    is @lib.FuncCompType(child_params, child_results) else {
    fail("expected child function type")
  }
  guard groups[1].get_subtype(0U).unwrap().get_comptype()
    is @lib.FuncCompType(original_params, _) else {
    fail("expected original child function type")
  }
  assert_eq(child_params, [original_params[0]])
  assert_true(child_results.is_empty())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
