///|
test "campaign optimize instructions preserves eager scalar traps" {
  let expressions = [
    "(i32.lt_u (i32.div_u (local.get 0) (i32.const 0)) (i32.const 0))", "(i32.mul (i32.div_s (local.get 0) (local.get 1)) (i32.const 0))",
    "(i32.rem_u (i32.div_u (local.get 0) (local.get 1)) (i32.const 1))", "(i32.lt_s (i32.div_s (local.get 0) (local.get 1)) (i32.const -2147483648))",
    "(select (i32.const 7) (i32.div_u (local.get 0) (local.get 1)) (i32.const 1))",
  ]
  for expression in expressions {
    let output = audit_run(
      "(module (func (param i32 i32) (result i32) \{expression}))",
      "optimize-instructions",
    )
    assert_true(
      audit_count(audit_body(output), fn(i) {
        i is @lib.I32DivU || i is @lib.I32DivS || i is @lib.Unreachable
      }) >
      0,
      msg=expression,
    )
  }
}

///|
test "campaign optimize instructions preserves trapping float conversion" {
  let output = audit_run(
    (
      #|(module (func (param f64) (result i32)
      #| (i32.lt_u (i32.trunc_f64_s (local.get 0)) (i32.const 0))))
    ),
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32TruncF64S || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.div_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.const 0) (i32.div_s (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.and (i32.div_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.or (i32.div_s (local.get 0) (local.get 1)) (i32.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.rem_u (i32.div_s (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.lt_u (i32.div_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.ge_u (i32.div_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_s select retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (select (i32.const 7) (i32.div_s (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.div_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.const 0) (i32.div_u (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.and (i32.div_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.or (i32.div_u (local.get 0) (local.get 1)) (i32.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.rem_u (i32.div_u (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.lt_u (i32.div_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.ge_u (i32.div_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 div_u select retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (select (i32.const 7) (i32.div_u (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.rem_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.const 0) (i32.rem_s (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.and (i32.rem_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.or (i32.rem_s (local.get 0) (local.get 1)) (i32.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.rem_u (i32.rem_s (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.lt_u (i32.rem_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.ge_u (i32.rem_s (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_s select retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (select (i32.const 7) (i32.rem_s (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.rem_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.mul (i32.const 0) (i32.rem_u (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.and (i32.rem_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.or (i32.rem_u (local.get 0) (local.get 1)) (i32.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.rem_u (i32.rem_u (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.lt_u (i32.rem_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (i32.ge_u (i32.rem_u (local.get 0) (local.get 1)) (i32.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i32 rem_u select retains trap" {
  let output = audit_run(
    "(module (func (param i32 i32) (result i32) (select (i32.const 7) (i32.rem_u (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I32RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.div_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.const 0) (i64.div_s (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.and (i64.div_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.or (i64.div_s (local.get 0) (local.get 1)) (i64.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.rem_u (i64.div_s (local.get 0) (local.get 1)) (i64.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.lt_u (i64.div_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.ge_u (i64.div_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_s select retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (select (i64.const 7) (i64.div_s (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.div_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.const 0) (i64.div_u (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.and (i64.div_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.or (i64.div_u (local.get 0) (local.get 1)) (i64.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.rem_u (i64.div_u (local.get 0) (local.get 1)) (i64.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.lt_u (i64.div_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.ge_u (i64.div_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 div_u select retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (select (i64.const 7) (i64.div_u (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64DivU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.rem_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.const 0) (i64.rem_s (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.and (i64.rem_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.or (i64.rem_s (local.get 0) (local.get 1)) (i64.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.rem_u (i64.rem_s (local.get 0) (local.get 1)) (i64.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.lt_u (i64.rem_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.ge_u (i64.rem_s (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_s select retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (select (i64.const 7) (i64.rem_s (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemS || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u mul_right retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.rem_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u mul_left retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.mul (i64.const 0) (i64.rem_u (local.get 0) (local.get 1)))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u and_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.and (i64.rem_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u or_ones retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.or (i64.rem_u (local.get 0) (local.get 1)) (i64.const -1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u rem_one retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (i64.rem_u (i64.rem_u (local.get 0) (local.get 1)) (i64.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u lt_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.lt_u (i64.rem_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u ge_zero retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i32) (i64.ge_u (i64.rem_u (local.get 0) (local.get 1)) (i64.const 0))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "campaign scalar i64 rem_u select retains trap" {
  let output = audit_run(
    "(module (func (param i64 i64) (result i64) (select (i64.const 7) (i64.rem_u (local.get 0) (local.get 1)) (i32.const 1))))",
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.I64RemU || i is @lib.Unreachable
    }) >
    0,
  )
}
