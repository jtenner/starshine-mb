///|
priv struct WTLowerCtx {
  type_recs : Array[@lib.RecType]
  type_ids : Map[String, UInt]
  func_ids : Map[String, UInt]
  table_ids : Map[String, UInt]
  mem_ids : Map[String, UInt]
  global_ids : Map[String, UInt]
  tag_ids : Map[String, UInt]
  tag_type_idxs : Array[UInt]
  elem_ids : Map[String, UInt]
  data_ids : Map[String, UInt]
  mut next_func_idx : UInt
  mut next_table_idx : UInt
  mut next_mem_idx : UInt
  mut next_global_idx : UInt
  mut next_tag_idx : UInt
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
    tag_ids: {},
    tag_type_idxs: [],
    elem_ids: {},
    data_ids: {},
    next_func_idx: 0U,
    next_table_idx: 0U,
    next_mem_idx: 0U,
    next_global_idx: 0U,
    next_tag_idx: 0U,
    next_elem_idx: 0U,
    next_data_idx: 0U,
  }
}

///|
fn wt_resolve_heap_type_ref(
  ctx : WTLowerCtx,
  ht : HeapTypeRef,
) -> Result[@lib.HeapType, String] {
  match ht {
    TypeNum(n) => Ok(@lib.HeapType::new(@lib.TypeIdx::new(n)))
    TypeId(id) =>
      match ctx.type_ids.get(id) {
        Some(v) => Ok(@lib.HeapType::new(@lib.TypeIdx::new(v)))
        None => Err("unknown type id: \{id}")
      }
    Any => Ok(@lib.HeapType::abs(@lib.AbsHeapType::any()))
    Eq => Ok(@lib.HeapType::abs(@lib.AbsHeapType::eq()))
    I31 => Ok(@lib.HeapType::abs(@lib.AbsHeapType::i31()))
    None_ => Ok(@lib.HeapType::abs(@lib.AbsHeapType::none()))
    NoFunc => Ok(@lib.HeapType::abs(@lib.AbsHeapType::no_func()))
    NoExtern => Ok(@lib.HeapType::abs(@lib.AbsHeapType::no_extern()))
    NoExn => Ok(@lib.HeapType::abs(@lib.AbsHeapType::no_exn()))
  }
}

///|
fn wt_value_type(
  ctx : WTLowerCtx,
  vt : ValueType,
) -> Result[@lib.ValType, String] {
  match vt {
    I32 => Ok(@lib.ValType::i32())
    I64 => Ok(@lib.ValType::i64())
    F32 => Ok(@lib.ValType::f32())
    F64 => Ok(@lib.ValType::f64())
    V128 => Ok(@lib.ValType::v128())
    FuncRef => Ok(@lib.ValType::funcref())
    ExternRef => Ok(@lib.ValType::externref())
    ExnRef =>
      Ok(
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::exn())),
        ),
      )
    NonNullFuncRef =>
      Ok(
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
        ),
      )
    NonNullExternRef =>
      Ok(
        @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
          ),
        ),
      )
    NonNullExnRef =>
      Ok(
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::exn())),
        ),
      )
    TypedFuncRef(ht) => {
      let resolved = match wt_resolve_heap_type_ref(ctx, ht) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.ValType::ref_type(@lib.RefType::new(true, resolved)))
    }
    NonNullTypedFuncRef(ht) => {
      let resolved = match wt_resolve_heap_type_ref(ctx, ht) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.ValType::ref_type(@lib.RefType::new(false, resolved)))
    }
  }
}

///|
fn wt_ref_heap_type(
  ctx : WTLowerCtx,
  vt : ValueType,
) -> Result[@lib.HeapType?, String] {
  match vt {
    FuncRef | NonNullFuncRef =>
      Ok(Some(@lib.HeapType::abs(@lib.AbsHeapType::func())))
    ExternRef | NonNullExternRef =>
      Ok(Some(@lib.HeapType::abs(@lib.AbsHeapType::extern_())))
    ExnRef | NonNullExnRef =>
      Ok(Some(@lib.HeapType::abs(@lib.AbsHeapType::exn())))
    TypedFuncRef(ht) | NonNullTypedFuncRef(ht) => {
      let resolved = match wt_resolve_heap_type_ref(ctx, ht) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(Some(resolved))
    }
    _ => Ok(None)
  }
}

///|
fn wt_ref_type_for_elem_value_type(
  ctx : WTLowerCtx,
  vt : ValueType,
) -> Result[@lib.RefType, String] {
  match wt_ref_heap_type(ctx, vt) {
    Ok(Some(ht)) => Ok(@lib.RefType::new(true, ht))
    Ok(None) =>
      Err(
        "elem type must be a reference type, got non-reference value type: \{vt}",
      )
    Err(e) => Err(e)
  }
}

///|
fn wt_elem_item_ref_func_index(item : ElemInitExpr) -> Index? {
  match item.instrs {
    [RefFunc(idx)] => Some(idx)
    _ => None
  }
}

///|
fn wt_elem_item_to_expr(
  ctx : WTLowerCtx,
  item : ElemInitExpr,
) -> Result[@lib.Expr, String] {
  match wt_instrs_to_lib(ctx, item.instrs, {}, [], wt_default_legacy_ctx()) {
    Ok(instrs) => Ok(@lib.Expr::new(instrs))
    Err(e) => Err(e)
  }
}

///|
fn wt_limits(lim : Limits) -> @lib.Limits {
  @lib.Limits::i32(lim.min, lim.max)
}

///|
fn wt_align_pow_from_text_align(align : UInt64) -> Result[UInt, String] {
  if align == 0UL {
    return Err("alignment must be a positive power of two")
  }
  let mut cur = align
  let mut pow = 0U
  while cur > 1UL {
    if (cur & 1UL) != 0UL {
      return Err("alignment must be a positive power of two")
    }
    cur = cur >> 1
    pow += 1
  }
  Ok(pow)
}

///|
fn wt_mem_arg(ma : MemArg) -> Result[@lib.MemArg, String] {
  let align_pow = match wt_align_pow_from_text_align(ma.align) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(@lib.MemArg::new(@lib.U32(align_pow), None, @lib.U64(ma.offset)))
}

///|
fn wt_func_sig(
  ctx : WTLowerCtx,
  ft : FuncType,
) -> Result[(Array[@lib.ValType], Array[@lib.ValType]), String] {
  let params : Array[@lib.ValType] = []
  for p in ft.params {
    let v = match wt_value_type(ctx, p) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    params.push(v)
  }
  let results : Array[@lib.ValType] = []
  for r in ft.results {
    let v = match wt_value_type(ctx, r) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    results.push(v)
  }
  Ok((params, results))
}

///|
fn wt_append_type(ctx : WTLowerCtx, ft : FuncType) -> Result[UInt, String] {
  let (params, results) = match wt_func_sig(ctx, ft) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let rec = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func(params, results)),
  )
  let idx = ctx.type_recs.length().reinterpret_as_uint()
  ctx.type_recs.push(rec)
  Ok(idx)
}

///|
fn wt_append_lib_func_type(
  ctx : WTLowerCtx,
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> UInt {
  let rec = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func(params, results)),
  )
  let idx = ctx.type_recs.length().reinterpret_as_uint()
  ctx.type_recs.push(rec)
  idx
}

///|
fn wt_find_matching_func_type_index(
  ctx : WTLowerCtx,
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> UInt? {
  let mut flat = 0U
  for rec in ctx.type_recs {
    match rec {
      SingleRecType(CompTypeSubType(FuncCompType(ps, rs)))
      | SingleRecType(SubType(_, _, FuncCompType(ps, rs))) => {
        if ps == params && rs == results {
          return Some(flat)
        }
        flat += 1
      }
      SingleRecType(_) => flat += 1
      GroupRecType(sts) =>
        for st in sts {
          match st {
            CompTypeSubType(FuncCompType(ps, rs))
            | SubType(_, _, FuncCompType(ps, rs)) => {
              if ps == params && rs == results {
                return Some(flat)
              }
              flat += 1
            }
            _ => flat += 1
          }
        }
    }
  }
  None
}

///|
fn wt_resolve_functype_sig_by_index(
  ctx : WTLowerCtx,
  type_idx : UInt,
) -> Result[(Array[@lib.ValType], Array[@lib.ValType]), String] {
  let mut flat = 0U
  for rec in ctx.type_recs {
    match rec {
      SingleRecType(CompTypeSubType(FuncCompType(params, results)))
      | SingleRecType(SubType(_, _, FuncCompType(params, results))) => {
        if flat == type_idx {
          return Ok((params, results))
        }
        flat += 1
      }
      SingleRecType(_) => {
        if flat == type_idx {
          return Err("type index does not reference a function type: \{type_idx}")
        }
        flat += 1
      }
      GroupRecType(sts) =>
        for st in sts {
          match st {
            CompTypeSubType(FuncCompType(params, results))
            | SubType(_, _, FuncCompType(params, results)) => {
              if flat == type_idx {
                return Ok((params, results))
              }
              flat += 1
            }
            _ => {
              if flat == type_idx {
                return Err(
                  "type index does not reference a function type: \{type_idx}",
                )
              }
              flat += 1
            }
          }
        }
    }
  }
  Err("type index out of bounds: \{type_idx}")
}

///|
fn wt_block_type_results(
  ctx : WTLowerCtx,
  bt : BlockType,
) -> Result[Array[@lib.ValType], String] {
  match bt.type_use {
    None => Ok([])
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
          let (_, results) = match wt_resolve_functype_sig_by_index(ctx, ti) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          Ok(results)
        }
        None => {
          let (_, results) = match wt_func_sig(ctx, tu.func_type) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          Ok(results)
        }
      }
  }
}

///|
fn wt_tag_payload_types(
  ctx : WTLowerCtx,
  tag_idx : UInt,
) -> Result[Array[@lib.ValType], String] {
  let ti = match ctx.tag_type_idxs.get(tag_idx.reinterpret_as_int()) {
    Some(v) => v
    None => return Err("unknown tag index: \{tag_idx}")
  }
  let (params, _) = match wt_resolve_functype_sig_by_index(ctx, ti) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(params)
}

///|
fn wt_default_value_instrs_for_valtype(
  vt : @lib.ValType,
) -> Result[Array[@lib.Instruction], String] {
  match vt {
    @lib.NumTypeValType(@lib.I32NumType) =>
      Ok([@lib.Instruction::i32_const(@lib.I32(0))])
    @lib.NumTypeValType(@lib.I64NumType) =>
      Ok([@lib.Instruction::i64_const(@lib.I64(0L))])
    @lib.NumTypeValType(@lib.F32NumType) =>
      Ok([@lib.Instruction::f32_const(@lib.F32(0.0))])
    @lib.NumTypeValType(@lib.F64NumType) =>
      Ok([@lib.Instruction::f64_const(@lib.F64(0.0))])
    @lib.VecTypeValType =>
      Ok([
        @lib.Instruction::v128_const(
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ),
      ])
    @lib.RefTypeValType(rt) => {
      let ref_null = @lib.Instruction::ref_null(rt.get_heap_type())
      if rt.is_nullable() {
        Ok([ref_null])
      } else {
        Ok([ref_null, @lib.Instruction::ref_as_non_null()])
      }
    }
    @lib.BotValType =>
      Err("cannot synthesize legacy-catch payload value for bottom type")
  }
}

///|
fn wt_drop_n_instrs(n : Int) -> Array[@lib.Instruction] {
  let drops : Array[@lib.Instruction] = []
  let mut i = 0
  while i < n {
    drops.push(@lib.Instruction::drop())
    i += 1
  }
  drops
}

