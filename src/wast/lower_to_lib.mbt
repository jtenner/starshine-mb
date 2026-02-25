///|
priv struct WTLowerCtx {
  type_recs : Array[@lib.RecType]
  type_ids : Map[String, UInt]
  func_ids : Map[String, UInt]
  table_ids : Map[String, UInt]
  mem_ids : Map[String, UInt]
  global_ids : Map[String, UInt]
  elem_ids : Map[String, UInt]
  data_ids : Map[String, UInt]
  mut next_func_idx : UInt
  mut next_table_idx : UInt
  mut next_mem_idx : UInt
  mut next_global_idx : UInt
  mut next_elem_idx : UInt
  mut next_data_idx : UInt
}

///|
fn wt_new_ctx() -> WTLowerCtx {
  WTLowerCtx::{
    type_recs: [],
    type_ids: {},
    func_ids: {},
    table_ids: {},
    mem_ids: {},
    global_ids: {},
    elem_ids: {},
    data_ids: {},
    next_func_idx: 0U,
    next_table_idx: 0U,
    next_mem_idx: 0U,
    next_global_idx: 0U,
    next_elem_idx: 0U,
    next_data_idx: 0U,
  }
}

///|
fn wt_value_type(vt : ValueType) -> @lib.ValType {
  match vt {
    I32 => @lib.ValType::i32()
    I64 => @lib.ValType::i64()
    F32 => @lib.ValType::f32()
    F64 => @lib.ValType::f64()
    V128 => @lib.ValType::v128()
    FuncRef => @lib.ValType::funcref()
    ExternRef => @lib.ValType::externref()
  }
}

///|
fn wt_ref_heap_type(vt : ValueType) -> @lib.HeapType? {
  match vt {
    FuncRef => Some(@lib.HeapType::abs(@lib.AbsHeapType::func()))
    ExternRef => Some(@lib.HeapType::abs(@lib.AbsHeapType::extern_()))
    _ => None
  }
}

///|
fn wt_limits(lim : Limits) -> @lib.Limits {
  @lib.Limits::i32(lim.min, lim.max)
}

///|
fn wt_mem_arg(ma : MemArg) -> @lib.MemArg {
  @lib.MemArg::new(@lib.U32(ma.align), None, @lib.U64(ma.offset.to_uint64()))
}

///|
fn wt_func_sig(ft : FuncType) -> (Array[@lib.ValType], Array[@lib.ValType]) {
  let params : Array[@lib.ValType] = []
  for p in ft.params {
    params.push(wt_value_type(p))
  }
  let results : Array[@lib.ValType] = []
  for r in ft.results {
    results.push(wt_value_type(r))
  }
  (params, results)
}

///|
fn wt_append_type(ctx : WTLowerCtx, ft : FuncType) -> UInt {
  let (params, results) = wt_func_sig(ft)
  let rec = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func(params, results)),
  )
  let idx = ctx.type_recs.length().reinterpret_as_uint()
  ctx.type_recs.push(rec)
  idx
}

///|
fn wt_resolve_named_or_num_index(
  idx : Index,
  ids : Map[String, UInt],
  upper_bound : UInt,
  kind : String,
) -> Result[UInt, String] {
  match idx {
    Num(n) =>
      if n < upper_bound {
        Ok(n)
      } else {
        Err("invalid \{kind} index: \{n}")
      }
    Id(name) =>
      match ids.get(name) {
        Some(v) => Ok(v)
        None => Err("unknown \{kind} id: \{name}")
      }
  }
}

///|
fn wt_resolve_type_use(ctx : WTLowerCtx, tu : TypeUse) -> Result[UInt, String] {
  match tu.type_index {
    Some(idx) =>
      wt_resolve_named_or_num_index(
        idx,
        ctx.type_ids,
        ctx.type_recs.length().reinterpret_as_uint(),
        "type",
      )
    None => Ok(wt_append_type(ctx, tu.func_type))
  }
}

///|
fn wt_type_param_count(
  ctx : WTLowerCtx,
  type_idx : UInt,
) -> Result[UInt, String] {
  let mut flat = 0U
  for rec in ctx.type_recs {
    match rec {
      SingleRecType(CompTypeSubType(FuncCompType(params, _)))
      | SingleRecType(SubType(_, _, FuncCompType(params, _))) => {
        if flat == type_idx {
          return Ok(params.length().reinterpret_as_uint())
        }
        flat += 1
      }
      SingleRecType(_) => {
        if flat == type_idx {
          return Err(
            "type index does not reference a function type: \{type_idx}",
          )
        }
        flat += 1
      }
      GroupRecType(sts) =>
        for st in sts {
          match st {
            CompTypeSubType(FuncCompType(params, _))
            | SubType(_, _, FuncCompType(params, _)) =>
              if flat == type_idx {
                return Ok(params.length().reinterpret_as_uint())
              }
            _ =>
              if flat == type_idx {
                return Err(
                  "type index does not reference a function type: \{type_idx}",
                )
              }
          }
          flat += 1
        }
    }
  }
  Err("invalid type index: \{type_idx}")
}

///|
fn wt_resolve_label(
  idx : Index,
  labels : Array[String?],
) -> Result[UInt, String] {
  match idx {
    Num(n) =>
      if n < labels.length().reinterpret_as_uint() {
        Ok(n)
      } else {
        Err("invalid label index: \{n}")
      }
    Id(name) => {
      let mut i = labels.length() - 1
      while i >= 0 {
        match labels[i] {
          Some(label) if label == name =>
            return Ok((labels.length() - 1 - i).reinterpret_as_uint())
          _ => ()
        }
        i = i - 1
      }
      Err("unknown label id: \{name}")
    }
  }
}

///|
fn wt_parse_i32(text : String) -> Result[@lib.I32, String] {
  let v = @strconv.parse_int64(text) catch {
    _ => return Err("invalid i32 literal: \{text}")
  }
  Ok(@lib.I32(v.to_int()))
}

///|
fn wt_parse_i64(text : String) -> Result[@lib.I64, String] {
  let v = @strconv.parse_int64(text) catch {
    _ => return Err("invalid i64 literal: \{text}")
  }
  Ok(@lib.I64(v))
}

///|
fn wt_hex_digit_value(c : Int) -> Int {
  if c >= 0x30 && c <= 0x39 {
    c - 0x30
  } else if c >= 0x61 && c <= 0x66 {
    c - 0x61 + 10
  } else if c >= 0x41 && c <= 0x46 {
    c - 0x41 + 10
  } else {
    -1
  }
}

///|
fn wt_parse_hex_u64(text : String, kind : String) -> Result[UInt64, String] {
  if !(text.has_prefix("0x") || text.has_prefix("0X")) {
    return Err("invalid \{kind} literal: \{text}")
  }
  let mut value : UInt64 = 0UL
  let mut digits = 0
  for i = 2; i < text.length(); i = i + 1 {
    let c = text[i]
    if c == '_' {
      continue
    }
    let digit = wt_hex_digit_value(c.to_int())
    if digit < 0 {
      return Err("invalid \{kind} literal: \{text}")
    }
    digits = digits + 1
    if digits > 16 {
      return Err("invalid \{kind} literal: \{text}")
    }
    value = (value << 4) | digit.to_uint64()
  }
  if digits == 0 {
    return Err("invalid \{kind} literal: \{text}")
  }
  Ok(value)
}

///|
fn wt_parse_u64_decimal(text : String, kind : String) -> Result[UInt64, String] {
  let mut value : UInt64 = 0UL
  let mut digits = 0
  for i = 0; i < text.length(); i = i + 1 {
    let c = text[i]
    if c == '_' {
      continue
    }
    let code = c.to_int()
    if code < 0x30 || code > 0x39 {
      return Err("invalid \{kind} literal: \{text}")
    }
    let digit = (code - 0x30).to_uint64()
    if value > (18446744073709551615UL - digit) / 10UL {
      return Err("invalid \{kind} literal: \{text}")
    }
    value = value * 10UL + digit
    digits = digits + 1
  }
  if digits == 0 {
    return Err("invalid \{kind} literal: \{text}")
  }
  Ok(value)
}

///|
fn wt_parse_u64_literal(text : String, kind : String) -> Result[UInt64, String] {
  let trimmed = text.trim().to_string()
  let parsed_signed = @strconv.parse_int64(trimmed) catch {
    _ =>
      if trimmed.has_prefix("0x") || trimmed.has_prefix("0X") {
        return wt_parse_hex_u64(trimmed, kind)
      } else {
        return wt_parse_u64_decimal(trimmed, kind)
      }
  }
  Ok(parsed_signed.reinterpret_as_uint64())
}

///|
fn wt_parse_f64(text : String) -> Result[@lib.F64, String] {
  let lowered = text.trim().to_string()
  if lowered.has_prefix("nan:") ||
    lowered == "nan" ||
    lowered == "+nan" ||
    lowered == "-nan" ||
    lowered.has_prefix("+nan:") ||
    lowered.has_prefix("-nan:") {
    return Ok(@lib.F64(@double.not_a_number))
  }
  let v = @strconv.parse_double(text) catch {
    _ => return Err("invalid f64 literal: \{text}")
  }
  Ok(@lib.F64(v))
}

///|
fn wt_parse_f32(text : String) -> Result[@lib.F32, String] {
  let v = match wt_parse_f64(text) {
    Ok(@lib.F64(d)) => d
    Err(e) => return Err(e)
  }
  Ok(@lib.F32(Float::from_double(v)))
}

///|
fn wt_parse_i64_literal(text : String, kind : String) -> Result[Int64, String] {
  let parsed = @strconv.parse_int64(text) catch {
    _ => return Err("invalid \{kind} literal: \{text}")
  }
  Ok(parsed)
}

