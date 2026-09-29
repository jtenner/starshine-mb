///|
test "command local-flow passes preserve parameterized if entry calls" {
  for
    pass in [
      "coalesce-locals", "dae2", "dae2-optimizing", "precompute", "precompute-propagate",
      "optimize-instructions", "simplify-locals", "heap-store-optimization", "merge-locals",
      "ssa", "vacuum",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"value\" (func $value (result i32))) (import \"m\" \"condition\" (func $condition (result i32))) (func (export \"run\") (result i32) call $value call $condition if (param i32) (result i32) i32.const 3 i32.add else i32.const 2 i32.add end))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
    assert_eq(body[1], @lib.Instruction::call(@lib.FuncIdx::new(1U)))
    for target in 0U..<2U {
      assert_eq(
        cmd_deep_audit_count(body, fn(instr) {
          instr is @lib.Call(index) && index == @lib.FuncIdx::new(target)
        }),
        1,
      )
    }
  }
}

///|
test "command passes retain typed if entries when a constant selects implicit else" {
  for
    pass in [
      "coalesce-locals", "dae2", "dae2-optimizing", "precompute", "precompute-propagate",
      "optimize-instructions", "simplify-locals", "heap-store-optimization", "merge-locals",
      "ssa", "vacuum",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"value\" (func $value (result i32))) (func (export \"run\") (result i32) call $value i32.const 0 if (param i32) (result i32) i32.const 3 i32.add end))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.Call(@lib.FuncIdx(0U))
      }),
      1,
    )
  }
}

///|
test "command passes preserve tuple entry calls and typed if label payloads" {
  for
    pass in [
      "coalesce-locals", "dae2", "dae2-optimizing", "precompute", "precompute-propagate",
      "optimize-instructions", "simplify-locals", "heap-store-optimization", "merge-locals",
      "ssa", "vacuum",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"pair\" (func $pair (result i32 i64))) (func (export \"run\") (param i32) (result i32 i64) call $pair local.get 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add br 0 else i64.const 2 i64.add br 0 end))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.Call(@lib.FuncIdx(0U))
      }),
      1,
    )
  }
}

///|
test "command passes reuse scalar typed if entries without scratch locals" {
  for
    pass in [
      "coalesce-locals", "dae2", "dae2-optimizing", "precompute-propagate", "optimize-instructions",
      "simplify-locals", "heap-store-optimization", "merge-locals", "ssa", "vacuum",
    ] {
    let output = cmd_deep_audit_run(
      "(module (func (export \"run\") (param i32) (result i32 i64) i32.const 4 i64.const 7 local.get 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add else i64.const 2 i64.add end))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_eq(locals.runs().length(), 0)
    let body = cmd_deep_audit_body(output)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.LocalSet(_) || instr is @lib.LocalTee(_)
      }),
      0,
    )
  }
}

///|
test "command passes retain tuple entries when a constant selects implicit else" {
  for
    pass in [
      "coalesce-locals", "dae2", "dae2-optimizing", "precompute", "precompute-propagate",
      "optimize-instructions", "simplify-locals", "heap-store-optimization", "merge-locals",
      "ssa", "vacuum",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"pair\" (func $pair (result i32 i64))) (func (export \"run\") (result i32 i64) call $pair i32.const 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add end))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.Call(@lib.FuncIdx(0U))
      }),
      1,
    )
  }
}

///|
test "command cleanup keeps global entry effects before trapping typed if arms" {
  for
    pass in [
      "simplify-locals", "simplify-locals-nostructure", "simplify-locals-notee",
      "simplify-locals-nonesting", "simplify-locals-notee-nostructure", "heap-store-optimization",
      "precompute", "precompute-propagate", "optimize-instructions", "coalesce-locals",
      "ssa", "vacuum",
    ] {
    let output = cmd_deep_audit_run(
      "(module (global $g (export \"g\") (mut i32) (i32.const 0)) (func (export \"run\") (param i32) block (result i32) i32.const 7 global.set $g i32.const 9 end local.get 0 if (param i32) unreachable else unreachable end))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.GlobalSet(@lib.GlobalIdx(0U))
      }),
      1,
    )
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        instr is @lib.I32Const(@lib.I32(7))
      }),
      1,
    )
    assert_true(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.Unreachable }) >= 1,
    )
  }
}
