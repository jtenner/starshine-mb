///|
priv suberror EncodingFailed {
  EncodingFailed(BinaryEncodeError)
}

///|
priv suberror DecodingFailed {
  DecodingFailed(BinaryDecodeError)
}

///|
fn[T : Encode + Decode + Eq + Show + @debug.Debug] roundtrip(
  x : T,
) -> Unit raise {
  let buf = @buffer.new()
  match Encode::encode(x, buf) {
    Ok(_) => ()
    Err(t) => raise EncodingFailed(t)
  }
  let bytes = buf.to_bytes()
  let (y, i2) = match Decode::decode(bytes, 0) {
    Ok(t) => t
    Err(t) => raise DecodingFailed(t)
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
      Err(t) => println("Could not re-encode actual value \{t}")
    }
    println(("Decoded", y))
  }
  @debug.assert_eq(i2, bytes.length())
  @debug.assert_eq(y, x)
}

///|
fn[T : Encode + Decode + Eq + Show + @debug.Debug + @quickcheck.Arbitrary] roundtrip_arbitrary_with_state(
  count : Int,
  st : @splitmix.RandomState,
) -> Array[T] raise {
  let a = Array::new(capacity=count)
  let mut i = 0
  while i < count {
    let val = @quickcheck.Arbitrary::arbitrary(i, st)
    roundtrip(val)
    a.push(val)
    i += 1
  }
  a
}

///|
fn binary_fuzz_ascii_lower(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
pub struct BinaryRoundtripFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  arbitrary_roundtrips : Int
  gen_valid_modules : Int
  gen_valid_validated : Int
  byte_fuzz_cases : Int
  byte_fuzz_decode_rejections : Int
  byte_fuzz_decode_accepts : Int
  byte_fuzz_validate_rejections : Int
  byte_fuzz_stable_roundtrips : Int
  boundary_roundtrips : Int
  instruction_roundtrips : Int
  section_roundtrips : Int
  immediate_roundtrips : Int
} derive(Eq, Debug)

///|
fn binary_roundtrip_gen_valid_module(
  index : Int,
  st : @splitmix.RandomState,
  config : GenValidConfig,
) -> Result[Unit, String] {
  let generated = match gen_valid_module_result(st, config) {
    Ok(generated) => generated
    Err(failure) =>
      return Err(
        "GenValid module generation failed at case \{index}: \{failure.validation_error_message}",
      )
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "GenValid produced invalid module at case \{index}: \{validation_error_message(err)}",
      )
  }
  let bytes = match encode_module(generated.wasm_module) {
    Ok(bytes) => bytes
    Err(err) =>
      return Err("GenValid module encode failed at case \{index}: \{err}")
  }
  let decoded = match decode_module(bytes) {
    Ok(module_) => module_
    Err(err) =>
      return Err("GenValid module decode failed at case \{index}: \{err}")
  }
  match validate_module(decoded) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "decoded GenValid module failed validation at case \{index}: \{validation_error_message(err)}",
      )
  }
  let reencoded = match encode_module(decoded) {
    Ok(bytes) => bytes
    Err(err) =>
      return Err(
        "decoded GenValid module re-encode failed at case \{index}: \{err}",
      )
  }
  let redecoded = match decode_module(reencoded) {
    Ok(module_) => module_
    Err(err) =>
      return Err(
        "re-encoded GenValid module decode failed at case \{index}: \{err}",
      )
  }
  match validate_module(redecoded) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "re-encoded GenValid module failed validation at case \{index}: \{validation_error_message(err)}",
      )
  }
  let canonical = match encode_module(redecoded) {
    Ok(bytes) => bytes
    Err(err) =>
      return Err(
        "re-decoded GenValid module encode failed at case \{index}: \{err}",
      )
  }
  if canonical != reencoded {
    return Err(
      "GenValid module canonical binary roundtrip changed bytes at case \{index}: before=\{reencoded.length()} after=\{canonical.length()}",
    )
  }
  Ok(())
}

///|
fn run_binary_roundtrip_gen_valid_fuzz(
  normalized : String,
  seed : UInt64,
  count : Int,
  config : GenValidConfig,
) -> Result[BinaryRoundtripFuzzStats, String] {
  let st = @splitmix.new(seed~)
  let mut i = 0
  while i < count {
    match binary_roundtrip_gen_valid_module(i, st, config) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    i += 1
  }
  Ok(BinaryRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts: count,
    arbitrary_roundtrips: 0,
    gen_valid_modules: count,
    gen_valid_validated: count,
    byte_fuzz_cases: 0,
    byte_fuzz_decode_rejections: 0,
    byte_fuzz_decode_accepts: 0,
    byte_fuzz_validate_rejections: 0,
    byte_fuzz_stable_roundtrips: 0,
    boundary_roundtrips: 0,
    instruction_roundtrips: 0,
    section_roundtrips: 0,
    immediate_roundtrips: 0,
  })
}

