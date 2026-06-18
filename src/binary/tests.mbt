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
    let val = T::arbitrary(i, st)
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

///|
fn[T] assert_decode_err_contains(
  result : Result[(T, Int), BinaryDecodeError],
  expected : BinaryDecodeError,
) -> Unit raise {
  match result {
    Ok(_) => fail("expected decode failure: \{expected}")
    Err(err) => @debug.assert_eq(err, expected)
  }
}

///|
fn assert_encode_err_contains(
  result : Result[Unit, BinaryEncodeError],
  expected : BinaryEncodeError,
) -> Unit raise {
  match result {
    Ok(_) => fail("expected encode failure: \{expected}")
    Err(err) => @debug.assert_eq(err, expected)
  }
}

///|
test "legacy try without pop instruction roundtrips" {
  let instr = Instruction::try_(
    BlockType::void_(),
    Expr::new([Instruction::nop()]),
    [LegacyCatch::new(TagIdx::new(0U), Expr::new([Instruction::nop()]))],
  )
  let buf = @buffer.new()
  match Encode::encode(instr, buf) {
    Ok(_) => ()
    Err(err) => fail("expected legacy try without pop to encode, got \{err}")
  }
  @debug.assert_eq(buf.to_bytes().to_array(), [
    0x06, 0x40, 0x01, 0x07, 0x00, 0x01, 0x0B,
  ])
  match Decode::decode(buf.to_bytes(), 0) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, buf.length())
      @debug.assert_eq(decoded, instr)
    }
    Err(err) => fail("expected legacy try without pop to decode, got \{err}")
  }
}

///|
test "legacy try catch_all without pop instruction roundtrips" {
  let instr = Instruction::try_(
    BlockType::void_(),
    Expr::new([Instruction::nop()]),
    [LegacyCatch::all(Expr::new([Instruction::nop()]))],
  )
  let buf = @buffer.new()
  match Encode::encode(instr, buf) {
    Ok(_) => ()
    Err(err) =>
      fail("expected legacy try catch_all without pop to encode, got \{err}")
  }
  @debug.assert_eq(buf.to_bytes().to_array(), [
    0x06, 0x40, 0x01, 0x19, 0x01, 0x0B,
  ])
  match Decode::decode(buf.to_bytes(), 0) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, buf.length())
      @debug.assert_eq(decoded, instr)
    }
    Err(err) =>
      fail("expected legacy try catch_all without pop to decode, got \{err}")
  }
}

///|
test "legacy rethrow instruction roundtrips inside catch" {
  let instr = Instruction::try_(
    BlockType::void_(),
    Expr::new([Instruction::throw_(TagIdx::new(0U))]),
    [
      LegacyCatch::new(
        TagIdx::new(0U),
        Expr::new([Instruction::rethrow(LabelIdx::new(0U))]),
      ),
    ],
  )
  let buf = @buffer.new()
  match Encode::encode(instr, buf) {
    Ok(_) => ()
    Err(err) => fail("expected legacy try with rethrow to encode, got \{err}")
  }
  @debug.assert_eq(buf.to_bytes().to_array(), [
    0x06, 0x40, 0x08, 0x00, 0x07, 0x00, 0x09, 0x00, 0x0B,
  ])
  match Decode::decode(buf.to_bytes(), 0) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, buf.length())
      @debug.assert_eq(decoded, instr)
    }
    Err(err) => fail("expected legacy try with rethrow to decode, got \{err}")
  }
}

///|
test "legacy try catch payload pop roundtrips through module binary" {
  let type_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let type_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([type_void, type_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1U))]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::new([LocalRun::new(1U, ValType::i32())]),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                LegacyCatch::new(
                  TagIdx::new(0U),
                  Expr::new([
                    Instruction::pop(ValType::i32()),
                    Instruction::local_set(LocalIdx::new(0U)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => ()
    Err(err) => fail("expected contextual legacy pop module to encode: \{err}")
  }
  let bytes = buf.to_bytes()
  match (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, bytes.length())
      match decoded.code_sec {
        Some(
          CodeSec(
            [Func(_, Expr([Try(_, _, [LegacyCatch(_, Expr(catch_body))], _)]))]
          )
        ) =>
          @debug.assert_eq(catch_body, [
            Instruction::pop(ValType::i32()),
            Instruction::local_set(LocalIdx::new(0U)),
          ])
        _ => fail("expected decoded legacy try catch pop shape")
      }
      match @validate.validate_module(decoded) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "expected decoded contextual legacy pop module to validate: \{@validate.validation_error_message(err)}",
          )
      }
    }
    Err(err) => fail("expected contextual legacy pop module to decode: \{err}")
  }
}

///|
test "legacy multi-payload catch pop prefix preserves lifo order through module binary" {
  let type_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let type_i32_i64 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32(), ValType::i64()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([type_void, type_i32_i64]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1U))]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::new([
            LocalRun::new(1U, ValType::i32()),
            LocalRun::new(1U, ValType::i64()),
          ]),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                LegacyCatch::new(
                  TagIdx::new(0U),
                  Expr::new([
                    Instruction::pop(ValType::i64()),
                    Instruction::pop(ValType::i32()),
                    Instruction::local_set(LocalIdx::new(0U)),
                    Instruction::local_set(LocalIdx::new(1U)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multi-payload contextual pop module to encode: \{err}")
  }
  let bytes = buf.to_bytes()
  match (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, bytes.length())
      match decoded.code_sec {
        Some(
          CodeSec(
            [Func(_, Expr([Try(_, _, [LegacyCatch(_, Expr(catch_body))], _)]))]
          )
        ) =>
          @debug.assert_eq(catch_body, [
            Instruction::pop(ValType::i64()),
            Instruction::pop(ValType::i32()),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::local_set(LocalIdx::new(1U)),
          ])
        _ => fail("expected decoded multi-payload legacy try catch pop shape")
      }
      match @validate.validate_module(decoded) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "expected decoded multi-payload contextual legacy pop module to validate: \{@validate.validation_error_message(err)}",
          )
      }
    }
    Err(err) =>
      fail(
        "expected multi-payload contextual legacy pop module to decode: \{err}",
      )
  }
}

///|
test "legacy interleaved catch payload pops roundtrip through module binary carriers" {
  let type_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let type_i32_i64 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32(), ValType::i64()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([type_void, type_i32_i64]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1U))]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::new([
            LocalRun::new(1U, ValType::i32()),
            LocalRun::new(1U, ValType::i64()),
          ]),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                LegacyCatch::new(
                  TagIdx::new(0U),
                  Expr::new([
                    Instruction::pop(ValType::i64()),
                    Instruction::nop(),
                    Instruction::pop(ValType::i32()),
                    Instruction::local_set(LocalIdx::new(0U)),
                    Instruction::local_set(LocalIdx::new(1U)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => ()
    Err(err) => fail("expected interleaved legacy pop module to encode: \{err}")
  }
  let bytes = buf.to_bytes()
  match (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, bytes.length())
      match @validate.validate_module(decoded) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "expected decoded interleaved legacy pop module to validate: \{@validate.validation_error_message(err)}",
          )
      }
    }
    Err(err) => fail("expected interleaved legacy pop module to decode: \{err}")
  }
}

