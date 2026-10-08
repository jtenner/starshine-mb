///|
test "command ssa merges a write bypassed by nested operand control" {
  let output = cmd_deep_audit_run(
    "(module (func (export \"f\") (param $p i32) (result i32) (local $x i32) (local.set $x (i32.const 5)) (drop (block $v (result i32) (local.set $x (if (result i32) (local.get $p) (then (br_if $v (i32.const 0) (i32.const 1))) (else (i32.const 0)))) (i32.const 0))) (local.get $x)))",
    "ssa",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output)
  let target = match body.last() {
    Some(@lib.LocalGet(target)) => target
    _ => abort("expected final SSA local read")
  }
  assert_eq(
    cmd_deep_audit_count(body, fn(instr) {
      match instr {
        @lib.LocalSet(local) | @lib.LocalTee(local) => local == target
        _ => false
      }
    }),
    2,
  )
}

///|
test "command ssa-nomerge keeps a single-write body local and its escaping read together" {
  for write in ["local.set", "local.tee"] {
    let drop = if write == "local.tee" { "drop" } else { "" }
    let output = cmd_deep_audit_run(
      "(module (import \"env\" \"log\" (func $log)) (memory 1) (func (export \"f\") (param i32) (result i32) (local i32) (call $log) (block (" +
      write +
      " 1 (if (result i32) (i32.const 1) (then (local.get 0)) (else (i32.load (i32.const 0))))) " +
      drop +
      ") (call $log) (local.get 1)))",
      "ssa-nomerge",
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    let target = match body.last() {
      Some(@lib.LocalGet(target)) => target
      _ => abort("expected final scratch read")
    }
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        match instr {
          @lib.LocalSet(local) | @lib.LocalTee(local) => local == target
          _ => false
        }
      }),
      1,
    )
  }
}

///|
test "command merge-locals preserves source read when a throw skips its copy" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"log\" (func $log (param i32) (result i32))) (tag $t (param i32)) (func $thr (param i32) (if (local.get 0) (then (throw $t (i32.const 42))))) (func (param i32) (result i32) (local i32 i32) (local.set 1 (call $log (i32.const 1))) (block $h (try_table (catch_all $h) (call $thr (local.get 0)) (local.set 2 (local.get 1)))) (local.get 1)))",
    "merge-locals",
  )
  @validate.validate_module(output).unwrap()
  assert_eq(
    cmd_deep_audit_body(output, index=1).last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(1U))),
  )
}

///|
test "command ssa-nomerge retains legacy try writes before later reads" {
  let output = cmd_deep_audit_run(
    "(module (tag $t (param i32)) (func $thr (param i32) (if (local.get 0) (then (throw $t (i32.const 42))))) (func (param i32) (result i32) (local i32) (try (do (call $thr (local.get 0)) (local.set 1 (i32.const 7))) (catch_all)) (local.get 1)))",
    "ssa-nomerge",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output, index=1)
  assert_true(body.last() is Some(@lib.LocalGet(_)))
  assert_eq(
    cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Const(@lib.I32(7)) }),
    1,
  )
}

///|
test "command simplify-globals-optimizing preserves empty then branch selection" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"log\" (func $log (param i32))) (global $g5 (mut i32) (i32.const -1)) (global $p (mut i32) (i32.const 1)) (func $w (global.set $p (i32.const 0))) (func (export \"f\") (if (block $B (result i32) (drop (br_if $B (block $C (result i32) (drop (br_if $C (i32.const 3) (global.get $g5))) (i32.const 0)) (global.get $p))) (i32.const 0)) (then) (else (call $log (i32.const 0))))))",
    "simplify-globals-optimizing",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output, index=1)
  assert_false(body.any(fn(instr) { instr is @lib.Call(@lib.FuncIdx(0U)) }))
  assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Eqz }), 1)
}

///|
test "command ssa-nomerge retains a repeated nested write and its later read" {
  for parameter in [false, true] {
    let signature = if parameter {
      "(param i32) (result i32)"
    } else {
      "(result i32) (local i32)"
    }
    let output = cmd_deep_audit_run(
      "(module (memory 1) (func (export \"f\") " +
      signature +
      " i32.const 1 local.set 0 block i32.const 0 i32.load local.tee 0 drop end local.get 0))",
      "ssa-nomerge",
    )
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    let target = match body.last() {
      Some(@lib.LocalGet(target)) => target
      _ => abort("expected final scratch read")
    }
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        match instr {
          @lib.LocalSet(local) | @lib.LocalTee(local) => local == target
          _ => false
        }
      }),
      2,
    )
  }
}

///|
test "command ssa-nomerge keeps loads visible to legacy catches" {
  for
    (source, expected) in [
      (
        "(module (memory 1) (tag $t) (func (result i32) (local $x i32) (local.set $x (i32.load (i32.const 0))) (try (result i32) (do (throw $t)) (catch_all (local.get $x)))))",
        1,
      ),
      (
        "(module (memory 1) (tag $t) (func (result i32) (local $x i32) (local $i i32) (local $sum i32) (local.set $x (i32.const 1)) (loop $l (try (do (throw $t)) (catch_all (local.set $sum (i32.add (local.get $sum) (local.get $x))))) (drop (local.tee $x (i32.load (i32.const 0)))) (local.set $i (i32.add (local.get $i) (i32.const 1))) (br_if $l (i32.lt_u (local.get $i) (i32.const 2)))) (local.get $sum)))",
        2,
      ),
    ] {
    let output = cmd_deep_audit_run(source, "ssa-nomerge")
    @validate.validate_module(output).unwrap()
    let body = cmd_deep_audit_body(output)
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) {
        match instr {
          @lib.LocalSet(local) | @lib.LocalTee(local) =>
            local == @lib.LocalIdx::new(0U)
          _ => false
        }
      }),
      expected,
    )
  }
}

///|
test "command ssa-nomerge keeps both-arm parameter writes visible at the continuation" {
  for wrapped in [false, true] {
    for branch in [false, true] {
      let open = if wrapped { "(block (result i32) " } else { "" }
      let close = if wrapped { ")" } else { "" }
      let exit = if branch { "(br_if $if (local.get $p))" } else { "" }
      let output = cmd_deep_audit_run(
        "(module (memory 1) (func (param $p i32) (param $x i32) (result i32) (local.set $x (i32.const 1)) " +
        open +
        "(if $if (local.get $p) (then (drop (local.tee $x (i32.load (i32.const 0)))) " +
        exit +
        " (drop (local.tee $x (i32.load (i32.const 4))))) (else (drop (local.tee $x (i32.load (i32.const 8)))))) (local.get $x)" +
        close +
        "))",
        "ssa-nomerge",
      )
      @validate.validate_module(output).unwrap()
      assert_eq(
        cmd_deep_audit_count(cmd_deep_audit_body(output), fn(instr) {
          instr is @lib.LocalTee(@lib.LocalIdx(1U))
        }),
        if branch {
          3
        } else {
          2
        },
      )
    }
  }
}