///|
fn wt_resolve_named_or_num_index(
  idx : Index,
  ids : Map[String, UInt],
  upper_bound : UInt,
  kind : String,
) -> Result[UInt, String] {
  ignore(upper_bound)
  match idx {
    Num(n) => Ok(n)
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
    None => {
      let (params, results) = match wt_func_sig(ctx, tu.func_type) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      match wt_find_matching_func_type_index(ctx, params, results) {
        Some(idx) => Ok(idx)
        None =>
          match wt_append_type(ctx, tu.func_type) {
            Ok(v) => Ok(v)
            Err(e) => Err(e)
          }
      }
    }
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
fn wt_select_types(
  ctx : WTLowerCtx,
  types : Array[ValueType]?,
) -> Result[Array[@lib.ValType]?, String] {
  match types {
    Some(vs) => {
      let out : Array[@lib.ValType] = []
      for v in vs {
        let vv = match wt_value_type(ctx, v) {
          Ok(vv) => vv
          Err(e) => return Err(e)
        }
        out.push(vv)
      }
      Ok(Some(out))
    }
    None => Ok(None)
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
          if tu.func_type.params.length() == 0 &&
            tu.func_type.results.length() == 0 {
            Ok(@lib.BlockType::void_())
          } else if tu.func_type.params.length() == 0 &&
            tu.func_type.results.length() == 1 {
            let vt = match wt_value_type(ctx, tu.func_type.results[0]) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            Ok(@lib.BlockType::val_type(vt))
          } else {
            let ti = match wt_append_type(ctx, tu.func_type) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
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
    I8x16Eq => Ok(@lib.Instruction::i8x16_eq())
    I8x16Ne => Ok(@lib.Instruction::i8x16_ne())
    I8x16LtS => Ok(@lib.Instruction::i8x16_lt_s())
    I8x16LtU => Ok(@lib.Instruction::i8x16_lt_u())
    I8x16GtS => Ok(@lib.Instruction::i8x16_gt_s())
    I8x16GtU => Ok(@lib.Instruction::i8x16_gt_u())
    I8x16LeS => Ok(@lib.Instruction::i8x16_le_s())
    I8x16LeU => Ok(@lib.Instruction::i8x16_le_u())
    I8x16GeS => Ok(@lib.Instruction::i8x16_ge_s())
    I8x16GeU => Ok(@lib.Instruction::i8x16_ge_u())
    I8x16Abs => Ok(@lib.Instruction::i8x16_abs())
    I8x16Neg => Ok(@lib.Instruction::i8x16_neg())
    I8x16Popcnt => Ok(@lib.Instruction::i8x16_popcnt())
    I8x16AllTrue => Ok(@lib.Instruction::i8x16_all_true())
    I8x16Bitmask => Ok(@lib.Instruction::i8x16_bitmask())
    I8x16NarrowI16x8S => Ok(@lib.Instruction::i8x16_narrow_i16x8s())
    I8x16NarrowI16x8U => Ok(@lib.Instruction::i8x16_narrow_i16x8u())
    I8x16Shl => Ok(@lib.Instruction::i8x16_shl())
    I8x16ShrS => Ok(@lib.Instruction::i8x16_shr_s())
    I8x16ShrU => Ok(@lib.Instruction::i8x16_shr_u())
    I8x16Add => Ok(@lib.Instruction::i8x16_add())
    I8x16AddSatS => Ok(@lib.Instruction::i8x16_add_sat_s())
    I8x16AddSatU => Ok(@lib.Instruction::i8x16_add_sat_u())
    I8x16Sub => Ok(@lib.Instruction::i8x16_sub())
    I8x16SubSatS => Ok(@lib.Instruction::i8x16_sub_sat_s())
    I8x16SubSatU => Ok(@lib.Instruction::i8x16_sub_sat_u())
    I8x16MinS => Ok(@lib.Instruction::i8x16_min_s())
    I8x16MinU => Ok(@lib.Instruction::i8x16_min_u())
    I8x16MaxS => Ok(@lib.Instruction::i8x16_max_s())
    I8x16MaxU => Ok(@lib.Instruction::i8x16_max_u())
    I8x16AvgrU => Ok(@lib.Instruction::i8x16_avgr_u())
    I16x8Eq => Ok(@lib.Instruction::i16x8_eq())
    I16x8Ne => Ok(@lib.Instruction::i16x8_ne())
    I16x8LtS => Ok(@lib.Instruction::i16x8_lt_s())
    I16x8LtU => Ok(@lib.Instruction::i16x8_lt_u())
    I16x8GtS => Ok(@lib.Instruction::i16x8_gt_s())
    I16x8GtU => Ok(@lib.Instruction::i16x8_gt_u())
    I16x8LeS => Ok(@lib.Instruction::i16x8_le_s())
    I16x8LeU => Ok(@lib.Instruction::i16x8_le_u())
    I16x8GeS => Ok(@lib.Instruction::i16x8_ge_s())
    I16x8GeU => Ok(@lib.Instruction::i16x8_ge_u())
    I16x8Abs => Ok(@lib.Instruction::i16x8_abs())
    I16x8Neg => Ok(@lib.Instruction::i16x8_neg())
    I16x8Q15mulrSatS => Ok(@lib.Instruction::i16x8q15mulr_sat_s())
    I16x8AllTrue => Ok(@lib.Instruction::i16x8_all_true())
    I16x8Bitmask => Ok(@lib.Instruction::i16x8_bitmask())
    I16x8NarrowI32x4S => Ok(@lib.Instruction::i16x8_narrow_i32x4s())
    I16x8NarrowI32x4U => Ok(@lib.Instruction::i16x8_narrow_i32x4u())
    I16x8ExtendLowI8x16S => Ok(@lib.Instruction::i16x8_extend_low_i8x16s())
    I16x8ExtendHighI8x16S => Ok(@lib.Instruction::i16x8_extend_high_i8x16s())
    I16x8ExtendLowI8x16U => Ok(@lib.Instruction::i16x8_extend_low_i8x16u())
    I16x8ExtendHighI8x16U => Ok(@lib.Instruction::i16x8_extend_high_i8x16u())
    I16x8Shl => Ok(@lib.Instruction::i16x8_shl())
    I16x8ShrS => Ok(@lib.Instruction::i16x8_shr_s())
    I16x8ShrU => Ok(@lib.Instruction::i16x8_shr_u())
    I16x8Add => Ok(@lib.Instruction::i16x8_add())
    I16x8AddSatS => Ok(@lib.Instruction::i16x8_add_sat_s())
    I16x8AddSatU => Ok(@lib.Instruction::i16x8_add_sat_u())
    I16x8Sub => Ok(@lib.Instruction::i16x8_sub())
    I16x8SubSatS => Ok(@lib.Instruction::i16x8_sub_sat_s())
    I16x8SubSatU => Ok(@lib.Instruction::i16x8_sub_sat_u())
    I16x8Mul => Ok(@lib.Instruction::i16x8_mul())
    I16x8MinS => Ok(@lib.Instruction::i16x8_min_s())
    I16x8MinU => Ok(@lib.Instruction::i16x8_min_u())
    I16x8MaxS => Ok(@lib.Instruction::i16x8_max_s())
    I16x8MaxU => Ok(@lib.Instruction::i16x8_max_u())
    I16x8AvgrU => Ok(@lib.Instruction::i16x8_avgr_u())
    I16x8ExtmulLowI8x16S => Ok(@lib.Instruction::i16x8_extmul_low_i8x16s())
    I16x8ExtmulHighI8x16S => Ok(@lib.Instruction::i16x8_extmul_high_i8x16s())
    I16x8ExtmulLowI8x16U => Ok(@lib.Instruction::i16x8_extmul_low_i8x16u())
    I16x8ExtmulHighI8x16U => Ok(@lib.Instruction::i16x8_extmul_high_i8x16u())
    I32x4Eq => Ok(@lib.Instruction::i32x4_eq())
    I32x4Ne => Ok(@lib.Instruction::i32x4_ne())
    I32x4LtS => Ok(@lib.Instruction::i32x4_lt_s())
    I32x4LtU => Ok(@lib.Instruction::i32x4_lt_u())
    I32x4GtS => Ok(@lib.Instruction::i32x4_gt_s())
    I32x4GtU => Ok(@lib.Instruction::i32x4_gt_u())
    I32x4LeS => Ok(@lib.Instruction::i32x4_le_s())
    I32x4LeU => Ok(@lib.Instruction::i32x4_le_u())
    I32x4GeS => Ok(@lib.Instruction::i32x4_ge_s())
    I32x4GeU => Ok(@lib.Instruction::i32x4_ge_u())
    I32x4Abs => Ok(@lib.Instruction::i32x4_abs())
    I32x4Neg => Ok(@lib.Instruction::i32x4_neg())
    I32x4AllTrue => Ok(@lib.Instruction::i32x4_all_true())
    I32x4Bitmask => Ok(@lib.Instruction::i32x4_bitmask())
    I32x4ExtendLowI16x8S => Ok(@lib.Instruction::i32x4_extend_low_i16x8s())
    I32x4ExtendHighI16x8S => Ok(@lib.Instruction::i32x4_extend_high_i16x8s())
    I32x4ExtendLowI16x8U => Ok(@lib.Instruction::i32x4_extend_low_i16x8u())
    I32x4ExtendHighI16x8U => Ok(@lib.Instruction::i32x4_extend_high_i16x8u())
    I32x4Shl => Ok(@lib.Instruction::i32x4_shl())
    I32x4ShrS => Ok(@lib.Instruction::i32x4_shr_s())
    I32x4ShrU => Ok(@lib.Instruction::i32x4_shr_u())
    I32x4Add => Ok(@lib.Instruction::i32x4_add())
    I32x4Sub => Ok(@lib.Instruction::i32x4_sub())
    I32x4Mul => Ok(@lib.Instruction::i32x4_mul())
    I32x4MinS => Ok(@lib.Instruction::i32x4_min_s())
    I32x4MinU => Ok(@lib.Instruction::i32x4_min_u())
    I32x4MaxS => Ok(@lib.Instruction::i32x4_max_s())
    I32x4MaxU => Ok(@lib.Instruction::i32x4_max_u())
    I32x4DotI16x8S => Ok(@lib.Instruction::i32x4_dot_i16x8s())
    I32x4ExtmulLowI16x8S => Ok(@lib.Instruction::i32x4_extmul_low_i16x8s())
    I32x4ExtmulHighI16x8S => Ok(@lib.Instruction::i32x4_extmul_high_i16x8s())
    I32x4ExtmulLowI16x8U => Ok(@lib.Instruction::i32x4_extmul_low_i16x8u())
    I32x4ExtmulHighI16x8U => Ok(@lib.Instruction::i32x4_extmul_high_i16x8u())
    I32x4TruncSatF32x4S => Ok(@lib.Instruction::i32x4_trunc_sat_f32x4s())
    I32x4TruncSatF32x4U => Ok(@lib.Instruction::i32x4_trunc_sat_f32x4u())
    I32x4TruncSatF64x2SZero =>
      Ok(@lib.Instruction::i32x4_trunc_sat_f64x2s_zero())
    I32x4TruncSatF64x2UZero =>
      Ok(@lib.Instruction::i32x4_trunc_sat_f64x2u_zero())
    I64x2Eq => Ok(@lib.Instruction::i64x2_eq())
    I64x2Ne => Ok(@lib.Instruction::i64x2_ne())
    I64x2LtS => Ok(@lib.Instruction::i64x2_lt_s())
    I64x2GtS => Ok(@lib.Instruction::i64x2_gt_s())
    I64x2LeS => Ok(@lib.Instruction::i64x2_le_s())
    I64x2GeS => Ok(@lib.Instruction::i64x2_ge_s())
    I64x2Abs => Ok(@lib.Instruction::i64x2_abs())
    I64x2Neg => Ok(@lib.Instruction::i64x2_neg())
    I64x2AllTrue => Ok(@lib.Instruction::i64x2_all_true())
    I64x2Bitmask => Ok(@lib.Instruction::i64x2_bitmask())
    I64x2ExtendLowI32x4S => Ok(@lib.Instruction::i64x2_extend_low_i32x4s())
    I64x2ExtendHighI32x4S => Ok(@lib.Instruction::i64x2_extend_high_i32x4s())
    I64x2ExtendLowI32x4U => Ok(@lib.Instruction::i64x2_extend_low_i32x4u())
    I64x2ExtendHighI32x4U => Ok(@lib.Instruction::i64x2_extend_high_i32x4u())
    I64x2Shl => Ok(@lib.Instruction::i64x2_shl())
    I64x2ShrS => Ok(@lib.Instruction::i64x2_shr_s())
    I64x2ShrU => Ok(@lib.Instruction::i64x2_shr_u())
    I64x2Add => Ok(@lib.Instruction::i64x2_add())
    I64x2Sub => Ok(@lib.Instruction::i64x2_sub())
    I64x2Mul => Ok(@lib.Instruction::i64x2_mul())
    I64x2ExtmulLowI32x4S => Ok(@lib.Instruction::i64x2_extmul_low_i32x4s())
    I64x2ExtmulHighI32x4S => Ok(@lib.Instruction::i64x2_extmul_high_i32x4s())
    I64x2ExtmulLowI32x4U => Ok(@lib.Instruction::i64x2_extmul_low_i32x4u())
    I64x2ExtmulHighI32x4U => Ok(@lib.Instruction::i64x2_extmul_high_i32x4u())
    F32x4Eq => Ok(@lib.Instruction::f32x4_eq())
    F32x4Ne => Ok(@lib.Instruction::f32x4_ne())
    F32x4Lt => Ok(@lib.Instruction::f32x4_lt())
    F32x4Gt => Ok(@lib.Instruction::f32x4_gt())
    F32x4Le => Ok(@lib.Instruction::f32x4_le())
    F32x4Ge => Ok(@lib.Instruction::f32x4_ge())
    F32x4Abs => Ok(@lib.Instruction::f32x4_abs())
    F32x4Neg => Ok(@lib.Instruction::f32x4_neg())
    F32x4Sqrt => Ok(@lib.Instruction::f32x4_sqrt())
    F32x4Add => Ok(@lib.Instruction::f32x4_add())
    F32x4Sub => Ok(@lib.Instruction::f32x4_sub())
    F32x4Mul => Ok(@lib.Instruction::f32x4_mul())
    F32x4Div => Ok(@lib.Instruction::f32x4_div())
    F32x4Min => Ok(@lib.Instruction::f32x4_min())
    F32x4Max => Ok(@lib.Instruction::f32x4_max())
    F32x4Pmin => Ok(@lib.Instruction::f32x4_pmin())
    F32x4Pmax => Ok(@lib.Instruction::f32x4_pmax())
    F32x4Ceil => Ok(@lib.Instruction::f32x4_ceil())
    F32x4Floor => Ok(@lib.Instruction::f32x4_floor())
    F32x4Trunc => Ok(@lib.Instruction::f32x4_trunc())
    F32x4Nearest => Ok(@lib.Instruction::f32x4_nearest())
    F32x4ConvertI32x4S => Ok(@lib.Instruction::f32x4_convert_i32x4s())
    F32x4ConvertI32x4U => Ok(@lib.Instruction::f32x4_convert_i32x4u())
    F32x4DemoteF64x2Zero => Ok(@lib.Instruction::f32x4_demote_f64x2_zero())
    F64x2Eq => Ok(@lib.Instruction::f64x2_eq())
    F64x2Ne => Ok(@lib.Instruction::f64x2_ne())
    F64x2Lt => Ok(@lib.Instruction::f64x2_lt())
    F64x2Gt => Ok(@lib.Instruction::f64x2_gt())
    F64x2Le => Ok(@lib.Instruction::f64x2_le())
    F64x2Ge => Ok(@lib.Instruction::f64x2_ge())
    F64x2Abs => Ok(@lib.Instruction::f64x2_abs())
    F64x2Neg => Ok(@lib.Instruction::f64x2_neg())
    F64x2Sqrt => Ok(@lib.Instruction::f64x2_sqrt())
    F64x2Add => Ok(@lib.Instruction::f64x2_add())
    F64x2Sub => Ok(@lib.Instruction::f64x2_sub())
    F64x2Mul => Ok(@lib.Instruction::f64x2_mul())
    F64x2Div => Ok(@lib.Instruction::f64x2_div())
    F64x2Min => Ok(@lib.Instruction::f64x2_min())
    F64x2Max => Ok(@lib.Instruction::f64x2_max())
    F64x2Pmin => Ok(@lib.Instruction::f64x2_pmin())
    F64x2Pmax => Ok(@lib.Instruction::f64x2_pmax())
    F64x2Ceil => Ok(@lib.Instruction::f64x2_ceil())
    F64x2Floor => Ok(@lib.Instruction::f64x2_floor())
    F64x2Trunc => Ok(@lib.Instruction::f64x2_trunc())
    F64x2Nearest => Ok(@lib.Instruction::f64x2_nearest())
    F64x2ConvertLowI32x4S => Ok(@lib.Instruction::f64x2_convert_low_i32x4s())
    F64x2ConvertLowI32x4U => Ok(@lib.Instruction::f64x2_convert_low_i32x4u())
    F64x2PromoteLowF32x4 => Ok(@lib.Instruction::f64x2_promote_low_f32x4())
    I8x16RelaxedSwizzle => Ok(@lib.Instruction::i8x16_relaxed_swizzle())
    I8x16RelaxedLaneselect => Ok(@lib.Instruction::i8x16_relaxed_laneselect())
    I16x8RelaxedLaneselect => Ok(@lib.Instruction::i16x8_relaxed_laneselect())
    I32x4RelaxedLaneselect => Ok(@lib.Instruction::i32x4_relaxed_laneselect())
    I64x2RelaxedLaneselect => Ok(@lib.Instruction::i64x2_relaxed_laneselect())
    I32x4RelaxedTruncF32x4S =>
      Ok(@lib.Instruction::i32x4_relaxed_trunc_f32x4s())
    I32x4RelaxedTruncF32x4U =>
      Ok(@lib.Instruction::i32x4_relaxed_trunc_f32x4u())
    I32x4RelaxedTruncF64x2SZero =>
      Ok(@lib.Instruction::i32x4_relaxed_trunc_zero_f64x2s())
    I32x4RelaxedTruncF64x2UZero =>
      Ok(@lib.Instruction::i32x4_relaxed_trunc_zero_f64x2u())
    F32x4RelaxedMadd => Ok(@lib.Instruction::f32x4_relaxed_madd())
    F32x4RelaxedNmadd => Ok(@lib.Instruction::f32x4_relaxed_nmadd())
    F64x2RelaxedMadd => Ok(@lib.Instruction::f64x2_relaxed_madd())
    F64x2RelaxedNmadd => Ok(@lib.Instruction::f64x2_relaxed_nmadd())
    F32x4RelaxedMin => Ok(@lib.Instruction::f32x4_relaxed_min())
    F32x4RelaxedMax => Ok(@lib.Instruction::f32x4_relaxed_max())
    F64x2RelaxedMin => Ok(@lib.Instruction::f64x2_relaxed_min())
    F64x2RelaxedMax => Ok(@lib.Instruction::f64x2_relaxed_max())
    I16x8RelaxedQ15mulrS => Ok(@lib.Instruction::i16x8_relaxed_q15mulr_s())
    I16x8RelaxedDotI8x16I7x16S =>
      Ok(@lib.Instruction::i16x8_relaxed_dot_i8x16i7x16s())
    I32x4RelaxedDotI8x16I7x16AddS =>
      Ok(@lib.Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s())
    _ => wt_unsupported("\{op}")
  }
}

///|
fn wt_load_store(op : Opcode, ma : MemArg) -> Result[@lib.Instruction, String] {
  let memarg = match wt_mem_arg(ma) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
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
priv struct WTLegacyCtx {
  catch_depth : UInt
  enclosing_try_count : UInt
  try_labels : Array[String]
}

///|
fn wt_index_text(idx : Index) -> String {
  match idx {
    Num(n) => "\{n}"
    Id(name) => name
  }
}

///|
fn wt_default_legacy_ctx() -> WTLegacyCtx {
  { catch_depth: 0U, enclosing_try_count: 0U, try_labels: [] }
}

///|
fn wt_legacy_rethrow_valid(idx : Index, legacy : WTLegacyCtx) -> Bool {
  match idx {
    Num(n) => n < legacy.catch_depth
    Id(_) => false
  }
}

///|
fn wt_legacy_delegate_valid(idx : Index, legacy : WTLegacyCtx) -> Bool {
  match idx {
    Num(n) => n <= legacy.enclosing_try_count
    Id(name) => {
      for label in legacy.try_labels {
        if label == name {
          return true
        }
      }
      false
    }
  }
}

///|
fn wt_legacy_instrs_invalid_reason(
  instrs : Array[Instruction],
  legacy : WTLegacyCtx,
) -> String? {
  for instr in instrs {
    match wt_legacy_instr_invalid_reason(instr, legacy) {
      Some(reason) => return Some(reason)
      None => ()
    }
  }
  None
}

///|
fn wt_legacy_instr_invalid_reason(
  instr : Instruction,
  legacy : WTLegacyCtx,
) -> String? {
  match instr {
    Rethrow(idx) =>
      if wt_legacy_rethrow_valid(idx, legacy) {
        None
      } else {
        Some("invalid legacy rethrow label: \{wt_index_text(idx)}")
      }
    Block(_, body) | Loop(_, body) =>
      wt_legacy_instrs_invalid_reason(body, legacy)
    If(_, then_body, else_body) =>
      match wt_legacy_instrs_invalid_reason(then_body, legacy) {
        Some(reason) => Some(reason)
        None => wt_legacy_instrs_invalid_reason(else_body, legacy)
      }
    TryTable(_, _, body) => wt_legacy_instrs_invalid_reason(body, legacy)
    TryLegacy(bt, body, catches, delegate_target) => {
      if delegate_target is Some(idx) {
        if !wt_legacy_delegate_valid(idx, legacy) {
          return Some("invalid legacy delegate label: \{wt_index_text(idx)}")
        }
      }
      let nested_labels = legacy.try_labels.copy()
      match bt.label {
        Some(lbl) => nested_labels.push(lbl)
        None => ()
      }
      let nested_base : WTLegacyCtx = {
        catch_depth: legacy.catch_depth,
        enclosing_try_count: legacy.enclosing_try_count + 1U,
        try_labels: nested_labels,
      }
      match wt_legacy_instrs_invalid_reason(body, nested_base) {
        Some(reason) => return Some(reason)
        None => ()
      }
      for clause in catches {
        match clause {
          LegacyCatch(_, catch_body) | LegacyCatchAll(catch_body) => {
            let catch_ctx : WTLegacyCtx = {
              catch_depth: nested_base.catch_depth + 1U,
              enclosing_try_count: nested_base.enclosing_try_count,
              try_labels: nested_base.try_labels,
            }
            match wt_legacy_instrs_invalid_reason(catch_body, catch_ctx) {
              Some(reason) => return Some(reason)
              None => ()
            }
          }
        }
      }
      None
    }
    _ => None
  }
}

///|
fn wt_instrs_to_lib(
  ctx : WTLowerCtx,
  instrs : Array[Instruction],
  local_ids : Map[String, UInt],
  labels : Array[String?],
  legacy : WTLegacyCtx,
) -> Result[Array[@lib.Instruction], String] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    let lib_instr = match
      wt_instr_to_lib(ctx, instr, local_ids, labels, legacy) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    out.push(lib_instr)
  }
  Ok(out)
}

///|
fn wt_legacy_synthetic_check_instrs(
  ctx : WTLowerCtx,
  lib_bt : @lib.BlockType,
  bt : BlockType,
  bt_results : Array[@lib.ValType],
  body : Array[Instruction],
  catches : Array[LegacyCatchClause],
  local_ids : Map[String, UInt],
  labels : Array[String?],
  legacy : WTLegacyCtx,
) -> Result[Array[@lib.Instruction], String] {
  let try_labels = legacy.try_labels.copy()
  match bt.label {
    Some(label) => try_labels.push(label)
    None => ()
  }
  let nested_base : WTLegacyCtx = {
    catch_depth: legacy.catch_depth,
    enclosing_try_count: legacy.enclosing_try_count + 1U,
    try_labels,
  }
  let next_labels = labels.copy()
  next_labels.push(bt.label)

  let checks : Array[@lib.Instruction] = []

  let lib_body = match
    wt_instrs_to_lib(ctx, body, local_ids, next_labels, nested_base) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  checks.push(@lib.Instruction::block(lib_bt, @lib.Expr::new(lib_body)))
  for drop_instr in wt_drop_n_instrs(bt_results.length()) {
    checks.push(drop_instr)
  }

  for clause in catches {
    let (payload, catch_body) = match clause {
      LegacyCatch(tag_idx, catch_body) => {
        let ti = match
          wt_resolve_named_or_num_index(
            tag_idx,
            ctx.tag_ids,
            ctx.next_tag_idx,
            "tag",
          ) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let payload = match wt_tag_payload_types(ctx, ti) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        (payload, catch_body)
      }
      LegacyCatchAll(catch_body) => ([], catch_body)
    }

    let catch_ctx : WTLegacyCtx = {
      catch_depth: nested_base.catch_depth + 1U,
      enclosing_try_count: nested_base.enclosing_try_count,
      try_labels: nested_base.try_labels,
    }
    let lib_catch_body = match
      wt_instrs_to_lib(ctx, catch_body, local_ids, next_labels, catch_ctx) {
      Ok(v) => v
      Err(e) => return Err(e)
    }

    for vt in payload {
      let defaults = match wt_default_value_instrs_for_valtype(vt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      for instr in defaults {
        checks.push(instr)
      }
    }

    let loop_type_idx = match
      wt_find_matching_func_type_index(ctx, payload, bt_results) {
      Some(idx) => idx
      None => wt_append_lib_func_type(ctx, payload, bt_results)
    }
    checks.push(
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(loop_type_idx)),
        @lib.Expr::new(lib_catch_body),
      ),
    )
    for drop_instr in wt_drop_n_instrs(bt_results.length()) {
      checks.push(drop_instr)
    }
  }

  Ok(checks)
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
  legacy : WTLegacyCtx,
) -> Result[@lib.Instruction, String] {
  match instr {
    Unreachable => Ok(@lib.Instruction::unreachable_())
    Nop => Ok(@lib.Instruction::nop())
    Block(bt, body) => {
      let next_labels = labels.copy()
      next_labels.push(bt.label)
      let lib_body = match
        wt_instrs_to_lib(ctx, body, local_ids, next_labels, legacy) {
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
      let lib_body = match
        wt_instrs_to_lib(ctx, body, local_ids, next_labels, legacy) {
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
        wt_instrs_to_lib(ctx, then_body, local_ids, next_labels, legacy) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_else = match
        wt_instrs_to_lib(ctx, else_body, local_ids, next_labels, legacy) {
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
    ReturnCall(idx) => {
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
      Ok(@lib.Instruction::return_call(@lib.FuncIdx::new(fi)))
    }
    ReturnCallIndirect(table_idx, type_use) => {
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
        @lib.Instruction::return_call_indirect(
          @lib.TypeIdx::new(ti),
          @lib.TableIdx::new(tbl),
        ),
      )
    }
    ReturnCallRef(type_use) => {
      let ti = match wt_resolve_type_use(ctx, type_use) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::return_call_ref(@lib.TypeIdx::new(ti)))
    }
    Throw(idx) => {
      let ti = match
        wt_resolve_named_or_num_index(idx, ctx.tag_ids, ctx.next_tag_idx, "tag") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::throw_(@lib.TagIdx::new(ti)))
    }
    ThrowRef => Ok(@lib.Instruction::throw_ref())
    Rethrow(idx) =>
      if wt_legacy_rethrow_valid(idx, legacy) {
        Ok(@lib.Instruction::unreachable_())
      } else {
        Err("invalid legacy rethrow label: \{wt_index_text(idx)}")
      }
    TryLegacy(bt, body, catches, _) => {
      match wt_legacy_instr_invalid_reason(instr, legacy) {
        Some(reason) => return Err(reason)
        None => ()
      }
      let lib_bt = match wt_block_type(ctx, bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let bt_results = match wt_block_type_results(ctx, bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let checks = match
        wt_legacy_synthetic_check_instrs(
          ctx,
          lib_bt,
          bt,
          bt_results,
          body,
          catches,
          local_ids,
          labels,
          legacy,
        ) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let block_body = checks.copy()
      block_body.push(@lib.Instruction::unreachable_())
      Ok(@lib.Instruction::block(lib_bt, @lib.Expr::new(block_body)))
    }
    Drop => Ok(@lib.Instruction::drop())
    Select(types) => {
      let lib_types = match wt_select_types(ctx, types) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::select(types=lib_types))
    }
    TryTable(bt, catches, body) => {
      let next_labels = labels.copy()
      next_labels.push(None)
      let catch_labels : Array[String?] = [None]
      for label in labels {
        catch_labels.push(label)
      }
      let lib_bt = match wt_block_type(ctx, bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_body = match
        wt_instrs_to_lib(ctx, body, local_ids, next_labels, legacy) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let lib_catches : Array[@lib.Catch] = []
      for catch_clause in catches {
        match catch_clause {
          CatchClause(tag_idx, label_idx) => {
            let ti = match
              wt_resolve_named_or_num_index(
                tag_idx,
                ctx.tag_ids,
                ctx.next_tag_idx,
                "tag",
              ) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            let li = match wt_resolve_label(label_idx, catch_labels) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            lib_catches.push(
              @lib.Catch::new(@lib.TagIdx::new(ti), @lib.LabelIdx::new(li)),
            )
          }
          CatchRefClause(tag_idx, label_idx) => {
            let ti = match
              wt_resolve_named_or_num_index(
                tag_idx,
                ctx.tag_ids,
                ctx.next_tag_idx,
                "tag",
              ) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            let li = match wt_resolve_label(label_idx, catch_labels) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            lib_catches.push(
              @lib.Catch::ref_(@lib.TagIdx::new(ti), @lib.LabelIdx::new(li)),
            )
          }
          CatchAllClause(label_idx) => {
            let li = match wt_resolve_label(label_idx, catch_labels) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            lib_catches.push(@lib.Catch::all(@lib.LabelIdx::new(li)))
          }
          CatchAllRefClause(label_idx) => {
            let li = match wt_resolve_label(label_idx, catch_labels) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            lib_catches.push(@lib.Catch::all_ref(@lib.LabelIdx::new(li)))
          }
        }
      }
      Ok(
        @lib.Instruction::try_table(
          lib_bt,
          lib_catches,
          @lib.Expr::new(lib_body),
        ),
      )
    }
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
      match wt_ref_heap_type(ctx, vt) {
        Ok(Some(ht)) => Ok(@lib.Instruction::ref_null(ht))
        Ok(None) => Err("unsupported ref.null type: \{vt}")
        Err(e) => Err(e)
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
    V128Load(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load(memarg))
    }
    V128Load8x8S(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load8x8s(memarg))
    }
    V128Load8x8U(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load8x8u(memarg))
    }
    V128Load16x4S(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load16x4s(memarg))
    }
    V128Load16x4U(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load16x4u(memarg))
    }
    V128Load32x2S(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load32x2s(memarg))
    }
    V128Load32x2U(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load32x2u(memarg))
    }
    V128Load8Splat(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load8_splat(memarg))
    }
    V128Load16Splat(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load16_splat(memarg))
    }
    V128Load32Splat(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load32_splat(memarg))
    }
    V128Load64Splat(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load64_splat(memarg))
    }
    V128Load32Zero(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load32_zero(memarg))
    }
    V128Load64Zero(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load64_zero(memarg))
    }
    V128Store(ma) => {
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store(memarg))
    }
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
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load8_lane(memarg, li))
    }
    V128Load16Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load16_lane", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load16_lane(memarg, li))
    }
    V128Load32Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load32_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load32_lane(memarg, li))
    }
    V128Load64Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.load64_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_load64_lane(memarg, li))
    }
    V128Store8Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store8_lane", lane, 15U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store8_lane(memarg, li))
    }
    V128Store16Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store16_lane", lane, 7U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store16_lane(memarg, li))
    }
    V128Store32Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store32_lane", lane, 3U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store32_lane(memarg, li))
    }
    V128Store64Lane(ma, lane) => {
      let li = match wt_lane_idx("v128.store64_lane", lane, 1U) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let memarg = match wt_mem_arg(ma) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(@lib.Instruction::v128_store64_lane(memarg, li))
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
        let idx = match wt_append_type(ctx, td.func_type) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
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
  let tag_defs_raw : Array[(Tag, UInt)] = []
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
            let table_heap_type = match wt_ref_heap_type(ctx, tt.elem_type) {
              Ok(Some(ht)) => ht
              Ok(None) => @lib.HeapType::abs(@lib.AbsHeapType::func())
              Err(e) => return Err(e)
            }
            let table_type = @lib.TableType::new(
              @lib.RefType::new(true, table_heap_type),
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
            let global_vt = match wt_value_type(ctx, gt.val_type) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            imports.push(
              @lib.Import::new(
                @lib.Name::new(im.module_name),
                @lib.Name::new(im.field_name),
                @lib.ExternType::global(
                  @lib.GlobalType::new(global_vt, gt.mutable_),
                ),
              ),
            )
            match im.id {
              Some(id) => ctx.global_ids[id] = ctx.next_global_idx
              None => ()
            }
            ctx.next_global_idx += 1
          }
          Tag(type_use) => {
            let ti = match wt_resolve_type_use(ctx, type_use) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            imports.push(
              @lib.Import::new(
                @lib.Name::new(im.module_name),
                @lib.Name::new(im.field_name),
                @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(ti))),
              ),
            )
            match im.id {
              Some(id) => ctx.tag_ids[id] = ctx.next_tag_idx
              None => ()
            }
            ctx.tag_type_idxs.push(ti)
            ctx.next_tag_idx += 1
          }
        }
      FuncField(f) => {
        let func_idx = ctx.next_func_idx
        for inline_export in f.exports {
          match inline_export {
            Export(name) =>
              export_defs.push({ name, desc: ExportDesc::Func(Num(func_idx)) })
          }
        }
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
        let table_idx = ctx.next_table_idx
        for inline_export in t.exports {
          match inline_export {
            Export(name) =>
              export_defs.push({ name, desc: ExportDesc::Table(Num(table_idx)) })
          }
        }
        match t.elem_init {
          Some(func_indices) => {
            let elem_exprs = t.elem_exprs.unwrap_or([])
            let mut has_non_ref_func_item = false
            let mut i = 0
            while i < elem_exprs.length() {
              if wt_elem_item_ref_func_index(elem_exprs[i]) is None {
                has_non_ref_func_item = true
              }
              i += 1
            }
            let elem_type : ValueType? = match t.elem_init_type {
              Some(v) => Some(v)
              None =>
                if has_non_ref_func_item {
                  Some(t.table_type.elem_type)
                } else {
                  None
                }
            }
            elem_defs_raw.push({
              id: None,
              table_index: Num(table_idx),
              offset: t.elem_offset.unwrap_or([Const(I32Const, "0")]),
              func_indices,
              elem_exprs,
              elem_type,
            })
            ctx.next_elem_idx += 1
          }
          None => ()
        }
        table_defs_raw.push(t)
        match t.id {
          Some(id) => ctx.table_ids[id] = ctx.next_table_idx
          None => ()
        }
        ctx.next_table_idx += 1
      }
      MemoryField(m) => {
        let mem_idx = ctx.next_mem_idx
        for inline_export in m.exports {
          match inline_export {
            Export(name) =>
              export_defs.push({ name, desc: ExportDesc::Memory(Num(mem_idx)) })
          }
        }
        mem_defs_raw.push(m)
        match m.id {
          Some(id) => ctx.mem_ids[id] = ctx.next_mem_idx
          None => ()
        }
        ctx.next_mem_idx += 1
      }
      GlobalField(g) => {
        let global_idx = ctx.next_global_idx
        for inline_export in g.exports {
          match inline_export {
            Export(name) =>
              export_defs.push({
                name,
                desc: ExportDesc::Global(Num(global_idx)),
              })
          }
        }
        global_defs_raw.push(g)
        match g.id {
          Some(id) => ctx.global_ids[id] = ctx.next_global_idx
          None => ()
        }
        ctx.next_global_idx += 1
      }
      TagField(t) => {
        let ti = match wt_resolve_type_use(ctx, t.type_use) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let tag_idx = ctx.next_tag_idx
        for inline_export in t.exports {
          match inline_export {
            Export(name) =>
              export_defs.push({ name, desc: ExportDesc::Tag(Num(tag_idx)) })
          }
        }
        tag_defs_raw.push((t, ti))
        match t.id {
          Some(id) => ctx.tag_ids[id] = ctx.next_tag_idx
          None => ()
        }
        ctx.tag_type_idxs.push(ti)
        ctx.next_tag_idx += 1
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
    let mut param_idx = 0U
    for param_id in f.type_use.param_ids {
      match param_id {
        Some(id) => local_ids[id] = param_idx
        None => ()
      }
      param_idx += 1
    }
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
    let body = match
      wt_instrs_to_lib(ctx, f.body, local_ids, [], wt_default_legacy_ctx()) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let local_types : Array[@lib.ValType] = []
    for loc in f.locals {
      let local_vt = match wt_value_type(ctx, loc.val_type) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      local_types.push(local_vt)
    }
    let locals : Array[@lib.Locals] = []
    for vt in local_types {
      locals.push(@lib.Locals::new(1U, vt))
    }
    code_funcs.push(@lib.Func::new(locals, @lib.Expr::new(body)))
  }

  let table_defs : Array[@lib.Table] = []
  for t in table_defs_raw {
    let ht = match wt_ref_heap_type(ctx, t.table_type.elem_type) {
      Ok(Some(v)) => v
      Ok(None) => @lib.HeapType::abs(@lib.AbsHeapType::func())
      Err(e) => return Err(e)
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
    let init = match
      wt_instrs_to_lib(ctx, g.init, {}, [], wt_default_legacy_ctx()) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let global_vt = match wt_value_type(ctx, g.global_type.val_type) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    global_defs.push(
      @lib.Global::new(
        @lib.GlobalType::new(global_vt, g.global_type.mutable_),
        @lib.Expr::new(init),
      ),
    )
  }

  let tag_defs : Array[@lib.TagType] = []
  for entry in tag_defs_raw {
    let (_, ti) = entry
    tag_defs.push(@lib.TagType::new(@lib.TypeIdx::new(ti)))
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
      Tag(idx) =>
        match
          wt_resolve_named_or_num_index(
            idx,
            ctx.tag_ids,
            ctx.next_tag_idx,
            "tag",
          ) {
          Ok(v) => @lib.ExternIdx::tag(@lib.TagIdx::new(v))
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
    let funcs_from_indices : Array[@lib.FuncIdx] = []
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
      funcs_from_indices.push(@lib.FuncIdx::new(fi))
    }
    let mode = if e.offset.length() == 0 {
      @lib.ElemMode::passive()
    } else {
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
      let offset = match
        wt_instrs_to_lib(ctx, e.offset, {}, [], wt_default_legacy_ctx()) {
        Ok(v) => @lib.Expr::new(v)
        Err(e) => return Err(e)
      }
      @lib.ElemMode::active(@lib.TableIdx::new(table_idx), offset)
    }
    let elem_type_hint = e.elem_type
    let elem_exprs = e.elem_exprs
    let funcs_from_items : Array[@lib.FuncIdx] = []
    let mut has_non_ref_func_item = false
    let mut has_explicit_typed_item = false
    let mut item_i = 0
    while item_i < elem_exprs.length() {
      let item = elem_exprs[item_i]
      if item.explicit_item {
        has_explicit_typed_item = true
      }
      match wt_elem_item_ref_func_index(item) {
        Some(idx) => {
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
          funcs_from_items.push(@lib.FuncIdx::new(fi))
        }
        None => has_non_ref_func_item = true
      }
      item_i += 1
    }

    let has_explicit_typed_intent = match elem_type_hint {
      Some(_) => true
      None => has_explicit_typed_item
    }

    if !has_non_ref_func_item && !has_explicit_typed_intent {
      let funcs : Array[@lib.FuncIdx] = []
      for fi in funcs_from_indices {
        funcs.push(fi)
      }
      for fi in funcs_from_items {
        funcs.push(fi)
      }
      elems.push(@lib.Elem::new(mode, @lib.ElemKind::funcs(funcs)))
      continue
    }

    let exprs : Array[@lib.Expr] = []
    for fi in funcs_from_indices {
      exprs.push(@lib.Expr::new([@lib.Instruction::ref_func(fi)]))
    }
    let mut expr_i = 0
    while expr_i < elem_exprs.length() {
      let item = elem_exprs[expr_i]
      match wt_elem_item_ref_func_index(item) {
        Some(idx) => {
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
          exprs.push(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(fi))]),
          )
        }
        None =>
          match wt_elem_item_to_expr(ctx, item) {
            Ok(expr) => exprs.push(expr)
            Err(e) => return Err(e)
          }
      }
      expr_i += 1
    }

    let elem_ref_type = match elem_type_hint {
      Some(vt) =>
        match wt_ref_type_for_elem_value_type(ctx, vt) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      None =>
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func()))
    }
    elems.push(
      @lib.Elem::new(mode, @lib.ElemKind::typed_exprs(elem_ref_type, exprs)),
    )
  }

  let datas : Array[@lib.Data] = []
  for d in data_defs_raw {
    if d.offset.length() == 0 {
      datas.push(@lib.Data::new(@lib.DataMode::passive(), d.data))
    } else {
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
      let offset = match
        wt_instrs_to_lib(ctx, d.offset, {}, [], wt_default_legacy_ctx()) {
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
  if tag_defs.length() > 0 {
    out = out.with_tag_sec(@lib.TagSec::new(tag_defs))
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
test "wast_to_binary_module resolves named params in function bodies" {
  let lowered = match
    wast_to_binary_module("(module (func (param $x i32) local.get $x drop))") {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(i)), _]))]
      )
    ) => assert_eq(i, 0U)
    _ => fail("expected local.get on lowered named param")
  }
}