///|
test "legacy nested catch payload pop roundtrips through module binary carriers" {
  let type_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let type_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([type_void, type_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1U))]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                LegacyCatch::new(
                  TagIdx::new(0U),
                  Expr::new([
                    Instruction::block(
                      BlockType::void_(),
                      Expr::new([
                        Instruction::pop(ValType::i32()),
                        Instruction::drop(),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => ()
    Err(err) => fail("expected nested legacy pop module to encode: \{err}")
  }
  let bytes = buf.to_bytes()
  match (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
    Ok((decoded, pos)) => {
      @debug.assert_eq(pos, bytes.length())
      match @validate.validate_module(decoded) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "expected decoded nested legacy pop module to validate: \{@validate.validation_error_message(err)}",
          )
      }
    }
    Err(err) => fail("expected nested legacy pop module to decode: \{err}")
  }
}

///|
test "encode rejects uncontextualized legacy pop placeholder explicitly" {
  assert_encode_err_contains(
    Encode::encode(Instruction::pop(ValType::i32()), @buffer.new()),
    BinaryEncodeError::CannotEncodeLegacyPop,
  )
  let instr = Instruction::try_(
    BlockType::void_(),
    Expr::new([Instruction::nop()]),
    [
      LegacyCatch::new(
        TagIdx::new(0U),
        Expr::new([Instruction::pop(ValType::i32()), Instruction::drop()]),
      ),
    ],
  )
  assert_encode_err_contains(
    Encode::encode(instr, @buffer.new()),
    BinaryEncodeError::CannotEncodeLegacyPop,
  )
  let type_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let type_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mismatched_mod = Module::new()
    .with_type_sec(TypeSec::new([type_void, type_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1U))]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                LegacyCatch::new(
                  TagIdx::new(0U),
                  Expr::new([
                    Instruction::pop(ValType::i64()),
                    Instruction::drop(),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  assert_encode_err_contains(
    Encode::encode(mismatched_mod, @buffer.new()),
    BinaryEncodeError::CannotEncodeLegacyPop,
  )
  let type_i32_i64 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32(), ValType::i64()], [])),
  )
  let incomplete_prefix_mod = Module::new()
    .with_type_sec(TypeSec::new([type_void, type_i32_i64]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1U))]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::new([LocalRun::new(1U, ValType::i64())]),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                LegacyCatch::new(
                  TagIdx::new(0U),
                  Expr::new([
                    Instruction::pop(ValType::i64()),
                    Instruction::local_set(LocalIdx::new(0U)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  assert_encode_err_contains(
    Encode::encode(incomplete_prefix_mod, @buffer.new()),
    BinaryEncodeError::CannotEncodeLegacyPop,
  )
}

///|
fn binary_test_write_u32_leb(buf : @buffer.Buffer, value : Int) -> Unit {
  encode_unsigned(value.to_uint64(), buf, 32).unwrap()
}

///|
fn binary_test_deep_nested_block_module_bytes(depth : Int) -> Bytes {
  let type_payload = @buffer.new()
  binary_test_write_u32_leb(type_payload, 1)
  type_payload.write_byte(0x60)
  binary_test_write_u32_leb(type_payload, 0)
  binary_test_write_u32_leb(type_payload, 0)

  let func_payload = @buffer.new()
  binary_test_write_u32_leb(func_payload, 1)
  binary_test_write_u32_leb(func_payload, 0)

  let body = @buffer.new()
  binary_test_write_u32_leb(body, 0)
  for _ in 0..<depth {
    body.write_byte(0x02)
    body.write_byte(0x40)
  }
  for _ in 0..<depth {
    body.write_byte(0x0B)
  }
  body.write_byte(0x0B)
  let body_bytes = body.to_bytes()

  let code_payload = @buffer.new()
  binary_test_write_u32_leb(code_payload, 1)
  binary_test_write_u32_leb(code_payload, body_bytes.length())
  code_payload.write_bytes(body_bytes)

  let wasm = @buffer.new()
  wasm.write_bytes(b"\x00\x61\x73\x6D\x01\x00\x00\x00")
  wasm.write_byte(0x01)
  binary_test_write_u32_leb(wasm, type_payload.to_bytes().length())
  wasm.write_bytes(type_payload.to_bytes())
  wasm.write_byte(0x03)
  binary_test_write_u32_leb(wasm, func_payload.to_bytes().length())
  wasm.write_bytes(func_payload.to_bytes())
  wasm.write_byte(0x0A)
  binary_test_write_u32_leb(wasm, code_payload.to_bytes().length())
  wasm.write_bytes(code_payload.to_bytes())
  wasm.to_bytes()
}

///|
test "run_binary_roundtrip_fuzz rejects unknown profile" {
  match run_binary_roundtrip_fuzz("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown binary fuzz profile error")
    Err(msg) => assert_true(msg.contains("unknown binary fuzz profile"))
  }
}

///|
test "run_binary_roundtrip_fuzz covers GenValid full modules" {
  match run_binary_roundtrip_fuzz("gen-valid-smoke", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.profile, "gen-valid-smoke")
      @debug.assert_eq(stats.seed, 0x5eedUL)
      @debug.assert_eq(stats.arbitrary_roundtrips, 0)
      @debug.assert_eq(stats.gen_valid_modules, 8)
      @debug.assert_eq(stats.gen_valid_validated, 8)
      @debug.assert_eq(stats.byte_fuzz_cases, 0)
      @debug.assert_eq(stats.byte_fuzz_decode_rejections, 0)
      @debug.assert_eq(stats.boundary_roundtrips, 0)
      @debug.assert_eq(stats.instruction_roundtrips, 0)
      @debug.assert_eq(stats.section_roundtrips, 0)
      @debug.assert_eq(stats.immediate_roundtrips, 0)
      @debug.assert_eq(stats.attempts, 8)
    }
    Err(msg) => fail("expected GenValid binary roundtrip success: \{msg}")
  }
}

///|
test "run_binary_roundtrip_fuzz covers byte fuzz corruptions" {
  match run_binary_roundtrip_fuzz("byte-fuzz-smoke", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.profile, "byte-fuzz-smoke")
      @debug.assert_eq(stats.seed, 0x5eedUL)
      @debug.assert_eq(stats.arbitrary_roundtrips, 0)
      @debug.assert_eq(stats.gen_valid_modules, 0)
      @debug.assert_eq(stats.byte_fuzz_cases, 16)
      @debug.assert_eq(stats.attempts, 16)
      assert_true(stats.byte_fuzz_decode_rejections > 0)
      assert_true(
        stats.byte_fuzz_decode_accepts + stats.byte_fuzz_decode_rejections == 16,
      )
      @debug.assert_eq(stats.boundary_roundtrips, 0)
      @debug.assert_eq(stats.instruction_roundtrips, 0)
      @debug.assert_eq(stats.section_roundtrips, 0)
      @debug.assert_eq(stats.immediate_roundtrips, 0)
    }
    Err(msg) => fail("expected byte-fuzz binary roundtrip success: \{msg}")
  }
}

///|
test "run_binary_roundtrip_fuzz covers explicit boundary corpus" {
  match run_binary_roundtrip_fuzz("boundary-smoke", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.profile, "boundary-smoke")
      @debug.assert_eq(stats.seed, 0x5eedUL)
      @debug.assert_eq(stats.arbitrary_roundtrips, 0)
      @debug.assert_eq(stats.gen_valid_modules, 0)
      @debug.assert_eq(stats.byte_fuzz_cases, 0)
      @debug.assert_eq(stats.boundary_roundtrips, 40)
      @debug.assert_eq(stats.attempts, 40)
      @debug.assert_eq(stats.instruction_roundtrips, 0)
      @debug.assert_eq(stats.section_roundtrips, 0)
      @debug.assert_eq(stats.immediate_roundtrips, 0)
    }
    Err(msg) =>
      fail("expected boundary corpus binary roundtrip success: \{msg}")
  }
}

///|
test "run_binary_roundtrip_fuzz reports exact arbitrary coverage counters" {
  match run_binary_roundtrip_fuzz("smoke", 0x5eedUL) {
    Ok(stats) => {
      @debug.assert_eq(stats.profile, "smoke")
      @debug.assert_eq(stats.instruction_roundtrips, 1024)
      @debug.assert_eq(stats.section_roundtrips, 224)
      @debug.assert_eq(stats.immediate_roundtrips, 1208)
      assert_true(stats.arbitrary_roundtrips >= stats.instruction_roundtrips)
    }
    Err(msg) => fail("expected smoke binary roundtrip success: \{msg}")
  }
}

///|
test "binary codec errors derive eq show debug" {
  let enc = BinaryEncodeError::CannotEncodeDefTypeHeapType
  let dec = BinaryDecodeError::InvalidCompType
  @debug.assert_eq(enc, BinaryEncodeError::CannotEncodeDefTypeHeapType)
  @debug.assert_eq(dec, BinaryDecodeError::InvalidCompType)
  inspect(enc, content="CannotEncodeDefTypeHeapType")
  inspect(dec, content="InvalidCompType")
  debug_inspect(enc, content="CannotEncodeDefTypeHeapType")
  debug_inspect(dec, content="InvalidCompType")
}

///|
test "module codec wrapper errors derive eq show debug" {
  let enc = EncodeError::Encode(BinaryEncodeError::CannotEncodeBottomValType)
  let dec = DecodeError::Decode(BinaryDecodeError::InvalidModule)
  let trailing = DecodeError::TrailingBytes(1, 1)
  let spanned = DecodeError::DecodeAt(
    BinaryDecodeError::InvalidSectionHeader,
    8,
    2,
  )
  @debug.assert_eq(
    enc,
    EncodeError::Encode(BinaryEncodeError::CannotEncodeBottomValType),
  )
  @debug.assert_eq(dec, DecodeError::Decode(BinaryDecodeError::InvalidModule))
  @debug.assert_eq(trailing, DecodeError::TrailingBytes(1, 1))
  @debug.assert_eq(
    spanned,
    DecodeError::DecodeAt(BinaryDecodeError::InvalidSectionHeader, 8, 2),
  )
  inspect(enc, content="Encode(CannotEncodeBottomValType)")
  inspect(dec, content="Decode(InvalidModule)")
  inspect(trailing, content="TrailingBytes(1, 1)")
  inspect(spanned, content="DecodeAt(InvalidSectionHeader, 8, 2)")
  debug_inspect(enc, content="Encode(CannotEncodeBottomValType)")
  debug_inspect(dec, content="Decode(InvalidModule)")
  debug_inspect(trailing, content="TrailingBytes(1, 1)")
  debug_inspect(spanned, content="DecodeAt(InvalidSectionHeader, 8, 2)")
}

///|
test "decode_module wraps decode success and malformed extra bytes as decode errors" {
  let mod = Module::new()
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected wrapper encode success: \{e}")
  }
  match decode_module(wasm) {
    Ok(decoded) => @debug.assert_eq(decoded, mod)
    Err(e) => fail("expected wrapper decode success: \{e}")
  }
  let trailing = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x7f"
  match decode_module(trailing) {
    Ok(_) => fail("expected malformed extra-bytes decode failure")
    Err(DecodeError::TrailingBytes(offset, len)) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 1)
    }
    Err(e) => fail("expected decode-error variant, got \{e}")
  }
}

///|
test "decode_module attaches section spans to wrapper decode errors" {
  let bad_standard = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x02\x00"
  match decode_module(bad_standard) {
    Ok(_) => fail("expected decode failure for malformed section")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::SectionPayloadLengthOutOfRange,
        offset,
        len
      )
    ) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 3)
    }
    Err(e) => fail("expected section span decode error, got \{e}")
  }

  let bad_custom = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x02\x00"
  match decode_module(bad_custom) {
    Ok(_) => fail("expected decode failure for malformed custom section")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::CustomSectionPayloadLengthOutOfRange,
        offset,
        len
      )
    ) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 3)
    }
    Err(e) => fail("expected custom-section span decode error, got \{e}")
  }
}

///|
test "FUZ1056A1 curated invalid binary reports byte offset and section span" {
  let bad_type_payload = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x03\x01\x00\x00"
  match decode_module(bad_type_payload) {
    Ok(_) => fail("expected curated malformed type section fixture to fail")
    Err(DecodeError::DecodeAt(BinaryDecodeError::InvalidCompType, offset, len)) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 5)
    }
    Err(e) => fail("expected curated type-section span decode error, got \{e}")
  }
  match decode_module_with_detail(bad_type_payload, 0) {
    Ok(_) => fail("expected detailed malformed type section fixture to fail")
    Err(detail) => {
      @debug.assert_eq(detail.err, BinaryDecodeError::InvalidCompType)
      @debug.assert_eq(detail.section_id, Some(1))
      @debug.assert_eq(detail.section_offset, Some(8))
      @debug.assert_eq(detail.section_len, Some(5))
    }
  }
}

///|
test "decode_module reports section span for non-length type section decode errors" {
  let bad_type_payload = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x03\x01\x00\x00"
  match decode_module(bad_type_payload) {
    Ok(_) => fail("expected decode failure for invalid type section payload")
    Err(DecodeError::DecodeAt(BinaryDecodeError::InvalidCompType, offset, len)) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 5)
    }
    Err(e) => fail("expected type-section span decode error, got \{e}")
  }
}

