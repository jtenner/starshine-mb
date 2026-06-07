///|
pub fn local_cse_summary() -> String {
  "Reuse repeated local expression trees through fresh temp locals."
}

///|
pub fn local_cse_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "local-cse",
    requires=[@ir.HotAnalysis::effects()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
priv struct LcseRawRewrite {
  func : @lib.Func
  changed : Bool
}

///|
priv struct LcseRawExpr {
  start : Int
  end : Int
  instr : @lib.Instruction
  key : Int
  ty : @lib.ValType
  size : Int
  children : Array[Int]
  reads_locals : Array[Int]
  reads_memory : Bool
  reads_memory_size : Bool
  reads_table_state : Bool
  reads_global : Bool
  reads_heap : Bool
  cache_child_for_replay : Bool
  mut repeat_of : Int
  mut local_id : Int
}

///|
priv struct LcseRawNestedRepeat {
  parent_idx : Int
  start : Int
  end : Int
  original : Int
}

///|
priv struct LcseRawCallInfo {
  params : Array[@lib.ValType]
  result : @lib.ValType?
  idempotent : Bool
}

///|
fn lcse_simd_pure_operand_count(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.Instruction::V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(0)
    @lib.Instruction::V128Not
    | @lib.Instruction::V128AnyTrue
    | @lib.Instruction::I8x16Splat
    | @lib.Instruction::I16x8Splat
    | @lib.Instruction::I32x4Splat
    | @lib.Instruction::I64x2Splat
    | @lib.Instruction::F32x4Splat
    | @lib.Instruction::F64x2Splat
    | @lib.Instruction::I8x16ExtractLaneS(_)
    | @lib.Instruction::I8x16ExtractLaneU(_)
    | @lib.Instruction::I16x8ExtractLaneS(_)
    | @lib.Instruction::I16x8ExtractLaneU(_)
    | @lib.Instruction::I32x4ExtractLane(_)
    | @lib.Instruction::I64x2ExtractLane(_)
    | @lib.Instruction::F32x4ExtractLane(_)
    | @lib.Instruction::F64x2ExtractLane(_)
    | @lib.Instruction::I8x16Abs
    | @lib.Instruction::I8x16Neg
    | @lib.Instruction::I8x16Popcnt
    | @lib.Instruction::I8x16AllTrue
    | @lib.Instruction::I8x16Bitmask
    | @lib.Instruction::I16x8ExtaddPairwiseI8x16S
    | @lib.Instruction::I16x8ExtaddPairwiseI8x16U
    | @lib.Instruction::I32x4ExtaddPairwiseI16x8S
    | @lib.Instruction::I32x4ExtaddPairwiseI16x8U
    | @lib.Instruction::I16x8Abs
    | @lib.Instruction::I16x8Neg
    | @lib.Instruction::I16x8AllTrue
    | @lib.Instruction::I16x8Bitmask
    | @lib.Instruction::I16x8ExtendLowI8x16S
    | @lib.Instruction::I16x8ExtendHighI8x16S
    | @lib.Instruction::I16x8ExtendLowI8x16U
    | @lib.Instruction::I16x8ExtendHighI8x16U
    | @lib.Instruction::I32x4Abs
    | @lib.Instruction::I32x4Neg
    | @lib.Instruction::I32x4AllTrue
    | @lib.Instruction::I32x4Bitmask
    | @lib.Instruction::I32x4ExtendLowI16x8S
    | @lib.Instruction::I32x4ExtendHighI16x8S
    | @lib.Instruction::I32x4ExtendLowI16x8U
    | @lib.Instruction::I32x4ExtendHighI16x8U
    | @lib.Instruction::I64x2Abs
    | @lib.Instruction::I64x2Neg
    | @lib.Instruction::I64x2AllTrue
    | @lib.Instruction::I64x2Bitmask
    | @lib.Instruction::I64x2ExtendLowI32x4S
    | @lib.Instruction::I64x2ExtendHighI32x4S
    | @lib.Instruction::I64x2ExtendLowI32x4U
    | @lib.Instruction::I64x2ExtendHighI32x4U
    | @lib.Instruction::F32x4Ceil
    | @lib.Instruction::F32x4Floor
    | @lib.Instruction::F32x4Trunc
    | @lib.Instruction::F32x4Nearest
    | @lib.Instruction::F32x4Abs
    | @lib.Instruction::F32x4Neg
    | @lib.Instruction::F32x4Sqrt
    | @lib.Instruction::F64x2Ceil
    | @lib.Instruction::F64x2Floor
    | @lib.Instruction::F64x2Trunc
    | @lib.Instruction::F64x2Nearest
    | @lib.Instruction::F64x2Abs
    | @lib.Instruction::F64x2Neg
    | @lib.Instruction::F64x2Sqrt
    | @lib.Instruction::F32x4DemoteF64x2Zero
    | @lib.Instruction::F64x2PromoteLowF32x4
    | @lib.Instruction::I32x4TruncSatF32x4S
    | @lib.Instruction::I32x4TruncSatF32x4U
    | @lib.Instruction::F32x4ConvertI32x4S
    | @lib.Instruction::F32x4ConvertI32x4U
    | @lib.Instruction::I32x4TruncSatF64x2SZero
    | @lib.Instruction::I32x4TruncSatF64x2UZero
    | @lib.Instruction::F64x2ConvertLowI32x4S
    | @lib.Instruction::F64x2ConvertLowI32x4U => Some(1)
    @lib.Instruction::I8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    )
    | @lib.Instruction::I8x16Swizzle
    | @lib.Instruction::I8x16ReplaceLane(_)
    | @lib.Instruction::I16x8ReplaceLane(_)
    | @lib.Instruction::I32x4ReplaceLane(_)
    | @lib.Instruction::I64x2ReplaceLane(_)
    | @lib.Instruction::F32x4ReplaceLane(_)
    | @lib.Instruction::F64x2ReplaceLane(_)
    | @lib.Instruction::I8x16Eq
    | @lib.Instruction::I8x16Ne
    | @lib.Instruction::I8x16LtS
    | @lib.Instruction::I8x16LtU
    | @lib.Instruction::I8x16GtS
    | @lib.Instruction::I8x16GtU
    | @lib.Instruction::I8x16LeS
    | @lib.Instruction::I8x16LeU
    | @lib.Instruction::I8x16GeS
    | @lib.Instruction::I8x16GeU
    | @lib.Instruction::I16x8Eq
    | @lib.Instruction::I16x8Ne
    | @lib.Instruction::I16x8LtS
    | @lib.Instruction::I16x8LtU
    | @lib.Instruction::I16x8GtS
    | @lib.Instruction::I16x8GtU
    | @lib.Instruction::I16x8LeS
    | @lib.Instruction::I16x8LeU
    | @lib.Instruction::I16x8GeS
    | @lib.Instruction::I16x8GeU
    | @lib.Instruction::I32x4Eq
    | @lib.Instruction::I32x4Ne
    | @lib.Instruction::I32x4LtS
    | @lib.Instruction::I32x4LtU
    | @lib.Instruction::I32x4GtS
    | @lib.Instruction::I32x4GtU
    | @lib.Instruction::I32x4LeS
    | @lib.Instruction::I32x4LeU
    | @lib.Instruction::I32x4GeS
    | @lib.Instruction::I32x4GeU
    | @lib.Instruction::I64x2Eq
    | @lib.Instruction::I64x2Ne
    | @lib.Instruction::I64x2LtS
    | @lib.Instruction::I64x2GtS
    | @lib.Instruction::I64x2LeS
    | @lib.Instruction::I64x2GeS
    | @lib.Instruction::F32x4Eq
    | @lib.Instruction::F32x4Ne
    | @lib.Instruction::F32x4Lt
    | @lib.Instruction::F32x4Gt
    | @lib.Instruction::F32x4Le
    | @lib.Instruction::F32x4Ge
    | @lib.Instruction::F64x2Eq
    | @lib.Instruction::F64x2Ne
    | @lib.Instruction::F64x2Lt
    | @lib.Instruction::F64x2Gt
    | @lib.Instruction::F64x2Le
    | @lib.Instruction::F64x2Ge
    | @lib.Instruction::V128And
    | @lib.Instruction::V128Andnot
    | @lib.Instruction::V128Or
    | @lib.Instruction::V128Xor
    | @lib.Instruction::I8x16NarrowI16x8S
    | @lib.Instruction::I8x16NarrowI16x8U
    | @lib.Instruction::I8x16Shl
    | @lib.Instruction::I8x16ShrS
    | @lib.Instruction::I8x16ShrU
    | @lib.Instruction::I8x16Add
    | @lib.Instruction::I8x16AddSatS
    | @lib.Instruction::I8x16AddSatU
    | @lib.Instruction::I8x16Sub
    | @lib.Instruction::I8x16SubSatS
    | @lib.Instruction::I8x16SubSatU
    | @lib.Instruction::I8x16MinS
    | @lib.Instruction::I8x16MinU
    | @lib.Instruction::I8x16MaxS
    | @lib.Instruction::I8x16MaxU
    | @lib.Instruction::I8x16AvgrU
    | @lib.Instruction::I16x8Q15mulrSatS
    | @lib.Instruction::I16x8NarrowI32x4S
    | @lib.Instruction::I16x8NarrowI32x4U
    | @lib.Instruction::I16x8Shl
    | @lib.Instruction::I16x8ShrS
    | @lib.Instruction::I16x8ShrU
    | @lib.Instruction::I16x8Add
    | @lib.Instruction::I16x8AddSatS
    | @lib.Instruction::I16x8AddSatU
    | @lib.Instruction::I16x8Sub
    | @lib.Instruction::I16x8SubSatS
    | @lib.Instruction::I16x8SubSatU
    | @lib.Instruction::I16x8Mul
    | @lib.Instruction::I16x8MinS
    | @lib.Instruction::I16x8MinU
    | @lib.Instruction::I16x8MaxS
    | @lib.Instruction::I16x8MaxU
    | @lib.Instruction::I16x8AvgrU
    | @lib.Instruction::I16x8ExtmulLowI8x16S
    | @lib.Instruction::I16x8ExtmulHighI8x16S
    | @lib.Instruction::I16x8ExtmulLowI8x16U
    | @lib.Instruction::I16x8ExtmulHighI8x16U
    | @lib.Instruction::I32x4Shl
    | @lib.Instruction::I32x4ShrS
    | @lib.Instruction::I32x4ShrU
    | @lib.Instruction::I32x4Add
    | @lib.Instruction::I32x4Sub
    | @lib.Instruction::I32x4Mul
    | @lib.Instruction::I32x4MinS
    | @lib.Instruction::I32x4MinU
    | @lib.Instruction::I32x4MaxS
    | @lib.Instruction::I32x4MaxU
    | @lib.Instruction::I32x4DotI16x8S
    | @lib.Instruction::I32x4ExtmulLowI16x8S
    | @lib.Instruction::I32x4ExtmulHighI16x8S
    | @lib.Instruction::I32x4ExtmulLowI16x8U
    | @lib.Instruction::I32x4ExtmulHighI16x8U
    | @lib.Instruction::I64x2Shl
    | @lib.Instruction::I64x2ShrS
    | @lib.Instruction::I64x2ShrU
    | @lib.Instruction::I64x2Add
    | @lib.Instruction::I64x2Sub
    | @lib.Instruction::I64x2Mul
    | @lib.Instruction::I64x2ExtmulLowI32x4S
    | @lib.Instruction::I64x2ExtmulHighI32x4S
    | @lib.Instruction::I64x2ExtmulLowI32x4U
    | @lib.Instruction::I64x2ExtmulHighI32x4U
    | @lib.Instruction::F32x4Add
    | @lib.Instruction::F32x4Sub
    | @lib.Instruction::F32x4Mul
    | @lib.Instruction::F32x4Div
    | @lib.Instruction::F32x4Min
    | @lib.Instruction::F32x4Max
    | @lib.Instruction::F32x4Pmin
    | @lib.Instruction::F32x4Pmax
    | @lib.Instruction::F64x2Add
    | @lib.Instruction::F64x2Sub
    | @lib.Instruction::F64x2Mul
    | @lib.Instruction::F64x2Div
    | @lib.Instruction::F64x2Min
    | @lib.Instruction::F64x2Max
    | @lib.Instruction::F64x2Pmin
    | @lib.Instruction::F64x2Pmax => Some(2)
    @lib.Instruction::V128Bitselect => Some(3)
    _ => None
  }
}