///|
test "wast_to_binary_module resolves named params after explicit type use" {
  let lowered = match
    wast_to_binary_module(
      "(module (type (func (param i32) (result i32))) (func (type 0) (param $x i32) (result i32) local.get $x))",
    ) {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec([@lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(i))]))])
    ) => assert_eq(i, 0U)
    _ => fail("expected named type-use param to lower to local index 0")
  }
}

///|
test "wast_to_binary_module rejects malformed text align literals" {
  assert_true(
    wt_lower_error_contains(
      "(module (memory 0) (func (drop (i32.load8_s align=0 (i32.const 0)))))", "alignment",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (memory 0) (func (drop (i32.load8_s align=7 (i32.const 0)))))", "alignment",
    ),
  )
}

///|
test "wast_to_binary_module lowers text align bytes to exponent memargs" {
  let lowered = match
    wast_to_binary_module(
      "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load align=4))",
    ) {
    Ok(m) => m
    Err(e) => fail("expected lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.LocalGet(@lib.LocalIdx(0)), instr]))]
      )
    ) =>
      assert_eq(
        instr,
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0)),
        ),
      )
    _ => fail("expected i32.load with exponent-form memarg alignment")
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
          @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0)),
          @lib.LaneIdx::new(5),
        ),
      )
      assert_eq(
        store_lane_instr,
        @lib.Instruction::v128_store8_lane(
          @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0)),
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
  let ma16 = @lib.MemArg::new(@lib.U32(4), None, @lib.U64(0))
  let ma8 = @lib.MemArg::new(@lib.U32(3), None, @lib.U64(0))
  let ma4 = @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0))
  let ma2 = @lib.MemArg::new(@lib.U32(1), None, @lib.U64(0))
  let ma1 = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
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
test "wast_to_binary_module lowers SIMD i8x16 no-immediate ops" {
  let src =
    #|(module
    #|  (func (param v128 v128 i32)
    #|    local.get 0
    #|    i8x16.abs
    #|    drop
    #|    local.get 0
    #|    i8x16.neg
    #|    drop
    #|    local.get 0
    #|    i8x16.popcnt
    #|    drop
    #|    local.get 0
    #|    i8x16.all_true
    #|    drop
    #|    local.get 0
    #|    i8x16.bitmask
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.eq
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.ne
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.lt_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.lt_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.gt_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.gt_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.le_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.le_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.ge_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.ge_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.narrow_i16x8_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.narrow_i16x8_u
    #|    drop
    #|    local.get 0
    #|    local.get 2
    #|    i8x16.shl
    #|    drop
    #|    local.get 0
    #|    local.get 2
    #|    i8x16.shr_s
    #|    drop
    #|    local.get 0
    #|    local.get 2
    #|    i8x16.shr_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.add
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.add_sat_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.add_sat_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.sub
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.sub_sat_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.sub_sat_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.min_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.min_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.max_s
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.max_u
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.avgr_u
    #|    drop))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected i8x16 no-immediate lowering success: \{e}")
  }
  let expected : Array[@lib.Instruction] = [
    @lib.Instruction::i8x16_abs(),
    @lib.Instruction::i8x16_neg(),
    @lib.Instruction::i8x16_popcnt(),
    @lib.Instruction::i8x16_all_true(),
    @lib.Instruction::i8x16_bitmask(),
    @lib.Instruction::i8x16_eq(),
    @lib.Instruction::i8x16_ne(),
    @lib.Instruction::i8x16_lt_s(),
    @lib.Instruction::i8x16_lt_u(),
    @lib.Instruction::i8x16_gt_s(),
    @lib.Instruction::i8x16_gt_u(),
    @lib.Instruction::i8x16_le_s(),
    @lib.Instruction::i8x16_le_u(),
    @lib.Instruction::i8x16_ge_s(),
    @lib.Instruction::i8x16_ge_u(),
    @lib.Instruction::i8x16_narrow_i16x8s(),
    @lib.Instruction::i8x16_narrow_i16x8u(),
    @lib.Instruction::i8x16_shl(),
    @lib.Instruction::i8x16_shr_s(),
    @lib.Instruction::i8x16_shr_u(),
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::i8x16_add_sat_s(),
    @lib.Instruction::i8x16_add_sat_u(),
    @lib.Instruction::i8x16_sub(),
    @lib.Instruction::i8x16_sub_sat_s(),
    @lib.Instruction::i8x16_sub_sat_u(),
    @lib.Instruction::i8x16_min_s(),
    @lib.Instruction::i8x16_min_u(),
    @lib.Instruction::i8x16_max_s(),
    @lib.Instruction::i8x16_max_u(),
    @lib.Instruction::i8x16_avgr_u(),
  ]
  match lowered.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => {
      let lowered_ops : Array[@lib.Instruction] = []
      for instr in body {
        match instr {
          @lib.LocalGet(_) | @lib.Drop => ()
          _ => lowered_ops.push(instr)
        }
      }
      assert_eq(lowered_ops, expected)
    }
    _ => fail("expected lowered module code section for i8x16 no-immediate ops")
  }
}

