///|
fn cl_branch_live_storage_bench(
  it : @bench.T,
  branch_count : Int,
  local_count : Int,
) -> Unit raise {
  let locals = Array::make(local_count - 1, "i32").join(" ")
  let source = Array::make(
    branch_count, "local.get 0 if local.get 1 local.set 2 else local.get 3 local.set 2 end",
  ).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local \{locals}) \{source} local.get 2 drop))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let live_after = Array::makei(local_count, fn(i) { i % 3 == 0 })
  let saved = live_after.copy()
  assert_eq(
    cl_branch_live_storage_result(body, live_after, [], [], false),
    cl_branch_live_storage_result(body, live_after, [], [], true),
  )
  let actions : Array[CLAction] = []
  let control_index = cl_control_index_for_body(body, None)
  cl_collect_instrs(body, actions, local_count, control_index~)
  it.bench(fn() {
    it.keep(
      cl_mark_structured_liveness_backward(
        body,
        actions,
        Array::make(actions.length(), false),
        CLBitMatrix::new(local_count),
        [0],
        live_after,
        [],
        [actions.length() - 1],
        control_index~,
      ),
    )
  })
  assert_eq(live_after, saved)
}

///|
test "bench CL branch join one branch four locals" (it : @bench.T) {
  cl_branch_live_storage_bench(it, 1, 4)
}

///|
test "bench CL branch join 32 branches four locals" (it : @bench.T) {
  cl_branch_live_storage_bench(it, 32, 4)
}

///|
test "bench CL branch join 32 branches 256 locals" (it : @bench.T) {
  cl_branch_live_storage_bench(it, 32, 256)
}

///|
test "bench CL branch join no-branch 256 locals control" (it : @bench.T) {
  cl_branch_live_storage_bench(it, 0, 256)
}
