///|
test "deep audit once reduction preserves call skipped by br_on_cast_desc_eq" {
  let output = audit_run(
    (
      #|(module (rec (type $s (sub (descriptor $d) (struct)))
      #| (type $d (sub (describes $s) (struct))))
      #| (global $desc (ref (exact $d)) (struct.new $d))
      #| (global $obj (ref $s) (struct.new_default_desc $s (global.get $desc)))
      #| (global $flag (mut i32) (i32.const 0))
      #| (global $hits (mut i32) (i32.const 0))
      #| (func $once global.get $flag if return end i32.const 1 global.set $flag
      #| (global.set $hits (i32.add (global.get $hits) (i32.const 1))))
      #| (func (export "run") (result i32)
      #| (drop (block $exit (result (ref null $s))
      #| (br_on_cast_desc_eq $exit (ref null $s) (ref $s) (global.get $obj) (global.get $desc))
      #| (call $once))) (call $once) (global.get $hits)))
    ),
    "once-reduction",
  )
  @debug.assert_eq(
    audit_count(audit_body(output, index=1), fn(i) { i is @lib.Call(_) }),
    2,
  )
}

///|
test "deep audit once reduction preserves call skipped by br_on_cast_desc_eq_fail" {
  let output = audit_run(
    (
      #|(module (rec (type $s (sub (descriptor $d) (struct)))
      #| (type $d (sub (describes $s) (struct))))
      #| (global $desc (ref (exact $d)) (struct.new $d))
      #| (global $obj (ref $s) (struct.new_default_desc $s (global.get $desc)))
      #| (global $flag (mut i32) (i32.const 0))
      #| (global $hits (mut i32) (i32.const 0))
      #| (func $once global.get $flag if return end i32.const 1 global.set $flag
      #| (global.set $hits (i32.add (global.get $hits) (i32.const 1))))
      #| (func (export "run") (result i32)
      #| (drop (block $exit (result (ref null $s))
      #| (br_on_cast_desc_eq_fail $exit (ref null $s) (ref $s) (ref.null $s) (global.get $desc))
      #| (call $once))) (call $once) (global.get $hits)))
    ),
    "once-reduction",
  )
  @debug.assert_eq(
    audit_count(audit_body(output, index=1), fn(i) { i is @lib.Call(_) }),
    2,
  )
}

///|
test "deep audit once reduction preserves call skipped by resume handler" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (type $cont (func (param i64))) (type $tag (func (result i32))) (tag (type $tag)) (global $flag (mut i32) (i32.const 0)) (global $hits (mut i32) (i32.const 0)) (func $once global.get $flag if return end i32.const 1 global.set $flag (global.set $hits (i32.add (global.get $hits) (i32.const 1)))) (func (export \"run\") (param (ref null $cont)) (result i32) unreachable))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
        ),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::resume_(@lib.TypeIdx::new(1U), [
            @lib.ResumeHandler::on_label(
              @lib.TagIdx::new(0U),
              @lib.LabelIdx::new(0U),
            ),
          ]),
          @lib.Instruction::drop(),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
        ]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
    ]),
  )
  let output = audit_run_module(
    input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs)),
    "once-reduction",
  )
  @debug.assert_eq(
    audit_count(audit_body(output, index=1), fn(i) { i is @lib.Call(_) }),
    2,
  )
}