///|
test "wast_to_binary_module lowers SIMD no-immediate ops for i16x8 i32x4 i64x2 f32x4 f64x2" {
  let src =
    #|(module
    #|  (func (param v128 v128 i32)
    #|    local.get 0 local.get 1 i16x8.eq drop
    #|    local.get 0 local.get 1 i16x8.ne drop
    #|    local.get 0 local.get 1 i16x8.lt_s drop
    #|    local.get 0 local.get 1 i16x8.lt_u drop
    #|    local.get 0 local.get 1 i16x8.gt_s drop
    #|    local.get 0 local.get 1 i16x8.gt_u drop
    #|    local.get 0 local.get 1 i16x8.le_s drop
    #|    local.get 0 local.get 1 i16x8.le_u drop
    #|    local.get 0 local.get 1 i16x8.ge_s drop
    #|    local.get 0 local.get 1 i16x8.ge_u drop
    #|    local.get 0 i16x8.abs drop
    #|    local.get 0 i16x8.neg drop
    #|    local.get 0 local.get 1 i16x8.q15mulr_sat_s drop
    #|    local.get 0 i16x8.all_true drop
    #|    local.get 0 i16x8.bitmask drop
    #|    local.get 0 local.get 1 i16x8.narrow_i32x4_s drop
    #|    local.get 0 local.get 1 i16x8.narrow_i32x4_u drop
    #|    local.get 0 i16x8.extend_low_i8x16_s drop
    #|    local.get 0 i16x8.extend_high_i8x16_s drop
    #|    local.get 0 i16x8.extend_low_i8x16_u drop
    #|    local.get 0 i16x8.extend_high_i8x16_u drop
    #|    local.get 0 local.get 2 i16x8.shl drop
    #|    local.get 0 local.get 2 i16x8.shr_s drop
    #|    local.get 0 local.get 2 i16x8.shr_u drop
    #|    local.get 0 local.get 1 i16x8.add drop
    #|    local.get 0 local.get 1 i16x8.add_sat_s drop
    #|    local.get 0 local.get 1 i16x8.add_sat_u drop
    #|    local.get 0 local.get 1 i16x8.sub drop
    #|    local.get 0 local.get 1 i16x8.sub_sat_s drop
    #|    local.get 0 local.get 1 i16x8.sub_sat_u drop
    #|    local.get 0 local.get 1 i16x8.mul drop
    #|    local.get 0 local.get 1 i16x8.min_s drop
    #|    local.get 0 local.get 1 i16x8.min_u drop
    #|    local.get 0 local.get 1 i16x8.max_s drop
    #|    local.get 0 local.get 1 i16x8.max_u drop
    #|    local.get 0 local.get 1 i16x8.avgr_u drop
    #|    local.get 0 local.get 1 i16x8.extmul_low_i8x16_s drop
    #|    local.get 0 local.get 1 i16x8.extmul_high_i8x16_s drop
    #|    local.get 0 local.get 1 i16x8.extmul_low_i8x16_u drop
    #|    local.get 0 local.get 1 i16x8.extmul_high_i8x16_u drop)
    #|  (func (param v128 v128 i32)
    #|    local.get 0 local.get 1 i32x4.eq drop
    #|    local.get 0 local.get 1 i32x4.ne drop
    #|    local.get 0 local.get 1 i32x4.lt_s drop
    #|    local.get 0 local.get 1 i32x4.lt_u drop
    #|    local.get 0 local.get 1 i32x4.gt_s drop
    #|    local.get 0 local.get 1 i32x4.gt_u drop
    #|    local.get 0 local.get 1 i32x4.le_s drop
    #|    local.get 0 local.get 1 i32x4.le_u drop
    #|    local.get 0 local.get 1 i32x4.ge_s drop
    #|    local.get 0 local.get 1 i32x4.ge_u drop
    #|    local.get 0 i32x4.abs drop
    #|    local.get 0 i32x4.neg drop
    #|    local.get 0 i32x4.all_true drop
    #|    local.get 0 i32x4.bitmask drop
    #|    local.get 0 i32x4.extend_low_i16x8_s drop
    #|    local.get 0 i32x4.extend_high_i16x8_s drop
    #|    local.get 0 i32x4.extend_low_i16x8_u drop
    #|    local.get 0 i32x4.extend_high_i16x8_u drop
    #|    local.get 0 local.get 2 i32x4.shl drop
    #|    local.get 0 local.get 2 i32x4.shr_s drop
    #|    local.get 0 local.get 2 i32x4.shr_u drop
    #|    local.get 0 local.get 1 i32x4.add drop
    #|    local.get 0 local.get 1 i32x4.sub drop
    #|    local.get 0 local.get 1 i32x4.mul drop
    #|    local.get 0 local.get 1 i32x4.min_s drop
    #|    local.get 0 local.get 1 i32x4.min_u drop
    #|    local.get 0 local.get 1 i32x4.max_s drop
    #|    local.get 0 local.get 1 i32x4.max_u drop
    #|    local.get 0 local.get 1 i32x4.dot_i16x8_s drop
    #|    local.get 0 local.get 1 i32x4.extmul_low_i16x8_s drop
    #|    local.get 0 local.get 1 i32x4.extmul_high_i16x8_s drop
    #|    local.get 0 local.get 1 i32x4.extmul_low_i16x8_u drop
    #|    local.get 0 local.get 1 i32x4.extmul_high_i16x8_u drop
    #|    local.get 0 i32x4.trunc_sat_f32x4_s drop
    #|    local.get 0 i32x4.trunc_sat_f32x4_u drop
    #|    local.get 0 i32x4.trunc_sat_f64x2_s_zero drop
    #|    local.get 0 i32x4.trunc_sat_f64x2_u_zero drop)
    #|  (func (param v128 v128 i32)
    #|    local.get 0 local.get 1 i64x2.eq drop
    #|    local.get 0 local.get 1 i64x2.ne drop
    #|    local.get 0 local.get 1 i64x2.lt_s drop
    #|    local.get 0 local.get 1 i64x2.gt_s drop
    #|    local.get 0 local.get 1 i64x2.le_s drop
    #|    local.get 0 local.get 1 i64x2.ge_s drop
    #|    local.get 0 i64x2.abs drop
    #|    local.get 0 i64x2.neg drop
    #|    local.get 0 i64x2.all_true drop
    #|    local.get 0 i64x2.bitmask drop
    #|    local.get 0 i64x2.extend_low_i32x4_s drop
    #|    local.get 0 i64x2.extend_high_i32x4_s drop
    #|    local.get 0 i64x2.extend_low_i32x4_u drop
    #|    local.get 0 i64x2.extend_high_i32x4_u drop
    #|    local.get 0 local.get 2 i64x2.shl drop
    #|    local.get 0 local.get 2 i64x2.shr_s drop
    #|    local.get 0 local.get 2 i64x2.shr_u drop
    #|    local.get 0 local.get 1 i64x2.add drop
    #|    local.get 0 local.get 1 i64x2.sub drop
    #|    local.get 0 local.get 1 i64x2.mul drop
    #|    local.get 0 local.get 1 i64x2.extmul_low_i32x4_s drop
    #|    local.get 0 local.get 1 i64x2.extmul_high_i32x4_s drop
    #|    local.get 0 local.get 1 i64x2.extmul_low_i32x4_u drop
    #|    local.get 0 local.get 1 i64x2.extmul_high_i32x4_u drop)
    #|  (func (param v128 v128)
    #|    local.get 0 local.get 1 f32x4.eq drop
    #|    local.get 0 local.get 1 f32x4.ne drop
    #|    local.get 0 local.get 1 f32x4.lt drop
    #|    local.get 0 local.get 1 f32x4.gt drop
    #|    local.get 0 local.get 1 f32x4.le drop
    #|    local.get 0 local.get 1 f32x4.ge drop
    #|    local.get 0 f32x4.abs drop
    #|    local.get 0 f32x4.neg drop
    #|    local.get 0 f32x4.sqrt drop
    #|    local.get 0 local.get 1 f32x4.add drop
    #|    local.get 0 local.get 1 f32x4.sub drop
    #|    local.get 0 local.get 1 f32x4.mul drop
    #|    local.get 0 local.get 1 f32x4.div drop
    #|    local.get 0 local.get 1 f32x4.min drop
    #|    local.get 0 local.get 1 f32x4.max drop
    #|    local.get 0 local.get 1 f32x4.pmin drop
    #|    local.get 0 local.get 1 f32x4.pmax drop
    #|    local.get 0 f32x4.ceil drop
    #|    local.get 0 f32x4.floor drop
    #|    local.get 0 f32x4.trunc drop
    #|    local.get 0 f32x4.nearest drop
    #|    local.get 0 f32x4.convert_i32x4_s drop
    #|    local.get 0 f32x4.convert_i32x4_u drop
    #|    local.get 0 f32x4.demote_f64x2_zero drop)
    #|  (func (param v128 v128)
    #|    local.get 0 local.get 1 f64x2.eq drop
    #|    local.get 0 local.get 1 f64x2.ne drop
    #|    local.get 0 local.get 1 f64x2.lt drop
    #|    local.get 0 local.get 1 f64x2.gt drop
    #|    local.get 0 local.get 1 f64x2.le drop
    #|    local.get 0 local.get 1 f64x2.ge drop
    #|    local.get 0 f64x2.abs drop
    #|    local.get 0 f64x2.neg drop
    #|    local.get 0 f64x2.sqrt drop
    #|    local.get 0 local.get 1 f64x2.add drop
    #|    local.get 0 local.get 1 f64x2.sub drop
    #|    local.get 0 local.get 1 f64x2.mul drop
    #|    local.get 0 local.get 1 f64x2.div drop
    #|    local.get 0 local.get 1 f64x2.min drop
    #|    local.get 0 local.get 1 f64x2.max drop
    #|    local.get 0 local.get 1 f64x2.pmin drop
    #|    local.get 0 local.get 1 f64x2.pmax drop
    #|    local.get 0 f64x2.ceil drop
    #|    local.get 0 f64x2.floor drop
    #|    local.get 0 f64x2.trunc drop
    #|    local.get 0 f64x2.nearest drop
    #|    local.get 0 f64x2.convert_low_i32x4_s drop
    #|    local.get 0 f64x2.convert_low_i32x4_u drop
    #|    local.get 0 f64x2.promote_low_f32x4 drop))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected non-i8x16 SIMD no-immediate lowering success for full family coverage: \{e}",
      )
  }
  match lowered.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      assert_eq(funcs.length(), 5)

      match funcs[0] {
        @lib.Func(_, @lib.Expr(body)) => {
          let lowered_ops : Array[@lib.Instruction] = []
          for instr in body {
            match instr {
              @lib.LocalGet(_) | @lib.Drop => ()
              _ => lowered_ops.push(instr)
            }
          }
          assert_eq(lowered_ops[0], @lib.Instruction::i16x8_eq())
          assert_eq(lowered_ops[12], @lib.Instruction::i16x8q15mulr_sat_s())
          assert_eq(lowered_ops[21], @lib.Instruction::i16x8_shl())
          assert_eq(lowered_ops[35], @lib.Instruction::i16x8_avgr_u())
          assert_eq(
            lowered_ops[39],
            @lib.Instruction::i16x8_extmul_high_i8x16u(),
          )
        }
        _ => fail("expected i16x8 no-immediate lowered body")
      }

      match funcs[1] {
        @lib.Func(_, @lib.Expr(body)) => {
          let lowered_ops : Array[@lib.Instruction] = []
          for instr in body {
            match instr {
              @lib.LocalGet(_) | @lib.Drop => ()
              _ => lowered_ops.push(instr)
            }
          }
          assert_eq(lowered_ops[0], @lib.Instruction::i32x4_eq())
          assert_eq(lowered_ops[18], @lib.Instruction::i32x4_shl())
          assert_eq(lowered_ops[28], @lib.Instruction::i32x4_dot_i16x8s())
          assert_eq(lowered_ops[33], @lib.Instruction::i32x4_trunc_sat_f32x4s())
          assert_eq(
            lowered_ops[36],
            @lib.Instruction::i32x4_trunc_sat_f64x2u_zero(),
          )
        }
        _ => fail("expected i32x4 no-immediate lowered body")
      }

      match funcs[2] {
        @lib.Func(_, @lib.Expr(body)) => {
          let lowered_ops : Array[@lib.Instruction] = []
          for instr in body {
            match instr {
              @lib.LocalGet(_) | @lib.Drop => ()
              _ => lowered_ops.push(instr)
            }
          }
          assert_eq(lowered_ops[0], @lib.Instruction::i64x2_eq())
          assert_eq(lowered_ops[14], @lib.Instruction::i64x2_shl())
          assert_eq(lowered_ops[19], @lib.Instruction::i64x2_mul())
          assert_eq(
            lowered_ops[23],
            @lib.Instruction::i64x2_extmul_high_i32x4u(),
          )
        }
        _ => fail("expected i64x2 no-immediate lowered body")
      }

      match funcs[3] {
        @lib.Func(_, @lib.Expr(body)) => {
          let lowered_ops : Array[@lib.Instruction] = []
          for instr in body {
            match instr {
              @lib.LocalGet(_) | @lib.Drop => ()
              _ => lowered_ops.push(instr)
            }
          }
          assert_eq(lowered_ops[0], @lib.Instruction::f32x4_eq())
          assert_eq(lowered_ops[8], @lib.Instruction::f32x4_sqrt())
          assert_eq(lowered_ops[15], @lib.Instruction::f32x4_pmin())
          assert_eq(lowered_ops[20], @lib.Instruction::f32x4_nearest())
          assert_eq(
            lowered_ops[23],
            @lib.Instruction::f32x4_demote_f64x2_zero(),
          )
        }
        _ => fail("expected f32x4 no-immediate lowered body")
      }

      match funcs[4] {
        @lib.Func(_, @lib.Expr(body)) => {
          let lowered_ops : Array[@lib.Instruction] = []
          for instr in body {
            match instr {
              @lib.LocalGet(_) | @lib.Drop => ()
              _ => lowered_ops.push(instr)
            }
          }
          assert_eq(lowered_ops[0], @lib.Instruction::f64x2_eq())
          assert_eq(lowered_ops[8], @lib.Instruction::f64x2_sqrt())
          assert_eq(lowered_ops[15], @lib.Instruction::f64x2_pmin())
          assert_eq(lowered_ops[20], @lib.Instruction::f64x2_nearest())
          assert_eq(
            lowered_ops[23],
            @lib.Instruction::f64x2_promote_low_f32x4(),
          )
        }
        _ => fail("expected f64x2 no-immediate lowered body")
      }
    }
    _ =>
      fail(
        "expected lowered module code section for non-i8x16 SIMD no-immediate ops",
      )
  }
}

