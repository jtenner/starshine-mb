///|
test "encoded size pairs match full encoding at body and section length boundaries" {
  for count in [0, 1, 8, 127, 128] {
    for width in [0, 120, 127, 128, 16370] {
      if (count > 8 && width > 128) || (count > 1 && width == 16370) {
        continue
      }
      let before = encoded_size_fixture(count, width)
      let funcs = before.code_sec.unwrap().0.copy()
      if funcs.length() > 0 {
        funcs[0] = @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        )
      }
      let after = before.with_code_sec(@lib.CodeSec::new(funcs))
      assert_eq(
        @binary.encoded_module_sizes(before, after).unwrap(),
        (
          @binary.encode_module(before).unwrap().length(),
          @binary.encode_module(after).unwrap().length(),
        ),
      )
    }
  }
}

///|
fn encoded_size_fixture(count : Int, width : Int) -> @lib.Module {
  let input = pass_test_module_from_wat("(module (func))")
  let func = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new(Array::make(width, @lib.Instruction::nop())),
  )
  input
  .with_func_sec(@lib.FuncSec::new(Array::make(count, @lib.TypeIdx::new(0U))))
  .with_code_sec(@lib.CodeSec::new(Array::make(count, func)))
}

///|
test "encoded size pairs invalidate shared functions after string pool changes" {
  let before = pass_test_module_from_wat(
    (
      #|(module
      #| (func (drop (string.const "original")))
      #| (func (drop (string.const "shared"))))
    ),
  )
  let replacement = pass_test_module_from_wat(
      (
        #|(module (func (drop (string.const "new"))))
      ),
    ).code_sec.unwrap().0[0]
  let funcs = before.code_sec.unwrap().0.copy()
  funcs[0] = replacement
  let after = before.with_code_sec(@lib.CodeSec::new(funcs))
  assert_eq(
    @binary.encoded_module_sizes(before, after).unwrap(),
    (
      @binary.encode_module(before).unwrap().length(),
      @binary.encode_module(after).unwrap().length(),
    ),
  )
}

///|
test "encoded size pairs preserve compiler facts and name section accounting" {
  let before = pass_test_module_from_wat(
    (
      #|(module $named (func $worker (param $x i32) (local $tmp i64) nop))
    ),
  )
  let before = before.with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("named"))),
  )
  let before = before.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
    ),
  )
  let after = before.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))]),
  )
  assert_eq(
    @binary.encoded_module_sizes(before, after).unwrap(),
    (
      @binary.encode_module(before).unwrap().length(),
      @binary.encode_module(after).unwrap().length(),
    ),
  )
}

///|
test "encoded size reuse respects string index LEB growth at 128" {
  let source = StringBuilder::new()
  source.write_string("(module (func")
  for index in 0..<127 {
    source.write_string(" (drop (string.const \"s\{index}\"))")
  }
  source.write_string(") (func (drop (string.const \"shared\"))))")
  let before = pass_test_module_from_wat(source.to_string())
  let funcs = before.code_sec.unwrap().0.copy()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
  let body = body.copy()
  body.push(@lib.Instruction::string_const(b"inserted"))
  body.push(@lib.Instruction::drop())
  funcs[0] = @lib.Func::new(locals, @lib.Expr::new(body))
  let after = before.with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(
    physical_equal(before.code_sec.unwrap().0[1], after.code_sec.unwrap().0[1]),
  )
  assert_eq(
    @binary.encoded_module_sizes(before, after).unwrap(),
    (
      @binary.encode_module(before).unwrap().length(),
      @binary.encode_module(after).unwrap().length(),
    ),
  )
}

///|
test "encoded size pairs reject intentionally invalid reserved custom names" {
  let good = encoded_size_fixture(1, 1)
  let invalid = good.with_custom_secs([
    @lib.CustomSec::new(@lib.Name::from_string("name"), b""),
  ])
  assert_true(@binary.encode_module(invalid) is Err(_))
  assert_true(@binary.encoded_module_sizes(invalid, good) is Err(_))
  assert_true(@binary.encoded_module_sizes(good, invalid) is Err(_))
}
