///|
// Compare identical CFG/source work; full graphs also publish writer and SSA
// metadata. CFG construction is outside these solver-only controls.
fn read_flow_perf_run(it : @bench.T, count : Int, full : Bool) -> Unit {
  let (func, cfg, _, _) = entry_read_fixture(count)
  it.bench(fn() {
    if full {
      it.keep(local_graph_build_full_flow(func, cfg))
    } else {
      it.keep(local_graph_build_read_sources(func, cfg))
    }
  })
}

///|
test "bench conditional read flow 8 full" (it : @bench.T) {
  read_flow_perf_run(it, 8, true)
}

///|
test "bench conditional read flow 8 sources" (it : @bench.T) {
  read_flow_perf_run(it, 8, false)
}

///|
test "bench conditional read flow 64 full" (it : @bench.T) {
  read_flow_perf_run(it, 64, true)
}

///|
test "bench conditional read flow 64 sources" (it : @bench.T) {
  read_flow_perf_run(it, 64, false)
}

///|
test "bench conditional read flow 512 full" (it : @bench.T) {
  read_flow_perf_run(it, 512, true)
}

///|
test "bench conditional read flow 512 sources" (it : @bench.T) {
  read_flow_perf_run(it, 512, false)
}

///|
fn read_flow_cold_perf_run(it : @bench.T, full : Bool) -> Unit {
  let module_ = ir_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
  )
  it.bench(fn() {
    let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    let cfg = cfg_build(func, expand_operand_control=true)
    if full {
      it.keep(local_graph_build_full_flow(func, cfg))
    } else {
      it.keep(local_graph_build_read_sources(func, cfg))
    }
  })
}

///|
test "bench cold conditional read flow full" (it : @bench.T) {
  read_flow_cold_perf_run(it, true)
}

///|
test "bench cold conditional read flow sources" (it : @bench.T) {
  read_flow_cold_perf_run(it, false)
}
