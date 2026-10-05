///|
test "DAE2 HOT fallback keeps discarded internal calls before later imports" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func $h (param i32 i32 i64) (result i32) i32.const 19 call 0 local.get 0 block (param i32 i32) (result i32) i32.div_s end) (func (export \"run\") (param i32) local.get 0 i32.const 0 i64.const 99 call $h drop i32.const 23 call 0 drop))",
  )
  for optimizing in [false, true] {
    let output = dae2_run_module_pass(
      input,
      optimizing,
      raw_analysis=false,
      raw_conditionals=false,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    let calls : Array[UInt] = []
    for instr in body {
      match instr {
        @lib.Call(@lib.FuncIdx(index)) => calls.push(index)
        _ => ()
      }
    }
    assert_eq(calls, [1U, 0U])
  }
}

///|
test "DAE2 HOT fallback retains carried import arguments before intervening writes" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func (param i32) (result i32))) (global $g (mut i32) (i32.const 0)) (func $h (param i32 i64) (result i32) local.get 0 global.get $g i32.add) (func (export \"run\") (result i32) global.get $g call 0 i32.const 5 global.set $g i64.const 99 call $h))",
  )
  for optimizing in [false, true] {
    let output = dae2_run_module_pass(
      input,
      optimizing,
      raw_analysis=false,
      raw_conditionals=false,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    let events : Array[Int] = []
    for instr in body {
      match instr {
        @lib.Call(@lib.FuncIdx(index)) =>
          events.push(index.reinterpret_as_int())
        @lib.GlobalSet(_) => events.push(-1)
        _ => ()
      }
    }
    assert_eq(events, [0, -1, 1])
  }
}
