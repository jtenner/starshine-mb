///|
test "SSA unwritten-default cleanup visits legacy try and catch writes" {
  let input = @wast.wast_to_binary_module(
    "(module (func (local i32) (try (do i32.const 7 local.set 0) (catch_all i32.const 9 local.set 0)) local.get 0 drop))",
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let written = @bitset.BitSet::new(1)
  run_hot_pipeline_raw_ssa_nomerge_mark_written_locals(body, written)
  assert_true(written[0])
  let changed : SsaNoMergeRawRewriteCursor = {
    write_cursor: 0,
    get_cursor: 0,
    changed: false,
  }
  let output = run_hot_pipeline_raw_ssa_nomerge_materialize_all_unwritten_defaults_body(
    body,
    [],
    locals,
    @bitset.BitSet::new(1),
    changed,
  )
  assert_eq(output[1], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
}