///|
fn lcse_simd_pure_result_type(instr : @lib.Instruction) -> @lib.ValType? {
  match instr {
    @lib.Instruction::V128AnyTrue
    | @lib.Instruction::I8x16AllTrue
    | @lib.Instruction::I8x16Bitmask
    | @lib.Instruction::I16x8AllTrue
    | @lib.Instruction::I16x8Bitmask
    | @lib.Instruction::I32x4AllTrue
    | @lib.Instruction::I32x4Bitmask
    | @lib.Instruction::I8x16ExtractLaneS(_)
    | @lib.Instruction::I8x16ExtractLaneU(_)
    | @lib.Instruction::I16x8ExtractLaneS(_)
    | @lib.Instruction::I16x8ExtractLaneU(_)
    | @lib.Instruction::I32x4ExtractLane(_) => Some(@lib.ValType::i32())
    @lib.Instruction::I64x2AllTrue
    | @lib.Instruction::I64x2Bitmask
    | @lib.Instruction::I64x2ExtractLane(_) => Some(@lib.ValType::i64())
    @lib.Instruction::F32x4ExtractLane(_) => Some(@lib.ValType::f32())
    @lib.Instruction::F64x2ExtractLane(_) => Some(@lib.ValType::f64())
    _ =>
      match lcse_simd_pure_operand_count(instr) {
        Some(_) => Some(@lib.ValType::v128())
        None => None
      }
  }
}

///|
fn lcse_candidate_op_id(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Instruction::I32Add => 1
    @lib.Instruction::I32Sub => 2
    @lib.Instruction::I32Mul => 3
    @lib.Instruction::I32DivS => 142
    @lib.Instruction::I32DivU => 143
    @lib.Instruction::I32RemS => 144
    @lib.Instruction::I32RemU => 145
    @lib.Instruction::I64Add => 4
    @lib.Instruction::I64Sub => 5
    @lib.Instruction::I64Mul => 6
    @lib.Instruction::I64DivS => 146
    @lib.Instruction::I64DivU => 147
    @lib.Instruction::I64RemS => 148
    @lib.Instruction::I64RemU => 149
    @lib.Instruction::I32Eqz => 7
    @lib.Instruction::I64Eqz => 8
    @lib.Instruction::I32Eq => 9
    @lib.Instruction::I32Ne => 10
    @lib.Instruction::I64Eq => 11
    @lib.Instruction::I64Ne => 12
    @lib.Instruction::I32LtS => 20
    @lib.Instruction::I32LtU => 21
    @lib.Instruction::I32GtS => 22
    @lib.Instruction::I32GtU => 23
    @lib.Instruction::I32LeS => 24
    @lib.Instruction::I32LeU => 25
    @lib.Instruction::I32GeS => 26
    @lib.Instruction::I32GeU => 27
    @lib.Instruction::I64LtS => 28
    @lib.Instruction::I64LtU => 29
    @lib.Instruction::I64GtS => 30
    @lib.Instruction::I64GtU => 31
    @lib.Instruction::I64LeS => 32
    @lib.Instruction::I64LeU => 33
    @lib.Instruction::I64GeS => 34
    @lib.Instruction::I64GeU => 35
    @lib.Instruction::I32Clz => 36
    @lib.Instruction::I32Ctz => 37
    @lib.Instruction::I32Popcnt => 38
    @lib.Instruction::I64Clz => 39
    @lib.Instruction::I64Ctz => 40
    @lib.Instruction::I64Popcnt => 41
    @lib.Instruction::I32And => 42
    @lib.Instruction::I32Or => 43
    @lib.Instruction::I32Xor => 44
    @lib.Instruction::I32Shl => 45
    @lib.Instruction::I32ShrS => 46
    @lib.Instruction::I32ShrU => 47
    @lib.Instruction::I32Rotl => 48
    @lib.Instruction::I32Rotr => 49
    @lib.Instruction::I64And => 50
    @lib.Instruction::I64Or => 51
    @lib.Instruction::I64Xor => 52
    @lib.Instruction::I64Shl => 53
    @lib.Instruction::I64ShrS => 54
    @lib.Instruction::I64ShrU => 55
    @lib.Instruction::I64Rotl => 56
    @lib.Instruction::I64Rotr => 57
    @lib.Instruction::F32Eq => 58
    @lib.Instruction::F32Ne => 59
    @lib.Instruction::F32Lt => 60
    @lib.Instruction::F32Gt => 61
    @lib.Instruction::F32Le => 62
    @lib.Instruction::F32Ge => 63
    @lib.Instruction::F64Eq => 64
    @lib.Instruction::F64Ne => 65
    @lib.Instruction::F64Lt => 66
    @lib.Instruction::F64Gt => 67
    @lib.Instruction::F64Le => 68
    @lib.Instruction::F64Ge => 69
    @lib.Instruction::F32Abs => 70
    @lib.Instruction::F32Neg => 71
    @lib.Instruction::F32Ceil => 72
    @lib.Instruction::F32Floor => 73
    @lib.Instruction::F32Trunc => 74
    @lib.Instruction::F32Nearest => 75
    @lib.Instruction::F32Sqrt => 76
    @lib.Instruction::F64Abs => 77
    @lib.Instruction::F64Neg => 78
    @lib.Instruction::F64Ceil => 79
    @lib.Instruction::F64Floor => 80
    @lib.Instruction::F64Trunc => 81
    @lib.Instruction::F64Nearest => 82
    @lib.Instruction::F64Sqrt => 83
    @lib.Instruction::F32Add => 84
    @lib.Instruction::F32Sub => 85
    @lib.Instruction::F32Mul => 86
    @lib.Instruction::F32Div => 87
    @lib.Instruction::F32Min => 88
    @lib.Instruction::F32Max => 89
    @lib.Instruction::F32Copysign => 90
    @lib.Instruction::F64Add => 91
    @lib.Instruction::F64Sub => 92
    @lib.Instruction::F64Mul => 93
    @lib.Instruction::F64Div => 94
    @lib.Instruction::F64Min => 95
    @lib.Instruction::F64Max => 96
    @lib.Instruction::F64Copysign => 97
    @lib.Instruction::RefIsNull => 98
    @lib.Instruction::I32WrapI64 => 99
    @lib.Instruction::I64ExtendI32S => 100
    @lib.Instruction::I64ExtendI32U => 101
    @lib.Instruction::F32DemoteF64 => 102
    @lib.Instruction::F64PromoteF32 => 103
    @lib.Instruction::I32ReinterpretF32 => 104
    @lib.Instruction::I64ReinterpretF64 => 105
    @lib.Instruction::F32ReinterpretI32 => 106
    @lib.Instruction::F64ReinterpretI64 => 107
    @lib.Instruction::I32Extend8S => 108
    @lib.Instruction::I32Extend16S => 109
    @lib.Instruction::I64Extend8S => 110
    @lib.Instruction::I64Extend16S => 111
    @lib.Instruction::I64Extend32S => 112
    @lib.Instruction::I32Load8S(_) => 113
    @lib.Instruction::I32Load8U(_) => 114
    @lib.Instruction::I32Load16S(_) => 115
    @lib.Instruction::I32Load16U(_) => 116
    @lib.Instruction::I64Load8S(_) => 117
    @lib.Instruction::I64Load8U(_) => 118
    @lib.Instruction::I64Load16S(_) => 119
    @lib.Instruction::I64Load16U(_) => 120
    @lib.Instruction::I64Load32S(_) => 121
    @lib.Instruction::I64Load32U(_) => 122
    @lib.Instruction::I32TruncSatF32S => 123
    @lib.Instruction::I32TruncSatF32U => 124
    @lib.Instruction::I32TruncSatF64S => 125
    @lib.Instruction::I32TruncSatF64U => 126
    @lib.Instruction::I64TruncSatF32S => 127
    @lib.Instruction::I64TruncSatF32U => 128
    @lib.Instruction::I64TruncSatF64S => 129
    @lib.Instruction::I64TruncSatF64U => 130
    @lib.Instruction::I32TruncF32S => 150
    @lib.Instruction::I32TruncF32U => 151
    @lib.Instruction::I32TruncF64S => 152
    @lib.Instruction::I32TruncF64U => 153
    @lib.Instruction::I64TruncF32S => 154
    @lib.Instruction::I64TruncF32U => 155
    @lib.Instruction::I64TruncF64S => 156
    @lib.Instruction::I64TruncF64U => 157
    @lib.Instruction::RefTest(_, _) => 158
    @lib.Instruction::AnyConvertExtern => 159
    @lib.Instruction::ExternConvertAny => 160
    @lib.Instruction::RefCast(true, _) => 162
    @lib.Instruction::RefCast(false, _) => 163
    @lib.Instruction::RefAsNonNull => 164
    @lib.Instruction::RefI31 => 165
    @lib.Instruction::StructGet(_, _) => 166
    @lib.Instruction::StructGetS(_, _) => 167
    @lib.Instruction::StructGetU(_, _) => 168
    @lib.Instruction::ArrayGet(_) => 169
    @lib.Instruction::ArrayGetS(_) => 170
    @lib.Instruction::ArrayGetU(_) => 171
    @lib.Instruction::ArrayLen => 172
    @lib.Instruction::F32ConvertI32S => 134
    @lib.Instruction::F32ConvertI32U => 135
    @lib.Instruction::F32ConvertI64S => 136
    @lib.Instruction::F32ConvertI64U => 137
    @lib.Instruction::F64ConvertI32S => 138
    @lib.Instruction::F64ConvertI32U => 139
    @lib.Instruction::F64ConvertI64S => 140
    @lib.Instruction::F64ConvertI64U => 141
    @lib.Instruction::I31GetS => 132
    @lib.Instruction::I31GetU => 133
    @lib.Instruction::I32Load(_) => 13
    @lib.Instruction::I64Load(_) => 14
    @lib.Instruction::F32Load(_) => 15
    @lib.Instruction::F64Load(_) => 16
    @lib.Instruction::Select(_) => 17
    @lib.Instruction::Call(_) => 18
    @lib.Instruction::RefEq => 19
    _ =>
      if lcse_instr_is_simd_memory_load(instr) {
        173
      } else {
        match lcse_simd_pure_operand_count(instr) {
          Some(_) => 161
          None => -1
        }
      }
  }
}

