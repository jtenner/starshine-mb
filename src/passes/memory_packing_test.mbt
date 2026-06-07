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
fn mp_test_void_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn mp_test_i32_param_void_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
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
fn mp_test_first_func_locals(mod_ : @lib.Module) -> @lib.Locals {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) => locals
    Some(@lib.CodeSec([])) => abort("expected one function body, got none")
    Some(@lib.CodeSec(_)) => abort("expected one function body")
    None => abort("expected code section")
  }
}

///|
fn mp_test_instrs_have_memory_init(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if mp_test_instr_has_memory_init(instr) {
      return true
    }
  }
  false
}

///|
fn mp_test_instr_has_memory_init(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.MemoryInit(_, _) => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_instrs_have_memory_init(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      if mp_test_instrs_have_memory_init(then_body) {
        return true
      }
      match else_body {
        Some(body) => mp_test_instrs_have_memory_init(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn mp_test_instrs_have_memory_fill(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if mp_test_instr_has_memory_fill(instr) {
      return true
    }
  }
  false
}

///|
fn mp_test_instr_has_memory_fill(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.MemoryFill(_) => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_instrs_have_memory_fill(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      if mp_test_instrs_have_memory_fill(then_body) {
        return true
      }
      match else_body {
        Some(body) => mp_test_instrs_have_memory_fill(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn mp_test_instrs_have_unreachable(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if mp_test_instr_has_unreachable(instr) {
      return true
    }
  }
  false
}

///|
fn mp_test_instr_has_unreachable(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Unreachable => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_instrs_have_unreachable(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      if mp_test_instrs_have_unreachable(then_body) {
        return true
      }
      match else_body {
        Some(body) => mp_test_instrs_have_unreachable(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn mp_test_instrs_have_global_get(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if mp_test_instr_has_global_get(instr) {
      return true
    }
  }
  false
}

///|
fn mp_test_instr_has_global_get(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.GlobalGet(_) => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_instrs_have_global_get(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      if mp_test_instrs_have_global_get(then_body) {
        return true
      }
      match else_body {
        Some(body) => mp_test_instrs_have_global_get(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn mp_test_instrs_have_global_set(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if mp_test_instr_has_global_set(instr) {
      return true
    }
  }
  false
}

///|
fn mp_test_instr_has_global_set(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.GlobalSet(_) => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_instrs_have_global_set(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      if mp_test_instrs_have_global_set(then_body) {
        return true
      }
      match else_body {
        Some(body) => mp_test_instrs_have_global_set(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn mp_test_instrs_have_i32_div_s(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if mp_test_instr_has_i32_div_s(instr) {
      return true
    }
  }
  false
}

///|
fn mp_test_instr_has_i32_div_s(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32DivS => true
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_instrs_have_i32_div_s(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      if mp_test_instrs_have_i32_div_s(then_body) {
        return true
      }
      match else_body {
        Some(body) => mp_test_instrs_have_i32_div_s(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn mp_test_count_data_drop_instrs(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += mp_test_count_data_drop_instr(instr)
  }
  count
}

///|
fn mp_test_count_data_drop_instr(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.DataDrop(_) => 1
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) => {
      let @lib.Expr(instrs) = body
      mp_test_count_data_drop_instrs(instrs)
    }
    @lib.If(_, then_body, else_body) => {
      let mut count = mp_test_count_data_drop_instrs(then_body)
      match else_body {
        Some(body) => count += mp_test_count_data_drop_instrs(body)
        None => ()
      }
      count
    }
    _ => 0
  }
}

///|
fn mp_test_has_active_i32_offset(mod_ : @lib.Module, offset : Int) -> Bool {
  for segment in mp_test_active_data_segments(mod_) {
    match segment {
      (_, actual, _) => if actual == offset { return true }
    }
  }
  false
}

///|
fn mp_test_expect_valid(mod_ : @lib.Module, label : String) -> Unit {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("expected valid \{label}, got \{err}")
  }
}

///|
fn mp_test_data_name_entries(mod_ : @lib.Module) -> Array[@lib.NameAssoc] {
  match mod_.name_sec {
    Some(sec) =>
      match sec.data_names {
        Some(@lib.NameMap(entries)) => entries
        None => []
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
test "memory-packing drops trapping active zeros when traps never happen" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (memory 1)
      #|   (data (i32.const 65535) "\00\00"))
      #|,
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(traps_never_happen=true), [
      "memory-packing",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing TNH pipeline success, got \{err}")
  }

  @debug.assert_eq(mp_test_data_segments(optimized).length(), 0)
}

///|
test "memory-packing preserves empty active segment with trapping offset" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(65537))]),
          ),
          b"",
        ),
      ]),
    )
  let optimized = memory_packing_run_module_pass(input)

  let segments = mp_test_active_data_segments(optimized)
  @debug.assert_eq(segments.length(), 1)
  match segments[0] {
    (mem_idx, offset, bytes) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 65537)
      @debug.assert_eq(bytes, b"")
    }
  }
}

///|
test "memory-packing preserves trailing trap after a nonzero prefix" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data (i32.const 65534) "A\00\00"))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }

  let segments = mp_test_active_data_segments(optimized)
  @debug.assert_eq(segments.length(), 2)
  match segments[0] {
    (mem_idx, offset, bytes) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 65534)
      @debug.assert_eq(bytes, b"A")
    }
  }
  match segments[1] {
    (mem_idx, offset, bytes) => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 65536)
      @debug.assert_eq(bytes, b"\x00")
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

///|
test "memory-packing leaves imported memory active segments unchanged" {
  let wat =
    #| (module
    #|   (import "env" "memory" (memory 1))
    #|   (data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC"))
    #|
  let input = pass_test_module_from_wat(wat)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-packing imported-memory bailout success, got \{err}",
      )
  }
  @debug.assert_eq(optimized.data_sec, input.data_sec)
}

