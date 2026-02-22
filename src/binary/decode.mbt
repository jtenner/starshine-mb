///|
pub suberror BinaryDecodeError {
  IndexOutOfBounds
  InvalidNumTypeByte
  InvalidAbstractHeapType
  InvalidValType
  InvalidCompType
  UnexpectedEofDecodingMut
  InvalidMutByte
  InvalidStorageType
  InvalidPackedType
  InvalidUnsignedLebBitWidth
  UnexpectedEofInUnsignedLeb
  UnsignedLebTooManyBytes
  UnsignedLebOutOfRangeForBitWidth
  UnsignedLebTerminalHasNonZeroUnusedBits
  UnreachableDecodeState
  InvalidSignedLebBitWidth
  UnexpectedEofInSignedLeb
  SignedLebTooManyBytes
  SignedLebOutOfRangeForBitWidth
  SignedLebPositiveTerminalHasNonZeroUnusedBits
  SignedLebTerminalHasWrongSignExtensionBits
  InvalidS33Range
  InvalidBoolByte
  InvalidLaneIndex
  NegativeNameLength
  InvalidSectionHeader
  SectionPayloadLengthOutOfRange
  InvalidSectionPayloadTrailingBytes
  InvalidMagicHeader
  InvalidModule
  InvalidElemHeader
  InvalidDataHeader
  CustomSectionPayloadLengthOutOfRange
  InvalidLimits
  InvalidTagType
  InvalidExternTypeHeader
  InvalidBlockType
  InvalidExternIndex
  InvalidOffset
  InvalidCatch
  InvalidCastOp
  InvalidMemArg
  InvalidInstruction
  InvalidAtomicFenceImmediate
  InvalidAtomicInstruction
} derive(Eq, Show, Debug)

///|
pub trait Decode {
  decode(Bytes, Int) -> Result[(Self, Int), BinaryDecodeError]
}

///|
pub impl Decode for NumType with decode(buf, idx) {
  match buf.get(idx) {
    Some(0x7C) => Ok((NumType::f64(), idx + 1))
    Some(0x7D) => Ok((NumType::f32(), idx + 1))
    Some(0x7E) => Ok((NumType::i64(), idx + 1))
    Some(0x7F) => Ok((NumType::i32(), idx + 1))
    Some(_) => Err(BinaryDecodeError::InvalidNumTypeByte)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for HeapType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((abs, i)) => Ok((HeapType::abs(abs), i))
    Err(_) =>
      match Decode::decode(bytes, i) {
        Ok((@lib.S33(s), i)) => Ok((HeapType::new(TypeIdx::new(s)), i))
        Err(err) => Err(err)
      }
  }
}

///|
pub impl Decode for AbsHeapType with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x69) => Ok((AbsHeapType::exn(), i + 1))
    Some(0x6A) => Ok((AbsHeapType::array(), i + 1))
    Some(0x6B) => Ok((AbsHeapType::struct_(), i + 1))
    Some(0x6C) => Ok((AbsHeapType::i31(), i + 1))
    Some(0x6D) => Ok((AbsHeapType::eq(), i + 1))
    Some(0x6E) => Ok((AbsHeapType::any(), i + 1))
    Some(0x6F) => Ok((AbsHeapType::extern_(), i + 1))
    Some(0x70) => Ok((AbsHeapType::func(), i + 1))
    Some(0x71) => Ok((AbsHeapType::none(), i + 1))
    Some(0x72) => Ok((AbsHeapType::no_extern(), i + 1))
    Some(0x73) => Ok((AbsHeapType::no_func(), i + 1))
    Some(0x74) => Ok((AbsHeapType::no_exn(), i + 1))
    Some(_) => Err(BinaryDecodeError::InvalidAbstractHeapType)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for RefType with decode(bytes, i) {
  match bytes.get(i) {
    None => Err(BinaryDecodeError::IndexOutOfBounds)
    Some(0x63) =>
      match Decode::decode(bytes, i + 1) {
        Err(err) => Err(err)
        Ok((ht, i)) => Ok((RefType::new(true, ht), i))
      }
    Some(0x64) =>
      match Decode::decode(bytes, i + 1) {
        Err(err) => Err(err)
        Ok((ht, i)) => Ok((RefType::new(false, ht), i))
      }
    Some(_) =>
      match Decode::decode(bytes, i) {
        Err(err) => Err(err)
        Ok((abs, i)) => Ok((RefType::abs(abs), i))
      }
  }
}

///|
pub impl Decode for ValType with decode(bytes, i) {
  match bytes.get(i) {
    None => Err(BinaryDecodeError::IndexOutOfBounds)
    Some(0x7B) => Ok((ValType::v128(), i + 1))
    Some(_) =>
      match Decode::decode(bytes, i) {
        Ok((t, i)) => Ok((ValType::num_type(t), i))
        _ =>
          match Decode::decode(bytes, i) {
            Ok((rt, i)) => Ok((ValType::ref_type(rt), i))
            _ => Err(BinaryDecodeError::InvalidValType)
          }
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
pub impl Decode for CompType with decode(bytes, i) {
  match bytes.get(i) {
    None => Err(BinaryDecodeError::IndexOutOfBounds)
    Some(0x5E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((ft, i)) => Ok((CompType::array(ft), i))
        Err(err) => Err(err)
      }
    Some(0x5F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((fts, i)) => Ok((CompType::struct_(fts), i))
        Err(err) => Err(err)
      }
    Some(0x60) =>
      match Decode::decode(bytes, i + 1) {
        Ok((props, i)) =>
          match Decode::decode(bytes, i) {
            Ok((rets, i)) => Ok((CompType::func(props, rets), i))
            Err(err) => Err(err)
          }
        Err(err) => Err(err)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompType)
  }
}

///|
pub impl Decode for Mut with decode(bytes, i) {
  if i >= bytes.length() {
    return Err(BinaryDecodeError::UnexpectedEofDecodingMut)
  }
  let b = bytes[i]
  match b {
    0x00 => Ok((Const, i + 1))
    0x01 => Ok((Var, i + 1))
    _ => Err(BinaryDecodeError::InvalidMutByte)
  }
}

///|
pub impl Decode for StorageType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((vt, i)) => Ok((StorageType::val_type(vt), i))
    Err(_) =>
      match Decode::decode(bytes, i) {
        Ok((pt, i)) => Ok((StorageType::pack_type(pt), i))
        Err(_) => Err(BinaryDecodeError::InvalidStorageType)
      }
  }
}

///|
pub impl Decode for PackType with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x77) => Ok((PackType::i16(), i + 1))
    Some(0x78) => Ok((PackType::i8(), i + 1))
    Some(_) => Err(BinaryDecodeError::InvalidPackedType)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for RecType with decode(buf, i) {
  match buf.get(i) {
    None => Err(BinaryDecodeError::IndexOutOfBounds)
    Some(0x4E) =>
      match Decode::decode(buf, i + 1) {
        Ok((sts, i)) => Ok((RecType::group(sts), i))
        Err(err) => Err(err)
      }
    Some(_) =>
      match Decode::decode(buf, i) {
        Ok((st, i)) => Ok((RecType::new(st), i))
        Err(err) => Err(err)
      }
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
            Ok((ct, i)) => Ok((SubType::new(true, idxs, ct), i))
            Err(err) => Err(err)
          }
        Err(err) => Err(err)
      }
    // Subtypes
    Some(0x50) =>
      match Decode::decode(buf, i + 1) {
        Ok((idxs, i)) =>
          match Decode::decode(buf, i) {
            Ok((ct, i)) => Ok((SubType::new(false, idxs, ct), i))
            Err(err) => Err(err)
          }
        Err(err) => Err(err)
      }
    // CompType, defer to comp type decoder
    Some(_) =>
      match Decode::decode(buf, i) {
        Ok((ct, i)) => Ok((SubType::comp_type(ct), i))
        Err(err) => Err(err)
      }
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
fn decode_unsigned(
  bytes : Bytes,
  index : Int,
  nbits : Int,
) -> Result[(UInt64, Int), BinaryDecodeError] {
  if nbits <= 0 || nbits > 64 {
    return Err(BinaryDecodeError::InvalidUnsignedLebBitWidth)
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut i = index
  let mut shift = 0
  let mut acc : UInt64 = 0UL
  let mut count = 0
  while true {
    if i >= bytes.length() {
      return Err(BinaryDecodeError::UnexpectedEofInUnsignedLeb)
    }
    if count >= max_bytes {
      return Err(BinaryDecodeError::UnsignedLebTooManyBytes)
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
          return Err(BinaryDecodeError::UnsignedLebOutOfRangeForBitWidth)
        }
      }

      // terminal unused bits constraint - ONLY at max bytes
      if count == max_bytes {
        let rem = nbits % 7
        if rem != 0 {
          let limit = 1UL << rem
          if payload >= limit {
            return Err(
              BinaryDecodeError::UnsignedLebTerminalHasNonZeroUnusedBits,
            )
          }
        }
      }
      return Ok((acc, i))
    }
  }
  Err(BinaryDecodeError::UnreachableDecodeState)
}

///|
fn decode_signed(
  bytes : Bytes,
  index : Int,
  nbits : Int,
) -> Result[(Int64, Int), BinaryDecodeError] {
  if nbits <= 0 || nbits > 64 {
    return Err(BinaryDecodeError::InvalidSignedLebBitWidth)
  }
  let max_bytes = max_leb_bytes(nbits)
  let mut i = index
  let mut shift = 0
  let mut acc : Int64 = 0
  let mut count = 0
  let mut last_byte : UInt64 = 0
  while true {
    if i >= bytes.length() {
      return Err(BinaryDecodeError::UnexpectedEofInSignedLeb)
    }
    if count >= max_bytes {
      return Err(BinaryDecodeError::SignedLebTooManyBytes)
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
      return Err(BinaryDecodeError::SignedLebOutOfRangeForBitWidth)
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
          return Err(
            BinaryDecodeError::SignedLebPositiveTerminalHasNonZeroUnusedBits,
          )
        }
      } else {
        let want = inv_used
        if unused != want {
          return Err(
            BinaryDecodeError::SignedLebTerminalHasWrongSignExtensionBits,
          )
        }
      }
    }
  }
  Ok((acc, i))
}

