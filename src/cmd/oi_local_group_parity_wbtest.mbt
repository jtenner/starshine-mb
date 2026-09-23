///|
fn oi_local_group_case_15_input() -> Bytes {
  Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 17, 4, 96, 0, 0, 96, 2, 127, 124, 0, 96, 0, 0,
    96, 2, 126, 127, 0, 3, 2, 1, 0, 7, 8, 1, 4, 109, 97, 105, 110, 0, 0, 10, 42,
    1, 40, 5, 5, 127, 1, 125, 1, 124, 1, 125, 1, 126, 65, 1, 33, 0, 2, 127, 65, 7,
    33, 0, 65, 9, 33, 1, 32, 0, 11, 33, 2, 32, 0, 26, 32, 1, 26, 32, 2, 26, 11,
  ])
}

///|
fn oi_local_group_case_28_input() -> Bytes {
  Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 1, 126, 0, 3, 2, 1, 0, 7, 8, 1, 4,
    109, 97, 105, 110, 0, 0, 10, 35, 1, 33, 7, 5, 127, 2, 125, 1, 124, 1, 126, 1,
    124, 1, 125, 1, 127, 65, 1, 4, 64, 65, 7, 33, 1, 5, 65, 9, 33, 1, 11, 32, 1,
    26, 11,
  ])
}

///|
fn oi_local_group_case_15_binaryen_v132() -> Bytes {
  Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 4, 1, 96, 0, 0, 3, 2, 1, 0, 7, 8, 1, 4, 109,
    97, 105, 110, 0, 0, 10, 13, 1, 11, 4, 5, 127, 2, 125, 1, 124, 1, 126, 1, 11,
  ])
}

///|
fn oi_local_group_case_28_binaryen_v132() -> Bytes {
  Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 1, 126, 0, 3, 2, 1, 0, 7, 8, 1, 4,
    109, 97, 105, 110, 0, 0, 10, 13, 1, 11, 4, 6, 127, 3, 125, 2, 124, 1, 126, 1,
    11,
  ])
}

///|
fn oi_local_group_case_15_expected() -> Bytes {
  Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 4, 1, 96, 0, 0, 3, 2, 1, 0, 7, 8, 1, 4, 109,
    97, 105, 110, 0, 0, 10, 12, 1, 10, 4, 5, 127, 2, 125, 1, 124, 1, 126, 11,
  ])
}

///|
fn oi_local_group_case_28_expected() -> Bytes {
  Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 1, 126, 0, 3, 2, 1, 0, 7, 8, 1, 4,
    109, 97, 105, 110, 0, 0, 10, 12, 1, 10, 4, 6, 127, 3, 125, 2, 124, 1, 126, 11,
  ])
}

///|
fn oi_local_group_run_seven_passes(input : Bytes, name : String) -> Bytes raise {
  let writes : Array[(String, Bytes)] = []
  let io = CmdIO::new(
    list_candidates=fn() { [name] },
    file_exists=fn(path) { path == name },
    read_file=fn(path) {
      if path == name {
        Ok(input)
      } else {
        Err("missing fixture")
      }
    },
    write_file=fn(path, bytes) {
      writes.push((path, bytes))
      Ok(())
    },
  )
  let summary = run_cmd_with_adapter(
    [
      "--optimize-instructions", "--precompute", "--vacuum", "--local-cse", "--simplify-locals",
      "--remove-unused-brs", "--dead-code-elimination", "--out", "out.wasm", name,
    ],
    io,
  ).unwrap()
  @debug.assert_eq(summary.resolved_passes, [
    "optimize-instructions", "precompute", "vacuum", "local-cse", "simplify-locals",
    "remove-unused-brs", "dead-code-elimination",
  ])
  @debug.assert_eq(writes.length(), 1)
  writes[0].1
}

///|
test "dispatcher case 15 groups OI locals below Binaryen v132 raw size" {
  let encoded = oi_local_group_run_seven_passes(
    oi_local_group_case_15_input(),
    "case15.wasm",
  )
  @debug.assert_eq(encoded, oi_local_group_case_15_expected())
  assert_true(
    encoded.length() < oi_local_group_case_15_binaryen_v132().length(),
  )
  let output = @binary.decode_module(encoded).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(@binary.encode_module(output).unwrap(), encoded)
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.runs().length(), 4)
}

///|
test "dispatcher case 28 groups OI locals below Binaryen v132 raw size" {
  let encoded = oi_local_group_run_seven_passes(
    oi_local_group_case_28_input(),
    "case28.wasm",
  )
  @debug.assert_eq(encoded, oi_local_group_case_28_expected())
  assert_true(
    encoded.length() < oi_local_group_case_28_binaryen_v132().length(),
  )
  let output = @binary.decode_module(encoded).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(@binary.encode_module(output).unwrap(), encoded)
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.runs().length(), 4)
}
