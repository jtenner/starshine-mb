///|
test "round2 optimize instructions f32 negative zero array fixed False" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array (mut f32))) (func (result (ref $a)) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(@lib.F32::new(-0.0)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::array_new(@lib.TypeIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.ArrayNewDefault(_) }),
    0,
  )
}

///|
test "round2 optimize instructions f32 negative zero array fixed True" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array (mut f32))) (func (result (ref $a)) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(@lib.F32::new(-0.0)),
          @lib.Instruction::f32_const(@lib.F32::new(-0.0)),
          @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(2U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.ArrayNewDefault(_) }),
    0,
  )
}

///|
test "round2 optimize instructions f32 select distinct zero 0" {
  let output = audit_run(
    (
      #|(module (func (export "f") (param i32) (result f32) (f32.const 0) (f32.const -0) local.get 0 select))
    ),
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.Select(_) || i is @lib.If(_, _, _)
    }) >
    0,
  )
}

///|
test "round2 optimize instructions f32 select distinct zero -0" {
  let output = audit_run(
    (
      #|(module (func (export "f") (param i32) (result f32) (f32.const -0) (f32.const 0) local.get 0 select))
    ),
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.Select(_) || i is @lib.If(_, _, _)
    }) >
    0,
  )
}

///|
test "round2 optimize instructions f64 negative zero array fixed False" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array (mut f64))) (func (result (ref $a)) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f64_const(@lib.F64::new(-0.0)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::array_new(@lib.TypeIdx::new(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.ArrayNewDefault(_) }),
    0,
  )
}

///|
test "round2 optimize instructions f64 negative zero array fixed True" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array (mut f64))) (func (result (ref $a)) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f64_const(@lib.F64::new(-0.0)),
          @lib.Instruction::f64_const(@lib.F64::new(-0.0)),
          @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(2U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "optimize-instructions")
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.ArrayNewDefault(_) }),
    0,
  )
}

///|
test "round2 optimize instructions f64 select distinct zero 0" {
  let output = audit_run(
    (
      #|(module (func (export "f") (param i32) (result f64) (f64.const 0) (f64.const -0) local.get 0 select))
    ),
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.Select(_) || i is @lib.If(_, _, _)
    }) >
    0,
  )
}

///|
test "round2 optimize instructions f64 select distinct zero -0" {
  let output = audit_run(
    (
      #|(module (func (export "f") (param i32) (result f64) (f64.const -0) (f64.const 0) local.get 0 select))
    ),
    "optimize-instructions",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.Select(_) || i is @lib.If(_, _, _)
    }) >
    0,
  )
}

///|
test "round2 optimize instructions retains i32 div_u range observer" {
  let output = audit_run(
    (
      #|(module (func (param i32 i32) (result i32) (i32.and (i32.div_u (i32.and (local.get 0) (i32.const 255)) (i32.and (local.get 1) (i32.const 255))) (i32.const 1))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I32And }), 3)
}

///|
test "round2 optimize instructions retains i32 div_s range observer" {
  let output = audit_run(
    (
      #|(module (func (param i32 i32) (result i32) (i32.and (i32.div_s (i32.and (local.get 0) (i32.const 255)) (i32.and (local.get 1) (i32.const 255))) (i32.const 1))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I32And }), 3)
}

///|
test "round2 optimize instructions retains i32 rem_s range observer" {
  let output = audit_run(
    (
      #|(module (func (param i32 i32) (result i32) (i32.and (i32.rem_s (local.get 0) (i32.const 3)) (i32.const 3))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I32And }), 1)
}

///|
test "round2 optimize instructions retains i64 div_u range observer" {
  let output = audit_run(
    (
      #|(module (func (param i64 i64) (result i32) (i64.gt_u (i64.div_u (i64.and (local.get 0) (i64.const 255)) (i64.and (local.get 1) (i64.const 255))) (i64.const 3))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I64GtU }), 1)
}

///|
test "round2 optimize instructions retains i64 div_s range observer" {
  let output = audit_run(
    (
      #|(module (func (param i64 i64) (result i32) (i64.gt_u (i64.div_s (i64.and (local.get 0) (i64.const 255)) (i64.and (local.get 1) (i64.const 255))) (i64.const 3))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I64GtU }), 1)
}

///|
test "round2 optimize instructions retains i64 rem_s range observer" {
  let output = audit_run(
    (
      #|(module (func (param i64 i64) (result i32) (i64.gt_u (i64.rem_s (local.get 0) (i64.const 3)) (i64.const 4))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I64GtU }), 1)
}

///|
test "round2 optimize instructions block range observes prefix branch" {
  let output = audit_run(
    (
      #|(module (func (param i32) (result i32) (local i32)
      #|(i32.and (block $b (result i32)
      #|(local.set 1 (block (result i32) (br_if $b (i32.const 99) (local.get 0)))) (i32.const 0)) (i32.const 1))))
    ),
    "optimize-instructions",
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I32And }), 1)
}