///|
fn wt_parse_nan_payload_bits(
  text : String,
  exp_bits : UInt64,
  quiet_payload : UInt64,
  payload_mask : UInt64,
  sign_mask : UInt64,
  kind : String,
) -> Result[UInt64?, String] {
  let trimmed = text.trim().to_string()
  if trimmed.length() == 0 {
    return Ok(None)
  }
  let mut negative = false
  let mut body = trimmed
  if body[0] == '+' {
    body = body.sub(start=1, end=body.length()).to_string() catch { _ => "" }
  } else if body[0] == '-' {
    negative = true
    body = body.sub(start=1, end=body.length()).to_string() catch { _ => "" }
  }
  if body == "nan" {
    let mut bits = exp_bits | quiet_payload
    if negative {
      bits = bits | sign_mask
    }
    return Ok(Some(bits))
  }
  if body.has_prefix("nan:") {
    let payload_text = body.sub(start=4, end=body.length()).to_string() catch {
        _ => ""
      }
    let payload = match wt_parse_hex_u64(payload_text, "\{kind} NaN payload") {
      Ok(v) => v
      Err(_) => return Err("invalid \{kind} NaN payload literal: \{text}")
    }
    if payload == 0UL || payload > payload_mask {
      return Err("\{kind} NaN payload out of range: \{text}")
    }
    let mut bits = exp_bits | payload
    if negative {
      bits = bits | sign_mask
    }
    return Ok(Some(bits))
  }
  Ok(None)
}

///|
fn wt_push_le_bytes(out : Array[Byte], bits : UInt64, count : Int) -> Unit {
  for i = 0; i < count; i = i + 1 {
    out.push(((bits >> (i * 8)) & 0xffUL).to_byte())
  }
}

///|
fn wt_v128_const_instr(v : V128Const) -> Result[@lib.Instruction, String] {
  let bytes : Array[Byte] = []
  match v.shape {
    I8x16 =>
      for text in v.values {
        let lane = match wt_parse_i64_literal(text, "i8x16") {
          Ok(val) => val
          Err(e) => return Err(e)
        }
        if lane < -128L || lane > 255L {
          return Err("i8x16 lane literal out of range: \{text}")
        }
        bytes.push(lane.to_int().to_byte())
      }
    I16x8 =>
      for text in v.values {
        let lane = match wt_parse_i64_literal(text, "i16x8") {
          Ok(val) => val
          Err(e) => return Err(e)
        }
        if lane < -32768L || lane > 65535L {
          return Err("i16x8 lane literal out of range: \{text}")
        }
        wt_push_le_bytes(bytes, lane.reinterpret_as_uint64(), 2)
      }
    I32x4 =>
      for text in v.values {
        let lane = match wt_parse_i64_literal(text, "i32x4") {
          Ok(val) => val
          Err(e) => return Err(e)
        }
        if lane < -2147483648L || lane > 4294967295L {
          return Err("i32x4 lane literal out of range: \{text}")
        }
        wt_push_le_bytes(bytes, lane.reinterpret_as_uint64(), 4)
      }
    I64x2 =>
      for text in v.values {
        let lane = match wt_parse_u64_literal(text, "i64x2") {
          Ok(val) => val
          Err(e) => return Err(e)
        }
        wt_push_le_bytes(bytes, lane, 8)
      }
    F32x4 =>
      for text in v.values {
        let maybe_nan_bits = match
          wt_parse_nan_payload_bits(
            text, 0x7f800000UL, 0x00400000UL, 0x007fffffUL, 0x80000000UL, "f32x4",
          ) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        match maybe_nan_bits {
          Some(bits) => {
            wt_push_le_bytes(bytes, bits, 4)
            continue
          }
          None => ()
        }
        let lane = match wt_parse_f32(text) {
          Ok(val) => val
          Err(e) => return Err(e)
        }
        let @lib.F32(raw) = lane
        let buf = @buffer.new(size_hint=4)
        buf.write_float_le(raw)
        for b in buf.to_bytes().to_array() {
          bytes.push(b)
        }
      }
    F64x2 =>
      for text in v.values {
        let maybe_nan_bits = match
          wt_parse_nan_payload_bits(
            text, 0x7ff0000000000000UL, 0x0008000000000000UL, 0x000fffffffffffffUL,
            0x8000000000000000UL, "f64x2",
          ) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        match maybe_nan_bits {
          Some(bits) => {
            wt_push_le_bytes(bytes, bits, 8)
            continue
          }
          None => ()
        }
        let lane = match wt_parse_f64(text) {
          Ok(val) => val
          Err(e) => return Err(e)
        }
        let @lib.F64(raw) = lane
        let buf = @buffer.new(size_hint=8)
        buf.write_double_le(raw)
        for b in buf.to_bytes().to_array() {
          bytes.push(b)
        }
      }
  }
  if bytes.length() != 16 {
    return Err("v128.const lowering expected 16 bytes, got \{bytes.length()}")
  }
  Ok(
    @lib.Instruction::v128_const(
      bytes[0],
      bytes[1],
      bytes[2],
      bytes[3],
      bytes[4],
      bytes[5],
      bytes[6],
      bytes[7],
      bytes[8],
      bytes[9],
      bytes[10],
      bytes[11],
      bytes[12],
      bytes[13],
      bytes[14],
      bytes[15],
    ),
  )
}

///|
fn wt_shuffle_lane(lane : UInt) -> Result[@lib.LaneIdx, String] {
  if lane <= 31U {
    Ok(@lib.LaneIdx::new(lane.to_byte()))
  } else {
    Err("i8x16.shuffle lane index out of range: \{lane}")
  }
}

///|
fn wt_lane_idx(
  op : String,
  lane : UInt,
  max_lane : UInt,
) -> Result[@lib.LaneIdx, String] {
  if lane <= max_lane {
    Ok(@lib.LaneIdx::new(lane.to_byte()))
  } else {
    Err("\{op} lane index out of range: \{lane}")
  }
}

///|
fn wt_select_types(types : Array[ValueType]?) -> Array[@lib.ValType]? {
  match types {
    Some(vs) => {
      let out : Array[@lib.ValType] = []
      for v in vs {
        out.push(wt_value_type(v))
      }
      Some(out)
    }
    None => None
  }
}

///|
fn wt_block_type(
  ctx : WTLowerCtx,
  bt : BlockType,
) -> Result[@lib.BlockType, String] {
  match bt.type_use {
    None => Ok(@lib.BlockType::void_())
    Some(tu) =>
      match tu.type_index {
        Some(idx) => {
          let ti = match
            wt_resolve_named_or_num_index(
              idx,
              ctx.type_ids,
              ctx.type_recs.length().reinterpret_as_uint(),
              "type",
            ) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          Ok(@lib.BlockType::type_idx(@lib.TypeIdx::new(ti)))
        }
        None =>
          if tu.func_type.results.length() == 0 {
            Ok(@lib.BlockType::void_())
          } else if tu.func_type.results.length() == 1 {
            Ok(@lib.BlockType::val_type(wt_value_type(tu.func_type.results[0])))
          } else {
            let ti = wt_append_type(ctx, tu.func_type)
            Ok(@lib.BlockType::type_idx(@lib.TypeIdx::new(ti)))
          }
      }
  }
}

///|
fn wt_unsupported(op : String) -> Result[@lib.Instruction, String] {
  Err("unsupported instruction in text lowering bridge: \{op}")
}