///|
test "memory-packing packs imported memory when zero-filled memory is known" {
  let wat =
    #| (module
    #|   (import "env" "memory" (memory 1))
    #|   (data (i32.const 0) "\00\00\00\00\00\00\00\00\00ABC"))
    #|
  let input = pass_test_module_from_wat(wat)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(zero_filled_memory=true), [
      "memory-packing",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory-packing zero-filled imported-memory success, got \{err}",
      )
  }
  let segments = mp_test_active_data_segments(optimized)
  @debug.assert_eq(segments.length(), 1)
  @debug.assert_eq(segments[0].1, 9)
  @debug.assert_eq(segments[0].2.length(), 3)
}

///|
test "memory-packing remaps passive array data users after active segment count changes" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
        @lib.Data::new(@lib.DataMode::passive(), b"XY"),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::array_new_data(
              @lib.TypeIdx::new(0U),
              @lib.DataIdx::new(1U),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::array_init_data(
              @lib.TypeIdx::new(0U),
              @lib.DataIdx::new(1U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  @debug.assert_eq(mp_test_data_segments(optimized).length(), 3)
  @debug.assert_eq(mp_test_first_func_body(optimized), [
    @lib.Instruction::array_new_data(
      @lib.TypeIdx::new(0U),
      @lib.DataIdx::new(2U),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::array_init_data(
      @lib.TypeIdx::new(0U),
      @lib.DataIdx::new(2U),
    ),
  ])
}

///|
test "memory-packing rewrites constant memory64 active offsets" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(0L))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00ABC",
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  match mp_test_data_segments(optimized) {
    [
      @lib.Data(
        @lib.Active(
          @lib.MemIdx(mem_idx),
          @lib.Expr([@lib.I64Const(@lib.I64(offset))])
        ),
        bytes
      ),
    ] => {
      @debug.assert_eq(mem_idx, 0U)
      @debug.assert_eq(offset, 9L)
      @debug.assert_eq(bytes, b"ABC")
    }
    other =>
      fail("expected one memory64 active segment at offset 9, got \{other}")
  }
}

///|
test "memory-packing handles many out-of-order non-overlapping active segments" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(40))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00D",
        ),
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00A",
        ),
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(24))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00C",
        ),
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(12))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  let segments = mp_test_active_data_segments(optimized)
  @debug.assert_eq(segments.length(), 4)
  @debug.assert_eq(segments[0].1, 49)
  @debug.assert_eq(segments[1].1, 9)
  @debug.assert_eq(segments[2].1, 33)
  @debug.assert_eq(segments[3].1, 21)
}

