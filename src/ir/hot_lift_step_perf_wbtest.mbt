///|
fn lift_step_bench(it : @bench.T, width : Int, structured : Bool) -> Unit {
  let source = StringBuilder::new()
  source.write_string("(module (func (param i32) (local i32) ")
  for _ in 0..<width {
    source.write_string(
      if structured {
        "local.get 0 if local.get 1 i32.const 3 i32.add local.set 1 else i32.const 7 local.set 1 end "
      } else {
        "local.get 0 i32.const 7 i32.add local.tee 1 drop "
      },
    )
  }
  source.write_string("))")
  let input = @wast.wast_to_binary_module(source.to_string()).unwrap()
  let context = hot_module_context_from_module(input)
  it.bench(fn() {
    let lifted = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
    ).unwrap()
    it.keep(hot_node_count(lifted))
  })
}

///|
test "bench complete lift scalar width=1" (it : @bench.T) {
  lift_step_bench(it, 1, false)
}

///|
test "bench complete lift scalar width=64" (it : @bench.T) {
  lift_step_bench(it, 64, false)
}

///|
test "bench complete lift scalar width=1024" (it : @bench.T) {
  lift_step_bench(it, 1024, false)
}

///|
test "bench complete lift structured width=1" (it : @bench.T) {
  lift_step_bench(it, 1, true)
}

///|
test "bench complete lift structured width=64" (it : @bench.T) {
  lift_step_bench(it, 64, true)
}

///|
test "bench complete lift structured width=1024" (it : @bench.T) {
  lift_step_bench(it, 1024, true)
}
