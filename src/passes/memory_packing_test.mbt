///|
fn mp_test_active_data_segments(
  mod_ : @lib.Module,
) -> Array[(UInt, Int, Bytes)] {
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let segments : Array[(UInt, Int, Bytes)] = []
      for data in datas {
        match data {
          @lib.Data(
            @lib.Active(
              @lib.MemIdx(mem_idx),
              @lib.Expr([@lib.I32Const(@lib.I32(offset))])
            ),
            bytes
          ) => segments.push((mem_idx, offset, bytes))
          _ => ()
        }
      }
      segments
    }
    None => []
  }
}

///|
test "run_hot_pipeline applies memory-packing to profitable active zero ranges" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC"))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }

  let segments = mp_test_active_data_segments(optimized)
  assert_eq(segments.length(), 1)
  match segments[0] {
    (mem_idx, offset, bytes) => {
      assert_eq(mem_idx, 0U)
      assert_eq(offset, 9)
      assert_eq(bytes.length(), 3)
      assert_eq(bytes[0], 0x41)
      assert_eq(bytes[1], 0x42)
      assert_eq(bytes[2], 0x43)
    }
  }
}

///|
test "memory-packing preserves trapping active segments by keeping the top byte" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data (i32.const 65535) "\00\00"))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }

  let segments = mp_test_active_data_segments(optimized)
  assert_eq(segments.length(), 1)
  match segments[0] {
    (mem_idx, offset, bytes) => {
      assert_eq(mem_idx, 0U)
      assert_eq(offset, 65536)
      assert_eq(bytes.length(), 1)
      assert_eq(bytes[0], 0x00)
    }
  }
}

///|
test "memory-packing bails out when active segments overlap" {
  let wat =
    #| (module
    #|   (memory 1)
    #|   (data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC")
    #|   (data (i32.const 5) "ZZ"))
    #|
  let input = pass_test_module_from_wat(wat)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory-packing overlap bailout success, got \{err}")
  }
  assert_eq(optimized.data_sec, input.data_sec)
}