///|
fn wt_numeric_noarg(op : Opcode) -> Result[@lib.Instruction, String] {
  match op {
    I32Eqz => Ok(@lib.Instruction::i32_eqz())
    I32Eq => Ok(@lib.Instruction::i32_eq())
    I32Ne => Ok(@lib.Instruction::i32_ne())
    I32LtS => Ok(@lib.Instruction::i32_lt_s())
    I32LtU => Ok(@lib.Instruction::i32_lt_u())
    I32GtS => Ok(@lib.Instruction::i32_gt_s())
    I32GtU => Ok(@lib.Instruction::i32_gt_u())
    I32LeS => Ok(@lib.Instruction::i32_le_s())
    I32LeU => Ok(@lib.Instruction::i32_le_u())
    I32GeS => Ok(@lib.Instruction::i32_ge_s())
    I32GeU => Ok(@lib.Instruction::i32_ge_u())
    I64Eqz => Ok(@lib.Instruction::i64_eqz())
    I64Eq => Ok(@lib.Instruction::i64_eq())
    I64Ne => Ok(@lib.Instruction::i64_ne())
    I64LtS => Ok(@lib.Instruction::i64_lt_s())
    I64LtU => Ok(@lib.Instruction::i64_lt_u())
    I64GtS => Ok(@lib.Instruction::i64_gt_s())
    I64GtU => Ok(@lib.Instruction::i64_gt_u())
    I64LeS => Ok(@lib.Instruction::i64_le_s())
    I64LeU => Ok(@lib.Instruction::i64_le_u())
    I64GeS => Ok(@lib.Instruction::i64_ge_s())
    I64GeU => Ok(@lib.Instruction::i64_ge_u())
    F32Eq => Ok(@lib.Instruction::f32_eq())
    F32Ne => Ok(@lib.Instruction::f32_ne())
    F32Lt => Ok(@lib.Instruction::f32_lt())
    F32Gt => Ok(@lib.Instruction::f32_gt())
    F32Le => Ok(@lib.Instruction::f32_le())
    F32Ge => Ok(@lib.Instruction::f32_ge())
    F64Eq => Ok(@lib.Instruction::f64_eq())
    F64Ne => Ok(@lib.Instruction::f64_ne())
    F64Lt => Ok(@lib.Instruction::f64_lt())
    F64Gt => Ok(@lib.Instruction::f64_gt())
    F64Le => Ok(@lib.Instruction::f64_le())
    F64Ge => Ok(@lib.Instruction::f64_ge())
    I32Clz => Ok(@lib.Instruction::i32_clz())
    I32Ctz => Ok(@lib.Instruction::i32_ctz())
    I32Popcnt => Ok(@lib.Instruction::i32_popcnt())
    I32Add => Ok(@lib.Instruction::i32_add())
    I32Sub => Ok(@lib.Instruction::i32_sub())
    I32Mul => Ok(@lib.Instruction::i32_mul())
    I32DivS => Ok(@lib.Instruction::i32_div_s())
    I32DivU => Ok(@lib.Instruction::i32_div_u())
    I32RemS => Ok(@lib.Instruction::i32_rem_s())
    I32RemU => Ok(@lib.Instruction::i32_rem_u())
    I32And => Ok(@lib.Instruction::i32_and())
    I32Or => Ok(@lib.Instruction::i32_or())
    I32Xor => Ok(@lib.Instruction::i32_xor())
    I32Shl => Ok(@lib.Instruction::i32_shl())
    I32ShrS => Ok(@lib.Instruction::i32_shr_s())
    I32ShrU => Ok(@lib.Instruction::i32_shr_u())
    I32Rotl => Ok(@lib.Instruction::i32_rotl())
    I32Rotr => Ok(@lib.Instruction::i32_rotr())
    I64Clz => Ok(@lib.Instruction::i64_clz())
    I64Ctz => Ok(@lib.Instruction::i64_ctz())
    I64Popcnt => Ok(@lib.Instruction::i64_popcnt())
    I64Add => Ok(@lib.Instruction::i64_add())
    I64Sub => Ok(@lib.Instruction::i64_sub())
    I64Mul => Ok(@lib.Instruction::i64_mul())
    I64DivS => Ok(@lib.Instruction::i64_div_s())
    I64DivU => Ok(@lib.Instruction::i64_div_u())
    I64RemS => Ok(@lib.Instruction::i64_rem_s())
    I64RemU => Ok(@lib.Instruction::i64_rem_u())
    I64And => Ok(@lib.Instruction::i64_and())
    I64Or => Ok(@lib.Instruction::i64_or())
    I64Xor => Ok(@lib.Instruction::i64_xor())
    I64Shl => Ok(@lib.Instruction::i64_shl())
    I64ShrS => Ok(@lib.Instruction::i64_shr_s())
    I64ShrU => Ok(@lib.Instruction::i64_shr_u())
    I64Rotl => Ok(@lib.Instruction::i64_rotl())
    I64Rotr => Ok(@lib.Instruction::i64_rotr())
    F32Abs => Ok(@lib.Instruction::f32_abs())
    F32Neg => Ok(@lib.Instruction::f32_neg())
    F32Ceil => Ok(@lib.Instruction::f32_ceil())
    F32Floor => Ok(@lib.Instruction::f32_floor())
    F32Trunc => Ok(@lib.Instruction::f32_trunc())
    F32Nearest => Ok(@lib.Instruction::f32_nearest())
    F32Sqrt => Ok(@lib.Instruction::f32_sqrt())
    F32Add => Ok(@lib.Instruction::f32_add())
    F32Sub => Ok(@lib.Instruction::f32_sub())
    F32Mul => Ok(@lib.Instruction::f32_mul())
    F32Div => Ok(@lib.Instruction::f32_div())
    F32Min => Ok(@lib.Instruction::f32_min())
    F32Max => Ok(@lib.Instruction::f32_max())
    F32Copysign => Ok(@lib.Instruction::f32_copysign())
    F64Abs => Ok(@lib.Instruction::f64_abs())
    F64Neg => Ok(@lib.Instruction::f64_neg())
    F64Ceil => Ok(@lib.Instruction::f64_ceil())
    F64Floor => Ok(@lib.Instruction::f64_floor())
    F64Trunc => Ok(@lib.Instruction::f64_trunc())
    F64Nearest => Ok(@lib.Instruction::f64_nearest())
    F64Sqrt => Ok(@lib.Instruction::f64_sqrt())
    F64Add => Ok(@lib.Instruction::f64_add())
    F64Sub => Ok(@lib.Instruction::f64_sub())
    F64Mul => Ok(@lib.Instruction::f64_mul())
    F64Div => Ok(@lib.Instruction::f64_div())
    F64Min => Ok(@lib.Instruction::f64_min())
    F64Max => Ok(@lib.Instruction::f64_max())
    F64Copysign => Ok(@lib.Instruction::f64_copysign())
    I32WrapI64 => Ok(@lib.Instruction::i32_wrap_i64())
    I32TruncF32S => Ok(@lib.Instruction::i32_trunc_f32s())
    I32TruncF32U => Ok(@lib.Instruction::i32_trunc_f32u())
    I32TruncF64S => Ok(@lib.Instruction::i32_trunc_f64s())
    I32TruncF64U => Ok(@lib.Instruction::i32_trunc_f64u())
    I64ExtendI32S => Ok(@lib.Instruction::i64_extend_i32s())
    I64ExtendI32U => Ok(@lib.Instruction::i64_extend_i32u())
    I64TruncF32S => Ok(@lib.Instruction::i64_trunc_f32s())
    I64TruncF32U => Ok(@lib.Instruction::i64_trunc_f32u())
    I64TruncF64S => Ok(@lib.Instruction::i64_trunc_f64s())
    I64TruncF64U => Ok(@lib.Instruction::i64_trunc_f64u())
    F32ConvertI32S => Ok(@lib.Instruction::f32_convert_i32s())
    F32ConvertI32U => Ok(@lib.Instruction::f32_convert_i32u())
    F32ConvertI64S => Ok(@lib.Instruction::f32_convert_i64s())
    F32ConvertI64U => Ok(@lib.Instruction::f32_convert_i64u())
    F32DemoteF64 => Ok(@lib.Instruction::f32_demote_f64())
    F64ConvertI32S => Ok(@lib.Instruction::f64_convert_i32s())
    F64ConvertI32U => Ok(@lib.Instruction::f64_convert_i32u())
    F64ConvertI64S => Ok(@lib.Instruction::f64_convert_i64s())
    F64ConvertI64U => Ok(@lib.Instruction::f64_convert_i64u())
    F64PromoteF32 => Ok(@lib.Instruction::f64_promote_f32())
    I32ReinterpretF32 => Ok(@lib.Instruction::i32_reinterpret_f32())
    I64ReinterpretF64 => Ok(@lib.Instruction::i64_reinterpret_f64())
    F32ReinterpretI32 => Ok(@lib.Instruction::f32_reinterpret_i32())
    F64ReinterpretI64 => Ok(@lib.Instruction::f64_reinterpret_i64())
    I32Extend8S => Ok(@lib.Instruction::i32_extend8s())
    I32Extend16S => Ok(@lib.Instruction::i32_extend16s())
    I64Extend8S => Ok(@lib.Instruction::i64_extend8s())
    I64Extend16S => Ok(@lib.Instruction::i64_extend16s())
    I64Extend32S => Ok(@lib.Instruction::i64_extend32s())
    I32TruncSatF32S => Ok(@lib.Instruction::i32_trunc_sat_f32s())
    I32TruncSatF32U => Ok(@lib.Instruction::i32_trunc_sat_f32u())
    I32TruncSatF64S => Ok(@lib.Instruction::i32_trunc_sat_f64s())
    I32TruncSatF64U => Ok(@lib.Instruction::i32_trunc_sat_f64u())
    I64TruncSatF32S => Ok(@lib.Instruction::i64_trunc_sat_f32s())
    I64TruncSatF32U => Ok(@lib.Instruction::i64_trunc_sat_f32u())
    I64TruncSatF64S => Ok(@lib.Instruction::i64_trunc_sat_f64s())
    I64TruncSatF64U => Ok(@lib.Instruction::i64_trunc_sat_f64u())
    RefEq => Ok(@lib.Instruction::ref_eq())
    RefAsNonNull => Ok(@lib.Instruction::ref_as_non_null())
    AnyConvertExtern => Ok(@lib.Instruction::any_convert_extern())
    ExternConvertAny => Ok(@lib.Instruction::extern_convert_any())
    RefI31 => Ok(@lib.Instruction::ref_i31())
    I31GetS => Ok(@lib.Instruction::i31_get_s())
    I31GetU => Ok(@lib.Instruction::i31_get_u())
    _ => wt_unsupported("\{op}")
  }
}

///|
fn wt_load_store(op : Opcode, ma : MemArg) -> Result[@lib.Instruction, String] {
  let memarg = wt_mem_arg(ma)
  match op {
    I32Load => Ok(@lib.Instruction::i32_load(memarg))
    I64Load => Ok(@lib.Instruction::i64_load(memarg))
    F32Load => Ok(@lib.Instruction::f32_load(memarg))
    F64Load => Ok(@lib.Instruction::f64_load(memarg))
    I32Load8S => Ok(@lib.Instruction::i32_load8s(memarg))
    I32Load8U => Ok(@lib.Instruction::i32_load8u(memarg))
    I32Load16S => Ok(@lib.Instruction::i32_load16s(memarg))
    I32Load16U => Ok(@lib.Instruction::i32_load16u(memarg))
    I64Load8S => Ok(@lib.Instruction::i64_load8s(memarg))
    I64Load8U => Ok(@lib.Instruction::i64_load8u(memarg))
    I64Load16S => Ok(@lib.Instruction::i64_load16s(memarg))
    I64Load16U => Ok(@lib.Instruction::i64_load16u(memarg))
    I64Load32S => Ok(@lib.Instruction::i64_load32s(memarg))
    I64Load32U => Ok(@lib.Instruction::i64_load32u(memarg))
    I32Store => Ok(@lib.Instruction::i32_store(memarg))
    I64Store => Ok(@lib.Instruction::i64_store(memarg))
    F32Store => Ok(@lib.Instruction::f32_store(memarg))
    F64Store => Ok(@lib.Instruction::f64_store(memarg))
    I32Store8 => Ok(@lib.Instruction::i32_store8(memarg))
    I32Store16 => Ok(@lib.Instruction::i32_store16(memarg))
    I64Store8 => Ok(@lib.Instruction::i64_store8(memarg))
    I64Store16 => Ok(@lib.Instruction::i64_store16(memarg))
    I64Store32 => Ok(@lib.Instruction::i64_store32(memarg))
    _ => wt_unsupported("\{op}")
  }
}

///|
fn wt_instrs_to_lib(
  ctx : WTLowerCtx,
  instrs : Array[Instruction],
  local_ids : Map[String, UInt],
  labels : Array[String?],
) -> Result[Array[@lib.Instruction], String] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    let lib_instr = match wt_instr_to_lib(ctx, instr, local_ids, labels) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.push(lib_instr)
  }
  Ok(out)
}

///|
fn wt_local_idx(
  idx : Index,
  local_ids : Map[String, UInt],
) -> Result[UInt, String] {
  match idx {
    Num(n) => Ok(n)
    Id(name) =>
      match local_ids.get(name) {
        Some(v) => Ok(v)
        None => Err("unknown local id: \{name}")
      }
  }
}