///|
fn binary_roundtrip_boundary_corpus(
  normalized : String,
  seed : UInt64,
) -> Result[BinaryRoundtripFuzzStats, String] {
  let mut count = 0
  let idx_values : Array[UInt] = [0U, 1U, 127U, 128U, 624485U, 0xffffffffU]
  for v in idx_values {
    roundtrip(TypeIdx::new(v)) catch {
      _ => return Err("boundary corpus failed TypeIdx \{v}")
    }
    roundtrip(FuncIdx::new(v)) catch {
      _ => return Err("boundary corpus failed FuncIdx \{v}")
    }
    roundtrip(LocalIdx::new(v)) catch {
      _ => return Err("boundary corpus failed LocalIdx \{v}")
    }
    count += 3
  }
  let memargs = [
    MemArg::new(0U, None, 0UL),
    MemArg::new(2U, None, 0xffffffffUL),
    MemArg::new(4U, Some(MemIdx::new(1U)), 0xffffffffffffffffUL),
  ]
  for memarg in memargs {
    roundtrip(memarg) catch {
      _ => return Err("boundary corpus failed MemArg")
    }
    count += 1
  }
  let lanes = [
    LaneIdx::new(0),
    LaneIdx::new(1),
    LaneIdx::new(14),
    LaneIdx::new(15),
  ]
  for lane in lanes {
    roundtrip(lane) catch {
      _ => return Err("boundary corpus failed LaneIdx")
    }
    count += 1
  }
  let blocks = [
    BlockType::void_(),
    BlockType::val_type(ValType::i32()),
    BlockType::type_idx(TypeIdx::new(0xffffffffU)),
  ]
  for block in blocks {
    roundtrip(block) catch {
      _ => return Err("boundary corpus failed BlockType")
    }
    count += 1
  }
  let immediates_i64 : Array[I64] = [
    I64::new(0L),
    I64::new(-1L),
    I64::new(9223372036854775807L),
    I64::new(-9223372036854775807L - 1L),
  ]
  for value in immediates_i64 {
    roundtrip(value) catch {
      _ => return Err("boundary corpus failed I64")
    }
    count += 1
  }
  let floats : Array[F32] = [
    F32::new(0.0),
    F32::new(-0.0),
    F32::new(1.0),
    F32::new(-1.0),
  ]
  for value in floats {
    roundtrip(value) catch {
      _ => return Err("boundary corpus failed F32")
    }
    count += 1
  }
  let doubles : Array[F64] = [
    F64::new(0.0),
    F64::new(-0.0),
    F64::new(1.0),
    F64::new(-1.0),
  ]
  for value in doubles {
    roundtrip(value) catch {
      _ => return Err("boundary corpus failed F64")
    }
    count += 1
  }
  Ok(BinaryRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts: count,
    arbitrary_roundtrips: 0,
    gen_valid_modules: 0,
    gen_valid_validated: 0,
    byte_fuzz_cases: 0,
    byte_fuzz_decode_rejections: 0,
    byte_fuzz_decode_accepts: 0,
    byte_fuzz_validate_rejections: 0,
    byte_fuzz_stable_roundtrips: 0,
    boundary_roundtrips: count,
    instruction_roundtrips: 0,
    section_roundtrips: 0,
    immediate_roundtrips: 0,
  })
}

///|
fn binary_byte_fuzz_rand_index(
  bytes : Bytes,
  st : @splitmix.RandomState,
) -> Int {
  if bytes.length() == 0 {
    0
  } else {
    (st.next_uint() % bytes.length().reinterpret_as_uint()).reinterpret_as_int()
  }
}

///|
fn binary_byte_fuzz_corrupt(
  bytes : Bytes,
  case_index : Int,
  st : @splitmix.RandomState,
) -> Bytes {
  let mutated = bytes.to_array()
  match case_index % 6 {
    0 => if mutated.length() > 0 { ignore(mutated.pop()) }
    1 =>
      if mutated.length() > 0 {
        mutated[0] = (mutated[0].to_int() ^ 0xff).to_byte()
      }
    2 =>
      if mutated.length() > 4 {
        mutated[4] = (mutated[4].to_int() ^ 0x03).to_byte()
      }
    3 => mutated.push((st.next_uint() % 256).to_byte())
    4 =>
      if mutated.length() > 0 {
        let idx = binary_byte_fuzz_rand_index(bytes, st)
        mutated[idx] = (mutated[idx].to_int() ^ 0x80).to_byte()
      }
    _ =>
      if mutated.length() > 8 {
        let idx = 8 +
          (st.next_uint() % (mutated.length() - 8).reinterpret_as_uint()).reinterpret_as_int()
        mutated[idx] = (0xff).to_byte()
      } else {
        mutated.push((0xff).to_byte())
      }
  }
  Bytes::from_array(mutated)
}