///|
fn lcse_instrs_may_have_repeated_candidate_with_seen(
  instrs : Array[@lib.Instruction],
  seen : @bitset.BitSet,
) -> Bool {
  for instr in instrs {
    let id = lcse_candidate_op_id(instr)
    if id >= 0 {
      if seen[id] {
        return true
      }
      seen[id] = true
    }
    match instr {
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(body, seen) {
          return true
        }
      @lib.Instruction::If(_, then_body, Some(else_body)) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(then_body, seen) ||
          lcse_instrs_may_have_repeated_candidate_with_seen(else_body, seen) {
          return true
        }
      @lib.Instruction::If(_, then_body, None) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(then_body, seen) {
          return true
        }
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        if lcse_instrs_may_have_repeated_candidate_with_seen(body, seen) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn lcse_instrs_may_have_repeated_candidate(
  instrs : Array[@lib.Instruction],
) -> Bool {
  lcse_instrs_may_have_repeated_candidate_with_seen(
    instrs,
    @bitset.BitSet::new(224),
  )
}

///|
fn lcse_raw_instr_is_branch_control(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::Br(_)
    | @lib.Instruction::BrIf(_)
    | @lib.Instruction::BrTable(_, _)
    | @lib.Instruction::BrOnNull(_)
    | @lib.Instruction::BrOnNonNull(_)
    | @lib.Instruction::BrOnCast(_, _, _, _)
    | @lib.Instruction::BrOnCastFail(_, _, _, _)
    | @lib.Instruction::Return
    | @lib.Instruction::ReturnCall(_)
    | @lib.Instruction::ReturnCallIndirect(_, _)
    | @lib.Instruction::ReturnCallRef(_) => true
    _ => false
  }
}

///|
fn lcse_raw_instrs_have_branch_control(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    if lcse_raw_instr_is_branch_control(instr) {
      return true
    }
    match instr {
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        if lcse_raw_instrs_have_branch_control(body) {
          return true
        }
      @lib.Instruction::If(_, then_body, Some(else_body)) =>
        if lcse_raw_instrs_have_branch_control(then_body) ||
          lcse_raw_instrs_have_branch_control(else_body) {
          return true
        }
      @lib.Instruction::If(_, then_body, None) =>
        if lcse_raw_instrs_have_branch_control(then_body) {
          return true
        }
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        if lcse_raw_instrs_have_branch_control(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn lcse_raw_instrs_end_in_unreachable(instrs : Array[@lib.Instruction]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  match instrs[instrs.length() - 1] {
    @lib.Instruction::Unreachable => true
    _ => false
  }
}

///|
fn lcse_raw_dropped_block_has_unreachable_tail(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::Block(_, @lib.Expr(body)) =>
      lcse_raw_instrs_end_in_unreachable(body) &&
      !lcse_raw_instrs_have_branch_control(body)
    _ => false
  }
}

///|
fn lcse_raw_void_block_can_inline_before_unreachable(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::Block(_, @lib.Expr(body)) =>
      !lcse_raw_instrs_have_branch_control(body)
    _ => false
  }
}

///|
fn lcse_instrs_may_have_dropped_unreachable_before_unreachable(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut i = 0
  while i < instrs.length() {
    match instrs[i] {
      @lib.Instruction::Unreachable | @lib.Instruction::Block(_, _) => {
        let mut j = i + 1
        let mut saw_drop = false
        while j < instrs.length() {
          match instrs[j] {
            @lib.Instruction::Drop => {
              saw_drop = true
              j += 1
            }
            _ => break
          }
        }
        if j < instrs.length() {
          match instrs[j] {
            @lib.Instruction::Unreachable =>
              match instrs[i] {
                @lib.Instruction::Unreachable => if saw_drop { return true }
                other =>
                  if lcse_raw_dropped_block_has_unreachable_tail(other) ||
                    lcse_raw_void_block_can_inline_before_unreachable(other) {
                    return true
                  }
              }
            _ => ()
          }
        }
      }
      @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        if lcse_instrs_may_have_dropped_unreachable_before_unreachable(body) {
          return true
        }
      @lib.Instruction::If(_, then_body, Some(else_body)) =>
        if lcse_instrs_may_have_dropped_unreachable_before_unreachable(
            then_body,
          ) ||
          lcse_instrs_may_have_dropped_unreachable_before_unreachable(else_body) {
          return true
        }
      @lib.Instruction::If(_, then_body, None) =>
        if lcse_instrs_may_have_dropped_unreachable_before_unreachable(
            then_body,
          ) {
          return true
        }
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        if lcse_instrs_may_have_dropped_unreachable_before_unreachable(body) {
          return true
        }
      _ => ()
    }
    i += 1
  }
  false
}

///|
fn lcse_raw_collapse_trailing_unreachable_run(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut end = instrs.length()
  while end > 0 {
    match instrs[end - 1] {
      @lib.Instruction::Unreachable => end -= 1
      _ => break
    }
  }
  if end == instrs.length() {
    for instr in instrs {
      out.push(instr)
    }
    return out
  }
  for idx = 0; idx < end; idx = idx + 1 {
    out.push(instrs[idx])
  }
  out.push(@lib.Instruction::unreachable_())
  out
}

///|
fn lcse_raw_remove_dropped_unreachable_debris(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    match instrs[i] {
      @lib.Instruction::Unreachable | @lib.Instruction::Block(_, _) => {
        let mut j = i + 1
        let mut saw_drop = false
        while j < instrs.length() {
          match instrs[j] {
            @lib.Instruction::Drop => {
              saw_drop = true
              j += 1
            }
            _ => break
          }
        }
        if j < instrs.length() {
          match instrs[j] {
            @lib.Instruction::Unreachable =>
              match instrs[i] {
                @lib.Instruction::Unreachable =>
                  if saw_drop {
                    changed = true
                    i = j
                    continue
                  }
                @lib.Instruction::Block(_, @lib.Expr(body)) =>
                  if lcse_raw_dropped_block_has_unreachable_tail(instrs[i]) {
                    let collapsed = lcse_raw_collapse_trailing_unreachable_run(
                      body,
                    )
                    let (cleaned_body, _) = lcse_raw_remove_dropped_unreachable_debris(
                      collapsed,
                    )
                    for body_instr in cleaned_body {
                      out.push(body_instr)
                    }
                    changed = true
                    i = j + 1
                    continue
                  } else if lcse_raw_void_block_can_inline_before_unreachable(
                      instrs[i],
                    ) {
                    let (cleaned_body, _) = lcse_raw_remove_dropped_unreachable_debris(
                      body,
                    )
                    for body_instr in cleaned_body {
                      out.push(body_instr)
                    }
                    changed = true
                    i += 1
                    continue
                  }
                _ => ()
              }
            _ => ()
          }
        }
      }
      _ => ()
    }
    let rewritten_instr = match instrs[i] {
      @lib.Instruction::Block(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = lcse_raw_remove_dropped_unreachable_debris(
          body,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = lcse_raw_remove_dropped_unreachable_debris(
          body,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::If(block_type, then_body, else_body) => {
        let (next_then, then_changed) = lcse_raw_remove_dropped_unreachable_debris(
          then_body,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (body2, changed2) = lcse_raw_remove_dropped_unreachable_debris(
              body,
            )
            (Some(body2), changed2)
          }
          None => (None, false)
        }
        if then_changed || else_changed {
          changed = true
        }
        @lib.Instruction::if_(block_type, next_then, next_else)
      }
      @lib.Instruction::TryTable(block_type, catches, @lib.Expr(body)) => {
        let (next_body, body_changed) = lcse_raw_remove_dropped_unreachable_debris(
          body,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(next_body),
        )
      }
      other => other
    }
    out.push(rewritten_instr)
    i += 1
  }
  (out, changed)
}

///|
fn lcse_instr_is_load(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::I32Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_)
    | @lib.Instruction::I64Load(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_)
    | @lib.Instruction::F32Load(_)
    | @lib.Instruction::F64Load(_) => true
    _ => false
  }
}

///|
fn lcse_instr_is_simd_memory_load(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::V128Load(_)
    | @lib.Instruction::V128Load8x8S(_)
    | @lib.Instruction::V128Load8x8U(_)
    | @lib.Instruction::V128Load16x4S(_)
    | @lib.Instruction::V128Load16x4U(_)
    | @lib.Instruction::V128Load32x2S(_)
    | @lib.Instruction::V128Load32x2U(_)
    | @lib.Instruction::V128Load8Splat(_)
    | @lib.Instruction::V128Load16Splat(_)
    | @lib.Instruction::V128Load32Splat(_)
    | @lib.Instruction::V128Load64Splat(_)
    | @lib.Instruction::V128Load32Zero(_)
    | @lib.Instruction::V128Load64Zero(_)
    | @lib.Instruction::V128Load8Lane(_, _)
    | @lib.Instruction::V128Load16Lane(_, _)
    | @lib.Instruction::V128Load32Lane(_, _)
    | @lib.Instruction::V128Load64Lane(_, _) => true
    _ => false
  }
}

///|
fn lcse_instr_reads_memory(instr : @lib.Instruction) -> Bool {
  lcse_instr_is_load(instr) || lcse_instr_is_simd_memory_load(instr)
}

///|
fn lcse_instr_is_store(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::I32Store(_)
    | @lib.Instruction::I32Store8(_)
    | @lib.Instruction::I32Store16(_)
    | @lib.Instruction::I64Store(_)
    | @lib.Instruction::I64Store8(_)
    | @lib.Instruction::I64Store16(_)
    | @lib.Instruction::I64Store32(_)
    | @lib.Instruction::F32Store(_)
    | @lib.Instruction::F64Store(_)
    | @lib.Instruction::V128Store(_)
    | @lib.Instruction::V128Store8Lane(_, _)
    | @lib.Instruction::V128Store16Lane(_, _)
    | @lib.Instruction::V128Store32Lane(_, _)
    | @lib.Instruction::V128Store64Lane(_, _) => true
    _ => false
  }
}