///|
fn wt_instr_to_lib(
  ctx : WTLowerCtx,
  instr : Instruction,
  local_ids : Map[String, UInt],
  labels : Array[String?],
) -> Result[@lib.Instruction, String] {
  match instr {
    Unreachable => Ok(@lib.Instruction::unreachable_())
    Nop => Ok(@lib.Instruction::nop())
    Block(bt, body) => {
      let next_labels = labels.copy()
      next_labels.push(bt.label)
      let lib_body = match wt_instrs_to_lib(ctx, body, local_ids, next_labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_bt = match wt_block_type(ctx, bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::block(lib_bt, @lib.Expr::new(lib_body)))
    }
    Loop(bt, body) => {
      let next_labels = labels.copy()
      next_labels.push(bt.label)
      let lib_body = match wt_instrs_to_lib(ctx, body, local_ids, next_labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_bt = match wt_block_type(ctx, bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::loop_(lib_bt, @lib.Expr::new(lib_body)))
    }
    If(bt, then_body, else_body) => {
      let next_labels = labels.copy()
      next_labels.push(bt.label)
      let lib_then = match
        wt_instrs_to_lib(ctx, then_body, local_ids, next_labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_else = match
        wt_instrs_to_lib(ctx, else_body, local_ids, next_labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_bt = match wt_block_type(ctx, bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let else_opt : Array[@lib.Instruction]? = if lib_else.length() == 0 {
        None
      } else {
        Some(lib_else)
      }
      Ok(@lib.Instruction::if_(lib_bt, lib_then, else_opt))
    }
    Br(idx) => {
      let depth = match wt_resolve_label(idx, labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::br(@lib.LabelIdx::new(depth)))
    }
    BrIf(idx) => {
      let depth = match wt_resolve_label(idx, labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::br_if(@lib.LabelIdx::new(depth)))
    }
    BrTable(targets, fallback) => {
      let ls : Array[@lib.LabelIdx] = []
      for target in targets {
        let depth = match wt_resolve_label(target, labels) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        ls.push(@lib.LabelIdx::new(depth))
      }
      let fb = match wt_resolve_label(fallback, labels) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::br_table(ls, @lib.LabelIdx::new(fb)))
    }
    Return => Ok(@lib.Instruction::return_())
    Call(idx) => {
      let fi = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.func_ids,
          ctx.next_func_idx,
          "func",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::call(@lib.FuncIdx::new(fi)))
    }
    CallIndirect(table_idx, type_use) => {
      let ti = match wt_resolve_type_use(ctx, type_use) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let tbl = match
        wt_resolve_named_or_num_index(
          table_idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        @lib.Instruction::call_indirect(
          @lib.TypeIdx::new(ti),
          @lib.TableIdx::new(tbl),
        ),
      )
    }
    Drop => Ok(@lib.Instruction::drop())
    Select(types) => Ok(@lib.Instruction::select(types=wt_select_types(types)))
    LocalGet(idx) => {
      let li = match wt_local_idx(idx, local_ids) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::local_get(@lib.LocalIdx::new(li)))
    }
    LocalSet(idx) => {
      let li = match wt_local_idx(idx, local_ids) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::local_set(@lib.LocalIdx::new(li)))
    }
    LocalTee(idx) => {
      let li = match wt_local_idx(idx, local_ids) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::local_tee(@lib.LocalIdx::new(li)))
    }
    GlobalGet(idx) => {
      let gi = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.global_ids,
          ctx.next_global_idx,
          "global",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::global_get(@lib.GlobalIdx::new(gi)))
    }
    GlobalSet(idx) => {
      let gi = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.global_ids,
          ctx.next_global_idx,
          "global",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::global_set(@lib.GlobalIdx::new(gi)))
    }
    TableGet(idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::table_get(@lib.TableIdx::new(ti)))
    }
    TableSet(idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::table_set(@lib.TableIdx::new(ti)))
    }
    TableSize(idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::table_size(@lib.TableIdx::new(ti)))
    }
    TableGrow(idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::table_grow(@lib.TableIdx::new(ti)))
    }
    TableFill(idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::table_fill(@lib.TableIdx::new(ti)))
    }
    TableCopy(dst, src) => {
      let dsti = match
        wt_resolve_named_or_num_index(
          dst,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let srci = match
        wt_resolve_named_or_num_index(
          src,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        @lib.Instruction::table_copy(
          @lib.TableIdx::new(dsti),
          @lib.TableIdx::new(srci),
        ),
      )
    }
    TableInit(table_idx, elem_idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          table_idx,
          ctx.table_ids,
          ctx.next_table_idx,
          "table",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let ei = match
        wt_resolve_named_or_num_index(
          elem_idx,
          ctx.elem_ids,
          ctx.next_elem_idx,
          "elem",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        @lib.Instruction::table_init(
          @lib.ElemIdx::new(ei),
          @lib.TableIdx::new(ti),
        ),
      )
    }
    ElemDrop(idx) => {
      let ei = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.elem_ids,
          ctx.next_elem_idx,
          "elem",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::elem_drop(@lib.ElemIdx::new(ei)))
    }
    Load(op, ma) | Store(op, ma) => wt_load_store(op, ma)
    MemorySize => Ok(@lib.Instruction::memory_size(@lib.MemIdx::new(0)))
    MemoryGrow => Ok(@lib.Instruction::memory_grow(@lib.MemIdx::new(0)))
    MemoryFill => Ok(@lib.Instruction::memory_fill(@lib.MemIdx::new(0)))
    MemoryCopy =>
      Ok(
        @lib.Instruction::memory_copy(@lib.MemIdx::new(0), @lib.MemIdx::new(0)),
      )
    MemoryInit(idx) => {
      let di = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.data_ids,
          ctx.next_data_idx,
          "data",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        @lib.Instruction::memory_init(
          @lib.DataIdx::new(di),
          @lib.MemIdx::new(0),
        ),
      )
    }
    DataDrop(idx) => {
      let di = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.data_ids,
          ctx.next_data_idx,
          "data",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::data_drop(@lib.DataIdx::new(di)))
    }
    Const(op, text) =>
      match op {
        I32Const =>
          match wt_parse_i32(text) {
            Ok(v) => Ok(@lib.Instruction::i32_const(v))
            Err(e) => Err(e)
          }
        I64Const =>
          match wt_parse_i64(text) {
            Ok(v) => Ok(@lib.Instruction::i64_const(v))
            Err(e) => Err(e)
          }
        F32Const =>
          match wt_parse_f32(text) {
            Ok(v) => Ok(@lib.Instruction::f32_const(v))
            Err(e) => Err(e)
          }
        F64Const =>
          match wt_parse_f64(text) {
            Ok(v) => Ok(@lib.Instruction::f64_const(v))
            Err(e) => Err(e)
          }
        _ => wt_unsupported("\{op}")
      }
    Unary(op)
    | Binary(op)
    | Test(op)
    | Compare(op)
    | Convert(op)
    | SimdUnary(op)
    | SimdBinary(op)
    | SimdTernary(op)
    | SimdShift(op)
    | SimdTest(op)
    | SimdCompare(op)
    | SimdConvert(op)
    | SimdRelaxed(op) => wt_numeric_noarg(op)
    RefNull(vt) =>
      match wt_ref_heap_type(vt) {
        Some(ht) => Ok(@lib.Instruction::ref_null(ht))
        None => Err("unsupported ref.null type: \{vt}")
      }
    RefIsNull => Ok(@lib.Instruction::ref_is_null())
    RefFunc(idx) => {
      let fi = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.func_ids,
          ctx.next_func_idx,
          "func",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::ref_func(@lib.FuncIdx::new(fi)))
    }
    RefGetDesc => Ok(@lib.Instruction::ref_get_desc())
    RefTestDesc(nullable, idx) | RefCastDescEq(nullable, idx) => {
      let ti = match
        wt_resolve_named_or_num_index(
          idx,
          ctx.type_ids,
          ctx.type_recs.length().reinterpret_as_uint(),
          "type",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let ht = @lib.HeapType::new(@lib.TypeIdx::new(ti))
      if instr is RefTestDesc(_, _) {
        Ok(@lib.Instruction::ref_test_desc(nullable, ht))
      } else {
        Ok(@lib.Instruction::ref_cast_desc_eq(nullable, ht))
      }
    }
    V128Const(v) => wt_v128_const_instr(v)
    V128Load(ma) => Ok(@lib.Instruction::v128_load(wt_mem_arg(ma)))
    V128Load8x8S(ma) => Ok(@lib.Instruction::v128_load8x8s(wt_mem_arg(ma)))
    V128Load8x8U(ma) => Ok(@lib.Instruction::v128_load8x8u(wt_mem_arg(ma)))
    V128Load16x4S(ma) => Ok(@lib.Instruction::v128_load16x4s(wt_mem_arg(ma)))
    V128Load16x4U(ma) => Ok(@lib.Instruction::v128_load16x4u(wt_mem_arg(ma)))
    V128Load32x2S(ma) => Ok(@lib.Instruction::v128_load32x2s(wt_mem_arg(ma)))
    V128Load32x2U(ma) => Ok(@lib.Instruction::v128_load32x2u(wt_mem_arg(ma)))
    V128Load8Splat(ma) => Ok(@lib.Instruction::v128_load8_splat(wt_mem_arg(ma)))
    V128Load16Splat(ma) =>
      Ok(@lib.Instruction::v128_load16_splat(wt_mem_arg(ma)))
    V128Load32Splat(ma) =>
      Ok(@lib.Instruction::v128_load32_splat(wt_mem_arg(ma)))
    V128Load64Splat(ma) =>
      Ok(@lib.Instruction::v128_load64_splat(wt_mem_arg(ma)))
    V128Load32Zero(ma) => Ok(@lib.Instruction::v128_load32_zero(wt_mem_arg(ma)))
    V128Load64Zero(ma) => Ok(@lib.Instruction::v128_load64_zero(wt_mem_arg(ma)))
    V128Store(ma) => Ok(@lib.Instruction::v128_store(wt_mem_arg(ma)))
    I8x16Shuffle(lanes) => {
      let li0 = match wt_shuffle_lane(lanes.lanes[0]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li1 = match wt_shuffle_lane(lanes.lanes[1]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li2 = match wt_shuffle_lane(lanes.lanes[2]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li3 = match wt_shuffle_lane(lanes.lanes[3]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li4 = match wt_shuffle_lane(lanes.lanes[4]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li5 = match wt_shuffle_lane(lanes.lanes[5]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li6 = match wt_shuffle_lane(lanes.lanes[6]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li7 = match wt_shuffle_lane(lanes.lanes[7]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li8 = match wt_shuffle_lane(lanes.lanes[8]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li9 = match wt_shuffle_lane(lanes.lanes[9]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li10 = match wt_shuffle_lane(lanes.lanes[10]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li11 = match wt_shuffle_lane(lanes.lanes[11]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li12 = match wt_shuffle_lane(lanes.lanes[12]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li13 = match wt_shuffle_lane(lanes.lanes[13]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li14 = match wt_shuffle_lane(lanes.lanes[14]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let li15 = match wt_shuffle_lane(lanes.lanes[15]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        @lib.Instruction::i8x16_shuffle(
          li0, li1, li2, li3, li4, li5, li6, li7, li8, li9, li10, li11, li12, li13,
          li14, li15,
        ),
      )
    }
    I8x16Swizzle => Ok(@lib.Instruction::i8x16_swizzle())
    I8x16Splat => Ok(@lib.Instruction::i8x16_splat())
    I16x8Splat => Ok(@lib.Instruction::i16x8_splat())
    I32x4Splat => Ok(@lib.Instruction::i32x4_splat())
    I64x2Splat => Ok(@lib.Instruction::i64x2_splat())
    F32x4Splat => Ok(@lib.Instruction::f32x4_splat())
    F64x2Splat => Ok(@lib.Instruction::f64x2_splat())
    V128Load8Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load8_lane", lane, 15U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load8_lane(wt_mem_arg(ma), li))
    }
    V128Load16Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load16_lane", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load16_lane(wt_mem_arg(ma), li))
    }
    V128Load32Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load32_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load32_lane(wt_mem_arg(ma), li))
    }
    V128Load64Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load64_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load64_lane(wt_mem_arg(ma), li))
    }
    V128Store8Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store8_lane", lane, 15U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store8_lane(wt_mem_arg(ma), li))
    }
    V128Store16Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store16_lane", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store16_lane(wt_mem_arg(ma), li))
    }
    V128Store32Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store32_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store32_lane(wt_mem_arg(ma), li))
    }
    V128Store64Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store64_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store64_lane(wt_mem_arg(ma), li))
    }
    I8x16ExtractLaneS(lane) => {
      let li = match wt_lane_idx("i8x16.extract_lane_s", lane, 15U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i8x16_extract_lane_s(li))
    }
    I8x16ExtractLaneU(lane) => {
      let li = match wt_lane_idx("i8x16.extract_lane_u", lane, 15U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i8x16_extract_lane_u(li))
    }
    I8x16ReplaceLane(lane) => {
      let li = match wt_lane_idx("i8x16.replace_lane", lane, 15U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i8x16_replace_lane(li))
    }
    I16x8ExtractLaneS(lane) => {
      let li = match wt_lane_idx("i16x8.extract_lane_s", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i16x8_extract_lane_s(li))
    }
    I16x8ExtractLaneU(lane) => {
      let li = match wt_lane_idx("i16x8.extract_lane_u", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i16x8_extract_lane_u(li))
    }
    I16x8ReplaceLane(lane) => {
      let li = match wt_lane_idx("i16x8.replace_lane", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i16x8_replace_lane(li))
    }
    I32x4ExtractLane(lane) => {
      let li = match wt_lane_idx("i32x4.extract_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i32x4_extract_lane(li))
    }
    I32x4ReplaceLane(lane) => {
      let li = match wt_lane_idx("i32x4.replace_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i32x4_replace_lane(li))
    }
    I64x2ExtractLane(lane) => {
      let li = match wt_lane_idx("i64x2.extract_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i64x2_extract_lane(li))
    }
    I64x2ReplaceLane(lane) => {
      let li = match wt_lane_idx("i64x2.replace_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::i64x2_replace_lane(li))
    }
    F32x4ExtractLane(lane) => {
      let li = match wt_lane_idx("f32x4.extract_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::f32x4_extract_lane(li))
    }
    F32x4ReplaceLane(lane) => {
      let li = match wt_lane_idx("f32x4.replace_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::f32x4_replace_lane(li))
    }
    F64x2ExtractLane(lane) => {
      let li = match wt_lane_idx("f64x2.extract_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::f64x2_extract_lane(li))
    }
    F64x2ReplaceLane(lane) => {
      let li = match wt_lane_idx("f64x2.replace_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::f64x2_replace_lane(li))
    }
  }
}

///|
fn wt_lower_module(mod : Module) -> Result[@lib.Module, String] {
  let ctx = wt_new_ctx()
  for field in mod.fields {
    match field {
      TypeField(td) => {
        let idx = wt_append_type(ctx, td.func_type)
        match td.id {
          Some(id) => ctx.type_ids[id] = idx
          None => ()
        }
      }
      _ => ()
    }
  }

  let imports : Array[@lib.Import] = []
  let func_defs : Array[(Func, UInt)] = []
  let table_defs_raw : Array[Table] = []
  let mem_defs_raw : Array[Memory] = []
  let global_defs_raw : Array[Global] = []
  let export_defs : Array[Export] = []
  let start_defs : Array[Start] = []
  let elem_defs_raw : Array[ElemSegment] = []
  let data_defs_raw : Array[DataSegment] = []

  for field in mod.fields {
    match field {
      TypeField(_) => ()
      ImportField(im) =>
        match im.desc {
          Func(type_use) => {
            let ti = match wt_resolve_type_use(ctx, type_use) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            imports.push(
              @lib.Import::new(
                @lib.Name::new(im.module_name),
                @lib.Name::new(im.field_name),
                @lib.ExternType::func(@lib.TypeIdx::new(ti)),
              ),
            )
            match im.id {
              Some(id) => ctx.func_ids[id] = ctx.next_func_idx
              None => ()
            }
            ctx.next_func_idx += 1
          }
          Table(tt) => {
            let table_type = @lib.TableType::new(
              @lib.RefType::new(
                true,
                match wt_ref_heap_type(tt.elem_type) {
                  Some(ht) => ht
                  None => @lib.HeapType::abs(@lib.AbsHeapType::func())
                },
              ),
              wt_limits(tt.limits),
            )
            imports.push(
              @lib.Import::new(
                @lib.Name::new(im.module_name),
                @lib.Name::new(im.field_name),
                @lib.ExternType::table(table_type),
              ),
            )
            match im.id {
              Some(id) => ctx.table_ids[id] = ctx.next_table_idx
              None => ()
            }
            ctx.next_table_idx += 1
          }
          Memory(mt) => {
            imports.push(
              @lib.Import::new(
                @lib.Name::new(im.module_name),
                @lib.Name::new(im.field_name),
                @lib.ExternType::mem(@lib.MemType::new(wt_limits(mt.0))),
              ),
            )
            match im.id {
              Some(id) => ctx.mem_ids[id] = ctx.next_mem_idx
              None => ()
            }
            ctx.next_mem_idx += 1
          }
          Global(gt) => {
            imports.push(
              @lib.Import::new(
                @lib.Name::new(im.module_name),
                @lib.Name::new(im.field_name),
                @lib.ExternType::global(
                  @lib.GlobalType::new(wt_value_type(gt.val_type), gt.mutable_),
                ),
              ),
            )
            match im.id {
              Some(id) => ctx.global_ids[id] = ctx.next_global_idx
              None => ()
            }
            ctx.next_global_idx += 1
          }
        }
      FuncField(f) => {
        let ti = match wt_resolve_type_use(ctx, f.type_use) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        func_defs.push((f, ti))
        match f.id {
          Some(id) => ctx.func_ids[id] = ctx.next_func_idx
          None => ()
        }
        ctx.next_func_idx += 1
      }
      TableField(t) => {
        table_defs_raw.push(t)
        match t.id {
          Some(id) => ctx.table_ids[id] = ctx.next_table_idx
          None => ()
        }
        ctx.next_table_idx += 1
      }
      MemoryField(m) => {
        mem_defs_raw.push(m)
        match m.id {
          Some(id) => ctx.mem_ids[id] = ctx.next_mem_idx
          None => ()
        }
        ctx.next_mem_idx += 1
      }
      GlobalField(g) => {
        global_defs_raw.push(g)
        match g.id {
          Some(id) => ctx.global_ids[id] = ctx.next_global_idx
          None => ()
        }
        ctx.next_global_idx += 1
      }
      ExportField(e) => export_defs.push(e)
      StartField(s) => start_defs.push(s)
      ElemField(e) => {
        elem_defs_raw.push(e)
        match e.id {
          Some(id) => ctx.elem_ids[id] = ctx.next_elem_idx
          None => ()
        }
        ctx.next_elem_idx += 1
      }
      DataField(d) => {
        data_defs_raw.push(d)
        match d.id {
          Some(id) => ctx.data_ids[id] = ctx.next_data_idx
          None => ()
        }
        ctx.next_data_idx += 1
      }
    }
  }

  let func_type_idxs : Array[@lib.TypeIdx] = []
  let code_funcs : Array[@lib.Func] = []
  for entry in func_defs {
    let (f, type_idx) = entry
    func_type_idxs.push(@lib.TypeIdx::new(type_idx))
    let local_ids : Map[String, UInt] = {}
    let base = match f.type_use.type_index {
      Some(_) =>
        match wt_type_param_count(ctx, type_idx) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      None => f.type_use.func_type.params.length().reinterpret_as_uint()
    }
    let mut offset = 0U
    for loc in f.locals {
      match loc.id {
        Some(id) => local_ids[id] = base + offset
        None => ()
      }
      offset += 1
    }
    let body = match wt_instrs_to_lib(ctx, f.body, local_ids, []) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let local_types : Array[@lib.ValType] = []
    for loc in f.locals {
      local_types.push(wt_value_type(loc.val_type))
    }
    let locals : Array[@lib.Locals] = []
    for vt in local_types {
      locals.push(@lib.Locals::new(1U, vt))
    }
    code_funcs.push(@lib.Func::new(locals, @lib.Expr::new(body)))
  }

  let table_defs : Array[@lib.Table] = []
  for t in table_defs_raw {
    let ht = match wt_ref_heap_type(t.table_type.elem_type) {
      Some(v) => v
      None => @lib.HeapType::abs(@lib.AbsHeapType::func())
    }
    table_defs.push(
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, ht),
          wt_limits(t.table_type.limits),
        ),
        None,
      ),
    )
  }

  let mem_defs : Array[@lib.MemType] = []
  for m in mem_defs_raw {
    mem_defs.push(@lib.MemType::new(wt_limits(m.memory_type.0)))
  }

  let global_defs : Array[@lib.Global] = []
  for g in global_defs_raw {
    let init = match wt_instrs_to_lib(ctx, g.init, {}, []) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    global_defs.push(
      @lib.Global::new(
        @lib.GlobalType::new(
          wt_value_type(g.global_type.val_type),
          g.global_type.mutable_,
        ),
        @lib.Expr::new(init),
      ),
    )
  }

  let exports : Array[@lib.Export] = []
  for ex in export_defs {
    let ext_idx = match ex.desc {
      Func(idx) =>
        match
          wt_resolve_named_or_num_index(
            idx,
            ctx.func_ids,
            ctx.next_func_idx,
            "func",
          ) {
          Ok(v) => @lib.ExternIdx::func(@lib.FuncIdx::new(v))
          Err(e) => return Err(e)
        }
      Table(idx) =>
        match
          wt_resolve_named_or_num_index(
            idx,
            ctx.table_ids,
            ctx.next_table_idx,
            "table",
          ) {
          Ok(v) => @lib.ExternIdx::table(@lib.TableIdx::new(v))
          Err(e) => return Err(e)
        }
      Memory(idx) =>
        match
          wt_resolve_named_or_num_index(
            idx,
            ctx.mem_ids,
            ctx.next_mem_idx,
            "mem",
          ) {
          Ok(v) => @lib.ExternIdx::mem(@lib.MemIdx::new(v))
          Err(e) => return Err(e)
        }
      Global(idx) =>
        match
          wt_resolve_named_or_num_index(
            idx,
            ctx.global_ids,
            ctx.next_global_idx,
            "global",
          ) {
          Ok(v) => @lib.ExternIdx::global(@lib.GlobalIdx::new(v))
          Err(e) => return Err(e)
        }
    }
    exports.push(@lib.Export::new(@lib.Name::new(ex.name), ext_idx))
  }

  let mut start : @lib.StartSec? = None
  if start_defs.length() > 0 {
    let s = start_defs[start_defs.length() - 1]
    let fi = match
      wt_resolve_named_or_num_index(
        s.func_index,
        ctx.func_ids,
        ctx.next_func_idx,
        "func",
      ) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    start = Some(@lib.StartSec::new(@lib.FuncIdx::new(fi)))
  }

  let elems : Array[@lib.Elem] = []
  for e in elem_defs_raw {
    let table_idx = match
      wt_resolve_named_or_num_index(
        e.table_index,
        ctx.table_ids,
        ctx.next_table_idx,
        "table",
      ) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let offset = match wt_instrs_to_lib(ctx, e.offset, {}, []) {
      Ok(v) => @lib.Expr::new(v)
      Err(e) => return Err(e)
    }
    let funcs : Array[@lib.FuncIdx] = []
    for fidx in e.func_indices {
      let fi = match
        wt_resolve_named_or_num_index(
          fidx,
          ctx.func_ids,
          ctx.next_func_idx,
          "func",
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      funcs.push(@lib.FuncIdx::new(fi))
    }
    elems.push(
      @lib.Elem::new(
        @lib.ElemMode::active(@lib.TableIdx::new(table_idx), offset),
        @lib.ElemKind::funcs(funcs),
      ),
    )
  }

  let datas : Array[@lib.Data] = []
  for d in data_defs_raw {
    let mem_idx = match
      wt_resolve_named_or_num_index(
        d.memory_index,
        ctx.mem_ids,
        ctx.next_mem_idx,
        "mem",
      ) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let offset = match wt_instrs_to_lib(ctx, d.offset, {}, []) {
      Ok(v) => @lib.Expr::new(v)
      Err(e) => return Err(e)
    }
    datas.push(
      @lib.Data::new(
        @lib.DataMode::active(@lib.MemIdx::new(mem_idx), offset),
        d.data,
      ),
    )
  }

  let mut out = @lib.Module::new()
  if ctx.type_recs.length() > 0 {
    out = out.with_type_sec(@lib.TypeSec::new(ctx.type_recs))
  }
  if imports.length() > 0 {
    out = out.with_import_sec(@lib.ImportSec::new(imports))
  }
  if func_type_idxs.length() > 0 {
    out = out.with_func_sec(@lib.FuncSec::new(func_type_idxs))
  }
  if table_defs.length() > 0 {
    out = out.with_table_sec(@lib.TableSec::new(table_defs))
  }
  if mem_defs.length() > 0 {
    out = out.with_mem_sec(@lib.MemSec::new(mem_defs))
  }
  if global_defs.length() > 0 {
    out = out.with_global_sec(@lib.GlobalSec::new(global_defs))
  }
  if exports.length() > 0 {
    out = out.with_export_sec(@lib.ExportSec::new(exports))
  }
  match start {
    Some(sec) => out = out.with_start_sec(sec)
    None => ()
  }
  if elems.length() > 0 {
    out = out.with_elem_sec(@lib.ElemSec::new(elems))
  }
  if code_funcs.length() > 0 {
    out = out.with_code_sec(@lib.CodeSec::new(code_funcs))
  }
  if datas.length() > 0 {
    out = out.with_data_sec(@lib.DataSec::new(datas))
  }
  if datas.length() > 0 {
    out = out.with_data_cnt_sec(
      @lib.DataCntSec::new(@lib.U32(datas.length().reinterpret_as_uint())),
    )
  }
  Ok(out)
}

///|
pub fn wast_ast_to_binary_module(mod : Module) -> Result[@lib.Module, String] {
  wt_lower_module(mod)
}

///|
pub fn wast_to_binary_module(
  source : String,
  filename? : String = "<memory>",
) -> Result[@lib.Module, String] {
  match wast_to_module(source, filename~) {
    Ok(mod) => wast_ast_to_binary_module(mod)
    Err(e) => Err(e)
  }
}

///|
pub fn wast_text_binary_roundtrip(
  source : String,
  filename? : String = "<memory>",
) -> Result[(String, @lib.Module), String] {
  let parsed = match wast_to_module(source, filename~) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let normalized = match module_to_wast(parsed) {
    Ok(t) => t
    Err(e) => return Err("text normalization failed during roundtrip: \{e}")
  }
  let lowered = match wast_ast_to_binary_module(parsed) {
    Ok(m) => m
    Err(e) => return Err("text lowering failed during roundtrip: \{e}")
  }
  let bytes = match @binary.encode_module(lowered) {
    Ok(raw) => raw
    Err(e) => return Err("binary encode failed during roundtrip: \{e}")
  }
  let decoded = match @binary.decode_module(bytes) {
    Ok(m) => m
    Err(e) => return Err("binary decode failed during roundtrip: \{e}")
  }
  Ok((normalized, decoded))
}

///|
test "wast_to_binary_module lowers simple function module" {
  let lowered = match
    wast_to_binary_module("(module (func (result i32) i32.const 5))") {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([@lib.I32Const(@lib.I32(v))]))])) =>
      assert_eq(v, 5)
    _ => fail("expected lowered module code section")
  }
}

///|
test "wast_to_binary_module lowers memory and data segments" {
  let lowered = match
    wast_to_binary_module("(module (memory 1) (data (i32.const 0) \"A\"))") {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match (lowered.mem_sec, lowered.data_sec) {
    (Some(_), Some(@lib.DataSec([@lib.Data(_, bytes)]))) =>
      assert_eq(bytes.length(), 1)
    _ => fail("expected lowered memory/data sections")
  }
}

///|
test "wast_to_binary_module resolves named locals after type-index params" {
  let lowered = match
    wast_to_binary_module(
      "(module (type (func (param i32))) (func (type 0) (local $x i32) local.get $x drop))",
    ) {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(i)), _]))]
      )
    ) => assert_eq(i, 1U)
    _ => fail("expected local.get on lowered named local")
  }
}