///|
test "wast_to_binary_module lowers relaxed SIMD no-immediate ops" {
  let src =
    #|(module
    #|  (func (param v128 v128 v128)
    #|    local.get 0 local.get 1 i8x16.relaxed_swizzle drop
    #|    local.get 0 local.get 1 local.get 2 i8x16.relaxed_laneselect drop
    #|    local.get 0 local.get 1 local.get 2 i16x8.relaxed_laneselect drop
    #|    local.get 0 local.get 1 local.get 2 i32x4.relaxed_laneselect drop
    #|    local.get 0 local.get 1 local.get 2 i64x2.relaxed_laneselect drop
    #|    local.get 0 i32x4.relaxed_trunc_f32x4_s drop
    #|    local.get 0 i32x4.relaxed_trunc_f32x4_u drop
    #|    local.get 0 i32x4.relaxed_trunc_f64x2_s_zero drop
    #|    local.get 0 i32x4.relaxed_trunc_f64x2_u_zero drop
    #|    local.get 0 local.get 1 local.get 2 f32x4.relaxed_madd drop
    #|    local.get 0 local.get 1 local.get 2 f32x4.relaxed_nmadd drop
    #|    local.get 0 local.get 1 local.get 2 f64x2.relaxed_madd drop
    #|    local.get 0 local.get 1 local.get 2 f64x2.relaxed_nmadd drop
    #|    local.get 0 local.get 1 f32x4.relaxed_min drop
    #|    local.get 0 local.get 1 f32x4.relaxed_max drop
    #|    local.get 0 local.get 1 f64x2.relaxed_min drop
    #|    local.get 0 local.get 1 f64x2.relaxed_max drop
    #|    local.get 0 local.get 1 i16x8.relaxed_q15mulr_s drop
    #|    local.get 0 local.get 1 i16x8.relaxed_dot_i8x16_i7x16_s drop
    #|    local.get 0 local.get 1 local.get 2 i32x4.relaxed_dot_i8x16_i7x16_add_s drop))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected relaxed SIMD no-immediate lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => {
      let lowered_ops : Array[@lib.Instruction] = []
      for instr in body {
        match instr {
          @lib.LocalGet(_) | @lib.Drop => ()
          _ => lowered_ops.push(instr)
        }
      }
      assert_eq(lowered_ops.length(), 20)
      assert_eq(lowered_ops[0], @lib.Instruction::i8x16_relaxed_swizzle())
      assert_eq(lowered_ops[2], @lib.Instruction::i16x8_relaxed_laneselect())
      assert_eq(lowered_ops[5], @lib.Instruction::i32x4_relaxed_trunc_f32x4s())
      assert_eq(
        lowered_ops[7],
        @lib.Instruction::i32x4_relaxed_trunc_zero_f64x2s(),
      )
      assert_eq(lowered_ops[9], @lib.Instruction::f32x4_relaxed_madd())
      assert_eq(lowered_ops[12], @lib.Instruction::f64x2_relaxed_nmadd())
      assert_eq(lowered_ops[17], @lib.Instruction::i16x8_relaxed_q15mulr_s())
      assert_eq(
        lowered_ops[18],
        @lib.Instruction::i16x8_relaxed_dot_i8x16i7x16s(),
      )
      assert_eq(
        lowered_ops[19],
        @lib.Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s(),
      )
    }
    _ =>
      fail(
        "expected lowered module code section for relaxed SIMD no-immediate ops",
      )
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
test "wast_to_binary_module rejects func import shorthand mixed with inline exports" {
  let src =
    #|(module
    #|  (func $f (export "f") (import "env" "f")))
  assert_true(
    wt_lower_error_contains(
      src, "inline exports are not supported on inline func import shorthand",
    ),
  )
}

