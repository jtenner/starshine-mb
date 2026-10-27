///|
fn mp_encoded_cost_fixture(
  zero_count : Int32,
  passive~ : Bool = false,
  name~ : String? = None,
) -> @lib.Module {
  let bytes = Array::make(zero_count + 2, b'\x00')
  bytes[0] = b'\x01'
  bytes[zero_count + 1] = b'\x02'
  let base = if passive {
    pass_test_module_from_wat(
      "(module (memory 1) (data \"\") (func i32.const 0 i32.const 0 i32.const \{zero_count + 2} memory.init 0))",
    )
  } else {
    pass_test_module_from_wat("(module (memory 1) (data (i32.const 0) \"\"))")
  }
  let mode = if passive {
    @lib.DataMode::passive()
  } else {
    @lib.DataMode::active(
      @lib.MemIdx::new(0U),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    )
  }
  let input = base.with_data_sec(
    @lib.DataSec::new([@lib.Data::new(mode, Bytes::from_array(bytes))]),
  )
  match name {
    Some(name) =>
      input.with_name_sec(
        @lib.NameSec::new(
          data_names=Some(
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string(name)),
            ]),
          ),
        ),
      )
    None => input
  }
}

///|
// Build the proposed split independently of the public acceptance decision.
fn mp_encoded_cost_active_candidate(input : @lib.Module) -> @lib.Module {
  let @lib.Data(_, payload) = input.data_sec.unwrap().0[0]
  let candidate = input.with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        b"\x01",
      ),
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(payload.length() - 1)),
          ]),
        ),
        b"\x02",
      ),
    ]),
  )
  let candidate = if input.data_cnt_sec is Some(_) {
    candidate.with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(2U)))
  } else {
    candidate
  }
  match input.name_sec {
    Some(sec) => {
      let @lib.NameAssoc(_, @lib.Name(name)) = sec.data_names.unwrap().0[0]
      candidate.with_name_sec(
        @lib.NameSec::new(
          data_names=Some(
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::new(name)),
              @lib.NameAssoc::new(
                1U,
                @lib.Name::from_string(name.to_owned() + ".1"),
              ),
            ]),
          ),
        ),
      )
    }
    None => candidate
  }
}

///|
fn mp_encoded_cost_assert_valid(input : @lib.Module) -> Unit raise {
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(error) => fail("encoded-cost fixture validation failed: \{error}")
  }
}

///|
fn mp_encoded_cost_assert_rollback(input : @lib.Module) -> Unit raise {
  let saved = @binary.encode_module(input).unwrap()
  mp_encoded_cost_assert_valid(input)
  for direct in [true, false] {
    let output = if direct {
      memory_packing_run_module_pass(input)
    } else {
      run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]).unwrap()
    }
    mp_encoded_cost_assert_valid(output)
    assert_true(
      @binary.encode_module(output).unwrap().length() <= saved.length(),
    )
    assert_eq(output.data_sec, input.data_sec)
    assert_eq(output.code_sec, input.code_sec)
    assert_eq(output.name_sec, input.name_sec)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "memory-packing rejects an active split whose retained names cost more than its zero bytes" {
  let input = mp_encoded_cost_fixture(
    9,
    name=Some("a-long-data-segment-name-that-makes-the-second-name-expensive"),
  )
  let proposed = mp_encoded_cost_active_candidate(input)
  mp_encoded_cost_assert_valid(input)
  mp_encoded_cost_assert_valid(proposed)
  assert_true(
    @binary.encode_module(proposed).unwrap().length() >
    @binary.encode_module(input).unwrap().length(),
  )
  mp_encoded_cost_assert_rollback(input)
}

