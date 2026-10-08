///|
test "P00 valid rethrow depths survive control cleanup in both DAE2 modes" {
  let fixtures : Array[String] = [
    "(module (tag $t) (tag $u) (func (try (do (try (do (throw $t)) (catch $t (block (rethrow 1))) (catch $u))) (catch_all))))",
    "(module (tag $t (param i32)) (func (export \"f\") (param $x i32) (result i32) (try (result i32) (do (throw $t (local.get $x))) (catch $t (drop) (try (result i32) (do (rethrow 1)) (catch_all (i32.const 1000)))) (catch_all (i32.const 1)))))",
    "(module (tag $t) (func (param $x i32) (try (do (throw $t)) (catch_all (if (local.get $x) (then (rethrow 1)))))))",
    "(module (tag $t) (func (try (do (throw $t)) (catch_all (if (i32.const 1) (then (rethrow 1)))))))",
    "(module (tag $t) (func (try (do (throw $t)) (catch_all i32.const 1 (loop (param i32) drop (rethrow 1))))))",
    "(module (tag $a) (tag $b) (func (try (do (throw $a)) (catch_all (try (do (throw $b)) (catch_all (block (if (i32.const 1) (then (rethrow 3))))))))))",
  ]
  assert_eq(fixtures.length(), 6)
  for source in fixtures {
    for pass_name in ["vacuum", "dae2", "dae2-optimizing"] {
      let output = cmd_deep_audit_run(source, pass_name)
      @validate.validate_module(output).unwrap()
      @validate.validate_module(
        @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
      ).unwrap()
    }
  }
}