///|
test "wast_to_binary_module supports imported funcs exported via explicit export field" {
  let src =
    #|(module
    #|  (func $f (import "env" "f"))
    #|  (export "f" (func $f)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected explicit import+export lowering success: \{e}")
  }
  match lowered.import_sec {
    Some(@lib.ImportSec([@lib.Import(_, _, @lib.FuncExternType(_))])) => ()
    _ => fail("expected lowered import section containing one imported func")
  }
  match lowered.export_sec {
    Some(
      @lib.ExportSec(
        [@lib.Export(name, @lib.FuncExternIdx(@lib.FuncIdx(func_idx)))]
      )
    ) => {
      assert_eq(name.0, "f")
      assert_eq(func_idx, 0U)
    }
    _ =>
      fail("expected lowered export section for explicit import+export fixture")
  }
}

///|
test "wast_to_binary_module rejects tag import shorthand mixed with inline exports" {
  let src =
    #|(module
    #|  (type $t (func))
    #|  (tag $e (export "e") (import "env" "e") (type $t)))
  assert_true(
    wt_lower_error_contains(
      src, "inline exports are not supported on inline tag import shorthand",
    ),
  )
}

///|
test "wast_to_binary_module supports imported tags exported via explicit export field" {
  let src =
    #|(module
    #|  (type $t (func))
    #|  (tag $e (import "env" "e") (type $t))
    #|  (export "e" (tag $e)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected explicit tag import+export lowering success: \{e}")
  }
  match lowered.import_sec {
    Some(
      @lib.ImportSec(
        [@lib.Import(_, _, @lib.TagExternType(@lib.TagType(@lib.TypeIdx(idx))))]
      )
    ) => assert_eq(idx, 0U)
    _ => fail("expected lowered import section containing one imported tag")
  }
  match lowered.export_sec {
    Some(
      @lib.ExportSec(
        [@lib.Export(name, @lib.TagExternIdx(@lib.TagIdx(tag_idx)))]
      )
    ) => {
      assert_eq(name.0, "e")
      assert_eq(tag_idx, 0U)
    }
    _ =>
      fail(
        "expected lowered export section for explicit tag import+export fixture",
      )
  }
}

