///|
test "HOT private lowering borrows control parameters without changing signatures" {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32 i64) i32.const 4 i64.const 7 local.get 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add else i64.const 2 i64.add end))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let original_bytes = @binary.encode_module(module_).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let mut checked = false
  for id in 0..<hot_node_count(func) {
    let node = hot_node_get(func, id)
    if node.op is HotOp::If {
      match hot_type_get(func, node.ty) {
        BlockResultResolved(_, params, _) => {
          assert_eq(params, [@lib.ValType::i32(), @lib.ValType::i64()])
          assert_true(
            physical_equal(hot_lower_impl_control_param_types(func, id), params),
          )
          checked = true
        }
        _ => fail("typed if has no resolved signature")
      }
    }
  }
  assert_true(checked)
  let first = hot_lower_func(func)
  let second = hot_lower_func(func)
  @validate.validate_module(module_.with_code_sec(@lib.CodeSec::new([first]))).unwrap()
  assert_eq(
    @binary.encode_module(module_.with_code_sec(@lib.CodeSec::new([second]))).unwrap(),
    original_bytes,
  )
  assert_eq(@binary.encode_module(module_).unwrap(), original_bytes)
}
