///|
test "command DAE modes reuse existing signatures after unread parameter batches" {
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(
      (
        #|(module
        #|  (type $empty (func (result i32)))
        #|  (type $arg (func (param i32) (result i32)))
        #|  (import "m" "value" (func $value (type $empty)))
        #|  (func $a (type $arg) call $value)
        #|  (func $b (type $arg) call $value i32.const 1 i32.add)
        #|  (func (export "run") (param i32) (result i32)
        #|    local.get 0 call $a local.get 0 call $b i32.add))
      ),
      pass,
    )
    @validate.validate_module(output).unwrap()
    let env = @validate.Env::new().with_module(output)
    for index in [1U, 2U] {
      assert_eq(
        env.get_functype_by_funcidx(@lib.FuncIdx::new(index)),
        Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
      )
    }
    let @lib.FuncSec(indices) = output.func_sec.unwrap()
    assert_eq(indices[0], indices[1])
  }
}
