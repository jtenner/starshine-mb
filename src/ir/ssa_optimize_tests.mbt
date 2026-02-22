// ssa_optimize_test.mbt

// ============================================================
// Helper: build a minimal SSACFG for testing
// ============================================================

///|
fn make_single_block_ssa(
  instrs : Array[SSAInstr],
  term : SSATerminator,
  next_value : Int,
) -> SSACFG {
  let bid = BlockId(0)
  let block : SSABlock = { id: bid, phis: [], instrs, terminator: term }
  let blocks : Map[BlockId, SSABlock] = {}
  blocks[bid] = block
  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[bid] = []
  { entry: bid, blocks, preds, param_values: {}, next_value }
}

///|
fn make_multi_block_ssa(
  block_defs : Array[(Int, Array[PhiNode], Array[SSAInstr], SSATerminator)],
  preds_defs : Array[(Int, Array[Int])],
  entry : Int,
  next_value : Int,
) -> SSACFG {
  let blocks : Map[BlockId, SSABlock] = {}
  for def in block_defs {
    let (id, phis, instrs, term) = def
    let bid = BlockId(id)
    blocks[bid] = { id: bid, phis, instrs, terminator: term }
  }
  let preds : Map[BlockId, Array[BlockId]] = {}
  for p in preds_defs {
    let (id, pred_ids) = p
    preds[BlockId(id)] = pred_ids.map(fn(i) { BlockId(i) })
  }
  { entry: BlockId(entry), blocks, preds, param_values: {}, next_value }
}

///|
fn find_assign(ssa : SSACFG, block_id : Int, value_id : Int) -> SSAOp? {
  match ssa.blocks.get(BlockId(block_id)) {
    Some(block) =>
      for instr in block.instrs {
        match instr {
          Assign(SSAValue(v), op) if v == value_id => return Some(op)
          _ => continue
        }
      }
    None => ()
  }
  None
}

///|
fn count_instrs(ssa : SSACFG, block_id : Int) -> Int {
  match ssa.blocks.get(BlockId(block_id)) {
    Some(block) => block.instrs.length()
    None => 0
  }
}

///|
fn get_terminator(ssa : SSACFG, block_id : Int) -> SSATerminator? {
  match ssa.blocks.get(BlockId(block_id)) {
    Some(block) => Some(block.terminator)
    None => None
  }
}

// ============================================================
// Tests: Utility helpers
// ============================================================

///|
test "is_power_of_2_i32 basic" {
  assert_true(is_power_of_2_i32(1))
  assert_true(is_power_of_2_i32(2))
  assert_true(is_power_of_2_i32(4))
  assert_true(is_power_of_2_i32(8))
  assert_true(is_power_of_2_i32(16))
  assert_true(is_power_of_2_i32(1024))
  assert_true(is_power_of_2_i32(1073741824)) // 2^30
}

///|
test "is_power_of_2_i32 non-powers" {
  assert_false(is_power_of_2_i32(0))
  assert_false(is_power_of_2_i32(-1))
  assert_false(is_power_of_2_i32(-2))
  assert_false(is_power_of_2_i32(3))
  assert_false(is_power_of_2_i32(5))
  assert_false(is_power_of_2_i32(6))
  assert_false(is_power_of_2_i32(7))
  assert_false(is_power_of_2_i32(12))
  assert_false(is_power_of_2_i32(100))
}

///|
test "log2_i32" {
  assert_eq(log2_i32(1), 0)
  assert_eq(log2_i32(2), 1)
  assert_eq(log2_i32(4), 2)
  assert_eq(log2_i32(8), 3)
  assert_eq(log2_i32(16), 4)
  assert_eq(log2_i32(1024), 10)
}

///|
test "is_power_of_2_i64 basic" {
  assert_true(is_power_of_2_i64(1L))
  assert_true(is_power_of_2_i64(2L))
  assert_true(is_power_of_2_i64(4L))
  assert_true(is_power_of_2_i64(4294967296L)) // 2^32
  assert_false(is_power_of_2_i64(0L))
  assert_false(is_power_of_2_i64(-1L))
  assert_false(is_power_of_2_i64(3L))
}

///|
test "log2_i64" {
  assert_eq(log2_i64(1L), 0L)
  assert_eq(log2_i64(2L), 1L)
  assert_eq(log2_i64(8L), 3L)
  assert_eq(log2_i64(4294967296L), 32L)
}

///|
test "round_half_to_even_f64 basic" {
  // Round down
  assert_eq(round_half_to_even_f64(2.3), 2.0)
  // Round up
  assert_eq(round_half_to_even_f64(2.7), 3.0)
  // Exact 0.5 rounds to even (2 is even)
  assert_eq(round_half_to_even_f64(2.5), 2.0)
  // Exact 0.5 rounds to even (4 is even, so 3.5 -> 4)
  assert_eq(round_half_to_even_f64(3.5), 4.0)
  // Negative
  assert_eq(round_half_to_even_f64(-2.5), -2.0)
  assert_eq(round_half_to_even_f64(-3.5), -4.0)
  assert_eq(round_half_to_even_f64(-2.3), -2.0)
  assert_eq(round_half_to_even_f64(-2.7), -3.0)
}

///|
test "round_half_to_even_f64 special" {
  assert_true(round_half_to_even_f64(@double.not_a_number).is_nan())
  assert_true(round_half_to_even_f64(@double.infinity).is_inf())
  assert_true(round_half_to_even_f64(@double.neg_infinity).is_inf())
  assert_eq(round_half_to_even_f64(0.0), 0.0)
  assert_eq(round_half_to_even_f64(-0.0), -0.0)
}

///|
test "round_half_to_even_f64 more halves" {
  assert_eq(round_half_to_even_f64(0.5), 0.0)
  assert_eq(round_half_to_even_f64(1.5), 2.0)
  assert_eq(round_half_to_even_f64(4.5), 4.0)
  assert_eq(round_half_to_even_f64(5.5), 6.0)
  assert_eq(round_half_to_even_f64(-0.5), 0.0)
  assert_eq(round_half_to_even_f64(-1.5), -2.0)
}

// ============================================================
// Tests: Literal conversion round-trip
// ============================================================

///|
test "literal_to_op and op_to_literal round-trip" {
  let lits : Array[SSALiteral] = [
    LitI32(0),
    LitI32(42),
    LitI32(-1),
    LitI64(0L),
    LitI64(123456789L),
    LitF32(Float::from_double(3.14)),
    LitF64(2.718281828),
  ]
  for lit in lits {
    let op = literal_to_op(lit)
    let recovered = op_to_literal(op)
    assert_eq(recovered, Some(lit))
  }
}

///|
test "op_to_literal on non-const returns None" {
  let op = SSAOp::Copy(SSAValue(0))
  assert_eq(op_to_literal(op), None)
}

///|
test "is_const_op" {
  assert_true(is_const_op(SSAOp::I32Const(I32(42))))
  assert_true(is_const_op(SSAOp::I64Const(I64(100L))))
  assert_true(is_const_op(SSAOp::F32Const(F32(1.0))))
  assert_true(is_const_op(SSAOp::F64Const(F64(1.0))))
  assert_false(is_const_op(SSAOp::Copy(SSAValue(0))))
}

///|
test "op_to_literal on binary returns None" {
  let op = SSAOp::Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(1))
  assert_eq(op_to_literal(op), None)
}

