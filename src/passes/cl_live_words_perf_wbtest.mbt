///|
fn cl_live_words_bench(it : @bench.T, width : Int, dense : Bool) -> Unit raise {
  let last = width - 1
  let body : Array[@lib.Instruction] = []
  for _ in 0..<16 {
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(last.to_uint())))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(last.to_uint())))
    body.push(@lib.Instruction::drop())
  }
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, width)
  let effective = Array::make(actions.length(), false)
  let hazards = CLBitMatrix::new(width)
  let visited = [0]
  let cursor = [actions.length() - 1]
  let live_after = Array::makei(width, fn(i) { dense || i == 0 })
  let saved = live_after.copy()
  let index = cl_control_index_for_body(body, None)
  assert_eq(
    cl_branch_live_storage_result(body, live_after, [], [], false),
    cl_branch_live_storage_result(body, live_after, [], [], true),
  )
  let packed_after = cl_live_words_from_bools(live_after)
  it.bench(fn() {
    hazards.bits.fill(false)
    visited[0] = 0
    cursor[0] = actions.length() - 1
    it.keep(
      cl_mark_structured_live_words_backward(
        body,
        actions,
        effective,
        hazards,
        visited,
        packed_after,
        [],
        cursor,
        control_index=index,
      ),
    )
    it.keep(effective)
    it.keep(hazards)
  })
  assert_eq(live_after, saved)
}

///|
test "bench CL structured live words tiny sparse" (it : @bench.T) {
  cl_live_words_bench(it, 8, false)
}

///|
test "bench CL structured live words tiny dense" (it : @bench.T) {
  cl_live_words_bench(it, 8, true)
}

///|
test "bench CL structured live words wide sparse" (it : @bench.T) {
  cl_live_words_bench(it, 512, false)
}

///|
test "bench CL structured live words wide dense" (it : @bench.T) {
  cl_live_words_bench(it, 512, true)
}