///|
test "memory-packing retains unnamed active byte savings and profitable decoded split names" {
  for
    input in [
      mp_encoded_cost_fixture(9),
      mp_encoded_cost_fixture(128, name=Some("payload")),
    ] {
    let saved = @binary.encode_module(input).unwrap()
    let proposed = mp_encoded_cost_active_candidate(input)
    mp_encoded_cost_assert_valid(input)
    mp_encoded_cost_assert_valid(proposed)
    assert_true(
      @binary.encode_module(proposed).unwrap().length() < saved.length(),
    )
    for direct in [true, false] {
      let output = if direct {
        memory_packing_run_module_pass(input)
      } else {
        run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]).unwrap()
      }
      mp_encoded_cost_assert_valid(output)
      assert_eq(output.data_sec, proposed.data_sec)
      assert_eq(output.name_sec, proposed.name_sec)
      assert_true(
        @binary.encode_module(output).unwrap().length() < saved.length(),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "memory-packing rejects passive split name growth while preserving the original copy" {
  let input = mp_encoded_cost_fixture(
    22,
    passive=true,
    name=Some("a-long-data-segment-name-that-makes-the-second-name-expensive"),
  )
  // The interior run exceeds the existing 21-byte one-user threshold. Its
  // retained duplicate name alone costs more bytes than the omitted payload.
  let proposed_names = mp_encoded_cost_active_candidate(input).name_sec
  let split_code = pass_test_module_from_wat(
    "(module (memory 1) (data \"\") (data \"\") (func i32.const 0 i32.const 0 i32.const 1 memory.init 0 i32.const 1 i32.const 0 i32.const 22 memory.fill i32.const 23 i32.const 0 i32.const 1 memory.init 1))",
  ).code_sec.unwrap()
  let proposed = input
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(@lib.DataMode::passive(), b"\x01"),
        @lib.Data::new(@lib.DataMode::passive(), b"\x02"),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(2U)))
    .with_code_sec(split_code)
    .with_name_sec(proposed_names.unwrap())
  mp_encoded_cost_assert_valid(proposed)
  assert_true(
    @binary.encode_module(proposed).unwrap().length() >
    @binary.encode_module(input).unwrap().length(),
  )
  mp_encoded_cost_assert_rollback(input)
}

///|
test "memory-packing keeps profitable passive splitting with the original copy endpoints" {
  let input = mp_encoded_cost_fixture(128, passive=true)
  let saved = @binary.encode_module(input).unwrap()
  for direct in [true, false] {
    let output = if direct {
      memory_packing_run_module_pass(input)
    } else {
      run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]).unwrap()
    }
    mp_encoded_cost_assert_valid(output)
    assert_eq(output.data_sec.unwrap().0, [
      @lib.Data::new(@lib.DataMode::passive(), b"\x01"),
      @lib.Data::new(@lib.DataMode::passive(), b"\x02"),
    ])
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_true(
      body.contains(@lib.Instruction::memory_fill(@lib.MemIdx::new(0U))),
    )
    assert_true(
      body.contains(
        @lib.Instruction::memory_init(
          @lib.DataIdx::new(1U),
          @lib.MemIdx::new(0U),
        ),
      ),
    )
    assert_true(
      @binary.encode_module(output).unwrap().length() < saved.length(),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "memory-packing cannot pay for passive data growth by discarding compiler facts" {
  let build_id = StringBuilder()
  for _ in 0..<128 {
    build_id.write_string("x")
  }
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(
      producer=Some(
        @representation.ProducerInfo::new(
          "encoded-cost-regression",
          "1",
          build_id=Some(build_id.to_string()),
        ),
      ),
    ),
  )
  let input = mp_encoded_cost_fixture(
    22,
    passive=true,
    name=Some("a-long-data-segment-name-that-makes-the-second-name-expensive"),
  ).with_compiler_fact_custom_section(facts)
  mp_encoded_cost_assert_valid(input)
  let plain = input.without_compiler_fact_custom_section()
  let full_size = @binary.encode_module(input).unwrap().length()
  let plain_size = @binary.encode_module(plain).unwrap().length()
  assert_true(full_size > plain_size + 128)
  let output = memory_packing_run_module_pass(input)
  mp_encoded_cost_assert_valid(output)
  assert_true(physical_equal(output, input))
  assert_eq(output.compiler_fact_custom_section, Some(facts))
  assert_eq(output.data_sec, input.data_sec)
  assert_eq(output.name_sec, input.name_sec)
}

///|
test "memory-packing intentionally retains a smaller original trailing startup trap" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (data (i32.const 65534) \"A\\00\\00\"))",
  )
  guard input.data_sec.unwrap().0[0]
    is @lib.Data(@lib.Active(memory, offset), payload) else {
    fail("expected an active data segment")
  }
  let split = mp_active_rewrite(input, memory, offset, payload, false)
  assert_eq(split.length(), 2)
  let candidate = input.with_data_sec(@lib.DataSec::new(split))
  let candidate = if input.data_cnt_sec is Some(_) {
    candidate.with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(2U)))
  } else {
    candidate
  }
  mp_encoded_cost_assert_valid(input)
  mp_encoded_cost_assert_valid(candidate)
  assert_true(
    @binary.encode_module(input).unwrap().length() <
    @binary.encode_module(candidate).unwrap().length(),
  )
  // The unchanged segment still extends past the one-page memory and traps at
  // instantiation. Keeping the input preserves its semantics by identity.
  // Verified-v133 replay: original 26 bytes; Starshine split 32; oracle 35.
  // Enlarged positive coverage remains in memory_packing_test.mbt.
  let output = memory_packing_run_module_pass(input)
  assert_true(physical_equal(output, input))
  assert_eq(output.data_sec, input.data_sec)
  assert_eq(output.mem_sec, input.mem_sec)
}