///|
test "op_to_literal on unary returns None" {
  let op = SSAOp::Unary(UnaryOp::i32_eqz(), SSAValue(0))
  assert_eq(op_to_literal(op), None)
}

// ============================================================
// Tests: Unary constant folding
// ============================================================

///|
test "eval_ssa_unary i32eqz" {
  assert_eq(eval_ssa_unary(UnaryOp::i32_eqz(), LitI32(0)), Some(LitI32(1)))
  assert_eq(eval_ssa_unary(UnaryOp::i32_eqz(), LitI32(1)), Some(LitI32(0)))
  assert_eq(eval_ssa_unary(UnaryOp::i32_eqz(), LitI32(-5)), Some(LitI32(0)))
}

///|
test "eval_ssa_unary i64eqz" {
  assert_eq(eval_ssa_unary(UnaryOp::i64_eqz(), LitI64(0L)), Some(LitI32(1)))
  assert_eq(eval_ssa_unary(UnaryOp::i64_eqz(), LitI64(42L)), Some(LitI32(0)))
}

///|
test "eval_ssa_unary i32clz" {
  assert_eq(eval_ssa_unary(UnaryOp::i32_clz(), LitI32(1)), Some(LitI32(31)))
  assert_eq(eval_ssa_unary(UnaryOp::i32_clz(), LitI32(16)), Some(LitI32(27)))
}

///|
test "eval_ssa_unary i32ctz" {
  assert_eq(eval_ssa_unary(UnaryOp::i32_ctz(), LitI32(1)), Some(LitI32(0)))
  assert_eq(eval_ssa_unary(UnaryOp::i32_ctz(), LitI32(8)), Some(LitI32(3)))
}

///|
test "eval_ssa_unary i32popcnt" {
  assert_eq(eval_ssa_unary(UnaryOp::i32_popcnt(), LitI32(0)), Some(LitI32(0)))
  assert_eq(eval_ssa_unary(UnaryOp::i32_popcnt(), LitI32(7)), Some(LitI32(3)))
  assert_eq(eval_ssa_unary(UnaryOp::i32_popcnt(), LitI32(-1)), Some(LitI32(32)))
}

///|
test "eval_ssa_unary i64clz" {
  assert_eq(eval_ssa_unary(UnaryOp::i64_clz(), LitI64(1L)), Some(LitI64(63L)))
}

///|
test "eval_ssa_unary i64ctz" {
  assert_eq(eval_ssa_unary(UnaryOp::i64_ctz(), LitI64(8L)), Some(LitI64(3L)))
}

///|
test "eval_ssa_unary i64popcnt" {
  assert_eq(eval_ssa_unary(UnaryOp::i64_popcnt(), LitI64(7L)), Some(LitI64(3L)))
}

///|
test "eval_ssa_unary f64neg" {
  assert_eq(eval_ssa_unary(UnaryOp::f64_neg(), LitF64(3.0)), Some(LitF64(-3.0)))
  assert_eq(eval_ssa_unary(UnaryOp::f64_neg(), LitF64(-7.5)), Some(LitF64(7.5)))
}

///|
test "eval_ssa_unary f64abs" {
  assert_eq(eval_ssa_unary(UnaryOp::f64_abs(), LitF64(-5.0)), Some(LitF64(5.0)))
  assert_eq(eval_ssa_unary(UnaryOp::f64_abs(), LitF64(5.0)), Some(LitF64(5.0)))
}

///|
test "eval_ssa_unary f64ceil" {
  assert_eq(eval_ssa_unary(UnaryOp::f64_ceil(), LitF64(2.3)), Some(LitF64(3.0)))
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_ceil(), LitF64(-2.3)),
    Some(LitF64(-2.0)),
  )
}

///|
test "eval_ssa_unary f64floor" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_floor(), LitF64(2.7)),
    Some(LitF64(2.0)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_floor(), LitF64(-2.3)),
    Some(LitF64(-3.0)),
  )
}

///|
test "eval_ssa_unary f64trunc" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_trunc(), LitF64(2.9)),
    Some(LitF64(2.0)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_trunc(), LitF64(-2.9)),
    Some(LitF64(-2.0)),
  )
}

///|
test "eval_ssa_unary f64sqrt" {
  assert_eq(eval_ssa_unary(UnaryOp::f64_sqrt(), LitF64(4.0)), Some(LitF64(2.0)))
  assert_eq(eval_ssa_unary(UnaryOp::f64_sqrt(), LitF64(9.0)), Some(LitF64(3.0)))
}

///|
test "eval_ssa_unary f64nearest" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_nearest(), LitF64(2.5)),
    Some(LitF64(2.0)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_nearest(), LitF64(3.5)),
    Some(LitF64(4.0)),
  )
}

///|
test "eval_ssa_unary f32neg" {
  let f = Float::from_double(3.0)
  assert_eq(eval_ssa_unary(UnaryOp::f32_neg(), LitF32(f)), Some(LitF32(-f)))
}

///|
test "eval_ssa_unary f32abs" {
  let f = Float::from_double(-5.0)
  assert_eq(
    eval_ssa_unary(UnaryOp::f32_abs(), LitF32(f)),
    Some(LitF32(f.abs())),
  )
}

///|
test "eval_ssa_unary f32sqrt" {
  let f = Float::from_double(4.0)
  assert_eq(
    eval_ssa_unary(UnaryOp::f32_sqrt(), LitF32(f)),
    Some(LitF32(f.sqrt())),
  )
}

///|
test "eval_ssa_unary f64promote_f32" {
  let f = Float::from_double(3.0)
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_promote_f32(), LitF32(f)),
    Some(LitF64(f.to_double())),
  )
}

///|
test "eval_ssa_unary f32demote_f64" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f32_demote_f64(), LitF64(3.0)),
    Some(LitF32(Float::from_double(3.0))),
  )
}

///|
test "eval_ssa_unary f64convert_i32s" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_convert_i32s(), LitI32(-42)),
    Some(LitF64(-42.0)),
  )
}

///|
test "eval_ssa_unary f64convert_i32u" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_convert_i32u(), LitI32(42)),
    Some(LitF64(42.0)),
  )
}

///|
test "eval_ssa_unary i32wrap_i64" {
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_wrap_i64(), LitI64(4294967297L)),
    Some(LitI32(1)),
  ) // 2^32 + 1 wraps to 1
}

///|
test "eval_ssa_unary f64convert_i64s" {
  assert_eq(
    eval_ssa_unary(UnaryOp::f64_convert_i64s(), LitI64(100L)),
    Some(LitF64(100.0)),
  )
}

///|
test "eval_ssa_unary i32trunc_f64s" {
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64s(), LitF64(3.7)),
    Some(LitI32(3)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64s(), LitF64(-3.7)),
    Some(LitI32(-3)),
  )
}

///|
test "eval_ssa_unary i64extend_i32 conversions" {
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_extend_i32s(), LitI32(-42)),
    Some(LitI64(-42L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_extend_i32u(), LitI32(-1)),
    Some(LitI64(4294967295L)),
  )
}

///|
test "eval_ssa_unary i64 trunc_f32 handles values beyond i32 width" {
  let big = Float::from_double(3000000000.0)
  let neg_big = Float::from_double(-3000000000.0)
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f32s(), LitF32(big)),
    Some(LitI64(3000000000L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f32s(), LitF32(neg_big)),
    Some(LitI64(-3000000000L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f32u(), LitF32(big)),
    Some(LitI64(3000000000L)),
  )
}