///|
test "memory-packing rewrites active data.drop to nop" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"live",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::data_drop(@lib.DataIdx::new(0U))]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  @debug.assert_eq(mp_test_first_func_body(optimized), [@lib.Instruction::nop()])
}

///|
test "memory-packing rewrites out-of-range active memory.init to an explicit trap" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"abc",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  let body = mp_test_first_func_body(optimized)
  if mp_test_instrs_have_memory_init(body) {
    fail("expected active memory.init source trap to be lowered away")
  }
  if !mp_test_instrs_have_unreachable(body) {
    fail(
      "expected active memory.init source trap rewrite to contain unreachable",
    )
  }
}

///|
test "memory-packing preserves active memory.init trap operand side effects" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (global $g (mut i32) (i32.const 0))
    #|   (data (i32.const 0) "abc")
    #|   (func
    #|     (memory.init 0
    #|       (block (result i32)
    #|         (i32.const 7)
    #|         (global.set $g)
    #|         (i32.const 0))
    #|       (i32.const 10)
    #|       (i32.const 1))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }
  mp_test_expect_valid(
    optimized, "active memory.init trap operand side effects",
  )
  let body = mp_test_first_func_body(optimized)
  if mp_test_instrs_have_memory_init(body) {
    fail("expected active memory.init source trap to be lowered away")
  }
  if !mp_test_instrs_have_global_set(body) {
    fail(
      "expected active memory.init trap rewrite to preserve destination side effect",
    )
  }
  if !mp_test_instrs_have_unreachable(body) {
    fail(
      "expected active memory.init source trap rewrite to contain unreachable",
    )
  }
}

///|
test "memory-packing lowers zero-size active memory.init bounds checks" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"abc",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(65536)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  if mp_test_instrs_have_memory_init(mp_test_first_func_body(optimized)) {
    fail(
      "expected zero-size active memory.init to become an explicit bounds check",
    )
  }
}

///|
test "memory-packing preserves zero-size active memory.init trapping operands" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data (i32.const 0) "abc")
    #|   (func
    #|     (memory.init 0
    #|       (i32.div_s (i32.const 1) (i32.const 0))
    #|       (i32.const 0)
    #|       (i32.const 0))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }
  mp_test_expect_valid(
    optimized, "zero-size active memory.init trapping operand",
  )
  let body = mp_test_first_func_body(optimized)
  if mp_test_instrs_have_memory_init(body) {
    fail("expected zero-size active memory.init to be lowered away")
  }
  if !mp_test_instrs_have_i32_div_s(body) {
    fail(
      "expected zero-size active memory.init rewrite to preserve destination trap",
    )
  }
}

///|
test "memory-packing splits passive zero ranges and inserts memory.fill" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(34)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  if mp_test_data_segments(optimized).length() <= 1 {
    fail("expected live passive segment to be split around zero range")
  }
  if !mp_test_instrs_have_memory_fill(mp_test_first_func_body(optimized)) {
    fail(
      "expected passive split memory.init to insert memory.fill for zero slice",
    )
  }
}

///|
test "memory-packing allocates a temp local for dynamic passive memory.init destinations" {
  let input = @lib.Module::new()
    .with_type_sec(mp_test_i32_param_void_type_sec())
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(34)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  if mp_test_first_func_locals(optimized).length() == 0 {
    fail(
      "expected dynamic passive memory.init replacement to allocate a destination temp local",
    )
  }
  if !mp_test_instrs_have_memory_fill(mp_test_first_func_body(optimized)) {
    fail(
      "expected dynamic passive memory.init replacement to contain memory.fill",
    )
  }
}

///|
test "memory-packing rewrites out-of-range split-passive memory.init to an explicit trap" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(100)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  let body = mp_test_first_func_body(optimized)
  if mp_test_instrs_have_memory_fill(body) ||
    mp_test_instrs_have_memory_init(body) {
    fail(
      "expected out-of-range split-passive memory.init to lower to a trap only",
    )
  }
  if !mp_test_instrs_have_unreachable(body) {
    fail(
      "expected out-of-range split-passive memory.init to contain unreachable",
    )
  }
}

