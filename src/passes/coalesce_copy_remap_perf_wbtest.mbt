///|
fn cl_copy_remap_bench(it : @bench.T, count : Int, reference : Bool) -> Unit {
  let input = cl_copy_remap_fixture(count)
  let mapping = [0, 2, 1]
  let module_ = pass_test_module_from_wat(
    "(module (func (param i32) (local i32 i32)))",
  )
  let @lib.Func(locals, _) = module_.code_sec.unwrap().0[0]
  @validate.validate_module(
    module_.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(input))]),
    ),
  ).unwrap()
  let expected = cl_deep_copy_instrs(input)
  cl_rewrite_all_local_idxs_in_place(expected, mapping)
  if cl_copy_remap_instrs(input, mapping) != expected {
    abort("remap mismatch")
  }
  it.bench(fn() {
    let output = if reference {
      let output = cl_deep_copy_instrs(input)
      cl_rewrite_all_local_idxs_in_place(output, mapping)
      output
    } else {
      cl_copy_remap_instrs(input, mapping)
    }
    it.keep(output)
  })
}

///|
test "bench reuse-campaign coalesce remap regions=32 reference" (it : @bench.T) {
  cl_copy_remap_bench(it, 32, true)
}

///|
test "bench reuse-campaign coalesce remap regions=32 fused" (it : @bench.T) {
  cl_copy_remap_bench(it, 32, false)
}

///|
test "bench reuse-campaign coalesce remap regions=512 reference" (it : @bench.T) {
  cl_copy_remap_bench(it, 512, true)
}

///|
test "bench reuse-campaign coalesce remap regions=512 fused" (it : @bench.T) {
  cl_copy_remap_bench(it, 512, false)
}