///|
fn lcse_raw_func_idx_raw(idx : @lib.FuncIdx) -> Int {
  let @lib.FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn lcse_raw_call_info(
  call_infos : Array[LcseRawCallInfo],
  idx : @lib.FuncIdx,
) -> LcseRawCallInfo? {
  call_infos.get(lcse_raw_func_idx_raw(idx))
}

///|
fn lcse_raw_call_is_idempotent(
  call_infos : Array[LcseRawCallInfo],
  idx : @lib.FuncIdx,
) -> Bool {
  match lcse_raw_call_info(call_infos, idx) {
    Some(info) => info.idempotent
    None => false
  }
}

///|
fn lcse_raw_instr_operand_count(
  instr : @lib.Instruction,
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> Int? {
  match instr {
    @lib.Instruction::LocalGet(_)
    | @lib.Instruction::GlobalGet(_)
    | @lib.Instruction::I32Const(_)
    | @lib.Instruction::I64Const(_)
    | @lib.Instruction::F32Const(_)
    | @lib.Instruction::F64Const(_)
    | @lib.Instruction::MemorySize(_)
    | @lib.Instruction::TableSize(_)
    | @lib.Instruction::DataDrop(_)
    | @lib.Instruction::ElemDrop(_)
    | @lib.Instruction::RefNull(_)
    | @lib.Instruction::RefFunc(_)
    | @lib.Instruction::StringConst(_) => Some(0)
    @lib.Instruction::Drop
    | @lib.Instruction::RefIsNull
    | @lib.Instruction::ThrowRef
    | @lib.Instruction::BrOnNull(_)
    | @lib.Instruction::BrOnNonNull(_)
    | @lib.Instruction::BrOnCast(_, _, _, _)
    | @lib.Instruction::BrOnCastFail(_, _, _, _)
    | @lib.Instruction::LocalSet(_)
    | @lib.Instruction::LocalTee(_)
    | @lib.Instruction::GlobalSet(_)
    | @lib.Instruction::MemoryGrow(_)
    | @lib.Instruction::If(_, _, _)
    | @lib.Instruction::BrIf(_) => Some(1)
    @lib.Instruction::Select(_) => Some(3)
    @lib.Instruction::Call(idx) =>
      match lcse_raw_call_info(call_infos, idx) {
        Some(info) => Some(info.params.length())
        None => None
      }
    @lib.Instruction::ReturnCall(idx) =>
      match lcse_raw_call_info(call_infos, idx) {
        Some(info) => Some(info.params.length())
        None => None
      }
    @lib.Instruction::ReturnCallIndirect(type_idx, _) =>
      match lcse_raw_func_type_for_idx(subtypes, type_idx) {
        Some(@lib.FuncType(params, _)) => Some(params.length() + 1)
        None => None
      }
    @lib.Instruction::ReturnCallRef(type_idx) =>
      match lcse_raw_func_type_for_idx(subtypes, type_idx) {
        Some(@lib.FuncType(params, _)) => Some(params.length() + 1)
        None => None
      }
    @lib.Instruction::I32Add
    | @lib.Instruction::I32Sub
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I32DivS
    | @lib.Instruction::I32DivU
    | @lib.Instruction::I32RemS
    | @lib.Instruction::I32RemU
    | @lib.Instruction::I32And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr
    | @lib.Instruction::I64Add
    | @lib.Instruction::I64Sub
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I64DivS
    | @lib.Instruction::I64DivU
    | @lib.Instruction::I64RemS
    | @lib.Instruction::I64RemU
    | @lib.Instruction::I64And
    | @lib.Instruction::I64Or
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr
    | @lib.Instruction::F32Add
    | @lib.Instruction::F32Sub
    | @lib.Instruction::F32Mul
    | @lib.Instruction::F32Div
    | @lib.Instruction::F32Min
    | @lib.Instruction::F32Max
    | @lib.Instruction::F32Copysign
    | @lib.Instruction::F64Add
    | @lib.Instruction::F64Sub
    | @lib.Instruction::F64Mul
    | @lib.Instruction::F64Div
    | @lib.Instruction::F64Min
    | @lib.Instruction::F64Max
    | @lib.Instruction::F64Copysign
    | @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I32LtS
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I64LtS
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GtU
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64GeU
    | @lib.Instruction::F32Eq
    | @lib.Instruction::F32Ne
    | @lib.Instruction::F32Lt
    | @lib.Instruction::F32Gt
    | @lib.Instruction::F32Le
    | @lib.Instruction::F32Ge
    | @lib.Instruction::F64Eq
    | @lib.Instruction::F64Ne
    | @lib.Instruction::F64Lt
    | @lib.Instruction::F64Gt
    | @lib.Instruction::F64Le
    | @lib.Instruction::F64Ge
    | @lib.Instruction::RefEq => Some(2)
    @lib.Instruction::I32Eqz
    | @lib.Instruction::I32Clz
    | @lib.Instruction::I32Ctz
    | @lib.Instruction::I32Popcnt
    | @lib.Instruction::I64Eqz
    | @lib.Instruction::I64Clz
    | @lib.Instruction::I64Ctz
    | @lib.Instruction::I64Popcnt
    | @lib.Instruction::F32Abs
    | @lib.Instruction::F32Neg
    | @lib.Instruction::F32Ceil
    | @lib.Instruction::F32Floor
    | @lib.Instruction::F32Trunc
    | @lib.Instruction::F32Nearest
    | @lib.Instruction::F32Sqrt
    | @lib.Instruction::F64Abs
    | @lib.Instruction::F64Neg
    | @lib.Instruction::F64Ceil
    | @lib.Instruction::F64Floor
    | @lib.Instruction::F64Trunc
    | @lib.Instruction::F64Nearest
    | @lib.Instruction::F64Sqrt
    | @lib.Instruction::I32WrapI64
    | @lib.Instruction::I64ExtendI32S
    | @lib.Instruction::I64ExtendI32U
    | @lib.Instruction::F32ConvertI32S
    | @lib.Instruction::F32ConvertI32U
    | @lib.Instruction::F32ConvertI64S
    | @lib.Instruction::F32ConvertI64U
    | @lib.Instruction::F32DemoteF64
    | @lib.Instruction::F64ConvertI32S
    | @lib.Instruction::F64ConvertI32U
    | @lib.Instruction::F64ConvertI64S
    | @lib.Instruction::F64ConvertI64U
    | @lib.Instruction::F64PromoteF32
    | @lib.Instruction::I32ReinterpretF32
    | @lib.Instruction::I64ReinterpretF64
    | @lib.Instruction::F32ReinterpretI32
    | @lib.Instruction::F64ReinterpretI64
    | @lib.Instruction::I32Extend8S
    | @lib.Instruction::I32Extend16S
    | @lib.Instruction::I64Extend8S
    | @lib.Instruction::I64Extend16S
    | @lib.Instruction::I64Extend32S
    | @lib.Instruction::I32TruncSatF32S
    | @lib.Instruction::I32TruncSatF32U
    | @lib.Instruction::I32TruncSatF64S
    | @lib.Instruction::I32TruncSatF64U
    | @lib.Instruction::I64TruncSatF32S
    | @lib.Instruction::I64TruncSatF32U
    | @lib.Instruction::I64TruncSatF64S
    | @lib.Instruction::I64TruncSatF64U
    | @lib.Instruction::RefTest(_, _)
    | @lib.Instruction::AnyConvertExtern
    | @lib.Instruction::ExternConvertAny
    | @lib.Instruction::RefAsNonNull
    | @lib.Instruction::RefCast(_, _)
    | @lib.Instruction::RefI31
    | @lib.Instruction::I32TruncF32S
    | @lib.Instruction::I32TruncF32U
    | @lib.Instruction::I32TruncF64S
    | @lib.Instruction::I32TruncF64U
    | @lib.Instruction::I64TruncF32S
    | @lib.Instruction::I64TruncF32U
    | @lib.Instruction::I64TruncF64S
    | @lib.Instruction::I64TruncF64U
    | @lib.Instruction::I31GetS
    | @lib.Instruction::I31GetU
    | @lib.Instruction::StructGet(_, _)
    | @lib.Instruction::StructGetS(_, _)
    | @lib.Instruction::StructGetU(_, _)
    | @lib.Instruction::ArrayLen => Some(1)
    @lib.Instruction::StructSet(_, _) | @lib.Instruction::TableSet(_) => Some(2)
    @lib.Instruction::TableGet(_) => Some(1)
    @lib.Instruction::TableGrow(_) => Some(2)
    @lib.Instruction::ArrayGet(_)
    | @lib.Instruction::ArrayGetS(_)
    | @lib.Instruction::ArrayGetU(_) => Some(2)
    @lib.Instruction::ArraySet(_) => Some(3)
    @lib.Instruction::ArrayFill(_) => Some(4)
    @lib.Instruction::ArrayCopy(_, _) => Some(5)
    @lib.Instruction::ArrayInitData(_, _) => Some(4)
    @lib.Instruction::ArrayInitElem(_, _) => Some(4)
    @lib.Instruction::MemoryCopy(_, _)
    | @lib.Instruction::MemoryFill(_)
    | @lib.Instruction::MemoryInit(_, _)
    | @lib.Instruction::TableCopy(_, _)
    | @lib.Instruction::TableFill(_)
    | @lib.Instruction::TableInit(_, _) => Some(3)
    @lib.Instruction::V128Load8Lane(_, _)
    | @lib.Instruction::V128Load16Lane(_, _)
    | @lib.Instruction::V128Load32Lane(_, _)
    | @lib.Instruction::V128Load64Lane(_, _) => Some(2)
    _ =>
      match lcse_simd_pure_operand_count(instr) {
        Some(count) => Some(count)
        None =>
          if lcse_instr_is_store(instr) {
            Some(2)
          } else if lcse_instr_is_load(instr) ||
            lcse_instr_is_simd_memory_load(instr) {
            Some(1)
          } else {
            None
          }
      }
  }
}

///|
fn lcse_ref_as_non_null_result_type(
  child_exprs : Array[LcseRawExpr],
) -> @lib.ValType? {
  match child_exprs.get(0) {
    Some({ ty: @lib.RefTypeValType(ref_type), .. }) =>
      Some(
        @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            ref_type.get_heap_type(),
            exact=ref_type.is_exact(),
          ),
        ),
      )
    _ => None
  }
}