///|
test "eval_ssa_unary i64 trunc_f64 folds signed and unsigned" {
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64s(), LitF64(-42.9)),
    Some(LitI64(-42L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64u(), LitF64(42.9)),
    Some(LitI64(42L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64u(), LitF64(3000000000.0)),
    Some(LitI64(3000000000L)),
  )
}

///|
test "eval_ssa_unary float-to-int trunc returns None on NaN and infinities" {
  let nan32 = Float::from_double(@double.not_a_number)
  let inf32 = Float::from_double(@double.infinity)
  let ninf32 = Float::from_double(@double.neg_infinity)
  let f32_ops : Array[UnaryOp] = [
    UnaryOp::i32_trunc_f32s(),
    UnaryOp::i32_trunc_f32u(),
    UnaryOp::i64_trunc_f32s(),
    UnaryOp::i64_trunc_f32u(),
  ]
  for op in f32_ops {
    assert_eq(eval_ssa_unary(op, LitF32(nan32)), None)
    assert_eq(eval_ssa_unary(op, LitF32(inf32)), None)
    assert_eq(eval_ssa_unary(op, LitF32(ninf32)), None)
  }

  let f64_ops : Array[UnaryOp] = [
    UnaryOp::i32_trunc_f64s(),
    UnaryOp::i32_trunc_f64u(),
    UnaryOp::i64_trunc_f64s(),
    UnaryOp::i64_trunc_f64u(),
  ]
  for op in f64_ops {
    assert_eq(eval_ssa_unary(op, LitF64(@double.not_a_number)), None)
    assert_eq(eval_ssa_unary(op, LitF64(@double.infinity)), None)
    assert_eq(eval_ssa_unary(op, LitF64(@double.neg_infinity)), None)
  }
}

///|
test "eval_ssa_unary float-to-int trunc bound and trap parity checks" {
  // Signed i32 bounds: [-2^31, 2^31)
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64s(), LitF64(-2147483648.0)),
    Some(LitI32(-2147483648)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64s(), LitF64(2147483647.0)),
    Some(LitI32(2147483647)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64s(), LitF64(2147483648.0)),
    None,
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64s(), LitF64(-2147483649.0)),
    None,
  )

  // Unsigned i32 bounds: trunc can map (-1, 0) to 0.
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64u(), LitF64(-0.9)),
    Some(LitI32(0)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64u(), LitF64(4294967295.0)),
    Some(LitI32(-1)),
  )
  assert_eq(eval_ssa_unary(UnaryOp::i32_trunc_f64u(), LitF64(-1.0)), None)
  assert_eq(
    eval_ssa_unary(UnaryOp::i32_trunc_f64u(), LitF64(4294967296.0)),
    None,
  )

  // Signed i64 bounds: [-2^63, 2^63)
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64s(), LitF64(-9223372036854775808.0)),
    Some(LitI64(-9223372036854775808L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64s(), LitF64(9007199254740991.0)),
    Some(LitI64(9007199254740991L)),
  )
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64s(), LitF64(9223372036854775808.0)),
    None,
  )

  // Unsigned i64 bounds: [0, 2^64), with (-1, 0) truncating to 0.
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64u(), LitF64(-0.7)),
    Some(LitI64(0L)),
  )
  assert_eq(eval_ssa_unary(UnaryOp::i64_trunc_f64u(), LitF64(-1.0)), None)
  assert_eq(
    eval_ssa_unary(UnaryOp::i64_trunc_f64u(), LitF64(18446744073709551616.0)),
    None,
  )
}

///|
test "eval_ssa_unary type mismatch returns None" {
  // Applying i32 op to i64 literal
  assert_eq(eval_ssa_unary(UnaryOp::i32_eqz(), LitI64(0L)), None)
}

///|
test "eval_ssa_unary i64eqz on i32 returns None" {
  assert_eq(eval_ssa_unary(UnaryOp::i64_eqz(), LitI32(0)), None)
}

///|
test "eval_ssa_unary f64neg on i32 returns None" {
  assert_eq(eval_ssa_unary(UnaryOp::f64_neg(), LitI32(0)), None)
}

// ============================================================
// Tests: Binary constant folding
// ============================================================

///|
test "eval_ssa_binary i32 add" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_add(), LitI32(3), LitI32(4)),
    Some(LitI32(7)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_add(), LitI32(-1), LitI32(1)),
    Some(LitI32(0)),
  )
}

///|
test "eval_ssa_binary i32 sub" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_sub(), LitI32(10), LitI32(3)),
    Some(LitI32(7)),
  )
}

///|
test "eval_ssa_binary i32 mul" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_mul(), LitI32(6), LitI32(7)),
    Some(LitI32(42)),
  )
}

///|
test "eval_ssa_binary i32 div signed" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_div_s(), LitI32(10), LitI32(3)),
    Some(LitI32(3)),
  )
  assert_eq(eval_ssa_binary(BinaryOp::i32_div_s(), LitI32(10), LitI32(0)), None)
}

///|
test "eval_ssa_binary i32 div unsigned" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_div_u(), LitI32(10), LitI32(3)),
    Some(LitI32(3)),
  )
  assert_eq(eval_ssa_binary(BinaryOp::i32_div_u(), LitI32(10), LitI32(0)), None)
}

///|
test "eval_ssa_binary i32 rem signed" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_rem_s(), LitI32(10), LitI32(3)),
    Some(LitI32(1)),
  )
  assert_eq(eval_ssa_binary(BinaryOp::i32_rem_s(), LitI32(10), LitI32(0)), None)
}

///|
test "eval_ssa_binary i32 rem unsigned" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_rem_u(), LitI32(10), LitI32(3)),
    Some(LitI32(1)),
  )
  assert_eq(eval_ssa_binary(BinaryOp::i32_rem_u(), LitI32(10), LitI32(0)), None)
}

///|
test "eval_ssa_binary i32 bitwise" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_and(), LitI32(0xFF), LitI32(0x0F)),
    Some(LitI32(0x0F)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_or(), LitI32(0xF0), LitI32(0x0F)),
    Some(LitI32(0xFF)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_xor(), LitI32(0xFF), LitI32(0xFF)),
    Some(LitI32(0)),
  )
}

///|
test "eval_ssa_binary i32 shifts" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_shl(), LitI32(1), LitI32(4)),
    Some(LitI32(16)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_shr_s(), LitI32(16), LitI32(2)),
    Some(LitI32(4)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_shl(), LitI32(1), LitI32(33)),
    Some(LitI32(2)),
  ) // 33 & 31 = 1
}

///|
test "eval_ssa_binary i32 shr_u" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_shr_u(), LitI32(-1), LitI32(1)),
    Some(LitI32(0x7FFFFFFF)),
  )
}

