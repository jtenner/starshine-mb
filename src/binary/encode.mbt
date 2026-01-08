///|
pub trait Encode {
  encode(Self, @buffer.Buffer) -> Result[Unit, String]
}

///|
pub trait Decode {
  decode(Bytes, Int) -> Result[(Self, Int), String]
}

///|
using @lib {
  type NumType,
  type HeapType,
  type S33,
  type F32,
  type F64,
  type I32,
  type I64,
  type U32,
  type U64,
  type AbsHeapType,
  type RefType,
  type ValType,
  type CompType,
  type FieldType,
  type Mut,
  type StorageType,
  type PackType,
  type RecType,
  type SubType,
  type ExternIdx,
  type TypeIdx,
  type FuncIdx,
  type TableIdx,
  type MemIdx,
  type GlobalIdx,
  type TagIdx,
  type ElemIdx,
  type DataIdx,
  type LocalIdx,
  type LabelIdx,
  type LaneIdx,
  type Name,
  type CustomSec,
  type TypeSec,
  type ImportSec,
  type Import,
  type ExternType,
  type TableType,
  type Limits,
  type MemType,
  type GlobalType,
  type TagType,
  type FuncSec,
  type TableSec,
  type Table,
  type MemSec,
  type GlobalSec,
  type Global,
  type ExportSec,
  type Export,
  type StartSec,
  type ElemSec,
  type Elem,
  type CodeSec,
  type Func,
  type DataSec,
  type Data,
  type Locals,
  type DataCntSec,
  type TagSec,
  type CastOp,
  type Module,
  type Expr,
  type Instruction,
  type ElemMode,
  type DataMode,
  type BlockType,
  type Catch,
  type MemArg,
  tlocals_to_locals,
  texpr_to_expr,
  i32_valtype,
  i64_valtype,
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
pub impl Decode for NumType with decode(buf, idx) {
  match buf.get(idx) {
    Some(0x7C) => Ok((F64NumType, idx + 1))
    Some(0x7D) => Ok((F32NumType, idx + 1))
    Some(0x7E) => Ok((I64NumType, idx + 1))
    Some(0x7F) => Ok((I32NumType, idx + 1))
    Some(_) => Err("Invalid NumType Byte")
    None => Err("Index out of bounds")
  }
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
pub impl Decode for HeapType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((abs, i)) => Ok((AbsHeapTypeHeapType(abs), i))
    Err(_) =>
      match Decode::decode(bytes, i) {
        Ok((@lib.S33(s), i)) => Ok((HeapType(TypeIdx(s)), i))
        Err(err) => Err(err)
      }
  }
}

