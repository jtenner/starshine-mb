///|
test "audit heap2local retains nullable allocation dominance trap" {
  let wat =
    #|(module (type $s (struct (field i32)))
    #|(func (param i32) (result i32) (local $r (ref null $s))
    #| local.get 0 if i32.const 7 struct.new $s local.set $r end
    #| local.get $r struct.get $s 0))
  let output = audit_run(wat, "heap2local")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.StructGet(_, _) ||
      i is @lib.RefAsNonNull ||
      i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "audit heap2local preserves signed packed struct reads" {
  let wat =
    #|(module (type $s (struct (field (mut i8))))
    #|(func (result i32) (local $r (ref null $s))
    #| i32.const 255 struct.new $s local.set $r
    #| local.get $r struct.get_s $s 0))
  let output = audit_run(wat, "heap2local")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.StructGetS(_, _) ||
      i is @lib.I32Extend8S ||
      i == @lib.Instruction::i32_const(@lib.I32::new(-1))
    }) >
    0,
    msg="expected packed sign extension: \{audit_body(output)}",
  )
}

///|
test "audit heap2local retains nullable array allocation dominance trap" {
  let input = pass_test_module_from_wat(
    "(module (type $a (array i32)) (func (param i32) (result i32) (local $r (ref null $a)) i32.const 0))",
  )
  let type_ = @lib.TypeIdx::new(0U)
  let original = input.code_sec.unwrap().0[0]
  let @lib.Func(locals, _) = original
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(7),
              @lib.Instruction::i32_const(1),
              @lib.Instruction::array_new(type_),
              @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            ],
            None,
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(0),
          @lib.Instruction::array_get(type_),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "heap2local")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.ArrayGet(_) || i is @lib.RefAsNonNull || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "audit heap2local retains read before same block allocation" {
  let output = audit_run(
    "(module (type $s (struct (field i32))) (func (local $r (ref null $s)) local.get $r struct.get $s 0 drop i32.const 7 struct.new $s local.set $r))",
    "heap2local",
  )
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.StructGet(_, _) ||
      i is @lib.RefAsNonNull ||
      i is @lib.Unreachable
    }) >
    0,
  )
}
