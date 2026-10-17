///|
fn cl_flat_hazard_perf_fixture(
  label : String,
) -> (
  Array[@lib.Instruction],
  Array[CLAction],
  Array[Bool],
  Array[@lib.ValType],
) {
  let count = if label == "tiny" {
    4
  } else if label == "multiwrites" {
    16
  } else {
    64
  }
  let rounds = if label == "multiwrites" { 8 } else { 1 }
  let types = Array::makei(count, fn(index) {
    if label == "mixed" && index % 2 == 1 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let body : Array[@lib.Instruction] = []
  if label == "read-before-write" {
    for local in 0..<count {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
  }
  for _ in 0..<rounds {
    for local in 0..<count {
      body.push(
        if types[local] == @lib.ValType::i64() {
          @lib.Instruction::i64_const(@lib.I64(local.to_int64()))
        } else {
          @lib.Instruction::i32_const(@lib.I32(local))
        },
      )
      body.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())),
      )
    }
    for local in 0..<count {
      if label != "read-before-write" && (label != "sparse" || local % 16 == 0) {
        body.push(
          @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
        )
        body.push(@lib.Instruction::drop())
      }
    }
  }
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, count)
  (body, actions, Array::make(actions.length(), true), types)
}

///|
fn cl_flat_hazard_clock(label : String, old : Bool) -> Unit raise {
  let (body, actions, effective, types) = cl_flat_hazard_perf_fixture(label)
  let count = types.length()
  let input = cl_flat_hazard_module(body, count, 0).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(types), @lib.Expr::new(body)),
    ]),
  )
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let reference = cl_linear_hazard_reference_rewrite(func, [])
  let actual_rewrite = cl_rewrite_func(func, [])
  assert_eq(actual_rewrite.func, reference.func)
  assert_eq(actual_rewrite.changed, reference.changed)
  let expected_output = input.with_code_sec(@lib.CodeSec::new([reference.func]))
  let actual_output = input.with_code_sec(
    @lib.CodeSec::new([actual_rewrite.func]),
  )
  @validate.validate_module(actual_output).unwrap()
  @validate.validate_module(expected_output).unwrap()
  assert_eq(
    @binary.encode_module(actual_output).unwrap(),
    @binary.encode_module(expected_output).unwrap(),
  )
  let public_actual = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  let public_reference = cl_linear_hazard_reference_module(input)
  @validate.validate_module(public_actual).unwrap()
  @validate.validate_module(public_reference).unwrap()
  assert_eq(
    public_actual.code_sec.unwrap().0,
    public_reference.code_sec.unwrap().0,
  )
  assert_eq(
    @binary.encode_module(public_actual).unwrap(),
    @binary.encode_module(public_reference).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), before)
  let expected = CLBitMatrix::new(count)
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, 0, expected,
  )
  let batch = if label == "tiny" {
    256
  } else if label == "multiwrites" {
    8
  } else {
    32
  }
  for sample in 0..<54 {
    // Fixed output matrices are common to both paths and allocated outside
    // clocks. Every result is checked after the clock, so all calls are used.
    let matrices = Array::makei(batch, fn(_) { CLBitMatrix::new(count) })
    let started = @bench.monotonic_clock_start()
    for matrix in matrices {
      if old {
        cl_add_source_write_dest_read_interferences(
          body, actions, effective, types, 0, matrix,
        )
      } else {
        cl_add_linear_source_write_dest_read_interferences(
          body, actions, effective, types, 0, matrix,
        )
      }
    }
    let elapsed_us = @bench.monotonic_clock_end(started)
    let warmup = sample < 3
    println(
      "@CL_FLAT_SAMPLE {\"case\":\"\{label}\",\"old\":\{old},\"batch\":\{batch},\"sample\":\{sample},\"warmup\":\{warmup},\"elapsed_us\":\{elapsed_us}}",
    )
    for matrix in matrices {
      for source in 0..<count {
        for dest in 0..<count {
          assert_eq(
            cl_bit_matrix_get(matrix, source, dest),
            cl_bit_matrix_get(expected, source, dest),
          )
        }
      }
    }
    assert_eq(@binary.encode_module(input).unwrap(), before)
    println("@CL_FLAT_VERIFIED \{sample}")
  }
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard tiny old" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("tiny", true)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard tiny epochs" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("tiny", false)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard multiwrites old" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("multiwrites", true)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard multiwrites epochs" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("multiwrites", false)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard dense old" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("dense", true)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard dense epochs" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("dense", false)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard sparse old" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("sparse", true)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard sparse epochs" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("sparse", false)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard mixed old" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("mixed", true)
}

///|
#skip("Dedicated native straight-line hazard footprint control; unrun")
test "coalesce flat hazard mixed epochs" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("mixed", false)
}

///|
#skip("Dedicated native straight-line hazard negative control; unrun")
test "coalesce flat hazard read-before-write old" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("read-before-write", true)
}

///|
#skip("Dedicated native straight-line hazard negative control; unrun")
test "coalesce flat hazard read-before-write epochs" (driver : @bench.T) {
  ignore(driver)
  cl_flat_hazard_clock("read-before-write", false)
}
