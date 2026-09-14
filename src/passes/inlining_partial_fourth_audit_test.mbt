///|
test "fourth audit inlining partial arms preserve parameter writes" {
  let output = inl_test_run_named_with_options(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32) local.get 0 if i32.const 0 local.set 1 end local.get 1 if i32.const 1 global.set $g end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  // An outlined call cannot propagate a parameter assignment back to its caller.
  @debug.assert_eq(
    inl_test_count_named_func(output, "byn-split-outlined-B$maybe"),
    0,
  )
}

///|
test "fourth audit inlining partial body read" {
  let output = inl_test_run_named_with_options(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32)  local.get 0 if i32.const 0 local.set 1 end local.get 0 if local.get 1 global.set $g end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  @debug.assert_eq(
    inl_test_count_named_func(output, "byn-split-outlined-B$maybe"),
    0,
  )
}

///|
test "fourth audit inlining partial nested body read" {
  let output = inl_test_run_named_with_options(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32)  local.get 0 if i32.const 0 local.set 1 end local.get 0 if block local.get 1 global.set $g end end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  @debug.assert_eq(
    inl_test_count_named_func(output, "byn-split-outlined-B$maybe"),
    0,
  )
}

///|
test "fourth audit inlining partial body local" {
  let output = inl_test_run_named_with_options(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32) (local i32) local.get 0 if i32.const 7 local.set 2 end local.get 0 if local.get 2 global.set $g end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  @debug.assert_eq(
    inl_test_count_named_func(output, "byn-split-outlined-B$maybe"),
    0,
  )
}
