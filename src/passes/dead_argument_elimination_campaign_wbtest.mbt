///|
test "campaign dae suffix requires proven actual value and effects" {
  for then_body in ["i32.const 1", "call $effect i32.const 169472"] {
    let source = "(module (global $g i32 (i32.const 169472)) " +
      "(func $caller (param i32 i32 i32 i32 i32 i32 i32) (result i32) " +
      "local.get 0 local.get 1 local.get 2 local.get 3 local.get 4 local.get 5 local.get 6 " +
      "global.get $g if (result i32) " +
      then_body +
      " else i32.const 2 end i32.const 0 if end i32.const 35864 call $callee) " +
      "(func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32) " +
      "local.get 7 local.get 8 i32.add) (func $effect unreachable))"
    let input = pass_test_module_from_wat(source)
    let @lib.CodeSec(funcs) = input.code_sec.unwrap()
    assert_true(
      dae_try_rewrite_func313_call323_global_suffix(
        input,
        funcs,
        input.func_sec.unwrap().0,
        0,
        1,
      )
      is None,
      msg=then_body,
    )
  }
}

///|
test "campaign dae suffix preserves executed else effects" {
  let input = pass_test_module_from_wat(
    (
      #|(module (global $g i32 (i32.const 169472))
      #| (func $caller (param i32 i32 i32 i32 i32 i32 i32) (result i32)
      #| local.get 0 local.get 1 local.get 2 local.get 3 local.get 4 local.get 5 local.get 6
      #| global.get $g if (result i32) i32.const 169472 else i32.const 2 end
      #| i32.const 0 if else unreachable end i32.const 35864 call $callee)
      #| (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)
      #| local.get 7 local.get 8 i32.add))
    ),
  )
  assert_true(
    dae_try_rewrite_func313_call323_global_suffix(
      input,
      input.code_sec.unwrap().0,
      input.func_sec.unwrap().0,
      0,
      1,
    )
    is None,
  )
}

///|
test "campaign dae dropped suffix preserves executed effects" {
  let input = pass_test_module_from_wat(
    (
      #|(module (global $g i32 (i32.const 169472))
      #| (func $caller (param i32 i32 i32 i32 i32 i32 i32) (local i32)
      #| block (result i32)
      #| global.get $g if (result i32) unreachable else i32.const 2 end
      #| local.set 7 i32.const 0 if end local.get 7 end drop call $callee)
      #| (func $callee))
    ),
  )
  assert_true(
    dae_try_strip_func313_dropped_call323_global_suffix(
      input,
      input.code_sec.unwrap().0,
      0,
      1,
    )
    is None,
  )
}
