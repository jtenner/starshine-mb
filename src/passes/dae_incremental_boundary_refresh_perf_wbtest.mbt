///|
fn dae_incremental_refresh_bench(
  it : @bench.T,
  siblings : Int32,
  full : Bool,
) -> Unit raise {
  let declarations = Array::makei(siblings, fn(index) {
    let calls = Array::make(64, "call $target drop").join(" ")
    "(func $side\{index} (param i32) (result i32) \{calls} local.get 0)"
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func $target (result i32) i32.const 7) " +
    "(func (export \"run\") (result i32) call $target) \{declarations})",
  )
  let saved = @binary.encode_module(input).unwrap()
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::from_types([]),
    @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(8))]),
  )
  let next = input.with_code_sec(@lib.CodeSec::new(funcs))
  let graph = dae_current_boundary_graph_new(input)
  let reference = dae_current_boundary_graph_new(input)
  let changed_defs = Array::make(siblings + 2, false)
  changed_defs[0] = true
  dae_current_boundary_graph_refresh_full(reference, next)
  assert_true(
    dae_try_refresh_current_boundary_graph_incremental(
      graph,
      next,
      forced_changed_defs=Some(changed_defs),
    ),
  )
  dae_refresh_assert_graphs(graph, reference)
  let mut flip = false
  it.bench(fn() {
    let selected = if flip { next } else { input }
    flip = !flip
    if full {
      dae_current_boundary_graph_refresh_full(graph, selected)
    } else {
      it.keep(
        dae_try_refresh_current_boundary_graph_incremental(
          graph,
          selected,
          forced_changed_defs=Some(changed_defs),
        ),
      )
    }
    it.keep(graph)
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE refresh 0 siblings full reference" (it : @bench.T) {
  dae_incremental_refresh_bench(it, 0, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE refresh 0 siblings incremental" (it : @bench.T) {
  dae_incremental_refresh_bench(it, 0, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE refresh 32 siblings full reference" (it : @bench.T) {
  dae_incremental_refresh_bench(it, 32, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE refresh 32 siblings incremental" (it : @bench.T) {
  dae_incremental_refresh_bench(it, 32, false)
}