///|
fn binary_byte_fuzz_seed_bytes(
  index : Int,
  st : @splitmix.RandomState,
) -> Result[Bytes, String] {
  let generated = match
    gen_valid_module_result(st, GenValidConfig::natural_default()) {
    Ok(generated) => generated
    Err(failure) =>
      return Err(
        "GenValid byte-fuzz module generation failed at case \{index}: \{failure.validation_error_message}",
      )
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      return Err(
        "GenValid byte-fuzz seed failed validation at case \{index}: \{validation_error_message(err)}",
      )
  }
  match encode_module(generated.wasm_module) {
    Ok(bytes) => Ok(bytes)
    Err(err) =>
      Err("GenValid byte-fuzz seed encode failed at case \{index}: \{err}")
  }
}

///|
fn run_binary_byte_fuzz(
  normalized : String,
  seed : UInt64,
  count : Int,
) -> Result[BinaryRoundtripFuzzStats, String] {
  let st = @splitmix.new(seed~)
  let mut decode_rejections = 0
  let mut decode_accepts = 0
  let mut validate_rejections = 0
  let mut stable_roundtrips = 0
  let mut i = 0
  while i < count {
    let seed_bytes = match binary_byte_fuzz_seed_bytes(i, st) {
      Ok(bytes) => bytes
      Err(msg) => return Err(msg)
    }
    let mutated = binary_byte_fuzz_corrupt(seed_bytes, i, st)
    match decode_module(mutated) {
      Err(_) => decode_rejections += 1
      Ok(decoded) => {
        decode_accepts += 1
        match validate_module(decoded) {
          Err(_) => validate_rejections += 1
          Ok(_) => {
            let reencoded = match encode_module(decoded) {
              Ok(bytes) => bytes
              Err(err) =>
                return Err(
                  "byte-fuzz decoded valid module failed re-encode at case \{i}: \{err}",
                )
            }
            match decode_module(reencoded) {
              Ok(_) => stable_roundtrips += 1
              Err(err) =>
                return Err(
                  "byte-fuzz decoded valid module re-encode failed to decode at case \{i}: \{err}",
                )
            }
          }
        }
      }
    }
    i += 1
  }
  Ok(BinaryRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts: count,
    arbitrary_roundtrips: 0,
    gen_valid_modules: 0,
    gen_valid_validated: 0,
    byte_fuzz_cases: count,
    byte_fuzz_decode_rejections: decode_rejections,
    byte_fuzz_decode_accepts: decode_accepts,
    byte_fuzz_validate_rejections: validate_rejections,
    byte_fuzz_stable_roundtrips: stable_roundtrips,
    boundary_roundtrips: 0,
    instruction_roundtrips: 0,
    section_roundtrips: 0,
    immediate_roundtrips: 0,
  })
}

