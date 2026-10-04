///|
fn lift_provenance_demand_bench(
  it : @bench.T,
  width : Int,
  record : Bool,
) -> Unit {
  let body = StringBuilder::new()
  body.write_string("(module (func (param i32) (local i32) ")
  for _ in 0..<width {
    body.write_string("local.get 0 local.set 1 local.get 1 drop ")
  }
  body.write_string("))")
  let input = @wast.wast_to_binary_module(body.to_string()).unwrap()
  let context = hot_module_context_from_module(input)
  it.bench(fn() {
    it.keep(
      hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(0U),
        context,
        capture_stack_locals=true,
        materialize_multi_values=true,
        record_local_accesses=record,
      ),
    )
  })
}

///|
test "bench lift provenance width=8 default control" (it : @bench.T) {
  lift_provenance_demand_bench(it, 8, true)
}

///|
test "bench lift provenance width=8 omitted" (it : @bench.T) {
  lift_provenance_demand_bench(it, 8, false)
}

///|
test "bench lift provenance width=512 default control" (it : @bench.T) {
  lift_provenance_demand_bench(it, 512, true)
}

///|
test "bench lift provenance width=512 omitted" (it : @bench.T) {
  lift_provenance_demand_bench(it, 512, false)
}
