///|
fn code_pushing_wbtest_lift_hot_raw(text : String) -> @ir.HotFunc {
  pass_test_lift_first_func(text)
}

///|
test "code-pushing segment inventory recognizes if push-point windows" {
  let func = code_pushing_wbtest_lift_hot_raw(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )

  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(func, @ir.HotRegionRef::root(), 0),
    "candidate:if",
  )
}

///|
test "code-pushing segment inventory recognizes dropped if push-point windows" {
  let func = code_pushing_wbtest_lift_hot_raw(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    i32.const 7
      #|    local.set 1
      #|    (drop
      #|      (if (result i32) (local.get 0)
      #|        (then (local.get 1))
      #|        (else (i32.const 0))))))
      #|
    ),
  )

  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(func, @ir.HotRegionRef::root(), 0),
    "candidate:dropped-if",
  )
}

///|
test "code-pushing segment inventory recognizes conditional branch push-point windows" {
  let func = code_pushing_wbtest_lift_hot_raw(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (drop
      #|      (block (result i32)
      #|        i32.const 7
      #|        local.set 1
      #|        local.get 1
      #|        local.get 0
      #|        br_if 0))))
      #|
    ),
  )

  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(
      func,
      @ir.hot_region_body_ref(func, block_id),
      0,
    ),
    "candidate:conditional-branch",
  )
}

///|
test "code-pushing segment inventory reports SFA rejection reasons" {
  let prefix_read = code_pushing_wbtest_lift_hot_raw(
    "(module (func (param i32) (local i32) local.get 1 drop i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )
  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(
      prefix_read,
      @ir.HotRegionRef::root(),
      1,
    ),
    "reject:prefix-local-read",
  )

  let multiple_writes = code_pushing_wbtest_lift_hot_raw(
    "(module (func (param i32) (local i32) i32.const 6 local.set 1 i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )
  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(
      multiple_writes,
      @ir.HotRegionRef::root(),
      1,
    ),
    "reject:multiple-local-writes",
  )
}

///|
test "code-pushing segment inventory reports ordered-before barriers" {
  let func = code_pushing_wbtest_lift_hot_raw(
    (
      #|(module
      #|  (global i32 (i32.const 9))
      #|  (memory 1)
      #|  (func (param i32) (local i32)
      #|    global.get 0
      #|    local.set 1
      #|    i32.const 0
      #|    i32.const 1
      #|    i32.store
      #|    local.get 0
      #|    if
      #|      local.get 1
      #|      drop
      #|    end))
      #|
    ),
  )

  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(func, @ir.HotRegionRef::root(), 0),
    "reject:ordered-before-barrier",
  )
}
