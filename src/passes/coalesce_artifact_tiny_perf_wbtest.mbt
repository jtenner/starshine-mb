///|
// Dedicated threshold lane: artifact-scale scheduling is excluded from the
// bounded default suite. Each selected body has fixed, small analysis budgets.
#skip
test "O4s direct coalescing rewrites flat tiny bodies in a 2000-function module" {
  let seed = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 i32.const 1 i32.add local.set 2 local.get 2))",
  )
  let first = seed.code_sec.unwrap().0[0]
  let input = seed
    .with_func_sec(@lib.FuncSec::new(Array::make(2000, @lib.TypeIdx::new(0U))))
    .with_code_sec(@lib.CodeSec::new(Array::make(2000, first)))
  @validate.validate_module(input).unwrap()
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(optimize_level=4, shrink_level=1),
    ["coalesce-locals"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  let @lib.Func(original_locals, _) = input.code_sec.unwrap().0[0]
  assert_eq(original_locals.length(), 2)
  match output.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 2000)
    None => fail("expected retained function bodies")
  }
  assert_true(@binary.encode_module(output).unwrap().length() < @binary.encode_module(input).unwrap().length())
}