///|
test "decode_module reports section span for non-length custom section decode errors" {
  let bad_custom_name = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x01\x80"
  match decode_module(bad_custom_name) {
    Ok(_) => fail("expected decode failure for malformed custom section name")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::UnexpectedEofInUnsignedLeb,
        offset,
        len
      )
    ) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 3)
    }
    Err(e) => fail("expected custom-section span decode error, got \{e}")
  }
}

///|
test "decode_module wraps decode failure variant" {
  match decode_module(b"not-wasm") {
    Ok(_) => fail("expected decode wrapper failure")
    Err(DecodeError::Decode(err)) =>
      @debug.assert_eq(err, BinaryDecodeError::InvalidMagicHeader)
    Err(e) => fail("expected decode-error variant, got \{e}")
  }
}

///|
test "module roundtrip preserves raw high-type-index loop seed ordering" {
  let types : Array[RecType] = []
  for i = 0; i < 291; i = i + 1 {
    let rec_type = if i == 289 {
      RecType::new(SubType::comp_type(CompType::func([ValType::i32()], [])))
    } else if i == 290 {
      RecType::new(SubType::comp_type(CompType::func([], [])))
    } else {
      RecType::new(SubType::comp_type(CompType::func([], [])))
    }
    types.push(rec_type)
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new(types))
    .with_func_sec(FuncSec::new([TypeIdx::new(290U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::from_types([ValType::i32()]),
          Expr::new([
            Instruction::i32_const(I32(0)),
            Instruction::loop_(
              BlockType::type_idx(TypeIdx::new(289U)),
              Expr::new([
                Instruction::local_tee(LocalIdx::new(0U)),
                Instruction::i32_const(I32(1)),
                Instruction::i32_lt_s(),
                Instruction::if_(
                  BlockType::void_(),
                  [
                    Instruction::local_get(LocalIdx::new(0U)),
                    Instruction::i32_const(I32(1)),
                    Instruction::i32_add(),
                    Instruction::br(LabelIdx::new(0U)),
                  ],
                  Some([]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected encode success, got \{e}")
  }
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  match decoded.code_sec {
    Some(
      CodeSec(
        [
          Func(
            _,
            Expr(
              [
                I32Const(I32(seed)),
                Loop(
                  TypeIdxBlockType(TypeIdx(loop_type_idx)),
                  Expr(
                    [
                      LocalTee(LocalIdx(tee_idx)),
                      I32Const(I32(limit)),
                      I32LtS,
                      If(
                        VoidBlockType,
                        [
                          LocalGet(LocalIdx(br_arg_idx)),
                          I32Const(I32(step)),
                          I32Add,
                          Br(LabelIdx(br_label)),
                        ],
                        Some([])
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
      @debug.assert_eq(seed, 0)
      @debug.assert_eq(loop_type_idx, 289U)
      @debug.assert_eq(tee_idx, 0U)
      @debug.assert_eq(limit, 1)
      @debug.assert_eq(br_arg_idx, 0U)
      @debug.assert_eq(step, 1)
      @debug.assert_eq(br_label, 0U)
    }
    _ =>
      fail(
        "expected raw high-type-index loop seed to stay before the decoded loop",
      )
  }
}

///|
test "module roundtrip preserves raw high-type-index multi-value loop seed ordering" {
  let types : Array[RecType] = []
  for i = 0; i < 361; i = i + 1 {
    let rec_type = if i == 352 {
      RecType::new(
        SubType::comp_type(
          CompType::func([], [ValType::i32(), ValType::i32(), ValType::i32()]),
        ),
      )
    } else if i == 360 {
      RecType::new(
        SubType::comp_type(
          CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
          ]),
        ),
      )
    } else {
      RecType::new(SubType::comp_type(CompType::func([], [])))
    }
    types.push(rec_type)
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new(types))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::from_types([ValType::i32(), ValType::i32(), ValType::i32()]),
          Expr::new([
            Instruction::block(
              BlockType::type_idx(TypeIdx::new(352U)),
              Expr::new([
                Instruction::i32_const(I32(1)),
                Instruction::i32_const(I32(2)),
                Instruction::i32_const(I32(3)),
              ]),
            ),
            Instruction::local_set(LocalIdx::new(2U)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::loop_(
              BlockType::type_idx(TypeIdx::new(360U)),
              Expr::new([
                Instruction::local_tee(LocalIdx::new(0U)),
                Instruction::local_get(LocalIdx::new(1U)),
                Instruction::local_get(LocalIdx::new(2U)),
              ]),
            ),
            Instruction::drop(),
            Instruction::drop(),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected encode success, got \{e}")
  }
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  match decoded.code_sec {
    Some(
      CodeSec(
        [
          Func(
            _,
            Expr(
              [
                Block(
                  TypeIdxBlockType(TypeIdx(seed_block_type_idx)),
                  Expr([I32Const(I32(a)), I32Const(I32(b)), I32Const(I32(c))])
                ),
                LocalSet(LocalIdx(seed_local_2)),
                LocalSet(LocalIdx(seed_local_1)),
                Loop(
                  TypeIdxBlockType(TypeIdx(loop_type_idx)),
                  Expr(
                    [
                      LocalTee(LocalIdx(loop_local)),
                      LocalGet(LocalIdx(get_local_1)),
                      LocalGet(LocalIdx(get_local_2)),
                    ]
                  )
                ),
                Drop,
                Drop,
                Drop,
              ]
            )
          ),
        ]
      )
    ) => {
      @debug.assert_eq(seed_block_type_idx, 352U)
      @debug.assert_eq(a, 1)
      @debug.assert_eq(b, 2)
      @debug.assert_eq(c, 3)
      @debug.assert_eq(seed_local_2, 2U)
      @debug.assert_eq(seed_local_1, 1U)
      @debug.assert_eq(loop_type_idx, 360U)
      @debug.assert_eq(loop_local, 0U)
      @debug.assert_eq(get_local_1, 1U)
      @debug.assert_eq(get_local_2, 2U)
    }
    _ =>
      fail(
        "expected raw high-type-index multi-value loop seeds to stay before the decoded loop",
      )
  }
}

///|
test "encode_module roundtrips raw nested branch ladder that skips later returns" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::block(
                  BlockType::void_(),
                  Expr::new([
                    Instruction::local_get(LocalIdx::new(0U)),
                    Instruction::if_(
                      BlockType::val_type(ValType::i64()),
                      [
                        Instruction::local_get(LocalIdx::new(0U)),
                        Instruction::drop(),
                        Instruction::br(LabelIdx::new(1U)),
                      ],
                      Some([
                        Instruction::local_get(LocalIdx::new(0U)),
                        Instruction::if_(
                          BlockType::val_type(ValType::i64()),
                          [
                            Instruction::local_get(LocalIdx::new(0U)),
                            Instruction::drop(),
                            Instruction::br(LabelIdx::new(2U)),
                          ],
                          Some([
                            Instruction::local_get(LocalIdx::new(0U)),
                            Instruction::if_(
                              BlockType::val_type(ValType::i64()),
                              [
                                Instruction::local_get(LocalIdx::new(0U)),
                                Instruction::drop(),
                                Instruction::br(LabelIdx::new(4U)),
                              ],
                              Some([
                                Instruction::local_get(LocalIdx::new(0U)),
                                Instruction::if_(
                                  BlockType::val_type(ValType::i64()),
                                  [
                                    Instruction::local_get(LocalIdx::new(0U)),
                                    Instruction::drop(),
                                    Instruction::br(LabelIdx::new(5U)),
                                  ],
                                  Some([
                                    Instruction::i64_const(I64(4294967296L)),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    Instruction::return_(),
                  ]),
                ),
                Instruction::i64_const(I64(0L)),
                Instruction::return_(),
              ]),
            ),
            Instruction::i64_const(I64(1L)),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected raw nested branch ladder fixture to validate before encode, got \{@validate.validation_error_message(e)}",
      )
  }
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected raw nested branch ladder encode success, got \{e}")
  }
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected raw nested branch ladder decode success, got \{e}")
  }
  match @validate.validate_module(decoded) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected raw nested branch ladder fixture to stay valid after encode, got \{@validate.validation_error_message(e)}",
      )
  }
}

///|
test "decode_module accepts elem header 6 with explicit reftype and roundtrips module semantics" {
  let wasm = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x09\x0b\x01\x06\x00\x41\x00\x0b\x70\x01\xd2\x00\x0b"
  let mod = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected elem header 6 decode success, got \{e}")
  }
  let reencoded = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected re-encode success for header 6 fixture, got \{e}")
  }
  let reparsed = match decode_module(reencoded) {
    Ok(v) => v
    Err(e) => fail("expected decode success after re-encode, got \{e}")
  }
  @debug.assert_eq(reparsed, mod)
}

///|
test "decode_module accepts shared memory imports and encode_module preserves them" {
  let wasm = Bytes::from_array([
    0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00, 0x02, 0x07, 0x01, 0x00, 0x00,
    0x02, 0x03, 0x00, 0x0A,
  ])
  let mod = match decode_module(wasm) {
    Ok(mod) => mod
    Err(err) => fail("expected shared-memory import decode success, got \{err}")
  }
  match @validate.validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail("expected shared-memory import module to validate, got \{err}")
  }
  let reencoded = match encode_module(mod) {
    Ok(wasm) => wasm
    Err(err) =>
      fail("expected shared-memory import module to re-encode, got \{err}")
  }
  @debug.assert_eq(reencoded, wasm)
}

///|
test "decode_module accepts shared memories without max but validation rejects them" {
  let wasm = Bytes::from_array([
    0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00, 0x02, 0x06, 0x01, 0x00, 0x00,
    0x02, 0x02, 0x00,
  ])
  let mod = match decode_module(wasm) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected shared-memory-without-max decode success for validator coverage, got \{err}",
      )
  }
  match @validate.validate_module(mod) {
    Ok(_) => fail("expected shared-memory-without-max validation failure")
    Err(err) =>
      assert_true(
        @validate.validation_error_message(err).contains(
          "shared memories require a max",
        ),
      )
  }
}

///|
test "encode elem active non-zero table func exprs includes explicit funcref reftype for header 6" {
  let elem = Elem::new(
    ElemMode::active(
      TableIdx::new(1),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    ElemKind::func_exprs([Expr::new([Instruction::ref_func(FuncIdx::new(0))])]),
  )
  let buf = @buffer.new()
  match Encode::encode(elem, buf) {
    Ok(_) => ()
    Err(e) => fail("expected elem encode success, got \{e}")
  }
  let bytes = buf.to_bytes()
  @debug.assert_eq(bytes, b"\x06\x01\x41\x00\x0b\x70\x01\xd2\x00\x0b")
  let (decoded, i) = match
    (Decode::decode(bytes, 0) : Result[(Elem, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => fail("expected elem decode success, got \{e}")
  }
  @debug.assert_eq(i, bytes.length())
  @debug.assert_eq(decoded, elem)
}

///|
test "encode elem supports active typed expr segments for header 6" {
  let rt = RefType::new(true, HeapType::abs(AbsHeapType::extern_()))
  let elem = Elem::new(
    ElemMode::active(
      TableIdx::new(0),
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    ElemKind::typed_exprs(rt, [
      Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::extern_()))]),
    ]),
  )
  let buf = @buffer.new()
  match Encode::encode(elem, buf) {
    Ok(_) => ()
    Err(e) => fail("expected active typed elem encode success, got \{e}")
  }
  let bytes = buf.to_bytes()
  let (decoded, i) = match
    (Decode::decode(bytes, 0) : Result[(Elem, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => fail("expected active typed elem decode success, got \{e}")
  }
  @debug.assert_eq(i, bytes.length())
  @debug.assert_eq(decoded, elem)
}

///|
test "decode_module preserves trailing-byte diagnostics for section-order and duplicate-section invalid modules" {
  let vectors : Array[(String, Bytes, Int, Int)] = [
    (
      "duplicate type section", b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x01\x00\x01\x01\x00",
      11, 3,
    ),
    (
      "out-of-order type section after import section", b"\x00\x61\x73\x6d\x01\x00\x00\x00\x02\x01\x00\x01\x01\x00",
      11, 3,
    ),
  ]
  for vector in vectors {
    let (name, bytes, expected_offset, expected_len) = vector
    match
      (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected raw module decode failure for '\{name}'")
      Err(err) => @debug.assert_eq(err, BinaryDecodeError::InvalidModule)
    }
    match decode_module(bytes) {
      Ok(_) => fail("expected wrapper decode failure for '\{name}'")
      Err(DecodeError::TrailingBytes(offset, len)) => {
        @debug.assert_eq(offset, expected_offset)
        @debug.assert_eq(len, expected_len)
      }
      Err(e) =>
        fail("expected trailing-byte wrapper error for '\{name}', got \{e}")
    }
  }
}

///|
test "encode_module wraps encode failure variant" {
  let bad = Module::new().with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([ValType::bottom()], []))),
    ]),
  )
  match encode_module(bad) {
    Ok(_) => fail("expected encode wrapper failure")
    Err(EncodeError::Encode(err)) =>
      @debug.assert_eq(err, BinaryEncodeError::CannotEncodeBottomValType)
  }
}

///|
test "FUZ1057B1 uleb encoder emits compact canonical byte forms" {
  let cases : Array[(UInt64, Bytes)] = [
    (0UL, b"\x00"),
    (1UL, b"\x01"),
    (127UL, b"\x7f"),
    (128UL, b"\x80\x01"),
    (624485UL, b"\xe5\x8e\x26"),
    (0xffffffffUL, b"\xff\xff\xff\xff\x0f"),
  ]
  for case in cases {
    let (value, expected) = case
    let buf = @buffer.new()
    encode_unsigned(value, buf, 32).unwrap()
    let bytes = buf.to_bytes()
    @debug.assert_eq(bytes, expected)
    let (decoded, next) = decode_unsigned(bytes, 0, 32).unwrap()
    @debug.assert_eq(decoded, value)
    @debug.assert_eq(next, expected.length())
  }
}

///|
test "FUZ1057B1 uleb decoder accepts overwide well-formed unsigned forms" {
  let cases : Array[(Bytes, UInt64)] = [
    (b"\x80\x00", 0UL),
    (b"\x81\x00", 1UL),
    (b"\xff\x00", 127UL),
    (b"\x80\x81\x00", 128UL),
  ]
  for case in cases {
    let (bytes, expected) = case
    let (decoded, next) = decode_unsigned(bytes, 0, 32).unwrap()
    @debug.assert_eq(decoded, expected)
    @debug.assert_eq(next, bytes.length())
  }
}

///|
test "FUZ1057B3 section sizes and custom payloads encode canonically and roundtrip" {
  let custom_buf = @buffer.new()
  match
    Encode::encode(CustomSec::new(Name::new("x"), b"\x01\x02\x03"), custom_buf) {
    Ok(_) => ()
    Err(e) => fail("expected custom section encode success, got \{e}")
  }
  let custom = custom_buf.to_bytes()
  @debug.assert_eq(custom, b"\x00\x05\x01x\x01\x02\x03")
  let wasm = b"\x00\x61\x73\x6d\x01\x00\x00\x00" + custom
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected custom-section decode success, got \{e}")
  }
  let reencoded = match encode_module(decoded) {
    Ok(bytes) => bytes
    Err(e) => fail("expected custom-section re-encode success, got \{e}")
  }
  @debug.assert_eq(reencoded, wasm)
}

///|
test "FUZ1057B3 fixed-width NaN payload bytes are preserved" {
  let f32_nan_payload = b"\x01\x00\xc0\x7f"
  let (f32_value, f32_next) = (
    Decode::decode(f32_nan_payload, 0) : Result[(F32, Int), BinaryDecodeError]).unwrap()
  @debug.assert_eq(f32_next, f32_nan_payload.length())
  let f32_buf = @buffer.new()
  Encode::encode(f32_value, f32_buf).unwrap()
  @debug.assert_eq(f32_buf.to_bytes(), f32_nan_payload)

  let f64_nan_payload = b"\x01\x00\x00\x00\x00\x00\xf8\x7f"
  let (f64_value, f64_next) = (
    Decode::decode(f64_nan_payload, 0) : Result[(F64, Int), BinaryDecodeError]).unwrap()
  @debug.assert_eq(f64_next, f64_nan_payload.length())
  let f64_buf = @buffer.new()
  Encode::encode(f64_value, f64_buf).unwrap()
  @debug.assert_eq(f64_buf.to_bytes(), f64_nan_payload)
}

///|
test "uleb roundtrip u33" {
  let vals : Array[UInt64] = [0, 1, 127, 128, 129, 0xffff, 0xffffffff]
  for v in vals {
    let buf = @buffer.new()
    encode_unsigned(v, buf, 33).unwrap()
    let bytes = buf.to_bytes()
    let (v2, i2) = decode_unsigned(bytes, 0, 33).unwrap()
    @debug.assert_eq(v2, v)
    @debug.assert_eq(i2, bytes.length())
  }
}

///|
test "FUZ1057B2 sleb encoder emits compact signed boundary forms" {
  let cases : Array[(Int64, Bytes)] = [
    (0L, b"\x00"),
    (1L, b"\x01"),
    (-1L, b"\x7f"),
    (63L, b"\x3f"),
    (-64L, b"\x40"),
    (64L, b"\xc0\x00"),
    (-65L, b"\xbf\x7f"),
  ]
  for case in cases {
    let (value, expected) = case
    let buf = @buffer.new()
    encode_signed(value, buf, 32).unwrap()
    let bytes = buf.to_bytes()
    @debug.assert_eq(bytes, expected)
    let (decoded, next) = decode_signed(bytes, 0, 32).unwrap()
    @debug.assert_eq(decoded, value)
    @debug.assert_eq(next, expected.length())
  }
}

///|
test "FUZ1057B2 sleb decoder accepts bounded overwide sign extension" {
  let cases : Array[(Bytes, Int64)] = [
    (b"\x80\x00", 0L),
    (b"\xff\x7f", -1L),
    (b"\xbf\x00", 63L),
    (b"\xc0\x7f", -64L),
  ]
  for case in cases {
    let (bytes, expected) = case
    let (decoded, next) = decode_signed(bytes, 0, 32).unwrap()
    @debug.assert_eq(decoded, expected)
    @debug.assert_eq(next, bytes.length())
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
    @debug.assert_eq(v2, v)
    @debug.assert_eq(i2, bytes.length())
  }
}

///|
test "uleb rejects terminal unused bits at max width" {
  let bytes : Bytes = [
    0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x02,
  ]
  match decode_unsigned(bytes, 0, 64) {
    Ok(_) => fail("expected error")
    Err(err) =>
      @debug.assert_eq(
        err,
        BinaryDecodeError::UnsignedLebTerminalHasNonZeroUnusedBits,
      )
  }
}

///|
test "sleb s33 accepts 0x3f" {
  match decode_signed(b"\x3f", 0, 33) {
    Ok((value, _)) => @debug.assert_eq(value, 63L)
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "uleb u33 rejects too many bytes" {
  let bytes : Bytes = [0x80, 0x80, 0x80, 0x80, 0x80, 0x00]
  match decode_unsigned(bytes, 0, 33) {
    Ok(_) => fail("expected error")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::UnsignedLebTooManyBytes)
  }
}

///|
test "uleb allows trailing zeros within max bytes" {
  let bytes : Bytes = [0x83, 0x00]
  let (v, i) = decode_unsigned(bytes, 0, 8).unwrap()
  @debug.assert_eq(v, 3)
  @debug.assert_eq(i, 2)
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
    @debug.assert_eq(v2, v)
    @debug.assert_eq(i2, bytes.length())
  }
}

///|
test "uleb allows trailing zeros within bound" {
  let (v, i) = decode_unsigned(b"\x83\x00", 0, 8).unwrap()
  @debug.assert_eq(v, 3UL)
  @debug.assert_eq(i, 2)
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
    @debug.assert_eq(v2, v)
    @debug.assert_eq(i2, bytes.length())
  }
}

///|
test "decode S33 accepts full unsigned upper bound" {
  let max_u32_in_s33 : Int64 = (1L << 32) - 1L
  let buf = @buffer.new()
  encode_signed(max_u32_in_s33, buf, 33).unwrap()
  let bytes = buf.to_bytes()
  let decoded : Result[(S33, Int), BinaryDecodeError] = Decode::decode(bytes, 0)
  match decoded {
    Ok((S33(v), i)) => {
      @debug.assert_eq(v, 0xffffffff)
      @debug.assert_eq(i, bytes.length())
    }
    Err(e) => fail("expected S33 upper bound to decode, got error: \{e}")
  }
}

///|
test "S33 roundtrip includes upper bound" {
  let values : Array[S33] = [S33(0), S33(1), S33(0xffffffff)]
  for value in values {
    roundtrip(value)
  }
}

///|
test "sleb s33 rejects too many bytes" {
  match decode_signed(b"\x80\x80\x80\x80\x80\x00", 0, 33) {
    Ok(_) => fail("expected error")
    Err(err) => @debug.assert_eq(err, BinaryDecodeError::SignedLebTooManyBytes)
  }
}

///|
test "sleb allows extra sign extension within bound" {
  let (v, i) = decode_signed(b"\xff\x7f", 0, 8).unwrap()
  @debug.assert_eq(v, -1)
  @debug.assert_eq(i, 2)
}

///|
test "sleb rejects malformed sign-extension bits" {
  match decode_signed(b"\xff\xff\xff\xff\x5f", 0, 33) {
    Ok(_) => fail("expected malformed sign-extension error")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::SignedLebOutOfRangeForBitWidth)
  }
}

///|
test "optional decode fallthrough keeps cursor on decode failure" {
  let (none1, i1) = (
    Decode::decode(b"\x02", 0) : Result[(Bool?, Int), BinaryDecodeError]).unwrap()
  @debug.assert_eq(none1, None)
  @debug.assert_eq(i1, 0)

  let (none2, i2) = (
    Decode::decode(b"", 0) : Result[(Bool?, Int), BinaryDecodeError]).unwrap()
  @debug.assert_eq(none2, None)
  @debug.assert_eq(i2, 0)
}

///|
test "numeric decoders reject out-of-bounds fixed-width loads" {
  assert_decode_err_contains(
    (Decode::decode(b"\x00\x00\x00", 0) : Result[(F32, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x00\x00\x00\x00\x00\x00", 0) :
      Result[(F64, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
}

///|
test "decode helpers reject invalid bit widths and truncated inputs" {
  match decode_unsigned(b"\x00", 0, 0) {
    Ok(_) => fail("expected invalid nbits error for uleb nbits=0")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::InvalidUnsignedLebBitWidth)
  }
  match decode_unsigned(b"\x00", 0, 65) {
    Ok(_) => fail("expected invalid nbits error for uleb nbits=65")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::InvalidUnsignedLebBitWidth)
  }
  match decode_unsigned(b"\x80", 0, 8) {
    Ok(_) => fail("expected EOF error for unterminated uleb")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::UnexpectedEofInUnsignedLeb)
  }
  match decode_signed(b"\x00", 0, 0) {
    Ok(_) => fail("expected invalid nbits error for sleb nbits=0")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::InvalidSignedLebBitWidth)
  }
  match decode_signed(b"\x00", 0, 65) {
    Ok(_) => fail("expected invalid nbits error for sleb nbits=65")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::InvalidSignedLebBitWidth)
  }
  match decode_signed(b"\x80", 0, 8) {
    Ok(_) => fail("expected EOF error for unterminated sleb")
    Err(err) =>
      @debug.assert_eq(err, BinaryDecodeError::UnexpectedEofInSignedLeb)
  }
}

///|
test "bool decode rejects invalid byte and out of bounds" {
  let invalid : Result[(Bool, Int), BinaryDecodeError] = Decode::decode(
    b"\x02", 0,
  )
  assert_decode_err_contains(invalid, BinaryDecodeError::InvalidBoolByte)
  let oob : Result[(Bool, Int), BinaryDecodeError] = Decode::decode(b"", 0)
  assert_decode_err_contains(oob, BinaryDecodeError::IndexOutOfBounds)
}

///|
test "decode reports invalid bytes for instruction and lane index" {
  assert_decode_err_contains(
    (Decode::decode(b"\xFF", 0) : Result[(Instruction, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidInstruction,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x10", 0) : Result[(LaneIdx, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidLaneIndex,
  )
}

///|
test "decode i8x16.shuffle preserves all 16 lane indices in order" {
  let bytes : Bytes = [
    0xFD, 0x0D, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A,
    0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
  ]
  match
    (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]) {
    Ok((instr, next)) => {
      @debug.assert_eq(
        instr,
        Instruction::i8x16_shuffle(
          LaneIdx::new(0),
          LaneIdx::new(1),
          LaneIdx::new(2),
          LaneIdx::new(3),
          LaneIdx::new(4),
          LaneIdx::new(5),
          LaneIdx::new(6),
          LaneIdx::new(7),
          LaneIdx::new(8),
          LaneIdx::new(9),
          LaneIdx::new(10),
          LaneIdx::new(11),
          LaneIdx::new(12),
          LaneIdx::new(13),
          LaneIdx::new(14),
          LaneIdx::new(15),
        ),
      )
      @debug.assert_eq(next, bytes.length())
    }
    Err(e) => fail("unexpected shuffle decode failure: \{e}")
  }
}

///|
test "relaxed SIMD instructions use exact 0xFD subopcode roundtrips" {
  let cases : Array[(String, Instruction, Bytes)] = [
    (
      "i8x16.relaxed_swizzle",
      Instruction::i8x16_relaxed_swizzle(),
      b"\xFD\x80\x02",
    ),
    (
      "i32x4.relaxed_trunc_f32x4_s",
      Instruction::i32x4_relaxed_trunc_f32x4s(),
      b"\xFD\x81\x02",
    ),
    (
      "i32x4.relaxed_trunc_f32x4_u",
      Instruction::i32x4_relaxed_trunc_f32x4u(),
      b"\xFD\x82\x02",
    ),
    (
      "i32x4.relaxed_trunc_zero_f64x2_s",
      Instruction::i32x4_relaxed_trunc_zero_f64x2s(),
      b"\xFD\x83\x02",
    ),
    (
      "i32x4.relaxed_trunc_zero_f64x2_u",
      Instruction::i32x4_relaxed_trunc_zero_f64x2u(),
      b"\xFD\x84\x02",
    ),
    ("f32x4.relaxed_madd", Instruction::f32x4_relaxed_madd(), b"\xFD\x85\x02"),
    ("f32x4.relaxed_nmadd", Instruction::f32x4_relaxed_nmadd(), b"\xFD\x86\x02"),
    ("f64x2.relaxed_madd", Instruction::f64x2_relaxed_madd(), b"\xFD\x87\x02"),
    ("f64x2.relaxed_nmadd", Instruction::f64x2_relaxed_nmadd(), b"\xFD\x88\x02"),
    (
      "i8x16.relaxed_laneselect",
      Instruction::i8x16_relaxed_laneselect(),
      b"\xFD\x89\x02",
    ),
    (
      "i16x8.relaxed_laneselect",
      Instruction::i16x8_relaxed_laneselect(),
      b"\xFD\x8A\x02",
    ),
    (
      "i32x4.relaxed_laneselect",
      Instruction::i32x4_relaxed_laneselect(),
      b"\xFD\x8B\x02",
    ),
    (
      "i64x2.relaxed_laneselect",
      Instruction::i64x2_relaxed_laneselect(),
      b"\xFD\x8C\x02",
    ),
    ("f32x4.relaxed_min", Instruction::f32x4_relaxed_min(), b"\xFD\x8D\x02"),
    ("f32x4.relaxed_max", Instruction::f32x4_relaxed_max(), b"\xFD\x8E\x02"),
    ("f64x2.relaxed_min", Instruction::f64x2_relaxed_min(), b"\xFD\x8F\x02"),
    ("f64x2.relaxed_max", Instruction::f64x2_relaxed_max(), b"\xFD\x90\x02"),
    (
      "i16x8.relaxed_q15mulr_s",
      Instruction::i16x8_relaxed_q15mulr_s(),
      b"\xFD\x91\x02",
    ),
    (
      "i16x8.relaxed_dot_i8x16_i7x16_s",
      Instruction::i16x8_relaxed_dot_i8x16i7x16s(),
      b"\xFD\x92\x02",
    ),
    (
      "i32x4.relaxed_dot_i8x16_i7x16_add_s",
      Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s(),
      b"\xFD\x93\x02",
    ),
  ]
  for case in cases {
    let (name, expected_instr, expected_bytes) = case
    let buf = @buffer.new()
    match Encode::encode(expected_instr, buf) {
      Ok(_) => @debug.assert_eq(buf.to_bytes(), expected_bytes)
      Err(e) =>
        fail("expected relaxed SIMD encode success for \{name}, got \{e}")
    }
    match
      (
        Decode::decode(expected_bytes, 0) :
        Result[(Instruction, Int), BinaryDecodeError]) {
      Ok((decoded, next)) => {
        @debug.assert_eq(decoded, expected_instr)
        @debug.assert_eq(next, expected_bytes.length())
      }
      Err(e) =>
        fail("expected relaxed SIMD decode success for \{name}, got \{e}")
    }
  }
}

///|
test "struct atomic get instruction encode decode opcodes" {
  let cases = [
    (
      "struct.atomic.get acq_rel",
      Instruction::struct_atomic_get(
        AtomicOrder::acq_rel(),
        TypeIdx::new(0U),
        U32(0U),
      ),
      b"\xFE\x5C\x01\x00\x00",
    ),
    (
      "struct.atomic.get_s seq_cst",
      Instruction::struct_atomic_get_s(
        AtomicOrder::seq_cst(),
        TypeIdx::new(1U),
        U32(2U),
      ),
      b"\xFE\x5D\x00\x01\x02",
    ),
    (
      "struct.atomic.get_u acq_rel",
      Instruction::struct_atomic_get_u(
        AtomicOrder::acq_rel(),
        TypeIdx::new(2U),
        U32(3U),
      ),
      b"\xFE\x5E\x01\x02\x03",
    ),
  ]
  for case in cases {
    let (name, expected_instr, expected_bytes) = case
    let buf = @buffer.new()
    match Encode::encode(expected_instr, buf) {
      Ok(_) => @debug.assert_eq(buf.to_bytes(), expected_bytes)
      Err(e) =>
        fail("expected struct atomic get encode success for \{name}, got \{e}")
    }
    match
      (
        Decode::decode(expected_bytes, 0) :
        Result[(Instruction, Int), BinaryDecodeError]) {
      Ok((decoded, next)) => {
        @debug.assert_eq(decoded, expected_instr)
        @debug.assert_eq(next, expected_bytes.length())
      }
      Err(e) =>
        fail("expected struct atomic get decode success for \{name}, got \{e}")
    }
  }
}

///|
test "decode reports invalid atomic.fence immediate" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\xFE\x03\x01", 0) :
      Result[(Instruction, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidAtomicFenceImmediate,
  )
}

///|
test "type section decode reports payload EOF and trailing bytes" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x01\x03\x00", 0) :
      Result[(TypeSec, Int), BinaryDecodeError]),
    BinaryDecodeError::SectionPayloadLengthOutOfRange,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x01\x02\x00\x00", 0) :
      Result[(TypeSec, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidSectionPayloadTrailingBytes,
  )
}

///|
test "section payload decoders consume exact spans from nonzero offsets" {
  match
    (
      Decode::decode(b"\xFF\xFF\x01\x01\x00", 2) :
      Result[(TypeSec, Int), BinaryDecodeError]) {
    Ok((sec, next)) => {
      @debug.assert_eq(sec, TypeSec::new([]))
      @debug.assert_eq(next, 5)
    }
    Err(err) => fail("expected nonzero-offset type section decode, got \{err}")
  }

  match
    (
      Decode::decode(b"\xFF\x0E\x06\x00\x01\x03abc", 1) :
      Result[(StringRefsSec, Int), BinaryDecodeError]) {
    Ok((sec, next)) => {
      @debug.assert_eq(sec, StringRefsSec::new([b"abc"]))
      @debug.assert_eq(next, 9)
    }
    Err(err) =>
      fail("expected nonzero-offset string refs section decode, got \{err}")
  }
}

///|
test "module decode bubbles section errors instead of generic invalid module" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x02\x00", 0) :
      Result[(Module, Int), BinaryDecodeError]),
    BinaryDecodeError::CustomSectionPayloadLengthOutOfRange,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x02\x01\xFF", 0) :
      Result[(Module, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidCompType,
  )
}

///|
test "decode_module accepts deep nested block modules up to the nesting limit" {
  let wasm = binary_test_deep_nested_block_module_bytes(10000)
  match decode_module(wasm) {
    Ok(_) => ()
    Err(err) => fail("expected deep nested module decode success, got \{err}")
  }
}

///|
test "decode_module rejects deep nested block modules past the nesting limit" {
  let wasm = binary_test_deep_nested_block_module_bytes(10001)
  assert_decode_err_contains(
    (Decode::decode(wasm, 0) : Result[(Module, Int), BinaryDecodeError]),
    BinaryDecodeError::InstructionNestingLimitExceeded,
  )
  match decode_module(wasm) {
    Ok(_) => fail("expected nesting-limit wrapper decode failure")
    Err(
      DecodeError::DecodeAt(
        BinaryDecodeError::InstructionNestingLimitExceeded,
        18,
        30013
      )
    ) => ()
    Err(err) => fail("expected nesting-limit decode error, got \{err}")
  }
}

///|
test "Decode I32 rejects invalid terminal signed LEB unused bits" {
  assert_decode_err_contains(
    (
      Decode::decode(b"\x80\x80\x80\x80\x1f", 0) :
      Result[(I32, Int), BinaryDecodeError]),
    BinaryDecodeError::SignedLebOutOfRangeForBitWidth,
  )
  match
    (
      Decode::decode(b"\xff\xff\xff\xff\x4f", 0) :
      Result[(I32, Int), BinaryDecodeError]) {
    Ok(_) => fail("expected decode failure for invalid sign-extension bits")
    Err(_) => ()
  }
}

///|
test "invalid decode vectors are table-driven across decoders" {
  let module_vectors : Array[(String, Bytes, BinaryDecodeError)] = [
    (
      "bad magic header",
      b"\x01\x61\x73\x6D\x01\x00\x00\x00",
      BinaryDecodeError::InvalidMagicHeader,
    ),
    (
      "module trailing bytes",
      b"\x00\x61\x73\x6D\x01\x00\x00\x00\x7F",
      BinaryDecodeError::InvalidModule,
    ),
    (
      "custom section payload overflow",
      b"\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x02\x00",
      BinaryDecodeError::CustomSectionPayloadLengthOutOfRange,
    ),
    (
      "type section invalid payload content",
      b"\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x02\x01\xFF",
      BinaryDecodeError::InvalidCompType,
    ),
  ]
  for vector in module_vectors {
    let (name, bytes, expected) = vector
    match
      (Decode::decode(bytes, 0) : Result[(Module, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected module decode failure for vector '\{name}'")
      Err(err) => @debug.assert_eq(err, expected)
    }
  }

  let type_sec_vectors : Array[(String, Bytes, BinaryDecodeError)] = [
    (
      "wrong section header",
      b"\x02\x00",
      BinaryDecodeError::InvalidSectionHeader,
    ),
    (
      "payload length overflow",
      b"\x01\x03\x00",
      BinaryDecodeError::SectionPayloadLengthOutOfRange,
    ),
    (
      "unconsumed payload bytes",
      b"\x01\x02\x00\x00",
      BinaryDecodeError::InvalidSectionPayloadTrailingBytes,
    ),
  ]
  for vector in type_sec_vectors {
    let (name, bytes, expected) = vector
    match
      (Decode::decode(bytes, 0) : Result[(TypeSec, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected TypeSec decode failure for vector '\{name}'")
      Err(err) => @debug.assert_eq(err, expected)
    }
  }

  let instruction_vectors : Array[(String, Bytes, BinaryDecodeError)] = [
    ("unknown opcode", b"\xFF", BinaryDecodeError::InvalidInstruction),
    (
      "atomic.fence with non-zero immediate",
      b"\xFE\x03\x01",
      BinaryDecodeError::InvalidAtomicFenceImmediate,
    ),
  ]
  for vector in instruction_vectors {
    let (name, bytes, expected) = vector
    match
      (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]) {
      Ok(_) => fail("expected Instruction decode failure for vector '\{name}'")
      Err(err) => @debug.assert_eq(err, expected)
    }
  }
}

///|
test "decode primitive error branches include oob and nested failures" {
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(NumType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(AbsHeapType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(RefType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x63", 0) : Result[(RefType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInSignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x64", 0) : Result[(RefType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInSignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(ValType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(CompType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(Mut, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofDecodingMut,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x02", 0) : Result[(Mut, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidMutByte,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x79", 0) : Result[(StorageType, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidStorageType,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x79", 0) : Result[(PackType, Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidPackedType,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(RecType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x4E", 0) : Result[(RecType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(SubType, Int), BinaryDecodeError]),
    BinaryDecodeError::IndexOutOfBounds,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x4F", 0) : Result[(SubType, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
}

///|
test "generic list decode and encode propagate nested failures" {
  assert_decode_err_contains(
    (Decode::decode(b"", 0) : Result[(@list.List[Bool], Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x01\x02", 0) :
      Result[(@list.List[Bool], Int), BinaryDecodeError]),
    BinaryDecodeError::InvalidBoolByte,
  )
  match
    (
      Decode::decode(b"\x02\x00\x01", 0) :
      Result[(@list.List[Bool], Int), BinaryDecodeError]) {
    Ok((decoded, i)) => {
      @debug.assert_eq(i, 3)
      @debug.assert_eq(decoded.to_array(), [false, true])
    }
    Err(e) => fail("unexpected list decode failure: \{e}")
  }

  let bad_list = @list.List::from_array([TypeIdx::new(0), TypeIdx::rec(0)])
  assert_encode_err_contains(
    Encode::encode(bad_list, @buffer.new()),
    BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
  )
}

///|
test "encode rejects unsupported type/index forms" {
  assert_encode_err_contains(
    Encode::encode(TypeIdx::rec(0), @buffer.new()),
    BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
  )
  assert_encode_err_contains(
    Encode::encode(HeapType::new(TypeIdx::rec(0)), @buffer.new()),
    BinaryEncodeError::CannotEncodeRecursiveIndexHeapType,
  )
  assert_encode_err_contains(
    Encode::encode(ValType::bottom(), @buffer.new()),
    BinaryEncodeError::CannotEncodeBottomValType,
  )
  assert_encode_err_contains(
    Encode::encode(BlockType::type_idx(TypeIdx::rec(0)), @buffer.new()),
    BinaryEncodeError::CannotEncodeRecursiveIndexBlockType,
  )
  assert_encode_err_contains(
    Encode::encode(
      HeapType::def_type(DefType::new(RecType::group([]), 0)),
      @buffer.new(),
    ),
    BinaryEncodeError::CannotEncodeDefTypeHeapType,
  )
  assert_encode_err_contains(
    Encode::encode(MemArg::new(64, None, 0), @buffer.new()),
    BinaryEncodeError::InvalidMemArgEncoding,
  )
}

///|
test "encode section payload errors propagate from nested values" {
  let bad_type_sec = TypeSec::new([
    RecType::new(SubType::comp_type(CompType::func([ValType::bottom()], []))),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_type_sec, @buffer.new()),
    BinaryEncodeError::CannotEncodeBottomValType,
  )

  let bad_import_sec = ImportSec::new([
    Import::new(
      Name::new("m"),
      Name::new("f"),
      ExternType::func(TypeIdx::rec(0)),
    ),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_import_sec, @buffer.new()),
    BinaryEncodeError::CannotEncodeNonStandardTypeIndex,
  )

  let bad_code_sec = CodeSec::new([
    Func::new(
      Locals::empty(),
      Expr::new([
        Instruction::block(BlockType::type_idx(TypeIdx::rec(0)), Expr::new([])),
      ]),
    ),
  ])
  assert_encode_err_contains(
    Encode::encode(bad_code_sec, @buffer.new()),
    BinaryEncodeError::CannotEncodeRecursiveIndexBlockType,
  )

  let bad_module = Module::new().with_type_sec(bad_type_sec)
  assert_encode_err_contains(
    Encode::encode(bad_module, @buffer.new()),
    BinaryEncodeError::CannotEncodeBottomValType,
  )
}

///|
test "uleb encoder never exceeds ceil(nbits/7)" {
  let buf = @buffer.new()
  encode_unsigned((1UL << 33) - 1UL, buf, 33).unwrap()
  assert_true(buf.to_bytes().length() <= max_leb_bytes(33))
}

///|
test "sleb encoder never exceeds ceil(nbits/7)" {
  let buf = @buffer.new()
  encode_signed(-1L << 32, buf, 33).unwrap()
  assert_true(buf.to_bytes().length() <= max_leb_bytes(33))
}

///|
test "leb sizing and encoding reject invalid bit widths and ranges" {
  assert_encode_err_contains(
    encode_unsigned(1UL, @buffer.new(), 0),
    BinaryEncodeError::InvalidUnsignedLebBitWidth,
  )
  assert_encode_err_contains(
    encode_unsigned(256UL, @buffer.new(), 8),
    BinaryEncodeError::UnsignedLebValueOutOfRange,
  )
  assert_encode_err_contains(
    encode_signed(1L, @buffer.new(), 0),
    BinaryEncodeError::InvalidSignedLebBitWidth,
  )
  assert_encode_err_contains(
    encode_signed(200L, @buffer.new(), 8),
    BinaryEncodeError::SignedLebValueOutOfRange,
  )

  match size_unsigned(1UL, 0) {
    Ok(_) => fail("expected invalid nbits for size_unsigned")
    Err(e) => @debug.assert_eq(e, BinaryEncodeError::InvalidUnsignedLebBitWidth)
  }
  match size_unsigned(300UL, 8) {
    Ok(_) => fail("expected out-of-range size_unsigned")
    Err(e) => @debug.assert_eq(e, BinaryEncodeError::UnsignedLebValueOutOfRange)
  }
  match size_signed(1L, 0) {
    Ok(_) => fail("expected invalid nbits for size_signed")
    Err(e) => @debug.assert_eq(e, BinaryEncodeError::InvalidSignedLebBitWidth)
  }
  match size_signed(200L, 8) {
    Ok(_) => fail("expected out-of-range size_signed")
    Err(e) => @debug.assert_eq(e, BinaryEncodeError::SignedLebValueOutOfRange)
  }
}

///|
test "max leb constants match common widths" {
  @debug.assert_eq(MAX_LEB128_BYTES_32, 5)
  @debug.assert_eq(MAX_LEB128_BYTES_33, 5)
  @debug.assert_eq(MAX_LEB128_BYTES_64, 10)
  @debug.assert_eq(max_leb_bytes(32), MAX_LEB128_BYTES_32)
  @debug.assert_eq(max_leb_bytes(33), MAX_LEB128_BYTES_33)
  @debug.assert_eq(max_leb_bytes(64), MAX_LEB128_BYTES_64)
}

///|
test "write_section helper writes id length and payload" {
  let buf = @buffer.new()
  match
    write_section(42, buf, fn(payload) {
      payload.write_byte(0xAB)
      payload.write_byte(0xCD)
      Ok(())
    }) {
    Ok(_) => @debug.assert_eq(buf.to_bytes().to_array(), [42, 2, 0xAB, 0xCD])
    Err(e) => fail("unexpected write_section error: \{e}")
  }
}

///|
test "write_section helper propagates payload errors" {
  let buf = @buffer.new()
  assert_encode_err_contains(
    write_section(1, buf, fn(_) {
      Err(BinaryEncodeError::CannotEncodeBottomValType)
    }),
    BinaryEncodeError::CannotEncodeBottomValType,
  )
}

///|
test "start code and data count sections encode with canonical payload lengths" {
  let start_buf = @buffer.new()
  match Encode::encode(StartSec::new(FuncIdx::new(0)), start_buf) {
    Ok(_) =>
      @debug.assert_eq(start_buf.to_bytes().to_array(), [0x08, 0x01, 0x00])
    Err(e) => fail("unexpected start section encode failure: \{e}")
  }

  let code_buf = @buffer.new()
  match Encode::encode(CodeSec::new([]), code_buf) {
    Ok(_) =>
      @debug.assert_eq(code_buf.to_bytes().to_array(), [0x0A, 0x01, 0x00])
    Err(e) => fail("unexpected code section encode failure: \{e}")
  }

  let data_cnt_buf = @buffer.new()
  match Encode::encode(DataCntSec::new(U32(0)), data_cnt_buf) {
    Ok(_) =>
      @debug.assert_eq(data_cnt_buf.to_bytes().to_array(), [0x0C, 0x01, 0x00])
    Err(e) => fail("unexpected data count section encode failure: \{e}")
  }
}

///|
test "start code and data count sections decode canonical payload wrappers" {
  match
    (
      Decode::decode(b"\x08\x01\x00", 0) :
      Result[(StartSec, Int), BinaryDecodeError]) {
    Ok((start, next)) => {
      @debug.assert_eq(start, StartSec::new(FuncIdx::new(0)))
      @debug.assert_eq(next, 3)
    }
    Err(e) => fail("unexpected start section decode failure: \{e}")
  }

  match
    (
      Decode::decode(b"\x0A\x01\x00", 0) :
      Result[(CodeSec, Int), BinaryDecodeError]) {
    Ok((code, next)) => {
      @debug.assert_eq(code, CodeSec::new([]))
      @debug.assert_eq(next, 3)
    }
    Err(e) => fail("unexpected code section decode failure: \{e}")
  }

  match
    (
      Decode::decode(b"\x0C\x01\x00", 0) :
      Result[(DataCntSec, Int), BinaryDecodeError]) {
    Ok((data_count, next)) => {
      @debug.assert_eq(data_count, DataCntSec::new(U32(0)))
      @debug.assert_eq(next, 3)
    }
    Err(e) => fail("unexpected data count section decode failure: \{e}")
  }
}

///|
test "start code and data count sections reject legacy non-length encoding forms" {
  assert_decode_err_contains(
    (Decode::decode(b"\x08\x00", 0) : Result[(StartSec, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (Decode::decode(b"\x0A\x00", 0) : Result[(CodeSec, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
  assert_decode_err_contains(
    (
      Decode::decode(b"\x0C\x00", 0) :
      Result[(DataCntSec, Int), BinaryDecodeError]),
    BinaryDecodeError::UnexpectedEofInUnsignedLeb,
  )
}

///|
test "numtype valtype" {
  roundtrip(NumType::f32())
  roundtrip(NumType::f64())
  roundtrip(NumType::i32())
  roundtrip(NumType::i64())
}

///|
test "Heap Types" {
  roundtrip(HeapType::abs(AbsHeapType::exn()))
  roundtrip(HeapType::abs(AbsHeapType::string_()))
  roundtrip(HeapType::abs(AbsHeapType::array()))
  roundtrip(HeapType::abs(AbsHeapType::struct_()))
  roundtrip(HeapType::abs(AbsHeapType::i31()))
  roundtrip(HeapType::abs(AbsHeapType::eq()))
  roundtrip(HeapType::abs(AbsHeapType::any()))
  roundtrip(HeapType::abs(AbsHeapType::extern_()))
  roundtrip(HeapType::abs(AbsHeapType::func()))
  roundtrip(HeapType::abs(AbsHeapType::none()))
  roundtrip(HeapType::abs(AbsHeapType::no_extern()))
  roundtrip(HeapType::abs(AbsHeapType::no_func()))
  roundtrip(HeapType::abs(AbsHeapType::no_exn()))
  roundtrip(HeapType::new(TypeIdx::new(23)))
}

///|
test "Type Indexes" {
  roundtrip(TypeIdx::new(0))
  roundtrip(TypeIdx::new(23))
  roundtrip(TypeIdx::new(2048))
}

///|
test "decode accepts bare stringref valtype" {
  match
    (Decode::decode(b"\x64", 0) : Result[(ValType, Int), BinaryDecodeError]) {
    Ok((vt, next)) => {
      @debug.assert_eq(vt, ValType::stringref())
      @debug.assert_eq(next, 1)
    }
    Err(err) =>
      fail("expected bare stringref valtype decode success, got \{err}")
  }
}

///|
test "decode bare stringref valtype re-encodes canonical nullable form" {
  let (vt, next) = match
    (Decode::decode(b"\x64", 0) : Result[(ValType, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(err) =>
      fail("expected bare stringref valtype decode success, got \{err}")
  }
  @debug.assert_eq(next, 1)
  @debug.assert_eq(vt, ValType::stringref())
  let buf = @buffer.new()
  match Encode::encode(vt, buf) {
    Ok(_) => ()
    Err(err) => fail("expected stringref valtype re-encode success, got \{err}")
  }
  @debug.assert_eq(buf.to_bytes(), b"\x63\x64")
}

///|
test "decode accepts explicit nullable stringref valtype" {
  let (vt, next) = match
    (Decode::decode(b"\x63\x64", 0) : Result[(ValType, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(err) =>
      fail(
        "expected explicit nullable stringref valtype decode success, got \{err}",
      )
  }
  @debug.assert_eq(next, 2)
  @debug.assert_eq(vt, ValType::stringref())
  let buf = @buffer.new()
  match Encode::encode(vt, buf) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nullable stringref valtype re-encode success, got \{err}")
  }
  @debug.assert_eq(buf.to_bytes(), b"\x63\x64")
}

///|
test "decode accepts explicit non-null stringref valtype" {
  let expected = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::string_())),
  )
  let (vt, next) = match
    (Decode::decode(b"\x64\x64", 0) : Result[(ValType, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(err) =>
      fail(
        "expected explicit non-null stringref valtype decode success, got \{err}",
      )
  }
  @debug.assert_eq(next, 2)
  @debug.assert_eq(vt, expected)
  let buf = @buffer.new()
  match Encode::encode(vt, buf) {
    Ok(_) => ()
    Err(err) =>
      fail("expected non-null stringref valtype re-encode success, got \{err}")
  }
  @debug.assert_eq(buf.to_bytes(), b"\x64\x64")
}

///|
test "decode type section accepts bare stringref result" {
  let wasm = Bytes::from_array([
    0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60, 0x00,
    0x01, 0x64,
  ])
  let mod = match decode_module(wasm) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected bare stringref type-section decode success, got \{err}")
  }
  match mod.type_sec {
    Some(
      @lib.TypeSec(
        [
          @lib.SingleRecType(
            @lib.CompTypeSubType(_, @lib.FuncCompType(_, results))
          ),
        ]
      )
    ) => @debug.assert_eq(results, [ValType::stringref()])
    other =>
      fail(
        "expected decoded stringref result type, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "Ref Types" {
  roundtrip(RefType::new(true, HeapType::abs(AbsHeapType::func())))
  roundtrip(RefType::new(false, HeapType::abs(AbsHeapType::extern_())))
  roundtrip(RefType::abs(AbsHeapType::eq()))
}

///|
test "encode ref.null uses heap-type immediate for abstract refs" {
  let instr = Instruction::ref_null(HeapType::abs(AbsHeapType::extern_()))
  let buf = @buffer.new()
  match Encode::encode(instr, buf) {
    Ok(_) => ()
    Err(e) => fail("expected ref.null extern encode success, got \{e}")
  }
  let bytes = buf.to_bytes()
  @debug.assert_eq(bytes, b"\xd0\x6f")
  let (decoded, i) = match
    (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => fail("expected ref.null extern decode success, got \{e}")
  }
  @debug.assert_eq(i, bytes.length())
  @debug.assert_eq(decoded, instr)
}

///|
test "encode ref.null exact type index uses heap-type immediate" {
  let instr = Instruction::ref_null_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0U)), exact=true),
  )
  let buf = @buffer.new()
  match Encode::encode(instr, buf) {
    Ok(_) => ()
    Err(e) => fail("expected exact typed ref.null encode success, got \{e}")
  }
  let bytes = buf.to_bytes()
  @debug.assert_eq(bytes, b"\xd0\x62\x00")
  let (decoded, i) = match
    (Decode::decode(bytes, 0) : Result[(Instruction, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => fail("expected exact typed ref.null decode success, got \{e}")
  }
  @debug.assert_eq(i, bytes.length())
  @debug.assert_eq(decoded, instr)
}

///|
test "Comp Types" {
  roundtrip(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  roundtrip(
    CompType::struct_([
      FieldType::new(
        StorageType::val_type(
          ValType::ref_type(
            RefType::new(true, HeapType::abs(AbsHeapType::i31())),
          ),
        ),
        Var,
      ),
    ]),
  )
  roundtrip(
    CompType::func([ValType::i32(), ValType::i64()], [
      ValType::i64(),
      ValType::i32(),
    ]),
  )
}

///|
test "Packed Type" {
  roundtrip(PackType::i8())
  roundtrip(PackType::i16())
}

///|
test "SubTypes" {
  roundtrip(
    SubType::comp_type(
      CompType::array(
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ),
    ),
  )
  roundtrip(
    SubType::new(
      false,
      [TypeIdx::new(0), TypeIdx::new(2), TypeIdx::new(4)],
      CompType::func([], []),
    ),
  )
}

///|
test "Float specific edge case?" {
  roundtrip(Instruction::f32_const(F32(0.011397957801818848)))
}

///|
test "Descriptor instruction roundtrip" {
  roundtrip(Instruction::ref_get_desc(TypeIdx::new(0)))
  roundtrip(
    Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::struct_())),
  )
  roundtrip(
    Instruction::ref_cast_desc_eq(false, HeapType::new(TypeIdx::new(2))),
  )
}

///|
test "String array instruction roundtrip" {
  roundtrip(Instruction::string_new_utf8_array())
  roundtrip(Instruction::string_new_lossy_utf8_array())
  roundtrip(Instruction::string_new_wtf8_array())
  roundtrip(Instruction::string_new_wtf16_array())
  roundtrip(Instruction::string_encode_utf8_array())
  roundtrip(Instruction::string_encode_lossy_utf8_array())
  roundtrip(Instruction::string_encode_wtf8_array())
  roundtrip(Instruction::string_encode_wtf16_array())
}

///|
test "module roundtrip preserves string.const literals and stringrefs section" {
  let bytes = b"hello"
  let mod = Module::new(
    type_sec=Some(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([], [ValType::stringref()])),
        ),
      ]),
    ),
    stringrefs_sec=Some(StringRefsSec::new([bytes])),
    func_sec=Some(FuncSec::new([TypeIdx::new(0)])),
    global_sec=Some(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::stringref(), false),
          Expr::new([Instruction::string_const(bytes)]),
        ),
      ]),
    ),
    code_sec=Some(
      CodeSec::new([
        Func::new(
          Locals::new([]),
          Expr::new([Instruction::string_const(bytes)]),
        ),
      ]),
    ),
  )
  let wasm = match encode_module(mod) {
    Ok(wasm) => wasm
    Err(err) => fail("expected string.const module to encode: \{err}")
  }
  let decoded = match decode_module(wasm) {
    Ok(decoded) => decoded
    Err(err) => fail("expected string.const module to decode: \{err}")
  }
  @debug.assert_eq(decoded, mod)
}

///|
fn binary_name_section_fixture_module() -> Module {
  let struct_type = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1U, Some(1U)),
  )
  let name_sec = NameSec::new(
    module_name=Some(Name::new("fixture")),
    func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("id"))])),
    local_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([NameAssoc::new(0U, Name::new("x"))]),
        ),
      ]),
    ),
    label_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([
            NameAssoc::new(0U, Name::new("entry")),
            NameAssoc::new(1U, Name::new("repeat")),
            NameAssoc::new(2U, Name::new("branch")),
          ]),
        ),
      ]),
    ),
    type_names=Some(
      NameMap::new([
        NameAssoc::new(0U, Name::new("Pair")),
        NameAssoc::new(1U, Name::new("IdSig")),
        NameAssoc::new(2U, Name::new("TagSig")),
      ]),
    ),
    table_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("dispatch"))])),
    memory_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("heap"))])),
    global_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("flag"))])),
    elem_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("targets"))])),
    data_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("blob"))])),
    field_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([NameAssoc::new(0U, Name::new("value"))]),
        ),
      ]),
    ),
    tag_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("boom"))])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([struct_type, func_type, tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_table_sec(TableSec::new([Table::new(table_type, None)]))
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::i32_const(I32(1))]),
      ),
    ]),
  )
  .with_elem_sec(
    ElemSec::new([
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_data_sec(
    DataSec::new([
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"fixture",
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::block(BlockType::void_(), Expr::new([])),
          Instruction::loop_(BlockType::void_(), Expr::new([])),
          Instruction::i32_const(I32(1)),
          Instruction::if_(BlockType::void_(), [], Some([])),
          Instruction::local_get(LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_name_sec(name_sec)
}

///|
test "encode_module emits structured name section after standard sections and decode_module roundtrips it" {
  let mod = binary_name_section_fixture_module()
  let wasm = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(e) => fail("expected encode success, got \{e}")
  }
  @debug.assert_eq(wasm[8], 0x01)

  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  @debug.assert_eq(decoded, mod)
  @debug.assert_eq(decoded.custom_secs.length(), 0)
  @debug.assert_eq(decoded.name_sec, mod.name_sec)
  assert_true(decoded.raw_name_sec_payload is Some(_))
}

///|
test "encode_module reuses raw decoded name-section payload bytes" {
  let module_name = Name::new("fixture")
  let func_names = NameMap::new([NameAssoc::new(0U, Name::new("id"))])
  let module_name_payload = @buffer.new()
  match Encode::encode(module_name, module_name_payload) {
    Ok(_) => ()
    Err(e) => fail("expected module name payload encode success, got \{e}")
  }
  let func_name_payload = @buffer.new()
  match Encode::encode(func_names, func_name_payload) {
    Ok(_) => ()
    Err(e) => fail("expected func name payload encode success, got \{e}")
  }
  let name_payload = @buffer.new()
  name_payload.write_byte(0)
  match
    Encode::encode(
      @lib.U32(module_name_payload.to_bytes().length().reinterpret_as_uint()),
      name_payload,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail("expected module name subsection size encode success, got \{e}")
  }
  name_payload.write_bytes(module_name_payload.to_bytes())
  name_payload.write_byte(1)
  match
    Encode::encode(
      @lib.U32(func_name_payload.to_bytes().length().reinterpret_as_uint()),
      name_payload,
    ) {
    Ok(_) => ()
    Err(e) =>
      fail("expected func name subsection size encode success, got \{e}")
  }
  name_payload.write_bytes(func_name_payload.to_bytes())
  let custom_buf = @buffer.new()
  match
    Encode::encode(
      CustomSec::new(Name::new("name"), name_payload.to_bytes()),
      custom_buf,
    ) {
    Ok(_) => ()
    Err(e) => fail("expected custom section encode success, got \{e}")
  }
  let wasm = b"\x00\x61\x73\x6D\x01\x00\x00\x00" + custom_buf.to_bytes()
  let decoded = match decode_module(wasm) {
    Ok(v) => v
    Err(e) => fail("expected decode success, got \{e}")
  }
  @debug.assert_eq(decoded.raw_name_sec_payload, Some(name_payload.to_bytes()))
  let reencoded = match encode_module(decoded) {
    Ok(bytes) => bytes
    Err(e) => fail("expected re-encode success, got \{e}")
  }
  @debug.assert_eq(reencoded, wasm)
}

///|
test "decode_module rejects malformed function name map ordering inside name section" {
  let bad = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x0e\x04name\x01\x07\x02\x01\x01b\x00\x01a"
  match decode_module(bad) {
    Ok(_) => fail("expected malformed name section decode failure")
    Err(
      DecodeError::DecodeAt(BinaryDecodeError::InvalidNameMapOrder, offset, len)
    ) => {
      @debug.assert_eq(offset, 8)
      @debug.assert_eq(len, 16)
    }
    Err(e) =>
      fail("expected spanned malformed name-section decode error, got \{e}")
  }
}

///|
test "FUZ1056A4 malformed name section detail carries custom section id and span" {
  let bad = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x0e\x04name\x01\x07\x02\x01\x01b\x00\x01a"
  match decode_module_with_detail(bad, 0) {
    Ok(_) => fail("expected detailed malformed name section decode failure")
    Err(detail) => {
      @debug.assert_eq(detail.err, BinaryDecodeError::InvalidNameMapOrder)
      @debug.assert_eq(detail.section_id, Some(0))
      @debug.assert_eq(detail.section_offset, Some(8))
      @debug.assert_eq(detail.section_len, Some(16))
    }
  }
}
