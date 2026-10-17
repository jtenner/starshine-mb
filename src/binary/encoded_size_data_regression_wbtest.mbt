///|
fn encoded_data_size_check(before : Module, after : Module) -> Unit raise {
  let before_bytes = encode_module(before).unwrap()
  let after_bytes = encode_module(after).unwrap()
  assert_eq(
    encoded_module_sizes(before, after).unwrap(),
    (before_bytes.length(), after_bytes.length()),
  )
  assert_eq(
    encoded_module_sizes(after, before).unwrap(),
    (after_bytes.length(), before_bytes.length()),
  )
  assert_eq(encode_module(before).unwrap(), before_bytes)
}

///|
test "exact data size preserves active passive and explicit memory framing" {
  // These are encoder fixtures. Index128 tests its representation width; the
  // module deliberately has no memory declarations and is not executable.
  for length in [0, 1, 122, 123, 127, 128, 16383, 16384] {
    for
      mode in [
        DataMode::passive(),
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(0)]),
        ),
        DataMode::active(
          MemIdx::new(128U),
          Expr::new([Instruction::i64_const(127L)]),
        ),
      ] {
      let original = Module::new().with_data_sec(
        DataSec::new([Data::new(mode, Bytes::make(length, 0xA5))]),
      )
      let changed = Module::new().with_data_sec(
        DataSec::new([Data::new(mode, Bytes::make(length + 1, 0x5A))]),
      )
      encoded_data_size_check(original, changed)
    }
  }
}

///|
test "exact data size distinguishes absent empty and segment count boundaries" {
  let absent = Module::new()
  let empty = Module::new().with_data_sec(DataSec::new([]))
  encoded_data_size_check(absent, empty)
  assert_eq(encode_module(empty).unwrap().length(), 11)
  for count in [1, 127, 128] {
    let data = Array::make(count, Data::new(DataMode::passive(), b""))
    let mod_ = Module::new().with_data_sec(DataSec::new(data))
    encoded_data_size_check(empty, mod_)
  }
}

///|
test "exact data size retains invalid offset encoding errors in either argument" {
  // Bottom annotations are intentionally invalid for the encoder.
  let invalid = Module::new().with_data_sec(
    DataSec::new([
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::select(types=Some([ValType::bottom()]))]),
        ),
        b"payload",
      ),
    ]),
  )
  let expected = encode_module(invalid)
  assert_true(expected is Err(_))
  match expected {
    Err(err) => {
      assert_eq(encoded_module_sizes(Module::new(), invalid), Err(err))
      assert_eq(encoded_module_sizes(invalid, Module::new()), Err(err))
    }
    Ok(_) => fail("invalid offset unexpectedly encoded")
  }
}

///|
test "exact data size rejects shared payload length overflow without materializing bytes" {
  // Only4MiB is allocated. Sharing it exposes a4GiB section without encoding or
  // constructing that output. Keep this critical arithmetic check bounded.
  let payload = Bytes::make(4 * 1024 * 1024, 0)
  for count in [512, 1024] {
    let too_large = Module::new().with_data_sec(
      DataSec::new(Array::make(count, Data::new(DataMode::passive(), payload))),
    )
    let error = Err(
      EncodeError::Encode(BinaryEncodeError::UnsignedLebValueOutOfRange),
    )
    assert_eq(encoded_module_sizes(too_large, Module::new()), error)
    assert_eq(encoded_module_sizes(Module::new(), too_large), error)
  }
}