///|
pub impl Decode for S33 with decode(bytes, i) {
  match decode_signed(bytes, i, 33) {
    Err(err) => Err(err)
    Ok((val, i)) if val >= 0 && val <= 4294967295 =>
      Ok((S33(val.to_int().reinterpret_as_uint()), i))
    Ok(_) => Err(BinaryDecodeError::InvalidS33Range)
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
    Err(BinaryDecodeError::IndexOutOfBounds)
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
    Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for Bool with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) => Ok((false, i + 1))
    Some(0x01) => Ok((true, i + 1))
    Some(_) => Err(BinaryDecodeError::InvalidBoolByte)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
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
pub impl Decode for TypeIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((TypeIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for FuncIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((FuncIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for TableIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((TableIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for MemIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((MemIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for GlobalIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((GlobalIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for TagIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((TagIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for ElemIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((ElemIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for DataIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((DataIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for LocalIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((LocalIdx::new(n.to_uint()), i))
  }
}

///|
pub impl Decode for LaneIdx with decode(bytes, i) {
  if bytes.get(i) is Some(n) && n < 16 {
    Ok((LaneIdx::new(n), i + 1))
  } else {
    Err(BinaryDecodeError::InvalidLaneIndex)
  }
}

///|
pub impl Decode for LabelIdx with decode(bytes, i) {
  match decode_unsigned(bytes, i, 32) {
    Err(t) => Err(t)
    Ok((n, i)) => Ok((LabelIdx::new(n.to_uint()), i))
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
    return Err(BinaryDecodeError::NegativeNameLength)
  }
  let end = j + len
  if end > bytes.length() {
    return Err(BinaryDecodeError::IndexOutOfBounds)
  }
  let name = @utf8.decode_lossy(bytes[j:end]).to_string_view()
  Ok((Name::new(name), end))
}

///|
fn[T : Decode] decode_section_vector_payload(
  bytes : Bytes,
  i : Int,
  section_id : Byte,
) -> Result[(Array[T], Int), BinaryDecodeError] {
  if bytes.get(i) != Some(section_id) {
    return Err(BinaryDecodeError::InvalidSectionHeader)
  }
  let (@lib.U32(len_u), payload_start) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len_u.reinterpret_as_int()
  let payload_end = payload_start + len
  if payload_end > bytes.length() {
    return Err(BinaryDecodeError::SectionPayloadLengthOutOfRange)
  }
  let payload = bytes[payload_start:payload_end].to_bytes()
  let (content, consumed) = match Decode::decode(payload, 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  if consumed == len {
    Ok((content, payload_end))
  } else {
    Err(BinaryDecodeError::InvalidSectionPayloadTrailingBytes)
  }
}

///|
fn decode_custom_sections(
  bytes : Bytes,
  i : Int,
  out : Array[CustomSec],
) -> Result[Int, BinaryDecodeError] {
  let mut i = i
  while bytes.get(i) == Some(0) {
    match Decode::decode(bytes, i) {
      Ok((sec, next)) => {
        out.push(sec)
        i = next
      }
      Err(t) => return Err(t)
    }
  }
  Ok(i)
}

///|
fn[T : Decode] decode_optional_section(
  bytes : Bytes,
  i : Int,
  section_id : Byte,
) -> Result[(T?, Int), BinaryDecodeError] {
  if bytes.get(i) != Some(section_id) {
    return Ok((None, i))
  }
  match Decode::decode(bytes, i) {
    Ok((sec, next)) => Ok((Some(sec), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Module with decode(bytes, i) {
  let mut i = i
  let custom = Array::new()
  let mut mod = Module::new()
  for b in [0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00] {
    if bytes.get(i) != Some(b.to_byte()) {
      return Err(BinaryDecodeError::InvalidMagicHeader)
    }
    i = i + 1
  }
  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (type_sec, next) = match decode_optional_section(bytes, i, 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if type_sec is Some(sec) {
    mod = mod.with_type_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (import_sec, next) = match decode_optional_section(bytes, i, 2) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if import_sec is Some(sec) {
    mod = mod.with_import_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (func_sec, next) = match decode_optional_section(bytes, i, 3) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if func_sec is Some(sec) {
    mod = mod.with_func_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (table_sec, next) = match decode_optional_section(bytes, i, 4) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if table_sec is Some(sec) {
    mod = mod.with_table_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (mem_sec, next) = match decode_optional_section(bytes, i, 5) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if mem_sec is Some(sec) {
    mod = mod.with_mem_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (tag_sec, next) = match decode_optional_section(bytes, i, 13) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if tag_sec is Some(sec) {
    mod = mod.with_tag_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (global_sec, next) = match decode_optional_section(bytes, i, 6) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if global_sec is Some(sec) {
    mod = mod.with_global_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (export_sec, next) = match decode_optional_section(bytes, i, 7) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if export_sec is Some(sec) {
    mod = mod.with_export_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (start_sec, next) = match decode_optional_section(bytes, i, 8) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if start_sec is Some(sec) {
    mod = mod.with_start_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (elem_sec, next) = match decode_optional_section(bytes, i, 9) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if elem_sec is Some(sec) {
    mod = mod.with_elem_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (data_cnt_sec, next) = match decode_optional_section(bytes, i, 12) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if data_cnt_sec is Some(sec) {
    mod = mod.with_data_cnt_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (code_sec, next) = match decode_optional_section(bytes, i, 10) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if code_sec is Some(sec) {
    mod = mod.with_code_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }
  let (data_sec, next) = match decode_optional_section(bytes, i, 11) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  i = next
  if data_sec is Some(sec) {
    mod = mod.with_data_sec(sec)
  }

  i = match decode_custom_sections(bytes, i, custom) {
    Ok(next) => next
    Err(t) => return Err(t)
  }

  mod = mod.with_custom_secs(custom)
  if i == bytes.length() {
    Ok((mod, i))
  } else {
    Err(BinaryDecodeError::InvalidModule)
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
              Ok(
                (
                  Elem::new(
                    ElemMode::active(TableIdx::new(0), expr),
                    ElemKind::funcs(fidxs),
                  ),
                  i,
                ),
              )
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match bytes.get(i + 1) {
        Some(0x00) =>
          match Decode::decode(bytes, i + 2) {
            Ok((fidxs, i)) =>
              Ok((Elem::new(ElemMode::passive(), ElemKind::funcs(fidxs)), i))
            Err(t) => Err(t)
          }
        _ => Err(BinaryDecodeError::InvalidElemHeader)
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
                          Elem::new(
                            ElemMode::active(TableIdx::new(idx), expr),
                            ElemKind::funcs(fidxs),
                          ),
                          i,
                        ),
                      )
                    Err(t) => Err(t)
                  }
                _ => Err(BinaryDecodeError::InvalidElemHeader)
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match bytes.get(i + 1) {
        Some(0x00) =>
          match Decode::decode(bytes, i + 2) {
            Ok((fidxs, i)) =>
              Ok(
                (Elem::new(ElemMode::declarative(), ElemKind::funcs(fidxs)), i),
              )
            Err(t) => Err(t)
          }
        _ => Err(BinaryDecodeError::InvalidElemHeader)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((expr, i)) =>
          match Decode::decode(bytes, i) {
            Ok((exprs, i)) =>
              Ok(
                (
                  Elem::new(
                    ElemMode::active(TableIdx::new(0), expr),
                    ElemKind::func_exprs(exprs),
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
              Ok(
                (
                  Elem::new(
                    ElemMode::passive(),
                    ElemKind::typed_exprs(rt, exprs),
                  ),
                  i,
                ),
              )
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
                      Elem::new(
                        ElemMode::active(idx, expr),
                        ElemKind::func_exprs(exprs),
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
              Ok(
                (
                  Elem::new(
                    ElemMode::declarative(),
                    ElemKind::typed_exprs(rt, exprs),
                  ),
                  i,
                ),
              )
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(_) => Err(BinaryDecodeError::InvalidElemHeader)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for ElemSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 9) {
    Ok((content, next)) => Ok((ElemSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for DataCntSec with decode(bytes, i) {
  if bytes.get(i) != Some(12) {
    return Err(BinaryDecodeError::InvalidSectionHeader)
  }
  match Decode::decode(bytes, i + 1) {
    Ok((@lib.U32(count), i)) => Ok((DataCntSec::new(count), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Locals with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((@lib.U32(count), i)) =>
      match Decode::decode(bytes, i) {
        Ok((vt, i)) => Ok((Locals::new(count, vt), i))
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
            Ok((expr, i)) => Ok((Func::new(locals, expr), i))
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
    return Err(BinaryDecodeError::InvalidSectionHeader)
  }
  match Decode::decode(bytes, i + 1) {
    Ok((funcs, i)) => Ok((CodeSec::new(funcs), i))
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
              Ok((Data::new(DataMode::active(MemIdx::new(0), expr), bytes), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bytes, i)) => Ok((Data::new(DataMode::passive(), bytes), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) =>
              match Decode::decode(bytes, i) {
                Ok((bytes, i)) =>
                  Ok((Data::new(DataMode::active(idx, expr), bytes), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(_) => Err(BinaryDecodeError::InvalidDataHeader)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for DataSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 11) {
    Ok((content, next)) => Ok((DataSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for CustomSec with decode(bytes, i) {
  if bytes.get(i) != Some(0) {
    return Err(BinaryDecodeError::InvalidSectionHeader)
  }
  let (@lib.U32(len), i1) = match Decode::decode(bytes, i + 1) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let len = len.reinterpret_as_int()
  let end = i1 + len
  if end > bytes.length() {
    return Err(BinaryDecodeError::CustomSectionPayloadLengthOutOfRange)
  }
  let view = bytes[i1:end].to_bytes()
  let (name, j) = match Decode::decode(view, 0) {
    Ok(t) => t
    Err(t) => return Err(t)
  }
  let bytes = view[j:].to_bytes()
  Ok((CustomSec::new(name, bytes), end))
}

///|
pub impl Decode for TypeSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 1) {
    Ok((content, next)) => Ok((TypeSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for Import with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((nm1, i)) =>
      match Decode::decode(bytes, i) {
        Ok((nm2, i)) =>
          match Decode::decode(bytes, i) {
            Ok((et, i)) => Ok((Import::new(nm1, nm2, et), i))
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
    None => Err(BinaryDecodeError::IndexOutOfBounds)
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) => Ok((Limits::i32(n.to_uint(), None), i))
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) =>
          match Decode::decode(bytes, i) {
            Ok((@lib.U64(m), i)) =>
              Ok((Limits::i32(n.to_uint(), Some(m.to_uint())), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) => Ok((Limits::i64(n, None), i))
        Err(t) => Err(t)
      }
    Some(0x05) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U64(n), i)) =>
          match Decode::decode(bytes, i) {
            Ok((@lib.U64(m), i)) => Ok((Limits::i64(n, Some(m)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(_) => Err(BinaryDecodeError::InvalidLimits)
  }
}

///|
pub impl Decode for TableType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((rt, i)) =>
      match Decode::decode(bytes, i) {
        Ok((l, i)) => Ok((TableType::new(rt, l), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for MemType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((l, i)) => Ok((MemType::new(l), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for GlobalType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((vt, i)) =>
      match Decode::decode(bytes, i) {
        Ok((m, i)) => Ok((GlobalType::new(vt, m), i))
        Err(_) => Ok((GlobalType::new(vt, false), i))
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for TagType with decode(bytes, i) {
  if bytes.get(i) != Some(0x00) {
    return Err(BinaryDecodeError::InvalidTagType)
  }
  match Decode::decode(bytes, i + 1) {
    Ok((idx, i)) => Ok((TagType::new(idx), i))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for ExternType with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((ExternType::func(idx), i))
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tt, i)) => Ok((ExternType::table(tt), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((mt, i)) => Ok((ExternType::mem(mt), i))
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((gt, i)) => Ok((ExternType::global(gt), i))
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tt, i)) => Ok((ExternType::tag(tt), i))
        Err(t) => Err(t)
      }
    Some(_) => Err(BinaryDecodeError::InvalidExternTypeHeader)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

// General pattern for section decoding

///|
pub impl Decode for ImportSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 2) {
    Ok((content, next)) => Ok((ImportSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for FuncSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 3) {
    Ok((content, next)) => Ok((FuncSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for BlockType with decode(bytes, i) {
  if bytes.get(i) is Some(0x40) {
    return Ok((BlockType::void_(), i + 1))
  }
  if Decode::decode(bytes, i) is Ok((vt, i)) {
    return Ok((BlockType::val_type(vt), i))
  }
  if Decode::decode(bytes, i) is Ok((@lib.S33(idx), i)) {
    return Ok((BlockType::type_idx(TypeIdx::new(idx)), i))
  }
  Err(BinaryDecodeError::InvalidBlockType)
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
  Ok((Expr::new(a), i))
}

///|
pub impl Decode for Table with decode(bytes, i) {
  match (bytes.get(i), bytes.get(i + 1)) {
    (Some(0x40), Some(0x00)) =>
      match Decode::decode(bytes, i + 2) {
        Ok((tt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((e, i)) => Ok((Table::new(tt, Some(e)), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    _ =>
      match Decode::decode(bytes, i) {
        Ok((tt, i)) => Ok((Table::new(tt, None), i))
        Err(t) => Err(t)
      }
  }
}

///|
pub impl Decode for Global with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((gt, i)) =>
      match Decode::decode(bytes, i) {
        Ok((expr, i)) => Ok((Global::new(gt, expr), i))
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
        Ok((idx, i)) => Ok((ExternIdx::func(idx), i))
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((ExternIdx::table(idx), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((ExternIdx::mem(idx), i))
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((ExternIdx::global(idx), i))
        Err(t) => Err(t)
      }
    Some(0x04) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((ExternIdx::tag(idx), i))
        Err(t) => Err(t)
      }
    Some(_) => Err(BinaryDecodeError::InvalidExternIndex)
    None => Err(BinaryDecodeError::IndexOutOfBounds)
  }
}

///|
pub impl Decode for Export with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((n, i)) =>
      match Decode::decode(bytes, i) {
        Ok((idx, i)) => Ok((Export::new(n, idx), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for TableSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 4) {
    Ok((content, next)) => Ok((TableSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for MemSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 5) {
    Ok((content, next)) => Ok((MemSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for TagSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 13) {
    Ok((content, next)) => Ok((TagSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for GlobalSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 6) {
    Ok((content, next)) => Ok((GlobalSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for ExportSec with decode(bytes, i) {
  match decode_section_vector_payload(bytes, i, 7) {
    Ok((content, next)) => Ok((ExportSec::new(content), next))
    Err(t) => Err(t)
  }
}

///|
pub impl Decode for StartSec with decode(bytes, i) {
  if bytes.get(i) != Some(8) {
    return Err(BinaryDecodeError::InvalidSectionHeader)
  }
  match Decode::decode(bytes, i + 1) {
    Err(t) => Err(t)
    Ok((idx, i)) => Ok((StartSec::new(idx), i))
  }
}

///|
pub impl Decode for Bytes with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Err(t) => Err(t)
    Ok((@lib.U32(len), i)) if len + i.reinterpret_as_uint() <=
      bytes.length().reinterpret_as_uint() => {
      let next = i + len.reinterpret_as_int()
      let val = bytes[i:next].to_bytes()
      Ok((val, next))
    }
    Ok(_) => Err(BinaryDecodeError::InvalidOffset)
  }
}

///|
pub impl Decode for Catch with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((lidx, i)) => Ok((Catch::new(tidx, lidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x01) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((lidx, i)) => Ok((Catch::ref_(tidx, lidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Catch::all(idx), i))
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Catch::all_ref(idx), i))
        Err(t) => Err(t)
      }
    _ => Err(BinaryDecodeError::InvalidCatch)
  }
}

///|
pub impl Decode for CastOp with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) => Ok((CastOp::new(false, false), i + 1))
    Some(0x01) => Ok((CastOp::new(true, false), i + 1))
    Some(0x02) => Ok((CastOp::new(false, true), i + 1))
    Some(0x03) => Ok((CastOp::new(true, true), i + 1))
    _ => Err(BinaryDecodeError::InvalidCastOp)
  }
}

///|
pub impl Decode for MemArg with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Ok((@lib.U32(n), i)) if n >= 64 && n < 128 =>
      match Decode::decode(bytes, i) {
        Ok((x, i)) =>
          match Decode::decode(bytes, i) {
            Ok((@lib.U64(m), i)) => Ok((MemArg::new(n - 64, Some(x), m), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Ok((@lib.U32(n), i)) if n < 64 =>
      match Decode::decode(bytes, i) {
        Ok((@lib.U64(m), i)) => Ok((MemArg::new(n, None, m), i))
        Err(t) => Err(t)
      }
    Err(t) => Err(t)
    _ => Err(BinaryDecodeError::InvalidMemArg)
  }
}

///|
pub impl Decode for Instruction with decode(bytes, i) {
  match bytes.get(i) {
    Some(0x00) => Ok((Instruction::unreachable_(), i + 1))
    Some(0x01) => Ok((Instruction::nop(), i + 1))
    Some(0x1A) => Ok((Instruction::drop(), i + 1))
    Some(0x1B) => Ok((Instruction::select(types=None), i + 1))
    Some(0x1C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((vts, i)) => Ok((Instruction::select(types=Some(vts)), i))
        Err(t) => Err(t)
      }
    Some(0x02) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) => Ok((Instruction::block(bt, expr), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x03) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((expr, i)) => Ok((Instruction::loop_(bt, expr), i))
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
                  break (
                    Instruction::if_(bt, if_insts, Some(else_insts)),
                    i + 1,
                  )
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
                Some(0x0B) =>
                  break (Instruction::if_(bt, if_insts, None), i + 1)
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
        Ok((tag, i)) => Ok((Instruction::throw_(tag), i))
        Err(t) => Err(t)
      }
    Some(0x0A) => Ok((Instruction::throw_ref(), i + 1))
    Some(0x0C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((lbl, i)) => Ok((Instruction::br(lbl), i))
        Err(t) => Err(t)
      }
    Some(0x0D) =>
      match Decode::decode(bytes, i + 1) {
        Ok((lbl, i)) => Ok((Instruction::br_if(lbl), i))
        Err(t) => Err(t)
      }
    Some(0x0E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((lbls, i)) =>
          match Decode::decode(bytes, i) {
            Ok((lbl, i)) => Ok((Instruction::br_table(lbls, lbl), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x0F) => Ok((Instruction::return_(), i + 1))
    Some(0x10) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::call(idx), i))
        Err(t) => Err(t)
      }
    Some(0x11) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((tblidx, i)) => Ok((Instruction::call_indirect(tidx, tblidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x12) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::return_call(idx), i))
        Err(t) => Err(t)
      }
    Some(0x13) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) =>
          match Decode::decode(bytes, i) {
            Ok((tblidx, i)) =>
              Ok((Instruction::return_call_indirect(tidx, tblidx), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0x14) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) => Ok((Instruction::call_ref(tidx), i))
        Err(t) => Err(t)
      }
    Some(0x15) =>
      match Decode::decode(bytes, i + 1) {
        Ok((tidx, i)) => Ok((Instruction::return_call_ref(tidx), i))
        Err(t) => Err(t)
      }
    Some(0x1F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((bt, i)) =>
          match Decode::decode(bytes, i) {
            Ok((c, i)) =>
              match Decode::decode(bytes, i) {
                Ok((e, i)) => Ok((Instruction::try_table(bt, c, e), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
      }
    Some(0xD5) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::br_on_null(idx), i))
        Err(t) => Err(t)
      }
    Some(0xD6) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::br_on_non_null(idx), i))
        Err(t) => Err(t)
      }
    Some(0x20) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::local_get(idx), i))
        Err(t) => Err(t)
      }
    Some(0x21) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::local_set(idx), i))
        Err(t) => Err(t)
      }
    Some(0x22) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::local_tee(idx), i))
        Err(t) => Err(t)
      }
    Some(0x23) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::global_get(idx), i))
        Err(t) => Err(t)
      }
    Some(0x24) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::global_set(idx), i))
        Err(t) => Err(t)
      }
    Some(0x25) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::table_get(idx), i))
        Err(t) => Err(t)
      }
    Some(0x26) =>
      match Decode::decode(bytes, i + 1) {
        Ok((idx, i)) => Ok((Instruction::table_set(idx), i))
        Err(t) => Err(t)
      }
    Some(0x28) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_load(m), i))
        Err(t) => Err(t)
      }
    Some(0x29) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load(m), i))
        Err(t) => Err(t)
      }
    Some(0x2A) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::f32_load(m), i))
        Err(t) => Err(t)
      }
    Some(0x2B) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::f64_load(m), i))
        Err(t) => Err(t)
      }
    Some(0x2C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_load8s(m), i))
        Err(t) => Err(t)
      }
    Some(0x2D) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_load8u(m), i))
        Err(t) => Err(t)
      }
    Some(0x2E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_load16s(m), i))
        Err(t) => Err(t)
      }
    Some(0x2F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_load16u(m), i))
        Err(t) => Err(t)
      }
    Some(0x30) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load8s(m), i))
        Err(t) => Err(t)
      }
    Some(0x31) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load8u(m), i))
        Err(t) => Err(t)
      }
    Some(0x32) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load16s(m), i))
        Err(t) => Err(t)
      }
    Some(0x33) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load16u(m), i))
        Err(t) => Err(t)
      }
    Some(0x34) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load32s(m), i))
        Err(t) => Err(t)
      }
    Some(0x35) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_load32u(m), i))
        Err(t) => Err(t)
      }
    Some(0x36) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_store(m), i))
        Err(t) => Err(t)
      }
    Some(0x37) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_store(m), i))
        Err(t) => Err(t)
      }
    Some(0x38) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::f32_store(m), i))
        Err(t) => Err(t)
      }
    Some(0x39) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::f64_store(m), i))
        Err(t) => Err(t)
      }
    Some(0x3A) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_store8(m), i))
        Err(t) => Err(t)
      }
    Some(0x3B) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i32_store16(m), i))
        Err(t) => Err(t)
      }
    Some(0x3C) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_store8(m), i))
        Err(t) => Err(t)
      }
    Some(0x3D) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_store16(m), i))
        Err(t) => Err(t)
      }
    Some(0x3E) =>
      match Decode::decode(bytes, i + 1) {
        Ok((m, i)) => Ok((Instruction::i64_store32(m), i))
        Err(t) => Err(t)
      }
    Some(0x3F) =>
      match Decode::decode(bytes, i + 1) {
        Ok((x, i)) => Ok((Instruction::memory_size(x), i))
        Err(t) => Err(t)
      }
    Some(0x40) =>
      match Decode::decode(bytes, i + 1) {
        Ok((x, i)) => Ok((Instruction::memory_grow(x), i))
        Err(t) => Err(t)
      }
    Some(0xD0) =>
      match Decode::decode(bytes, i + 1) {
        Ok((ht, i)) => Ok((Instruction::ref_null(ht), i))
        Err(t) => Err(t)
      }
    Some(0xD1) => Ok((Instruction::ref_is_null(), i + 1))
    Some(0xD2) =>
      match Decode::decode(bytes, i + 1) {
        Ok((x, i)) => Ok((Instruction::ref_func(x), i))
        Err(t) => Err(t)
      }
    Some(0xD3) => Ok((Instruction::ref_eq(), i + 1))
    Some(0xD4) => Ok((Instruction::ref_as_non_null(), i + 1))
    Some(0x45) => Ok((Instruction::i32_eqz(), i + 1))
    Some(0x46) => Ok((Instruction::i32_eq(), i + 1))
    Some(0x47) => Ok((Instruction::i32_ne(), i + 1))
    Some(0x48) => Ok((Instruction::i32_lt_s(), i + 1))
    Some(0x49) => Ok((Instruction::i32_lt_u(), i + 1))
    Some(0x4A) => Ok((Instruction::i32_gt_s(), i + 1))
    Some(0x4B) => Ok((Instruction::i32_gt_u(), i + 1))
    Some(0x4C) => Ok((Instruction::i32_le_s(), i + 1))
    Some(0x4D) => Ok((Instruction::i32_le_u(), i + 1))
    Some(0x4E) => Ok((Instruction::i32_ge_s(), i + 1))
    Some(0x4F) => Ok((Instruction::i32_ge_u(), i + 1))
    Some(0x50) => Ok((Instruction::i64_eqz(), i + 1))
    Some(0x51) => Ok((Instruction::i64_eq(), i + 1))
    Some(0x52) => Ok((Instruction::i64_ne(), i + 1))
    Some(0x53) => Ok((Instruction::i64_lt_s(), i + 1))
    Some(0x54) => Ok((Instruction::i64_lt_u(), i + 1))
    Some(0x55) => Ok((Instruction::i64_gt_s(), i + 1))
    Some(0x56) => Ok((Instruction::i64_gt_u(), i + 1))
    Some(0x57) => Ok((Instruction::i64_le_s(), i + 1))
    Some(0x58) => Ok((Instruction::i64_le_u(), i + 1))
    Some(0x59) => Ok((Instruction::i64_ge_s(), i + 1))
    Some(0x5A) => Ok((Instruction::i64_ge_u(), i + 1))
    Some(0x5B) => Ok((Instruction::f32_eq(), i + 1))
    Some(0x5C) => Ok((Instruction::f32_ne(), i + 1))
    Some(0x5D) => Ok((Instruction::f32_lt(), i + 1))
    Some(0x5E) => Ok((Instruction::f32_gt(), i + 1))
    Some(0x5F) => Ok((Instruction::f32_le(), i + 1))
    Some(0x60) => Ok((Instruction::f32_ge(), i + 1))
    Some(0x61) => Ok((Instruction::f64_eq(), i + 1))
    Some(0x62) => Ok((Instruction::f64_ne(), i + 1))
    Some(0x63) => Ok((Instruction::f64_lt(), i + 1))
    Some(0x64) => Ok((Instruction::f64_gt(), i + 1))
    Some(0x65) => Ok((Instruction::f64_le(), i + 1))
    Some(0x66) => Ok((Instruction::f64_ge(), i + 1))
    Some(0x67) => Ok((Instruction::i32_clz(), i + 1))
    Some(0x68) => Ok((Instruction::i32_ctz(), i + 1))
    Some(0x69) => Ok((Instruction::i32_popcnt(), i + 1))
    Some(0x6A) => Ok((Instruction::i32_add(), i + 1))
    Some(0x6B) => Ok((Instruction::i32_sub(), i + 1))
    Some(0x6C) => Ok((Instruction::i32_mul(), i + 1))
    Some(0x6D) => Ok((Instruction::i32_div_s(), i + 1))
    Some(0x6E) => Ok((Instruction::i32_div_u(), i + 1))
    Some(0x6F) => Ok((Instruction::i32_rem_s(), i + 1))
    Some(0x70) => Ok((Instruction::i32_rem_u(), i + 1))
    Some(0x71) => Ok((Instruction::i32_and(), i + 1))
    Some(0x72) => Ok((Instruction::i32_or(), i + 1))
    Some(0x73) => Ok((Instruction::i32_xor(), i + 1))
    Some(0x74) => Ok((Instruction::i32_shl(), i + 1))
    Some(0x75) => Ok((Instruction::i32_shr_s(), i + 1))
    Some(0x76) => Ok((Instruction::i32_shr_u(), i + 1))
    Some(0x77) => Ok((Instruction::i32_rotl(), i + 1))
    Some(0x78) => Ok((Instruction::i32_rotr(), i + 1))
    Some(0x79) => Ok((Instruction::i64_clz(), i + 1))
    Some(0x7A) => Ok((Instruction::i64_ctz(), i + 1))
    Some(0x7B) => Ok((Instruction::i64_popcnt(), i + 1))
    Some(0x7C) => Ok((Instruction::i64_add(), i + 1))
    Some(0x7D) => Ok((Instruction::i64_sub(), i + 1))
    Some(0x7E) => Ok((Instruction::i64_mul(), i + 1))
    Some(0x7F) => Ok((Instruction::i64_div_s(), i + 1))
    Some(0x80) => Ok((Instruction::i64_div_u(), i + 1))
    Some(0x81) => Ok((Instruction::i64_rem_s(), i + 1))
    Some(0x82) => Ok((Instruction::i64_rem_u(), i + 1))
    Some(0x83) => Ok((Instruction::i64_and(), i + 1))
    Some(0x84) => Ok((Instruction::i64_or(), i + 1))
    Some(0x85) => Ok((Instruction::i64_xor(), i + 1))
    Some(0x86) => Ok((Instruction::i64_shl(), i + 1))
    Some(0x87) => Ok((Instruction::i64_shr_s(), i + 1))
    Some(0x88) => Ok((Instruction::i64_shr_u(), i + 1))
    Some(0x89) => Ok((Instruction::i64_rotl(), i + 1))
    Some(0x8A) => Ok((Instruction::i64_rotr(), i + 1))
    Some(0x8B) => Ok((Instruction::f32_abs(), i + 1))
    Some(0x8C) => Ok((Instruction::f32_neg(), i + 1))
    Some(0x8D) => Ok((Instruction::f32_ceil(), i + 1))
    Some(0x8E) => Ok((Instruction::f32_floor(), i + 1))
    Some(0x8F) => Ok((Instruction::f32_trunc(), i + 1))
    Some(0x90) => Ok((Instruction::f32_nearest(), i + 1))
    Some(0x91) => Ok((Instruction::f32_sqrt(), i + 1))
    Some(0x92) => Ok((Instruction::f32_add(), i + 1))
    Some(0x93) => Ok((Instruction::f32_sub(), i + 1))
    Some(0x94) => Ok((Instruction::f32_mul(), i + 1))
    Some(0x95) => Ok((Instruction::f32_div(), i + 1))
    Some(0x96) => Ok((Instruction::f32_min(), i + 1))
    Some(0x97) => Ok((Instruction::f32_max(), i + 1))
    Some(0x98) => Ok((Instruction::f32_copysign(), i + 1))
    Some(0x99) => Ok((Instruction::f64_abs(), i + 1))
    Some(0x9A) => Ok((Instruction::f64_neg(), i + 1))
    Some(0x9B) => Ok((Instruction::f64_ceil(), i + 1))
    Some(0x9C) => Ok((Instruction::f64_floor(), i + 1))
    Some(0x9D) => Ok((Instruction::f64_trunc(), i + 1))
    Some(0x9E) => Ok((Instruction::f64_nearest(), i + 1))
    Some(0x9F) => Ok((Instruction::f64_sqrt(), i + 1))
    Some(0xA0) => Ok((Instruction::f64_add(), i + 1))
    Some(0xA1) => Ok((Instruction::f64_sub(), i + 1))
    Some(0xA2) => Ok((Instruction::f64_mul(), i + 1))
    Some(0xA3) => Ok((Instruction::f64_div(), i + 1))
    Some(0xA4) => Ok((Instruction::f64_min(), i + 1))
    Some(0xA5) => Ok((Instruction::f64_max(), i + 1))
    Some(0xA6) => Ok((Instruction::f64_copysign(), i + 1))
    Some(0xA7) => Ok((Instruction::i32_wrap_i64(), i + 1))
    Some(0xA8) => Ok((Instruction::i32_trunc_f32s(), i + 1))
    Some(0xA9) => Ok((Instruction::i32_trunc_f32u(), i + 1))
    Some(0xAA) => Ok((Instruction::i32_trunc_f64s(), i + 1))
    Some(0xAB) => Ok((Instruction::i32_trunc_f64u(), i + 1))
    Some(0xAC) => Ok((Instruction::i64_extend_i32s(), i + 1))
    Some(0xAD) => Ok((Instruction::i64_extend_i32u(), i + 1))
    Some(0xAE) => Ok((Instruction::i64_trunc_f32s(), i + 1))
    Some(0xAF) => Ok((Instruction::i64_trunc_f32u(), i + 1))
    Some(0xB0) => Ok((Instruction::i64_trunc_f64s(), i + 1))
    Some(0xB1) => Ok((Instruction::i64_trunc_f64u(), i + 1))
    Some(0xB2) => Ok((Instruction::f32_convert_i32s(), i + 1))
    Some(0xB3) => Ok((Instruction::f32_convert_i32u(), i + 1))
    Some(0xB4) => Ok((Instruction::f32_convert_i64s(), i + 1))
    Some(0xB5) => Ok((Instruction::f32_convert_i64u(), i + 1))
    Some(0xB6) => Ok((Instruction::f32_demote_f64(), i + 1))
    Some(0xB7) => Ok((Instruction::f64_convert_i32s(), i + 1))
    Some(0xB8) => Ok((Instruction::f64_convert_i32u(), i + 1))
    Some(0xB9) => Ok((Instruction::f64_convert_i64s(), i + 1))
    Some(0xBA) => Ok((Instruction::f64_convert_i64u(), i + 1))
    Some(0xBB) => Ok((Instruction::f64_promote_f32(), i + 1))
    Some(0xBC) => Ok((Instruction::i32_reinterpret_f32(), i + 1))
    Some(0xBD) => Ok((Instruction::i64_reinterpret_f64(), i + 1))
    Some(0xBE) => Ok((Instruction::f32_reinterpret_i32(), i + 1))
    Some(0xBF) => Ok((Instruction::f64_reinterpret_i64(), i + 1))
    Some(0xC0) => Ok((Instruction::i32_extend8s(), i + 1))
    Some(0xC1) => Ok((Instruction::i32_extend16s(), i + 1))
    Some(0xC2) => Ok((Instruction::i64_extend8s(), i + 1))
    Some(0xC3) => Ok((Instruction::i64_extend16s(), i + 1))
    Some(0xC4) => Ok((Instruction::i64_extend32s(), i + 1))
    Some(0x41) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((Instruction::i32_const(n), i))
        Err(t) => Err(t)
      }
    Some(0x42) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((Instruction::i64_const(n), i))
        Err(t) => Err(t)
      }
    Some(0x43) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((Instruction::f32_const(n), i))
        Err(t) => Err(t)
      }
    Some(0x44) =>
      match Decode::decode(bytes, i + 1) {
        Ok((n, i)) => Ok((Instruction::f64_const(n), i))
        Err(t) => Err(t)
      }

    // Section: Control Flow/Aggregate 0xFB
    Some(0xFB) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::struct_new(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(1), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::struct_new_default(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(2), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::struct_get(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(3), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::struct_get_s(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(4), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::struct_get_u(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(5), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::struct_set(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(6), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_new(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(7), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_new_default(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(8), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::array_new_fixed(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(9), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::array_new_data(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(10), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((n, i)) => Ok((Instruction::array_new_elem(x, n), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(11), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_get(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(12), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_get_s(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(13), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_get_u(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(14), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_set(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(15), i)) => Ok((Instruction::array_len(), i))
        Ok((@lib.U32(16), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::array_fill(x), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(17), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x1, i)) =>
              match Decode::decode(bytes, i) {
                Ok((x2, i)) => Ok((Instruction::array_copy(x1, x2), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(18), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x1, i)) =>
              match Decode::decode(bytes, i) {
                Ok((x2, i)) => Ok((Instruction::array_init_data(x1, x2), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(19), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x1, i)) =>
              match Decode::decode(bytes, i) {
                Ok((x2, i)) => Ok((Instruction::array_init_elem(x1, x2), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(20), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_test(false, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(21), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_test(true, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(22), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_cast(false, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(23), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_cast(true, ht), i))
            Err(t) => Err(t)
          }
        Ok((U32(24), i)) => {
          let castop : Result[(CastOp, Int), BinaryDecodeError] = Decode::decode(
            bytes, i,
          )
          match castop {
            Ok((c, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) =>
                  match Decode::decode(bytes, i) {
                    Ok((ht1, i)) =>
                      match Decode::decode(bytes, i) {
                        Ok((ht2, i)) =>
                          Ok(
                            (Instruction::br_on_cast(l, c.0, ht1, c.1, ht2), i),
                          )
                        Err(t) => Err(t)
                      }
                    Err(t) => Err(t)
                  }
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        }
        Ok((U32(25), i)) => {
          let castop : Result[(CastOp, Int), BinaryDecodeError] = Decode::decode(
            bytes, i,
          )
          match castop {
            Ok((c, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) =>
                  match Decode::decode(bytes, i) {
                    Ok((ht1, i)) =>
                      match Decode::decode(bytes, i) {
                        Ok((ht2, i)) =>
                          Ok(
                            (
                              Instruction::br_on_cast_fail(
                                l,
                                c.0,
                                ht1,
                                c.1,
                                ht2,
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
            Err(t) => Err(t)
          }
        }
        Ok((U32(26), i)) => Ok((Instruction::any_convert_extern(), i))
        Ok((U32(27), i)) => Ok((Instruction::extern_convert_any(), i))
        Ok((U32(28), i)) => Ok((Instruction::ref_i31(), i))
        Ok((U32(29), i)) => Ok((Instruction::i31_get_s(), i))
        Ok((U32(30), i)) => Ok((Instruction::i31_get_u(), i))
        Ok((U32(31), i)) => Ok((Instruction::ref_get_desc(), i))
        Ok((@lib.U32(32), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_test_desc(false, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(33), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_test_desc(true, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(34), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_cast_desc_eq(false, ht), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(35), i)) =>
          match Decode::decode(bytes, i) {
            Ok((ht, i)) => Ok((Instruction::ref_cast_desc_eq(true, ht), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
        _ => Err(BinaryDecodeError::InvalidInstruction)
      }

    // Section: Memory/Table/Elem
    Some(0xFC) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) => Ok((Instruction::i32_trunc_sat_f32s(), i))
        Ok((U32(1), i)) => Ok((Instruction::i32_trunc_sat_f32u(), i))
        Ok((U32(2), i)) => Ok((Instruction::i32_trunc_sat_f64s(), i))
        Ok((U32(3), i)) => Ok((Instruction::i32_trunc_sat_f64u(), i))
        Ok((U32(4), i)) => Ok((Instruction::i64_trunc_sat_f32s(), i))
        Ok((U32(5), i)) => Ok((Instruction::i64_trunc_sat_f32u(), i))
        Ok((U32(6), i)) => Ok((Instruction::i64_trunc_sat_f64s(), i))
        Ok((U32(7), i)) => Ok((Instruction::i64_trunc_sat_f64u(), i))
        Ok((U32(8), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((Instruction::memory_init(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(9), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::data_drop(x), i))
            Err(t) => Err(t)
          }
        Ok((U32(10), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((Instruction::memory_copy(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(11), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) => Ok((Instruction::memory_fill(x), i))
            Err(t) => Err(t)
          }
        Ok((U32(12), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((Instruction::table_init(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(13), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((Instruction::elem_drop(y), i))
            Err(t) => Err(t)
          }
        Ok((U32(14), i)) =>
          match Decode::decode(bytes, i) {
            Ok((x, i)) =>
              match Decode::decode(bytes, i) {
                Ok((y, i)) => Ok((Instruction::table_copy(x, y), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(15), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((Instruction::table_grow(y), i))
            Err(t) => Err(t)
          }
        Ok((U32(16), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((Instruction::table_size(y), i))
            Err(t) => Err(t)
          }
        Ok((U32(17), i)) =>
          match Decode::decode(bytes, i) {
            Ok((y, i)) => Ok((Instruction::table_fill(y), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
        _ => Err(BinaryDecodeError::InvalidInstruction)
      }

    // Section: Threads atomics
    Some(0xFE) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::memory_atomic_notify(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(1), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::memory_atomic_wait32(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(2), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::memory_atomic_wait64(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(3), i)) =>
          match bytes.get(i) {
            Some(0x00) => Ok((Instruction::atomic_fence(), i + 1))
            _ => Err(BinaryDecodeError::InvalidAtomicFenceImmediate)
          }
        Ok((@lib.U32(16), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i32_atomic_load(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(17), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_load(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(18), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i32_atomic_load8_u(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(19), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i32_atomic_load16_u(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(20), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_load8_u(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(21), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_load16_u(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(22), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_load32_u(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(23), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i32_atomic_store(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(24), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_store(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(25), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i32_atomic_store8(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(26), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i32_atomic_store16(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(27), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_store8(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(28), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_store16(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(29), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::i64_atomic_store32(m), i))
            Err(t) => Err(t)
          }
        Ok((@lib.U32(id), i)) if id >= 30 && id <= 71 =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => {
              let op : AtomicRmwOp = match id {
                30 => AtomicRmwOp::i32_add()
                31 => AtomicRmwOp::i64_add()
                32 => AtomicRmwOp::i32_8_add_u()
                33 => AtomicRmwOp::i32_16_add_u()
                34 => AtomicRmwOp::i64_8_add_u()
                35 => AtomicRmwOp::i64_16_add_u()
                36 => AtomicRmwOp::i64_32_add_u()
                37 => AtomicRmwOp::i32_sub()
                38 => AtomicRmwOp::i64_sub()
                39 => AtomicRmwOp::i32_8_sub_u()
                40 => AtomicRmwOp::i32_16_sub_u()
                41 => AtomicRmwOp::i64_8_sub_u()
                42 => AtomicRmwOp::i64_16_sub_u()
                43 => AtomicRmwOp::i64_32_sub_u()
                44 => AtomicRmwOp::i32_and()
                45 => AtomicRmwOp::i64_and()
                46 => AtomicRmwOp::i32_8_and_u()
                47 => AtomicRmwOp::i32_16_and_u()
                48 => AtomicRmwOp::i64_8_and_u()
                49 => AtomicRmwOp::i64_16_and_u()
                50 => AtomicRmwOp::i64_32_and_u()
                51 => AtomicRmwOp::i32_or()
                52 => AtomicRmwOp::i64_or()
                53 => AtomicRmwOp::i32_8_or_u()
                54 => AtomicRmwOp::i32_16_or_u()
                55 => AtomicRmwOp::i64_8_or_u()
                56 => AtomicRmwOp::i64_16_or_u()
                57 => AtomicRmwOp::i64_32_or_u()
                58 => AtomicRmwOp::i32_xor()
                59 => AtomicRmwOp::i64_xor()
                60 => AtomicRmwOp::i32_8_xor_u()
                61 => AtomicRmwOp::i32_16_xor_u()
                62 => AtomicRmwOp::i64_8_xor_u()
                63 => AtomicRmwOp::i64_16_xor_u()
                64 => AtomicRmwOp::i64_32_xor_u()
                65 => AtomicRmwOp::i32_xchg()
                66 => AtomicRmwOp::i64_xchg()
                67 => AtomicRmwOp::i32_8_xchg_u()
                68 => AtomicRmwOp::i32_16_xchg_u()
                69 => AtomicRmwOp::i64_8_xchg_u()
                70 => AtomicRmwOp::i64_16_xchg_u()
                _ => AtomicRmwOp::i64_32_xchg_u()
              }
              Ok((Instruction::atomic_rmw(op, m), i))
            }
            Err(t) => Err(t)
          }
        Ok((@lib.U32(id), i)) if id >= 72 && id <= 78 =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => {
              let op : AtomicCmpxchgOp = match id {
                72 => AtomicCmpxchgOp::i32()
                73 => AtomicCmpxchgOp::i64()
                74 => AtomicCmpxchgOp::i32_8_u()
                75 => AtomicCmpxchgOp::i32_16_u()
                76 => AtomicCmpxchgOp::i64_8_u()
                77 => AtomicCmpxchgOp::i64_16_u()
                _ => AtomicCmpxchgOp::i64_32_u()
              }
              Ok((Instruction::atomic_cmpxchg(op, m), i))
            }
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
        _ => Err(BinaryDecodeError::InvalidAtomicInstruction)
      }

    // Section: Vector
    Some(0xFD) =>
      match Decode::decode(bytes, i + 1) {
        Ok((@lib.U32(0), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(1), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load8x8s(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(2), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load8x8u(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(3), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load16x4s(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(4), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load16x4u(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(5), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load32x2s(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(6), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load32x2u(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(7), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load8_splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(8), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load16_splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(9), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load32_splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(10), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load64_splat(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(11), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_store(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(12), i)) =>
          // 16 bytes const
          if bytes.length() >= i + 16 {
            Ok(
              (
                Instruction::v128_const(
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
            Err(BinaryDecodeError::InvalidInstruction)
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
                                                                              Instruction::i8x16_shuffle(
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
        Ok((@lib.U32(14), i)) => Ok((Instruction::i8x16_swizzle(), i))
        Ok((@lib.U32(15), i)) => Ok((Instruction::i8x16_splat(), i))
        Ok((@lib.U32(16), i)) => Ok((Instruction::i16x8_splat(), i))
        Ok((@lib.U32(17), i)) => Ok((Instruction::i32x4_splat(), i))
        Ok((@lib.U32(18), i)) => Ok((Instruction::i64x2_splat(), i))
        Ok((@lib.U32(19), i)) => Ok((Instruction::f32x4_splat(), i))
        Ok((@lib.U32(20), i)) => Ok((Instruction::f64x2_splat(), i))
        Ok((@lib.U32(35), i)) => Ok((Instruction::i8x16_eq(), i))
        Ok((@lib.U32(36), i)) => Ok((Instruction::i8x16_ne(), i))
        Ok((@lib.U32(37), i)) => Ok((Instruction::i8x16_lt_s(), i))
        Ok((@lib.U32(38), i)) => Ok((Instruction::i8x16_lt_u(), i))
        Ok((@lib.U32(39), i)) => Ok((Instruction::i8x16_gt_s(), i))
        Ok((@lib.U32(40), i)) => Ok((Instruction::i8x16_gt_u(), i))
        Ok((@lib.U32(41), i)) => Ok((Instruction::i8x16_le_s(), i))
        Ok((@lib.U32(42), i)) => Ok((Instruction::i8x16_le_u(), i))
        Ok((@lib.U32(43), i)) => Ok((Instruction::i8x16_ge_s(), i))
        Ok((@lib.U32(44), i)) => Ok((Instruction::i8x16_ge_u(), i))
        Ok((@lib.U32(45), i)) => Ok((Instruction::i16x8_eq(), i))
        Ok((@lib.U32(46), i)) => Ok((Instruction::i16x8_ne(), i))
        Ok((@lib.U32(47), i)) => Ok((Instruction::i16x8_lt_s(), i))
        Ok((@lib.U32(48), i)) => Ok((Instruction::i16x8_lt_u(), i))
        Ok((@lib.U32(49), i)) => Ok((Instruction::i16x8_gt_s(), i))
        Ok((@lib.U32(50), i)) => Ok((Instruction::i16x8_gt_u(), i))
        Ok((@lib.U32(51), i)) => Ok((Instruction::i16x8_le_s(), i))
        Ok((@lib.U32(52), i)) => Ok((Instruction::i16x8_le_u(), i))
        Ok((@lib.U32(53), i)) => Ok((Instruction::i16x8_ge_s(), i))
        Ok((@lib.U32(54), i)) => Ok((Instruction::i16x8_ge_u(), i))
        Ok((@lib.U32(55), i)) => Ok((Instruction::i32x4_eq(), i))
        Ok((@lib.U32(56), i)) => Ok((Instruction::i32x4_ne(), i))
        Ok((@lib.U32(57), i)) => Ok((Instruction::i32x4_lt_s(), i))
        Ok((@lib.U32(58), i)) => Ok((Instruction::i32x4_lt_u(), i))
        Ok((@lib.U32(59), i)) => Ok((Instruction::i32x4_gt_s(), i))
        Ok((@lib.U32(60), i)) => Ok((Instruction::i32x4_gt_u(), i))
        Ok((@lib.U32(61), i)) => Ok((Instruction::i32x4_le_s(), i))
        Ok((@lib.U32(62), i)) => Ok((Instruction::i32x4_le_u(), i))
        Ok((@lib.U32(63), i)) => Ok((Instruction::i32x4_ge_s(), i))
        Ok((@lib.U32(64), i)) => Ok((Instruction::i32x4_ge_u(), i))
        Ok((@lib.U32(65), i)) => Ok((Instruction::f32x4_eq(), i))
        Ok((@lib.U32(66), i)) => Ok((Instruction::f32x4_ne(), i))
        Ok((@lib.U32(67), i)) => Ok((Instruction::f32x4_lt(), i))
        Ok((@lib.U32(68), i)) => Ok((Instruction::f32x4_gt(), i))
        Ok((@lib.U32(69), i)) => Ok((Instruction::f32x4_le(), i))
        Ok((@lib.U32(70), i)) => Ok((Instruction::f32x4_ge(), i))
        Ok((@lib.U32(71), i)) => Ok((Instruction::f64x2_eq(), i))
        Ok((@lib.U32(72), i)) => Ok((Instruction::f64x2_ne(), i))
        Ok((@lib.U32(73), i)) => Ok((Instruction::f64x2_lt(), i))
        Ok((@lib.U32(74), i)) => Ok((Instruction::f64x2_gt(), i))
        Ok((@lib.U32(75), i)) => Ok((Instruction::f64x2_le(), i))
        Ok((@lib.U32(76), i)) => Ok((Instruction::f64x2_ge(), i))
        Ok((@lib.U32(77), i)) => Ok((Instruction::v128_not(), i))
        Ok((@lib.U32(78), i)) => Ok((Instruction::v128_and(), i))
        Ok((@lib.U32(79), i)) => Ok((Instruction::v128_andnot(), i))
        Ok((@lib.U32(80), i)) => Ok((Instruction::v128_or(), i))
        Ok((@lib.U32(81), i)) => Ok((Instruction::v128_xor(), i))
        Ok((@lib.U32(82), i)) => Ok((Instruction::v128_bitselect(), i))
        Ok((@lib.U32(83), i)) => Ok((Instruction::v128_any_true(), i))
        Ok((@lib.U32(94), i)) => Ok((Instruction::f32x4_demote_f64x2_zero(), i))
        Ok((@lib.U32(95), i)) => Ok((Instruction::f64x2_promote_low_f32x4(), i))
        Ok((@lib.U32(96), i)) => Ok((Instruction::i8x16_abs(), i))
        Ok((@lib.U32(97), i)) => Ok((Instruction::i8x16_neg(), i))
        Ok((@lib.U32(98), i)) => Ok((Instruction::i8x16_popcnt(), i))
        Ok((@lib.U32(99), i)) => Ok((Instruction::i8x16_all_true(), i))
        Ok((@lib.U32(100), i)) => Ok((Instruction::i8x16_bitmask(), i))
        Ok((@lib.U32(101), i)) => Ok((Instruction::i8x16_narrow_i16x8s(), i))
        Ok((@lib.U32(102), i)) => Ok((Instruction::i8x16_narrow_i16x8u(), i))
        Ok((@lib.U32(103), i)) => Ok((Instruction::f32x4_ceil(), i))
        Ok((@lib.U32(104), i)) => Ok((Instruction::f32x4_floor(), i))
        Ok((@lib.U32(105), i)) => Ok((Instruction::f32x4_trunc(), i))
        Ok((@lib.U32(106), i)) => Ok((Instruction::f32x4_nearest(), i))
        Ok((@lib.U32(107), i)) => Ok((Instruction::i8x16_shl(), i))
        Ok((@lib.U32(108), i)) => Ok((Instruction::i8x16_shr_s(), i))
        Ok((@lib.U32(109), i)) => Ok((Instruction::i8x16_shr_u(), i))
        Ok((@lib.U32(110), i)) => Ok((Instruction::i8x16_add(), i))
        Ok((@lib.U32(111), i)) => Ok((Instruction::i8x16_add_sat_s(), i))
        Ok((@lib.U32(112), i)) => Ok((Instruction::i8x16_add_sat_u(), i))
        Ok((@lib.U32(113), i)) => Ok((Instruction::i8x16_sub(), i))
        Ok((@lib.U32(114), i)) => Ok((Instruction::i8x16_sub_sat_s(), i))
        Ok((@lib.U32(115), i)) => Ok((Instruction::i8x16_sub_sat_u(), i))
        Ok((@lib.U32(116), i)) => Ok((Instruction::f64x2_ceil(), i))
        Ok((@lib.U32(117), i)) => Ok((Instruction::f64x2_floor(), i))
        Ok((@lib.U32(118), i)) => Ok((Instruction::i8x16_min_s(), i))
        Ok((@lib.U32(119), i)) => Ok((Instruction::i8x16_min_u(), i))
        Ok((@lib.U32(120), i)) => Ok((Instruction::i8x16_max_s(), i))
        Ok((@lib.U32(121), i)) => Ok((Instruction::i8x16_max_u(), i))
        Ok((@lib.U32(122), i)) => Ok((Instruction::f64x2_trunc(), i))
        Ok((@lib.U32(123), i)) => Ok((Instruction::i8x16_avgr_u(), i))
        Ok((@lib.U32(124), i)) =>
          Ok((Instruction::i16x8_extadd_pairwise_i8x16s(), i))
        Ok((@lib.U32(125), i)) =>
          Ok((Instruction::i16x8_extadd_pairwise_i8x16u(), i))
        Ok((@lib.U32(126), i)) =>
          Ok((Instruction::i32x4_extadd_pairwise_i16x8s(), i))
        Ok((@lib.U32(127), i)) =>
          Ok((Instruction::i32x4_extadd_pairwise_i16x8u(), i))
        Ok((@lib.U32(128), i)) => Ok((Instruction::i16x8_abs(), i))
        Ok((@lib.U32(129), i)) => Ok((Instruction::i16x8_neg(), i))
        Ok((@lib.U32(130), i)) => Ok((Instruction::i16x8q15mulr_sat_s(), i))
        Ok((@lib.U32(131), i)) => Ok((Instruction::i16x8_all_true(), i))
        Ok((@lib.U32(132), i)) => Ok((Instruction::i16x8_bitmask(), i))
        Ok((@lib.U32(133), i)) => Ok((Instruction::i16x8_narrow_i32x4s(), i))
        Ok((@lib.U32(134), i)) => Ok((Instruction::i16x8_narrow_i32x4u(), i))
        Ok((@lib.U32(135), i)) =>
          Ok((Instruction::i16x8_extend_low_i8x16s(), i))
        Ok((@lib.U32(136), i)) =>
          Ok((Instruction::i16x8_extend_high_i8x16s(), i))
        Ok((@lib.U32(137), i)) =>
          Ok((Instruction::i16x8_extend_low_i8x16u(), i))
        Ok((@lib.U32(138), i)) =>
          Ok((Instruction::i16x8_extend_high_i8x16u(), i))
        Ok((@lib.U32(139), i)) => Ok((Instruction::i16x8_shl(), i))
        Ok((@lib.U32(140), i)) => Ok((Instruction::i16x8_shr_s(), i))
        Ok((@lib.U32(141), i)) => Ok((Instruction::i16x8_shr_u(), i))
        Ok((@lib.U32(142), i)) => Ok((Instruction::i16x8_add(), i))
        Ok((@lib.U32(143), i)) => Ok((Instruction::i16x8_add_sat_s(), i))
        Ok((@lib.U32(144), i)) => Ok((Instruction::i16x8_add_sat_u(), i))
        Ok((@lib.U32(145), i)) => Ok((Instruction::i16x8_sub(), i))
        Ok((@lib.U32(146), i)) => Ok((Instruction::i16x8_sub_sat_s(), i))
        Ok((@lib.U32(147), i)) => Ok((Instruction::i16x8_sub_sat_u(), i))
        Ok((@lib.U32(148), i)) => Ok((Instruction::f64x2_nearest(), i))
        Ok((@lib.U32(149), i)) => Ok((Instruction::i16x8_mul(), i))
        Ok((@lib.U32(150), i)) => Ok((Instruction::i16x8_min_s(), i))
        Ok((@lib.U32(151), i)) => Ok((Instruction::i16x8_min_u(), i))
        Ok((@lib.U32(152), i)) => Ok((Instruction::i16x8_max_s(), i))
        Ok((@lib.U32(153), i)) => Ok((Instruction::i16x8_max_u(), i))
        Ok((@lib.U32(155), i)) => Ok((Instruction::i16x8_avgr_u(), i))
        Ok((@lib.U32(156), i)) =>
          Ok((Instruction::i16x8_extmul_low_i8x16s(), i))
        Ok((@lib.U32(157), i)) =>
          Ok((Instruction::i16x8_extmul_high_i8x16s(), i))
        Ok((@lib.U32(158), i)) =>
          Ok((Instruction::i16x8_extmul_low_i8x16u(), i))
        Ok((@lib.U32(159), i)) =>
          Ok((Instruction::i16x8_extmul_high_i8x16u(), i))
        Ok((@lib.U32(160), i)) => Ok((Instruction::i32x4_abs(), i))
        Ok((@lib.U32(161), i)) => Ok((Instruction::i32x4_neg(), i))
        Ok((@lib.U32(163), i)) => Ok((Instruction::i32x4_all_true(), i))
        Ok((@lib.U32(164), i)) => Ok((Instruction::i32x4_bitmask(), i))
        Ok((@lib.U32(167), i)) =>
          Ok((Instruction::i32x4_extend_low_i16x8s(), i))
        Ok((@lib.U32(168), i)) =>
          Ok((Instruction::i32x4_extend_high_i16x8s(), i))
        Ok((@lib.U32(169), i)) =>
          Ok((Instruction::i32x4_extend_low_i16x8u(), i))
        Ok((@lib.U32(170), i)) =>
          Ok((Instruction::i32x4_extend_high_i16x8u(), i))
        Ok((@lib.U32(171), i)) => Ok((Instruction::i32x4_shl(), i))
        Ok((@lib.U32(172), i)) => Ok((Instruction::i32x4_shr_s(), i))
        Ok((@lib.U32(173), i)) => Ok((Instruction::i32x4_shr_u(), i))
        Ok((@lib.U32(174), i)) => Ok((Instruction::i32x4_add(), i))
        Ok((@lib.U32(177), i)) => Ok((Instruction::i32x4_sub(), i))
        Ok((@lib.U32(181), i)) => Ok((Instruction::i32x4_mul(), i))
        Ok((@lib.U32(182), i)) => Ok((Instruction::i32x4_min_s(), i))
        Ok((@lib.U32(183), i)) => Ok((Instruction::i32x4_min_u(), i))
        Ok((@lib.U32(184), i)) => Ok((Instruction::i32x4_max_s(), i))
        Ok((@lib.U32(185), i)) => Ok((Instruction::i32x4_max_u(), i))
        Ok((@lib.U32(186), i)) => Ok((Instruction::i32x4_dot_i16x8s(), i))
        Ok((@lib.U32(188), i)) =>
          Ok((Instruction::i32x4_extmul_low_i16x8s(), i))
        Ok((@lib.U32(189), i)) =>
          Ok((Instruction::i32x4_extmul_high_i16x8s(), i))
        Ok((@lib.U32(190), i)) =>
          Ok((Instruction::i32x4_extmul_low_i16x8u(), i))
        Ok((@lib.U32(191), i)) =>
          Ok((Instruction::i32x4_extmul_high_i16x8u(), i))
        Ok((@lib.U32(192), i)) => Ok((Instruction::i64x2_abs(), i))
        Ok((@lib.U32(193), i)) => Ok((Instruction::i64x2_neg(), i))
        Ok((@lib.U32(195), i)) => Ok((Instruction::i64x2_all_true(), i))
        Ok((@lib.U32(196), i)) => Ok((Instruction::i64x2_bitmask(), i))
        Ok((@lib.U32(199), i)) =>
          Ok((Instruction::i64x2_extend_low_i32x4s(), i))
        Ok((@lib.U32(200), i)) =>
          Ok((Instruction::i64x2_extend_high_i32x4s(), i))
        Ok((@lib.U32(201), i)) =>
          Ok((Instruction::i64x2_extend_low_i32x4u(), i))
        Ok((@lib.U32(202), i)) =>
          Ok((Instruction::i64x2_extend_high_i32x4u(), i))
        Ok((@lib.U32(203), i)) => Ok((Instruction::i64x2_shl(), i))
        Ok((@lib.U32(204), i)) => Ok((Instruction::i64x2_shr_s(), i))
        Ok((@lib.U32(205), i)) => Ok((Instruction::i64x2_shr_u(), i))
        Ok((@lib.U32(206), i)) => Ok((Instruction::i64x2_add(), i))
        Ok((@lib.U32(209), i)) => Ok((Instruction::i64x2_sub(), i))
        Ok((@lib.U32(213), i)) => Ok((Instruction::i64x2_mul(), i))
        Ok((@lib.U32(214), i)) => Ok((Instruction::i64x2_eq(), i))
        Ok((@lib.U32(215), i)) => Ok((Instruction::i64x2_ne(), i))
        Ok((@lib.U32(216), i)) => Ok((Instruction::i64x2_lt_s(), i))
        Ok((@lib.U32(217), i)) => Ok((Instruction::i64x2_gt_s(), i))
        Ok((@lib.U32(218), i)) => Ok((Instruction::i64x2_le_s(), i))
        Ok((@lib.U32(219), i)) => Ok((Instruction::i64x2_ge_s(), i))
        Ok((@lib.U32(220), i)) =>
          Ok((Instruction::i64x2_extmul_low_i32x4s(), i))
        Ok((@lib.U32(221), i)) =>
          Ok((Instruction::i64x2_extmul_high_i32x4s(), i))
        Ok((@lib.U32(222), i)) =>
          Ok((Instruction::i64x2_extmul_low_i32x4u(), i))
        Ok((@lib.U32(223), i)) =>
          Ok((Instruction::i64x2_extmul_high_i32x4u(), i))
        Ok((@lib.U32(224), i)) => Ok((Instruction::f32x4_abs(), i))
        Ok((@lib.U32(225), i)) => Ok((Instruction::f32x4_neg(), i))
        Ok((@lib.U32(227), i)) => Ok((Instruction::f32x4_sqrt(), i))
        Ok((@lib.U32(228), i)) => Ok((Instruction::f32x4_add(), i))
        Ok((@lib.U32(229), i)) => Ok((Instruction::f32x4_sub(), i))
        Ok((@lib.U32(230), i)) => Ok((Instruction::f32x4_mul(), i))
        Ok((@lib.U32(231), i)) => Ok((Instruction::f32x4_div(), i))
        Ok((@lib.U32(232), i)) => Ok((Instruction::f32x4_min(), i))
        Ok((@lib.U32(233), i)) => Ok((Instruction::f32x4_max(), i))
        Ok((@lib.U32(234), i)) => Ok((Instruction::f32x4_pmin(), i))
        Ok((@lib.U32(235), i)) => Ok((Instruction::f32x4_pmax(), i))
        Ok((@lib.U32(236), i)) => Ok((Instruction::f64x2_abs(), i))
        Ok((@lib.U32(237), i)) => Ok((Instruction::f64x2_neg(), i))
        Ok((@lib.U32(239), i)) => Ok((Instruction::f64x2_sqrt(), i))
        Ok((@lib.U32(240), i)) => Ok((Instruction::f64x2_add(), i))
        Ok((@lib.U32(241), i)) => Ok((Instruction::f64x2_sub(), i))
        Ok((@lib.U32(242), i)) => Ok((Instruction::f64x2_mul(), i))
        Ok((@lib.U32(243), i)) => Ok((Instruction::f64x2_div(), i))
        Ok((@lib.U32(244), i)) => Ok((Instruction::f64x2_min(), i))
        Ok((@lib.U32(245), i)) => Ok((Instruction::f64x2_max(), i))
        Ok((@lib.U32(246), i)) => Ok((Instruction::f64x2_pmin(), i))
        Ok((@lib.U32(247), i)) => Ok((Instruction::f64x2_pmax(), i))
        Ok((@lib.U32(248), i)) => Ok((Instruction::i32x4_trunc_sat_f32x4s(), i))
        Ok((@lib.U32(249), i)) => Ok((Instruction::i32x4_trunc_sat_f32x4u(), i))
        Ok((@lib.U32(250), i)) => Ok((Instruction::f32x4_convert_i32x4s(), i))
        Ok((@lib.U32(251), i)) => Ok((Instruction::f32x4_convert_i32x4u(), i))
        Ok((@lib.U32(252), i)) =>
          Ok((Instruction::i32x4_trunc_sat_f64x2s_zero(), i))
        Ok((@lib.U32(253), i)) =>
          Ok((Instruction::i32x4_trunc_sat_f64x2u_zero(), i))
        Ok((@lib.U32(254), i)) =>
          Ok((Instruction::f64x2_convert_low_i32x4s(), i))
        Ok((@lib.U32(255), i)) =>
          Ok((Instruction::f64x2_convert_low_i32x4u(), i))
        Ok((@lib.U32(256), i)) => Ok((Instruction::i8x16_relaxed_swizzle(), i))
        Ok((@lib.U32(257), i)) =>
          Ok((Instruction::i32x4_relaxed_trunc_f32x4s(), i))
        Ok((@lib.U32(258), i)) =>
          Ok((Instruction::i32x4_relaxed_trunc_f32x4u(), i))
        Ok((@lib.U32(259), i)) =>
          Ok((Instruction::i32x4_relaxed_trunc_zero_f64x2s(), i))
        Ok((@lib.U32(260), i)) =>
          Ok((Instruction::i32x4_relaxed_trunc_zero_f64x2u(), i))
        Ok((@lib.U32(261), i)) => Ok((Instruction::f32x4_relaxed_madd(), i))
        Ok((@lib.U32(262), i)) => Ok((Instruction::f32x4_relaxed_nmadd(), i))
        Ok((@lib.U32(263), i)) => Ok((Instruction::f64x2_relaxed_madd(), i))
        Ok((@lib.U32(264), i)) => Ok((Instruction::f64x2_relaxed_nmadd(), i))
        Ok((@lib.U32(265), i)) =>
          Ok((Instruction::i8x16_relaxed_laneselect(), i))
        Ok((@lib.U32(266), i)) =>
          Ok((Instruction::i16x8_relaxed_laneselect(), i))
        Ok((@lib.U32(267), i)) =>
          Ok((Instruction::i32x4_relaxed_laneselect(), i))
        Ok((@lib.U32(268), i)) =>
          Ok((Instruction::i64x2_relaxed_laneselect(), i))
        Ok((@lib.U32(269), i)) => Ok((Instruction::f32x4_relaxed_min(), i))
        Ok((@lib.U32(270), i)) => Ok((Instruction::f32x4_relaxed_max(), i))
        Ok((@lib.U32(271), i)) => Ok((Instruction::f64x2_relaxed_min(), i))
        Ok((@lib.U32(272), i)) => Ok((Instruction::f64x2_relaxed_max(), i))
        Ok((@lib.U32(273), i)) =>
          Ok((Instruction::i16x8_relaxed_q15mulr_s(), i))
        Ok((@lib.U32(274), i)) =>
          Ok((Instruction::i16x8_relaxed_dot_i8x16i7x16s(), i))
        Ok((@lib.U32(275), i)) =>
          Ok((Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s(), i))
        Ok((@lib.U32(21), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i8x16_extract_lane_s(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(22), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i8x16_extract_lane_u(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(23), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i8x16_replace_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(24), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i16x8_extract_lane_s(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(25), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i16x8_extract_lane_u(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(26), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i16x8_replace_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(27), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i32x4_extract_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(28), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i32x4_replace_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(29), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i64x2_extract_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(30), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::i64x2_replace_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(31), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::f32x4_extract_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(32), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::f32x4_replace_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(33), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::f64x2_extract_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(34), i)) =>
          match Decode::decode(bytes, i) {
            Ok((l, i)) => Ok((Instruction::f64x2_replace_lane(l), i))
            Err(t) => Err(t)
          }
        Ok((U32(84), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_load8_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(85), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_load16_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(86), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_load32_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(87), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_load64_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(88), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_store8_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(89), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_store16_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(90), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_store32_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(91), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) =>
              match Decode::decode(bytes, i) {
                Ok((l, i)) => Ok((Instruction::v128_store64_lane(m, l), i))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        Ok((U32(92), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load32_zero(m), i))
            Err(t) => Err(t)
          }
        Ok((U32(93), i)) =>
          match Decode::decode(bytes, i) {
            Ok((m, i)) => Ok((Instruction::v128_load64_zero(m), i))
            Err(t) => Err(t)
          }
        Err(t) => Err(t)
        _ => Err(BinaryDecodeError::InvalidInstruction)
      }
    _ => Err(BinaryDecodeError::InvalidInstruction)
  }
}

///|
pub impl Decode for FieldType with decode(bytes, i) {
  match Decode::decode(bytes, i) {
    Err(err) => Err(err)
    Ok((st, i)) =>
      match Decode::decode(bytes, i) {
        Ok((m, i)) => Ok((FieldType::new(st, m), i))
        Err(err) => Err(err)
      }
  }
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
