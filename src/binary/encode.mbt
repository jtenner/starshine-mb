///|
pub trait Encode {
  encode(Self, @buffer.Buffer) -> Result[Unit, String]
}

///|
pub impl Encode for NumType with encode(val, buf) {
  match val {
    F64NumType => buf.write_byte(0x7C)
    F32NumType => buf.write_byte(0x7D)
    I64NumType => buf.write_byte(0x7E)
    I32NumType => buf.write_byte(0x7F)
  }
  Ok(())
}

///|
pub impl Encode for HeapType with encode(val, buf) {
  match val {
    AbsHeapTypeHeapType(ht) => Encode::encode(ht, buf)
    HeapType(TypeIdx(i)) => Encode::encode(@lib.S33(i), buf)
    HeapType(RecIdx(_)) => Err("Cannot encode recursive indexes")
    DefTypeHeapType(_) => Err("Cannot encode deftypes")
  }
}

///|
pub impl Encode for AbsHeapType with encode(val, buf) {
  match val {
    ExnAbsHeapType => buf.write_byte(0x69)
    ArrayAbsHeapType => buf.write_byte(0x6A)
    StructAbsHeapType => buf.write_byte(0x6B)
    I31AbsHeapType => buf.write_byte(0x6C)
    EqAbsHeapType => buf.write_byte(0x6D)
    AnyAbsHeapType => buf.write_byte(0x6E)
    ExternAbsHeapType => buf.write_byte(0x6F)
    FuncAbsHeapType => buf.write_byte(0x70)
    NoneAbsHeapType => buf.write_byte(0x71)
    NoExternAbsHeapType => buf.write_byte(0x72)
    NoFuncAbsHeapType => buf.write_byte(0x73)
    NoExnAbsHeapType => buf.write_byte(0x74)
  }
  Ok(())
}

///|
pub impl Encode for RefType with encode(val, buf) {
  match val {
    HeapTypeRefType(true, ht) => {
      buf.write_byte(0x63)
      Encode::encode(ht, buf)
    }
    HeapTypeRefType(false, ht) => {
      buf.write_byte(0x64)
      Encode::encode(ht, buf)
    }
    AbsHeapTypeRefType(abs) => Encode::encode(abs, buf)
  }
}

///|
pub impl Encode for ValType with encode(val, buf) {
  match val {
    VecTypeValType => {
      buf.write_byte(0x7B)
      Ok(())
    }
    NumTypeValType(num) => Encode::encode(num, buf)
    RefTypeValType(rt) => Encode::encode(rt, buf)
    BotValType => Err("Cannot encode bottom type.")
  }
}

///|
pub impl[T : Encode] Encode for @list.List[T] with encode(val, buf) {
  if Encode::encode(@lib.U32(val.length().reinterpret_as_uint()), buf) is Err(t) {
    return Err(t)
  }
  loop val {
    Empty => Ok(())
    More(val, tail~) => {
      if Encode::encode(val, buf) is Err(t) {
        break Err(t)
      }
      continue tail
    }
  }
}

