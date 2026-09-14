///|
test "fourth audit i31 high bit 0 -2147483648" {
  let output = audit_run(
    "(module (func (result i32) i32.const 0 ref.i31 i32.const -2147483648 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 high bit 2147483647 -1" {
  let output = audit_run(
    "(module (func (result i32) i32.const 2147483647 ref.i31 i32.const -1 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 high bit 17 -2147483631" {
  let output = audit_run(
    "(module (func (result i32) i32.const 17 ref.i31 i32.const -2147483631 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 high bit -2147483648 0" {
  let output = audit_run(
    "(module (func (result i32) i32.const -2147483648 ref.i31 i32.const 0 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 high bit -1 2147483647" {
  let output = audit_run(
    "(module (func (result i32) i32.const -1 ref.i31 i32.const 2147483647 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 1 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 1 ref.i31 i32.const -2147483647 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 1 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -2147483647 ref.i31 i32.const 1 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 2 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 2 ref.i31 i32.const -2147483646 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 2 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -2147483646 ref.i31 i32.const 2 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 255 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 255 ref.i31 i32.const -2147483393 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 255 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -2147483393 ref.i31 i32.const 255 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 65535 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 65535 ref.i31 i32.const -2147418113 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 65535 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -2147418113 ref.i31 i32.const 65535 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 1073741823 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 1073741823 ref.i31 i32.const -1073741825 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 1073741823 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -1073741825 ref.i31 i32.const 1073741823 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 1073741824 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 1073741824 ref.i31 i32.const -1073741824 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 1073741824 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -1073741824 ref.i31 i32.const 1073741824 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 2147483646 reverse False" {
  let output = audit_run(
    "(module (func (result i32) i32.const 2147483646 ref.i31 i32.const -2 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "fourth audit i31 payload 2147483646 reverse True" {
  let output = audit_run(
    "(module (func (result i32) i32.const -2 ref.i31 i32.const 2147483646 ref.i31 ref.eq))",
    "optimize-instructions",
  )
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}
