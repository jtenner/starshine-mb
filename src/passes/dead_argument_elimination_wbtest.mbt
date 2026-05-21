///|
fn dae_wbtest_call_summary_fixture() -> @lib.Module {
  let void_type = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([void_type, void_type, void_type]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("entry"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        ]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    ]),
  )
}

///|
test "dae original call summary counts repeated undropped callees once per caller" {
  let mod_ = dae_wbtest_call_summary_fixture()
  let summary = dae_collect_original_call_summary_with_type_indices(
    mod_,
    dae_collect_func_type_indices(mod_),
  )
  assert_eq(summary.call_counts, [0, 2, 2])
  assert_eq(summary.prior_call_counts, [0, 1, 2])
  assert_eq(summary.self_call_counts, [0, 1, 0])
  assert_eq(summary.nonself_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.prior_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.active_nonself_call_counts, [0, 1, 2])
}

///|
test "dae raw cleanup strips nops and dropped pure leaves after any DAE touch" {
  let v128_zero = @lib.Instruction::v128_const(
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  )
  let v128_ones = @lib.Instruction::v128_const(
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
    b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let pure_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let pure_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let param_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let shuffle_low_lanes = @lib.Instruction::i8x16_shuffle(
    @lib.LaneIdx::new(b'\x00'),
    @lib.LaneIdx::new(b'\x01'),
    @lib.LaneIdx::new(b'\x02'),
    @lib.LaneIdx::new(b'\x03'),
    @lib.LaneIdx::new(b'\x04'),
    @lib.LaneIdx::new(b'\x05'),
    @lib.LaneIdx::new(b'\x06'),
    @lib.LaneIdx::new(b'\x07'),
    @lib.LaneIdx::new(b'\x08'),
    @lib.LaneIdx::new(b'\x09'),
    @lib.LaneIdx::new(b'\x0a'),
    @lib.LaneIdx::new(b'\x0b'),
    @lib.LaneIdx::new(b'\x0c'),
    @lib.LaneIdx::new(b'\x0d'),
    @lib.LaneIdx::new(b'\x0e'),
    @lib.LaneIdx::new(b'\x0f'),
  )
  let noisy_body = [
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(9L)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.25)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.5)),
    @lib.Instruction::f64x2_splat(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64_const(@lib.F64(3.5)),
    @lib.Instruction::f64x2_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32x4_shr_u(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i16x8_extend_low_i8x16s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_extadd_pairwise_i16x8u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i16x8_narrow_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i16x8_extmul_low_i8x16s(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_extmul_high_i16x8u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i64x2_extmul_low_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_dot_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_demote_f64x2_zero(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_promote_low_f32x4(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_trunc_sat_f32x4s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32x4_trunc_sat_f64x2u_zero(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_convert_i32x4u(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_convert_low_i32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(16.75)),
    @lib.Instruction::f64_sqrt(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::i32_trunc_sat_f32s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::i32_trunc_f32s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::i32_trunc_f32s(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(42.0)),
    @lib.Instruction::i64_trunc_sat_f64u(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(9.25)),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::f32_max(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(41)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(12)),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::i32_add(),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_mul(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(71)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(72L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(100)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(73)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(74L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(101)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::i32_const(@lib.I32(75)), @lib.Instruction::drop()],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [@lib.Instruction::i64_const(@lib.I64(76L)), @lib.Instruction::drop()],
      Some([]),
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      Some([@lib.Instruction::i32_const(@lib.I32(77)), @lib.Instruction::drop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(102)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [@lib.Instruction::drop()],
      Some([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(78)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
      [],
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64(79L)),
        @lib.Instruction::drop(),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(103)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
      [],
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::select(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::v128_not(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::v128_any_true(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i8x16_bitmask(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f32x4_sqrt(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::f64x2_nearest(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::v128_and(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i32x4_eq(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::f32x4_div(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    shuffle_low_lanes,
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::drop(),
    v128_zero,
    v128_ones,
    v128_zero,
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_is_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(123)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(321)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(654)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(656)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(657)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::any()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(655)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::ref_cast(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(456)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_test(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_test_desc(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_test(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
    @lib.Instruction::i31_get_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_test(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_test_desc(
      true,
      @lib.HeapType::abs(@lib.AbsHeapType::eq()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
    @lib.Instruction::ref_cast(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::i31()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_cast(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(84L)),
    @lib.Instruction::i64_const(@lib.I64(3L)),
    @lib.Instruction::i64_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
    @lib.Instruction::i64_const(@lib.I64(-1L)),
    @lib.Instruction::i64_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(4294967296.0)),
    @lib.Instruction::i32_trunc_f64u(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::select(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i16x8_extend_low_i8x16s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_extadd_pairwise_i16x8u(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::drop(),
    v128_zero,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i16x8_extmul_low_i8x16s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i32x4_dot_i16x8s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::f32x4_demote_f64x2_zero(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::i32x4_trunc_sat_f32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    @lib.Instruction::f64x2_convert_low_i32x4s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    shuffle_low_lanes,
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::v128_load(memarg),
    v128_zero,
    v128_ones,
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ]
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pure_typeidx_block_type, param_typeidx_block_type, pure_void_typeidx_block_type,
        param_void_typeidx_block_type,
      ]),
    )
    .with_table_sec(@lib.TableSec::new([@lib.Table::new(table_type, None)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
      ]),
    )
  let no_touch_result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    false, false,
  ])
  assert_false(no_touch_result.changed)
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    true, false,
  ])
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  assert_eq(result.touched, [true, false])
  let no_return_touched_result = dae_strip_module_nops_and_dropped_pure_leaf_once(
    mod_,
    [true, false],
    return_touched=false,
  )
  assert_true(no_return_touched_result.changed)
  assert_eq(no_return_touched_result.primary_def, 0)
  assert_eq(no_return_touched_result.touched, [])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned0)) = funcs[0]
      let @lib.Func(_, @lib.Expr(cleaned1)) = funcs[1]
      let preserved_trapping = [
        @lib.Instruction::i32_const(@lib.I32(100)),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(101)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(102)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          [@lib.Instruction::drop()],
          Some([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::unreachable_()],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(103)),
        @lib.Instruction::try_table(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(3U)),
          [],
          @lib.Expr::new([@lib.Instruction::drop()]),
        ),
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [],
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::i31_get_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::ref_cast(
          false,
          @lib.HeapType::abs(@lib.AbsHeapType::i31()),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_cast(
          true,
          @lib.HeapType::abs(@lib.AbsHeapType::eq()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new([]),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::i64_const(@lib.I64(-9223372036854775808L)),
        @lib.Instruction::i64_const(@lib.I64(-1L)),
        @lib.Instruction::i64_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::f64_const(@lib.F64(4294967296.0)),
        @lib.Instruction::i32_trunc_f64u(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::select(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(b'\x00')),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i8x16_shl(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        v128_zero,
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::i16x8_extmul_low_i8x16s(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::v128_load(memarg),
        v128_zero,
        v128_ones,
        @lib.Instruction::v128_bitselect(),
        @lib.Instruction::drop(),
        @lib.Instruction::return_(),
      ]
      assert_eq(cleaned0, preserved_trapping)
      assert_eq(cleaned1, preserved_trapping)
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup preserves dropped local get binary expressions" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips local and global self assignments and tees" {
  let same_global_set = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let different_global_set = [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(1U)),
  ]
  let same_global_set_read_drop = [
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let same_global_set_read_drop_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let same_global_set_read_set = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let same_global_set_read_set_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let different_global_set_read = [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ]
  let same_local_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
  let same_local_tee_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let same_local_tee_pure_use_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
  ]
  let same_local_tee_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_tee_used = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_tee_used_cleaned = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let same_local_set_read = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let same_local_set_read_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  ]
  let same_local_tee_set_from_const = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_tee_set_from_const_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let local_tee_drop_from_effect = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let local_tee_drop_from_effect_cleaned = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_drop = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let same_local_set_read_drop_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_set = [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let same_local_set_read_set_cleaned = [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let effect_local_set_read_drop = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
  ]
  let effect_local_set_read_drop_cleaned = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  let different_local_set_read = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]
  let different_local_set = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let different_local_tee_drop = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let different_local_tee_drop_cleaned = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let mod_ = @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              ..same_global_set,
              ..same_local_set,
              ..same_local_tee_drop,
              ..same_local_tee_pure_use_drop,
              ..same_local_tee_set,
              ..same_local_tee_used,
              ..same_local_set_read,
              ..same_local_tee_set_from_const,
              ..local_tee_drop_from_effect,
              ..same_local_set_read_drop,
              ..same_local_set_read_set,
              ..effect_local_set_read_drop,
              ..same_global_set_read_drop,
              ..same_global_set_read_set,
              ..different_global_set_read,
              ..different_local_set_read,
              ..different_global_set,
              ..different_local_set,
              ..different_local_tee_drop,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..same_local_tee_used_cleaned,
          ..same_local_set_read_cleaned,
          ..same_local_tee_set_from_const_cleaned,
          ..local_tee_drop_from_effect_cleaned,
          ..same_local_set_read_drop_cleaned,
          ..same_local_set_read_set_cleaned,
          ..effect_local_set_read_drop_cleaned,
          ..same_global_set_read_drop_cleaned,
          ..same_global_set_read_set_cleaned,
          ..different_global_set_read,
          ..different_local_set_read,
          ..different_global_set,
          ..different_local_set,
          ..different_local_tee_drop_cleaned,
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips live integer constant identities" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_or(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_xor(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shl(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shr_s(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_shr_u(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_rotl(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_rotr(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::i32_and(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_sub(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_shr_u(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::i64_mul(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(-1L)),
            @lib.Instruction::i64_and(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_and(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_xor(),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_mul(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_shl(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_shl(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup canonicalizes live integer zero comparisons" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_eq(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_ne(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_eq(),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_ne(),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i64_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips double eqz from live if conditions" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let then_body = [@lib.Instruction::unreachable_()]
  let mod_ = @lib.Module::new()
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(memarg),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ne(),
        @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ne(),
        @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup canonicalizes live integer and ref self comparisons" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_ne(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_le_s(),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i64_gt_u(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::ref_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::f32_eq(),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::f32_eq(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup folds live integer self binary operations" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_and(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_or(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_xor(),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i64_sub(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_xor(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::f32_sub(),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::f32_sub(),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup folds pure local copy chains" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(41)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(41)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup rewrites dropped local tee pure suffixes to sets" {
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_mul(),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_div_s(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
          @lib.Instruction::return_(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup peels dropped nontrapping wrappers from trapping values" {
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_load(memarg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_load(memarg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_div_s(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::drop(),
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
          @lib.Instruction::ref_as_non_null(),
          @lib.Instruction::ref_test(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::v128_load(memarg),
          @lib.Instruction::i8x16_abs(),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(4)),
          @lib.Instruction::v128_load(memarg),
          @lib.Instruction::v128_const(
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          ),
          @lib.Instruction::i8x16_add(),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_load(memarg),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
        @lib.Instruction::ref_as_non_null(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::v128_load(memarg),
        @lib.Instruction::drop(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value loops" {
  let pure_typeidx_loop_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_loop_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let param_loop = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(6)),
      ]),
    ),
    @lib.Instruction::drop(),
  ]
  let trapping_loop = [
    @lib.Instruction::loop_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([pure_typeidx_loop_type, param_typeidx_loop_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::loop_(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::loop_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              ..param_loop,
              ..trapping_loop,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [..param_loop, ..trapping_loop, @lib.Instruction::return_()],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value ifs" {
  let pure_typeidx_if_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
  )
  let param_typeidx_if_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL))
  let effectful_condition_if = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32(1))],
      Some([@lib.Instruction::i32_const(@lib.I32(2))]),
    ),
    @lib.Instruction::drop(),
  ]
  let effectful_condition_drop = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ]
  let trapping_branch_if = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::unreachable_()],
      Some([@lib.Instruction::i32_const(@lib.I32(3))]),
    ),
    @lib.Instruction::drop(),
  ]
  let param_if = [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(5))],
      Some([@lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(6))]),
    ),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([pure_typeidx_if_type, param_typeidx_if_type]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                [
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ],
                Some([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::if_(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                [@lib.Instruction::i64_const(@lib.I64(8L))],
                Some([@lib.Instruction::i64_const(@lib.I64(9L))]),
              ),
              @lib.Instruction::i64_eqz(),
              @lib.Instruction::drop(),
              ..effectful_condition_if,
              ..trapping_branch_if,
              ..param_if,
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..effectful_condition_drop,
          ..trapping_branch_if,
          ..param_if,
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips dropped pure value try_tables without catches" {
  let pure_typeidx_try_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let param_typeidx_try_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caught_tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
  )
  let param_try = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(6)),
      ]),
    ),
    @lib.Instruction::drop(),
  ]
  let trapping_try = [
    @lib.Instruction::try_table(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [],
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::drop(),
  ]
  let caught_pure_try = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i64()),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Catch::new(@lib.TagIdx::new(0U), @lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(8))]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::i64_const(@lib.I64(9L)),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pure_typeidx_try_type, param_typeidx_try_type, caught_tag_type,
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new(
            [
              @lib.Instruction::try_table(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                [],
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32(40)),
                  @lib.Instruction::i32_const(@lib.I32(2)),
                  @lib.Instruction::i32_add(),
                ]),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::try_table(
                @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
                [],
                @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
              ),
              @lib.Instruction::i32_eqz(),
              @lib.Instruction::drop(),
              ..param_try,
              ..trapping_try,
              caught_pure_try,
              @lib.Instruction::drop(),
              @lib.Instruction::return_(),
            ],
          ),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(
        cleaned,
        [
          ..param_try,
          ..trapping_try,
          caught_pure_try,
          @lib.Instruction::drop(),
          @lib.Instruction::return_(),
        ],
      )
    }
    None => fail("expected rewritten code section")
  }
}

///|
test "dae raw cleanup strips empty zero-result try_tables even with catches" {
  let param_void_typeidx_block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let catching_empty_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(12)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let catching_trapping_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ]),
  )
  let catching_param_body = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(13)),
      @lib.Instruction::try_table(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([]),
      ),
    ]),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([param_void_typeidx_block_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            catching_empty_body,
            catching_trapping_body,
            catching_param_body,
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    )
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [true])
  assert_true(result.changed)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      assert_eq(cleaned, [
        catching_trapping_body,
        catching_param_body,
        @lib.Instruction::return_(),
      ])
    }
    None => fail("expected rewritten code section")
  }
}