///|
pub fn run_binary_roundtrip_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[BinaryRoundtripFuzzStats, String] {
  let normalized = binary_fuzz_ascii_lower(profile.trim().to_owned())
  let (
    small,
    medium,
    section_count,
    large,
    floats,
    signed_ints,
    block_types,
    instructions,
  ) = match normalized {
    "smoke" => (8, 24, 16, 64, 256, 512, 128, 1024)
    "ci" => (30, 100, 100, 2000, 2000, 20000, 500, 50000)
    "stress" => (50, 100, 100, 1000, 10000, 100000, 1000, 1000000)
    "gen-valid-smoke" =>
      return run_binary_roundtrip_gen_valid_fuzz(
        normalized,
        seed,
        8,
        GenValidConfig::natural_default(),
      )
    "gen-valid-ci" =>
      return run_binary_roundtrip_gen_valid_fuzz(
        normalized,
        seed,
        100,
        GenValidConfig::coverage_forced_default(),
      )
    "gen-valid-stress" =>
      return run_binary_roundtrip_gen_valid_fuzz(
        normalized,
        seed,
        1000,
        GenValidConfig::coverage_forced_default(),
      )
    "byte-fuzz-smoke" => return run_binary_byte_fuzz(normalized, seed, 16)
    "byte-fuzz-ci" => return run_binary_byte_fuzz(normalized, seed, 256)
    "byte-fuzz-stress" => return run_binary_byte_fuzz(normalized, seed, 2048)
    "boundary-smoke" =>
      return binary_roundtrip_boundary_corpus(normalized, seed)
    _ =>
      return Err(
        "unknown binary fuzz profile '\{profile}'; expected smoke|ci|stress|gen-valid-smoke|gen-valid-ci|gen-valid-stress|byte-fuzz-smoke|byte-fuzz-ci|byte-fuzz-stress|boundary-smoke",
      )
  }
  let st = @splitmix.new(seed~)
  let mut attempts = 0
  let instruction_roundtrips = instructions
  let section_roundtrips = section_count * 14
  let immediate_roundtrips = small +
    medium +
    medium +
    block_types +
    floats +
    floats +
    signed_ints

  let _ : Array[TypeIdx] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TypeIdx values")
  }
  attempts += small
  let _ : Array[RefType] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping RefType values")
  }
  attempts += small
  let _ : Array[CompType] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping CompType values")
  }
  attempts += small
  let _ : Array[StorageType] = roundtrip_arbitrary_with_state(small, st) catch {
    _ => return Err("binary fuzz failed while roundtripping StorageType values")
  }
  attempts += small

  let _ : Array[SubType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping SubType values")
  }
  attempts += medium
  let _ : Array[RecType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping RecType values")
  }
  attempts += medium
  let _ : Array[TagType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TagType values")
  }
  attempts += medium
  let _ : Array[MemType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping MemType values")
  }
  attempts += medium
  let _ : Array[TableType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TableType values")
  }
  attempts += medium
  let _ : Array[ExternType] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ExternType values")
  }
  attempts += medium
  let _ : Array[MemArg] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping MemArg values")
  }
  attempts += medium
  let _ : Array[LaneIdx] = roundtrip_arbitrary_with_state(medium, st) catch {
    _ => return Err("binary fuzz failed while roundtripping LaneIdx values")
  }
  attempts += medium

  let _ : Array[F32] = roundtrip_arbitrary_with_state(floats, st) catch {
    _ => return Err("binary fuzz failed while roundtripping F32 values")
  }
  attempts += floats
  let _ : Array[F64] = roundtrip_arbitrary_with_state(floats, st) catch {
    _ => return Err("binary fuzz failed while roundtripping F64 values")
  }
  attempts += floats
  let _ : Array[I64] = roundtrip_arbitrary_with_state(signed_ints, st) catch {
    _ => return Err("binary fuzz failed while roundtripping I64 values")
  }
  attempts += signed_ints
  let _ : Array[BlockType] = roundtrip_arbitrary_with_state(block_types, st) catch {
    _ => return Err("binary fuzz failed while roundtripping BlockType values")
  }
  attempts += block_types
  let _ : Array[Instruction] = roundtrip_arbitrary_with_state(instructions, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Instruction values")
  }
  attempts += instructions

  let _ : Array[CustomSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping CustomSec values")
  }
  attempts += section_count
  let _ : Array[TypeSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TypeSec values")
  }
  attempts += section_count
  let _ : Array[ImportSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ImportSec values")
  }
  attempts += section_count
  let _ : Array[FuncSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping FuncSec values")
  }
  attempts += section_count
  let _ : Array[TableSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TableSec values")
  }
  attempts += section_count
  let _ : Array[MemSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping MemSec values")
  }
  attempts += section_count
  let _ : Array[GlobalSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping GlobalSec values")
  }
  attempts += section_count
  let _ : Array[ExportSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ExportSec values")
  }
  attempts += section_count
  let _ : Array[StartSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping StartSec values")
  }
  attempts += section_count
  let _ : Array[ElemSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping ElemSec values")
  }
  attempts += section_count
  let _ : Array[CodeSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping CodeSec values")
  }
  attempts += section_count
  let _ : Array[DataSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping DataSec values")
  }
  attempts += section_count
  let _ : Array[DataCntSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping DataCntSec values")
  }
  attempts += section_count
  let _ : Array[TagSec] = roundtrip_arbitrary_with_state(section_count, st) catch {
    _ => return Err("binary fuzz failed while roundtripping TagSec values")
  }
  attempts += section_count

  let _ : Array[Elem] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Elem values")
  }
  attempts += large
  let _ : Array[Func] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Func values")
  }
  attempts += large
  let _ : Array[Data] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Data values")
  }
  attempts += large
  let _ : Array[Module] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Module values")
  }
  attempts += large
  let _ : Array[Name] = roundtrip_arbitrary_with_state(large, st) catch {
    _ => return Err("binary fuzz failed while roundtripping Name values")
  }
  attempts += large

  Ok(BinaryRoundtripFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    arbitrary_roundtrips: attempts,
    gen_valid_modules: 0,
    gen_valid_validated: 0,
    byte_fuzz_cases: 0,
    byte_fuzz_decode_rejections: 0,
    byte_fuzz_decode_accepts: 0,
    byte_fuzz_validate_rejections: 0,
    byte_fuzz_stable_roundtrips: 0,
    boundary_roundtrips: 0,
    instruction_roundtrips,
    section_roundtrips,
    immediate_roundtrips,
  })
}
