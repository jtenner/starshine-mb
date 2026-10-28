///|
test "R1-01 command retains indirect returned callbacks in closed world" {
  for
    route in [
      "(global $saved (ref $cb) (ref.func $answer)) (func (export \"get\") (result (ref $cb)) global.get $saved)",
      "(func $helper (result (ref $cb)) ref.func $answer) (func (export \"get\") (result (ref $cb)) call $helper)",
      "(global $saved (ref $cb) (ref.func $answer)) (func $a (result (ref $cb)) call $b) (func $b (result (ref $cb)) i32.const 0 if (result (ref $cb)) call $a else global.get $saved end) (func (export \"get\") (result (ref $cb)) call $a)",
      "(func $helper (result (ref $cb)) ref.func $answer) (func (export \"get\") (result (ref $cb)) return_call $helper)",
      "(global $saved (ref $cb) (ref.func $answer)) (global $alias (ref $cb) (global.get $saved)) (func (export \"get\") (result (ref $cb)) global.get $alias)",
    ] {
    let input = @passes.pass_test_module_from_wat(
      "(module (type $cb (func (result i32))) (func $answer (type $cb) i32.const 42) (elem declare func $answer) \{route} (func (result i32) i32.const 99))",
    )
    @validate.validate_module(input).unwrap()
    let output = optimize_module_with_pass_flags(
      input,
      ["remove-unused-module-elements"],
      OptimizeOptions::new(closed_world=true),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(
      output.code_sec.unwrap().0.length(),
      input.code_sec.unwrap().0.length() - 1,
    )
    @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(42))])
  }
}
