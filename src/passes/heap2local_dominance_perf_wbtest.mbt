///|
fn h2l_dominance_perf_fixture(
  prefix_count : Int,
  read_count : Int,
) -> @lib.Module {
  let source = StringBuilder::new()
  source.write_string("(module (func (local i32)")
  for _ in 0..<prefix_count {
    source.write_string(" (drop (i32.const 0))")
  }
  source.write_string(" (local.set 0 (i32.const 1))")
  for _ in 0..<read_count {
    source.write_string(" (drop (local.get 0))")
  }
  source.write_string("))")
  pass_test_module_from_wat(source.to_string())
}

///|
fn h2l_dominance_perf_bench(
  it : @bench.T,
  prefix_count : Int,
  read_count : Int,
) -> Unit {
  let fixture = h2l_dominance_perf_fixture(prefix_count, read_count)
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let cfg = @ir.cfg_build(hot, expand_operand_control=true)
  let dom = @ir.dom_build(cfg)
  let mut write = -1
  let reads : Array[Int] = []
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    match @ir.hot_node_get(hot, node).op {
      @ir.HotOp::LocalSet => write = node
      @ir.HotOp::LocalGet => reads.push(node)
      _ => ()
    }
  }
  if write < 0 || reads.length() != read_count {
    abort("Heap2Local dominance fixture lost local accesses")
  }
  let check_order = H2LDominanceOrder::new(@ir.hot_node_count(hot))
  for read in reads {
    if !h2l_write_dominates_read(cfg, dom, check_order, write, read) {
      abort("Heap2Local dominance fixture has a nondominated read")
    }
  }
  it.bench(fn() {
    let order = H2LDominanceOrder::new(@ir.hot_node_count(hot))
    for read in reads {
      it.keep(h2l_write_dominates_read(cfg, dom, order, write, read))
    }
  })
}

///|
test "Heap2Local same-block dominance keeps read-before-write false" {
  let fixture = pass_test_module_from_wat(
    "(module (func (local i32) (drop (local.get 0)) (local.set 0 (i32.const 1)) (drop (local.get 0))))",
  )
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let cfg = @ir.cfg_build(hot, expand_operand_control=true)
  let dom = @ir.dom_build(cfg)
  let order = H2LDominanceOrder::new(@ir.hot_node_count(hot))
  let mut write = -1
  let reads : Array[Int] = []
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    match @ir.hot_node_get(hot, node).op {
      @ir.HotOp::LocalSet => write = node
      @ir.HotOp::LocalGet => reads.push(node)
      _ => ()
    }
  }
  assert_eq(reads.length(), 2)
  assert_false(h2l_write_dominates_read(cfg, dom, order, write, reads[0]))
  assert_true(h2l_write_dominates_read(cfg, dom, order, write, reads[1]))
}

///|
test "bench Heap2Local dominance prefix=0 reads=128" (it : @bench.T) {
  h2l_dominance_perf_bench(it, 0, 128)
}

///|
test "bench Heap2Local dominance prefix=512 reads=128" (it : @bench.T) {
  h2l_dominance_perf_bench(it, 512, 128)
}

///|
test "bench Heap2Local dominance prefix=512 reads=256" (it : @bench.T) {
  h2l_dominance_perf_bench(it, 512, 256)
}
