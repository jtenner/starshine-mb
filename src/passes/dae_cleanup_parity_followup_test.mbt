///|
test "parity followup dae optimizing removes dead touched caller local chains" {
  let output = audit_run(
    (
      #|(module
      #| (func $callee (param i32 i32) (result i32)
      #|  local.get 1 i32.const 0 i32.add)
      #| (func (export "run") (result i32) (local i32 i32)
      #|  i32.const 223 local.set 0 local.get 0 local.set 1 local.get 1 drop
      #|  i32.const 101 i32.const 7 call $callee)
      #| (func (result i32) i32.const 102 i32.const 8 call $callee))
    ),
    "dae-optimizing",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[1]
  assert_eq(locals.length(), 0)
  assert_eq(audit_body(output, index=1), [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
}

///|
test "parity followup dae optimizing drops unused effect results without scratch locals" {
  let output = audit_run(
    (
      #|(module (memory 1) (global $g (mut i32) (i32.const 0))
      #| (func $callee (param i32 i32) (result i32) local.get 1)
      #| (func (export "run") (result i32)
      #|  i32.const 3 i32.const 7 call $callee)
      #| (func (result i32) (local i32)
      #|  i32.const 0 memory.grow local.set 0
      #|  i32.const 100 global.set $g local.get 0 i32.const 8 call $callee)
      #| (func (result i32) (local i32)
      #|  i32.const 0 i32.load local.set 0
      #|  i32.const 101 global.set $g local.get 0 i32.const 9 call $callee))
    ),
    "dae-optimizing",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  for index in [2, 3] {
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[index]
    assert_eq(locals.length(), 0, msg="discarded producer in function \{index}")
    let body = audit_body(output, index~)
    // The discarded operation must still execute before the global write.
    assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(0)))
    if index == 2 {
      assert_eq(body[1], @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)))
    } else {
      assert_true(body[1] is @lib.I32Load(_))
    }
    assert_eq(body[2], @lib.Instruction::drop())
    assert_eq(body[3], @lib.Instruction::i32_const(@lib.I32(98 + index)))
    assert_eq(body[4], @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
    assert_eq(body[5], @lib.Instruction::i32_const(@lib.I32(6 + index)))
    assert_eq(body[6], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
    assert_eq(body.length(), 7)
  }
}
