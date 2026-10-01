///|
test "command DAE2 lazy legacy setup retains GC handler result and sibling declarations" {
  let wat = "(module (type $box (struct (field i32))) (tag $t) (func (export \"keep\") (param i32) (result i32) local.get 0) (func (export \"run\") (result (ref $box)) (try (result (ref $box)) (do (throw $t)) (catch $t (struct.new $box (i32.const 9))))))"
  let input = @wast.wast_to_binary_module(wat).unwrap()
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(wat, pass)
    @validate.validate_module(output).unwrap()
    assert_eq(output.func_sec, input.func_sec)
    assert_eq(output.export_sec, input.export_sec)
  }
}
