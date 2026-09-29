///|
test "command DAE variants prune parameters across wrapped-trap suffixes" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $target (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 7 local.get 0 call $target) (func (export \"trap\") (param i32) (result i32) i32.const 7 local.get 0 call $target drop block block unreachable end end i32.const 8 local.get 0 call $target))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(cmd_deep_audit_body(output, index=0), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
  }
}
