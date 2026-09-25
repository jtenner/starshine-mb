///|
fn gr_public_type_perf_fixture(
  type_count : Int,
  global_count : Int,
) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string("(module\n")
  wat.write_string("(type $base (sub (struct)))\n")
  wat.write_string("(type $child (sub $base (struct)))\n")
  for _ in 2..<type_count {
    wat.write_string("(type (func))\n")
  }
  for idx in 0..<global_count {
    wat.write_string(
      "(global $g\{idx} (export \"g\{idx}\") (ref null $base) (ref.null $child))\n",
    )
  }
  wat.write_string(")")
  pass_test_module_from_wat(wat.to_string())
}

///|
fn gr_public_type_perf_bench(
  it : @bench.T,
  type_count : Int,
  global_count : Int,
) -> Unit {
  let fixture = gr_public_type_perf_fixture(type_count, global_count)
  let output = gr_refine_module(fixture)
  if output == fixture || @validate.validate_module(output).is_err() {
    abort("GlobalRefining public-type fixture did not refine validly")
  }
  it.bench(fn() { it.keep(gr_refine_module(fixture)) })
}

///|
test "GlobalRefining public-type scratch resets after each root query" {
  let fixture = gr_public_type_perf_fixture(16, 2)
  let env = @validate.Env::new().with_module(fixture)
  let scratch = GrPublicTypeScratch::new(env)
  let refined = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  assert_true(gr_refined_export_type_is_public(refined, env, scratch))
  assert_true(scratch.visited.is_empty())
  assert_true(scratch.states.all(fn(state) { state == 0 }))
  assert_true(gr_refined_export_type_is_public(refined, env, scratch))
  assert_true(scratch.visited.is_empty())
  assert_true(scratch.states.all(fn(state) { state == 0 }))
}

///|
test "bench GlobalRefining public types=128 globals=128" (it : @bench.T) {
  gr_public_type_perf_bench(it, 128, 128)
}

///|
test "bench GlobalRefining public types=256 globals=256" (it : @bench.T) {
  gr_public_type_perf_bench(it, 256, 256)
}
