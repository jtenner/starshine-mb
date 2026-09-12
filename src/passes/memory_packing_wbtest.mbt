///|
test "memory-packing segment-limit guard allows exact wasm maximum only" {
  assert_false(mp_data_segment_limit_exceeded(99999, 1, 0))
  assert_false(mp_data_segment_limit_exceeded(99998, 1, 1))
  assert_true(mp_data_segment_limit_exceeded(99999, 2, 0))
}

///|
fn mp_wbtest_void_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn mp_wbtest_first_func_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected one function body")
  }
}

///|
fn mp_wbtest_instrs_have_memory_init(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if instr is @lib.MemoryInit(_, _) {
      return true
    }
  }
  false
}

///|
fn mp_wbtest_assert_active_memory_init_operand_rewrite(
  dest_and_effects : Array[@lib.Instruction],
) -> Unit raise {
  let body = dest_and_effects.copy()
  body.push(@lib.Instruction::i32_const(@lib.I32(0)))
  body.push(@lib.Instruction::i32_const(@lib.I32(1)))
  body.push(
    @lib.Instruction::memory_init(@lib.DataIdx::new(0U), @lib.MemIdx::new(0U)),
  )
  let input = @lib.Module::new()
    .with_type_sec(mp_wbtest_void_type_sec())
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
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
          b"\x00\x00\x00\x00",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(validate_final_module=false),
      ["memory-packing"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected public memory-packing pipeline success: \{err}")
  }
  let out = mp_wbtest_first_func_body(optimized)
  assert_false(
    mp_wbtest_instrs_have_memory_init(out),
    msg="expected public pipeline operand extraction to remove memory.init",
  )
  match out[out.length() - 1] {
    @lib.Unreachable => ()
    other =>
      fail(
        "expected active memory.init requiring source bytes to trap, got \{other}",
      )
  }
}

///|
test "memory-packing operand scanner uses exact validator stack deltas" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::table_set(@lib.TableIdx::new(0U))),
    Some((2, 0)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(
      @lib.Instruction::array_copy(@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)),
    ),
    Some((5, 0)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::br_on_null(@lib.LabelIdx::new(0U))),
    Some((1, 1)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::ref_test_desc(false, heap)),
    Some((2, 1)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::ref_cast_desc_eq(false, heap)),
    Some((2, 1)),
  )
}

///|
test "memory-packing public pipeline rewrites active memory.init across corrected stack effects" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::array_copy(@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_test_desc(false, heap),
    @lib.Instruction::drop(),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_cast_desc_eq(false, heap),
    @lib.Instruction::drop(),
  ])
}

///|
test "Binaryen 132 memory64 massive empty segment retains its offset and instantiation trap" {
  // v132 ctor-eval/memory64-massive.wast: an empty segment at this offset is
  // still outside a 16-page memory. Packing must neither zero-fill 4 GiB nor
  // discard the segment and make instantiation succeed.
  let input = pass_test_module_from_wat(
    (
      #|(module (memory i64 16 16 shared)
      #| (data (i64.const 4294968321) "")
      #| (func (export "func")))
    ),
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  @debug.assert_eq(output.data_sec, input.data_sec)
  @debug.assert_eq(output.mem_sec, input.mem_sec)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "memory-packing active byte length is not its runtime source length" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (data (i32.const 0) \"x\") (func (memory.init 0 (i32.const 0) (i32.const 0) (i32.const 1))))",
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  let body = mp_wbtest_first_func_body(output)
  assert_true(body[body.length() - 1] is @lib.Unreachable)
}

///|
test "memory-packing all-zero split keeps independent logical lifetimes" {
  let zeros = "\\00".repeat(64)
  let input = pass_test_module_from_wat(
    "(module (memory 1) (data \"\{zeros}\") (data \"\{zeros}\") (func (data.drop 0) (memory.init 0 (i32.const 0) (i32.const 0) (i32.const 1)) (data.drop 1) (memory.init 1 (i32.const 0) (i32.const 0) (i32.const 1))))",
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  match output.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 2)
    _ => fail("expected per-segment lifetime globals")
  }
  let body = mp_wbtest_first_func_body(output)
  assert_true(
    body.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U))),
  )
  assert_true(
    body.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(1U))),
  )
  assert_true(
    body.contains(@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))),
  )
  assert_true(
    body.contains(@lib.Instruction::global_get(@lib.GlobalIdx::new(1U))),
  )
  // Constant destinations are proven in bounds; lifetime checks still precede writes.
  let mut checks = 0
  let mut fills = 0
  for instr in body {
    match instr {
      @lib.If(_, _, _) => checks += 1
      @lib.MemoryFill(_) => {
        fills += 1
        assert_true(checks >= fills)
      }
      _ => ()
    }
  }
  assert_eq(fills, 2)
}

