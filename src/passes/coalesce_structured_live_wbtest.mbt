///|
fn cl_structured_live_fixture(
  width : Int,
  repetitions : Int,
) -> (Array[CLAction], CLLiveness, Array[@lib.ValType]) {
  let actions : Array[CLAction] = []
  for _ in 0..<repetitions {
    for
      (kind, local, source) in [
        (CLActionKind::Get, 0, CLValueSource::Unique),
        (CLActionKind::Set, 2, CLValueSource::Local(0)),
        (CLActionKind::Get, 1, CLValueSource::Unique),
        (CLActionKind::Tee, 3, CLValueSource::Local(1)),
        (CLActionKind::Get, 2, CLValueSource::Unique),
        (CLActionKind::Get, 3, CLValueSource::Unique),
      ] {
      actions.push({ kind, local_idx: local, source, })
    }
  }
  (
    actions,
    cl_compute_liveness(actions, width),
    Array::make(width, @lib.ValType::i32()),
  )
}

///|
test "coalesce structured interference visits only live members with identical edges" {
  let (actions, liveness, types) = cl_structured_live_fixture(64, 3)
  let visits = [0]
  let actual = cl_compute_interferences(
    actions,
    liveness,
    types,
    2,
    live_visits=Some(visits),
  )
  let expected = cl_structured_live_reference(actions, liveness, types, 2)
  assert_eq(actual.bits, expected.bits)
  assert_true(
    visits[0] <= actions.length() * 4,
    msg="structured live visits: \{visits[0]}",
  )
  assert_true(cl_bit_matrix_get(actual, 0, 1))
  assert_true(cl_bit_matrix_get(actual, 2, 3))
}

///|
test "coalesce structured live membership preserves default and ineffective-write edges" {
  let sources = [
    "(module (func (param i32 i32) (local i32 i32 i32) local.get 4 drop local.get 0 local.set 2 local.get 1 local.tee 3 drop local.get 2 drop local.get 3 drop))",
    "(module (func (param i32) (local i32 i32) local.get 0 local.set 1 i32.const 9 local.set 2 i32.const 0 local.set 2 local.get 1 drop local.get 2 drop))",
  ]
  for source in sources {
    let module = pass_test_module_from_wat(source)
    let context = @ir.hot_module_context_from_module(module)
    let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(0U),
    ).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = module.code_sec.unwrap().0[0]
    let types = cl_all_local_types(params, locals)
    let actions : Array[CLAction] = []
    cl_collect_instrs(body, actions, types.length())
    let liveness = cl_compute_liveness(actions, types.length())
    assert_eq(
      cl_compute_interferences(actions, liveness, types, params.length()).bits,
      cl_structured_live_reference(actions, liveness, types, params.length()).bits,
    )
  }
}
