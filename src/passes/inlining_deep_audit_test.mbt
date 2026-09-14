///|
test "deep audit inlining retains function br before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inlining")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inlining retains function br_if before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inlining")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inlining retains function br_table before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_table(
            [@lib.LabelIdx::new(0U)],
            @lib.LabelIdx::new(0U),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inlining")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inlining-optimizing retains function br before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inlining-optimizing")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inlining-optimizing retains function br_if before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inlining-optimizing")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inlining-optimizing retains function br_table before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_table(
            [@lib.LabelIdx::new(0U)],
            @lib.LabelIdx::new(0U),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inlining-optimizing")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inline-main retains function br before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inline-main")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inline-main retains function br_if before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inline-main")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}

///|
test "deep audit inline-main retains function br_table before unreachable" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) i32.const 7))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_table(
            [@lib.LabelIdx::new(0U)],
            @lib.LabelIdx::new(0U),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "inline-main")
  assert_true(
    audit_count(audit_body(output), fn(i) { i is @lib.I32Const(@lib.I32(7)) }) >
    0,
  )
}