///|
test "memory-packing preserves overflowing memory64 active initialization bytes" {
  let input = pass_test_module_from_wat(
    "(module (memory i64 1) (data (i64.const -1) \"\\00\\00\"))",
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  assert_eq(output.data_sec, input.data_sec)
}

///|
test "memory-packing active GC data users retain a valid runtime identity" {
  let input = pass_test_module_from_wat(
      "(module (type (array (mut i8))) (memory 1) (data (i32.const 0) \"\\00\\00\") (func (result i32) i32.const 0))",
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_new_data(
              @lib.TypeIdx::new(0U),
              @lib.DataIdx::new(0U),
            ),
            @lib.Instruction::array_len(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  assert_eq(output.data_sec, input.data_sec)
}

///|
test "memory-packing constant destination preflight folds to a page requirement" {
  let out : Array[@lib.Instruction] = []
  mp_emit_destination_preflight(
    out,
    mp_i32_const(65532),
    72,
    @lib.MemIdx::new(0U),
    None,
    I32Address,
  )
  assert_eq(out, [
    mp_i32_const(2),
    @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
  ])
}

///|
test "memory-packing constant preflight represents unsigned memory limits exactly" {
  for size in [0, 1, 2] {
    let out : Array[@lib.Instruction] = []
    mp_emit_destination_preflight(
      out,
      @lib.Instruction::i64_const(@lib.I64(-1L)),
      size,
      @lib.MemIdx::new(0U),
      None,
      I64Address,
    )
    if size == 2 {
      assert_eq(out, [@lib.Instruction::unreachable_()])
    } else {
      assert_eq(out[0], @lib.Instruction::i64_const(@lib.I64(1L << 48)))
      assert_eq(out.length(), 4)
    }
    let out32 : Array[@lib.Instruction] = []
    mp_emit_destination_preflight(
      out32,
      mp_i32_const(-1),
      size,
      @lib.MemIdx::new(0U),
      None,
      I32Address,
    )
    assert_eq(out32[0], mp_i32_const(if size == 2 { 65537 } else { 65536 }))
  }
}

///|
test "memory-packing constant split uses proven bounds and retained lifetime" {
  let zeros = "\\00".repeat(64)
  for memory in ["1", "i64 1"] {
    let addr = if memory == "1" { "i32" } else { "i64" }
    let input = pass_test_module_from_wat(
      "(module (memory \{memory}) (data \"A\{zeros}B\") (func (memory.init 0 (\{addr}.const 0) (i32.const 0) (i32.const 66)) (data.drop 0)))",
    )
    assert_true(@validate.validate_module(input) is Ok(_))
    let output = match
      run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
      Ok(output) => output
      Err(err) => fail(err)
    }
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_eq(output.global_sec, None)
    let body = mp_wbtest_first_func_body(output)
    assert_false(
      body.contains(@lib.Instruction::memory_size(@lib.MemIdx::new(0U))),
    )
    assert_eq(body.length(), 14)
  }
}

///|
test "memory-packing indexed user analysis isolates nested segment users" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (data \"a\") (data \"b\") (data \"c\") (func (param i32) (block (memory.init 0 (i32.const 0) (i32.const 0) (i32.const 1))) (if (local.get 0) (then (data.drop 1)) (else (memory.init 1 (i32.const 0) (local.get 0) (i32.const 1)))) (memory.init 0 (i32.const 0) (i32.const 0) (i32.const 0))))",
  )
  assert_true(@validate.validate_module(input) is Ok(_))
  let scans = mp_collect_segment_users(input, 3)
  assert_eq(scans[0].memory_init_count, 2)
  assert_true(scans[0].all_memory_init_const)
  assert_eq(scans[0].data_drop_count, 0)
  assert_eq(scans[1].memory_init_count, 1)
  assert_false(scans[1].all_memory_init_const)
  assert_eq(scans[1].data_drop_count, 1)
  assert_false(scans[2].has_memory_init)
  assert_true(scans[2].all_memory_init_const)
  assert_eq(scans[2].data_drop_count, 0)
}

///|
test "memory-packing minimum-page proofs preserve endpoints and overflow guards" {
  for
    entry in [
      (65535, 1, true),
      (65536, 0, true),
      (65535, 2, false),
      (65537, 0, false),
    ] {
    let (offset, size, proven) = entry
    let out : Array[@lib.Instruction] = []
    mp_emit_destination_preflight(
      out,
      mp_i32_const(offset),
      size,
      @lib.MemIdx::new(0U),
      None,
      I32Address,
      initial_pages=1UL,
    )
    assert_eq(out.is_empty(), proven)
  }
  for size in [0, 1, 2] {
    let out : Array[@lib.Instruction] = []
    mp_emit_destination_preflight(
      out,
      @lib.Instruction::i64_const(@lib.I64(-1L)),
      size,
      @lib.MemIdx::new(0U),
      None,
      I64Address,
      initial_pages=1UL << 48,
    )
    if size == 2 {
      assert_eq(out, [@lib.Instruction::unreachable_()])
    } else {
      assert_true(out.is_empty())
    }
  }
}
