///|
fn dae_batch_signature_reference(
  mod_ : @lib.Module,
  imported : Int32,
  defined : Int32,
  indices : Array[@lib.TypeIdx],
) -> Array[@lib.FuncType?] {
  let out : Array[@lib.FuncType?] = []
  for def_idx = 0; def_idx < defined; def_idx = def_idx + 1 {
    out.push(dae_resolve_func_type(mod_, indices, imported + def_idx))
  }
  out
}

///|
test "DAE batch signature lookup keeps imports groups holes and invalid index results" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (struct (field i32)))
      #|   (rec (type (func (param i32))) (type (array i64)))
      #|   (type (func (result i64)))
      #|   (import "host" "entry" (func (type 1)))
      #|   (func (type 1))
      #|   (func (type 3) i64.const 7))
    ),
  )
  for
    indices in [
      dae_collect_func_type_indices(input),
      [
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::rec(0U),
        @lib.TypeIdx::new(99U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(3U),
      ],
    ] {
    for (imported, defined) in [(-1, 5), (0, 6), (1, 2), (4, 3), (1, 0)] {
      let expected = dae_batch_signature_reference(
        input, imported, defined, indices,
      )
      assert_eq(
        dae_collect_defined_function_types(input, imported, defined, indices),
        expected,
      )
      assert_eq(
        dae_collect_defined_function_types(
          @lib.Module::new(),
          imported,
          defined,
          indices,
        ),
        Array::make(defined, None),
      )
    }
  }
}

///|
test "DAE dropped result graph adoption keeps grouped imported signature slots" {
  let original = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (struct (field i32)))
      #|   (rec (type (func (param i32))) (type (array i64)))
      #|   (type (func (result i64)))
      #|   (import "host" "entry" (func (type 1)))
      #|   (func (type 1))
      #|   (func (type 3) i64.const 7))
    ),
  )
  let candidate = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (struct (field i32)))
      #|   (rec (type (func (param i32))) (type (array i64)))
      #|   (type (func))
      #|   (import "host" "entry" (func (type 1)))
      #|   (func (type 1))
      #|   (func (type 3)))
    ),
  )
  let graph = dae_current_boundary_graph_new(original)
  let effects = dae_commit_effects_empty(2)
  effects.result_changed[1] = true
  effects.result_removed[1] = true
  effects.structurally_touched[1] = true
  assert_true(
    dae_current_boundary_graph_adopt_dropped_result_batch(
      graph, candidate, effects,
    ),
  )
  let indices = dae_collect_func_type_indices(candidate)
  assert_eq(
    graph.snapshot.function_types,
    dae_batch_signature_reference(candidate, 0, 3, indices),
  )
  assert_true(physical_equal(graph.mod_, candidate))
}

///|
test "DAE typed batch validation checks changed signatures with shared untouched bodies" {
  let original = pass_test_module_from_wat(
    "(module (import \"host\" \"entry\" (func)) (func (param i32) (result i32) local.get 0))",
  )
  let valid = pass_test_module_from_wat(
    "(module (import \"host\" \"entry\" (func)) (func (param f64) (result f64) local.get 0))",
  ).with_code_sec(original.code_sec.unwrap())
  assert_true(dae_validate_typed_batch_candidate(original, valid, [false]))
  let invalid = pass_test_module_from_wat(
    "(module (import \"host\" \"entry\" (func)) (func (param f64) (result i32) i32.const 1))",
  ).with_code_sec(original.code_sec.unwrap())
  // The unchanged local.get now produces f64 for an i32 result: invalid IR.
  assert_false(dae_validate_typed_batch_candidate(original, invalid, [false]))
}