///|
test "wast_to_binary_module lowers table elem-abbreviation with func keyword and non-zero offset" {
  let src =
    #|(module
    #|  (func $f)
    #|  (table 4 funcref (elem (i32.const 2) func $f)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected func-keyword table abbreviation lowering success: \{e}")
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
    ),
    @lib.ElemKind::funcs([@lib.FuncIdx::new(0)]),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ =>
      fail(
        "expected lowered elem section for func-keyword table abbreviation fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected func-keyword table abbreviation fixture to validate: \{e}")
  }
}

///|
test "wast_to_binary_module lowers table elem-abbreviation typed ref.func items" {
  let src =
    #|(module
    #|  (func $f)
    #|  (table 2 funcref (elem funcref (ref.func $f) (item (ref.func $f)))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected typed table elem-abbreviation lowering success: \{e}")
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      [
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
      ],
    ),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ =>
      fail(
        "expected lowered elem section for typed table elem-abbreviation fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected typed table elem-abbreviation fixture to validate: \{e}")
  }
}

///|
test "wast_to_binary_module lowers explicit typed ref.func-only elem segments as typed exprs" {
  let src =
    #|(module
    #|  (table 1 funcref)
    #|  (func $f)
    #|  (elem (i32.const 0) funcref (item (ref.func $f)) (item (ref.func $f))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected explicit typed ref.func-only elem-segment lowering success: \{e}",
      )
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      [
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
      ],
    ),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ =>
      fail(
        "expected lowered typed expr elem section for explicit typed ref.func-only fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected explicit typed ref.func-only elem fixture to validate: \{e}",
      )
  }
}

///|
test "wast_to_binary_module lowers table elem-abbreviation explicit item ref.func-only as typed exprs" {
  let src =
    #|(module
    #|  (func $f)
    #|  (table 2 funcref (elem (item (ref.func $f)) (item (ref.func $f)))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected explicit-item ref.func-only table abbreviation lowering success: \{e}",
      )
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      [
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
      ],
    ),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ =>
      fail(
        "expected lowered typed expr elem section for explicit-item table abbreviation fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected explicit-item ref.func-only table abbreviation fixture to validate: \{e}",
      )
  }
}

///|
test "wast_to_binary_module lowers explicit elem segment explicit item ref.func-only as typed exprs" {
  let src =
    #|(module
    #|  (table 1 funcref)
    #|  (func $f)
    #|  (elem (i32.const 0) (item (ref.func $f)) (item (ref.func $f))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected explicit-item ref.func-only elem segment lowering success: \{e}",
      )
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      [
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
      ],
    ),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ =>
      fail(
        "expected lowered typed expr elem section for explicit-item elem segment fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected explicit-item ref.func-only elem segment fixture to validate: \{e}",
      )
  }
}

///|
test "wast_to_binary_module lowers table elem-abbreviation typed ref.null items" {
  let src =
    #|(module
    #|  (func $f)
    #|  (table 2 funcref (elem funcref (item (ref.null func)) (item (ref.func $f)))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected typed ref.null table abbreviation lowering success: \{e}")
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      [
        @lib.Expr::new([
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
          ),
        ]),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
      ],
    ),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ =>
      fail(
        "expected lowered typed elem section for table abbreviation ref.null fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected typed ref.null table abbreviation fixture to validate: \{e}",
      )
  }
}

///|
test "wast_to_binary_module lowers explicit elem segments with typed item expressions" {
  let src =
    #|(module
    #|  (table 1 funcref)
    #|  (func $f)
    #|  (elem (i32.const 0) funcref (item (ref.null func)) (item (ref.func $f))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected explicit typed elem-segment lowering success: \{e}")
  }
  let expected = @lib.Elem::new(
    @lib.ElemMode::active(
      @lib.TableIdx::new(0),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      [
        @lib.Expr::new([
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
          ),
        ]),
        @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))]),
      ],
    ),
  )
  match lowered.elem_sec {
    Some(@lib.ElemSec([elem])) => assert_eq(elem, expected)
    _ => fail("expected lowered typed explicit elem section fixture")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected explicit typed elem-segment fixture to validate: \{e}")
  }
}

///|
test "wast_to_binary_module lowers typed-heap value types to concrete TypeIdx refs" {
  let src =
    #|(module
    #|  (type $t (func))
    #|  (func (param (ref $t)) (result (ref null $t))
    #|    (ref.null $t)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected typed-heap value-type lowering success: \{e}")
  }
  match lowered.type_sec {
    Some(@lib.TypeSec(types)) => {
      assert_eq(types.length(), 2)
      assert_eq(
        types[1],
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::ref_type(
                  @lib.RefType::new(
                    false,
                    @lib.HeapType::new(@lib.TypeIdx::new(0)),
                  ),
                ),
              ],
              [
                @lib.ValType::ref_type(
                  @lib.RefType::new(
                    true,
                    @lib.HeapType::new(@lib.TypeIdx::new(0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
    }
    _ =>
      fail(
        "expected concrete TypeIdx-backed ref param/result types in lowered type section",
      )
  }
  match lowered.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([instr]))])) =>
      assert_eq(
        instr,
        @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0))),
      )
    _ =>
      fail(
        "expected typed ref.null instruction to lower with concrete type index heap type",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) => fail("expected typed-heap value-type fixture to validate: \{e}")
  }
}

///|
test "wast_to_binary_module lowers abstract heap ref kinds without collapsing to func" {
  let src =
    #|(module
    #|  (func
    #|    (param (ref any) (ref eq) (ref i31) (ref none) (ref nofunc) (ref noextern) (ref noexn))
    #|    (result (ref null any) (ref null eq) (ref null i31) (ref null none) (ref null nofunc) (ref null noextern) (ref null noexn))
    #|    (ref.null any)
    #|    (ref.null eq)
    #|    (ref.null i31)
    #|    (ref.null none)
    #|    (ref.null nofunc)
    #|    (ref.null noextern)
    #|    (ref.null noexn)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected abstract heap-kind value-type lowering success: \{e}")
  }
  match lowered.type_sec {
    Some(
      @lib.TypeSec(
        [
          @lib.RecType::SingleRecType(
            @lib.SubType::CompTypeSubType(
              @lib.CompType::FuncCompType(params, results)
            )
          ),
        ]
      )
    ) => {
      assert_eq(params, [
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::any())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::none())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
          ),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
          ),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            @lib.HeapType::abs(@lib.AbsHeapType::no_exn()),
          ),
        ),
      ])
      assert_eq(results, [
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::none())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
          ),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
          ),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::no_exn()),
          ),
        ),
      ])
    }
    _ =>
      fail(
        "expected function signature in type section to preserve abstract heap-kind refs",
      )
  }
  match lowered.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      assert_eq(instrs, [
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::eq())),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::i31())),
        @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
        ),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
        ),
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::no_exn()),
        ),
      ])
    _ =>
      fail(
        "expected ref.null instructions to preserve abstract heap kinds in lowered code",
      )
  }
}

///|
test "wast_to_binary_module lowers abstract heap refs across table global tag and import surfaces" {
  let src =
    #|(module
    #|  (type $tag_t (func (param (ref null noextern))))
    #|  (import "env" "itbl" (table 1 (ref null nofunc)))
    #|  (import "env" "ig" (global (mut (ref null any))))
    #|  (import "env" "itag" (tag (type $tag_t)))
    #|  (table 2 (ref null noextern))
    #|  (global (mut (ref null none)) (ref.null none))
    #|  (tag (type $tag_t)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected abstract heap-kind module-surface lowering success: \{e}")
  }

  match lowered.type_sec {
    Some(@lib.TypeSec(types)) => {
      assert_eq(types.length(), 1)
      assert_eq(
        types[0],
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::ref_type(
                  @lib.RefType::new(
                    true,
                    @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
                  ),
                ),
              ],
              [],
            ),
          ),
        ),
      )
    }
    _ =>
      fail("expected abstract heap-kind tag signature in lowered type section")
  }

  match lowered.import_sec {
    Some(
      @lib.ImportSec(
        [
          @lib.Import(_, _, @lib.TableExternType(import_table_ty)),
          @lib.Import(_, _, @lib.GlobalExternType(import_global_ty)),
          @lib.Import(_, _, @lib.TagExternType(import_tag_ty)),
        ]
      )
    ) => {
      assert_eq(
        import_table_ty,
        @lib.TableType::new(
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
          ),
          @lib.Limits::i32(1, None),
        ),
      )
      assert_eq(
        import_global_ty,
        @lib.GlobalType::new(
          @lib.ValType::ref_type(
            @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
          ),
          true,
        ),
      )
      assert_eq(import_tag_ty, @lib.TagType::new(@lib.TypeIdx::new(0)))
    }
    _ =>
      fail(
        "expected lowered imports to preserve abstract heap-kind table/global/tag types",
      )
  }

  match lowered.table_sec {
    Some(@lib.TableSec([table])) =>
      assert_eq(
        table,
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
            ),
            @lib.Limits::i32(2, None),
          ),
          None,
        ),
      )
    _ => fail("expected lowered table section for abstract heap-kind fixture")
  }

  match lowered.global_sec {
    Some(@lib.GlobalSec([global])) =>
      assert_eq(
        global,
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                true,
                @lib.HeapType::abs(@lib.AbsHeapType::none()),
              ),
            ),
            true,
          ),
          @lib.Expr::new([
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::none()),
            ),
          ]),
        ),
      )
    _ => fail("expected lowered global section for abstract heap-kind fixture")
  }

  match lowered.tag_sec {
    Some(@lib.TagSec([tag])) =>
      assert_eq(tag, @lib.TagType::new(@lib.TypeIdx::new(0)))
    _ => fail("expected lowered tag section for abstract heap-kind fixture")
  }
}

///|
test "wast_to_binary_module keeps implicit table-abbrev elem order ahead of explicit elem segments" {
  let src =
    #|(module
    #|  (func $f)
    #|  (table 3 funcref (elem $f))
    #|  (elem (i32.const 1) $f)
    #|  (elem (i32.const 2) $f))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected table abbreviation ordering fixture lowering success: \{e}",
      )
  }
  let expected = [
    @lib.Elem::new(
      @lib.ElemMode::active(
        @lib.TableIdx::new(0),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
      @lib.ElemKind::funcs([@lib.FuncIdx::new(0)]),
    ),
    @lib.Elem::new(
      @lib.ElemMode::active(
        @lib.TableIdx::new(0),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
      ),
      @lib.ElemKind::funcs([@lib.FuncIdx::new(0)]),
    ),
    @lib.Elem::new(
      @lib.ElemMode::active(
        @lib.TableIdx::new(0),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
      ),
      @lib.ElemKind::funcs([@lib.FuncIdx::new(0)]),
    ),
  ]
  match lowered.elem_sec {
    Some(@lib.ElemSec(elems)) => assert_eq(elems, expected)
    _ => fail("expected lowered elem section in table-abbrev ordering fixture")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected table-abbrev ordering fixture to validate after lowering: \{e}",
      )
  }
}

///|
test "wast_to_binary_module reports targeted legacy delegate/rethrow label diagnostics" {
  let invalid_delegate_depth =
    #|(module
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (delegate 1))))
  assert_true(
    wt_lower_error_contains(
      invalid_delegate_depth, "invalid legacy delegate label",
    ),
  )

  let invalid_delegate_name =
    #|(module
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (delegate $missing))))
  assert_true(
    wt_lower_error_contains(
      invalid_delegate_name, "invalid legacy delegate label",
    ),
  )

  let invalid_rethrow_depth =
    #|(module
    #|  (tag $e)
    #|  (func
    #|    (try
    #|      (do (throw $e))
    #|      (catch $e
    #|        (rethrow 1)))))
  assert_true(
    wt_lower_error_contains(
      invalid_rethrow_depth, "invalid legacy rethrow label",
    ),
  )
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
test "wast_to_binary_module lowers throw throw_ref and try_table catch forms" {
  let src =
    #|(module
    #|  (type $void (func))
    #|  (tag $e0 (type $void))
    #|  (func
    #|    (block $h
    #|      (try_table (catch $e0 $h)
    #|        (throw $e0))
    #|      (try_table (catch_ref $e0 $h)
    #|        throw_ref)
    #|      (try_table (catch_all $h)
    #|        unreachable)
    #|      (try_table (catch_all_ref $h)
    #|        unreachable))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected exception-form lowering success: \{e}")
  }

  match lowered.tag_sec {
    Some(@lib.TagSec([@lib.TagType(@lib.TypeIdx(tag_type_idx))])) =>
      assert_eq(tag_type_idx, 0U)
    _ => fail("expected lowered tag section for exception fixture")
  }

  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  _,
                  @lib.Expr(
                    [try_catch, try_catch_ref, try_catch_all, try_catch_all_ref]
                  )
                ),
              ]
            )
          ),
        ]
      )
    ) => {
      match try_catch {
        @lib.TryTable(
          _,
          [@lib.Catch(@lib.TagIdx(catch_tag), @lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Throw(@lib.TagIdx(throw_tag))])
        ) => {
          assert_eq(catch_tag, 0U)
          assert_eq(catch_label, 0U)
          assert_eq(throw_tag, 0U)
        }
        _ => fail("expected try_table catch lowering shape")
      }

      match try_catch_ref {
        @lib.TryTable(
          _,
          [@lib.CatchRef(@lib.TagIdx(catch_tag), @lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.ThrowRef])
        ) => {
          assert_eq(catch_tag, 0U)
          assert_eq(catch_label, 0U)
        }
        _ => fail("expected try_table catch_ref lowering shape")
      }

      match try_catch_all {
        @lib.TryTable(
          _,
          [@lib.CatchAll(@lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Unreachable])
        ) => assert_eq(catch_label, 0U)
        _ => fail("expected try_table catch_all lowering shape")
      }

      match try_catch_all_ref {
        @lib.TryTable(
          _,
          [@lib.CatchAllRef(@lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Unreachable])
        ) => assert_eq(catch_label, 0U)
        _ => fail("expected try_table catch_all_ref lowering shape")
      }
    }
    _ =>
      fail(
        "expected lowered function body containing try_table exception forms",
      )
  }
}

