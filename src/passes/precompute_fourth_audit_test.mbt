///|
test "fourth audit precompute quiets f32 nearest snan" {
  let output = audit_run(
    "(module (func (result i32) f32.const nan:0x1 f32.nearest i32.reinterpret_f32))",
    "precompute",
  )
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute quiets f32 nearest -snan" {
  let output = audit_run(
    "(module (func (result i32) f32.const -nan:0x1 f32.nearest i32.reinterpret_f32))",
    "precompute",
  )
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute quiets f64 nearest snan" {
  let output = audit_run(
    "(module (func (result i64) f64.const nan:0x1 f64.nearest i64.reinterpret_f64))",
    "precompute",
  )
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute quiets f64 nearest -snan" {
  let output = audit_run(
    "(module (func (result i64) f64.const -nan:0x1 f64.nearest i64.reinterpret_f64))",
    "precompute",
  )
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute-propagate quiets f32 nearest snan" {
  let output = audit_run(
    "(module (func (result i32) f32.const nan:0x1 f32.nearest i32.reinterpret_f32))",
    "precompute-propagate",
  )
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute-propagate quiets f32 nearest -snan" {
  let output = audit_run(
    "(module (func (result i32) f32.const -nan:0x1 f32.nearest i32.reinterpret_f32))",
    "precompute-propagate",
  )
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute-propagate quiets f64 nearest snan" {
  let output = audit_run(
    "(module (func (result i64) f64.const nan:0x1 f64.nearest i64.reinterpret_f64))",
    "precompute-propagate",
  )
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute-propagate quiets f64 nearest -snan" {
  let output = audit_run(
    "(module (func (result i64) f64.const -nan:0x1 f64.nearest i64.reinterpret_f64))",
    "precompute-propagate",
  )
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute direct f32 signaling nan False" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(
            @lib.F32(Float::reinterpret_from_uint(0x7f800001U)),
          ),
          @lib.Instruction::f32_nearest(),
          @lib.Instruction::i32_reinterpret_f32(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute-propagate direct f32 signaling nan False" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(
            @lib.F32(Float::reinterpret_from_uint(0x7f800001U)),
          ),
          @lib.Instruction::f32_nearest(),
          @lib.Instruction::i32_reinterpret_f32(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute direct f32 signaling nan True" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(
            @lib.F32(Float::reinterpret_from_uint(0xff800001U)),
          ),
          @lib.Instruction::f32_nearest(),
          @lib.Instruction::i32_reinterpret_f32(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute-propagate direct f32 signaling nan True" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(
            @lib.F32(Float::reinterpret_from_uint(0xff800001U)),
          ),
          @lib.Instruction::f32_nearest(),
          @lib.Instruction::i32_reinterpret_f32(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  let bits = match audit_body(output) {
    [@lib.I32Const(@lib.I32(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x00400000) != 0)
}

///|
test "fourth audit precompute direct f64 signaling nan False" {
  let input = pass_test_module_from_wat(
    "(module (func (result i64) i64.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f64_const(
            @lib.F64(0x7ff0000000000001UL.reinterpret_as_double()),
          ),
          @lib.Instruction::f64_nearest(),
          @lib.Instruction::i64_reinterpret_f64(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute-propagate direct f64 signaling nan False" {
  let input = pass_test_module_from_wat(
    "(module (func (result i64) i64.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f64_const(
            @lib.F64(0x7ff0000000000001UL.reinterpret_as_double()),
          ),
          @lib.Instruction::f64_nearest(),
          @lib.Instruction::i64_reinterpret_f64(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute direct f64 signaling nan True" {
  let input = pass_test_module_from_wat(
    "(module (func (result i64) i64.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f64_const(
            @lib.F64(0xfff0000000000001UL.reinterpret_as_double()),
          ),
          @lib.Instruction::f64_nearest(),
          @lib.Instruction::i64_reinterpret_f64(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute")
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}

///|
test "fourth audit precompute-propagate direct f64 signaling nan True" {
  let input = pass_test_module_from_wat(
    "(module (func (result i64) i64.const 0))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f64_const(
            @lib.F64(0xfff0000000000001UL.reinterpret_as_double()),
          ),
          @lib.Instruction::f64_nearest(),
          @lib.Instruction::i64_reinterpret_f64(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "precompute-propagate")
  let bits = match audit_body(output) {
    [@lib.I64Const(@lib.I64(bits))] => bits
    _ => fail("expected folded integer bits")
  }
  assert_true((bits & 0x0008000000000000L) != 0L)
}
