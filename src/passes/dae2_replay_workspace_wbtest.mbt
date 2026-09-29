///|
test "DAE2 replay workspace clears prior body edges without changing solved module boundaries" {
  let source = Dae2Graph::new()
  ignore(source.locations(2))
  source.observe(1)
  source.solve()
  let saved_used = source.used.copy()
  let saved_work = source.work.copy()
  let saved_cursor = source.cursor
  let replay = source.for_raw_rewrite(2)
  assert_eq(replay.locations(2), 2)
  replay.edge(1, 2)
  replay.edge(0, 3)
  replay.solve()
  assert_eq(replay.used, [false, true, true, false])
  replay.reset_for_raw_rewrite(source, 2)
  assert_eq(replay.locations(1), 2)
  replay.edge(0, 2)
  replay.solve()
  assert_eq(replay.used, [false, true, false])
  assert_eq(source.used, saved_used)
  assert_eq(source.work, saved_work)
  assert_eq(source.cursor, saved_cursor)
  assert_true(source.edges.is_empty())
}

///|
test "DAE2 replay workspace preserves exact output across differently sized changed bodies" {
  ignore(
    dae2_raw_analysis_compare_fixture(
      "(module (global $g (mut i32) (i32.const 0)) (func $a (param i32 i32) (result i32) local.get 1 i32.const 7 i32.add i32.const 9 i32.mul) (func $b (param i32 i32) local.get 0 global.set $g local.get 1 drop) (func $c (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) i32.const 8 local.get 0 call $a drop local.get 0 i32.const 11 call $b local.get 0 i32.const 9 call $c))",
    ),
  )
}
