///|
test "bounded coalescing preserves intentionally unsupported stack-carried overwrite and rewrites independent helper" {
  let input = @passes.pass_test_module_from_wat(
    "(module (memory 1) (global i32 (i32.const 0)) (func $consume (param i32 i32) (result i32) local.get 0 local.get 1 i32.sub) (func (export \"overwrite\") (param i32 i32) (result i32) (local i32) local.get 0 local.set 2 global.get 0 local.get 2 i32.store local.get 2 local.get 1 local.set 2 global.get 0 local.get 2 i32.store offset=4 local.get 2 call $consume) (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 i32.const 1 i32.add local.set 2 local.get 2))",
  )
  let output = @passes.run_hot_pipeline(
    input,
    @passes.HotPipelineOptions::new(optimize_level=4, shrink_level=1),
    ["coalesce-locals"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0[1], input.code_sec.unwrap().0[1])
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[2]
  assert_eq(locals.length(), 0)
}