///|
test "eval_ssa_binary i32 comparisons" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_eq(), LitI32(5), LitI32(5)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_eq(), LitI32(5), LitI32(6)),
    Some(LitI32(0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_ne(), LitI32(5), LitI32(6)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_lt_s(), LitI32(3), LitI32(5)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_lt_s(), LitI32(5), LitI32(3)),
    Some(LitI32(0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_ge_s(), LitI32(5), LitI32(5)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary i32 unsigned comparisons" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_lt_u(), LitI32(3), LitI32(5)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_le_u(), LitI32(5), LitI32(5)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_lt_u(), LitI32(5), LitI32(5)),
    Some(LitI32(0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_lt_u(), LitI32(5), LitI32(3)),
    Some(LitI32(0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_le_u(), LitI32(5), LitI32(5)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_gt_u(), LitI32(5), LitI32(3)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_ge_u(), LitI32(5), LitI32(5)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary i32 le_s / gt_s" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_le_s(), LitI32(3), LitI32(5)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_gt_s(), LitI32(5), LitI32(3)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary i32 rotl/rotr" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_rotl(), LitI32(0x80000001), LitI32(1)),
    Some(LitI32(3)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_rotr(), LitI32(42), LitI32(0)),
    Some(LitI32(42)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i32_rotl(), LitI32(42), LitI32(0)),
    Some(LitI32(42)),
  )
}

///|
test "eval_ssa_binary i64 arithmetic" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_add(), LitI64(100L), LitI64(200L)),
    Some(LitI64(300L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_sub(), LitI64(300L), LitI64(100L)),
    Some(LitI64(200L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_mul(), LitI64(6L), LitI64(7L)),
    Some(LitI64(42L)),
  )
}

///|
test "eval_ssa_binary i64 div/rem" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_div_s(), LitI64(10L), LitI64(3L)),
    Some(LitI64(3L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_div_s(), LitI64(10L), LitI64(0L)),
    None,
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_div_u(), LitI64(10L), LitI64(3L)),
    Some(LitI64(3L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_div_u(), LitI64(10L), LitI64(0L)),
    None,
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_rem_s(), LitI64(10L), LitI64(3L)),
    Some(LitI64(1L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_rem_s(), LitI64(10L), LitI64(0L)),
    None,
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_rem_u(), LitI64(10L), LitI64(3L)),
    Some(LitI64(1L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_rem_u(), LitI64(10L), LitI64(0L)),
    None,
  )
}

///|
test "eval_ssa_binary i64 bitwise" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_and(), LitI64(0xFFL), LitI64(0x0FL)),
    Some(LitI64(0x0FL)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_or(), LitI64(0xF0L), LitI64(0x0FL)),
    Some(LitI64(0xFFL)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_xor(), LitI64(0xFFL), LitI64(0xFFL)),
    Some(LitI64(0L)),
  )
}

///|
test "eval_ssa_binary i64 shifts" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_shl(), LitI64(1L), LitI64(4L)),
    Some(LitI64(16L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_shr_s(), LitI64(16L), LitI64(2L)),
    Some(LitI64(4L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_shr_u(), LitI64(-1L), LitI64(1L)),
    Some(LitI64(0x7FFFFFFFFFFFFFFFL)),
  )
}

///|
test "eval_ssa_binary i64 rotl/rotr" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_rotl(), LitI64(42L), LitI64(0L)),
    Some(LitI64(42L)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_rotr(), LitI64(42L), LitI64(0L)),
    Some(LitI64(42L)),
  )
}

///|
test "eval_ssa_binary i64 comparisons" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_eq(), LitI64(42L), LitI64(42L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_ne(), LitI64(42L), LitI64(43L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_lt_s(), LitI64(1L), LitI64(2L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_le_s(), LitI64(2L), LitI64(2L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_gt_s(), LitI64(3L), LitI64(2L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_ge_s(), LitI64(2L), LitI64(2L)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary i64 unsigned comparisons" {
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_lt_u(), LitI64(1L), LitI64(2L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_le_u(), LitI64(2L), LitI64(2L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_gt_u(), LitI64(3L), LitI64(2L)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::i64_ge_u(), LitI64(2L), LitI64(2L)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary f32 arithmetic" {
  let a = Float::from_double(1.5)
  let b = Float::from_double(2.5)
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_add(), LitF32(a), LitF32(b)),
    Some(LitF32(a + b)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_sub(), LitF32(b), LitF32(a)),
    Some(LitF32(b - a)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_mul(), LitF32(a), LitF32(b)),
    Some(LitF32(a * b)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_div(), LitF32(b), LitF32(a)),
    Some(LitF32(b / a)),
  )
}

///|
test "eval_ssa_binary f32 comparisons" {
  let a = Float::from_double(1.0)
  let b = Float::from_double(2.0)
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_eq(), LitF32(a), LitF32(a)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_ne(), LitF32(a), LitF32(b)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_lt(), LitF32(a), LitF32(b)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_le(), LitF32(a), LitF32(a)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_gt(), LitF32(b), LitF32(a)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_ge(), LitF32(b), LitF32(b)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary f64 arithmetic" {
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_add(), LitF64(1.5), LitF64(2.5)),
    Some(LitF64(4.0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_sub(), LitF64(5.0), LitF64(3.0)),
    Some(LitF64(2.0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_mul(), LitF64(2.0), LitF64(3.0)),
    Some(LitF64(6.0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_div(), LitF64(6.0), LitF64(2.0)),
    Some(LitF64(3.0)),
  )
}

///|
test "eval_ssa_binary f64 min/max" {
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_min(), LitF64(1.0), LitF64(2.0)),
    Some(LitF64(1.0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_max(), LitF64(1.0), LitF64(2.0)),
    Some(LitF64(2.0)),
  )
  // NaN propagation
  match
    eval_ssa_binary(
      BinaryOp::f64_min(),
      LitF64(@double.not_a_number),
      LitF64(1.0),
    ) {
    Some(LitF64(r)) => assert_true(r.is_nan())
    _ => fail("Expected NaN result")
  }
}

///|
test "eval_ssa_binary f32 min/max" {
  let a = Float::from_double(1.0)
  let b = Float::from_double(2.0)
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_min(), LitF32(a), LitF32(b)),
    Some(LitF32(a)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_max(), LitF32(a), LitF32(b)),
    Some(LitF32(b)),
  )
}

///|
test "eval_ssa_binary f64 copysign" {
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_copysign(), LitF64(5.0), LitF64(-1.0)),
    Some(LitF64(-5.0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_copysign(), LitF64(-5.0), LitF64(1.0)),
    Some(LitF64(5.0)),
  )
}

///|
test "eval_ssa_binary f32 copysign" {
  let pos = Float::from_double(5.0)
  let neg_sign = Float::from_double(-1.0)
  assert_eq(
    eval_ssa_binary(BinaryOp::f32_copysign(), LitF32(pos), LitF32(neg_sign)),
    Some(LitF32(-pos)),
  )
}

///|
test "eval_ssa_binary f64 comparisons" {
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_eq(), LitF64(1.0), LitF64(1.0)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_ne(), LitF64(1.0), LitF64(2.0)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_lt(), LitF64(1.0), LitF64(2.0)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_le(), LitF64(2.0), LitF64(2.0)),
    Some(LitI32(1)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_gt(), LitF64(1.0), LitF64(2.0)),
    Some(LitI32(0)),
  )
  assert_eq(
    eval_ssa_binary(BinaryOp::f64_ge(), LitF64(2.0), LitF64(2.0)),
    Some(LitI32(1)),
  )
}

///|
test "eval_ssa_binary type mismatch returns None" {
  assert_eq(eval_ssa_binary(BinaryOp::i32_add(), LitI64(1L), LitI64(2L)), None)
  assert_eq(eval_ssa_binary(BinaryOp::i32_add(), LitI32(1), LitI64(2L)), None)
  assert_eq(eval_ssa_binary(BinaryOp::i64_add(), LitI32(1), LitI32(2)), None)
}
// ============================================================
// Tests: is_associative_binop
// ============================================================

