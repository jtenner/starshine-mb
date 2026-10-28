///|
test "BURN-008 direct block result promotion preserves its source local read" {
  let input = pass_test_module_from_wat(
    (
      #|(module (func (export "run") (param $p i32) (result i32) (local $a i32) (local $b i32)
      #| local.get $p local.set $a local.get $a
      #| block local.get $a local.set $b i32.const 9 local.set $a end
      #| local.get $b i32.add))
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  assert_eq(cl_dew_execute_reduced_i32(@ir.hot_lower_func(func), [7]), 14)
  let root_ref = @ir.HotRegionRef::root()
  let mut block_idx = -1
  for idx in 0..<@ir.hot_root_count(func) {
    if @ir.hot_node_op(func, @ir.hot_root_get(func, idx)) is @ir.HotOp::Block {
      block_idx = idx
    }
  }
  assert_true(block_idx >= 0, msg="expected block root")
  let detached : Array[Int32] = []
  assert_true(
    simplify_locals_try_rewrite_block_return(
      func,
      root_ref,
      block_idx,
      @ir.hot_root_get(func, block_idx),
      simplify_locals_count_local_gets(func),
      detached,
    ),
  )
  simplify_locals_delete_detached_nodes(func, detached)
  let lowered = @ir.hot_lower_func(func)
  let output = input.with_code_sec(@lib.CodeSec::new([lowered]))
  ignore(@validate.validate_module(output).unwrap())
  assert_eq(cl_dew_execute_reduced_i32(lowered, [7]), 14)
}

///|
test "BURN-008 public variants preserve source snapshots across nested writes" {
  for pass in ["simplify-locals", "simplify-locals-notee"] {
    for
      write in [
        "i32.const 9 local.set $a", "block i32.const 9 local.tee $a drop end",
      ] {
      let input = pass_test_module_from_wat(
        "(module (func (export \"run\") (param $p i32) (result i32) (local $a i32) (local $b i32) local.get $p local.set $a local.get $a block local.get $a local.set $b " +
        write +
        " end local.get $b i32.add))",
      )
      @validate.validate_module(input).unwrap()
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
      @validate.validate_module(output).unwrap()
      for arg in [0, 7, -3] {
        assert_eq(
          cl_dew_execute_reduced_i32(input.code_sec.unwrap().0[0], [arg]),
          arg + arg,
        )
        assert_eq(
          cl_dew_execute_reduced_i32(output.code_sec.unwrap().0[0], [arg]),
          arg + arg,
        )
      }
    }
  }
}

///|
#cfg(target="js")
extern "js" fn simplify_locals_burn008_run_wasm(
  bytes : Bytes,
  arg : Int32,
) -> Int32 =
  #|(bytes, arg) => new WebAssembly.Instance(new WebAssembly.Module(bytes)).exports.run(arg)

///|
#cfg(target="js")
test "BURN-008 WebAssembly execution preserves block source snapshots" {
  let input = pass_test_module_from_wat(
    (
      #|(module (func (export "run") (param $p i32) (result i32) (local $a i32) (local $b i32)
      #| local.get $p local.set $a local.get $a
      #| block local.get $a local.set $b i32.const 9 local.set $a end
      #| local.get $b i32.add))
    ),
  )
  for pass in ["simplify-locals", "simplify-locals-notee"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    for arg in [0, 7, -3] {
      assert_eq(
        simplify_locals_burn008_run_wasm(
          @binary.encode_module(input).unwrap(),
          arg,
        ),
        arg + arg,
      )
      assert_eq(
        simplify_locals_burn008_run_wasm(
          @binary.encode_module(output).unwrap(),
          arg,
        ),
        arg + arg,
      )
    }
  }
}