///|
fn lcse_raw_subtype_for_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> @lib.SubType? {
  match type_idx {
    @lib.TypeIdx(type_pos) => subtypes.get(type_pos.reinterpret_as_int())
    @lib.RecIdx(_) => None
  }
}

///|
fn lcse_raw_struct_field_type(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
) -> @lib.ValType? {
  let subtype = match lcse_raw_subtype_for_idx(subtypes, type_idx) {
    Some(st) => st
    None => return None
  }
  match subtype.get_comptype() {
    @lib.StructCompType(fields) => {
      let @lib.U32(raw_field_idx) = field_idx
      match fields.get(raw_field_idx.reinterpret_as_int()) {
        Some(@lib.FieldType(storage, _)) => Some(storage.unpack())
        None => None
      }
    }
    _ => None
  }
}

///|
fn lcse_raw_array_field_type(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> @lib.ValType? {
  let subtype = match lcse_raw_subtype_for_idx(subtypes, type_idx) {
    Some(st) => st
    None => return None
  }
  match subtype.get_comptype() {
    @lib.ArrayCompType(@lib.FieldType(storage, _)) => Some(storage.unpack())
    _ => None
  }
}

///|
fn lcse_raw_result_type(
  instr : @lib.Instruction,
  all_locals : Array[@lib.ValType],
  child_exprs : Array[LcseRawExpr],
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> @lib.ValType? {
  match instr {
    @lib.Instruction::LocalGet(idx) | @lib.Instruction::LocalTee(idx) =>
      match all_locals.get(cl_local_idx_raw(idx)) {
        Some(ty) => Some(ty)
        None => None
      }
    @lib.Instruction::I32Const(_)
    | @lib.Instruction::I32Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_)
    | @lib.Instruction::RefIsNull
    | @lib.Instruction::MemorySize(_)
    | @lib.Instruction::MemoryGrow(_)
    | @lib.Instruction::TableSize(_)
    | @lib.Instruction::TableGrow(_)
    | @lib.Instruction::I32WrapI64
    | @lib.Instruction::I32ReinterpretF32
    | @lib.Instruction::I32Extend8S
    | @lib.Instruction::I32Extend16S
    | @lib.Instruction::I32TruncSatF32S
    | @lib.Instruction::I32TruncSatF32U
    | @lib.Instruction::I32TruncSatF64S
    | @lib.Instruction::I32TruncSatF64U
    | @lib.Instruction::I32TruncF32S
    | @lib.Instruction::I32TruncF32U
    | @lib.Instruction::I32TruncF64S
    | @lib.Instruction::I32TruncF64U
    | @lib.Instruction::RefTest(_, _)
    | @lib.Instruction::I31GetS
    | @lib.Instruction::I31GetU
    | @lib.Instruction::StructGetS(_, _)
    | @lib.Instruction::StructGetU(_, _)
    | @lib.Instruction::ArrayGetS(_)
    | @lib.Instruction::ArrayGetU(_)
    | @lib.Instruction::ArrayLen => Some(@lib.ValType::i32())
    @lib.Instruction::I64Const(_)
    | @lib.Instruction::I64Load(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_)
    | @lib.Instruction::I64ExtendI32S
    | @lib.Instruction::I64ExtendI32U
    | @lib.Instruction::I64ReinterpretF64
    | @lib.Instruction::I64Extend8S
    | @lib.Instruction::I64Extend16S
    | @lib.Instruction::I64Extend32S
    | @lib.Instruction::I64TruncSatF32S
    | @lib.Instruction::I64TruncSatF32U
    | @lib.Instruction::I64TruncSatF64S
    | @lib.Instruction::I64TruncSatF64U
    | @lib.Instruction::I64TruncF32S
    | @lib.Instruction::I64TruncF32U
    | @lib.Instruction::I64TruncF64S
    | @lib.Instruction::I64TruncF64U => Some(@lib.ValType::i64())
    @lib.Instruction::F32Const(_)
    | @lib.Instruction::F32Load(_)
    | @lib.Instruction::F32Abs
    | @lib.Instruction::F32Neg
    | @lib.Instruction::F32Ceil
    | @lib.Instruction::F32Floor
    | @lib.Instruction::F32Trunc
    | @lib.Instruction::F32Nearest
    | @lib.Instruction::F32Sqrt
    | @lib.Instruction::F32Add
    | @lib.Instruction::F32Sub
    | @lib.Instruction::F32Mul
    | @lib.Instruction::F32Div
    | @lib.Instruction::F32Min
    | @lib.Instruction::F32Max
    | @lib.Instruction::F32Copysign
    | @lib.Instruction::F32ConvertI32S
    | @lib.Instruction::F32ConvertI32U
    | @lib.Instruction::F32ConvertI64S
    | @lib.Instruction::F32ConvertI64U
    | @lib.Instruction::F32DemoteF64
    | @lib.Instruction::F32ReinterpretI32 => Some(@lib.ValType::f32())
    @lib.Instruction::F64Const(_)
    | @lib.Instruction::F64Load(_)
    | @lib.Instruction::F64Abs
    | @lib.Instruction::F64Neg
    | @lib.Instruction::F64Ceil
    | @lib.Instruction::F64Floor
    | @lib.Instruction::F64Trunc
    | @lib.Instruction::F64Nearest
    | @lib.Instruction::F64Sqrt
    | @lib.Instruction::F64Add
    | @lib.Instruction::F64Sub
    | @lib.Instruction::F64Mul
    | @lib.Instruction::F64Div
    | @lib.Instruction::F64Min
    | @lib.Instruction::F64Max
    | @lib.Instruction::F64Copysign
    | @lib.Instruction::F64ConvertI32S
    | @lib.Instruction::F64ConvertI32U
    | @lib.Instruction::F64ConvertI64S
    | @lib.Instruction::F64ConvertI64U
    | @lib.Instruction::F64PromoteF32
    | @lib.Instruction::F64ReinterpretI64 => Some(@lib.ValType::f64())
    @lib.Instruction::RefNull(ty) => Some(@lib.ValType::ref_type(ty))
    @lib.Instruction::RefAsNonNull =>
      lcse_ref_as_non_null_result_type(child_exprs)
    @lib.Instruction::RefCast(nullable, heap_type) =>
      Some(@lib.ValType::ref_type(@lib.RefType::new(nullable, heap_type)))
    @lib.Instruction::RefI31 => Some(@lib.ValType::i31ref())
    @lib.Instruction::V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.Instruction::V128Load(_)
    | @lib.Instruction::V128Load8x8S(_)
    | @lib.Instruction::V128Load8x8U(_)
    | @lib.Instruction::V128Load16x4S(_)
    | @lib.Instruction::V128Load16x4U(_)
    | @lib.Instruction::V128Load32x2S(_)
    | @lib.Instruction::V128Load32x2U(_)
    | @lib.Instruction::V128Load8Splat(_)
    | @lib.Instruction::V128Load16Splat(_)
    | @lib.Instruction::V128Load32Splat(_)
    | @lib.Instruction::V128Load64Splat(_)
    | @lib.Instruction::V128Load32Zero(_)
    | @lib.Instruction::V128Load64Zero(_)
    | @lib.Instruction::V128Load8Lane(_, _)
    | @lib.Instruction::V128Load16Lane(_, _)
    | @lib.Instruction::V128Load32Lane(_, _)
    | @lib.Instruction::V128Load64Lane(_, _) => Some(@lib.ValType::v128())
    @lib.Instruction::AnyConvertExtern => Some(@lib.ValType::anyref())
    @lib.Instruction::ExternConvertAny => Some(@lib.ValType::externref())
    @lib.Instruction::RefFunc(_) | @lib.Instruction::TableGet(_) =>
      Some(@lib.ValType::funcref())
    @lib.Instruction::StructGet(type_idx, field_idx) =>
      lcse_raw_struct_field_type(subtypes, type_idx, field_idx)
    @lib.Instruction::ArrayGet(type_idx) =>
      lcse_raw_array_field_type(subtypes, type_idx)
    @lib.Instruction::Select(_) =>
      match child_exprs.get(0) {
        Some(expr) => Some(expr.ty)
        None => None
      }
    @lib.Instruction::Call(idx) =>
      match lcse_raw_call_info(call_infos, idx) {
        Some({ result: Some(ty), idempotent: true, .. }) => Some(ty)
        _ => None
      }
    @lib.Instruction::I32Add
    | @lib.Instruction::I32Sub
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I32DivS
    | @lib.Instruction::I32DivU
    | @lib.Instruction::I32RemS
    | @lib.Instruction::I32RemU
    | @lib.Instruction::I32Clz
    | @lib.Instruction::I32Ctz
    | @lib.Instruction::I32Popcnt
    | @lib.Instruction::I32And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr => Some(@lib.ValType::i32())
    @lib.Instruction::I64Add
    | @lib.Instruction::I64Sub
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I64DivS
    | @lib.Instruction::I64DivU
    | @lib.Instruction::I64RemS
    | @lib.Instruction::I64RemU
    | @lib.Instruction::I64Clz
    | @lib.Instruction::I64Ctz
    | @lib.Instruction::I64Popcnt
    | @lib.Instruction::I64And
    | @lib.Instruction::I64Or
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr => Some(@lib.ValType::i64())
    @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I32Eqz
    | @lib.Instruction::I32LtS
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I64Eqz
    | @lib.Instruction::I64LtS
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GtU
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64GeU
    | @lib.Instruction::F32Eq
    | @lib.Instruction::F32Ne
    | @lib.Instruction::F32Lt
    | @lib.Instruction::F32Gt
    | @lib.Instruction::F32Le
    | @lib.Instruction::F32Ge
    | @lib.Instruction::F64Eq
    | @lib.Instruction::F64Ne
    | @lib.Instruction::F64Lt
    | @lib.Instruction::F64Gt
    | @lib.Instruction::F64Le
    | @lib.Instruction::F64Ge
    | @lib.Instruction::RefEq => Some(@lib.ValType::i32())
    _ => lcse_simd_pure_result_type(instr)
  }
}

///|
fn lcse_cancel_request_tree(exprs : Array[LcseRawExpr], expr_id : Int) -> Unit {
  if expr_id < 0 || expr_id >= exprs.length() {
    return
  }
  exprs[expr_id].repeat_of = -1
  for child in exprs[expr_id].children {
    lcse_cancel_request_tree(exprs, child)
  }
}

///|
fn lcse_raw_expr_profitable(expr : LcseRawExpr) -> Bool {
  expr.size >= 2
}

///|
fn lcse_raw_instr_caches_child_for_replay(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::RefAsNonNull
    | @lib.Instruction::RefCast(false, _)
    | @lib.Instruction::RefI31 => true
    _ => false
  }
}