///|
pub impl Encode for CompType with encode(val, buf) {
  match val {
    StructCompType(fts) => {
      buf.write_byte(0x5F)
      Encode::encode(fts, buf)
    }
    ArrayCompType(ft) => {
      buf.write_byte(0x5E)
      Encode::encode(ft, buf)
    }
    FuncCompType(t1, t2) => {
      buf.write_byte(0x60)
      if Encode::encode(t1, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(t2, buf)
    }
  }
}

///|
pub impl Encode for FieldType with encode(val, buf) {
  let FieldType(st, m) = val
  if Encode::encode(st, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(m, buf) is Err(t) {
    return Err(t)
  }
  Ok(())
}

///|
pub impl Encode for Mut with encode(val, buf) {
  match val {
    Const => buf.write_byte(0x00)
    Var => buf.write_byte(0x01)
  }
  Ok(())
}

///|
pub impl Encode for StorageType with encode(val, buf) {
  match val {
    ValTypeStorageType(vt) => Encode::encode(vt, buf)
    PackTypeStorageType(pt) => Encode::encode(pt, buf)
  }
}

///|
pub impl Encode for PackType with encode(val, buf) {
  match val {
    I16PackType => {
      buf.write_byte(0x77)
      Ok(())
    }
    I8PackType => {
      buf.write_byte(0x78)
      Ok(())
    }
  }
}

///|
pub impl Encode for RecType with encode(val, buf) {
  match val {
    SingleRecType(st) => Encode::encode(st, buf)
    GroupRecType(sts) => {
      buf.write_byte(0x4E)
      Encode::encode(sts, buf)
    }
  }
}

///|
pub impl Encode for SubType with encode(val, buf) {
  match val {
    SubType(f, indexes, ct) => {
      match f {
        true => buf.write_byte(0x4F)
        false => buf.write_byte(0x50)
      }
      if Encode::encode(indexes, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(ct, buf)
    }
    CompTypeSubType(ct) => Encode::encode(ct, buf)
  }
}

///|
pub impl Encode for ExternIdx with encode(val, buf) {
  match val {
    FuncExternIdx(idx) => {
      buf.write_byte(0x00)
      Encode::encode(idx, buf)
    }
    TableExternIdx(idx) => {
      buf.write_byte(0x01)
      Encode::encode(idx, buf)
    }
    MemExternIdx(idx) => {
      buf.write_byte(0x02)
      Encode::encode(idx, buf)
    }
    GlobalExternIdx(idx) => {
      buf.write_byte(0x03)
      Encode::encode(idx, buf)
    }
    TagExternIdx(idx) => {
      buf.write_byte(0x04)
      Encode::encode(idx, buf)
    }
  }
}

///|
pub fn size_unsigned(val : UInt64, nbits : Int) -> Result[Int, String] {
  if nbits <= 0 || nbits > 64 {
    return Err("invalid nbits for uleb")
  }
  if nbits < 64 {
    let max = (1UL << nbits) - 1UL
    if val > max {
      return Err("uleb value out of range")
    }
  }
  let mut x = val
  let mut count = 0
  while true {
    x = x >> 7
    count += 1
    if x == 0 {
      break
    }
  }
  Ok(count)
}

///|
pub fn size_signed(val : Int64, nbits : Int) -> Result[Int, String] {
  if nbits <= 0 || nbits > 64 {
    return Err("invalid nbits for sleb")
  }
  if nbits < 64 {
    let min = -1L << (nbits - 1)
    let max = (1L << (nbits - 1)) - 1
    if val < min || val > max {
      return Err("sleb value out of range")
    }
  }
  let rem = nbits % 7
  let used_mask = if rem == 0 { 0UL } else { (1UL << rem) - 1UL }
  let inv_used7 = UInt64::lnot(used_mask) & 0x7fUL
  let mut x = val
  let mut count = 0
  while true {
    let payload_u = (x & 0x7f).reinterpret_as_uint64()
    let sign_bit = (payload_u & 0x40UL) != 0UL
    x = x >> 7
    let done_std = (x == 0 && !sign_bit) || (x == -1 && sign_bit)
    let done_bits_ok = if nbits == 64 || rem == 0 {
      true
    } else if val >= 0 {
      (payload_u & inv_used7) == 0UL
    } else {
      (payload_u & inv_used7) == inv_used7
    }
    let done = done_std && done_bits_ok
    count += 1
    if done {
      break
    }
  }
  Ok(count)
}

///|
fn encode_unsigned(
  val : UInt64,
  buf : @buffer.Buffer,
  nbits : Int,
) -> Result[Unit, String] {
  if nbits <= 0 || nbits > 64 {
    return Err("invalid nbits for uleb")
  }
  if nbits < 64 {
    let max = (1UL << nbits) - 1UL
    if val > max {
      return Err("uleb value out of range")
    }
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut x = val
  let mut count = 0
  while true {
    if count >= max_bytes {
      return Err("uleb encode exceeds max bytes")
    }
    let payload = x & 0x7fUL
    x = x >> 7
    let out = if x == 0UL { payload } else { payload | 0x80UL }
    buf.write_byte(out.to_byte())
    count += 1
    if x == 0UL {
      break
    }
  }
  Ok(())
}

///|
fn encode_signed(
  val : Int64,
  buf : @buffer.Buffer,
  nbits : Int,
) -> Result[Unit, String] {
  if nbits <= 0 || nbits > 64 {
    return Err("invalid nbits for sleb")
  }
  if nbits < 64 {
    let min = -1L << (nbits - 1)
    let max = (1L << (nbits - 1)) - 1
    if val < min || val > max {
      return Err("sleb value out of range")
    }
  }
  let max_bytes = max_leb_bytes(nbits)
  let rem = nbits % 7
  let used_mask = if rem == 0 { 0UL } else { (1UL << rem) - 1UL }
  let inv_used7 = UInt64::lnot(used_mask) & 0x7fUL
  let mut x = val
  let mut count = 0
  while true {
    if count >= max_bytes {
      return Err("sleb encode exceeds max bytes")
    }
    let payload_u = (x & 0x7f).reinterpret_as_uint64()
    let sign_bit = (payload_u & 0x40UL) != 0UL
    x = x >> 7
    let done_std = (x == 0 && !sign_bit) || (x == -1 && sign_bit)
    let done_bits_ok = if nbits == 64 || rem == 0 {
      true
    } else if val >= 0 {
      (payload_u & inv_used7) == 0UL
    } else {
      (payload_u & inv_used7) == inv_used7
    }
    let done = done_std && done_bits_ok
    let out = if done { payload_u } else { payload_u | 0x80UL }
    buf.write_byte(out.to_byte())
    count += 1
    if done {
      break
    }
  }
  Ok(())
}

///|
fn ceil_div(a : Int, b : Int) -> Int {
  (a + b - 1) / b
}

///|
fn max_leb_bytes(nbits : Int) -> Int {
  ceil_div(nbits, 7)
}

///|
pub impl Encode for S33 with encode(val, buf) {
  let S33(val) = val
  encode_signed(val.to_int64(), buf, 33)
}

///|
pub impl Encode for I32 with encode(val, buf) {
  let I32(val) = val
  encode_signed(val.to_int64(), buf, 32)
}

///|
pub impl Encode for U32 with encode(val, buf) {
  let @lib.U32(val) = val
  encode_unsigned(val.to_uint64(), buf, 32)
}

///|
pub impl Encode for U64 with encode(val, buf) {
  let @lib.U64(val) = val
  encode_unsigned(val, buf, 64)
}

///|
pub impl Encode for I64 with encode(val, buf) {
  let I64(val) = val
  encode_signed(val, buf, 64)
}

///|
pub impl Encode for F32 with encode(val, buf) {
  let F32(val) = val
  buf.write_float_le(val)
  Ok(())
}

///|
pub impl Encode for F64 with encode(val, buf) {
  let F64(val) = val
  buf.write_double_le(val)
  Ok(())
}

///|
pub impl Encode for Bool with encode(val, buf) {
  if val {
    buf.write_byte(0x01)
  } else {
    buf.write_byte(0x00)
  }
  Ok(())
}

///|
pub impl[T : Encode] Encode for T? with encode(val, buf) {
  match val {
    None => Ok(())
    Some(val) => Encode::encode(val, buf)
  }
}

///|
pub impl Encode for TypeIdx with encode(val, buf) {
  match val {
    TypeIdx(id) => encode_unsigned(id.to_uint64(), buf, 32)
    _ => Err("Cannot encode non standard type index ")
  }
}

///|
pub impl Encode for FuncIdx with encode(val, buf) {
  let FuncIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for TableIdx with encode(val, buf) {
  let TableIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for MemIdx with encode(val, buf) {
  let MemIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for GlobalIdx with encode(val, buf) {
  let GlobalIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for TagIdx with encode(val, buf) {
  let TagIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for ElemIdx with encode(val, buf) {
  let ElemIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for DataIdx with encode(val, buf) {
  let DataIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for LocalIdx with encode(val, buf) {
  let LocalIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for LabelIdx with encode(val, buf) {
  let LabelIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Encode for LaneIdx with encode(val, buf) {
  buf.write_byte(val.0)
  Ok(())
}

///|
pub impl Encode for Name with encode(val, buf) {
  let Name(name) = val
  let bytes = @utf8.encode(name)
  let len = bytes.length()
  match Encode::encode(@lib.U32(len.reinterpret_as_uint()), buf) {
    Err(err) => Err(err)
    Ok(_) => {
      buf.write_bytes(bytes)
      Ok(())
    }
  }
}

///|
pub impl Encode for CustomSec with encode(val, buf) {
  let CustomSec(name, bytes) = val
  buf.write_byte(0)
  let payload_buff = @buffer.new()
  if Encode::encode(name, payload_buff) is Err(t) {
    return Err(t)
  }
  payload_buff.write_bytes(bytes)
  let payload_bytes = payload_buff.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for TypeSec with encode(val, buf) {
  buf.write_byte(1)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for ImportSec with encode(val, buf) {
  buf.write_byte(2)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for Import with encode(val, buf) {
  let Import(ns, name, et) = val
  match Encode::encode(ns, buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match Encode::encode(name, buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Encode::encode(et, buf)
}

///|
pub impl Encode for ExternType with encode(val, buf) {
  match val {
    FuncExternType(idx) => {
      buf.write_byte(0x00)
      Encode::encode(idx, buf)
    }
    TableExternType(tt) => {
      buf.write_byte(0x01)
      Encode::encode(tt, buf)
    }
    MemExternType(mt) => {
      buf.write_byte(0x02)
      Encode::encode(mt, buf)
    }
    GlobalExternType(gt) => {
      buf.write_byte(0x03)
      Encode::encode(gt, buf)
    }
    TagExternType(tt) => {
      buf.write_byte(0x04)
      Encode::encode(tt, buf)
    }
  }
}

///|
pub impl Encode for TableType with encode(val, buf) {
  let TableType(rt, l) = val
  match Encode::encode(rt, buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Encode::encode(l, buf)
}

///|
pub impl Encode for Limits with encode(val, buf) {
  match val {
    I32Limits(min, None) => {
      buf.write_byte(0x00)
      Encode::encode(@lib.U64(min.to_uint64()), buf)
    }
    I32Limits(min, Some(max)) => {
      buf.write_byte(0x01)
      match Encode::encode(@lib.U64(min.to_uint64()), buf) {
        Err(err) => return Err(err)
        _ => ()
      }
      Encode::encode(@lib.U64(max.to_uint64()), buf)
    }
    I64Limits(min, None) => {
      buf.write_byte(0x04)
      Encode::encode(@lib.U64(min), buf)
    }
    I64Limits(min, Some(max)) => {
      buf.write_byte(0x05)
      match Encode::encode(@lib.U64(min), buf) {
        Err(err) => return Err(err)
        _ => ()
      }
      Encode::encode(@lib.U64(max), buf)
    }
  }
}

///|
pub impl Encode for MemType with encode(val, buf) {
  Encode::encode(val.0, buf)
}

///|
pub impl Encode for GlobalType with encode(val, buf) {
  let GlobalType(vt, m) = val
  match Encode::encode(vt, buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Encode::encode(m, buf)
}

///|
pub impl Encode for TagType with encode(val, buf) {
  buf.write_byte(0x00)
  Encode::encode(val.0, buf)
}

///|
pub impl Encode for FuncSec with encode(val, buf) {
  buf.write_byte(3)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for TableSec with encode(val, buf) {
  buf.write_byte(4)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for Table with encode(val, buf) {
  match val {
    Table(tt, None) => Encode::encode(tt, buf)
    Table(tt, Some(e)) => {
      buf.write_bytes(b"\x40\x00")
      match Encode::encode(tt, buf) {
        Err(err) => return Err(err)
        Ok(_) => Encode::encode(e, buf)
      }
    }
  }
}

///|
pub impl Encode for MemSec with encode(val, buf) {
  buf.write_byte(5)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for GlobalSec with encode(val, buf) {
  buf.write_byte(6)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for Global with encode(val, buf) {
  let Global(gt, e) = val
  match Encode::encode(gt, buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Encode::encode(e, buf)
}

///|
pub impl Encode for ExportSec with encode(val, buf) {
  buf.write_byte(7)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for Export with encode(val, buf) {
  let Export(n, eidx) = val
  match Encode::encode(n, buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Encode::encode(eidx, buf)
}

///|
pub impl Encode for StartSec with encode(val, buf) {
  buf.write_byte(0x08)
  Encode::encode(val.0, buf)
}

///|
pub impl Encode for ElemSec with encode(val, buf) {
  buf.write_byte(9)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for Elem with encode(val, buf) {
  match val {
    Elem(Active(TableIdx(0), e), FuncsElemKind(y)) => {
      buf.write_byte(0x00)
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(y, buf)
    }
    Elem(Passive, FuncsElemKind(y)) => {
      buf.write_bytes(b"\x01\x00")
      Encode::encode(y, buf)
    }
    Elem(Active(ti, e), FuncsElemKind(y)) => {
      buf.write_byte(0x02)
      if Encode::encode(ti, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
      buf.write_byte(0x00)
      Encode::encode(y, buf)
    }
    Elem(Declarative, FuncsElemKind(y)) => {
      buf.write_bytes(b"\x03\x00")
      Encode::encode(y, buf)
    }
    Elem(Active(TableIdx(0), e), FuncExprsElemKind(es)) => {
      buf.write_byte(0x04)
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(es, buf)
    }
    // Encoder fixes - add funcref reftype
    Elem(Passive, FuncExprsElemKind(es)) => {
      buf.write_byte(0x05)
      let rt = RefType::new(true, HeapType::abs(AbsHeapType::func()))
      if Encode::encode(rt, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(es, buf)
    }
    Elem(Active(ti, e), FuncExprsElemKind(es)) => {
      buf.write_byte(0x06)
      if Encode::encode(ti, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
      // DON'T encode reftype - format 6 has implicit (ref null func)
      Encode::encode(es, buf)
    }
    Elem(Declarative, FuncExprsElemKind(es)) => {
      let rt = RefType::new(true, HeapType::abs(AbsHeapType::func()))
      buf.write_byte(0x07)
      if Encode::encode(rt, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(es, buf)
    }
    Elem(Passive, TypedExprsElemKind(rt, es)) => {
      buf.write_byte(0x05)
      if Encode::encode(rt, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(es, buf)
    }
    Elem(Declarative, TypedExprsElemKind(rt, es)) => {
      buf.write_byte(0x07)
      if Encode::encode(rt, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(es, buf)
    }
    Elem(Active(_), TypedExprsElemKind(_)) =>
      Err(
        "Invalid Active Sequence. Active Sequences must be func refs or indicies.",
      )
  }
}

///|
pub impl Encode for CodeSec with encode(val, buf) {
  let CodeSec(fns) = val
  buf.write_byte(0x0A)
  Encode::encode(fns, buf)
}

///|
pub impl Encode for Func with encode(val, buf) {
  let fn_body = @buffer.new()
  let (locals, expr) = match val {
    Func(locals, expr) => (locals, expr)
    TFunc(tlocals, texpr) => {
      let locals = tlocals_to_locals(tlocals)
      let expr = texpr.to_expr()
      (locals, expr)
    }
  }
  if Encode::encode(locals, fn_body) is Err(t) {
    return Err(t)
  }
  if Encode::encode(expr, fn_body) is Err(t) {
    return Err(t)
  }
  let fn_bytes = fn_body.to_bytes()
  if Encode::encode(@lib.U32(fn_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(fn_bytes) // Don't use Encode::encode here - just write raw bytes
  Ok(())
}

///|
pub impl Encode for DataSec with encode(val, buf) {
  buf.write_byte(11)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for Data with encode(val, buf) {
  match val {
    Data(Active(MemIdx(0), e), bytes) => {
      buf.write_byte(0x00)
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(bytes, buf)
    }
    Data(Passive, bytes) => {
      buf.write_byte(0x01)
      Encode::encode(bytes, buf)
    }
    Data(Active(idx, e), bytes) => {
      buf.write_byte(0x02)
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
      Encode::encode(bytes, buf)
    }
  }
}

///|
pub impl Encode for Locals with encode(val, buf) {
  let Locals(count, vt) = val
  match Encode::encode(@lib.U32(count), buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Encode::encode(vt, buf)
}

///|
pub impl Encode for DataCntSec with encode(val, buf) {
  let DataCntSec(count) = val
  buf.write_byte(12)
  if Encode::encode(count, buf) is Err(t) {
    return Err(t)
  }
  Ok(())
}

///|
pub impl Encode for TagSec with encode(val, buf) {
  buf.write_byte(13)
  let payload = @buffer.new()
  if Encode::encode(val.0, payload) is Err(t) {
    return Err(t)
  }
  let payload_bytes = payload.to_bytes()
  if Encode::encode(@lib.U32(payload_bytes.length().reinterpret_as_uint()), buf)
    is Err(t) {
    return Err(t)
  }
  buf.write_bytes(payload_bytes)
  Ok(())
}

///|
pub impl Encode for CastOp with encode(val, buf) {
  match val {
    CastOp(false, false) => buf.write_byte(0x00)
    CastOp(true, false) => buf.write_byte(0x01)
    CastOp(false, true) => buf.write_byte(0x02)
    CastOp(true, true) => buf.write_byte(0x03)
  }
  Ok(())
}

///|
pub impl Encode for Module with encode(val, buf) {
  buf.write_bytes(b"\x00\x61\x73\x6D\x01\x00\x00\x00")
  // custom sections
  for sec in val.custom_secs {
    if Encode::encode(sec, buf) is Err(t) {
      return Err(t)
    }
  }
  if Encode::encode(val.type_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.import_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.func_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.table_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.mem_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.tag_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.global_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.export_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.start_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.elem_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.data_cnt_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.code_sec, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.data_sec, buf) is Err(t) {
    return Err(t)
  }
  Ok(())
}

///|
pub impl Encode for Bytes with encode(val, buf) {
  match Encode::encode(@lib.U32(val.length().reinterpret_as_uint()), buf) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  buf.write_bytes(val)
  Ok(())
}

///|
pub impl Encode for BlockType with encode(val, buf) {
  match val {
    VoidBlockType => {
      buf.write_byte(0x40)
      Ok(())
    }
    ValTypeBlockType(vt) => Encode::encode(vt, buf)
    TypeIdxBlockType(TypeIdx(idx)) => Encode::encode(@lib.S33(idx), buf)
    _ => Err("Cannot encode recursive indexes")
  }
}

///|
pub impl Encode for Expr with encode(val, buf) {
  for i in val.0.iter() {
    if Encode::encode(i, buf) is Err(err) {
      return Err(err)
    }
  }
  buf.write_byte(0x0B)
  Ok(())
}

///|
pub impl Encode for Catch with encode(val, buf) {
  match val {
    Catch(t, l) => {
      buf.write_byte(0x00)
      if Encode::encode(t, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    CatchRef(t, l) => {
      buf.write_byte(0x01)
      if Encode::encode(t, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    CatchAll(l) => {
      buf.write_byte(0x02)
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    CatchAllRef(l) => {
      buf.write_byte(0x03)
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
  }
  Ok(())
}

///|
pub impl Encode for MemArg with encode(val, buf) {
  match val {
    MemArg(U32(n), Some(i), m) if n < 64 => {
      if Encode::encode(@lib.U32(n + 64), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    MemArg(U32(n), None, m) if n < 64 => {
      if Encode::encode(@lib.U32(n), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    _ => return Err("Invalid Memarg")
  }
  Ok(())
}

///|
fn simd_inst(id : UInt, buf : @buffer.Buffer) -> Result[Unit, String] {
  buf.write_byte(0xFD)
  if Encode::encode(@lib.U32(id), buf) is Err(t) {
    return Err(t)
  }
  Ok(())
}

///|
pub impl Encode for Instruction with encode(val, buf) {
  match val {
    Unreachable => buf.write_byte(0x00)
    Nop => buf.write_byte(0x01)
    Block(bt, i) => {
      buf.write_byte(0x02)
      if Encode::encode(bt, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    Loop(bt, i) => {
      buf.write_byte(0x03)
      if Encode::encode(bt, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    If(bt, if_block, else_block) => {
      buf.write_byte(0x04)
      if Encode::encode(bt, buf) is Err(t) {
        return Err(t)
      }
      for i in if_block.iter() {
        if Encode::encode(i, buf) is Err(t) {
          return Err(t)
        }
      }
      if else_block is Some(else_block) {
        buf.write_byte(0x05)
        for i in else_block.iter() {
          if Encode::encode(i, buf) is Err(t) {
            return Err(t)
          }
        }
      }
      buf.write_byte(0x0B)
    }
    Throw(t) => {
      buf.write_byte(0x08)
      if Encode::encode(t, buf) is Err(t) {
        return Err(t)
      }
    }
    ThrowRef => buf.write_byte(0x0A)
    Br(i) => {
      buf.write_byte(0x0C)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    BrIf(i) => {
      buf.write_byte(0x0D)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    BrTable(ls, i) => {
      buf.write_byte(0x0E)
      if Encode::encode(ls, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    Return => buf.write_byte(0x0F)
    Call(i) => {
      buf.write_byte(0x10)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    CallIndirect(ty, ta) => {
      buf.write_byte(0x11)
      if Encode::encode(ty, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ta, buf) is Err(t) {
        return Err(t)
      }
    }
    ReturnCall(f) => {
      buf.write_byte(0x12)
      if Encode::encode(f, buf) is Err(t) {
        return Err(t)
      }
    }
    ReturnCallIndirect(ty, ta) => {
      buf.write_byte(0x13)
      if Encode::encode(ty, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ta, buf) is Err(t) {
        return Err(t)
      }
    }
    CallRef(t) => {
      buf.write_byte(0x14)
      if Encode::encode(t, buf) is Err(t) {
        return Err(t)
      }
    }
    ReturnCallRef(t) => {
      buf.write_byte(0x15)
      if Encode::encode(t, buf) is Err(t) {
        return Err(t)
      }
    }
    Drop => buf.write_byte(0x1A)
    Select(None) => buf.write_byte(0x1b)
    Select(Some(vts)) => {
      buf.write_byte(0x1C)
      if Encode::encode(vts, buf) is Err(t) {
        return Err(t)
      }
    }
    TryTable(bt, c, e) => {
      buf.write_byte(0x1F)
      if Encode::encode(bt, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(c, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(e, buf) is Err(t) {
        return Err(t)
      }
    }
    LocalGet(l) => {
      buf.write_byte(0x20)
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    LocalSet(l) => {
      buf.write_byte(0x21)
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    LocalTee(l) => {
      buf.write_byte(0x22)
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    GlobalGet(g) => {
      buf.write_byte(0x23)
      if Encode::encode(g, buf) is Err(t) {
        return Err(t)
      }
    }
    GlobalSet(g) => {
      buf.write_byte(0x24)
      if Encode::encode(g, buf) is Err(t) {
        return Err(t)
      }
    }
    TableGet(i) => {
      buf.write_byte(0x25)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    TableSet(i) => {
      buf.write_byte(0x26)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Load(m) => {
      buf.write_byte(0x28)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load(m) => {
      buf.write_byte(0x29)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    F32Load(m) => {
      buf.write_byte(0x2A)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    F64Load(m) => {
      buf.write_byte(0x2B)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Load8S(m) => {
      buf.write_byte(0x2C)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Load8U(m) => {
      buf.write_byte(0x2D)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Load16S(m) => {
      buf.write_byte(0x2E)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Load16U(m) => {
      buf.write_byte(0x2F)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load8S(m) => {
      buf.write_byte(0x30)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load8U(m) => {
      buf.write_byte(0x31)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load16S(m) => {
      buf.write_byte(0x32)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load16U(m) => {
      buf.write_byte(0x33)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load32S(m) => {
      buf.write_byte(0x34)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Load32U(m) => {
      buf.write_byte(0x35)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Store(m) => {
      buf.write_byte(0x36)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Store(m) => {
      buf.write_byte(0x37)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    F32Store(m) => {
      buf.write_byte(0x38)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    F64Store(m) => {
      buf.write_byte(0x39)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Store8(m) => {
      buf.write_byte(0x3A)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Store16(m) => {
      buf.write_byte(0x3B)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Store8(m) => {
      buf.write_byte(0x3C)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Store16(m) => {
      buf.write_byte(0x3D)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Store32(m) => {
      buf.write_byte(0x3E)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    MemorySize(m) => {
      buf.write_byte(0x3F)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    MemoryGrow(m) => {
      buf.write_byte(0x40)
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Const(c) => {
      buf.write_byte(0x41)
      if Encode::encode(c, buf) is Err(t) {
        return Err(t)
      }
    }
    I64Const(c) => {
      buf.write_byte(0x42)
      if Encode::encode(c, buf) is Err(t) {
        return Err(t)
      }
    }
    F32Const(c) => {
      buf.write_byte(0x43)
      if Encode::encode(c, buf) is Err(t) {
        return Err(t)
      }
    }
    F64Const(c) => {
      buf.write_byte(0x44)
      if Encode::encode(c, buf) is Err(t) {
        return Err(t)
      }
    }
    I32Eqz => buf.write_byte(0x45)
    I32Eq => buf.write_byte(0x46)
    I32Ne => buf.write_byte(0x47)
    I32LtS => buf.write_byte(0x48)
    I32LtU => buf.write_byte(0x49)
    I32GtS => buf.write_byte(0x4A)
    I32GtU => buf.write_byte(0x4B)
    I32LeS => buf.write_byte(0x4C)
    I32LeU => buf.write_byte(0x4D)
    I32GeS => buf.write_byte(0x4E)
    I32GeU => buf.write_byte(0x4F)
    I64Eqz => buf.write_byte(0x50)
    I64Eq => buf.write_byte(0x51)
    I64Ne => buf.write_byte(0x52)
    I64LtS => buf.write_byte(0x53)
    I64LtU => buf.write_byte(0x54)
    I64GtS => buf.write_byte(0x55)
    I64GtU => buf.write_byte(0x56)
    I64LeS => buf.write_byte(0x57)
    I64LeU => buf.write_byte(0x58)
    I64GeS => buf.write_byte(0x59)
    I64GeU => buf.write_byte(0x5A)
    F32Eq => buf.write_byte(0x5B)
    F32Ne => buf.write_byte(0x5C)
    F32Lt => buf.write_byte(0x5D)
    F32Gt => buf.write_byte(0x5E)
    F32Le => buf.write_byte(0x5F)
    F32Ge => buf.write_byte(0x60)
    F64Eq => buf.write_byte(0x61)
    F64Ne => buf.write_byte(0x62)
    F64Lt => buf.write_byte(0x63)
    F64Gt => buf.write_byte(0x64)
    F64Le => buf.write_byte(0x65)
    F64Ge => buf.write_byte(0x66)
    I32Clz => buf.write_byte(0x67)
    I32Ctz => buf.write_byte(0x68)
    I32Popcnt => buf.write_byte(0x69)
    I32Add => buf.write_byte(0x6A)
    I32Sub => buf.write_byte(0x6B)
    I32Mul => buf.write_byte(0x6C)
    I32DivS => buf.write_byte(0x6D)
    I32DivU => buf.write_byte(0x6E)
    I32RemS => buf.write_byte(0x6F)
    I32RemU => buf.write_byte(0x70)
    I32And => buf.write_byte(0x71)
    I32Or => buf.write_byte(0x72)
    I32Xor => buf.write_byte(0x73)
    I32Shl => buf.write_byte(0x74)
    I32ShrS => buf.write_byte(0x75)
    I32ShrU => buf.write_byte(0x76)
    I32Rotl => buf.write_byte(0x77)
    I32Rotr => buf.write_byte(0x78)
    I64Clz => buf.write_byte(0x79)
    I64Ctz => buf.write_byte(0x7A)
    I64Popcnt => buf.write_byte(0x7B)
    I64Add => buf.write_byte(0x7C)
    I64Sub => buf.write_byte(0x7D)
    I64Mul => buf.write_byte(0x7E)
    I64DivS => buf.write_byte(0x7F)
    I64DivU => buf.write_byte(0x80)
    I64RemS => buf.write_byte(0x81)
    I64RemU => buf.write_byte(0x82)
    I64And => buf.write_byte(0x83)
    I64Or => buf.write_byte(0x84)
    I64Xor => buf.write_byte(0x85)
    I64Shl => buf.write_byte(0x86)
    I64ShrS => buf.write_byte(0x87)
    I64ShrU => buf.write_byte(0x88)
    I64Rotl => buf.write_byte(0x89)
    I64Rotr => buf.write_byte(0x8A)
    F32Abs => buf.write_byte(0x8B)
    F32Neg => buf.write_byte(0x8C)
    F32Ceil => buf.write_byte(0x8D)
    F32Floor => buf.write_byte(0x8E)
    F32Trunc => buf.write_byte(0x8F)
    F32Nearest => buf.write_byte(0x90)
    F32Sqrt => buf.write_byte(0x91)
    F32Add => buf.write_byte(0x92)
    F32Sub => buf.write_byte(0x93)
    F32Mul => buf.write_byte(0x94)
    F32Div => buf.write_byte(0x95)
    F32Min => buf.write_byte(0x96)
    F32Max => buf.write_byte(0x97)
    F32Copysign => buf.write_byte(0x98)
    F64Abs => buf.write_byte(0x99)
    F64Neg => buf.write_byte(0x9A)
    F64Ceil => buf.write_byte(0x9B)
    F64Floor => buf.write_byte(0x9C)
    F64Trunc => buf.write_byte(0x9D)
    F64Nearest => buf.write_byte(0x9E)
    F64Sqrt => buf.write_byte(0x9F)
    F64Add => buf.write_byte(0xA0)
    F64Sub => buf.write_byte(0xA1)
    F64Mul => buf.write_byte(0xA2)
    F64Div => buf.write_byte(0xA3)
    F64Min => buf.write_byte(0xA4)
    F64Max => buf.write_byte(0xA5)
    F64Copysign => buf.write_byte(0xA6)
    I32WrapI64 => buf.write_byte(0xA7)
    I32TruncF32S => buf.write_byte(0xA8)
    I32TruncF32U => buf.write_byte(0xA9)
    I32TruncF64S => buf.write_byte(0xAA)
    I32TruncF64U => buf.write_byte(0xAB)
    I64ExtendI32S => buf.write_byte(0xAC)
    I64ExtendI32U => buf.write_byte(0xAD)
    I64TruncF32S => buf.write_byte(0xAE)
    I64TruncF32U => buf.write_byte(0xAF)
    I64TruncF64S => buf.write_byte(0xB0)
    I64TruncF64U => buf.write_byte(0xB1)
    F32ConvertI32S => buf.write_byte(0xB2)
    F32ConvertI32U => buf.write_byte(0xB3)
    F32ConvertI64S => buf.write_byte(0xB4)
    F32ConvertI64U => buf.write_byte(0xB5)
    F32DemoteF64 => buf.write_byte(0xB6)
    F64ConvertI32S => buf.write_byte(0xB7)
    F64ConvertI32U => buf.write_byte(0xB8)
    F64ConvertI64S => buf.write_byte(0xB9)
    F64ConvertI64U => buf.write_byte(0xBA)
    F64PromoteF32 => buf.write_byte(0xBB)
    I32ReinterpretF32 => buf.write_byte(0xBC)
    I64ReinterpretF64 => buf.write_byte(0xBD)
    F32ReinterpretI32 => buf.write_byte(0xBE)
    F64ReinterpretI64 => buf.write_byte(0xBF)
    I32Extend8S => buf.write_byte(0xC0)
    I32Extend16S => buf.write_byte(0xC1)
    I64Extend8S => buf.write_byte(0xC2)
    I64Extend16S => buf.write_byte(0xC3)
    I64Extend32S => buf.write_byte(0xC4)
    RefNull(ht) => {
      buf.write_byte(0xD0)
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefIsNull => buf.write_byte(0xD1)
    RefFunc(i) => {
      buf.write_byte(0xD2)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    RefEq => buf.write_byte(0xD3)
    RefAsNonNull => buf.write_byte(0xD4)
    BrOnNull(i) => {
      buf.write_byte(0xD5)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    BrOnNonNull(i) => {
      buf.write_byte(0xD6)
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    StructNew(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(0), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    StructNewDefault(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(1), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    StructGet(i, idx) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(2), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
    }
    StructGetS(i, idx) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(3), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
    }
    StructGetU(i, idx) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(4), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
    }
    StructSet(i, idx) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(5), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayNew(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(6), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayNewDefault(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(7), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayNewFixed(i, n) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(8), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(n, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayNewData(i, idx) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(9), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayNewElem(i, idx) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(10), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(idx, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayGet(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(11), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayGetS(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(12), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayGetU(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(13), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArraySet(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(14), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayLen => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(15), buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayFill(i) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(16), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(i, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayCopy(x0, x1) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(17), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(x0, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(x1, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayInitData(x, y) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(18), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(x, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(y, buf) is Err(t) {
        return Err(t)
      }
    }
    ArrayInitElem(x, y) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(19), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(x, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(y, buf) is Err(t) {
        return Err(t)
      }
    }
    RefTest(false, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(20), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefTest(true, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(21), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefCast(false, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(22), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefCast(true, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(23), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefGetDesc => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(31), buf) is Err(t) {
        return Err(t)
      }
    }
    RefTestDesc(false, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(32), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefTestDesc(true, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(33), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefCastDescEq(false, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(34), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    RefCastDescEq(true, ht) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(35), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht, buf) is Err(t) {
        return Err(t)
      }
    }
    BrOnCast(l, castop, ht0, ht1) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(24), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(castop, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht0, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht1, buf) is Err(t) {
        return Err(t)
      }
    }
    BrOnCastFail(l, castop, ht0, ht1) => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(25), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(castop, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht0, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ht1, buf) is Err(t) {
        return Err(t)
      }
    }
    AnyConvertExtern => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(26), buf) is Err(t) {
        return Err(t)
      }
    }
    ExternConvertAny => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(27), buf) is Err(t) {
        return Err(t)
      }
    }
    RefI31 => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(28), buf) is Err(t) {
        return Err(t)
      }
    }
    I31GetS => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(29), buf) is Err(t) {
        return Err(t)
      }
    }
    I31GetU => {
      buf.write_byte(0xFB)
      if Encode::encode(@lib.U32(30), buf) is Err(t) {
        return Err(t)
      }
    }
    I32TruncSatF32S => buf.write_bytes(b"\xFC\x00")
    I32TruncSatF32U => buf.write_bytes(b"\xFC\x01")
    I32TruncSatF64S => buf.write_bytes(b"\xFC\x02")
    I32TruncSatF64U => buf.write_bytes(b"\xFC\x03")
    I64TruncSatF32S => buf.write_bytes(b"\xFC\x04")
    I64TruncSatF32U => buf.write_bytes(b"\xFC\x05")
    I64TruncSatF64S => buf.write_bytes(b"\xFC\x06")
    I64TruncSatF64U => buf.write_bytes(b"\xFC\x07")
    MemoryInit(di, mi) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(8), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(di, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(mi, buf) is Err(t) {
        return Err(t)
      }
    }
    DataDrop(di) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(9), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(di, buf) is Err(t) {
        return Err(t)
      }
    }
    MemoryCopy(mi0, mi1) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(10), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(mi0, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(mi1, buf) is Err(t) {
        return Err(t)
      }
    }
    MemoryFill(mi) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(11), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(mi, buf) is Err(t) {
        return Err(t)
      }
    }
    TableInit(ei, ti) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(12), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ei, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ti, buf) is Err(t) {
        return Err(t)
      }
    }
    ElemDrop(ei) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(13), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ei, buf) is Err(t) {
        return Err(t)
      }
    }
    TableCopy(ti0, ti1) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(14), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ti0, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ti1, buf) is Err(t) {
        return Err(t)
      }
    }
    TableGrow(ti) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(15), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ti, buf) is Err(t) {
        return Err(t)
      }
    }
    TableSize(ti) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(16), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ti, buf) is Err(t) {
        return Err(t)
      }
    }
    TableFill(ti) => {
      buf.write_byte(0xFC)
      if Encode::encode(@lib.U32(17), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(ti, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(0), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load8x8S(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(1), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load8x8U(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(2), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load16x4S(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(3), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load16x4U(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(4), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load32x2S(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(5), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load32x2U(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(6), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load8Splat(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(7), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load16Splat(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(8), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load32Splat(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(9), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load64Splat(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(10), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Store(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(11), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Const(
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
    ) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(12), buf) is Err(t) {
        return Err(t)
      }
      buf.write_byte(b0)
      buf.write_byte(b1)
      buf.write_byte(b2)
      buf.write_byte(b3)
      buf.write_byte(b4)
      buf.write_byte(b5)
      buf.write_byte(b6)
      buf.write_byte(b7)
      buf.write_byte(b8)
      buf.write_byte(b9)
      buf.write_byte(b10)
      buf.write_byte(b11)
      buf.write_byte(b12)
      buf.write_byte(b13)
      buf.write_byte(b14)
      buf.write_byte(b15)
    }
    I8x16Shuffle(
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
    ) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(13), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b0, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b1, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b2, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b3, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b4, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b5, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b6, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b7, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b8, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b9, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b10, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b11, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b12, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b13, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b14, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(b15, buf) is Err(t) {
        return Err(t)
      }
    }
    I8x16Swizzle => return simd_inst(14, buf)
    I8x16Splat => return simd_inst(15, buf)
    I16x8Splat => return simd_inst(16, buf)
    I32x4Splat => return simd_inst(17, buf)
    I64x2Splat => return simd_inst(18, buf)
    F32x4Splat => return simd_inst(19, buf)
    F64x2Splat => return simd_inst(20, buf)
    I8x16ExtractLaneS(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(21), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I8x16ExtractLaneU(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(22), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I8x16ReplaceLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(23), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I16x8ExtractLaneS(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(24), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I16x8ExtractLaneU(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(25), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I16x8ReplaceLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(26), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I32x4ExtractLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(27), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I32x4ReplaceLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(28), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I64x2ExtractLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(29), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I64x2ReplaceLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(30), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    F32x4ExtractLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(31), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    F32x4ReplaceLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(32), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    F64x2ExtractLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(33), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    F64x2ReplaceLane(l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(34), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    I8x16Eq => return simd_inst(35, buf)
    I8x16Ne => return simd_inst(36, buf)
    I8x16LtS => return simd_inst(37, buf)
    I8x16LtU => return simd_inst(38, buf)
    I8x16GtS => return simd_inst(39, buf)
    I8x16GtU => return simd_inst(40, buf)
    I8x16LeS => return simd_inst(41, buf)
    I8x16LeU => return simd_inst(42, buf)
    I8x16GeS => return simd_inst(43, buf)
    I8x16GeU => return simd_inst(44, buf)
    I16x8Eq => return simd_inst(45, buf)
    I16x8Ne => return simd_inst(46, buf)
    I16x8LtS => return simd_inst(47, buf)
    I16x8LtU => return simd_inst(48, buf)
    I16x8GtS => return simd_inst(49, buf)
    I16x8GtU => return simd_inst(50, buf)
    I16x8LeS => return simd_inst(51, buf)
    I16x8LeU => return simd_inst(52, buf)
    I16x8GeS => return simd_inst(53, buf)
    I16x8GeU => return simd_inst(54, buf)
    I32x4Eq => return simd_inst(55, buf)
    I32x4Ne => return simd_inst(56, buf)
    I32x4LtS => return simd_inst(57, buf)
    I32x4LtU => return simd_inst(58, buf)
    I32x4GtS => return simd_inst(59, buf)
    I32x4GtU => return simd_inst(60, buf)
    I32x4LeS => return simd_inst(61, buf)
    I32x4LeU => return simd_inst(62, buf)
    I32x4GeS => return simd_inst(63, buf)
    I32x4GeU => return simd_inst(64, buf)
    F32x4Eq => return simd_inst(65, buf)
    F32x4Ne => return simd_inst(66, buf)
    F32x4Lt => return simd_inst(67, buf)
    F32x4Gt => return simd_inst(68, buf)
    F32x4Le => return simd_inst(69, buf)
    F32x4Ge => return simd_inst(70, buf)
    F64x2Eq => return simd_inst(71, buf)
    F64x2Ne => return simd_inst(72, buf)
    F64x2Lt => return simd_inst(73, buf)
    F64x2Gt => return simd_inst(74, buf)
    F64x2Le => return simd_inst(75, buf)
    F64x2Ge => return simd_inst(76, buf)
    V128Not => return simd_inst(77, buf)
    V128And => return simd_inst(78, buf)
    V128Andnot => return simd_inst(79, buf)
    V128Or => return simd_inst(80, buf)
    V128Xor => return simd_inst(81, buf)
    V128Bitselect => return simd_inst(82, buf)
    V128AnyTrue => return simd_inst(83, buf)
    V128Load8Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(84), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load16Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(85), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load32Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(86), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load64Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(87), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Store8Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(88), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Store16Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(89), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Store32Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(90), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Store64Lane(m, l) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(91), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(l, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load32Zero(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(92), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    V128Load64Zero(m) => {
      buf.write_byte(0xFD)
      if Encode::encode(@lib.U32(93), buf) is Err(t) {
        return Err(t)
      }
      if Encode::encode(m, buf) is Err(t) {
        return Err(t)
      }
    }
    F32x4DemoteF64x2Zero => return simd_inst(94, buf)
    F64x2PromoteLowF32x4 => return simd_inst(95, buf)
    I8x16Abs => return simd_inst(96, buf)
    I8x16Neg => return simd_inst(97, buf)
    I8x16Popcnt => return simd_inst(98, buf)
    I8x16AllTrue => return simd_inst(99, buf)
    I8x16Bitmask => return simd_inst(100, buf)
    I8x16NarrowI16x8S => return simd_inst(101, buf)
    I8x16NarrowI16x8U => return simd_inst(102, buf)
    F32x4Ceil => return simd_inst(103, buf)
    F32x4Floor => return simd_inst(104, buf)
    F32x4Trunc => return simd_inst(105, buf)
    F32x4Nearest => return simd_inst(106, buf)
    I8x16Shl => return simd_inst(107, buf)
    I8x16ShrS => return simd_inst(108, buf)
    I8x16ShrU => return simd_inst(109, buf)
    I8x16Add => return simd_inst(110, buf)
    I8x16AddSatS => return simd_inst(111, buf)
    I8x16AddSatU => return simd_inst(112, buf)
    I8x16Sub => return simd_inst(113, buf)
    I8x16SubSatS => return simd_inst(114, buf)
    I8x16SubSatU => return simd_inst(115, buf)
    F64x2Ceil => return simd_inst(116, buf)
    F64x2Floor => return simd_inst(117, buf)
    I8x16MinS => return simd_inst(118, buf)
    I8x16MinU => return simd_inst(119, buf)
    I8x16MaxS => return simd_inst(120, buf)
    I8x16MaxU => return simd_inst(121, buf)
    F64x2Trunc => return simd_inst(122, buf)
    I8x16AvgrU => return simd_inst(123, buf)
    I16x8ExtaddPairwiseI8x16S => return simd_inst(124, buf)
    I16x8ExtaddPairwiseI8x16U => return simd_inst(125, buf)
    I32x4ExtaddPairwiseI16x8S => return simd_inst(126, buf)
    I32x4ExtaddPairwiseI16x8U => return simd_inst(127, buf)
    I16x8Abs => return simd_inst(128, buf)
    I16x8Neg => return simd_inst(129, buf)
    I16x8Q15mulrSatS => return simd_inst(130, buf)
    I16x8AllTrue => return simd_inst(131, buf)
    I16x8Bitmask => return simd_inst(132, buf)
    I16x8NarrowI32x4S => return simd_inst(133, buf)
    I16x8NarrowI32x4U => return simd_inst(134, buf)
    I16x8ExtendLowI8x16S => return simd_inst(135, buf)
    I16x8ExtendHighI8x16S => return simd_inst(136, buf)
    I16x8ExtendLowI8x16U => return simd_inst(137, buf)
    I16x8ExtendHighI8x16U => return simd_inst(138, buf)
    I16x8Shl => return simd_inst(139, buf)
    I16x8ShrS => return simd_inst(140, buf)
    I16x8ShrU => return simd_inst(141, buf)
    I16x8Add => return simd_inst(142, buf)
    I16x8AddSatS => return simd_inst(143, buf)
    I16x8AddSatU => return simd_inst(144, buf)
    I16x8Sub => return simd_inst(145, buf)
    I16x8SubSatS => return simd_inst(146, buf)
    I16x8SubSatU => return simd_inst(147, buf)
    F64x2Nearest => return simd_inst(148, buf)
    I16x8Mul => return simd_inst(149, buf)
    I16x8MinS => return simd_inst(150, buf)
    I16x8MinU => return simd_inst(151, buf)
    I16x8MaxS => return simd_inst(152, buf)
    I16x8MaxU => return simd_inst(153, buf)
    I16x8AvgrU => return simd_inst(155, buf)
    I16x8ExtmulLowI8x16S => return simd_inst(156, buf)
    I16x8ExtmulHighI8x16S => return simd_inst(157, buf)
    I16x8ExtmulLowI8x16U => return simd_inst(158, buf)
    I16x8ExtmulHighI8x16U => return simd_inst(159, buf)
    I32x4Abs => return simd_inst(160, buf)
    I32x4Neg => return simd_inst(161, buf)
    I32x4AllTrue => return simd_inst(163, buf)
    I32x4Bitmask => return simd_inst(164, buf)
    I32x4ExtendLowI16x8S => return simd_inst(167, buf)
    I32x4ExtendHighI16x8S => return simd_inst(168, buf)
    I32x4ExtendLowI16x8U => return simd_inst(169, buf)
    I32x4ExtendHighI16x8U => return simd_inst(170, buf)
    I32x4Shl => return simd_inst(171, buf)
    I32x4ShrS => return simd_inst(172, buf)
    I32x4ShrU => return simd_inst(173, buf)
    I32x4Add => return simd_inst(174, buf)
    I32x4Sub => return simd_inst(177, buf)
    I32x4Mul => return simd_inst(181, buf)
    I32x4MinS => return simd_inst(182, buf)
    I32x4MinU => return simd_inst(183, buf)
    I32x4MaxS => return simd_inst(184, buf)
    I32x4MaxU => return simd_inst(185, buf)
    I32x4DotI16x8S => return simd_inst(186, buf)
    I32x4ExtmulLowI16x8S => return simd_inst(188, buf)
    I32x4ExtmulHighI16x8S => return simd_inst(189, buf)
    I32x4ExtmulLowI16x8U => return simd_inst(190, buf)
    I32x4ExtmulHighI16x8U => return simd_inst(191, buf)
    I64x2Abs => return simd_inst(192, buf)
    I64x2Neg => return simd_inst(193, buf)
    I64x2AllTrue => return simd_inst(195, buf)
    I64x2Bitmask => return simd_inst(196, buf)
    I64x2ExtendLowI32x4S => return simd_inst(199, buf)
    I64x2ExtendHighI32x4S => return simd_inst(200, buf)
    I64x2ExtendLowI32x4U => return simd_inst(201, buf)
    I64x2ExtendHighI32x4U => return simd_inst(202, buf)
    I64x2Shl => return simd_inst(203, buf)
    I64x2ShrS => return simd_inst(204, buf)
    I64x2ShrU => return simd_inst(205, buf)
    I64x2Add => return simd_inst(206, buf)
    I64x2Sub => return simd_inst(209, buf)
    I64x2Mul => return simd_inst(213, buf)
    I64x2Eq => return simd_inst(214, buf)
    I64x2Ne => return simd_inst(215, buf)
    I64x2LtS => return simd_inst(216, buf)
    I64x2GtS => return simd_inst(217, buf)
    I64x2LeS => return simd_inst(218, buf)
    I64x2GeS => return simd_inst(219, buf)
    I64x2ExtmulLowI32x4S => return simd_inst(220, buf)
    I64x2ExtmulHighI32x4S => return simd_inst(221, buf)
    I64x2ExtmulLowI32x4U => return simd_inst(222, buf)
    I64x2ExtmulHighI32x4U => return simd_inst(223, buf)
    F32x4Abs => return simd_inst(224, buf)
    F32x4Neg => return simd_inst(225, buf)
    F32x4Sqrt => return simd_inst(227, buf)
    F32x4Add => return simd_inst(228, buf)
    F32x4Sub => return simd_inst(229, buf)
    F32x4Mul => return simd_inst(230, buf)
    F32x4Div => return simd_inst(231, buf)
    F32x4Min => return simd_inst(232, buf)
    F32x4Max => return simd_inst(233, buf)
    F32x4Pmin => return simd_inst(234, buf)
    F32x4Pmax => return simd_inst(235, buf)
    F64x2Abs => return simd_inst(236, buf)
    F64x2Neg => return simd_inst(237, buf)
    F64x2Sqrt => return simd_inst(239, buf)
    F64x2Add => return simd_inst(240, buf)
    F64x2Sub => return simd_inst(241, buf)
    F64x2Mul => return simd_inst(242, buf)
    F64x2Div => return simd_inst(243, buf)
    F64x2Min => return simd_inst(244, buf)
    F64x2Max => return simd_inst(245, buf)
    F64x2Pmin => return simd_inst(246, buf)
    F64x2Pmax => return simd_inst(247, buf)
    I32x4TruncSatF32x4S => return simd_inst(248, buf)
    I32x4TruncSatF32x4U => return simd_inst(249, buf)
    F32x4ConvertI32x4S => return simd_inst(250, buf)
    F32x4ConvertI32x4U => return simd_inst(251, buf)
    I32x4TruncSatF64x2SZero => return simd_inst(252, buf)
    I32x4TruncSatF64x2UZero => return simd_inst(253, buf)
    F64x2ConvertLowI32x4S => return simd_inst(254, buf)
    F64x2ConvertLowI32x4U => return simd_inst(255, buf)
    I8x16RelaxedSwizzle => return simd_inst(256, buf)
    I32x4RelaxedTruncF32x4S => return simd_inst(257, buf)
    I32x4RelaxedTruncF32x4U => return simd_inst(258, buf)
    I32x4RelaxedTruncZeroF64x2S => return simd_inst(259, buf)
    I32x4RelaxedTruncZeroF64x2U => return simd_inst(260, buf)
    F32x4RelaxedMadd => return simd_inst(261, buf)
    F32x4RelaxedNmadd => return simd_inst(262, buf)
    F64x2RelaxedMadd => return simd_inst(263, buf)
    F64x2RelaxedNmadd => return simd_inst(264, buf)
    I8x16RelaxedLaneselect => return simd_inst(265, buf)
    I16x8RelaxedLaneselect => return simd_inst(266, buf)
    I32x4RelaxedLaneselect => return simd_inst(267, buf)
    I64x2RelaxedLaneselect => return simd_inst(268, buf)
    F32x4RelaxedMin => return simd_inst(269, buf)
    F32x4RelaxedMax => return simd_inst(270, buf)
    F64x2RelaxedMin => return simd_inst(271, buf)
    F64x2RelaxedMax => return simd_inst(272, buf)
    I16x8RelaxedQ15mulrS => return simd_inst(273, buf)
    I16x8RelaxedDotI8x16I7x16S => return simd_inst(274, buf)
    I32x4RelaxedDotI8x16I7x16AddS => return simd_inst(275, buf)
  }
  Ok(())
}

///|
pub impl[T : Encode] Encode for Array[T] with encode(val, buf) {
  if Encode::encode(@lib.U32(val.length().reinterpret_as_uint()), buf) is Err(t) {
    return Err(t)
  }
  for v in val {
    if Encode::encode(v, buf) is Err(t) {
      return Err(t)
    }
  }
  Ok(())
}
