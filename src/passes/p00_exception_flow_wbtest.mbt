///|
fn p00_flow_count(
  body : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int {
  let mut count = 0
  for instr in body {
    if predicate(instr) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        count += p00_flow_count(nested, predicate)
      @lib.If(_, then_body, else_body) => {
        count += p00_flow_count(then_body, predicate)
        if else_body is Some(nested) {
          count += p00_flow_count(nested, predicate)
        }
      }
      @lib.Try(_, @lib.Expr(nested), catches, _) => {
        count += p00_flow_count(nested, predicate)
        for arm in catches {
          let @lib.Expr(nested) = match arm {
            @lib.LegacyCatch(_, nested) | @lib.LegacyCatchAll(nested) => nested
          }
          count += p00_flow_count(nested, predicate)
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "DCE raw fallthrough includes try-table catch targets in enclosing label space" {
  for
    (handler, result, drop_ref) in [
      ("catch_all 0", "", ""),
      ("catch 0 0", "", ""),
      ("catch_all_ref 0", "(result exnref)", "drop"),
      ("catch_ref 0 0", "(result exnref)", "drop"),
    ] {
    let input = pass_test_module_from_wat(
      "(module (tag) (func (block " +
      result +
      " (try_table (" +
      handler +
      ") (throw 0)) unreachable) " +
      drop_ref +
      "))",
    )
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    assert_true(run_hot_pipeline_dce_raw_body_may_fallthrough(body))
  }
  let input = pass_test_module_from_wat("(module (func (block return)))")
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_false(run_hot_pipeline_dce_raw_body_may_fallthrough(body))
}

///|
test "DCE retains catch-driven continuation values after a returning try body" {
  let output = pass_test_run_pipeline(
    "(module (tag $t) (func $thr (param i32) (if (local.get 0) (then (throw $t)))) (func (export \"f\") (result i32) (local $x i32) (local.set $x (block $h (result i32) (try_table (block $h2 (try_table (catch_all $h2) (call $thr (i32.const 1)) (return (i32.const 5))))) (i32.const 9))) (i32.add (local.get $x) (i32.const 100))))",
    ["dead-code-elimination"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(
    p00_flow_count(body, fn(instr) { instr is @lib.I32Const(@lib.I32(9)) }),
    1,
  )
  assert_eq(
    p00_flow_count(body, fn(instr) { instr is @lib.I32Const(@lib.I32(100)) }),
    1,
  )
}

///|
test "coalesce-locals retains loop writes visible through catch-all edges" {
  let output = pass_test_run_pipeline(
    "(module (tag $t) (func $thr (param i32) (if (local.get 0) (then (throw $t)))) (func (export \"f\") (result i32) (local $unused i32) (local $x i32) (loop $L (if (i32.const 0) (then) (else (local.set $x (i32.const 77))))) (block $h (try_table (catch_all $h) (call $thr (if (result i32) (i32.const 0) (then (i32.const 0)) (else (i32.const 3)))) (local.set $x (i32.const 0)))) (local.get $x)))",
    ["coalesce-locals"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(
    p00_flow_count(body, fn(instr) {
      instr is @lib.LocalSet(_) || instr is @lib.LocalTee(_)
    }),
    2,
  )
}
