///|
test "dispatcher DCE keeps block targeted only by try_table catch" {
  let wat =
    #|(module
    #|  (import "env" "side" (func $side))
    #|  (tag $e)
    #|  (func
    #|    block $handler
    #|      call $side
    #|      try_table (catch_all $handler)
    #|        call $side
    #|      end
    #|      call $side
    #|    end
    #|    block
    #|      i32.const 0
    #|      br_if 0
    #|      i32.const 0
    #|      drop
    #|    end))
  let input = @passes.pass_test_module_from_wat(wat)
  let optimized = match
    optimize_module_with_pass_flags(
      input,
      ["dead-code-elimination"],
      OptimizeOptions::new(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dispatcher try_table target preservation, got \{err}")
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid dispatcher try_table output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
}