///|
pub impl Decode for AbsHeapType with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x69) => Ok((ExnAbsHeapType, i + 1))
    Some(0x6A) => Ok((ArrayAbsHeapType, i + 1))
    Some(0x6B) => Ok((StructAbsHeapType, i + 1))
    Some(0x6C) => Ok((I31AbsHeapType, i + 1))
    Some(0x6D) => Ok((EqAbsHeapType, i + 1))
    Some(0x6E) => Ok((AnyAbsHeapType, i + 1))
    Some(0x6F) => Ok((ExternAbsHeapType, i + 1))
    Some(0x70) => Ok((FuncAbsHeapType, i + 1))
    Some(0x71) => Ok((NoneAbsHeapType, i + 1))
    Some(0x72) => Ok((NoExternAbsHeapType, i + 1))
    Some(0x73) => Ok((NoFuncAbsHeapType, i + 1))
    Some(0x74) => Ok((NoExnAbsHeapType, i + 1))
    Some(_) => Err("Invalid Abstract Heap Type")
    None => Err("Index out of bounds")
  }
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
pub impl Decode for RefType with decode(bytes, i) {
  match bytes.get(i) {
    None => Err("Index out of bounds")
    Some(0x63) =>
      match Decode::decode(bytes, i + 1) {
        Err(err) => Err(err)
        Ok((ht, i)) => Ok((HeapTypeRefType(true, ht), i))
      }
    Some(0x64) =>
      match Decode::decode(bytes, i + 1) {
        Err(err) => Err(err)
        Ok((ht, i)) => Ok((HeapTypeRefType(false, ht), i))
      }
    Some(_) =>
      match Decode::decode(bytes, i) {
        Err(err) => Err(err)
        Ok((abs, i)) => Ok((AbsHeapTypeRefType(abs), i))
      }
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
pub impl Decode for ValType with decode(bytes, i) {
  match bytes.get(i) {
    None => Err("Index out of bounds")
    Some(0x7B) => Ok((VecTypeValType, i + 1))
    Some(_) =>
      match Decode::decode(bytes, i) {
        Ok((t, i)) => Ok((NumTypeValType(t), i))
        _ =>
          match Decode::decode(bytes, i) {
            Ok((rt, i)) => Ok((RefTypeValType(rt), i))
            _ => Err("Invalid ValType")
          }
      }
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
pub impl[T : Decode] Decode for @list.List[T] with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((@lib.U32(len), i)) =>
      loop ([], len, i) {
        (acc, left, i) if left > 0 =>
          match T::decode(bytes, i) {
            Ok((u, i)) => {
              acc.push(u)
              continue (acc, left - 1, i)
            }
            Err(err) => Err(err)
          }
        (acc, _, i) => Ok((@list.List::from_array(acc), i))
      }
    Err(err) => Err(err)
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
pub impl Decode for CompType with decode(bytes, i) {
  match bytes.get(i) {
    None => Err("Index out of bounds")
    Some(0x5E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((ft, i)) => Ok((ArrayCompType(ft), i))
        Err(err) => Err(err)
      }
    Some(0x5F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((fts, i)) => Ok((StructCompType(fts), i))
        Err(err) => Err(err)
      }
    Some(0x60) =>
      match Decode::decode(bytes, i + 1) {
        Ok((props, i)) =>
          match Decode::decode(bytes, i) {
            Ok((rets, i)) => Ok((FuncCompType(props, rets), i))
            Err(err) => Err(err)
          }
        Err(err) => Err(err)
      }
    Some(_) => Err("Invalid Comp Type")
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
pub impl Decode for FieldType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Err(err) => Err(err)
    Ok((st, i)) =>
      match Decode::decode(bytes, i) {
        Ok((m, i)) => Ok((FieldType(st, m), i))
        Err(err) => Err(err)
      }
  }
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
pub impl Decode for Mut with decode(bytes, i) {
  if i >= bytes.length() {
    return Err("unexpected EOF decoding mut")
  }
  let b = bytes[i]
  match b {
    0x00 => Ok((Const, i + 1))
    0x01 => Ok((Var, i + 1))
    _ => Err("invalid mut byte")
  }
}

///|
pub impl Encode for StorageType with encode(val, buf) {
  match val {
    ValTypeStorageType(vt) => Encode::encode(vt, buf)
    PackTypeStorageType(pt) => Encode::encode(pt, buf)
  }
}

///|
pub impl Decode for StorageType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((vt, i)) => Ok((ValTypeStorageType(vt), i))
    Err(_) =>
      match Decode::decode(bytes, i) {
        Ok((pt, i)) => Ok((PackTypeStorageType(pt), i))
        Err(_) => Err("Invalid StorageType")
      }
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
pub impl Decode for PackType with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x77) => Ok((I16PackType, i + 1))
    Some(0x78) => Ok((I8PackType, i + 1))
    Some(_) => Err("Invalid Packed Type")
    None => Err("Index out of bounds")
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
pub impl Decode for RecType with decode(buf, i) {
  match buf.get(i) {
    None => Err("Index out of bounds")
    Some(0x4E) =>
      match Decode::decode(buf, i + 1) {
        Ok((sts, i)) => Ok((GroupRecType(sts), i))
        Err(err) => Err(err)
      }
    Some(_) =>
      match Decode::decode(buf, i) {
        Ok((st, i)) => Ok((SingleRecType(st), i))
        Err(err) => Err(err)
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
pub impl Decode for SubType with decode(buf, i) {
  match buf.get(i) {
    // Final
    Some(0x4F) =>
      match Decode::decode(buf, i + 1) {
        Ok((idxs, i)) =>
          match Decode::decode(buf, i) {
            Ok((ct, i)) => Ok((SubType(true, idxs, ct), i))
            Err(err) => Err(err)
          }
        Err(err) => Err(err)
      }
    // Subtypes
    Some(0x50) =>
      match Decode::decode(buf, i + 1) {
        Ok((idxs, i)) =>
          match Decode::decode(buf, i) {
            Ok((ct, i)) => Ok((SubType(false, idxs, ct), i))
            Err(err) => Err(err)
          }
        Err(err) => Err(err)
      }
    // CompType, don't consume the character
    Some(_) =>
      match Decode::decode(buf, i) {
        Ok((ct, i)) => Ok((CompTypeSubType(ct), i))
        Err(err) => Err(err)
      }
    None => Err("Index out of bounds")
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
fn decode_unsigned(
  bytes : Bytes,
  index : Int,
  nbits : Int,
) -> Result[(UInt64, Int), String] {
  if nbits <= 0 || nbits > 64 {
    return Err("invalid nbits for uleb")
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut i = index
  let mut shift = 0
  let mut acc : UInt64 = 0UL
  let mut count = 0
  while true {
    if i >= bytes.length() {
      return Err("unexpected EOF in uleb")
    }
    if count >= max_bytes {
      return Err("uleb too many bytes")
    }
    let byte_u : UInt64 = bytes[i].to_uint64()
    i += 1
    count += 1
    let payload : UInt64 = byte_u & 0x7fUL
    acc = acc | (payload << shift)
    let cont = (byte_u & 0x80UL) != 0UL
    shift = shift + 7
    if !cont {
      // range check
      if nbits < 64 {
        let max_val = (1UL << nbits) - 1UL
        if acc > max_val {
          return Err("uleb out of range for bit width")
        }
      }

      // terminal unused bits constraint - ONLY at max bytes
      if count == max_bytes {
        let rem = nbits % 7
        if rem != 0 {
          let limit = 1UL << rem
          if payload >= limit {
            return Err("uleb terminal byte has non-zero unused bits")
          }
        }
      }
      return Ok((acc, i))
    }
  }
  Err("unreachable")
}

///|
fn decode_signed(
  bytes : Bytes,
  index : Int,
  nbits : Int,
) -> Result[(Int64, Int), String] {
  if nbits <= 0 || nbits > 64 {
    return Err("invalid nbits for sleb")
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut i = index
  let mut shift = 0
  let mut acc : Int64 = 0
  let mut count = 0
  let mut last_byte : UInt64 = 0
  while true {
    if i >= bytes.length() {
      return Err("unexpected EOF in sleb")
    }
    if count >= max_bytes {
      return Err("sleb too many bytes")
    }
    let byte_u = bytes[i].to_uint64()
    last_byte = byte_u
    i += 1
    count += 1
    let payload = (byte_u & 0x7f).reinterpret_as_int64()
    acc = acc | (payload << shift)
    let cont = (byte_u & 0x80) != 0
    shift += 7
    if !cont {
      break
    }
  }

  // sign extend to full int64 based on last byte's sign bit (0x40)
  if (last_byte & 0x40) != 0 && shift < 64 {
    acc = acc | ((-1 : Int64) << shift)
  }

  // range check for N bits signed
  if nbits < 64 {
    let min = (-1 : Int64) << (nbits - 1)
    let max = ((1 : Int64) << (nbits - 1)) - 1
    if acc < min || acc > max {
      return Err("sleb out of range for bit width")
    }
  }

  // terminal-byte unused bits constraint - ONLY at max bytes
  if count == max_bytes && nbits != 64 {
    let rem = nbits % 7
    if rem != 0 {
      let payload_u = last_byte & 0x7f
      let used_mask = (1UL << rem) - 1UL
      let inv_used = UInt64::lnot(used_mask) & 0x7fUL
      let unused = payload_u & inv_used
      if acc >= 0 {
        if unused != 0 {
          return Err("sleb terminal byte has non-zero unused bits for positive")
        }
      } else {
        let want = inv_used
        if unused != want {
          return Err("sleb terminal byte has wrong sign-extension bits")
        }
      }
    }
  }
  Ok((acc, i))
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
pub impl Decode for S33 with decode(bytes, i) {
  match decode_signed(bytes, i, 33) {
    Err(err) => Err(err)
    Ok((val, i)) if val >= 0 && val < 4294967295 =>
      Ok((S33(val.to_int().reinterpret_as_uint()), i))
    Ok(_) => Err("Invalid S33 Range")
  }
}

///|
pub impl Decode for I32 with decode(bytes, i) {
  match decode_signed(bytes, i, 32) {
    Err(err) => Err(err)
    Ok((val, i)) => Ok((I32(val.to_int()), i))
  }
}

///|
pub impl Decode for @lib.U32 with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(err) => Err(err)
    Ok((val, i)) => Ok((U32(val.to_uint()), i))
  }
}

///|
pub impl Decode for I64 with decode(bytes, i) {
  match decode_signed(bytes, i, 64) {
    Err(err) => Err(err)
    Ok((val, i)) => Ok((I64(val), i))
  }
}

///|
pub impl Decode for @lib.U64 with decode(bytes, i) {
  match decode_unsigned(bytes, i, 64) {
    Err(err) => Err(err)
    Ok((val, i)) => Ok((U64(val), i))
  }
}

///|
pub impl Decode for F32 with decode(bytes, i) {
  if bytes.length() >= i + 4 {
    let value : Int = (bytes.unsafe_get(i + 3).to_int() << 24) |
      (bytes.unsafe_get(i + 2).to_int() << 16) |
      (bytes.unsafe_get(i + 1).to_int() << 8) |
      bytes.unsafe_get(i).to_int()
    Ok((F32(Float::reinterpret_from_int(value)), i + 4))
  } else {
    Err("Index out of bounds")
  }
}

///|
pub impl Decode for F64 with decode(bytes, i) {
  if bytes.length() >= i + 8 {
    let value : Int64 = (bytes.unsafe_get(i + 7).to_int64() << 56) |
      (bytes.unsafe_get(i + 6).to_int64() << 48) |
      (bytes.unsafe_get(i + 5).to_int64() << 40) |
      (bytes.unsafe_get(i + 4).to_int64() << 32) |
      (bytes.unsafe_get(i + 3).to_int64() << 24) |
      (bytes.unsafe_get(i + 2).to_int64() << 16) |
      (bytes.unsafe_get(i + 1).to_int64() << 8) |
      bytes.unsafe_get(i).to_int64()
    Ok((F64(value.reinterpret_as_double()), i + 8))
  } else {
    Err("Index out of bounds")
  }
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
pub impl Decode for Bool with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) => Ok((false, i + 1))
    Some(0x01) => Ok((true, i + 1))
    Some(_) => Err("Invalid bool")
    None => Err("Index out of bounds")
  }
}

///|
pub impl[T : Decode] Decode for T? with decode(bytes, i) {
  match T::decode(bytes, i) {
    Err(_) => Ok((None, i))
    Ok((val, i)) => Ok((Some(val), i))
  }
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
pub impl Decode for TypeIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((TypeIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for FuncIdx with encode(val, buf) {
  let FuncIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for FuncIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((FuncIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for TableIdx with encode(val, buf) {
  let TableIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for TableIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((TableIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for MemIdx with encode(val, buf) {
  let MemIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for MemIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((MemIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for GlobalIdx with encode(val, buf) {
  let GlobalIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for GlobalIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((GlobalIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for TagIdx with encode(val, buf) {
  let TagIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for TagIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((TagIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for ElemIdx with encode(val, buf) {
  let ElemIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for ElemIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((ElemIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for DataIdx with encode(val, buf) {
  let DataIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for DataIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((DataIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for LocalIdx with encode(val, buf) {
  let LocalIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for LocalIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((LocalIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for LabelIdx with encode(val, buf) {
  let LabelIdx(id) = val
  encode_unsigned(id.to_uint64(), buf, 32)
}

///|
pub impl Decode for LabelIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((LabelIdx(n.to_uint()), i))
  }
}

///|
pub impl Encode for LaneIdx with encode(val, buf) {
  buf.write_byte(val.0)
  Ok(())
}

///|
pub impl Decode for LaneIdx with decode(bytes, i) {
  if bytes.get(i) is Some(n) && n < 16 {
    Ok((LaneIdx(n), i + 1))
  } else {
    Err("Invalid Lane Index")
  }
}

///|
pub impl Encode for Name with encode(val, buf) {
  let Name(name) = val
  let bytes = @encoding/utf8.encode(name)
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
pub impl Decode for Name with decode(bytes, i) {
  let (@lib.U32(len_u), j) = match Decode::decode(bytes, i) {
    Err(err) => return Err(err)
    Ok(t) => t
  }
  let len = len_u.reinterpret_as_int()
  if len < 0 {
    return Err("negative name length")
  }
  let end = j + len
  if end > bytes.length() {
    return Err("Index out of bounds")
  }
  let name = @encoding/utf8.decode_lossy(bytes[j:end]).to_string_view()
  Ok((Name(name), end))
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
      let rt = @lib.HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
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
      let rt = @lib.HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
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
    Elem(Active(_), TypedExprsElemKind(_)) => {
      println("Hit problem active sequence.")
      Err(
        "Invalid Active Sequence. Active Sequences must be func refs or indicies.",
      )
    }
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
      let expr = texpr_to_expr(texpr)
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
  for sec in val.0 {
    if Encode::encode(sec, buf) is Err(t) {
      return Err(t)
    }
  }
  if Encode::encode(val.1, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.2, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.3, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.4, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.5, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.6, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.7, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.8, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.9, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.10, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.11, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.12, buf) is Err(t) {
    return Err(t)
  }
  if Encode::encode(val.13, buf) is Err(t) {
    return Err(t)
  }
  Ok(())
}

///|
pub impl Decode for Module with decode(bytes, i) {
  let mut i = i
  let custom = Array::new()
  let mut type_sec = None
  let mut import_sec = None
  let mut func_sec = None
  let mut table_sec = None
  let mut mem_sec = None
  let mut tag_sec = None
  let mut global_sec = None
  let mut export_sec = None
  let mut start_sec = None
  let mut elem_sec = None
  let mut data_cnt_sec = None
  let mut code_sec = None
  let mut data_sec = None
  for b in [0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00] {
    if bytes.get(i) != Some(b.to_byte()) {
      return Err("Invalid magic header")
    }
    i = i + 1
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    type_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    import_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    func_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    table_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    mem_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    tag_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    global_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    export_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    start_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    elem_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    data_cnt_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    code_sec = Some(sec)
    i = next
  }
  while Decode::decode(bytes, i) is Ok((sec, next)) {
    custom.push(sec)
    i = next
  }
  if Decode::decode(bytes, i) is Ok((sec, next)) {
    data_sec = Some(sec)
    i = next
  }
  if i == bytes.length() {
    Ok(
      (
        Module(
          custom, type_sec, import_sec, func_sec, table_sec, mem_sec, tag_sec, global_sec,
          export_sec, start_sec, elem_sec, data_cnt_sec, code_sec, data_sec,
        ),
        i,
      ),
    )
  } else {
    Err("Invalid module")
  }
}

///|
pub impl Decode for Elem with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((expr, i)) =>
          match Decode::decode(bytes, i) {
            Ok((fidxs, i)) =>
              Ok((Elem(ElemMode::Active(0, expr), FuncsElemKind(fidxs)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match bytes.get(i + 1) {
        Some(0x00) =>
          match Decode::decode(bytes, i + 2) {
            Ok((fidxs, i)) => Ok((Elem(Passive, FuncsElemKind(fidxs)), i))
            Err(t) => Err(t)
          }
        _ => Err("Invalid elem header")
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.TableIdx(idx), i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) =>
              match bytes.get(i) {
                Some(0x00) =>
                  match Decode::decode(bytes, i + 1) {
                    Ok((fidxs, i)) =>
                      Ok(
                        (
                          Elem(
                            ElemMode::Active(idx, expr),
                            FuncsElemKind(fidxs),
                          ),
                          i,
                        ),
                      )
                    Err(t) => Err(t)
                  }
                _ => Err("Invalid elem header")
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match bytes.get(i + 1) {
        Some(0x00) =>
          match Decode::decode(bytes, i + 2) {
            Ok((fidxs, i)) => Ok((Elem(Declarative, FuncsElemKind(fidxs)), i))
            Err(t) => Err(t)
          }
        _ => Err("Invalid elem header")
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((expr, i)) =>
          match Decode::decode(bytes, i) {
            Ok((exprs, i)) =>
              Ok(
                (
                  Elem(
                    ElemMode::Active(TableIdx(0), expr),
                    FuncExprsElemKind(exprs),
                  ),
                  i,
                ),
              )
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x05) =>
      match Decode::decode(bytes, i + 1) {
        Ok((rt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((exprs, i)) =>
              Ok((Elem(Passive, TypedExprsElemKind(rt, exprs)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x06) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) =>
              match Decode::decode(bytes, i) {
                Ok((exprs, i)) =>
                  Ok(
                    (
                      Elem(
                        ElemMode::Active(idx, expr),
                        FuncExprsElemKind(exprs),
                      ),
                      i,
                    ),
                  )
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x07) =>
      match Decode::decode(bytes, i + 1) {
        Ok((rt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((exprs, i)) =>
              Ok((Elem(Declarative, TypedExprsElemKind(rt, exprs)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(_) => Err("Invalid elem header")
    None => Err("Index out of bounds")
  }
}

///|
pub impl Decode for ElemSec with decode(bytes, i) {
  if bytes.get(i) != Some(9) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((ElemSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for DataCntSec with decode(bytes, i) {
  if bytes.get(i) != Some(12) {
    return Err("Invalid section header")
  }
  match Decode::decode(bytes, i + 1) {
    Ok((@lib.U32(count), i)) => Ok((DataCntSec(count), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Locals with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((@lib.U32(count), i)) =>
      match Decode::decode(bytes, i) {
        Ok((vt, i)) => Ok((Locals(count, vt), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Func with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((@lib.U32(_size), i)) => // Read the length prefix first
      match Decode::decode(bytes, i) {
        Ok((locals, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) => Ok((Func(locals, expr), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for CodeSec with decode(bytes, i) {
  if bytes.get(i) != Some(10) {
    return Err("Invalid section header")
  }
  match Decode::decode(bytes, i + 1) {
    Ok((funcs, i)) => Ok((CodeSec(funcs), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Data with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((expr, i)) =>
          match Decode::decode(bytes, i) {
            Ok((bytes, i)) =>
              Ok((Data(DataMode::Active(MemIdx(0), expr), bytes), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bytes, i)) => Ok((Data(DataMode::Passive, bytes), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) =>
              match Decode::decode(bytes, i) {
                Ok((bytes, i)) =>
                  Ok((Data(DataMode::Active(idx, expr), bytes), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(_) => Err("Invalid data header")
    None => Err("Index out of bounds")
  }
}

///|
pub impl Decode for DataSec with decode(bytes, i) {
  if bytes.get(i) != Some(11) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((DataSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for CustomSec with decode(bytes, i) {
  if bytes.get(i) != Some(0) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), i1) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let end = i1 + len
  if end > bytes.length() {
    return Err("Custom section payload length out of range")
  }
  let view = bytes[i1:end].to_bytes()
  let (name, j) = match Decode::decode(view, 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let bytes = view[j:].to_bytes()
  Ok((CustomSec(name, bytes), end))
}

///|
pub impl Decode for TypeSec with decode(bytes, i) {
  if bytes.get(i) != Some(1) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((TypeSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for Import with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((nm1, i)) =>
      match Decode::decode(bytes, i) {
        Ok((nm2, i)) =>
          match Decode::decode(bytes, i) {
            Ok((et, i)) => Ok((Import(nm1, nm2, et), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Limits with decode(bytes, i) {
  match bytes.get(i) {
    None => Err("Index out of bounds")
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) => Ok((I32Limits(n.to_uint(), None), i))
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) =>
          match Decode::decode(bytes, i) {
            Ok((@lib.U64(m), i)) =>
              Ok((I32Limits(n.to_uint(), Some(m.to_uint())), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) => Ok((I64Limits(n, None), i))
        Err(t) => Err(t)
      }
    Some(0x05) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) =>
          match Decode::decode(bytes, i) {
            Ok((@lib.U64(m), i)) => Ok((I64Limits(n, Some(m)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(_) => Err("Invalid Limits")
  }
}

///|
pub impl Decode for TableType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((rt, i)) =>
      match Decode::decode(bytes, i) {
        Ok((l, i)) => Ok((TableType(rt, l), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for MemType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((l, i)) => Ok((MemType(l), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for GlobalType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((vt, i)) =>
      match Decode::decode(bytes, i) {
        Ok((m, i)) => Ok((GlobalType(vt, m), i))
        Err(_) => Ok((GlobalType(vt, false), i))
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for TagType with decode(bytes, i) {
  if bytes.get(i) != Some(0x00) {
    return Err("Invalid TagType")
  }
  match Decode::decode(bytes, i + 1) {
    Ok((idx, i)) => Ok((TagType(idx), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for ExternType with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((FuncExternType(idx), i))
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tt, i)) => Ok((TableExternType(tt), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((mt, i)) => Ok((MemExternType(mt), i))
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((gt, i)) => Ok((GlobalExternType(gt), i))
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tt, i)) => Ok((TagExternType(tt), i))
        Err(t) => Err(t)
      }
    Some(_) => Err("Invalid ExternType Header")
    None => Err("Index out of bounds")
  }
}

// General pattern for section decoding

///|
pub impl Decode for ImportSec with decode(bytes, i) {
  if bytes.get(i) != Some(2) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((ImportSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for FuncSec with decode(bytes, i) {
  if bytes.get(i) != Some(3) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((FuncSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for BlockType with decode(bytes, i) {
  if bytes.get(i) is Some(0x40) {
    return Ok((EmptyBlockType, i + 1))
  }
  if Decode::decode(bytes, i) is Ok((vt, i)) {
    return Ok((ValTypeBlockType(vt), i))
  }
  if Decode::decode(bytes, i) is Ok((@lib.S33(idx), i)) {
    return Ok((TypeIdxBlockType(TypeIdx(idx)), i))
  }
  Err("Invalid block type")
}

///|
pub impl Decode for Expr with decode(bytes, i) {
  let a = Array::new()
  let i = loop i {
    i =>
      match Decode::decode(bytes, i) {
        Ok((inst, i)) => {
          a.push(inst)
          continue i
        }
        Err(_) if bytes.get(i) == Some(0x0B) => break i + 1
        Err(t) => return Err(t)
      }
  }
  Ok((Expr(a), i))
}

///|
pub impl Decode for Table with decode(bytes, i) {
  match (bytes.get(i), bytes.get(i + 1)) {
    (Some(0x40), Some(0x00)) =>
      match Decode::decode(bytes, i + 2) {
        Ok((tt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((e, i)) => Ok((Table(tt, Some(e)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    _ =>
      match Decode::decode(bytes, i) {
        Ok((tt, i)) => Ok((Table(tt, None), i))
        Err(t) => Err(t)
      }
  }
}

///|
pub impl Decode for Global with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((gt, i)) =>
      match Decode::decode(bytes, i) {
        Ok((expr, i)) => Ok((Global(gt, expr), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for ExternIdx with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((FuncExternIdx(idx), i))
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((TableExternIdx(idx), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((MemExternIdx(idx), i))
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((GlobalExternIdx(idx), i))
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((TagExternIdx(idx), i))
        Err(t) => Err(t)
      }
    Some(_) => Err("Invalid extern index")
    None => Err("Index out of bounds")
  }
}

///|
pub impl Decode for Export with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((n, i)) =>
      match Decode::decode(bytes, i) {
        Ok((idx, i)) => Ok((Export(n, idx), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for TableSec with decode(bytes, i) {
  if bytes.get(i) != Some(4) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((TableSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for MemSec with decode(bytes, i) {
  if bytes.get(i) != Some(5) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((MemSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for TagSec with decode(bytes, i) {
  if bytes.get(i) != Some(13) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((TagSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for GlobalSec with decode(bytes, i) {
  if bytes.get(i) != Some(6) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((GlobalSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for ExportSec with decode(bytes, i) {
  if bytes.get(i) != Some(7) {
    return Err("Invalid section header")
  }
  let (@lib.U32(len), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let payload_end = payload_start + len

  // Decode from the payload slice (or directly with bounds checking)
  let (content, j) = match
    Decode::decode(bytes[payload_start:payload_end].to_bytes(), 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if j == len {
    Ok((ExportSec(content), payload_end))
  } else {
    Err("Invalid section - didn't consume all bytes")
  }
}

///|
pub impl Decode for StartSec with decode(bytes, i) {
  if bytes.get(i) != Some(8) {
    return Err("Invalid section header")
  }
  match Decode::decode(bytes, i + 1) {
    Err(t) => Err(t)
    Ok((idx, i)) => Ok((StartSec(idx), i))
  }
}

///|
pub impl Decode for Bytes with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Err(t) => Err(t)
    Ok((@lib.U32(len), i)) if len + i.reinterpret_as_uint() <=
      bytes.length().reinterpret_as_uint() => {
      let next = i + len.reinterpret_as_int()
      let val = bytes.sub(start=i, end=next).to_bytes()
      Ok((val, next))
    }
    Ok(_) => Err("Invalid offset.")
  }
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
    EmptyBlockType => {
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
pub impl Decode for Catch with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((lidx, i)) => Ok((Catch(tidx, lidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((lidx, i)) => Ok((CatchRef(tidx, lidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((CatchAll(idx), i))
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((CatchAllRef(idx), i))
        Err(t) => Err(t)
      }
    _ => Err("Invalid catch")
  }
}

///|
pub impl Decode for CastOp with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) => Ok((CastOp(false, false), i + 1))
    Some(0x01) => Ok((CastOp(true, false), i + 1))
    Some(0x02) => Ok((CastOp(false, true), i + 1))
    Some(0x03) => Ok((CastOp(true, true), i + 1))
    _ => Err("Invalid castop")
  }
}

///|
pub impl Decode for MemArg with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((@lib.U32(n), i)) if n >= 64 && n < 128 =>
      match Decode::decode(bytes, i) {
        Ok((x, i)) =>
          match Decode::decode(bytes, i) {
            Ok((@lib.U64(m), i)) => Ok((MemArg(n - 64, Some(x), m), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Ok((@lib.U32(n), i)) if n < 64 =>
      match Decode::decode(bytes, i) {
        Ok((@lib.U64(m), i)) => Ok((MemArg(n, None, m), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
    _ => Err("Invalid memarg")
  }
}

///|
pub impl Decode for Instruction with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) => Ok((Unreachable, i + 1))
    Some(0x01) => Ok((Nop, i + 1))
    Some(0x1A) => Ok((Drop, i + 1))
    Some(0x1B) => Ok((Select(None), i + 1))
    Some(0x1C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((vts, i)) => Ok((Select(Some(vts)), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) => Ok((Block(bt, expr), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) => Ok((Loop(bt, expr), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) => {
          let (if_inst, i) = loop (i, [], None) {
            (i, if_insts, Some(else_insts)) =>
              match bytes.get(i) {
                Some(0x0B) =>
                  break (@lib.If(bt, if_insts, Some(else_insts)), i + 1)
                _ =>
                  match Decode::decode(bytes, i) {
                    Ok((inst, i)) => {
                      else_insts.push(inst)
                      continue (i, if_insts, Some(else_insts))
                    }
                    Err(t) => return Err(t)
                  }
              }
            (i, if_insts, None) =>
              match bytes.get(i) {
                Some(0x05) => continue (i + 1, if_insts, Some([]))
                Some(0x0B) => break (If(bt, if_insts, None), i + 1)
                _ =>
                  match Decode::decode(bytes, i) {
                    Ok((inst, i)) => {
                      if_insts.push(inst)
                      continue (i, if_insts, None)
                    }
                    Err(t) => return Err(t)
                  }
              }
          }
          Ok((if_inst, i))
        }
        Err(t) => Err(t)
      }
    Some(0x08) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tag, i)) => Ok((Throw(tag), i))
        Err(t) => Err(t)
      }
    Some(0x0A) => Ok((ThrowRef, i + 1))
    Some(0x0C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((lbl, i)) => Ok((Br(lbl), i))
        Err(t) => Err(t)
      }
    Some(0x0D) =>
      match Decode::decode(bytes, i + 1) {
        Ok((lbl, i)) => Ok((BrIf(lbl), i))
        Err(t) => Err(t)
      }
    Some(0x0E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((lbls, i)) =>
          match Decode::decode(bytes, i) {
            Ok((lbl, i)) => Ok((BrTable(lbls, lbl), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x0F) => Ok((Return, i + 1))
    Some(0x10) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Call(idx), i))
        Err(t) => Err(t)
      }
    Some(0x11) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((tblidx, i)) => Ok((CallIndirect(tidx, tblidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x12) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((ReturnCall(idx), i))
        Err(t) => Err(t)
      }
    Some(0x13) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((tblidx, i)) => Ok((ReturnCallIndirect(tidx, tblidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x14) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) => Ok((CallRef(tidx), i))
        Err(t) => Err(t)
      }
    Some(0x15) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) => Ok((ReturnCallRef(tidx), i))
        Err(t) => Err(t)
      }
    Some(0x1F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((c, i)) =>
              match Decode::decode(bytes, i) {
                Ok((e, i)) => Ok((TryTable(bt, c, e), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0xD5) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((BrOnNull(idx), i))
        Err(t) => Err(t)
      }
    Some(0xD6) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((BrOnNonNull(idx), i))
        Err(t) => Err(t)
      }
    Some(0x20) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((LocalGet(idx), i))
        Err(t) => Err(t)
      }
    Some(0x21) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((LocalSet(idx), i))
        Err(t) => Err(t)
      }
    Some(0x22) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((LocalTee(idx), i))
        Err(t) => Err(t)
      }
    Some(0x23) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((GlobalGet(idx), i))
        Err(t) => Err(t)
      }
    Some(0x24) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((GlobalSet(idx), i))
        Err(t) => Err(t)
      }
    Some(0x25) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((TableGet(idx), i))
        Err(t) => Err(t)
      }
    Some(0x26) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((TableSet(idx), i))
        Err(t) => Err(t)
      }
    Some(0x28) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Load(m), i))
        Err(t) => Err(t)
      }
    Some(0x29) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load(m), i))
        Err(t) => Err(t)
      }
    Some(0x2A) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((F32Load(m), i))
        Err(t) => Err(t)
      }
    Some(0x2B) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((F64Load(m), i))
        Err(t) => Err(t)
      }
    Some(0x2C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Load8S(m), i))
        Err(t) => Err(t)
      }
    Some(0x2D) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Load8U(m), i))
        Err(t) => Err(t)
      }
    Some(0x2E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Load16S(m), i))
        Err(t) => Err(t)
      }
    Some(0x2F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Load16U(m), i))
        Err(t) => Err(t)
      }
    Some(0x30) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load8S(m), i))
        Err(t) => Err(t)
      }
    Some(0x31) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load8U(m), i))
        Err(t) => Err(t)
      }
    Some(0x32) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load16S(m), i))
        Err(t) => Err(t)
      }
    Some(0x33) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load16U(m), i))
        Err(t) => Err(t)
      }
    Some(0x34) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load32S(m), i))
        Err(t) => Err(t)
      }
    Some(0x35) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Load32U(m), i))
        Err(t) => Err(t)
      }
    Some(0x36) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Store(m), i))
        Err(t) => Err(t)
      }
    Some(0x37) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Store(m), i))
        Err(t) => Err(t)
      }
    Some(0x38) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((F32Store(m), i))
        Err(t) => Err(t)
      }
    Some(0x39) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((F64Store(m), i))
        Err(t) => Err(t)
      }
    Some(0x3A) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Store8(m), i))
        Err(t) => Err(t)
      }
    Some(0x3B) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I32Store16(m), i))
        Err(t) => Err(t)
      }
    Some(0x3C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Store8(m), i))
        Err(t) => Err(t)
      }
    Some(0x3D) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Store16(m), i))
        Err(t) => Err(t)
      }
    Some(0x3E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((I64Store32(m), i))
        Err(t) => Err(t)
      }
    Some(0x3F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((x, i)) => Ok((MemorySize(x), i))
        Err(t) => Err(t)
      }
    Some(0x40) =>
      match Decode::decode(bytes, i + 1) {
        Ok((x, i)) => Ok((MemoryGrow(x), i))
        Err(t) => Err(t)
      }
    Some(0xD0) =>
      match Decode::decode(bytes, i + 1) {
        Ok((ht, i)) => Ok((RefNull(ht), i))
        Err(t) => Err(t)
      }
    Some(0xD1) => Ok((RefIsNull, i + 1))
    Some(0xD2) =>
      match Decode::decode(bytes, i + 1) {
        Ok((x, i)) => Ok((RefFunc(x), i))
        Err(t) => Err(t)
      }
    Some(0xD3) => Ok((RefEq, i + 1))
    Some(0xD4) => Ok((RefAsNonNull, i + 1))
    Some(0x45) => Ok((I32Eqz, i + 1))
    Some(0x46) => Ok((I32Eq, i + 1))
    Some(0x47) => Ok((I32Ne, i + 1))
    Some(0x48) => Ok((I32LtS, i + 1))
    Some(0x49) => Ok((I32LtU, i + 1))
    Some(0x4A) => Ok((I32GtS, i + 1))
    Some(0x4B) => Ok((I32GtU, i + 1))
    Some(0x4C) => Ok((I32LeS, i + 1))
    Some(0x4D) => Ok((I32LeU, i + 1))
    Some(0x4E) => Ok((I32GeS, i + 1))
    Some(0x4F) => Ok((I32GeU, i + 1))
    Some(0x50) => Ok((I64Eqz, i + 1))
    Some(0x51) => Ok((I64Eq, i + 1))
    Some(0x52) => Ok((I64Ne, i + 1))
    Some(0x53) => Ok((I64LtS, i + 1))
    Some(0x54) => Ok((I64LtU, i + 1))
    Some(0x55) => Ok((I64GtS, i + 1))
    Some(0x56) => Ok((I64GtU, i + 1))
    Some(0x57) => Ok((I64LeS, i + 1))
    Some(0x58) => Ok((I64LeU, i + 1))
    Some(0x59) => Ok((I64GeS, i + 1))
    Some(0x5A) => Ok((I64GeU, i + 1))
    Some(0x5B) => Ok((F32Eq, i + 1))
    Some(0x5C) => Ok((F32Ne, i + 1))
    Some(0x5D) => Ok((F32Lt, i + 1))
    Some(0x5E) => Ok((F32Gt, i + 1))
    Some(0x5F) => Ok((F32Le, i + 1))
    Some(0x60) => Ok((F32Ge, i + 1))
    Some(0x61) => Ok((F64Eq, i + 1))
    Some(0x62) => Ok((F64Ne, i + 1))
    Some(0x63) => Ok((F64Lt, i + 1))
    Some(0x64) => Ok((F64Gt, i + 1))
    Some(0x65) => Ok((F64Le, i + 1))
    Some(0x66) => Ok((F64Ge, i + 1))
    Some(0x67) => Ok((I32Clz, i + 1))
    Some(0x68) => Ok((I32Ctz, i + 1))
    Some(0x69) => Ok((I32Popcnt, i + 1))
    Some(0x6A) => Ok((I32Add, i + 1))
    Some(0x6B) => Ok((I32Sub, i + 1))
    Some(0x6C) => Ok((I32Mul, i + 1))
    Some(0x6D) => Ok((I32DivS, i + 1))
    Some(0x6E) => Ok((I32DivU, i + 1))
    Some(0x6F) => Ok((I32RemS, i + 1))
    Some(0x70) => Ok((I32RemU, i + 1))
    Some(0x71) => Ok((I32And, i + 1))
    Some(0x72) => Ok((I32Or, i + 1))
    Some(0x73) => Ok((I32Xor, i + 1))
    Some(0x74) => Ok((I32Shl, i + 1))
    Some(0x75) => Ok((I32ShrS, i + 1))
    Some(0x76) => Ok((I32ShrU, i + 1))
    Some(0x77) => Ok((I32Rotl, i + 1))
    Some(0x78) => Ok((I32Rotr, i + 1))
    Some(0x79) => Ok((I64Clz, i + 1))
    Some(0x7A) => Ok((I64Ctz, i + 1))
    Some(0x7B) => Ok((I64Popcnt, i + 1))
    Some(0x7C) => Ok((I64Add, i + 1))
    Some(0x7D) => Ok((I64Sub, i + 1))
    Some(0x7E) => Ok((I64Mul, i + 1))
    Some(0x7F) => Ok((I64DivS, i + 1))
    Some(0x80) => Ok((I64DivU, i + 1))
    Some(0x81) => Ok((I64RemS, i + 1))
    Some(0x82) => Ok((I64RemU, i + 1))
    Some(0x83) => Ok((I64And, i + 1))
    Some(0x84) => Ok((I64Or, i + 1))
    Some(0x85) => Ok((I64Xor, i + 1))
    Some(0x86) => Ok((I64Shl, i + 1))
    Some(0x87) => Ok((I64ShrS, i + 1))
    Some(0x88) => Ok((I64ShrU, i + 1))
    Some(0x89) => Ok((I64Rotl, i + 1))
    Some(0x8A) => Ok((I64Rotr, i + 1))
    Some(0x8B) => Ok((F32Abs, i + 1))
    Some(0x8C) => Ok((F32Neg, i + 1))
    Some(0x8D) => Ok((F32Ceil, i + 1))
    Some(0x8E) => Ok((F32Floor, i + 1))
    Some(0x8F) => Ok((F32Trunc, i + 1))
    Some(0x90) => Ok((F32Nearest, i + 1))
    Some(0x91) => Ok((F32Sqrt, i + 1))
    Some(0x92) => Ok((F32Add, i + 1))
    Some(0x93) => Ok((F32Sub, i + 1))
    Some(0x94) => Ok((F32Mul, i + 1))
    Some(0x95) => Ok((F32Div, i + 1))
    Some(0x96) => Ok((F32Min, i + 1))
    Some(0x97) => Ok((F32Max, i + 1))
    Some(0x98) => Ok((F32Copysign, i + 1))
    Some(0x99) => Ok((F64Abs, i + 1))
    Some(0x9A) => Ok((F64Neg, i + 1))
    Some(0x9B) => Ok((F64Ceil, i + 1))
    Some(0x9C) => Ok((F64Floor, i + 1))
    Some(0x9D) => Ok((F64Trunc, i + 1))
    Some(0x9E) => Ok((F64Nearest, i + 1))
    Some(0x9F) => Ok((F64Sqrt, i + 1))
    Some(0xA0) => Ok((F64Add, i + 1))
    Some(0xA1) => Ok((F64Sub, i + 1))
    Some(0xA2) => Ok((F64Mul, i + 1))
    Some(0xA3) => Ok((F64Div, i + 1))
    Some(0xA4) => Ok((F64Min, i + 1))
    Some(0xA5) => Ok((F64Max, i + 1))
    Some(0xA6) => Ok((F64Copysign, i + 1))
    Some(0xA7) => Ok((I32WrapI64, i + 1))
    Some(0xA8) => Ok((I32TruncF32S, i + 1))
    Some(0xA9) => Ok((I32TruncF32U, i + 1))
    Some(0xAA) => Ok((I32TruncF64S, i + 1))
    Some(0xAB) => Ok((I32TruncF64U, i + 1))
    Some(0xAC) => Ok((I64ExtendI32S, i + 1))
    Some(0xAD) => Ok((I64ExtendI32U, i + 1))
    Some(0xAE) => Ok((I64TruncF32S, i + 1))
    Some(0xAF) => Ok((I64TruncF32U, i + 1))
    Some(0xB0) => Ok((I64TruncF64S, i + 1))
    Some(0xB1) => Ok((I64TruncF64U, i + 1))
    Some(0xB2) => Ok((F32ConvertI32S, i + 1))
    Some(0xB3) => Ok((F32ConvertI32U, i + 1))
    Some(0xB4) => Ok((F32ConvertI64S, i + 1))
    Some(0xB5) => Ok((F32ConvertI64U, i + 1))
    Some(0xB6) => Ok((F32DemoteF64, i + 1))
    Some(0xB7) => Ok((F64ConvertI32S, i + 1))
    Some(0xB8) => Ok((F64ConvertI32U, i + 1))
    Some(0xB9) => Ok((F64ConvertI64S, i + 1))
    Some(0xBA) => Ok((F64ConvertI64U, i + 1))
    Some(0xBB) => Ok((F64PromoteF32, i + 1))
    Some(0xBC) => Ok((I32ReinterpretF32, i + 1))
    Some(0xBD) => Ok((I64ReinterpretF64, i + 1))
    Some(0xBE) => Ok((F32ReinterpretI32, i + 1))
    Some(0xBF) => Ok((F64ReinterpretI64, i + 1))
    Some(0xC0) => Ok((I32Extend8S, i + 1))
    Some(0xC1) => Ok((I32Extend16S, i + 1))
    Some(0xC2) => Ok((I64Extend8S, i + 1))
    Some(0xC3) => Ok((I64Extend16S, i + 1))
    Some(0xC4) => Ok((I64Extend32S, i + 1))
    Some(0x41) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((I32Const(n), i))
        Err(t) => Err(t)
      }
    Some(0x42) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((I64Const(n), i))
        Err(t) => Err(t)
      }
    Some(0x43) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((F32Const(n), i))
        Err(t) => Err(t)
      }
    Some(0x44) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((F64Const(n), i))
        Err(t) => Err(t)
      }

    // Section: Control Flow/Aggregate 0xFB
    Some(0xFB) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((StructNew(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(1), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((StructNewDefault(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(2), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((StructGet(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(3), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((StructGetS(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(4), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((StructGetU(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(5), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((StructSet(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(6), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArrayNew(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(7), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArrayNewDefault(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(8), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((ArrayNewFixed(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(9), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((ArrayNewData(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(10), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((ArrayNewElem(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(11), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArrayGet(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(12), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArrayGetS(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(13), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArrayGetU(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(14), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArraySet(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(15), i)) => Ok((ArrayLen, i))
        Ok((@lib.U32(16), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((ArrayFill(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(17), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x1, i)) =>
              match Decode::decode(bytes, i) {
                Ok((x2, i)) => Ok((ArrayCopy(x1, x2), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(18), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x1, i)) =>
              match Decode::decode(bytes, i) {
                Ok((x2, i)) => Ok((ArrayInitData(x1, x2), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(19), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x1, i)) =>
              match Decode::decode(bytes, i) {
                Ok((x2, i)) => Ok((ArrayInitElem(x1, x2), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(20), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((RefTest(false, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(21), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((RefTest(true, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(22), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((RefCast(false, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(23), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((RefCast(true, ht), i))
            Err(t) => Err(t)
          }
        Ok((U32(24), i)) =>
          match Decode::decode(bytes, i) {
            Ok((c, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) =>
                  match Decode::decode(bytes, i) {
                    Ok((ht1, i)) =>
                      match Decode::decode(bytes, i) {
                        Ok((ht2, i)) => Ok((BrOnCast(l, c, ht1, ht2), i))
                        Err(t) => Err(t)
                      }
                    Err(t) => Err(t)
                  }
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(25), i)) =>
          match Decode::decode(bytes, i) {
            Ok((c, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) =>
                  match Decode::decode(bytes, i) {
                    Ok((ht1, i)) =>
                      match Decode::decode(bytes, i) {
                        Ok((ht2, i)) => Ok((BrOnCastFail(l, c, ht1, ht2), i))
                        Err(t) => Err(t)
                      }
                    Err(t) => Err(t)
                  }
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(26), i)) => Ok((AnyConvertExtern, i))
        Ok((U32(27), i)) => Ok((ExternConvertAny, i))
        Ok((U32(28), i)) => Ok((RefI31, i))
        Ok((U32(29), i)) => Ok((I31GetS, i))
        Ok((U32(30), i)) => Ok((I31GetU, i))
        Err(t) => Err(t)
        _ => Err("Invalid instruction")
      }

    // Section: Memory/Table/Elem
    Some(0xFC) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) => Ok((I32TruncSatF32S, i))
        Ok((U32(1), i)) => Ok((I32TruncSatF32U, i))
        Ok((U32(2), i)) => Ok((I32TruncSatF64S, i))
        Ok((U32(3), i)) => Ok((I32TruncSatF64U, i))
        Ok((U32(4), i)) => Ok((I64TruncSatF32S, i))
        Ok((U32(5), i)) => Ok((I64TruncSatF32U, i))
        Ok((U32(6), i)) => Ok((I64TruncSatF64S, i))
        Ok((U32(7), i)) => Ok((I64TruncSatF64U, i))
        Ok((U32(8), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((MemoryInit(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(9), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((DataDrop(x), i))
            Err(t) => Err(t)
          }
        Ok((U32(10), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((MemoryCopy(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(11), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((MemoryFill(x), i))
            Err(t) => Err(t)
          }
        Ok((U32(12), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((TableInit(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(13), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((ElemDrop(y), i))
            Err(t) => Err(t)
          }
        Ok((U32(14), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((TableCopy(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(15), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((TableGrow(y), i))
            Err(t) => Err(t)
          }
        Ok((U32(16), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((TableSize(y), i))
            Err(t) => Err(t)
          }
        Ok((U32(17), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((TableFill(y), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
        _ => Err("Invalid Instruction")
      }

    // Section: Vector
    Some(0xFD) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(1), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load8x8S(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(2), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load8x8U(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(3), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load16x4S(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(4), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load16x4U(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(5), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load32x2S(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(6), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load32x2U(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(7), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load8Splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(8), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load16Splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(9), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load32Splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(10), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load64Splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(11), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Store(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(12), i)) =>
          // 16 bytes const
          if bytes.length() >= i + 16 {
            Ok(
              (
                V128Const(
                  bytes.unsafe_get(i),
                  bytes.unsafe_get(i + 1),
                  bytes.unsafe_get(i + 2),
                  bytes.unsafe_get(i + 3),
                  bytes.unsafe_get(i + 4),
                  bytes.unsafe_get(i + 5),
                  bytes.unsafe_get(i + 6),
                  bytes.unsafe_get(i + 7),
                  bytes.unsafe_get(i + 8),
                  bytes.unsafe_get(i + 9),
                  bytes.unsafe_get(i + 10),
                  bytes.unsafe_get(i + 11),
                  bytes.unsafe_get(i + 12),
                  bytes.unsafe_get(i + 13),
                  bytes.unsafe_get(i + 14),
                  bytes.unsafe_get(i + 15),
                ),
                i + 16,
              ),
            )
          } else {
            Err("Invalid Instruction")
          }
        Ok((U32(13), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l0, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l1, i)) =>
                  match Decode::decode(bytes, i) {
                    Ok((l2, i)) =>
                      match Decode::decode(bytes, i) {
                        Ok((l3, i)) =>
                          match Decode::decode(bytes, i) {
                            Ok((l4, i)) =>
                              match Decode::decode(bytes, i) {
                                Ok((l5, i)) =>
                                  match Decode::decode(bytes, i) {
                                    Ok((l6, i)) =>
                                      match Decode::decode(bytes, i) {
                                        Ok((l7, i)) =>
                                          match Decode::decode(bytes, i) {
                                            Ok((l8, i)) =>
                                              match Decode::decode(bytes, i) {
                                                Ok((l9, i)) =>
                                                  match
                                                    Decode::decode(bytes, i) {
                                                    Ok((l10, i)) =>
                                                      match
                                                        Decode::decode(bytes, i) {
                                                        Ok((l11, i)) =>
                                                          match
                                                            Decode::decode(
                                                              bytes, i,
                                                            ) {
                                                            Ok((l12, i)) =>
                                                              match
                                                                Decode::decode(
                                                                  bytes, i,
                                                                ) {
                                                                Ok((l13, i)) =>
                                                                  match
                                                                    Decode::decode(
                                                                      bytes, i,
                                                                    ) {
                                                                    Ok((l14, i)) =>
                                                                      match
                                                                        Decode::decode(
                                                                          bytes,
                                                                          i,
                                                                        ) {
                                                                        Ok(
                                                                          (
                                                                            l15,
                                                                            i,
                                                                          )
                                                                        ) =>
                                                                          Ok(
                                                                            (
                                                                              I8x16Shuffle(
                                                                                l0,
                                                                                l1,
                                                                                l2,
                                                                                l3,
                                                                                l4,
                                                                                l5,
                                                                                l6,
                                                                                l7,
                                                                                l8,
                                                                                l9,
                                                                                l10,
                                                                                l11,
                                                                                l12,
                                                                                l13,
                                                                                l14,
                                                                                l15,
                                                                              ),
                                                                              i,
                                                                            ),
                                                                          )
                                                                        Err(t) =>
                                                                          Err(t)
                                                                      }
                                                                    Err(t) =>
                                                                      Err(t)
                                                                  }
                                                                Err(t) => Err(t)
                                                              }
                                                            Err(t) => Err(t)
                                                          }
                                                        Err(t) => Err(t)
                                                      }
                                                    Err(t) => Err(t)
                                                  }
                                                Err(t) => Err(t)
                                              }
                                            Err(t) => Err(t)
                                          }
                                        Err(t) => Err(t)
                                      }
                                    Err(t) => Err(t)
                                  }
                                Err(t) => Err(t)
                              }
                            Err(t) => Err(t)
                          }
                        Err(t) => Err(t)
                      }
                    Err(t) => Err(t)
                  }
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(14), i)) => Ok((I8x16Swizzle, i))
        Ok((@lib.U32(15), i)) => Ok((I8x16Splat, i))
        Ok((@lib.U32(16), i)) => Ok((I16x8Splat, i))
        Ok((@lib.U32(17), i)) => Ok((I32x4Splat, i))
        Ok((@lib.U32(18), i)) => Ok((I64x2Splat, i))
        Ok((@lib.U32(19), i)) => Ok((F32x4Splat, i))
        Ok((@lib.U32(20), i)) => Ok((F64x2Splat, i))
        Ok((@lib.U32(35), i)) => Ok((I8x16Eq, i))
        Ok((@lib.U32(36), i)) => Ok((I8x16Ne, i))
        Ok((@lib.U32(37), i)) => Ok((I8x16LtS, i))
        Ok((@lib.U32(38), i)) => Ok((I8x16LtU, i))
        Ok((@lib.U32(39), i)) => Ok((I8x16GtS, i))
        Ok((@lib.U32(40), i)) => Ok((I8x16GtU, i))
        Ok((@lib.U32(41), i)) => Ok((I8x16LeS, i))
        Ok((@lib.U32(42), i)) => Ok((I8x16LeU, i))
        Ok((@lib.U32(43), i)) => Ok((I8x16GeS, i))
        Ok((@lib.U32(44), i)) => Ok((I8x16GeU, i))
        Ok((@lib.U32(45), i)) => Ok((I16x8Eq, i))
        Ok((@lib.U32(46), i)) => Ok((I16x8Ne, i))
        Ok((@lib.U32(47), i)) => Ok((I16x8LtS, i))
        Ok((@lib.U32(48), i)) => Ok((I16x8LtU, i))
        Ok((@lib.U32(49), i)) => Ok((I16x8GtS, i))
        Ok((@lib.U32(50), i)) => Ok((I16x8GtU, i))
        Ok((@lib.U32(51), i)) => Ok((I16x8LeS, i))
        Ok((@lib.U32(52), i)) => Ok((I16x8LeU, i))
        Ok((@lib.U32(53), i)) => Ok((I16x8GeS, i))
        Ok((@lib.U32(54), i)) => Ok((I16x8GeU, i))
        Ok((@lib.U32(55), i)) => Ok((I32x4Eq, i))
        Ok((@lib.U32(56), i)) => Ok((I32x4Ne, i))
        Ok((@lib.U32(57), i)) => Ok((I32x4LtS, i))
        Ok((@lib.U32(58), i)) => Ok((I32x4LtU, i))
        Ok((@lib.U32(59), i)) => Ok((I32x4GtS, i))
        Ok((@lib.U32(60), i)) => Ok((I32x4GtU, i))
        Ok((@lib.U32(61), i)) => Ok((I32x4LeS, i))
        Ok((@lib.U32(62), i)) => Ok((I32x4LeU, i))
        Ok((@lib.U32(63), i)) => Ok((I32x4GeS, i))
        Ok((@lib.U32(64), i)) => Ok((I32x4GeU, i))
        Ok((@lib.U32(65), i)) => Ok((F32x4Eq, i))
        Ok((@lib.U32(66), i)) => Ok((F32x4Ne, i))
        Ok((@lib.U32(67), i)) => Ok((F32x4Lt, i))
        Ok((@lib.U32(68), i)) => Ok((F32x4Gt, i))
        Ok((@lib.U32(69), i)) => Ok((F32x4Le, i))
        Ok((@lib.U32(70), i)) => Ok((F32x4Ge, i))
        Ok((@lib.U32(71), i)) => Ok((F64x2Eq, i))
        Ok((@lib.U32(72), i)) => Ok((F64x2Ne, i))
        Ok((@lib.U32(73), i)) => Ok((F64x2Lt, i))
        Ok((@lib.U32(74), i)) => Ok((F64x2Gt, i))
        Ok((@lib.U32(75), i)) => Ok((F64x2Le, i))
        Ok((@lib.U32(76), i)) => Ok((F64x2Ge, i))
        Ok((@lib.U32(77), i)) => Ok((V128Not, i))
        Ok((@lib.U32(78), i)) => Ok((V128And, i))
        Ok((@lib.U32(79), i)) => Ok((V128Andnot, i))
        Ok((@lib.U32(80), i)) => Ok((V128Or, i))
        Ok((@lib.U32(81), i)) => Ok((V128Xor, i))
        Ok((@lib.U32(82), i)) => Ok((V128Bitselect, i))
        Ok((@lib.U32(83), i)) => Ok((V128AnyTrue, i))
        Ok((@lib.U32(94), i)) => Ok((F32x4DemoteF64x2Zero, i))
        Ok((@lib.U32(95), i)) => Ok((F64x2PromoteLowF32x4, i))
        Ok((@lib.U32(96), i)) => Ok((I8x16Abs, i))
        Ok((@lib.U32(97), i)) => Ok((I8x16Neg, i))
        Ok((@lib.U32(98), i)) => Ok((I8x16Popcnt, i))
        Ok((@lib.U32(99), i)) => Ok((I8x16AllTrue, i))
        Ok((@lib.U32(100), i)) => Ok((I8x16Bitmask, i))
        Ok((@lib.U32(101), i)) => Ok((I8x16NarrowI16x8S, i))
        Ok((@lib.U32(102), i)) => Ok((I8x16NarrowI16x8U, i))
        Ok((@lib.U32(103), i)) => Ok((F32x4Ceil, i))
        Ok((@lib.U32(104), i)) => Ok((F32x4Floor, i))
        Ok((@lib.U32(105), i)) => Ok((F32x4Trunc, i))
        Ok((@lib.U32(106), i)) => Ok((F32x4Nearest, i))
        Ok((@lib.U32(107), i)) => Ok((I8x16Shl, i))
        Ok((@lib.U32(108), i)) => Ok((I8x16ShrS, i))
        Ok((@lib.U32(109), i)) => Ok((I8x16ShrU, i))
        Ok((@lib.U32(110), i)) => Ok((I8x16Add, i))
        Ok((@lib.U32(111), i)) => Ok((I8x16AddSatS, i))
        Ok((@lib.U32(112), i)) => Ok((I8x16AddSatU, i))
        Ok((@lib.U32(113), i)) => Ok((I8x16Sub, i))
        Ok((@lib.U32(114), i)) => Ok((I8x16SubSatS, i))
        Ok((@lib.U32(115), i)) => Ok((I8x16SubSatU, i))
        Ok((@lib.U32(116), i)) => Ok((F64x2Ceil, i))
        Ok((@lib.U32(117), i)) => Ok((F64x2Floor, i))
        Ok((@lib.U32(118), i)) => Ok((I8x16MinS, i))
        Ok((@lib.U32(119), i)) => Ok((I8x16MinU, i))
        Ok((@lib.U32(120), i)) => Ok((I8x16MaxS, i))
        Ok((@lib.U32(121), i)) => Ok((I8x16MaxU, i))
        Ok((@lib.U32(122), i)) => Ok((F64x2Trunc, i))
        Ok((@lib.U32(123), i)) => Ok((I8x16AvgrU, i))
        Ok((@lib.U32(124), i)) => Ok((I16x8ExtaddPairwiseI8x16S, i))
        Ok((@lib.U32(125), i)) => Ok((I16x8ExtaddPairwiseI8x16U, i))
        Ok((@lib.U32(126), i)) => Ok((I32x4ExtaddPairwiseI16x8S, i))
        Ok((@lib.U32(127), i)) => Ok((I32x4ExtaddPairwiseI16x8U, i))
        Ok((@lib.U32(128), i)) => Ok((I16x8Abs, i))
        Ok((@lib.U32(129), i)) => Ok((I16x8Neg, i))
        Ok((@lib.U32(130), i)) => Ok((I16x8Q15mulrSatS, i))
        Ok((@lib.U32(131), i)) => Ok((I16x8AllTrue, i))
        Ok((@lib.U32(132), i)) => Ok((I16x8Bitmask, i))
        Ok((@lib.U32(133), i)) => Ok((I16x8NarrowI32x4S, i))
        Ok((@lib.U32(134), i)) => Ok((I16x8NarrowI32x4U, i))
        Ok((@lib.U32(135), i)) => Ok((I16x8ExtendLowI8x16S, i))
        Ok((@lib.U32(136), i)) => Ok((I16x8ExtendHighI8x16S, i))
        Ok((@lib.U32(137), i)) => Ok((I16x8ExtendLowI8x16U, i))
        Ok((@lib.U32(138), i)) => Ok((I16x8ExtendHighI8x16U, i))
        Ok((@lib.U32(139), i)) => Ok((I16x8Shl, i))
        Ok((@lib.U32(140), i)) => Ok((I16x8ShrS, i))
        Ok((@lib.U32(141), i)) => Ok((I16x8ShrU, i))
        Ok((@lib.U32(142), i)) => Ok((I16x8Add, i))
        Ok((@lib.U32(143), i)) => Ok((I16x8AddSatS, i))
        Ok((@lib.U32(144), i)) => Ok((I16x8AddSatU, i))
        Ok((@lib.U32(145), i)) => Ok((I16x8Sub, i))
        Ok((@lib.U32(146), i)) => Ok((I16x8SubSatS, i))
        Ok((@lib.U32(147), i)) => Ok((I16x8SubSatU, i))
        Ok((@lib.U32(148), i)) => Ok((F64x2Nearest, i))
        Ok((@lib.U32(149), i)) => Ok((I16x8Mul, i))
        Ok((@lib.U32(150), i)) => Ok((I16x8MinS, i))
        Ok((@lib.U32(151), i)) => Ok((I16x8MinU, i))
        Ok((@lib.U32(152), i)) => Ok((I16x8MaxS, i))
        Ok((@lib.U32(153), i)) => Ok((I16x8MaxU, i))
        Ok((@lib.U32(155), i)) => Ok((I16x8AvgrU, i))
        Ok((@lib.U32(156), i)) => Ok((I16x8ExtmulLowI8x16S, i))
        Ok((@lib.U32(157), i)) => Ok((I16x8ExtmulHighI8x16S, i))
        Ok((@lib.U32(158), i)) => Ok((I16x8ExtmulLowI8x16U, i))
        Ok((@lib.U32(159), i)) => Ok((I16x8ExtmulHighI8x16U, i))
        Ok((@lib.U32(160), i)) => Ok((I32x4Abs, i))
        Ok((@lib.U32(161), i)) => Ok((I32x4Neg, i))
        Ok((@lib.U32(163), i)) => Ok((I32x4AllTrue, i))
        Ok((@lib.U32(164), i)) => Ok((I32x4Bitmask, i))
        Ok((@lib.U32(167), i)) => Ok((I32x4ExtendLowI16x8S, i))
        Ok((@lib.U32(168), i)) => Ok((I32x4ExtendHighI16x8S, i))
        Ok((@lib.U32(169), i)) => Ok((I32x4ExtendLowI16x8U, i))
        Ok((@lib.U32(170), i)) => Ok((I32x4ExtendHighI16x8U, i))
        Ok((@lib.U32(171), i)) => Ok((I32x4Shl, i))
        Ok((@lib.U32(172), i)) => Ok((I32x4ShrS, i))
        Ok((@lib.U32(173), i)) => Ok((I32x4ShrU, i))
        Ok((@lib.U32(174), i)) => Ok((I32x4Add, i))
        Ok((@lib.U32(177), i)) => Ok((I32x4Sub, i))
        Ok((@lib.U32(181), i)) => Ok((I32x4Mul, i))
        Ok((@lib.U32(182), i)) => Ok((I32x4MinS, i))
        Ok((@lib.U32(183), i)) => Ok((I32x4MinU, i))
        Ok((@lib.U32(184), i)) => Ok((I32x4MaxS, i))
        Ok((@lib.U32(185), i)) => Ok((I32x4MaxU, i))
        Ok((@lib.U32(186), i)) => Ok((I32x4DotI16x8S, i))
        Ok((@lib.U32(188), i)) => Ok((I32x4ExtmulLowI16x8S, i))
        Ok((@lib.U32(189), i)) => Ok((I32x4ExtmulHighI16x8S, i))
        Ok((@lib.U32(190), i)) => Ok((I32x4ExtmulLowI16x8U, i))
        Ok((@lib.U32(191), i)) => Ok((I32x4ExtmulHighI16x8U, i))
        Ok((@lib.U32(192), i)) => Ok((I64x2Abs, i))
        Ok((@lib.U32(193), i)) => Ok((I64x2Neg, i))
        Ok((@lib.U32(195), i)) => Ok((I64x2AllTrue, i))
        Ok((@lib.U32(196), i)) => Ok((I64x2Bitmask, i))
        Ok((@lib.U32(199), i)) => Ok((I64x2ExtendLowI32x4S, i))
        Ok((@lib.U32(200), i)) => Ok((I64x2ExtendHighI32x4S, i))
        Ok((@lib.U32(201), i)) => Ok((I64x2ExtendLowI32x4U, i))
        Ok((@lib.U32(202), i)) => Ok((I64x2ExtendHighI32x4U, i))
        Ok((@lib.U32(203), i)) => Ok((I64x2Shl, i))
        Ok((@lib.U32(204), i)) => Ok((I64x2ShrS, i))
        Ok((@lib.U32(205), i)) => Ok((I64x2ShrU, i))
        Ok((@lib.U32(206), i)) => Ok((I64x2Add, i))
        Ok((@lib.U32(209), i)) => Ok((I64x2Sub, i))
        Ok((@lib.U32(213), i)) => Ok((I64x2Mul, i))
        Ok((@lib.U32(214), i)) => Ok((I64x2Eq, i))
        Ok((@lib.U32(215), i)) => Ok((I64x2Ne, i))
        Ok((@lib.U32(216), i)) => Ok((I64x2LtS, i))
        Ok((@lib.U32(217), i)) => Ok((I64x2GtS, i))
        Ok((@lib.U32(218), i)) => Ok((I64x2LeS, i))
        Ok((@lib.U32(219), i)) => Ok((I64x2GeS, i))
        Ok((@lib.U32(220), i)) => Ok((I64x2ExtmulLowI32x4S, i))
        Ok((@lib.U32(221), i)) => Ok((I64x2ExtmulHighI32x4S, i))
        Ok((@lib.U32(222), i)) => Ok((I64x2ExtmulLowI32x4U, i))
        Ok((@lib.U32(223), i)) => Ok((I64x2ExtmulHighI32x4U, i))
        Ok((@lib.U32(224), i)) => Ok((F32x4Abs, i))
        Ok((@lib.U32(225), i)) => Ok((F32x4Neg, i))
        Ok((@lib.U32(227), i)) => Ok((F32x4Sqrt, i))
        Ok((@lib.U32(228), i)) => Ok((F32x4Add, i))
        Ok((@lib.U32(229), i)) => Ok((F32x4Sub, i))
        Ok((@lib.U32(230), i)) => Ok((F32x4Mul, i))
        Ok((@lib.U32(231), i)) => Ok((F32x4Div, i))
        Ok((@lib.U32(232), i)) => Ok((F32x4Min, i))
        Ok((@lib.U32(233), i)) => Ok((F32x4Max, i))
        Ok((@lib.U32(234), i)) => Ok((F32x4Pmin, i))
        Ok((@lib.U32(235), i)) => Ok((F32x4Pmax, i))
        Ok((@lib.U32(236), i)) => Ok((F64x2Abs, i))
        Ok((@lib.U32(237), i)) => Ok((F64x2Neg, i))
        Ok((@lib.U32(239), i)) => Ok((F64x2Sqrt, i))
        Ok((@lib.U32(240), i)) => Ok((F64x2Add, i))
        Ok((@lib.U32(241), i)) => Ok((F64x2Sub, i))
        Ok((@lib.U32(242), i)) => Ok((F64x2Mul, i))
        Ok((@lib.U32(243), i)) => Ok((F64x2Div, i))
        Ok((@lib.U32(244), i)) => Ok((F64x2Min, i))
        Ok((@lib.U32(245), i)) => Ok((F64x2Max, i))
        Ok((@lib.U32(246), i)) => Ok((F64x2Pmin, i))
        Ok((@lib.U32(247), i)) => Ok((F64x2Pmax, i))
        Ok((@lib.U32(248), i)) => Ok((I32x4TruncSatF32x4S, i))
        Ok((@lib.U32(249), i)) => Ok((I32x4TruncSatF32x4U, i))
        Ok((@lib.U32(250), i)) => Ok((F32x4ConvertI32x4S, i))
        Ok((@lib.U32(251), i)) => Ok((F32x4ConvertI32x4U, i))
        Ok((@lib.U32(252), i)) => Ok((I32x4TruncSatF64x2SZero, i))
        Ok((@lib.U32(253), i)) => Ok((I32x4TruncSatF64x2UZero, i))
        Ok((@lib.U32(254), i)) => Ok((F64x2ConvertLowI32x4S, i))
        Ok((@lib.U32(255), i)) => Ok((F64x2ConvertLowI32x4U, i))
        Ok((@lib.U32(256), i)) => Ok((I8x16RelaxedSwizzle, i))
        Ok((@lib.U32(257), i)) => Ok((I32x4RelaxedTruncF32x4S, i))
        Ok((@lib.U32(258), i)) => Ok((I32x4RelaxedTruncF32x4U, i))
        Ok((@lib.U32(259), i)) => Ok((I32x4RelaxedTruncZeroF64x2S, i))
        Ok((@lib.U32(260), i)) => Ok((I32x4RelaxedTruncZeroF64x2U, i))
        Ok((@lib.U32(261), i)) => Ok((F32x4RelaxedMadd, i))
        Ok((@lib.U32(262), i)) => Ok((F32x4RelaxedNmadd, i))
        Ok((@lib.U32(263), i)) => Ok((F64x2RelaxedMadd, i))
        Ok((@lib.U32(264), i)) => Ok((F64x2RelaxedNmadd, i))
        Ok((@lib.U32(265), i)) => Ok((I8x16RelaxedLaneselect, i))
        Ok((@lib.U32(266), i)) => Ok((I16x8RelaxedLaneselect, i))
        Ok((@lib.U32(267), i)) => Ok((I32x4RelaxedLaneselect, i))
        Ok((@lib.U32(268), i)) => Ok((I64x2RelaxedLaneselect, i))
        Ok((@lib.U32(269), i)) => Ok((F32x4RelaxedMin, i))
        Ok((@lib.U32(270), i)) => Ok((F32x4RelaxedMax, i))
        Ok((@lib.U32(271), i)) => Ok((F64x2RelaxedMin, i))
        Ok((@lib.U32(272), i)) => Ok((F64x2RelaxedMax, i))
        Ok((@lib.U32(273), i)) => Ok((I16x8RelaxedQ15mulrS, i))
        Ok((@lib.U32(274), i)) => Ok((I16x8RelaxedDotI8x16I7x16S, i))
        Ok((@lib.U32(275), i)) => Ok((I32x4RelaxedDotI8x16I7x16AddS, i))
        Ok((@lib.U32(21), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I8x16ExtractLaneS(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(22), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I8x16ExtractLaneU(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(23), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I8x16ReplaceLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(24), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I16x8ExtractLaneS(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(25), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I16x8ExtractLaneU(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(26), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I16x8ReplaceLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(27), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I32x4ExtractLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(28), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I32x4ReplaceLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(29), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I64x2ExtractLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(30), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((I64x2ReplaceLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(31), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((F32x4ExtractLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(32), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((F32x4ReplaceLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(33), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((F64x2ExtractLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(34), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((F64x2ReplaceLane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(84), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Load8Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(85), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Load16Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(86), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Load32Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(87), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Load64Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(88), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Store8Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(89), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Store16Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(90), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Store32Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(91), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((V128Store64Lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(92), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load32Zero(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(93), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((V128Load64Zero(m), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
        _ => Err("Invalid Instruction")
      }
    _ => Err("Invalid Instruction")
  }
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

///|
pub impl[T : Decode] Decode for Array[T] with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Err(t) => Err(t)
    Ok((@lib.U32(count), i)) =>
      loop (count, [], i) {
        (0, result, i) => break Ok((result, i))
        (n, result, i) =>
          match T::decode(bytes, i) {
            Ok((t, i)) => {
              result.push(t)
              continue (n - 1, result, i)
            }
            Err(t) => break Err(t)
          }
      }
  }
}

// For tests:

///|
priv suberror EncodingFailed

///|
priv suberror DecodingFailed

///|
fn[T : Encode + Decode + Eq + Show] roundtrip(x : T) -> Unit raise {
  let buf = @buffer.new()
  match Encode::encode(x, buf) {
    Ok(_) => ()
    Err(t) => {
      println(("Encoding failed", t))
      raise EncodingFailed
    }
  }
  let bytes = buf.to_bytes()
  let (y, i2) = match Decode::decode(bytes, 0) {
    Ok(t) => t
    Err(t) => {
      println(("Decoding failed", t, "for", x))
      println(("Bytes", bytes.to_array()))
      raise DecodingFailed
    }
  }
  if bytes.length() != i2 {
    println(("Failed: Byte Length Mismatch", bytes.length(), i2))
  }
  if y != x {
    println(("Failed", x))
    println(("Byte Representation", bytes.to_array()))
    let compare = @buffer.new()
    match Encode::encode(y, compare) {
      Ok(_) =>
        println(("Decoded byte representation", compare.to_bytes().to_array()))
      Err(_) => println("Could not re-encode actual value")
    }
    println(("Decoded", y))
  }
  assert_eq(i2, bytes.length())
  assert_eq(y, x)
}

///|
fn[T : Encode + Decode + Eq + Show + @quickcheck.Arbitrary] roundtrip_arbitrary(
  count : Int,
) -> Array[T] raise {
  let st = @quickcheck/splitmix.new()
  let a = Array::new(capacity=count)
  loop count {
    0 => break a
    n => {
      let val = T::arbitrary(n, st)
      roundtrip(val)
      a.push(val)
      continue n - 1
    }
  }
}

///|
test "uleb roundtrip u33" {
  let vals : Array[UInt64] = [0, 1, 127, 128, 129, 0xffff, 0xffffffff]
  for v in vals {
    let buf = @buffer.new()
    encode_unsigned(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_unsigned(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "sleb roundtrip s33 boundary" {
  let vals : Array[Int64] = [
    0, 1, -1, 63, -64, 64, -65, 2147483647, -2147483648,
  ]
  for v in vals {
    let buf = @buffer.new()
    encode_signed(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_signed(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "uleb u33 rejects terminal unused bits" {
  let bytes : Bytes = [0x80, 0x80, 0x80, 0x80, 0x20]
  match decode_unsigned(bytes, 0, 33) {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

///|
test "sleb s33 accepts 0x3f" {
  match decode_signed(b"\x3f", 0, 33) {
    Ok((value, _)) => assert_eq(value, 63L)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "uleb u33 rejects too many bytes" {
  let bytes : Bytes = [0x80, 0x80, 0x80, 0x80, 0x80, 0x00]
  match decode_unsigned(bytes, 0, 33) {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

///|
test "uleb allows trailing zeros within max bytes" {
  let bytes : Bytes = [0x83, 0x00]
  let (v, i) = decode_unsigned(bytes, 0, 8).unwrap()
  assert_eq(v, 3)
  assert_eq(i, 2)
}

///|
test "uleb u33 boundaries roundtrip" {
  let vals : Array[UInt64] = [
    0UL,
    1UL,
    31UL,
    32UL,
    127UL,
    128UL,
    0xffffffffUL,
    (1UL << 33) - 1UL,
  ]
  for v in vals {
    let buf = @buffer.new()
    encode_unsigned(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_unsigned(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "uleb allows trailing zeros within bound" {
  let (v, i) = decode_unsigned(b"\x83\x00", 0, 8).unwrap()
  assert_eq(v, 3UL)
  assert_eq(i, 2)
}

///|
test "sleb s33 boundaries roundtrip" {
  let min = -1L << 32
  let max = (1L << 32) - 1L
  let vals : Array[Int64] = [
    min,
    min + 1,
    -1,
    0,
    1,
    31,
    32,
    63,
    64,
    max - 1,
    max,
  ]
  for v in vals {
    let buf = @buffer.new()
    encode_signed(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_signed(bytes, 0, 33).unwrap()
    assert_eq(v2, v)
    assert_eq(i2, bytes.length())
  }
}

///|
test "sleb s33 rejects too many bytes" {
  match decode_signed(b"\x80\x80\x80\x80\x80\x00", 0, 33) {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

///|
test "sleb allows extra sign extension within bound" {
  let (v, i) = decode_signed(b"\xff\x7f", 0, 8).unwrap()
  assert_eq(v, -1)
  assert_eq(i, 2)
}

///|
test "uleb encoder never exceeds ceil(nbits/7)" {
  let buf = @buffer.new()
  encode_unsigned((1UL << 33) - 1UL, buf, 33).unwrap()
  assert_true(buf.to_bytes().length() <= max_leb_bytes(33))
}

///|
test "numtype valtype" {
  roundtrip(@lib.F32NumType)
  roundtrip(@lib.F64NumType)
  roundtrip(@lib.I32NumType)
  roundtrip(@lib.I64NumType)
}

///|
test "Heap Types" {
  roundtrip(@lib.AbsHeapTypeHeapType(ExnAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(ArrayAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(StructAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(I31AbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(EqAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(AnyAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(ExternAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(FuncAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(NoneAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(NoExternAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(NoFuncAbsHeapType))
  roundtrip(@lib.AbsHeapTypeHeapType(NoExnAbsHeapType))
  roundtrip(@lib.HeapType(TypeIdx(23)))
}

///|
test "Type Indexes" {
  let _ : Array[TypeIdx] = roundtrip_arbitrary(50)

}

///|
test "Ref Types" {
  let _ : Array[RefType] = roundtrip_arbitrary(20)

}

///|
test "Comp Types" {
  roundtrip(
    @lib.ArrayCompType(
      FieldType(ValTypeStorageType(NumTypeValType(I32NumType)), Var),
    ),
  )
  roundtrip(
    @lib.StructCompType([
      FieldType(
        ValTypeStorageType(
          RefTypeValType(
            HeapTypeRefType(true, AbsHeapTypeHeapType(I31AbsHeapType)),
          ),
        ),
        Var,
      ),
    ]),
  )
  roundtrip(
    @lib.FuncCompType([i32_valtype(), i64_valtype()], [
      i64_valtype(),
      i32_valtype(),
    ]),
  )
  let _ : Array[CompType] = roundtrip_arbitrary(30)

}

///|
test "Storage Type" {
  let _ : Array[StorageType] = roundtrip_arbitrary(30)

}

///|
test "Packed Type" {
  roundtrip(@lib.I8PackType)
  roundtrip(@lib.I16PackType)
}

///|
test "SubTypes" {
  roundtrip(
    @lib.CompTypeSubType(
      ArrayCompType(FieldType(ValTypeStorageType(i32_valtype()), Var)),
    ),
  )
  roundtrip(
    @lib.SubType(
      false,
      [TypeIdx(0), TypeIdx(2), TypeIdx(4)],
      FuncCompType([], []),
    ),
  )
}

///|
test "SubTypes arbitrary" {
  let _ : Array[SubType] = roundtrip_arbitrary(100)

}

///|
test "RecTypes arbitrary" {
  let _ : Array[RecType] = roundtrip_arbitrary(100)

}

///|
test "TagTypes arbitrary" {
  let _ : Array[TagType] = roundtrip_arbitrary(100)

}

///|
test "MemTypes arbitrary" {
  let _ : Array[MemType] = roundtrip_arbitrary(100)

}

///|
test "TableTypes arbitrary" {
  let _ : Array[TableType] = roundtrip_arbitrary(100)

}

///|
test "ExternTypes arbitrary" {
  let _ : Array[TableType] = roundtrip_arbitrary(100)

}

///|
test "MemArg arbitrary" {
  let _ : Array[MemArg] = roundtrip_arbitrary(100)

}

///|
test "LaneIdx" {
  let _ : Array[LaneIdx] = roundtrip_arbitrary(100)

}

///|
test "Float specific edge case?" {
  roundtrip(@lib.F32Const(F32(0.011397957801818848)))
}

///|
test "Floats arbitrary" {
  let _ : Array[F32] = roundtrip_arbitrary(10000)

}

///|
test "Doubles arbitrary" {
  let _ : Array[F64] = roundtrip_arbitrary(10000)

}

///|
test "Signed integers" {
  let _ : Array[I64] = roundtrip_arbitrary(100000)

}

///|
test "Block Types" {
  let _ : Array[BlockType] = roundtrip_arbitrary(1000)

}

///|
test "Instructions arbitrary" {
  let st = @quickcheck/splitmix.new()
  loop 1000000 {
    0 => break ()
    n => {
      let val = Instruction::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary CustomSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = CustomSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary TypeSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = TypeSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary ImportSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = ImportSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary FuncSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = FuncSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary TableSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = TableSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary MemSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = MemSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary GlobalSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = GlobalSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary ExportSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = ExportSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary StartSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = StartSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Elem" {
  let st = @quickcheck/splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Elem::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary ElemSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = ElemSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Func" {
  let st = @quickcheck/splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Func::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary CodeSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = CodeSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Data" {
  let st = @quickcheck/splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Data::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary DataSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = DataSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary DataCntSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = DataCntSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary TagSec" {
  let st = @quickcheck/splitmix.new()
  loop 100 {
    0 => break ()
    n => {
      let val = TagSec::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Arbitrary Module" {
  let st = @quickcheck/splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Module::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}

///|
test "Names" {
  let st = @quickcheck/splitmix.new()
  loop 1000 {
    0 => break ()
    n => {
      let val = Name::arbitrary(n, st)
      roundtrip(val)
      continue n - 1
    }
  }
}