///|
test "wast_to_binary_module resolves try_table catch labels across nested numeric and named depths" {
  let src =
    #|(module
    #|  (tag $e0) (tag $e1) (tag $e2) (tag $e3) (tag $e4)
    #|  (func
    #|    (block $outer
    #|      (block $inner
    #|        (try_table
    #|          (catch $e0 0)
    #|          (catch $e1 1)
    #|          (catch $e2 2)
    #|          (catch $e3 $inner)
    #|          (catch $e4 $outer)
    #|          (throw $e0)))))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected nested try_table catch-depth lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  _,
                  @lib.Expr(
                    [
                      @lib.Block(
                        _,
                        @lib.Expr([@lib.TryTable(_, catches, @lib.Expr(_))])
                      ),
                    ]
                  )
                ),
              ]
            )
          ),
        ]
      )
    ) => {
      assert_eq(catches.length(), 5)
      assert_eq(catches, [
        @lib.Catch::new(@lib.TagIdx::new(0), @lib.LabelIdx::new(0)),
        @lib.Catch::new(@lib.TagIdx::new(1), @lib.LabelIdx::new(1)),
        @lib.Catch::new(@lib.TagIdx::new(2), @lib.LabelIdx::new(2)),
        @lib.Catch::new(@lib.TagIdx::new(3), @lib.LabelIdx::new(0)),
        @lib.Catch::new(@lib.TagIdx::new(4), @lib.LabelIdx::new(1)),
      ])
    }
    _ =>
      fail(
        "expected nested try_table lowering with numeric/named catch-depth mapping",
      )
  }
}

///|
test "wast_to_binary_module rejects try_table catch depth beyond implicit function label" {
  let src =
    #|(module
    #|  (tag $e0)
    #|  (func (try_table (catch $e0 1) (throw $e0))))
  assert_true(wt_lower_error_contains(src, "invalid label index: 1"))
}

///|
test "wast_to_binary_module preserves try_table param-only blocktype as typeidx" {
  let src =
    #|(module
    #|  (func
    #|    (i32.const 0)
    #|    (try_table (param i32) (drop))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected try_table param-only lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec([
        @lib.Func(_, @lib.Expr([@lib.I32Const(_), @lib.TryTable(bt, _, _)])),
      ])
    ) =>
      match bt {
        @lib.TypeIdxBlockType(@lib.TypeIdx(_)) => ()
        _ => fail("expected param-only try_table blocktype to lower as type_idx")
      }
    _ => fail("expected lowered function containing param-only try_table")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected param-only try_table fixture to validate after lowering: \{e}")
  }
}

///|
test "wast_to_binary_module reuses matching function type for implicit typeuse" {
  let src =
    #|(module
    #|  (type $t (func))
    #|  (func $dummy)
    #|  (tag $e (param (ref $t)))
    #|  (func (throw $e (ref.func $dummy))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected implicit typeuse lowering success: \{e}")
  }
  match lowered.func_sec {
    Some(@lib.FuncSec([@lib.TypeIdx(t0), @lib.TypeIdx(t1)])) => {
      assert_eq(t0, 0U)
      assert_eq(t1, 0U)
    }
    _ => fail("expected two defined functions with stable type indices")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected implicit typeuse fixture with ref.func tag payload to validate: \{e}",
      )
  }
}

///|
test "wast_to_binary_module lowers inline tag exports into export section" {
  let src =
    #|(module
    #|  (type $void (func))
    #|  (tag $e0 (export "e0") (export "e0_alias") (type $void)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected inline tag export lowering success: \{e}")
  }
  match lowered.tag_sec {
    Some(@lib.TagSec([@lib.TagType(@lib.TypeIdx(type_idx))])) =>
      assert_eq(type_idx, 0U)
    _ => fail("expected lowered tag section for inline-export tag fixture")
  }
  match lowered.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(name0, @lib.TagExternIdx(@lib.TagIdx(tag_idx0))),
          @lib.Export(name1, @lib.TagExternIdx(@lib.TagIdx(tag_idx1))),
        ]
      )
    ) => {
      assert_eq(name0.0, "e0")
      assert_eq(name1.0, "e0_alias")
      assert_eq(tag_idx0, 0U)
      assert_eq(tag_idx1, 0U)
    }
    _ => fail("expected lowered export section containing inline tag exports")
  }
}

///|
test "wast_to_binary_module lowers inline exports across func table memory and global fields" {
  let src =
    #|(module
    #|  (import "env" "ifunc" (func))
    #|  (import "env" "itbl" (table 1 funcref))
    #|  (import "env" "imem" (memory 1))
    #|  (import "env" "ig" (global i32))
    #|  (func (export "f"))
    #|  (table (export "t") 1 funcref)
    #|  (memory (export "m") 1)
    #|  (global (export "g") i32 (i32.const 0)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected shared inline export lowering success across field kinds: \{e}",
      )
  }
  match lowered.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(fname, @lib.FuncExternIdx(@lib.FuncIdx(fidx))),
          @lib.Export(tname, @lib.TableExternIdx(@lib.TableIdx(tidx))),
          @lib.Export(mname, @lib.MemExternIdx(@lib.MemIdx(midx))),
          @lib.Export(gname, @lib.GlobalExternIdx(@lib.GlobalIdx(gidx))),
        ]
      )
    ) => {
      assert_eq(fname.0, "f")
      assert_eq(tname.0, "t")
      assert_eq(mname.0, "m")
      assert_eq(gname.0, "g")
      assert_eq(fidx, 1U)
      assert_eq(tidx, 1U)
      assert_eq(midx, 1U)
      assert_eq(gidx, 1U)
    }
    _ =>
      fail(
        "expected export section containing inline exports for func/table/memory/global",
      )
  }
}

///|
test "wast_to_binary_module validates catch_ref and catch_all_ref exnref label flows" {
  let src =
    #|(module
    #|  (tag $e0)
    #|  (func
    #|    (block $h (result exnref)
    #|      (try_table (catch_ref $e0 $h) (throw $e0))
    #|      (unreachable))
    #|    (drop))
    #|  (func
    #|    (block $h (result exnref)
    #|      (try_table (result exnref) (catch_all_ref $h) (throw $e0)))
    #|    (drop)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected catch_ref/catch_all_ref exnref flow fixture lowering success: \{e}",
      )
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(_, @lib.Expr([try_catch_ref, @lib.Unreachable])),
                @lib.Drop,
              ]
            )
          ),
          @lib.Func(
            _,
            @lib.Expr(
              [@lib.Block(_, @lib.Expr([try_catch_all_ref])), @lib.Drop]
            )
          ),
        ]
      )
    ) => {
      match try_catch_ref {
        @lib.TryTable(
          _,
          [@lib.CatchRef(@lib.TagIdx(catch_tag), @lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Throw(@lib.TagIdx(throw_tag))])
        ) => {
          assert_eq(catch_tag, 0U)
          assert_eq(catch_label, 0U)
          assert_eq(throw_tag, 0U)
        }
        _ => fail("expected catch_ref exnref-flow lowering shape")
      }
      match try_catch_all_ref {
        @lib.TryTable(
          _,
          [@lib.CatchAllRef(@lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Throw(@lib.TagIdx(throw_tag))])
        ) => {
          assert_eq(catch_label, 0U)
          assert_eq(throw_tag, 0U)
        }
        _ => fail("expected catch_all_ref exnref-flow lowering shape")
      }
    }
    _ =>
      fail(
        "expected lowered code for catch_ref/catch_all_ref exnref flow fixture",
      )
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected catch_ref/catch_all_ref exnref flow fixture to validate: \{e}",
      )
  }
}

///|
test "wast_to_binary_module keeps imported-tag wiring stable across catch and throw forms" {
  let src =
    #|(module
    #|  (type $void (func))
    #|  (import "env" "imp0" (tag $imp0 (type $void)))
    #|  (tag $imp1 (import "env" "imp1") (type $void))
    #|  (tag $local (type $void))
    #|  (func
    #|    (block $h
    #|      (try_table (catch $imp0 $h) (throw $imp1))
    #|      (try_table (catch $local $h) (throw $local)))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected imported-tag wiring fixture lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr([@lib.Block(_, @lib.Expr([first_try, second_try]))])
          ),
        ]
      )
    ) => {
      match first_try {
        @lib.TryTable(
          _,
          [@lib.Catch(@lib.TagIdx(catch_tag), @lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Throw(@lib.TagIdx(throw_tag))])
        ) => {
          assert_eq(catch_tag, 0U)
          assert_eq(catch_label, 0U)
          assert_eq(throw_tag, 1U)
        }
        _ => fail("expected first imported-tag try_table lowering shape")
      }
      match second_try {
        @lib.TryTable(
          _,
          [@lib.Catch(@lib.TagIdx(catch_tag), @lib.LabelIdx(catch_label))],
          @lib.Expr([@lib.Throw(@lib.TagIdx(throw_tag))])
        ) => {
          assert_eq(catch_tag, 2U)
          assert_eq(catch_label, 0U)
          assert_eq(throw_tag, 2U)
        }
        _ => fail("expected second imported/local-tag try_table lowering shape")
      }
    }
    _ => fail("expected lowered code for imported-tag wiring fixture")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) => fail("expected imported-tag wiring fixture to validate: \{e}")
  }
}

///|
test "wast_to_binary_module reports malformed NaN payloads in v128.const" {
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const f32x4 nan:0x 0 0 0))", "invalid f32x4 NaN payload literal: nan:0x",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const f32x4 nan:0xg 0 0 0))", "invalid f32x4 NaN payload literal: nan:0xg",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const f64x2 nan:0x 0))", "invalid f64x2 NaN payload literal: nan:0x",
    ),
  )
}

///|
test "wast_to_binary_module enforces i64x2 unsigned literal boundaries" {
  let lowered = match
    wast_to_binary_module(
      "(module (func (result v128) v128.const i64x2 18446744073709551615 0))",
    ) {
    Ok(m) => m
    Err(e) =>
      fail(
        "expected i64x2 v128.const max unsigned literal lowering success: \{e}",
      )
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.V128Const(
                  b0,
                  b1,
                  b2,
                  b3,
                  b4,
                  b5,
                  b6,
                  b7,
                  b8,
                  b9,
                  b10,
                  b11,
                  b12,
                  b13,
                  b14,
                  b15
                ),
              ]
            )
          ),
        ]
      )
    ) => {
      assert_eq(b0, (0xff).to_byte())
      assert_eq(b1, (0xff).to_byte())
      assert_eq(b2, (0xff).to_byte())
      assert_eq(b3, (0xff).to_byte())
      assert_eq(b4, (0xff).to_byte())
      assert_eq(b5, (0xff).to_byte())
      assert_eq(b6, (0xff).to_byte())
      assert_eq(b7, (0xff).to_byte())
      assert_eq(b8, (0x00).to_byte())
      assert_eq(b9, (0x00).to_byte())
      assert_eq(b10, (0x00).to_byte())
      assert_eq(b11, (0x00).to_byte())
      assert_eq(b12, (0x00).to_byte())
      assert_eq(b13, (0x00).to_byte())
      assert_eq(b14, (0x00).to_byte())
      assert_eq(b15, (0x00).to_byte())
    }
    _ => fail("expected lowered i64x2 max-literal v128.const function body")
  }

  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const i64x2 18446744073709551616 0))", "invalid i64x2 literal: 18446744073709551616",
    ),
  )
  assert_true(
    wt_lower_error_contains(
      "(module (func (result v128) v128.const i64x2 0x10000000000000000 0))", "invalid i64x2 literal: 0x10000000000000000",
    ),
  )
}

///|
test "native text pipeline accepts exception fixtures with .wat and .wast inputs" {
  let wat_source =
    #|(module
    #|  (type (func))
    #|  (tag (type 0))
    #|  (func (throw 0)))
  let wat_module = match
    wast_to_binary_module(wat_source, filename="exception-fixture.wat") {
    Ok(m) => m
    Err(e) => fail("expected native .wat pipeline success: \{e}")
  }
  match wat_module.tag_sec {
    Some(@lib.TagSec([_])) => ()
    _ => fail("expected .wat pipeline to produce a tag section")
  }

  let wast_source =
    #|(module
    #|  (type (func))
    #|  (tag (type 0))
    #|  (func (throw 0)))
  let report = run_wast_spec_file("exception-fixture.wast", wast_source)
  match report.status {
    Passed => assert_true(report.checked_commands >= 1)
    Skipped(reason) =>
      fail(
        "expected native .wast pipeline check to run without skips: \{reason}",
      )
    Failed(msg) => fail("expected native .wast pipeline success: \{msg}")
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