///|
test "memory-packing preserves split-passive memory.init trap operand side effects" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (global $g (mut i32) (i32.const 0))
    #|   (data "A\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00B")
    #|   (func
    #|     (memory.init 0
    #|       (block (result i32)
    #|         (i32.const 7)
    #|         (global.set $g)
    #|         (i32.const 0))
    #|       (i32.const 100)
    #|       (i32.const 1))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["memory-packing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory-packing pipeline success, got \{err}")
  }
  mp_test_expect_valid(
    optimized, "split-passive memory.init trap operand side effects",
  )
  let body = mp_test_first_func_body(optimized)
  if mp_test_instrs_have_memory_fill(body) ||
    mp_test_instrs_have_memory_init(body) {
    fail("expected split-passive memory.init source trap to be lowered away")
  }
  if !mp_test_instrs_have_global_set(body) {
    fail(
      "expected split-passive memory.init trap rewrite to preserve destination side effect",
    )
  }
  if !mp_test_instrs_have_unreachable(body) {
    fail(
      "expected split-passive memory.init source trap rewrite to contain unreachable",
    )
  }
}

///|
test "memory-packing expands data.drop over passive split survivors" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(34)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
            @lib.Instruction::data_drop(@lib.DataIdx::new(0U)),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  let drop_count = mp_test_count_data_drop_instrs(
    mp_test_first_func_body(optimized),
  )
  if drop_count <= 1 {
    fail("expected data.drop to expand across passive split survivors")
  }
}

///|
test "memory-packing adds a lazy drop-state global for fill-first passive replacements" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00A",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(33)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  match optimized.global_sec {
    Some(_) => ()
    None =>
      fail("expected fill-first passive replacement to add a drop-state global")
  }
  if !mp_test_instrs_have_global_get(mp_test_first_func_body(optimized)) {
    fail(
      "expected fill-first passive replacement to check the drop-state global",
    )
  }
}

///|
test "memory-packing keeps named __llvm data segments intact" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00ABC",
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        data_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::new("__llvm_covfun")),
          ]),
        ),
      ),
    )

  let optimized = memory_packing_run_module_pass(input)
  @debug.assert_eq(
    mp_test_data_segments(optimized),
    mp_test_data_segments(input),
  )
}

///|
test "memory-packing gives split data segments suffixed names" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(34)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        data_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("payload")),
          ]),
        ),
      ),
    )

  let optimized = memory_packing_run_module_pass(input)
  @debug.assert_eq(mp_test_data_name_entries(optimized), [
    @lib.NameAssoc::new(0U, @lib.Name::from_string("payload")),
    @lib.NameAssoc::new(1U, @lib.Name::from_string("payload.1")),
  ])
}

///|
test "memory-packing does not split passive segments with GC data users" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::array_new_data(
              @lib.TypeIdx::new(0U),
              @lib.DataIdx::new(0U),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(34)),
            @lib.Instruction::memory_init(
              @lib.DataIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  @debug.assert_eq(mp_test_data_segments(optimized).length(), 1)
  if mp_test_instrs_have_memory_fill(mp_test_first_func_body(optimized)) {
    fail("expected GC data-user segment to stay unsplit")
  }
}

///|
test "memory-packing repairs data names after deleting drop-only passive segments" {
  let input = @lib.Module::new()
    .with_type_sec(mp_test_void_type_sec())
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"dead")]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::data_drop(@lib.DataIdx::new(0U))]),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        data_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::new("dead_segment")),
          ]),
        ),
      ),
    )

  let optimized = memory_packing_run_module_pass(input)
  mp_test_expect_valid(optimized, "memory-packing named data deletion")
}

///|
test "memory-packing does not wrap high-address active offsets into low memory" {
  let input = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(-4))]),
          ),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00A",
        ),
      ]),
    )

  let optimized = memory_packing_run_module_pass(input)
  if mp_test_has_active_i32_offset(optimized, 5) {
    fail("expected high-address split not to wrap into low memory offset 5")
  }
  if !mp_test_has_active_i32_offset(optimized, -1) {
    fail("expected high-address split to saturate at i32 max offset")
  }
}