///|
test "wt_type_param_count supports grouped recursive function entries" {
  let ctx = wt_new_ctx()
  let st0 = @lib.SubType::comp_type(
    @lib.CompType::func([@lib.ValType::i32()], []),
  )
  let st1 = @lib.SubType::comp_type(
    @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::f32()], []),
  )
  ctx.type_recs.push(@lib.RecType::group([st0, st1]))
  match wt_type_param_count(ctx, 1U) {
    Ok(count) => assert_eq(count, 2U)
    Err(e) => fail("expected grouped rec param count resolution, got \{e}")
  }
}

///|
test "wast_to_binary_module lowers SIMD extract/replace lane ops" {
  let lowered = match
    wast_to_binary_module(
      "(module (func (param v128 i32) (result v128) local.get 0 i8x16.extract_lane_u 7 drop local.get 0 local.get 1 i8x16.replace_lane 3))",
    ) {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([_, extract_lane, _, _, _, replace_lane]))]
      )
    ) => {
      assert_eq(
        extract_lane,
        @lib.Instruction::i8x16_extract_lane_u(@lib.LaneIdx::new(7)),
      )
      assert_eq(
        replace_lane,
        @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(3)),
      )
    }
    _ => fail("expected lowered SIMD extract/replace lane instructions")
  }
}

