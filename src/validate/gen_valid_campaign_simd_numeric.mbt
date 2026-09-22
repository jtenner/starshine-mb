///|
fn gen_valid_campaign_simd_numeric_config() -> GenValidConfig {
  let base = GenValidConfig::coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 1,
    max_imports: 0,
    max_defined_funcs: 1,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_params: 1,
    max_results: 1,
    max_locals: 3,
    max_body_statements: 24,
    max_body_depth: 1,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_v128: true,
      allow_relaxed_simd: false,
      allow_atomics: false,
    },
  }
}

///|
fn gen_valid_campaign_simd_numeric_const(seed : UInt64) -> Instruction {
  let b0 = (seed & 0xffUL).to_byte()
  let b1 = ((seed >> 8) & 0xffUL).to_byte()
  let b2 = ((seed >> 16) & 0xffUL).to_byte()
  let b3 = ((seed >> 24) & 0xffUL).to_byte()
  Instruction::v128_const(
    b0, b1, b2, b3, b3, b2, b1, b0, b0, b1, b2, b3, b3, b2, b1, b0,
  )
}

///|
fn gen_valid_campaign_simd_numeric_module(ctx : GenValidContext) -> Module {
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  let shape = (seed % 12UL).to_int()
  let lane = LaneIdx::new((seed / 12UL % 4UL).to_byte())
  let first = LocalIdx::new(1U)
  let second = LocalIdx::new(2U)
  let mask = LocalIdx::new(3U)
  let (a, b, c) = match shape {
    0 => (first, first, mask)
    1 => (first, second, first)
    2 => (first, second, second)
    3 => (first, second, mask)
    4 => (first, first, first)
    _ =>
      if ((seed / 12UL) & 1UL) == 0UL {
        (first, second, mask)
      } else {
        (second, first, mask)
      }
  }
  let body : Array[Instruction] = [
    gen_valid_campaign_simd_numeric_const(seed ^ 0x10001UL),
    Instruction::local_set(first),
    Instruction::i32_const(I32(((seed ^ 0x5a5aUL) & 0x7fffffffUL).to_int())),
    Instruction::i32x4_splat(),
    Instruction::local_set(second),
    gen_valid_campaign_simd_numeric_const(seed ^ 0xa55aa55aUL),
    Instruction::local_set(mask),
    Instruction::local_get(a),
    Instruction::local_get(b),
    Instruction::local_get(c),
    Instruction::v128_bitselect(),
  ]
  match shape {
    5 => {
      body.push(Instruction::i32_const(I32((seed & 0xffffUL).to_int())))
      body.push(Instruction::i32x4_replace_lane(lane))
      body.push(Instruction::i32x4_extract_lane(lane))
    }
    6 => {
      body.push(Instruction::f32x4_convert_i32x4s())
      body.push(Instruction::f32x4_extract_lane(lane))
      body.push(Instruction::i32_reinterpret_f32())
    }
    7 =>
      body.push(
        Instruction::i8x16_extract_lane_s(
          LaneIdx::new((seed / 12UL % 16UL).to_byte()),
        ),
      )
    8 =>
      body.push(
        Instruction::i8x16_extract_lane_u(
          LaneIdx::new((seed / 12UL % 16UL).to_byte()),
        ),
      )
    9 => {
      body.push(Instruction::local_tee(first))
      body.push(Instruction::local_get(second))
      body.push(Instruction::v128_xor())
      body.push(Instruction::i32x4_extract_lane(lane))
    }
    10 => {
      body.push(Instruction::local_set(first))
      body.push(Instruction::local_get(LocalIdx::new(0U)))
      body.push(
        Instruction::if_(
          BlockType::val_type(ValType::i32()),
          [Instruction::local_get(first), Instruction::i32x4_extract_lane(lane)],
          Some([
            Instruction::local_get(second),
            Instruction::i32x4_extract_lane(lane),
          ]),
        ),
      )
    }
    11 => {
      body.push(Instruction::i32x4_extract_lane(lane))
      body.push(Instruction::i32_const(I32((seed & 127UL).to_int())))
      body.push(Instruction::local_get(LocalIdx::new(0U)))
      body.push(Instruction::select())
    }
    _ => body.push(Instruction::i32x4_extract_lane(lane))
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::from_types([ValType::v128(), ValType::v128(), ValType::v128()]),
        Expr::new(body),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}