///|
test "is_associative_binop" {
  assert_true(is_associative_binop(BinaryOp::i32_add()))
  assert_true(is_associative_binop(BinaryOp::i32_mul()))
  assert_true(is_associative_binop(BinaryOp::i32_and()))
  assert_true(is_associative_binop(BinaryOp::i32_or()))
  assert_true(is_associative_binop(BinaryOp::i32_xor()))
  assert_true(is_associative_binop(BinaryOp::i64_add()))
  assert_true(is_associative_binop(BinaryOp::i64_mul()))
  assert_true(is_associative_binop(BinaryOp::i64_and()))
  assert_true(is_associative_binop(BinaryOp::i64_or()))
  assert_true(is_associative_binop(BinaryOp::i64_xor()))
  assert_false(is_associative_binop(BinaryOp::i32_sub()))
  assert_false(is_associative_binop(BinaryOp::i32_div_s()))
  assert_false(is_associative_binop(BinaryOp::f64_add()))
  assert_false(is_associative_binop(BinaryOp::i64_sub()))
  assert_false(is_associative_binop(BinaryOp::i32_shl()))
  assert_false(is_associative_binop(BinaryOp::i32_eq()))
}

// ============================================================
// Tests: has_side_effects
// ============================================================

///|
test "has_side_effects pure ops" {
  assert_false(has_side_effects(I32Const(I32(0))))
  assert_false(has_side_effects(I64Const(I64(0L))))
  assert_false(has_side_effects(F32Const(F32(0.0))))
  assert_false(has_side_effects(F64Const(F64(0.0))))
  assert_false(has_side_effects(Copy(SSAValue(0))))
  assert_false(
    has_side_effects(Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(1))),
  )
  assert_false(has_side_effects(Unary(UnaryOp::i32_eqz(), SSAValue(0))))
  assert_false(has_side_effects(RefIsNull(SSAValue(0))))
  assert_false(has_side_effects(RefEq(SSAValue(0), SSAValue(1))))
}

///|
test "has_side_effects effectful ops" {
  assert_true(
    has_side_effects(
      Store(
        StoreOp::i32_store(),
        MemArg::new(U32(0), None, U64(0)),
        SSAValue(0),
        SSAValue(1),
      ),
    ),
  )
  assert_true(has_side_effects(GlobalSet(GlobalIdx::new(0U), SSAValue(0))))
  assert_true(has_side_effects(Call(FuncIdx::new(0U), [SSAValue(0)])))
  assert_true(has_side_effects(DataDrop(DataIdx::new(0U))))
  assert_true(has_side_effects(ElemDrop(ElemIdx::new(0U))))
  assert_true(has_side_effects(MemoryGrow(MemIdx::new(0U), SSAValue(0))))
}

///|
test "has_side_effects loads are side-effecting (may trap)" {
  assert_true(
    has_side_effects(
      Load(LoadOp::i32_load(), MemArg::new(U32(0), None, U64(0)), SSAValue(0)),
    ),
  )
}

///|
test "has_side_effects table operations" {
  assert_true(
    has_side_effects(TableSet(TableIdx::new(0U), SSAValue(0), SSAValue(1))),
  )
  assert_true(
    has_side_effects(
      SSAOp::TableGrow(TableIdx::new(0U), SSAValue(0), SSAValue(1)),
    ),
  )
}

///|
test "has_side_effects struct/array mutations" {
  assert_true(
    has_side_effects(
      SSAOp::StructSet(TypeIdx::new(0), U32(0), SSAValue(0), SSAValue(1)),
    ),
  )
  assert_true(
    has_side_effects(
      SSAOp::ArraySet(TypeIdx::new(0U), SSAValue(0), SSAValue(1), SSAValue(2)),
    ),
  )
}

///|
test "has_side_effects call_indirect" {
  assert_true(
    has_side_effects(
      SSAOp::CallIndirect(
        TypeIdx::new(0U),
        TableIdx::new(0U),
        [SSAValue(0)],
        SSAValue(1),
      ),
    ),
  )
}

///|
test "has_side_effects call_ref" {
  assert_true(
    has_side_effects(
      SSAOp::CallRef(TypeIdx::new(0U), [SSAValue(0)], SSAValue(1)),
    ),
  )
}
// ============================================================
// Tests: SSAOptCtx basics
// ============================================================

///|
test "SSAOptCtx resolve with no replacements" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(42)))],
    SSATerminator::Return([SSAValue(0)]),
    1,
  )
  let ctx = SSAOptCtx::new(ssa)
  assert_eq(ctx.resolve(SSAValue(0)), SSAValue(0))
}

///|
test "SSAOptCtx resolve with chain" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(42))),
      Assign(SSAValue(1), Copy(SSAValue(0))),
      Assign(SSAValue(2), Copy(SSAValue(1))),
    ],
    SSATerminator::Return([SSAValue(2)]),
    3,
  )
  let ctx = SSAOptCtx::new(ssa)
  ctx.replacements[SSAValue(2)] = SSAValue(1)
  ctx.replacements[SSAValue(1)] = SSAValue(0)
  assert_eq(ctx.resolve(SSAValue(2)), SSAValue(0))
}

///|
test "SSAOptCtx resolve self-loop terminates" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(42)))],
    SSATerminator::Return([SSAValue(0)]),
    1,
  )
  let ctx = SSAOptCtx::new(ssa)
  // Self-referencing replacement — should not infinite loop
  ctx.replacements[SSAValue(0)] = SSAValue(0)
  assert_eq(ctx.resolve(SSAValue(0)), SSAValue(0))
}

///|
test "SSAOptCtx get_const" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(99)))],
    SSATerminator::Return([SSAValue(0)]),
    1,
  )
  let ctx = SSAOptCtx::new(ssa)
  assert_eq(ctx.get_const(SSAValue(0)), Some(LitI32(99)))
}

///|
test "SSAOptCtx get_const non-const returns None" {
  let ssa = make_single_block_ssa(
    [
      Assign(
        SSAValue(0),
        Binary(BinaryOp::i32_add(), SSAValue(10), SSAValue(11)),
      ),
    ],
    SSATerminator::Return([SSAValue(0)]),
    1,
  )
  let ctx = SSAOptCtx::new(ssa)
  assert_eq(ctx.get_const(SSAValue(0)), None)
}

///|
test "SSAOptCtx get_const through replacement" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(77))),
      Assign(SSAValue(1), Copy(SSAValue(0))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    2,
  )
  let ctx = SSAOptCtx::new(ssa)
  ctx.replacements[SSAValue(1)] = SSAValue(0)
  assert_eq(ctx.get_const(SSAValue(1)), Some(LitI32(77)))
}

///|
test "SSAOptCtx get_const undefined value returns None" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 0)
  let ctx = SSAOptCtx::new(ssa)
  assert_eq(ctx.get_const(SSAValue(99)), None)
}

///|
test "SSAOptCtx fresh_value and make_const" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 5)
  let ctx = SSAOptCtx::new(ssa)
  let v = ctx.fresh_value()
  assert_eq(v, SSAValue(5))
  assert_eq(ctx.next_value, 6)
  let cv = ctx.make_const(LitI32(77))
  assert_eq(cv, SSAValue(6))
  assert_eq(ctx.get_const(cv), Some(LitI32(77)))
}