///|
test "wast_to_binary_module lowers SIMD load/store lane ops" {
  let lowered = match
    wast_to_binary_module(
      "(module (memory 1) (func (param i32 v128) (result v128) local.get 0 local.get 1 v128.load8_lane 5 local.get 0 v128.store8_lane 2 local.get 1))",
    ) {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr([_, _, load_lane_instr, _, store_lane_instr, _])
          ),
        ]
      )
    ) => {
      assert_eq(
        load_lane_instr,
        @lib.Instruction::v128_load8_lane(
          @lib.MemArg::new(@lib.U32(1), None, @lib.U64(0)),
          @lib.LaneIdx::new(5),
        ),
      )
      assert_eq(
        store_lane_instr,
        @lib.Instruction::v128_store8_lane(
          @lib.MemArg::new(@lib.U32(1), None, @lib.U64(0)),
          @lib.LaneIdx::new(2),
        ),
      )
    }
    _ => fail("expected lowered SIMD load/store lane instructions")
  }
}

///|
test "wast_to_binary_module lowers SIMD v128.const shapes" {
  let src =
    #|(module
    #|  (func (result v128) v128.const i8x16 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
    #|  (func (result v128) v128.const i16x8 1 2 3 4 5 6 7 8)
    #|  (func (result v128) v128.const i32x4 1 2 3 4)
    #|  (func (result v128) v128.const i64x2 1 2)
    #|  (func (result v128) v128.const f32x4 1 2 3 4)
    #|  (func (result v128) v128.const f64x2 1 2))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected SIMD v128.const lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(funcs.length(), 6)

      match funcs[0] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0).to_byte(),
              (1).to_byte(),
              (2).to_byte(),
              (3).to_byte(),
              (4).to_byte(),
              (5).to_byte(),
              (6).to_byte(),
              (7).to_byte(),
              (8).to_byte(),
              (9).to_byte(),
              (10).to_byte(),
              (11).to_byte(),
              (12).to_byte(),
              (13).to_byte(),
              (14).to_byte(),
              (15).to_byte(),
            ),
          )
        _ => fail("expected i8x16 v128.const function body")
      }

      match funcs[1] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (1).to_byte(),
              (0).to_byte(),
              (2).to_byte(),
              (0).to_byte(),
              (3).to_byte(),
              (0).to_byte(),
              (4).to_byte(),
              (0).to_byte(),
              (5).to_byte(),
              (0).to_byte(),
              (6).to_byte(),
              (0).to_byte(),
              (7).to_byte(),
              (0).to_byte(),
              (8).to_byte(),
              (0).to_byte(),
            ),
          )
        _ => fail("expected i16x8 v128.const function body")
      }

      match funcs[2] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (1).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (2).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (3).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (4).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
            ),
          )
        _ => fail("expected i32x4 v128.const function body")
      }

      match funcs[3] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (1).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (2).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
            ),
          )
        _ => fail("expected i64x2 v128.const function body")
      }

      match funcs[4] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0).to_byte(),
              (0).to_byte(),
              (128).to_byte(),
              (63).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (64).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (64).to_byte(),
              (64).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (128).to_byte(),
              (64).to_byte(),
            ),
          )
        _ => fail("expected f32x4 v128.const function body")
      }

      match funcs[5] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (240).to_byte(),
              (63).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (0).to_byte(),
              (64).to_byte(),
            ),
          )
        _ => fail("expected f64x2 v128.const function body")
      }
    }
    _ => fail("expected lowered module code section for v128.const shapes")
  }
}

