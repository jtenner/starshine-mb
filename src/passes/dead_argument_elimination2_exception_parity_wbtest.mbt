///|
fn dae2_exception_parity_count_dispatch(body : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Throw(_) | @lib.TryTable(_, _, _) => count += 1
      _ => ()
    }
    ignore(
      pass_lower_map_children(instr, fn(children) {
        count += dae2_exception_parity_count_dispatch(children)
        children
      }),
    )
  }
  count
}

///|
fn dae2_exception_parity_count_void_blocks(
  body : Array[@lib.Instruction],
) -> Int {
  let mut count = 0
  for instr in body {
    if instr is @lib.Block(@lib.VoidBlockType, _) {
      count += 1
    }
    ignore(
      pass_lower_map_children(instr, fn(children) {
        count += dae2_exception_parity_count_void_blocks(children)
        children
      }),
    )
  }
  count
}

///|
test "DAE2 exception parity folds known local tag dispatch after signature pruning" {
  for pass in ["dae2", "dae2-optimizing"] {
    let input = pass_test_module_from_wat(
      "(module (tag (param i32)) (global (export \"effects\") (mut i32) (i32.const 0)) (func (param i32) (result i32) global.get 0 i32.const 1 i32.add global.set 0 local.get 0) (func (param i32) global.get 0 i32.const 2 i32.add global.set 0) (func (export \"run\") (result i32) (try (result i32) (do (throw 0 (i32.const 37))) (catch 0 (call 0) (call 1) (i32.const 37)) (catch_all (i32.const 36)))))",
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    @debug.assert_eq(dae2_exception_parity_count_dispatch(body), 0)
    @debug.assert_eq(dae2_exception_parity_count_void_blocks(body), 0)
    @debug.assert_eq(dae2_test_count_calls(body), 2)
    @debug.assert_eq(dae2_test_signature(output, 0), @lib.FuncType::new([], []))
    @debug.assert_eq(dae2_test_signature(output, 1), @lib.FuncType::new([], []))
  }
}

///|
test "DAE2 exception parity selects later local tags and catch-all in declaration order" {
  for
    last_catch in [
      "(catch 1 (drop) (i32.const 36))", "(catch_all (i32.const 36))",
    ] {
    let input = pass_test_module_from_wat(
      "(module (tag (param i32)) (tag (param i32)) (global (export \"effects\") (mut i32) (i32.const 0)) (func (param i32) (result i32) global.get 0 i32.const 1 i32.add global.set 0 local.get 0) (func (param i32) global.get 0 i32.const 2 i32.add global.set 0) (func (export \"run\") (result i32) (try (result i32) (do (throw 1 (i32.const 37))) (catch 0 (call 0) (call 1) (i32.const 37)) \{last_catch})))",
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    @debug.assert_eq(dae2_exception_parity_count_dispatch(body), 0)
  }
}

///|
test "DAE2 exception parity retains dispatch outside the known local tag proof" {
  // Folding imported-tag aliases or a potentially throwing payload call is
  // intentionally unsupported by this local proof, since either can select
  // a different handler before the final throw.
  for
    (imports, tags, payload, earlier_catch) in [
      (
        "(import \"m\" \"u\" (tag $u (param i32))) (import \"m\" \"t\" (tag $t (param i32)))",
        "", "(i32.const 37)", "(catch $u (drop) (i32.const 35))",
      ),
      (
        "(import \"m\" \"get\" (func $get (result i32)))", "(tag $t (param i32))",
        "(call $get)", "",
      ),
    ] {
    let input = pass_test_module_from_wat(
      "(module \{imports} \{tags} (global $count (mut i32) (i32.const 0)) (func $producer (param i32) (result i32) global.get $count i32.const 1 i32.add global.set $count local.get 0) (func $sink (param i32) global.get $count i32.const 2 i32.add global.set $count) (func (export \"run\") (result i32) (try (result i32) (do (throw $t \{payload})) \{earlier_catch} (catch $t (call $producer) (call $sink) (i32.const 37)) (catch_all (i32.const 36)))))",
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0
      .last()
      .unwrap()
    assert_true(dae2_exception_parity_count_dispatch(body) > 0)
  }
}

///|
test "DAE2 exception parity retains captured exception identity for rethrow" {
  // A plain branch cannot materialize the exception reference. This fold is
  // intentionally unsupported when the selected handler captures that identity.
  let input = pass_test_module_from_wat(
    "(module (tag $t (param i32)) (func $sink (param i32)) (func (export \"run\") (local $e exnref) (block $caught (result i32 (ref exn)) (try_table (catch_ref $t $caught) (throw $t (i32.const 37))) unreachable) local.set $e call $sink local.get $e ref.as_non_null throw_ref))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(dae2_exception_parity_count_dispatch(body) > 0)
}