///|
fn lcse_raw_child_cache_type(
  exprs : Array[LcseRawExpr],
  expr : LcseRawExpr,
) -> @lib.ValType? {
  if !expr.cache_child_for_replay || expr.children.length() != 1 {
    return None
  }
  match exprs.get(expr.children[0]) {
    Some({ ty: @lib.RefTypeValType(ref_type), .. }) =>
      Some(
        @lib.ValType::ref_type(
          @lib.RefType::new(
            true,
            ref_type.get_heap_type(),
            exact=ref_type.is_exact(),
          ),
        ),
      )
    Some(child) => Some(child.ty)
    None => None
  }
}

///|
fn lcse_raw_can_cache_child_for_replay(
  exprs : Array[LcseRawExpr],
  children : Array[Int],
) -> Bool {
  match children {
    [child_id] =>
      match exprs.get(child_id) {
        Some(child) => @lib.has_default(child.ty)
        None => false
      }
    _ => false
  }
}

///|
fn lcse_raw_filter_active_without_memory(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
) -> Unit {
  let keep : Array[Int] = []
  for expr_id in active {
    if expr_id >= 0 && expr_id < exprs.length() && !exprs[expr_id].reads_memory {
      keep.push(expr_id)
    }
  }
  active.clear()
  for expr_id in keep {
    active.push(expr_id)
  }
}

///|
fn lcse_raw_filter_active_without_memory_or_size(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
) -> Unit {
  let keep : Array[Int] = []
  for expr_id in active {
    if expr_id >= 0 &&
      expr_id < exprs.length() &&
      !exprs[expr_id].reads_memory &&
      !exprs[expr_id].reads_memory_size {
      keep.push(expr_id)
    }
  }
  active.clear()
  for expr_id in keep {
    active.push(expr_id)
  }
}

///|
fn lcse_raw_expr_reads_local(expr : LcseRawExpr, local_idx : Int) -> Bool {
  for read_idx in expr.reads_locals {
    if read_idx == local_idx {
      return true
    }
  }
  false
}

///|
fn lcse_raw_filter_active_without_local(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
  local_idx : Int,
) -> Unit {
  let keep : Array[Int] = []
  for expr_id in active {
    if expr_id >= 0 &&
      expr_id < exprs.length() &&
      !lcse_raw_expr_reads_local(exprs[expr_id], local_idx) {
      keep.push(expr_id)
    }
  }
  active.clear()
  for expr_id in keep {
    active.push(expr_id)
  }
}

///|
fn lcse_raw_filter_active_local_only(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
) -> Unit {
  let keep : Array[Int] = []
  for expr_id in active {
    if expr_id >= 0 && expr_id < exprs.length() {
      let expr = exprs[expr_id]
      if !expr.reads_memory &&
        !expr.reads_memory_size &&
        !expr.reads_table_state &&
        !expr.reads_global &&
        !expr.reads_heap {
        keep.push(expr_id)
      }
    }
  }
  active.clear()
  for expr_id in keep {
    active.push(expr_id)
  }
}

///|
fn lcse_raw_filter_active_without_heap(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
) -> Unit {
  let keep : Array[Int] = []
  for expr_id in active {
    if expr_id >= 0 && expr_id < exprs.length() && !exprs[expr_id].reads_heap {
      keep.push(expr_id)
    }
  }
  active.clear()
  for expr_id in keep {
    active.push(expr_id)
  }
}

///|
fn lcse_raw_exprs_match(
  exprs : Array[LcseRawExpr],
  lhs_id : Int,
  instr : @lib.Instruction,
  children : Array[Int],
) -> Bool {
  if lhs_id < 0 || lhs_id >= exprs.length() {
    return false
  }
  let lhs = exprs[lhs_id]
  if lhs.instr != instr || lhs.children.length() != children.length() {
    return false
  }
  for idx = 0; idx < children.length(); idx = idx + 1 {
    let rhs_child = children[idx]
    let lhs_child = lhs.children[idx]
    if rhs_child < 0 ||
      rhs_child >= exprs.length() ||
      lhs_child < 0 ||
      lhs_child >= exprs.length() {
      return false
    }
    if exprs[rhs_child].key != exprs[lhs_child].key {
      return false
    }
  }
  true
}

///|
fn lcse_raw_find_active_match(
  exprs : Array[LcseRawExpr],
  active : Array[Int],
  instr : @lib.Instruction,
  children : Array[Int],
) -> Int {
  for active_id in active {
    if lcse_raw_exprs_match(exprs, active_id, instr, children) {
      return active_id
    }
  }
  -1
}

///|
fn lcse_raw_instr_slice_matches(
  instrs : Array[@lib.Instruction],
  start : Int,
  end : Int,
  body : Array[@lib.Instruction],
  body_start : Int,
) -> Bool {
  let len = end - start + 1
  if len <= 0 || body_start + len > body.length() {
    return false
  }
  for offset = 0; offset < len; offset = offset + 1 {
    if instrs[start + offset] != body[body_start + offset] {
      return false
    }
  }
  true
}

///|
fn lcse_raw_instr_clears_nested_window(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::LocalSet(_) | @lib.Instruction::LocalTee(_) => true
    @lib.Instruction::Call(_) => false
    @lib.Instruction::CallIndirect(_, _) | @lib.Instruction::CallRef(_) => true
    @lib.Instruction::Br(_)
    | @lib.Instruction::BrTable(_, _)
    | @lib.Instruction::Return
    | @lib.Instruction::ReturnCall(_)
    | @lib.Instruction::ReturnCallIndirect(_, _)
    | @lib.Instruction::ReturnCallRef(_)
    | @lib.Instruction::Throw(_)
    | @lib.Instruction::ThrowRef
    | @lib.Instruction::Unreachable => true
    _ => lcse_instr_is_store(instr)
  }
}

///|
fn lcse_raw_scan_nested_repeats(
  parent_idx : Int,
  outer_instrs : Array[@lib.Instruction],
  body : Array[@lib.Instruction],
  exprs : Array[LcseRawExpr],
  outer_active : Array[Int],
  repeats : Array[LcseRawNestedRepeat],
  call_infos : Array[LcseRawCallInfo],
) -> Unit {
  if body.length() > 16 || outer_active.length() == 0 {
    return
  }
  let active = outer_active.copy()
  let mut idx = 0
  while idx < body.length() {
    let mut best_original = -1
    let mut best_end = -1
    let mut best_size = -1
    for original_id in active {
      let original = exprs[original_id]
      if lcse_raw_expr_profitable(original) &&
        original.size > best_size &&
        lcse_raw_instr_slice_matches(
          outer_instrs,
          original.start,
          original.end,
          body,
          idx,
        ) {
        best_original = original_id
        best_end = idx + original.end - original.start
        best_size = original.size
      }
    }
    if best_original >= 0 {
      repeats.push({
        parent_idx,
        start: idx,
        end: best_end,
        original: best_original,
      })
      idx = best_end + 1
      continue
    }
    match body[idx] {
      @lib.Instruction::Call(call_idx) =>
        if !lcse_raw_call_is_idempotent(call_infos, call_idx) {
          active.clear()
        }
      other => if lcse_raw_instr_clears_nested_window(other) { active.clear() }
    }
    idx += 1
  }
}

///|
fn lcse_raw_nested_repeat_for_parent(
  repeats : Array[LcseRawNestedRepeat],
  parent_idx : Int,
  start : Int,
) -> LcseRawNestedRepeat? {
  for repeat in repeats {
    if repeat.parent_idx == parent_idx && repeat.start == start {
      return Some(repeat)
    }
  }
  None
}

///|
fn lcse_raw_push_replay(
  out : Array[@lib.Instruction],
  expr : LcseRawExpr,
  local_id : Int,
) -> Unit {
  out.push(
    @lib.Instruction::local_get(
      @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
    ),
  )
  if expr.cache_child_for_replay {
    out.push(expr.instr)
  }
}

///|
fn lcse_raw_original_materialize_end(
  exprs : Array[LcseRawExpr],
  original : LcseRawExpr,
) -> Int {
  if original.cache_child_for_replay && original.children.length() == 1 {
    match exprs.get(original.children[0]) {
      Some(child) => return child.end
      None => ()
    }
  }
  original.end
}

///|
fn lcse_raw_original_materialize_type(
  exprs : Array[LcseRawExpr],
  original : LcseRawExpr,
) -> @lib.ValType {
  match lcse_raw_child_cache_type(exprs, original) {
    Some(ty) => ty
    None => original.ty
  }
}

///|
fn lcse_raw_rewrite_nested_with_outer_repeats(
  body : Array[@lib.Instruction],
  parent_idx : Int,
  repeats : Array[LcseRawNestedRepeat],
  exprs : Array[LcseRawExpr],
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < body.length() {
    match lcse_raw_nested_repeat_for_parent(repeats, parent_idx, i) {
      Some(repeat) => {
        let local_id = exprs[repeat.original].local_id
        if local_id >= 0 {
          lcse_raw_push_replay(out, exprs[repeat.original], local_id)
          changed = true
          i = repeat.end + 1
          continue
        }
      }
      None => ()
    }
    out.push(body[i])
    i += 1
  }
  (out, changed)
}

