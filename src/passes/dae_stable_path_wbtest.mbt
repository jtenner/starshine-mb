///|
test "dae stable paths append deep prefixes persistently" {
  let mut path = DaeStablePath::empty()
  for value in 0..<512 {
    path = path.append(value)
  }
  assert_eq(path.length(), 512)
  assert_eq(path.to_array(), Array::makei(512, fn(index) { index }))
  let sibling = path.append(999)
  assert_eq(path.length(), 512)
  assert_eq(sibling.length(), 513)
  assert_eq(sibling.to_array().last(), Some(999))
}

///|
test "dae stable paths materialize artifact-scale nesting without recursion" {
  let depth = 32768
  let mut path = DaeStablePath::empty()
  for value in 0..<depth {
    path = path.append(value)
  }
  let materialized = path.to_array()
  assert_eq(materialized.length(), depth)
  assert_eq(materialized[0], 0)
  assert_eq(materialized[depth - 1], depth - 1)
}

///|
test "dae stable call paths intern nested prefixes linearly" {
  let depth = 4096
  let paths : Array[DaeStablePath] = []
  let mut prefix = DaeStablePath::empty()
  for _ in 0..<depth {
    paths.push(prefix.append(0))
    prefix = prefix.append(1).append(0)
  }
  let selection = dae_stable_rewrite_selection(paths).unwrap()
  assert_true(selection.workspace.nodes.length() <= depth * 3)
  assert_true(selection.selected_nodes <= depth * 3)
}

///|
test "dae stable call selection stays sparse across unrelated paths" {
  let root = DaeStablePath::empty()
  let paths : Array[DaeStablePath] = []
  for index in 0..<4096 {
    paths.push(root.append(index))
  }
  let selection = dae_stable_rewrite_selection([paths[2048]]).unwrap()
  assert_eq(selection.workspace.nodes.length(), 4096)
  assert_eq(selection.selected_nodes, 1)
}

///|
test "dae stable rewrite rebuilds each nested scope once" {
  let depth = 32
  let source = StringBuilder::new()
  source.write_string(
    "(module (type (func (param i32))) (func $target (type 0) (param i32)) (func",
  )
  for value in 0..<depth {
    source.write_string(" i32.const \{value} call $target")
    if value + 1 < depth {
      source.write_string(" block")
    }
  }
  for _ in 1..<depth {
    source.write_string(" end")
  }
  source.write_string("))")
  let input = pass_test_module_from_wat(source.to_string())
  let analysis = dae_collect_current_function_analysis(input, 2)
  let funcs = input.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(body)) = funcs[1]
  let stats = DaeStableRewriteStats::new()
  let result = dae_rewrite_calls_from_stable_callsites(
    body,
    0,
    [true],
    input,
    dae_collect_func_type_indices(input),
    analysis.function_infos[0],
    1,
    {
      first_scratch_local: 0,
      param_types: [@lib.ValType::i32()],
      scratch_local_types: [],
      localized_params: [false],
    },
    rewrite_stats=Some(stats),
  )
  assert_true(result.ok)
  assert_eq(result.calls_rewritten, depth)
  assert_eq(stats.calls, depth)
  assert_eq(stats.scopes, depth)
  assert_eq(stats.structured_rebuilds, depth - 1)
}