///|
test "wast_to_binary_module lowers SIMD non-lane memory prefixed ops" {
  let src =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result v128) local.get 0 v128.load)
    #|  (func (param i32) (result v128) local.get 0 v128.load8x8_s)
    #|  (func (param i32) (result v128) local.get 0 v128.load8x8_u)
    #|  (func (param i32) (result v128) local.get 0 v128.load16x4_s)
    #|  (func (param i32) (result v128) local.get 0 v128.load16x4_u)
    #|  (func (param i32) (result v128) local.get 0 v128.load32x2_s)
    #|  (func (param i32) (result v128) local.get 0 v128.load32x2_u)
    #|  (func (param i32) (result v128) local.get 0 v128.load8_splat)
    #|  (func (param i32) (result v128) local.get 0 v128.load16_splat)
    #|  (func (param i32) (result v128) local.get 0 v128.load32_splat)
    #|  (func (param i32) (result v128) local.get 0 v128.load64_splat)
    #|  (func (param i32) (result v128) local.get 0 v128.load32_zero)
    #|  (func (param i32) (result v128) local.get 0 v128.load64_zero)
    #|  (func (param i32 v128) (result v128) local.get 0 local.get 1 v128.store local.get 1))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected SIMD memory-op lowering success: \{e}")
  }
  let ma16 = @lib.MemArg::new(@lib.U32(16), None, @lib.U64(0))
  let ma8 = @lib.MemArg::new(@lib.U32(8), None, @lib.U64(0))
  let ma4 = @lib.MemArg::new(@lib.U32(4), None, @lib.U64(0))
  let ma2 = @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0))
  let ma1 = @lib.MemArg::new(@lib.U32(1), None, @lib.U64(0))
  match lowered.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(funcs.length(), 14)

      match funcs[0] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load(ma16))
        _ => fail("expected v128.load lowered body")
      }

      match funcs[1] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load8x8s(ma8))
        _ => fail("expected v128.load8x8_s lowered body")
      }

      match funcs[2] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load8x8u(ma8))
        _ => fail("expected v128.load8x8_u lowered body")
      }

      match funcs[3] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load16x4s(ma8))
        _ => fail("expected v128.load16x4_s lowered body")
      }

      match funcs[4] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load16x4u(ma8))
        _ => fail("expected v128.load16x4_u lowered body")
      }

      match funcs[5] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load32x2s(ma8))
        _ => fail("expected v128.load32x2_s lowered body")
      }

      match funcs[6] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load32x2u(ma8))
        _ => fail("expected v128.load32x2_u lowered body")
      }

      match funcs[7] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load8_splat(ma1))
        _ => fail("expected v128.load8_splat lowered body")
      }

      match funcs[8] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load16_splat(ma2))
        _ => fail("expected v128.load16_splat lowered body")
      }

      match funcs[9] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load32_splat(ma4))
        _ => fail("expected v128.load32_splat lowered body")
      }

      match funcs[10] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load64_splat(ma8))
        _ => fail("expected v128.load64_splat lowered body")
      }

      match funcs[11] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load32_zero(ma4))
        _ => fail("expected v128.load32_zero lowered body")
      }

      match funcs[12] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::v128_load64_zero(ma8))
        _ => fail("expected v128.load64_zero lowered body")
      }

      match funcs[13] {
        @lib.Func(
          _,
          @lib.Expr(
            [
              @lib.LocalGet(@lib.LocalIdx(i0)),
              @lib.LocalGet(@lib.LocalIdx(i1)),
              store_instr,
              @lib.LocalGet(@lib.LocalIdx(i2)),
            ]
          )
        ) => {
          assert_eq(i0, 0U)
          assert_eq(i1, 1U)
          assert_eq(i2, 1U)
          assert_eq(store_instr, @lib.Instruction::v128_store(ma16))
        }
        _ => fail("expected v128.store lowered body")
      }
    }
    _ => fail("expected lowered module code section for SIMD memory ops")
  }
}

///|
test "wast_to_binary_module lowers SIMD shuffle and swizzle ops" {
  let src =
    #|(module
    #|  (func (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.shuffle 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.swizzle))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected SIMD shuffle/swizzle lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.LocalGet(@lib.LocalIdx(0)),
                @lib.LocalGet(@lib.LocalIdx(1)),
                shuffle_instr,
                @lib.Drop,
                @lib.LocalGet(@lib.LocalIdx(0)),
                @lib.LocalGet(@lib.LocalIdx(1)),
                swizzle_instr,
              ]
            )
          ),
        ]
      )
    ) => {
      assert_eq(
        shuffle_instr,
        @lib.Instruction::i8x16_shuffle(
          @lib.LaneIdx::new(0),
          @lib.LaneIdx::new(1),
          @lib.LaneIdx::new(2),
          @lib.LaneIdx::new(3),
          @lib.LaneIdx::new(4),
          @lib.LaneIdx::new(5),
          @lib.LaneIdx::new(6),
          @lib.LaneIdx::new(7),
          @lib.LaneIdx::new(8),
          @lib.LaneIdx::new(9),
          @lib.LaneIdx::new(10),
          @lib.LaneIdx::new(11),
          @lib.LaneIdx::new(12),
          @lib.LaneIdx::new(13),
          @lib.LaneIdx::new(14),
          @lib.LaneIdx::new(15),
        ),
      )
      assert_eq(swizzle_instr, @lib.Instruction::i8x16_swizzle())
    }
    _ => fail("expected lowered module shuffle/swizzle function body")
  }
}

///|
test "wast_to_binary_module lowers SIMD splat ops" {
  let src =
    #|(module
    #|  (func (param i32) (result v128) local.get 0 i8x16.splat)
    #|  (func (param i32) (result v128) local.get 0 i16x8.splat)
    #|  (func (param i32) (result v128) local.get 0 i32x4.splat)
    #|  (func (param i64) (result v128) local.get 0 i64x2.splat)
    #|  (func (param f32) (result v128) local.get 0 f32x4.splat)
    #|  (func (param f64) (result v128) local.get 0 f64x2.splat))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected SIMD splat lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(funcs.length(), 6)

      match funcs[0] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::i8x16_splat())
        _ => fail("expected i8x16.splat lowered body")
      }
      match funcs[1] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::i16x8_splat())
        _ => fail("expected i16x8.splat lowered body")
      }
      match funcs[2] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::i32x4_splat())
        _ => fail("expected i32x4.splat lowered body")
      }
      match funcs[3] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::i64x2_splat())
        _ => fail("expected i64x2.splat lowered body")
      }
      match funcs[4] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::f32x4_splat())
        _ => fail("expected f32x4.splat lowered body")
      }
      match funcs[5] {
        @lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr])) =>
          assert_eq(instr, @lib.Instruction::f64x2_splat())
        _ => fail("expected f64x2.splat lowered body")
      }
    }
    _ => fail("expected lowered module code section for SIMD splat ops")
  }
}

///|
test "wast_text_binary_roundtrip returns validator-clean module for core fixture" {
  let src =
    #|(module
    #|  (func (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add)
    #|  (export "inc" (func 0)))
  let (_, roundtripped) = match
    wast_text_binary_roundtrip(src, filename="roundtrip-core.wast") {
    Ok(m) => m
    Err(e) => fail("expected full text/binary roundtrip to succeed: \{e}")
  }
  match roundtripped.export_sec {
    Some(
      @lib.ExportSec([@lib.Export(name, @lib.FuncExternIdx(@lib.FuncIdx(idx)))])
    ) => {
      assert_eq(name.0, "inc")
      assert_eq(idx, 0U)
    }
    _ => fail("expected roundtripped core fixture to preserve export shape")
  }
}