///|
fn lcse_raw_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  params : Array[@lib.ValType],
  local_types : Array[@lib.ValType],
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> (Array[@lib.Instruction], Bool) {
  if instrs.length() > 16 {
    return (instrs, false)
  }
  let all_locals = params.copy()
  for ty in local_types {
    all_locals.push(ty)
  }
  let exprs : Array[LcseRawExpr] = []
  let stack : Array[Int] = []
  let active : Array[Int] = []
  let nested_repeats : Array[LcseRawNestedRepeat] = []
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    let operand_count = match
      lcse_raw_instr_operand_count(instr, call_infos, subtypes) {
      Some(count) => count
      None => {
        match instr {
          @lib.Instruction::Block(_, @lib.Expr(body))
          | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
            lcse_raw_scan_nested_repeats(
              idx, instrs, body, exprs, active, nested_repeats, call_infos,
            )
          _ => ()
        }
        stack.clear()
        active.clear()
        continue
      }
    }
    let children : Array[Int] = []
    if stack.length() < operand_count {
      stack.clear()
      active.clear()
      continue
    }
    let first_child_stack = stack.length() - operand_count
    for child_idx = first_child_stack
        child_idx < stack.length()
        child_idx = child_idx + 1 {
      children.push(stack[child_idx])
    }
    for _ in 0..<operand_count {
      ignore(stack.pop())
    }
    match instr {
      @lib.Instruction::LocalSet(local_idx)
      | @lib.Instruction::LocalTee(local_idx) =>
        lcse_raw_filter_active_without_local(
          exprs,
          active,
          cl_local_idx_raw(local_idx),
        )
      @lib.Instruction::Call(call_idx) =>
        if !lcse_raw_call_is_idempotent(call_infos, call_idx) {
          lcse_raw_filter_active_local_only(exprs, active)
        }
      @lib.Instruction::CallIndirect(_, _) | @lib.Instruction::CallRef(_) =>
        active.clear()
      @lib.Instruction::MemoryGrow(_) =>
        lcse_raw_filter_active_without_memory_or_size(exprs, active)
      @lib.Instruction::MemoryCopy(_, _)
      | @lib.Instruction::MemoryFill(_)
      | @lib.Instruction::MemoryInit(_, _) =>
        lcse_raw_filter_active_without_memory(exprs, active)
      @lib.Instruction::StructSet(_, _)
      | @lib.Instruction::ArraySet(_)
      | @lib.Instruction::ArrayFill(_)
      | @lib.Instruction::ArrayCopy(_, _)
      | @lib.Instruction::ArrayInitData(_, _)
      | @lib.Instruction::ArrayInitElem(_, _) =>
        lcse_raw_filter_active_without_heap(exprs, active)
      _ =>
        if lcse_instr_is_store(instr) {
          lcse_raw_filter_active_without_memory(exprs, active)
        }
    }
    match instr {
      @lib.Instruction::BrOnNull(_)
      | @lib.Instruction::BrOnCast(_, _, _, _)
      | @lib.Instruction::BrOnCastFail(_, _, _, _) => {
        if children.length() == 1 {
          stack.push(children[0])
        }
        continue
      }
      _ => ()
    }
    match
      lcse_raw_result_type(
        instr,
        all_locals,
        children.map(fn(id) { exprs[id] }),
        call_infos,
        subtypes,
      ) {
      Some(ty) => {
        let mut start = idx
        let mut size = 1
        let reads_locals : Array[Int] = []
        let mut reads_memory = lcse_instr_reads_memory(instr)
        let mut reads_memory_size = match instr {
          @lib.Instruction::MemorySize(_) => true
          _ => false
        }
        let mut reads_table_state = match instr {
          @lib.Instruction::TableGet(_) | @lib.Instruction::TableSize(_) => true
          _ => false
        }
        let mut reads_global = match instr {
          @lib.Instruction::GlobalGet(_) => true
          _ => false
        }
        let mut reads_heap = match instr {
          @lib.Instruction::StructGet(_, _)
          | @lib.Instruction::StructGetS(_, _)
          | @lib.Instruction::StructGetU(_, _)
          | @lib.Instruction::ArrayGet(_)
          | @lib.Instruction::ArrayGetS(_)
          | @lib.Instruction::ArrayGetU(_)
          | @lib.Instruction::ArrayLen => true
          _ => false
        }
        for child in children {
          let child_expr = exprs[child]
          if child_expr.start < start {
            start = child_expr.start
          }
          size += child_expr.size
          for local_id in child_expr.reads_locals {
            if !reads_locals.contains(local_id) {
              reads_locals.push(local_id)
            }
          }
          if child_expr.reads_memory {
            reads_memory = true
          }
          if child_expr.reads_memory_size {
            reads_memory_size = true
          }
          if child_expr.reads_table_state {
            reads_table_state = true
          }
          if child_expr.reads_global {
            reads_global = true
          }
          if child_expr.reads_heap {
            reads_heap = true
          }
        }
        match instr {
          @lib.Instruction::LocalGet(local_idx) => {
            let local_id = cl_local_idx_raw(local_idx)
            if !reads_locals.contains(local_id) {
              reads_locals.push(local_id)
            }
          }
          _ => ()
        }
        let expr_id = exprs.length()
        let cache_child_for_replay = lcse_raw_instr_caches_child_for_replay(
          instr,
        )
        let can_cache_child_for_replay = !cache_child_for_replay ||
          lcse_raw_can_cache_child_for_replay(exprs, children)
        let reusable_root = match instr {
          @lib.Instruction::MemoryGrow(_) | @lib.Instruction::TableGrow(_) =>
            false
          _ => !reads_table_state && can_cache_child_for_replay
        }
        let materializable_root = cache_child_for_replay || @lib.has_default(ty)
        let key_match_id = if reusable_root && size <= 32 {
          lcse_raw_find_active_match(exprs, active, instr, children)
        } else {
          -1
        }
        let original_id = if materializable_root { key_match_id } else { -1 }
        let canonical_key = if key_match_id >= 0 {
          exprs[key_match_id].key
        } else {
          expr_id
        }
        let expr = {
          start,
          end: idx,
          instr,
          key: canonical_key,
          ty,
          size,
          children,
          reads_locals,
          reads_memory,
          reads_memory_size,
          reads_table_state,
          reads_global,
          reads_heap,
          cache_child_for_replay,
          repeat_of: -1,
          local_id: -1,
        }
        exprs.push(expr)
        if original_id >= 0 {
          if lcse_raw_expr_profitable(expr) {
            exprs[expr_id].repeat_of = original_id
            for child in children {
              lcse_cancel_request_tree(exprs, child)
            }
          }
        } else if reusable_root {
          active.push(expr_id)
        }
        stack.push(expr_id)
      }
      None => ()
    }
    match instr {
      @lib.Instruction::If(_, then_body, _) => {
        lcse_raw_scan_nested_repeats(
          idx, instrs, then_body, exprs, active, nested_repeats, call_infos,
        )
        active.clear()
      }
      _ => ()
    }
  }
  let repeat_start = Array::make(instrs.length(), -1)
  let original_end = Array::make(instrs.length(), -1)
  for expr_id = 0; expr_id < exprs.length(); expr_id = expr_id + 1 {
    let expr = exprs[expr_id]
    if expr.repeat_of >= 0 {
      repeat_start[expr.start] = expr_id
      let original = exprs[expr.repeat_of]
      let materialize_end = lcse_raw_original_materialize_end(exprs, original)
      original_end[materialize_end] = expr.repeat_of
    }
  }
  for repeat in nested_repeats {
    let original = exprs[repeat.original]
    let materialize_end = lcse_raw_original_materialize_end(exprs, original)
    if materialize_end >= 0 && materialize_end < original_end.length() {
      original_end[materialize_end] = repeat.original
    }
  }
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    let repeat_id = repeat_start[i]
    if repeat_id >= 0 {
      let original_id = exprs[repeat_id].repeat_of
      let local_id = exprs[original_id].local_id
      if local_id >= 0 {
        lcse_raw_push_replay(out, exprs[repeat_id], local_id)
        changed = true
        i = exprs[repeat_id].end + 1
        continue
      }
    }
    let rewritten_instr = match instrs[i] {
      @lib.Instruction::Block(block_type, @lib.Expr(body)) => {
        let (outer_body, outer_body_changed) = lcse_raw_rewrite_nested_with_outer_repeats(
          body, i, nested_repeats, exprs,
        )
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          outer_body, params, local_types, call_infos, subtypes,
        )
        if outer_body_changed || body_changed {
          changed = true
        }
        @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::Loop(block_type, @lib.Expr(body)) => {
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          body, params, local_types, call_infos, subtypes,
        )
        if body_changed {
          changed = true
        }
        @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body))
      }
      @lib.Instruction::If(block_type, then_body, else_body) => {
        let (outer_then, outer_then_changed) = lcse_raw_rewrite_nested_with_outer_repeats(
          then_body, i, nested_repeats, exprs,
        )
        let (next_then, then_changed) = lcse_raw_rewrite_instrs(
          outer_then, params, local_types, call_infos, subtypes,
        )
        let (next_else, else_changed) = match else_body {
          Some(body) => {
            let (body2, changed2) = lcse_raw_rewrite_instrs(
              body, params, local_types, call_infos, subtypes,
            )
            (Some(body2), changed2)
          }
          None => (None, false)
        }
        if outer_then_changed || then_changed || else_changed {
          changed = true
        }
        @lib.Instruction::if_(block_type, next_then, next_else)
      }
      @lib.Instruction::TryTable(block_type, catches, @lib.Expr(body)) => {
        let (outer_body, outer_body_changed) = lcse_raw_rewrite_nested_with_outer_repeats(
          body, i, nested_repeats, exprs,
        )
        let (next_body, body_changed) = lcse_raw_rewrite_instrs(
          outer_body, params, local_types, call_infos, subtypes,
        )
        if outer_body_changed || body_changed {
          changed = true
        }
        @lib.Instruction::try_table(
          block_type,
          catches,
          @lib.Expr::new(next_body),
        )
      }
      other => other
    }
    out.push(rewritten_instr)
    let original_id = original_end[i]
    if original_id >= 0 {
      let local_id = params.length() + local_types.length()
      local_types.push(
        lcse_raw_original_materialize_type(exprs, exprs[original_id]),
      )
      exprs[original_id].local_id = local_id
      out.push(
        @lib.Instruction::local_tee(
          @lib.LocalIdx::new(local_id.reinterpret_as_uint()),
        ),
      )
      changed = true
    }
    i += 1
  }
  (out, changed)
}

