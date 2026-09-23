///|
test "dispatcher preserves case 259 and 367 multivalue loop after OI then DCE" {
  // Cases 259 and 367 reduce to this shape; only the sentinel and loop bound
  // differ. optimize-instructions turns the tee/drop increment into a set and
  // materializes the typed loop's unreachable tail before DCE runs.
  let wat =
    #|(module
    #|  (type $pair (func (result i32 f64)))
    #|  (func (param i32) (result i32 f64) (local i32 i32)
    #|    loop (type $pair)
    #|      local.get 0
    #|      local.tee 2
    #|      i32.const 76349679
    #|      i32.eq
    #|      if (type $pair)
    #|        local.get 2
    #|        f64.const 1.25
    #|        return
    #|      else
    #|        local.get 1
    #|        i32.const 4
    #|        i32.lt_u
    #|        if (result i32)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.tee 1
    #|          drop
    #|          i32.const 1
    #|        else
    #|          i32.const 0
    #|        end
    #|        if (type $pair)
    #|          br 2
    #|        else
    #|          local.get 2
    #|          f64.const 2.5
    #|          return
    #|        end
    #|      end
    #|    end))
  let input = @passes.pass_test_module_from_wat(wat)
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions", "dead-code-elimination"],
    OptimizeOptions::new(),
  ).unwrap()

  let @lib.Func(_, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  match body {
    [@lib.Unreachable] =>
      fail(
        "OI then DCE replaced the reachable typed loop with unconditional unreachable",
      )
    _ => ()
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("(br "), msg=pretty)
  assert_true(pretty.contains("F64(2.5)"), msg=pretty)
}