///|
test "SSAOptCtx make_const i64" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 0)
  let ctx = SSAOptCtx::new(ssa)
  let cv = ctx.make_const(LitI64(999L))
  assert_eq(ctx.get_const(cv), Some(LitI64(999L)))
}

///|
test "SSAOptCtx make_const f64" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 0)
  let ctx = SSAOptCtx::new(ssa)
  let cv = ctx.make_const(LitF64(3.14))
  assert_eq(ctx.get_const(cv), Some(LitF64(3.14)))
}

///|
test "SSAOptCtx replace marks changed" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 2)
  let ctx = SSAOptCtx::new(ssa)
  assert_false(ctx.changed)
  ctx.replace(SSAValue(0), SSAValue(1))
  assert_true(ctx.changed)
}

// ============================================================
// Tests: Full optimize_ssa — constant folding
// ============================================================

///|
test "optimize_ssa constant folds i32 add" {
  // v0 = 3; v1 = 4; v2 = v0 + v1; return v2
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(3))),
      Assign(SSAValue(1), I32Const(I32(4))),
      Assign(SSAValue(2), Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(1))),
    ],
    SSATerminator::Return([SSAValue(2)]),
    3,
  )
  let result = ssa.optimize()
  // The return should now reference a constant 7
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      assert_eq(vs.length(), 1)
      let rv = vs[0]
      // Find the defining instruction for the return value
      let block = result.blocks[BlockId(0)]
      let mut found_7 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(7))) if v == rv => found_7 = true
          _ => continue
        }
      }
      assert_true(found_7)
    }
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa constant folds unary i32eqz" {
  // v0 = 0; v1 = eqz(v0); return v1
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(0))),
      Assign(SSAValue(1), Unary(UnaryOp::i32_eqz(), SSAValue(0))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    2,
  )
  let result = ssa.optimize()
  // Should fold to constant 1
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_1 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(1))) if v == rv => found_1 = true
          _ => continue
        }
      }
      assert_true(found_1)
    }
    _ => fail("Expected Return terminator")
  }
}

// ============================================================
// Tests: Copy propagation
// ============================================================

///|
test "optimize_ssa copy propagation" {
  // v0 = 42; v1 = copy(v0); return v1
  // Should simplify to returning v0
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(42))),
      Assign(SSAValue(1), Copy(SSAValue(0))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    2,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      assert_eq(vs.length(), 1)
      // The return value should reference v0 directly
      assert_eq(vs[0], SSAValue(0))
    }
    _ => fail("Expected Return terminator")
  }
}

// ============================================================
// Tests: Algebraic simplification
// ============================================================

///|
test "optimize_ssa x + 0 = x" {
  // v0 = param; v1 = 0; v2 = v0 + v1; return v2
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(0))),
      Assign(
        SSAValue(1),
        Binary(
          BinaryOp::i32_add(),
          SSAValue(10), // some non-const value
          SSAValue(0),
        ),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) =>
      // Should be simplified to SSAValue(10)
      assert_eq(vs[0], SSAValue(10))
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa x * 1 = x (semantic)" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(1))),
      Assign(SSAValue(1), I32Const(I32(10))),
      Assign(SSAValue(2), Binary(BinaryOp::i32_mul(), SSAValue(0), SSAValue(1))),
    ],
    SSATerminator::Return([SSAValue(2)]),
    3,
  )
  let result = ssa.optimize()
  let rv = match get_terminator(result, 0) {
    Some(Return(vs)) => vs[0]
    _ => fail("Expected Return")
  }
  match find_assign(result, 0, rv.0) {
    Some(I32Const(I32(10))) => ()
    _ => fail("Expected constant 10")
  }
}

///|
test "optimize_ssa x * 0 = 0" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(0))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_mul(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_0 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(0))) if v == rv => found_0 = true
          _ => continue
        }
      }
      assert_true(found_0)
    }
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa x & -1 = x" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(-1))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_and(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(10))
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa x ^ x = 0" {
  let ssa = make_single_block_ssa(
    [
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_xor(), SSAValue(10), SSAValue(10)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_0 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(0))) if v == rv => found_0 = true
          _ => continue
        }
      }
      assert_true(found_0)
    }
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa x - x = 0" {
  let ssa = make_single_block_ssa(
    [
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_sub(), SSAValue(10), SSAValue(10)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_0 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(0))) if v == rv => found_0 = true
          _ => continue
        }
      }
      assert_true(found_0)
    }
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa x == x = 1" {
  let ssa = make_single_block_ssa(
    [
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_eq(), SSAValue(10), SSAValue(10)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_1 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(1))) if v == rv => found_1 = true
          _ => continue
        }
      }
      assert_true(found_1)
    }
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa x < x = 0" {
  let ssa = make_single_block_ssa(
    [
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_lt_s(), SSAValue(10), SSAValue(10)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_0 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(0))) if v == rv => found_0 = true
          _ => continue
        }
      }
      assert_true(found_0)
    }
    _ => fail("Expected Return terminator")
  }
}

// ============================================================
// Tests: Strength reduction
// ============================================================

///|
test "optimize_ssa mul by power of 2 becomes shl" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(8))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_mul(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  let rv = match get_terminator(result, 0) {
    Some(Return(vs)) => vs[0]
    _ => fail("Expected Return terminator")
  }
  match find_assign(result, 0, rv.0) {
    Some(Binary(op, left, _)) => {
      assert_eq(op, BinaryOp::i32_shl())
      assert_eq(left, SSAValue(10))
      // optional: check shift amount == 3
    }
    a => fail("Expected shift-left instruction, received: \{a}")
  }
}

///|
test "optimize_ssa div_u by power of 2 becomes shr_u" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(4))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_div_u(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match find_assign(result, 0, 1) {
    Some(Binary(op, left, _)) => {
      assert_eq(op, BinaryOp::i32_shr_u())
      assert_eq(left, SSAValue(10))
    }
    _ => fail("Expected shr_u instruction")
  }
}

///|
test "optimize_ssa rem_u by power of 2 becomes and" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(16))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_rem_u(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match find_assign(result, 0, 1) {
    Some(Binary(op, left, _)) => {
      assert_eq(op, BinaryOp::i32_and())
      assert_eq(left, SSAValue(10))
    }
    _ => fail("Expected and instruction")
  }
}

// ============================================================
// Tests: Select optimization
// ============================================================

///|
test "optimize_ssa select with const true" {
  // v0 = 1 (cond); select(v0, v10, v11) => v10
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(1))),
      Assign(SSAValue(1), Select(None, SSAValue(0), SSAValue(10), SSAValue(11))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(10))
    _ => fail("Expected Return terminator")
  }
}

///|
test "optimize_ssa select with const false" {
  // v0 = 0 (cond); select(v0, v10, v11) => v11
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(0))),
      Assign(SSAValue(1), Select(None, SSAValue(0), SSAValue(10), SSAValue(11))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    20,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(11))
    _ => fail("Expected Return terminator")
  }
}

// ============================================================
// Tests: Terminator optimization
// ============================================================

///|
test "optimize_ssa BrIf with const true becomes Br" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(1)))],
    SSATerminator::BrIf(SSAValue(0), BlockId(1), BlockId(2)),
    1,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Br(bid)) => assert_eq(bid, BlockId(1))
    _ => fail("Expected unconditional Br to block 1")
  }
}