///|
fn lcse_raw_rewrite_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
  call_infos : Array[LcseRawCallInfo],
  subtypes : Array[@lib.SubType],
) -> LcseRawRewrite {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let has_repeated_candidate = lcse_instrs_may_have_repeated_candidate(instrs)
  let has_dropped_unreachable_debris = lcse_instrs_may_have_dropped_unreachable_before_unreachable(
    instrs,
  )
  if !has_repeated_candidate && !has_dropped_unreachable_debris {
    return { func, changed: false }
  }
  let local_types = cl_flatten_locals(locals, locals.length())
  let (rewritten, rewrite_changed) = if has_repeated_candidate {
    lcse_raw_rewrite_instrs(instrs, params, local_types, call_infos, subtypes)
  } else {
    (instrs, false)
  }
  let (cleaned, cleanup_changed) = lcse_raw_remove_dropped_unreachable_debris(
    rewritten,
  )
  if rewrite_changed || cleanup_changed {
    {
      func: @lib.Func::new(
        @lib.Locals::from_types(local_types),
        @lib.Expr::new(cleaned),
      ),
      changed: true,
    }
  } else {
    { func, changed: false }
  }
}

///|
fn local_cse_run_raw_func_with_params(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> (@lib.Func, Bool) {
  let rewrite = lcse_raw_rewrite_func(func, params, [], [])
  (rewrite.func, rewrite.changed)
}

///|
fn lcse_raw_func_type_for_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> @lib.FuncType? {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => return None
      }
    @lib.RecIdx(_) => return None
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, results) =>
      Some(@lib.FuncType::new(params, results))
    _ => None
  }
}

///|
fn lcse_raw_func_has_idempotent_annotation(
  sec : @lib.FuncAnnotationSec?,
  func_idx : UInt,
) -> Bool {
  match sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(idx, annotations) = entry
        if idx == func_idx {
          for annotation in annotations {
            if annotation.name == "binaryen.idempotent" &&
              annotation.args.length() == 0 {
              return true
            }
          }
        }
      }
    None => ()
  }
  false
}

///|
fn lcse_raw_module_call_infos(mod_ : @lib.Module) -> Array[LcseRawCallInfo] {
  let subtypes = cl_module_subtypes(mod_)
  let type_idxs : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for im in imports {
        match im {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            type_idxs.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(func_type_idxs)) =>
      for type_idx in func_type_idxs {
        type_idxs.push(type_idx)
      }
    None => ()
  }
  let out : Array[LcseRawCallInfo] = []
  for idx = 0; idx < type_idxs.length(); idx = idx + 1 {
    match lcse_raw_func_type_for_idx(subtypes, type_idxs[idx]) {
      Some(@lib.FuncType(params, results)) => {
        let result = match results {
          [ty] => Some(ty)
          _ => None
        }
        out.push({
          params,
          result,
          idempotent: lcse_raw_func_has_idempotent_annotation(
            mod_.func_annotation_sec,
            idx.reinterpret_as_uint(),
          ),
        })
      }
      None => out.push({ params: [], result: None, idempotent: false })
    }
  }
  out
}

///|
pub fn local_cse_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let params = cl_defined_func_param_cache(mod_)
      let call_infos = lcse_raw_module_call_infos(mod_)
      let subtypes = cl_module_subtypes(mod_)
      let rewritten : Array[@lib.Func] = []
      let mut changed = false
      for idx = 0; idx < funcs.length(); idx = idx + 1 {
        let rewrite = lcse_raw_rewrite_func(
          funcs[idx],
          params[idx],
          call_infos,
          subtypes,
        )
        rewritten.push(rewrite.func)
        if rewrite.changed {
          changed = true
        }
      }
      if !changed {
        return mod_
      }
      cl_rebuild_module(
        mod_,
        Some(@lib.CodeSec::new(rewritten)),
        cl_name_sec_without_local_names(mod_.name_sec),
      )
    }
    None => mod_
  }
}

///|
priv enum LcsePlace {
  Region(@ir.HotRegionRef, Int)
  Child(Int, Int)
}

///|
priv struct LcseBinding {
  original : Int
  place : LcsePlace
  mut local_id : Int
  ty : @lib.ValType
}

///|
priv struct LcseState {
  mut bindings : @hashmap.HashMap[String, LcseBinding]
}

///|
fn LcseState::new() -> LcseState {
  { bindings: @hashmap.new(capacity=64) }
}

///|
fn lcse_result_type(func : @ir.HotFunc, node_id : Int) -> @lib.ValType? {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [ty] => Some(ty)
    _ => None
  }
}

///|
fn lcse_node_exact_suffix(func : @ir.HotFunc, node_id : Int) -> String {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => ":instr=\{@debug.to_string(instr)}"
    None => ""
  }
}

///|
fn lcse_tree_key(func : @ir.HotFunc, node_id : Int) -> String? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut key = "op=\{node.op};results=\{@ir.hot_type_results(func, node.ty)};imm0=\{node.imm0};imm1=\{node.imm1};flags=\{node.flags}\{lcse_node_exact_suffix(func, node_id)}("
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    match lcse_tree_key(func, @ir.hot_child_get(func, node_id, slot)) {
      Some(child_key) => key = key + child_key + ","
      None => return None
    }
  }
  Some(key + ")")
}

///|
fn lcse_tree_size(func : @ir.HotFunc, node_id : Int) -> Int {
  let mut size = 1
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    size += lcse_tree_size(func, @ir.hot_child_get(func, node_id, slot))
  }
  size
}

///|
fn lcse_effect_mask_allowed(mask : @ir.EffectMask) -> Bool {
  // Allow pure trees and repeated loads. The linear window is cleared by memory,
  // local, global, table, call, throw, and control barriers before a later use can
  // reuse stale state.
  let allowed = @ir.EFFECT_MASK_MEMORY_READ |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_LOCAL_STATE
  (mask | allowed) == allowed
}

///|
fn lcse_candidate_key(func : @ir.HotFunc, node_id : Int) -> String? {
  let node = @ir.hot_node_get(func, node_id)
  if lcse_result_type(func, node_id) is None {
    return None
  }
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => return None
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee | @ir.HotOp::Drop => return None
    @ir.HotOp::Atomic => return None
    _ => ()
  }
  if lcse_tree_size(func, node_id) < 2 {
    return None
  }
  lcse_tree_key(func, node_id)
}

///|
fn lcse_barrier_clears_window(func : @ir.HotFunc, node_id : Int) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => false
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => true
    @ir.HotOp::LocalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => false
    _ => {
      let mask = @ir.effects_for_node(func, node_id)
      !lcse_effect_mask_allowed(mask)
    }
  }
}

///|
fn lcse_wrap_original(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  binding : LcseBinding,
) -> Int {
  if binding.local_id >= 0 {
    return binding.local_id
  }
  let local_id = @ir.hot_append_body_local(func, binding.ty)
  let tee_id = @ir.hot_build_local_tee(func, local_id, binding.original)
  match binding.place {
    LcsePlace::Region(region_ref, idx) =>
      ignore(@ir.hot_region_set(func, region_ref, idx, tee_id))
    LcsePlace::Child(parent_id, slot) =>
      @ir.hot_child_set(func, parent_id, slot, tee_id)
  }
  binding.local_id = local_id
  pass_mark_mutated(ctx, func)
  local_id
}

///|
fn lcse_replace_repeat(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  place : LcsePlace,
  local_id : Int,
) -> Unit {
  let get_id = @ir.hot_build_local_get(func, local_id)
  match place {
    LcsePlace::Region(region_ref, idx) =>
      ignore(@ir.hot_region_set(func, region_ref, idx, get_id))
    LcsePlace::Child(parent_id, slot) =>
      @ir.hot_child_set(func, parent_id, slot, get_id)
  }
  pass_mark_mutated(ctx, func)
}

///|
fn lcse_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : LcseState,
  node_id : Int,
  place : LcsePlace,
) -> Unit {
  match lcse_candidate_key(func, node_id) {
    Some(key) =>
      match state.bindings.get(key) {
        Some(binding) => {
          let local_id = lcse_wrap_original(ctx, func, binding)
          lcse_replace_repeat(ctx, func, place, local_id)
          return
        }
        None =>
          match lcse_result_type(func, node_id) {
            Some(ty) =>
              state.bindings.set(key, {
                original: node_id,
                place,
                local_id: -1,
                ty,
              })
            None => ()
          }
      }
    None => ()
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable => {
      lcse_visit_region(ctx, func, @ir.hot_region_body_ref(func, node_id))
      return
    }
    @ir.HotOp::If => {
      if @ir.hot_child_count(func, node_id) > 0 {
        let condition = @ir.hot_child_get(func, node_id, 0)
        if condition >= 0 && @ir.hot_node_is_live(func, condition) {
          lcse_visit_node(
            ctx,
            func,
            state,
            condition,
            LcsePlace::Child(node_id, 0),
          )
        }
      }
      lcse_visit_region(ctx, func, @ir.hot_region_then_ref(func, node_id))
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => lcse_visit_region(ctx, func, else_ref)
        None => ()
      }
      return
    }
    _ => ()
  }
  let count = @ir.hot_child_count(func, node_id)
  for slot = 0; slot < count; slot = slot + 1 {
    let child = @ir.hot_child_get(func, node_id, slot)
    if child >= 0 && @ir.hot_node_is_live(func, child) {
      lcse_visit_node(ctx, func, state, child, LcsePlace::Child(node_id, slot))
    }
  }
}

///|
fn lcse_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Unit {
  let state = LcseState::new()
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    if root < 0 || !@ir.hot_node_is_live(func, root) {
      continue
    }
    lcse_visit_node(ctx, func, state, root, LcsePlace::Region(region_ref, idx))
    if lcse_barrier_clears_window(func, root) {
      state.bindings = @hashmap.new(capacity=64)
    }
  }
}

///|
pub fn local_cse_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let before_revision = @ir.hot_revision_current(func)
  lcse_visit_region(ctx, func, @ir.HotRegionRef::root())
  if @ir.hot_revision_current(func) != before_revision {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
