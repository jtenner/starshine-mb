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
fn mp_test_data_segments(mod_ : @lib.Module) -> Array[@lib.Data] {
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => datas
    None => []
  }
}

///|
fn mp_test_first_func_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    Some(@lib.CodeSec([])) => abort("expected one function body, got none")
    Some(@lib.CodeSec(_)) => abort("expected one function body")
    None => abort("expected code section")
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
  @debug.assert_eq(segments.length(), 1)
  match segments[0] {
    (mem_idx, offset, bytes) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 9)
      @debug.assert_eq(bytes.length(), 3)
      @debug.assert_eq(bytes[0], 0x41)
      @debug.assert_eq(bytes[1], 0x42)
      @debug.assert_eq(bytes[2], 0x43)
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
  @debug.assert_eq(segments.length(), 1)
  match segments[0] {
    (mem_idx, offset, bytes) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 65536)
      @debug.assert_eq(bytes.length(), 1)
      @debug.assert_eq(bytes[0], 0x00)
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
  @debug.assert_eq(optimized.data_sec, input.data_sec)
}

///|
test "memory-packing drops passive segments referenced only by data.drop" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data "dead")
    #|   (func
    #|     (data.drop 0)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }

  @debug.assert_eq(mp_test_data_segments(optimized), [])
  @debug.assert_eq(optimized.data_cnt_sec, None)
  @debug.assert_eq(mp_test_first_func_body(optimized), [@lib.Instruction::nop()])
}

///|
test "memory-packing remaps passive data users after active segment count changes" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data (i32.const 0) "A\00\00\00\00\00\00\00\00\00B")
    #|   (data "XY")
    #|   (func
    #|     (memory.init 1 (i32.const 0) (i32.const 0) (i32.const 2))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }

  let segments = mp_test_data_segments(optimized)
  @debug.assert_eq(segments.length(), 3)
  match segments[0] {
    @lib.Data(
      @lib.Active(
        @lib.MemIdx(mem_idx),
        @lib.Expr([@lib.I32Const(@lib.I32(offset))])
      ),
      bytes
    ) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 0)
      @debug.assert_eq(bytes, b"A")
    }
    _ => fail("expected first rewritten segment to be active at offset 0")
  }
  match segments[1] {
    @lib.Data(
      @lib.Active(
        @lib.MemIdx(mem_idx),
        @lib.Expr([@lib.I32Const(@lib.I32(offset))])
      ),
      bytes
    ) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 10)
      @debug.assert_eq(bytes, b"B")
    }
    _ => fail("expected second rewritten segment to be active at offset 10")
  }
  match segments[2] {
    @lib.Data(@lib.Passive, bytes) => @debug.assert_eq(bytes, b"XY")
    _ => fail("expected passive segment to be preserved after active rewrites")
  }

  @debug.assert_eq(mp_test_first_func_body(optimized), [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::memory_init(@lib.DataIdx::new(2U), @lib.MemIdx::new(0U)),
  ])
}