///|
test "optimize_ssa BrIf with const false becomes Br" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(0)))],
    SSATerminator::BrIf(SSAValue(0), BlockId(1), BlockId(2)),
    1,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Br(bid)) => assert_eq(bid, BlockId(2))
    _ => fail("Expected unconditional Br to block 2")
  }
}

///|
test "optimize_ssa BrTable with const index" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(1)))],
    SSATerminator::BrTable(
      SSAValue(0),
      [BlockId(10), BlockId(11), BlockId(12)],
      BlockId(99),
    ),
    1,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Br(bid)) => assert_eq(bid, BlockId(11))
    _ => fail("Expected unconditional Br to block 11")
  }
}

///|
test "optimize_ssa BrTable with out-of-range index goes to default" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(5)))],
    SSATerminator::BrTable(SSAValue(0), [BlockId(10), BlockId(11)], BlockId(99)),
    1,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Br(bid)) => assert_eq(bid, BlockId(99))
    _ => fail("Expected unconditional Br to default block 99")
  }
}

// ============================================================
// Tests: DCE (dead code elimination)
// ============================================================

///|
test "optimize_ssa removes dead pure instructions" {
  // v0 = 42 (dead, not used by return)
  // v1 = 99; return v1
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(42))),
      Assign(SSAValue(1), I32Const(I32(99))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    2,
  )
  let result = ssa.optimize()
  let block = result.blocks[BlockId(0)]
  // v0 should be removed, only v1 remains
  let mut has_42 = false
  let mut has_99 = false
  for instr in block.instrs {
    match instr {
      Assign(_, I32Const(I32(42))) => has_42 = true
      Assign(_, I32Const(I32(99))) => has_99 = true
      _ => continue
    }
  }
  assert_false(has_42)
  assert_true(has_99)
}

///|
test "optimize_ssa keeps side-effecting dead instructions" {
  // v0 = call f() (side effect, result unused); return ()
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), Call(FuncIdx::new(0U), []))],
    SSATerminator::Return([]),
    1,
  )
  let result = ssa.optimize()
  let block = result.blocks[BlockId(0)]
  // Call should be kept even though result is unused
  assert_eq(block.instrs.length(), 1)
}

///|
test "optimize_ssa keeps Effect instructions" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(0))),
      Effect(GlobalSet(GlobalIdx::new(0U), SSAValue(0))),
    ],
    SSATerminator::Return([]),
    1,
  )
  let result = ssa.optimize()
  let block = result.blocks[BlockId(0)]
  let mut has_effect = false
  for instr in block.instrs {
    match instr {
      Effect(_) => has_effect = true
      _ => continue
    }
  }
  assert_true(has_effect)
}

// ============================================================
// Tests: Phi simplification
// ============================================================

///|
test "optimize_ssa simplifies trivial phi" {
  // Block 0: br block1
  // Block 1: phi(v2) = [block0 -> v0, block2 -> v0]; return v2
  // Block 2: br block1  (back edge)
  // All phi args are the same v0, so phi should be eliminated
  let phi : PhiNode = {
    local_idx: LocalIdx::new(0U),
    result: SSAValue(2),
    args: {
      let m : Map[BlockId, SSAValue] = {}
      m[BlockId(0)] = SSAValue(0)
      m[BlockId(2)] = SSAValue(0)
      m
    },
  }
  let ssa = make_multi_block_ssa(
    [
      (0, [], [], SSATerminator::Br(BlockId(1))),
      (1, [phi], [], SSATerminator::Return([SSAValue(2)])),
      (2, [], [], SSATerminator::Br(BlockId(1))),
    ],
    [(0, []), (1, [0, 2]), (2, [1])],
    0,
    3,
  )
  let result = ssa.optimize()
  // Return should reference v0 directly, phi eliminated
  match get_terminator(result, 1) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(0))
    _ => fail("Expected Return terminator in block 1")
  }
}

///|
test "optimize_ssa rewrites phi uses across atomic table array call_ref families" {
  let memarg = MemArg::new(U32(0), None, U64(0))
  let phi : PhiNode = {
    local_idx: LocalIdx::new(0U),
    result: SSAValue(2),
    args: {
      let m : Map[BlockId, SSAValue] = {}
      m[BlockId(0)] = SSAValue(0)
      m[BlockId(2)] = SSAValue(0)
      m
    },
  }
  let ssa = make_multi_block_ssa(
    [
      (0, [], [], SSATerminator::Br(BlockId(1))),
      (
        1,
        [phi],
        [
          Assign(
            SSAValue(3),
            SSAOp::AtomicRmw(
              AtomicRmwOp::i32_add(),
              memarg,
              SSAValue(2),
              SSAValue(2),
            ),
          ),
          Effect(SSAOp::TableSet(TableIdx::new(0U), SSAValue(2), SSAValue(2))),
          Effect(
            SSAOp::ArraySet(
              TypeIdx::new(0U),
              SSAValue(2),
              SSAValue(2),
              SSAValue(2),
            ),
          ),
          Assign(
            SSAValue(4),
            SSAOp::CallRef(TypeIdx::new(0U), [SSAValue(2)], SSAValue(2)),
          ),
        ],
        SSATerminator::ReturnCallRef(
          TypeIdx::new(0U),
          [SSAValue(4), SSAValue(2)],
          SSAValue(2),
        ),
      ),
      (2, [], [], SSATerminator::Br(BlockId(1))),
    ],
    [(0, []), (1, [0, 2]), (2, [1])],
    0,
    5,
  )

  let result = ssa.optimize()
  let block = result.blocks[BlockId(1)]
  assert_eq(block.phis.length(), 0)

  let mut saw_atomic = false
  let mut saw_table = false
  let mut saw_array = false
  let mut saw_call_ref = false
  for instr in block.instrs {
    match instr {
      Assign(_, SSAOp::AtomicRmw(_, _, addr, value)) => {
        assert_eq(addr, SSAValue(0))
        assert_eq(value, SSAValue(0))
        saw_atomic = true
      }
      Effect(SSAOp::TableSet(_, idx, value)) => {
        assert_eq(idx, SSAValue(0))
        assert_eq(value, SSAValue(0))
        saw_table = true
      }
      Effect(SSAOp::ArraySet(_, arr, idx, value)) => {
        assert_eq(arr, SSAValue(0))
        assert_eq(idx, SSAValue(0))
        assert_eq(value, SSAValue(0))
        saw_array = true
      }
      Assign(_, SSAOp::CallRef(_, args, func)) => {
        assert_eq(args.length(), 1)
        assert_eq(args[0], SSAValue(0))
        assert_eq(func, SSAValue(0))
        saw_call_ref = true
      }
      _ => ()
    }
  }
  assert_true(saw_atomic)
  assert_true(saw_table)
  assert_true(saw_array)
  assert_true(saw_call_ref)

  match block.terminator {
    SSATerminator::ReturnCallRef(_, args, func) => {
      assert_eq(args.length(), 2)
      assert_eq(args[1], SSAValue(0))
      assert_eq(func, SSAValue(0))
    }
    _ => fail("Expected ReturnCallRef terminator")
  }
}

// ============================================================
// Tests: Multi-iteration convergence
// ============================================================

