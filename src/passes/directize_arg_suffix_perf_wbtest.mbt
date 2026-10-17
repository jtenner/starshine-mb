///|
fn directize_arg_suffix_measure(
  out : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  info : DirectizeInfo,
  reference : Bool,
  expected : Int32?,
) -> UInt64 {
  let start = @lib.trace_now_us()
  for _ in 0..<32 {
    let actual = if reference {
      directize_arg_suffix_reference(out, params, info)
    } else {
      directize_find_removable_arg_suffix(out, params, info)
    }
    if actual != expected {
      abort("unexpected suffix benchmark result")
    }
  }
  @lib.trace_elapsed_us_since(start)
}

///|
#skip("manual native-release Directize suffix benchmark with exhaustive-search control")
test "directize exact-arity suffix benchmark retains equivalent outcomes" {
  let info = directize_arg_suffix_info()
  for width in [32, 128, 256] {
    for mismatch in [false, true] {
      let out = Array::make(
        width + 16,
        @lib.Instruction::i32_const(@lib.I32(1)),
      )
      out.push(@lib.Instruction::i32_const(@lib.I32(0)))
      let params = Array::make(width, @lib.ValType::i32())
      if mismatch {
        params[width - 1] = @lib.ValType::i64()
      }
      let expected = if mismatch { None } else { Some(16) }
      let original = out.copy()
      for reference in [true, false] {
        ignore(
          directize_arg_suffix_measure(out, params, info, reference, expected),
        )
      }
      let reference_samples : Array[UInt64] = []
      let candidate_samples : Array[UInt64] = []
      // Alternate measurement order to reduce warmup and order bias.
      for sample in 0..<7 {
        for
          reference in (if sample % 2 == 0 {
            [true, false]
          } else {
            [false, true]
          }) {
          let elapsed = directize_arg_suffix_measure(
            out, params, info, reference, expected,
          )
          if reference {
            reference_samples.push(elapsed)
          } else {
            candidate_samples.push(elapsed)
          }
        }
      }
      assert_eq(out, original)
      println(
        "directize suffix width=\{width} mismatch=\{mismatch} repetitions=32 reference_us=\{reference_samples} candidate_us=\{candidate_samples}",
      )
    }
  }
}