///|
test "wast_text_binary_roundtrip preserves descriptor instruction families" {
  let src =
    #|(module
    #|  (func (param funcref) (result i32)
    #|    local.get 0
    #|    ref.get_desc
    #|    drop
    #|    local.get 0
    #|    ref.test_desc 0
    #|    drop
    #|    local.get 0
    #|    ref.cast_desc_eq_null 0
    #|    drop
    #|    (i32.const 0))
    #|  (export "f" (func 0)))
  let (normalized, _) = match
    wast_text_binary_roundtrip(src, filename="roundtrip-descriptor.wast") {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected descriptor fixture full text/binary roundtrip to succeed: \{e}",
      )
  }
  assert_true(normalized.contains("ref.get_desc"))
  assert_true(normalized.contains("ref.test_desc 0"))
  assert_true(normalized.contains("ref.cast_desc_eq_null 0"))
}

///|
fn wt_lower_error_contains(source : String, needle : String) -> Bool {
  match wast_to_binary_module(source) {
    Ok(_) => false
    Err(e) => e.contains(needle)
  }
}

///|
test "wast_to_binary_module lowers advanced reference no-immediate instructions" {
  let src =
    #|(module
    #|  (func (param externref externref i32 externref)
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq
    #|    drop
    #|    local.get 0
    #|    ref.as_non_null
    #|    drop
    #|    local.get 2
    #|    ref.i31
    #|    i31.get_s
    #|    drop
    #|    local.get 2
    #|    ref.i31
    #|    i31.get_u
    #|    drop
    #|    local.get 3
    #|    any.convert_extern
    #|    extern.convert_any
    #|    drop))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected advanced reference lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.LocalGet(@lib.LocalIdx(0)),
                @lib.LocalGet(@lib.LocalIdx(1)),
                ref_eq_instr,
                @lib.Drop,
                @lib.LocalGet(@lib.LocalIdx(0)),
                ref_as_non_null_instr,
                @lib.Drop,
                @lib.LocalGet(@lib.LocalIdx(2)),
                ref_i31_s_instr,
                i31_get_s_instr,
                @lib.Drop,
                @lib.LocalGet(@lib.LocalIdx(2)),
                ref_i31_u_instr,
                i31_get_u_instr,
                @lib.Drop,
                @lib.LocalGet(@lib.LocalIdx(3)),
                any_convert_extern_instr,
                extern_convert_any_instr,
                @lib.Drop,
              ]
            )
          ),
        ]
      )
    ) => {
      assert_eq(ref_eq_instr, @lib.Instruction::ref_eq())
      assert_eq(ref_as_non_null_instr, @lib.Instruction::ref_as_non_null())
      assert_eq(ref_i31_s_instr, @lib.Instruction::ref_i31())
      assert_eq(i31_get_s_instr, @lib.Instruction::i31_get_s())
      assert_eq(ref_i31_u_instr, @lib.Instruction::ref_i31())
      assert_eq(i31_get_u_instr, @lib.Instruction::i31_get_u())
      assert_eq(
        any_convert_extern_instr,
        @lib.Instruction::any_convert_extern(),
      )
      assert_eq(
        extern_convert_any_instr,
        @lib.Instruction::extern_convert_any(),
      )
    }
    _ =>
      fail(
        "expected lowered function body containing advanced reference instructions",
      )
  }
}

///|
test "wast_to_binary_module rejects out-of-range SIMD lane immediates" {
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.load8_lane 16 drop))",
      "v128.load8_lane lane index out of range: 16",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.load16_lane 8 drop))",
      "v128.load16_lane lane index out of range: 8",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.load32_lane 4 drop))",
      "v128.load32_lane lane index out of range: 4",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.load64_lane 2 drop))",
      "v128.load64_lane lane index out of range: 2",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.store8_lane 16))",
      "v128.store8_lane lane index out of range: 16",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.store16_lane 8))",
      "v128.store16_lane lane index out of range: 8",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.store32_lane 4))",
      "v128.store32_lane lane index out of range: 4",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 1) (func (param i32 v128) local.get 0 local.get 1 v128.store64_lane 2))",
      "v128.store64_lane lane index out of range: 2",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128) local.get 0 i8x16.extract_lane_u 16 drop))", "i8x16.extract_lane_u lane index out of range: 16",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 i32) local.get 0 local.get 1 i8x16.replace_lane 16 drop))",
      "i8x16.replace_lane lane index out of range: 16",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128) local.get 0 i16x8.extract_lane_u 8 drop))", "i16x8.extract_lane_u lane index out of range: 8",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 i32) local.get 0 local.get 1 i16x8.replace_lane 8 drop))",
      "i16x8.replace_lane lane index out of range: 8",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128) local.get 0 i32x4.extract_lane 4 drop))", "i32x4.extract_lane lane index out of range: 4",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 i32) local.get 0 local.get 1 i32x4.replace_lane 4 drop))",
      "i32x4.replace_lane lane index out of range: 4",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128) local.get 0 i64x2.extract_lane 2 drop))", "i64x2.extract_lane lane index out of range: 2",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 i64) local.get 0 local.get 1 i64x2.replace_lane 2 drop))",
      "i64x2.replace_lane lane index out of range: 2",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128) local.get 0 f32x4.extract_lane 4 drop))", "f32x4.extract_lane lane index out of range: 4",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 f32) local.get 0 local.get 1 f32x4.replace_lane 4 drop))",
      "f32x4.replace_lane lane index out of range: 4",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128) local.get 0 f64x2.extract_lane 2 drop))", "f64x2.extract_lane lane index out of range: 2",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 f64) local.get 0 local.get 1 f64x2.replace_lane 2 drop))",
      "f64x2.replace_lane lane index out of range: 2",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (param v128 v128) local.get 0 local.get 1 i8x16.shuffle 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 32 drop))",
      "i8x16.shuffle lane index out of range: 32",
    ),
  )
}

///|
test "wast_to_binary_module rejects out-of-range SIMD v128.const lane values" {
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const i8x16 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 256))",
      "i8x16 lane literal out of range: 256",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const i16x8 0 0 0 0 0 0 0 70000))", "i16x8 lane literal out of range: 70000",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const i32x4 0 0 0 4294967296))", "i32x4 lane literal out of range: 4294967296",
    ),
  )
}

///|
test "wast_to_binary_module preserves hexadecimal integer v128.const literals" {
  let src =
    #|(module
    #|  (func (result v128)
    #|    v128.const i8x16
    #|      0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x07
    #|      0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f)
    #|  (func (result v128)
    #|    v128.const i16x8 0x0102 0x0304 0x0506 0x0708 0x090a 0x0b0c 0x0d0e 0x0f10)
    #|  (func (result v128)
    #|    v128.const i32x4 0x01020304 0x05060708 0x090a0b0c 0x0d0e0f10)
    #|  (func (result v128)
    #|    v128.const i64x2 0xffffffffffffffff 0x8000000000000000))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected hexadecimal integer v128.const lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(funcs.length(), 4)

      match funcs[0] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0x00).to_byte(),
              (0x01).to_byte(),
              (0x02).to_byte(),
              (0x03).to_byte(),
              (0x04).to_byte(),
              (0x05).to_byte(),
              (0x06).to_byte(),
              (0x07).to_byte(),
              (0x08).to_byte(),
              (0x09).to_byte(),
              (0x0a).to_byte(),
              (0x0b).to_byte(),
              (0x0c).to_byte(),
              (0x0d).to_byte(),
              (0x0e).to_byte(),
              (0x0f).to_byte(),
            ),
          )
        _ => fail("expected i8x16 hex v128.const function body")
      }

      match funcs[1] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0x02).to_byte(),
              (0x01).to_byte(),
              (0x04).to_byte(),
              (0x03).to_byte(),
              (0x06).to_byte(),
              (0x05).to_byte(),
              (0x08).to_byte(),
              (0x07).to_byte(),
              (0x0a).to_byte(),
              (0x09).to_byte(),
              (0x0c).to_byte(),
              (0x0b).to_byte(),
              (0x0e).to_byte(),
              (0x0d).to_byte(),
              (0x10).to_byte(),
              (0x0f).to_byte(),
            ),
          )
        _ => fail("expected i16x8 hex v128.const function body")
      }

      match funcs[2] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0x04).to_byte(),
              (0x03).to_byte(),
              (0x02).to_byte(),
              (0x01).to_byte(),
              (0x08).to_byte(),
              (0x07).to_byte(),
              (0x06).to_byte(),
              (0x05).to_byte(),
              (0x0c).to_byte(),
              (0x0b).to_byte(),
              (0x0a).to_byte(),
              (0x09).to_byte(),
              (0x10).to_byte(),
              (0x0f).to_byte(),
              (0x0e).to_byte(),
              (0x0d).to_byte(),
            ),
          )
        _ => fail("expected i32x4 hex v128.const function body")
      }

      match funcs[3] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x80).to_byte(),
            ),
          )
        _ => fail("expected i64x2 hex v128.const function body")
      }
    }
    _ =>
      fail("expected lowered module code section for hex v128.const literals")
  }
}

///|
test "wast_to_binary_module preserves NaN payload lanes in v128.const" {
  let src =
    #|(module
    #|  (func (result v128)
    #|    v128.const f32x4 nan:0x1 -nan:0x400001 +nan:0x7fffff nan:0x123456)
    #|  (func (result v128)
    #|    v128.const f64x2 nan:0x1 -nan:0x8000000000001))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected NaN payload v128.const lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(funcs.length(), 2)

      match funcs[0] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0x01).to_byte(),
              (0x00).to_byte(),
              (0x80).to_byte(),
              (0x7f).to_byte(),
              (0x01).to_byte(),
              (0x00).to_byte(),
              (0xc0).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0xff).to_byte(),
              (0x7f).to_byte(),
              (0x56).to_byte(),
              (0x34).to_byte(),
              (0x92).to_byte(),
              (0x7f).to_byte(),
            ),
          )
        _ => fail("expected f32x4 NaN payload v128.const function body")
      }

      match funcs[1] {
        @lib.Func(_, @lib.Expr([instr])) =>
          assert_eq(
            instr,
            @lib.Instruction::v128_const(
              (0x01).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0xf0).to_byte(),
              (0x7f).to_byte(),
              (0x01).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0x00).to_byte(),
              (0xf8).to_byte(),
              (0xff).to_byte(),
            ),
          )
        _ => fail("expected f64x2 NaN payload v128.const function body")
      }
    }
    _ => fail("expected lowered module code section for NaN payload v128.const")
  }
}
