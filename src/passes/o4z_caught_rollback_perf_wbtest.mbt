///|
fn o4z_caught_rollback_measure(
  input : @lib.Module,
  options : HotPipelineOptions,
  preset : Bool,
  expected : Bytes,
) -> UInt64 {
  let start = @lib.trace_now_us()
  let result = run_hot_pipeline(
    input,
    options,
    if preset {
      ["optimize"]
    } else {
      []
    },
  ).unwrap()
  let elapsed = @lib.trace_elapsed_us_since(start)
  if @binary.encode_module(result).unwrap() != expected {
    abort("rollback benchmark must return the prepared module")
  }
  elapsed
}

///|
#skip("manual native-release O4z caught rollback versus preparation-only control")
test "O4z caught rollback benchmark retains preparation validation and ownership" {
  let source = StringBuilder()
  source.write_string(
    "(module (tag $e) (func $producer (result i32) i32.const 7) ",
  )
  for index in 0..<32 {
    source.write_string(
      "(func (export \"run\{index}\") (result i32) call $producer i32.const 7 i32.eq) ",
    )
  }
  source.write_string(
    "(func (block $handler (try_table (catch_all $handler) (throw $e)))))",
  )
  let base = pass_test_module_from_wat(source.to_string())
  for trusted in [false, true] {
    let input = if trusted {
      o4z_caught_rollback_value_fact(base)
    } else {
      base
    }
    let original = @binary.encode_module(input).unwrap()
    let policy = if trusted {
      CompilerFactUsePolicy::trust_assertions()
    } else {
      CompilerFactUsePolicy::ignore()
    }
    let expected = @binary.encode_module(
      apply_compiler_facts(input, policy).unwrap().module_,
    ).unwrap()
    let options = HotPipelineOptions::new(
      optimize_level=4,
      shrink_level=4,
      compiler_fact_policy=policy,
    )
    for preset in [true, false] {
      ignore(o4z_caught_rollback_measure(input, options, preset, expected))
    }
    let preset_samples : Array[UInt64] = []
    let control_samples : Array[UInt64] = []
    for sample in 0..<7 {
      for
        preset in (if sample % 2 == 0 { [true, false] } else { [false, true] }) {
        let elapsed = o4z_caught_rollback_measure(
          input, options, preset, expected,
        )
        if preset {
          preset_samples.push(elapsed)
        } else {
          control_samples.push(elapsed)
        }
      }
    }
    assert_eq(@binary.encode_module(input).unwrap(), original)
    println(
      "O4z caught rollback functions=34 trusted=\{trusted} preset_us=\{preset_samples} preparation_only_us=\{control_samples}",
    )
  }
}