///|
test "optimize_ssa cascading constant fold" {
  // v0 = 2; v1 = 3; v2 = v0 + v1; v3 = 4; v4 = v2 * v3
  // Should fold to: v4 = 20
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(2))),
      Assign(SSAValue(1), I32Const(I32(3))),
      Assign(SSAValue(2), Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(1))),
      Assign(SSAValue(3), I32Const(I32(4))),
      Assign(SSAValue(4), Binary(BinaryOp::i32_mul(), SSAValue(2), SSAValue(3))),
    ],
    SSATerminator::Return([SSAValue(4)]),
    5,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => {
      let rv = vs[0]
      let block = result.blocks[BlockId(0)]
      let mut found_20 = false
      for instr in block.instrs {
        match instr {
          Assign(v, I32Const(I32(20))) if v == rv => found_20 = true
          _ => continue
        }
      }
      assert_true(found_20)
    }
    _ => fail("Expected Return terminator")
  }
}

///|
test "SSAOptCtx get_op basic" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(10))),
      Assign(SSAValue(1), Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(0))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    2,
  )
  let ctx = SSAOptCtx::new(ssa)
  match ctx.get_op(SSAValue(1)) {
    Some(Binary(_, _, _)) => ()
    _ => fail("Expected Binary op")
  }
}

///|
test "SSAOptCtx rewrite_value applies replacement" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 0)
  let ctx = SSAOptCtx::new(ssa)
  ctx.replacements[SSAValue(2)] = SSAValue(0)
  assert_eq(ctx.rewrite_value(SSAValue(2)), SSAValue(0))
}

///|
test "SSAOptCtx rewrite_op rewrites operands" {
  let ssa = make_single_block_ssa([], SSATerminator::Return([]), 0)
  let ctx = SSAOptCtx::new(ssa)
  ctx.replacements[SSAValue(1)] = SSAValue(0)
  match ctx.rewrite_op(Binary(BinaryOp::i32_add(), SSAValue(1), SSAValue(1))) {
    Binary(_, a, b) => {
      assert_eq(a, SSAValue(0))
      assert_eq(b, SSAValue(0))
    }
    _ => fail("Expected rewritten binary")
  }
}

///|
test "optimize_assign copy propagation" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(5))),
      Assign(SSAValue(1), Copy(SSAValue(0))),
    ],
    SSATerminator::Return([SSAValue(1)]),
    2,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(0))
    _ => fail("Expected Return")
  }
}

///|
test "optimize_assign constant folding binary" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(3))),
      Assign(SSAValue(1), I32Const(I32(4))),
      Assign(SSAValue(2), Binary(BinaryOp::i32_mul(), SSAValue(0), SSAValue(1))),
    ],
    SSATerminator::Return([SSAValue(2)]),
    3,
  )
  let result = ssa.optimize()
  let block = result.blocks[BlockId(0)]
  assert_true(
    block.instrs.any(fn(i) {
      match i {
        Assign(_, I32Const(I32(12))) => true
        _ => false
      }
    }),
  )
}

///|
test "strength reduction prefers shift over mul" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(4))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_mul(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    11,
  )
  let result = ssa.optimize()
  match find_assign(result, 0, 1) {
    Some(Binary(op, _, _)) => assert_eq(op, BinaryOp::i32_shl())
    _ => fail("Expected shift-left")
  }
}

///|
test "strength reduction does not apply for non-powers" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(6))),
      Assign(
        SSAValue(1),
        Binary(BinaryOp::i32_mul(), SSAValue(10), SSAValue(0)),
      ),
    ],
    SSATerminator::Return([SSAValue(1)]),
    11,
  )
  let result = ssa.optimize()
  match find_assign(result, 0, 1) {
    Some(Binary(op, _, _)) => assert_eq(op, BinaryOp::i32_mul())
    _ => fail("Expected mul")
  }
}

///|
test "optimize_ssa BrIf non-const unchanged" {
  let ssa = make_single_block_ssa(
    [],
    SSATerminator::BrIf(SSAValue(10), BlockId(1), BlockId(2)),
    0,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(BrIf(_, _, _)) => ()
    _ => fail("Expected BrIf unchanged")
  }
}

///|
test "optimize_ssa BrTable negative index goes default" {
  let ssa = make_single_block_ssa(
    [Assign(SSAValue(0), I32Const(I32(-1)))],
    SSATerminator::BrTable(SSAValue(0), [BlockId(1), BlockId(2)], BlockId(99)),
    1,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Br(b)) => assert_eq(b, BlockId(99))
    _ => fail("Expected default branch")
  }
}

///|
test "DCE removes chained unused pure instructions" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(1))),
      Assign(SSAValue(1), I32Const(I32(2))),
      Assign(SSAValue(2), Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(1))),
    ],
    SSATerminator::Return([]),
    3,
  )
  let result = ssa.optimize()
  assert_eq(count_instrs(result, 0), 0)
}

///|
test "DCE preserves effectful chain" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(5))),
      Assign(SSAValue(1), Call(FuncIdx::new(0U), [SSAValue(0)])),
    ],
    SSATerminator::Return([]),
    2,
  )
  let result = ssa.optimize()
  assert_eq(count_instrs(result, 0), 2)
}

///|
test "phi with self reference preserved" {
  let phi : PhiNode = {
    local_idx: LocalIdx::new(0U),
    result: SSAValue(1),
    args: {
      let m : Map[BlockId, SSAValue] = {}
      m[BlockId(0)] = SSAValue(1)
      m
    },
  }
  let ssa = make_multi_block_ssa(
    [(0, [phi], [], SSATerminator::Return([SSAValue(1)]))],
    [(0, [])],
    0,
    2,
  )
  let result = ssa.optimize()
  match get_terminator(result, 0) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(1))
    _ => fail("Expected Return")
  }
}

///|
test "phi not simplified with differing inputs" {
  let phi : PhiNode = {
    local_idx: LocalIdx::new(0U),
    result: SSAValue(2),
    args: {
      let m : Map[BlockId, SSAValue] = {}
      m[BlockId(0)] = SSAValue(0)
      m[BlockId(1)] = SSAValue(1)
      m
    },
  }
  let ssa = make_multi_block_ssa(
    [
      (0, [], [], SSATerminator::Br(BlockId(2))),
      (1, [], [], SSATerminator::Br(BlockId(2))),
      (2, [phi], [], SSATerminator::Return([SSAValue(2)])),
    ],
    [(0, []), (1, []), (2, [0, 1])],
    0,
    3,
  )
  let result = ssa.optimize()
  match get_terminator(result, 2) {
    Some(Return(vs)) => assert_eq(vs[0], SSAValue(2))
    _ => fail("Expected phi preserved")
  }
}

///|
test "optimize_ssa converges on chained simplifications" {
  let ssa = make_single_block_ssa(
    [
      Assign(SSAValue(0), I32Const(I32(1))),
      Assign(SSAValue(1), Binary(BinaryOp::i32_add(), SSAValue(0), SSAValue(0))),
      Assign(SSAValue(2), Binary(BinaryOp::i32_mul(), SSAValue(1), SSAValue(1))),
    ],
    SSATerminator::Return([SSAValue(2)]),
    3,
  )
  let result = ssa.optimize()
  let block = result.blocks[BlockId(0)]
  assert_true(
    block.instrs.any(fn(i) {
      match i {
        Assign(_, I32Const(I32(4))) => true
        _ => false
      }
    }),
  )
}
