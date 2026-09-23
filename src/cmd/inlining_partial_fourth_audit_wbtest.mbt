///|
fn cmd_fourth_partial_run(
  text : String,
  names : Array[(UInt, String)],
  passes : Array[String],
  options : OptimizeOptions,
) -> @lib.Module raise {
  let entries : Array[@lib.NameAssoc] = []
  for pair in names {
    let (idx, name) = pair
    entries.push(@lib.NameAssoc::new(idx, @lib.Name::from_string(name)))
  }
  let input = @passes.pass_test_module_from_wat(text).with_name_sec(
    @lib.NameSec::new(func_names=Some(@lib.NameMap::new(entries))),
  )
  match optimize_module_with_pass_flags(input, passes, options) {
    Ok(output) => output
    Err(err) => fail("partial inlining: \{err}")
  }
}

///|
test "fourth audit command inlining partial arms preserve parameter writes" {
  let output = cmd_fourth_partial_run(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32) local.get 0 if i32.const 0 local.set 1 end local.get 1 if i32.const 1 global.set $g end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    OptimizeOptions::new(
      optimize_level=3,
      inlining=InliningOptions::new(partial_inlining_ifs=4),
    ),
  )
  // An outlined call cannot propagate a parameter assignment back to its caller.
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
}

///|
test "fourth audit command inlining partial body read" {
  let output = cmd_fourth_partial_run(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32)  local.get 0 if i32.const 0 local.set 1 end local.get 0 if local.get 1 global.set $g end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    OptimizeOptions::new(
      optimize_level=3,
      inlining=InliningOptions::new(partial_inlining_ifs=4),
    ),
  )
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
}

///|
test "fourth audit command inlining partial nested body read" {
  let output = cmd_fourth_partial_run(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32)  local.get 0 if i32.const 0 local.set 1 end local.get 0 if block local.get 1 global.set $g end end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    OptimizeOptions::new(
      optimize_level=3,
      inlining=InliningOptions::new(partial_inlining_ifs=4),
    ),
  )
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
}

///|
test "fourth audit command inlining partial body local" {
  let output = cmd_fourth_partial_run(
    "(module (global $g (mut i32) (i32.const 0)) (func $maybe (param i32 i32) (local i32) local.get 0 if i32.const 7 local.set 2 end local.get 0 if local.get 2 global.set $g end) (func $left (export \"left\") (param i32 i32) local.get 0 local.get 1 call $maybe) (func $right (export \"right\") (param i32 i32) local.get 0 local.get 1 call $maybe))",
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    OptimizeOptions::new(
      optimize_level=3,
      inlining=InliningOptions::new(partial_inlining_ifs=4),
    ),
  )
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
}

///|
test "command inlining rejects Pattern B br_on_null outlined-arm escape" {
  let output = cmd_fourth_partial_run(
    (
      #|(module
      #|  (func $guarded (param i32 externref externref) (result externref)
      #|    local.get 0
      #|    if
      #|      block
      #|        local.get 1
      #|        br_on_null 1
      #|        drop
      #|      end
      #|      i32.const 3
      #|      drop
      #|      i32.const 4
      #|      drop
      #|      i32.const 5
      #|      drop
      #|      i32.const 6
      #|      drop
      #|      i32.const 7
      #|      drop
      #|      i32.const 8
      #|      drop
      #|      local.get 1
      #|      return
      #|    end
      #|    local.get 2)
      #|  (func $left (export "left") (param i32 externref externref) (result externref)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    call $guarded)
      #|  (func $right (export "right") (param i32 externref externref) (result externref)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    call $guarded))
    ),
    [(0U, "guarded"), (1U, "left"), (2U, "right")],
    ["no-full-inline=guarded", "inlining"],
    OptimizeOptions::new(
      optimize_level=3,
      shrink_level=0,
      inlining=InliningOptions::new(
        always_inline_max_size=0,
        one_caller_inline_max_size=0,
        flexible_inline_max_size=0,
        partial_inlining_ifs=1,
      ),
    ),
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
}
